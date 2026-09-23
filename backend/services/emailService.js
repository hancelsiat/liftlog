const axios = require('axios');
const fs = require('fs');
const path = require('path');
const nodemailer = require('nodemailer');

const BREVO_API_KEY = process.env.BREVO_API_KEY;
const BREVO_API_URL = 'https://api.brevo.com/v3/smtp/email';

// List of sender configurations to try (in priority order)
const SENDERS = [
  {
    name: process.env.BREVO_SENDER_NAME || 'LiftLog App',
    email: process.env.BREVO_SENDER_EMAIL || 'lftlogapp@gmail.com',
  },
  {
    name: 'LiftLog App',
    email: 'hancel.siat@gmail.com',
  },
  {
    name: 'LiftLog Support',
    email: 'lftlogapp@gmail.com',
  },
];

// Gmail SMTP fallback config (in case Brevo HTTP fails entirely)
const GMAIL_SMTP_CONFIG = {
  host: 'smtp.gmail.com',
  port: 587,
  secure: false,
  auth: {
    user: 'lftlogapp@gmail.com',
    pass: process.env.GMAIL_APP_PASSWORD,
  },
  tls: {
    rejectUnauthorized: false,
    ciphers: 'SSLv3',
  },
};

if (!BREVO_API_KEY) {
  console.log('BREVO_API_KEY is missing in environment variables. Will try Gmail SMTP fallback.');
} else {
  console.log(`Brevo email service initialized. Primary Sender: ${SENDERS[0].name} <${SENDERS[0].email}>`);
}

const sendEmailViaBrevo = async (sender, to, subject, htmlContent) => {
  if (!BREVO_API_KEY) {
    throw new Error('BREVO_API_KEY not set');
  }

  const payload = {
    sender: {
      name: sender.name,
      email: sender.email,
    },
    to: [
      {
        email: to,
      },
    ],
    subject: subject,
    htmlContent: htmlContent,
  };

  const response = await axios.post(BREVO_API_URL, payload, {
    headers: {
      'api-key': BREVO_API_KEY,
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
    timeout: 10000,
  });

  return { method: 'brevo', sender: sender.email, messageId: response.data.messageId };
};

const sendEmailViaGmailSmtp = async (to, subject, htmlContent) => {
  if (!process.env.GMAIL_APP_PASSWORD) {
    throw new Error('GMAIL_APP_PASSWORD not set for SMTP fallback.');
  }

  const transporter = nodemailer.createTransport(GMAIL_SMTP_CONFIG);
  const info = await transporter.sendMail({
    from: `"LiftLog App" <${GMAIL_SMTP_CONFIG.auth.user}>`,
    to: to,
    subject: subject,
    html: htmlContent,
  });

  return { method: 'gmail_smtp', sender: GMAIL_SMTP_CONFIG.auth.user, messageId: info.messageId };
};

const sendEmail = async (to, subject, htmlContent) => {
  const errors = [];

  // Strategy 1: Try Brevo with multiple sender identities
  if (BREVO_API_KEY) {
    for (const sender of SENDERS) {
      try {
        const result = await sendEmailViaBrevo(sender, to, subject, htmlContent);
        console.log(`Email sent via Brevo [Sender: ${sender.email}] to ${to}. ID: ${result.messageId || 'N/A'}`);
        return { success: true, ...result };
      } catch (error) {
        const errMsg = error.response
          ? `Brevo [${sender.email}] Status: ${error.response.status}, Data: ${JSON.stringify(error.response.data)}`
          : `Brevo [${sender.email}] Error: ${error.message}`;
        console.error(`[EMAIL ERROR] ${errMsg}`);
        errors.push(errMsg);
      }
    }
  }

  // Strategy 2: Fallback to Gmail SMTP
  console.log('Brevo failed or unavailable. Trying Gmail SMTP fallback...');
  try {
    const result = await sendEmailViaGmailSmtp(to, subject, htmlContent);
    console.log(`Email sent via Gmail SMTP fallback to ${to}. ID: ${result.messageId || 'N/A'}`);
    return { success: true, ...result };
  } catch (smtpError) {
    const errMsg = `Gmail SMTP Error: ${smtpError.message}`;
    console.error(`[EMAIL ERROR] ${errMsg}`);
    errors.push(errMsg);
  }

  console.error(`All email sending methods failed for ${to}:`, errors);
  return { success: false, errors };
};

const sendVerificationEmail = async (to, token) => {
  const verificationUrl = `https://liftlog-7.onrender.com/api/auth/verify-email/${token}`;
  const templatePath = path.join(__dirname, '..', 'templates', 'verificationEmail.html');
  let htmlContent = fs.readFileSync(templatePath, 'utf8');
  htmlContent = htmlContent.replace('{{verificationUrl}}', verificationUrl);

  const result = await sendEmail(to, 'Verify Your Email Address', htmlContent);
  return result;
};

const sendApprovalEmail = async (to, username) => {
  const templatePath = path.join(__dirname, '..', 'templates', 'approvalEmail.html');
  let htmlContent = fs.readFileSync(templatePath, 'utf8');
  htmlContent = htmlContent.replace('{{username}}', username);

  return sendEmail(to, 'Your Trainer Account has been Approved!', htmlContent);
};

const sendRejectionEmail = async (to, username, rejectionReason) => {
  const templatePath = path.join(__dirname, '..', 'templates', 'rejectionEmail.html');
  let htmlContent = fs.readFileSync(templatePath, 'utf8');
  htmlContent = htmlContent.replace('{{username}}', username);
  htmlContent = htmlContent.replace('{{rejectionReason}}', rejectionReason);

  return sendEmail(to, 'An Update on Your Trainer Application', htmlContent);
};

module.exports = { sendVerificationEmail, sendApprovalEmail, sendRejectionEmail, sendEmail };
