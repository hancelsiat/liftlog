const mongoose = require('mongoose');
const User = require('../models/User');
require('dotenv').config();

const createDefaultAdmin = async () => {
  try {
    // Connect to MongoDB
    await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/liftlog', {
      useNewUrlParser: true,
      useUnifiedTopology: true,
    });

    console.log('Connected to MongoDB');

    // Check if admin already exists
    const existingAdmin = await User.findOne({ email: 'admin@gmail.com' });

    if (existingAdmin) {
      console.log('Admin account already exists');
      console.log('Email: admin@gmail.com');
      console.log('You can reset the password if needed');
      process.exit(0);
    }

    // Create default admin account
    const admin = new User({
      username: 'admin',
      email: 'admin@gmail.com',
      password: 'admin123',
      role: 'admin',
      isEmailVerified: true,
      isApproved: true,
      membershipExpiration: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000), // 1 year
      profile: {
        firstName: 'System',
        lastName: 'Administrator'
      }
    });

    await admin.save();

    console.log('✅ Default admin account created successfully!');
    console.log('-------------------------------------------');
    console.log('Email: admin@gmail.com');
    console.log('Password: admin123');
    console.log('-------------------------------------------');
    console.log('⚠️  IMPORTANT: Change the password after first login!');

    process.exit(0);
  } catch (error) {
    console.error('Error creating admin account:', error);
    process.exit(1);
  }
};

createDefaultAdmin();
