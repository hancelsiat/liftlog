const nodemailer = require('nodemailer');
const fs = require('fs');
const path = require('path');

// Configure Nodemailer transporter using Gmail
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: 'lftlogapp@gmail.com',
    pass: process.env.GMAIL_APP_PASSWORD, // Uses the app password from .env
  },
});

console.log('Gmail (Nodemailer) email service initialized.');

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

  try {
    await transporter.sendMail(mailOptions);
    console.log(`Verification email sent to ${to}`);
  } catch (error) {
    console.error('Error sending verification email with Gmail:', error);
  }
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

  try {
    await transporter.sendMail(mailOptions);
    console.log(`Approval email sent to ${to}`);
  } catch (error) {
    console.error('Error sending approval email with Gmail:', error);
  }
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

  try {
    await transporter.sendMail(mailOptions);
    console.log(`Rejection email sent to ${to}`);
  } catch (error) {
    console.error('Error sending rejection email with Gmail:', error);
  }
};

module.exports = { sendVerificationEmail, sendApprovalEmail, sendRejectionEmail };
