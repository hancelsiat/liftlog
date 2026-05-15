
const dns = require('dns');
const nodemailer = require('nodemailer');
const fs = require('fs');
const path = require('path');

dns.setDefaultResultOrder('ipv4first');

const transporter = nodemailer.createTransport({
  service: 'gmail',
  host: 'smtp.gmail.com',
  port: 465,
  secure: true,
  auth: {
    user: 'lftlogapp@gmail.com',
    pass: process.env.GMAIL_APP_PASSWORD,
  },
  tls: {
    rejectUnauthorized: false
  }
});

console.log('Nodemailer transporter created with updated settings.');

transporter.verify(function(error, success) {
  if (error) {
    console.error('Nodemailer transporter verification error:', error.message);
    console.error('Full error details:', error);
  } else {
    console.log('Nodemailer transporter is ready to send emails.');
  }
});

const sendVerificationEmail = async (to, token) => {
  const verificationUrl = `https://liftlog-7.onrender.com/api/auth/verify-email/${token}`;
  const templatePath = path.join(__dirname, '..', 'templates', 'verificationEmail.html');
  let htmlContent = fs.readFileSync(templatePath, 'utf8');
  htmlContent = htmlContent.replace('{{verificationUrl}}', verificationUrl);

  const mailOptions = {
    from: '"LiftLog" <lftlogapp@gmail.com>',
    to,
    subject: 'Verify Your Email Address',
    html: htmlContent,
  };

  await transporter.sendMail(mailOptions);
};

const sendApprovalEmail = async (to, username) => {
  const templatePath = path.join(__dirname, '..', 'templates', 'approvalEmail.html');
  let htmlContent = fs.readFileSync(templatePath, 'utf8');
  htmlContent = htmlContent.replace('{{username}}', username);

  const mailOptions = {
    from: '"LiftLog" <lftlogapp@gmail.com>',
    to,
    subject: 'Your Trainer Account has been Approved!',
    html: htmlContent,
  };

  await transporter.sendMail(mailOptions);
};

const sendRejectionEmail = async (to, username, rejectionReason) => {
  const templatePath = path.join(__dirname, '..', 'templates', 'rejectionEmail.html');
  let htmlContent = fs.readFileSync(templatePath, 'utf8');
  htmlContent = htmlContent.replace('{{username}}', username);
  htmlContent = htmlContent.replace('{{rejectionReason}}', rejectionReason);

  const mailOptions = {
    from: '"LiftLog" <lftlogapp@gmail.com>',
    to,
    subject: 'An Update on Your Trainer Application',
    html: htmlContent,
  };

  await transporter.sendMail(mailOptions);
};

module.exports = { sendVerificationEmail, sendApprovalEmail, sendRejectionEmail };
