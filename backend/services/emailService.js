const nodemailer = require('nodemailer');

const transporter = nodemailer.createTransport({
  host: 'smtp.sender.net',
  port: 587,
  secure: false, // true for 465, false for other ports
  auth: {
    user: 'sender', // Your Sender username
    pass: process.env.SENDER_API_KEY, // Your Sender API key
  },
});

const sendVerificationEmail = async (to, token) => {
  const verificationUrl = `https://liftlog-7.onrender.com/api/auth/verify-email/${token}`;

  const mailOptions = {
    from: '"LiftLog" <no-reply@liftlog.app>',
    to,
    subject: 'Verify Your Email Address',
    html: `
      <p>Please click the link below to verify your email address:</p>
      <a href="${verificationUrl}">${verificationUrl}</a>
    `,
  };

  await transporter.sendMail(mailOptions);
};

module.exports = { sendVerificationEmail };
