
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
  // Legal full name. Required for trainers at sign-up so the admin can
  // check it against the uploaded credential photo.
  fullName: {
    type: String,
    trim: true,
    maxlength: 100,
    default: ''
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
  clients: [{
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User'
  }],
  trainer: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    default: null
  },
  privateNotes: {
    type: String,
    default: ''
  },
  bio: {
    type: String,
    trim: true,
    maxlength: 500,
    default: ''
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
  // Forgot-password flow. All hidden from normal queries (select: false);
  // the auth routes opt in with .select('+field').
  // 1) A 6-digit OTP is emailed; only its hash is stored.
  passwordResetOtp: { type: String, default: null, select: false },
  passwordResetOtpExpires: { type: Date, default: null, select: false },
  passwordResetAttempts: { type: Number, default: 0, select: false },
  passwordResetLastSentAt: { type: Date, default: null, select: false },
  // 2) A correct OTP is swapped for a one-time token that allows the
  //    actual password change.
  passwordResetToken: { type: String, default: null, select: false },
  passwordResetTokenExpires: { type: Date, default: null, select: false },
  isApproved: {
    type: Boolean,
    default: true // Members are auto-approved, trainers need admin approval
  },
  profile: {
    firstName: String,
    lastName: String,
    age: Number,
    weight: Number,
    height: Number
    },
  credentialImageUrl: {
    type: String,
    default: ''
  },
  lastSeen: {
    type: Date,
    default: Date.now
  },
  blockedUsers: [{
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User'
  }]
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

// Generate email verification token
UserSchema.methods.generateEmailVerificationToken = function() {
  const token = crypto.randomBytes(32).toString('hex');
  this.emailVerificationToken = crypto.createHash('sha256').update(token).digest('hex');
  this.emailVerificationExpires = Date.now() + 24 * 60 * 60 * 1000; // 24 hours
  return token;
};

const sha256 = (value) => crypto.createHash('sha256').update(String(value)).digest('hex');

UserSchema.statics.PASSWORD_RESET_OTP_TTL_MS = 10 * 60 * 1000; // 10 minutes
UserSchema.statics.PASSWORD_RESET_MAX_ATTEMPTS = 5;
UserSchema.statics.PASSWORD_RESET_RESEND_MS = 60 * 1000; // 1 email per minute

// Creates a new 6-digit reset code (and cancels any earlier code or token).
// Returns the plain code so it can be emailed; only the hash is stored.
UserSchema.methods.generatePasswordResetOtp = function() {
  const otp = crypto.randomInt(0, 1000000).toString().padStart(6, '0');
  this.passwordResetOtp = sha256(otp);
  this.passwordResetOtpExpires = Date.now() + UserSchema.statics.PASSWORD_RESET_OTP_TTL_MS;
  this.passwordResetAttempts = 0;
  this.passwordResetLastSentAt = Date.now();
  this.passwordResetToken = null;
  this.passwordResetTokenExpires = null;
  return otp;
};

// Constant-time compare of a submitted code against the stored hash.
UserSchema.methods.checkPasswordResetOtp = function(otp) {
  if (!this.passwordResetOtp || !otp) return false;
  const a = Buffer.from(sha256(otp), 'hex');
  const b = Buffer.from(this.passwordResetOtp, 'hex');
  return a.length === b.length && crypto.timingSafeEqual(a, b);
};

// Swaps a verified OTP for a one-time token that allows the password change.
UserSchema.methods.generatePasswordResetToken = function() {
  const token = crypto.randomBytes(32).toString('hex');
  this.passwordResetToken = sha256(token);
  this.passwordResetTokenExpires = Date.now() + UserSchema.statics.PASSWORD_RESET_OTP_TTL_MS;
  this.passwordResetOtp = null;
  this.passwordResetOtpExpires = null;
  this.passwordResetAttempts = 0;
  return token;
};

UserSchema.methods.clearPasswordReset = function() {
  this.passwordResetOtp = null;
  this.passwordResetOtpExpires = null;
  this.passwordResetAttempts = 0;
  this.passwordResetToken = null;
  this.passwordResetTokenExpires = null;
};

UserSchema.statics.hashResetValue = sha256;

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
