const dotenv = require('dotenv');

// Global setup for test environment
module.exports = async () => {
  // Load environment variables for testing
  dotenv.config({ path: '.env.test' });

  // Any global setup tasks can be added here
  console.log('Global test setup completed');

  // You can add more global configurations like:
  // - Setting up global mocks
  // - Initializing global test utilities
  // - Configuring global test environment variables
};