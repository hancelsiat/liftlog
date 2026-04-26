
const nodemailer = require('nodemailer');
const fs = require('fs');
const path = require('path');

const transporter = nodemailer.createTransport({
  host: 'smtp.gmail.com',
  port: 465,
  secure: true, // true for 465, false for other ports
  auth: {
    user: 'lftlogapp@gmail.com', // Your new Gmail address
    pass: process.env.GMAIL_APP_PASSWORD, // Your new App Password
  },
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
