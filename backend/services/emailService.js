const axios = require('axios');
const fs = require('fs');
const path = require('path');

const BREVO_API_KEY = process.env.BREVO_API_KEY;
const BREVO_API_URL = 'https://api.brevo.com/v3/smtp/email';

const SENDER_EMAIL = process.env.BREVO_SENDER_EMAIL || 'lftlogapp@gmail.com';
const SENDER_NAME = process.env.BREVO_SENDER_NAME || 'LiftLog App';

if (!BREVO_API_KEY) {
  console.log('BREVO_API_KEY is missing in environment variables. Email service may not work.');
} else {
  console.log(`Brevo email service initialized. Sender: ${SENDER_NAME} <${SENDER_EMAIL}>`);
}

const sendEmail = async (to, subject, htmlContent) => {
  if (!BREVO_API_KEY) {
    console.error('Cannot send email: BREVO_API_KEY is not set.');
    return false;
  }

  const payload = {
    sender: {
      name: SENDER_NAME,
      email: SENDER_EMAIL,
    },
    to: [
      {
        email: to,
      },
    ],
    subject: subject,
    htmlContent: htmlContent,
  };

  try {
    const response = await axios.post(BREVO_API_URL, payload, {
      headers: {
        'api-key': BREVO_API_KEY,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      timeout: 15000,
    });

    console.log(`Email sent successfully to ${to}. Message ID: ${response.data.messageId || 'N/A'}`);
    return true;
  } catch (error) {
    console.error(`Error sending email to ${to} via Brevo:`);
    if (error.response) {
      console.error('Status:', error.response.status);
      console.error('Data:', error.response.data);
    } else if (error.request) {
      console.error('No response received:', error.message);
    } else {
      console.error('Error:', error.message);
    }
    return false;
  }
};

const sendVerificationEmail = async (to, token) => {
  const verificationUrl = `https://liftlog-7.onrender.com/api/auth/verify-email/${token}`;
  const templatePath = path.join(__dirname, '..', 'templates', 'verificationEmail.html');
  let htmlContent = fs.readFileSync(templatePath, 'utf8');
  htmlContent = htmlContent.replace('{{verificationUrl}}', verificationUrl);

  return sendEmail(to, 'Verify Your Email Address', htmlContent);
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

module.exports = { sendVerificationEmail, sendApprovalEmail, sendRejectionEmail };
