
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

  // Read the HTML template
  const templatePath = path.join(__dirname, '..', 'templates', 'verificationEmail.html');
  let htmlContent = fs.readFileSync(templatePath, 'utf8');

  // Replace the placeholder with the actual verification URL
  htmlContent = htmlContent.replace('{{verificationUrl}}', verificationUrl);

  const mailOptions = {
    from: '"LiftLog" <lftlogapp@gmail.com>',
    to,
    subject: 'Verify Your Email Address',
    html: htmlContent,
  };

  await transporter.sendMail(mailOptions);
};

module.exports = { sendVerificationEmail };
