const sgMail = require('@sendgrid/mail');
const fs = require('fs');
const path = require('path');

// Set the SendGrid API key from environment variables
sgMail.setApiKey(process.env.SENDGRID_API_KEY);

console.log('SendGrid email service initialized.');

const sendVerificationEmail = async (to, token) => {
  const verificationUrl = `https://liftlog-7.onrender.com/api/auth/verify-email/${token}`;
  const templatePath = path.join(__dirname, '..', 'templates', 'verificationEmail.html');
  let htmlContent = fs.readFileSync(templatePath, 'utf8');
  htmlContent = htmlContent.replace('{{verificationUrl}}', verificationUrl);

  const msg = {
    to,
    from: 'lftlogapp@gmail.com', // This must be your verified sender
    subject: 'Verify Your Email Address',
    html: htmlContent,
  };

  try {
    await sgMail.send(msg);
    console.log(`Verification email sent to ${to}`);
  } catch (error) {
    console.error('Error sending verification email with SendGrid:', error);
    if (error.response) {
      console.error(error.response.body);
    }
  }
};

const sendApprovalEmail = async (to, username) => {
  const templatePath = path.join(__dirname, '..', 'templates', 'approvalEmail.html');
  let htmlContent = fs.readFileSync(templatePath, 'utf8');
  htmlContent = htmlContent.replace('{{username}}', username);

  const msg = {
    to,
    from: 'lftlogapp@gmail.com', 
    subject: 'Your Trainer Account has been Approved!',
    html: htmlContent,
  };

  try {
    await sgMail.send(msg);
    console.log(`Approval email sent to ${to}`);
  } catch (error) {
    console.error('Error sending approval email with SendGrid:', error);
  }
};

const sendRejectionEmail = async (to, username, rejectionReason) => {
  const templatePath = path.join(__dirname, '..', 'templates', 'rejectionEmail.html');
  let htmlContent = fs.readFileSync(templatePath, 'utf8');
  htmlContent = htmlContent.replace('{{username}}', username);
  htmlContent = htmlContent.replace('{{rejectionReason}}', rejectionReason);

  const msg = {
    to,
    from: 'lftlogapp@gmail.com',
    subject: 'An Update on Your Trainer Application',
    html: htmlContent,
  };

  try {
    await sgMail.send(msg);
    console.log(`Rejection email sent to ${to}`);
  } catch (error) {
    console.error('Error sending rejection email with SendGrid:', error);
  }
};

module.exports = { sendVerificationEmail, sendApprovalEmail, sendRejectionEmail };
