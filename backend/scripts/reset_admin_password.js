const mongoose = require('mongoose');
const User = require('../models/User');
require('dotenv').config();

const resetAdminPassword = async () => {
  try {
    // Connect to MongoDB
    await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/liftlog', {
      useNewUrlParser: true,
      useUnifiedTopology: true,
    });

    console.log('Connected to MongoDB');

    // Find admin account
    const admin = await User.findOne({ email: 'admin@gmail.com' });

    if (!admin) {
      console.log('❌ Admin account not found. Creating new admin account...');
      
      const newAdmin = new User({
        username: 'admin',
        email: 'admin@gmail.com',
        password: 'admin123',
        role: 'admin',
        isEmailVerified: true,
        isApproved: true,
        membershipExpiration: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000),
        profile: {
          firstName: 'System',
          lastName: 'Administrator'
        }
      });

      await newAdmin.save();
      console.log('✅ New admin account created successfully!');
    } else {
      // Reset password
      admin.password = 'admin123';
      admin.isEmailVerified = true;
      admin.isApproved = true;
      await admin.save();
      
      console.log('✅ Admin password reset successfully!');
    }

    console.log('-------------------------------------------');
    console.log('Email: admin@gmail.com');
    console.log('Password: admin123');
    console.log('-------------------------------------------');
    console.log('You can now login with these credentials.');

    process.exit(0);
  } catch (error) {
    console.error('Error resetting admin password:', error);
    process.exit(1);
  }
};

resetAdminPassword();
