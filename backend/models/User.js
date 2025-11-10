const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

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

const User = mongoose.model('User', UserSchema);
module.exports = User;