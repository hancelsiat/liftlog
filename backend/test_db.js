
require('dotenv').config();
const mongoose = require('mongoose');

const testDbConnection = async () => {
  try {
    console.log('Attempting to connect to MongoDB...');
    await mongoose.connect(process.env.MONGODB_URI, {
      useNewUrlParser: true,
      useUnifiedTopology: true,
    });
    console.log('MongoDB connection successful!');
    mongoose.connection.close();
  } catch (error) {
    console.error('MongoDB connection failed:', error.message);
  }
};

testDbConnection();
