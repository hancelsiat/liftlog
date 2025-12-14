const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const crypto = require('crypto');

const UserSchema = new mongoose.Schema({
  username: {
    type: String,
    required: true,
    unique: true,
    trim: true,
    minlength: 3
  },
  email: {
    type: String,
    required: true,
    unique: true,
    trim: true,
    lowercase: true
  },
  password: {
    type: String,
    required: true,
    minlength: 6
  },
  role: {
    type: String,
    enum: ['member', 'trainer', 'admin'],
    default: 'member'
  },
  isEmailVerified: {
    type: Boolean,
    default: false
  },
  emailVerificationToken: {
    type: String,
    default: null
  },
  emailVerificationExpires: {
    type: Date,
    default: null
  },
  isApproved: {
    type: Boolean,
    default: true // Members are auto-approved, trainers need admin approval
  },
  membershipStart: {
    type: Date,
    default: Date.now
  },
  membershipExpiration: {
    type: Date,
    required: true
  },
  profile: {
    firstName: String,
    lastName: String,
    age: Number,
    weight: Number,
    height: Number
  }
}, {
  timestamps: true
});

// Password hashing middleware
UserSchema.pre('save', async function(next) {
  if (this.isModified('password')) {
    this.password = await bcrypt.hash(this.password, 10);
  }
  next();
});

// Method to check password
UserSchema.methods.comparePassword = async function(candidatePassword) {
  return bcrypt.compare(candidatePassword, this.password);
};

// Check if membership is active
UserSchema.methods.isMembershipActive = function() {
  return new Date() <= this.membershipExpiration;
};

// Generate email verification token
UserSchema.methods.generateEmailVerificationToken = function() {
  const token = crypto.randomBytes(32).toString('hex');
  this.emailVerificationToken = crypto.createHash('sha256').update(token).digest('hex');
  this.emailVerificationExpires = Date.now() + 24 * 60 * 60 * 1000; // 24 hours
  return token;
};

// Check if user can access the system
UserSchema.methods.canAccess = function() {
  // Members can access immediately
  if (this.role === 'member') return true;
  
  // Admins can access immediately
  if (this.role === 'admin') return true;
  
  // Trainers need email verification and admin approval
  if (this.role === 'trainer') {
    return this.isEmailVerified && this.isApproved;
  }
  
  return false;
};

const User = mongoose.model('User', UserSchema);
module.exports = User;