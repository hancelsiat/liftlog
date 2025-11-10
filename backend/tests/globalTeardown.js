const mongoose = require('mongoose');

// Global teardown for test environment
module.exports = async () => {
  try {
    // Disconnect from the MongoDB database
    await mongoose.connection.close();
    console.log('Disconnected from test database');
  } catch (error) {
    console.error('Error during test database teardown:', error);
    process.exit(1);
  }
};