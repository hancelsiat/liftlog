
require('dotenv').config();
const { sendVerificationEmail } = require('./services/emailService');

const testEmail = async () => {
  try {
    console.log('Attempting to send a test verification email...');
    await sendVerificationEmail('test@example.com', 'test-token-123');
    console.log('Test email sent successfully! Please check the inbox of test@example.com.');
  } catch (error) {
    console.error('Failed to send the test email:', error);
  }
};

testEmail();
