const mongoose = require('mongoose');
require('dotenv').config();

// Global setup for test environment
module.exports = async () => {
  // Configure MongoDB connection for testing
  const testMongoUri = process.env.MONGODB_TEST_URI || 'mongodb://localhost:27017/liftlog_test';
  
  try {
    await mongoose.connect(testMongoUri, {
      useNewUrlParser: true,
      useUnifiedTopology: true,
    });
    console.log('Connected to test database');
  } catch (error) {
    console.error('Failed to connect to test database:', error);
    process.exit(1);
  }
};