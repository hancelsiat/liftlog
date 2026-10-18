const mongoose = require('mongoose');

// A member's request for an admin to reset their BMI / calorie tracking
// cooldown (e.g. after misclicking the update button).
const CooldownResetRequestSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  type: {
    type: String,
    enum: ['bmi', 'calories', 'both'],
    required: true
  },
  reason: {
    type: String,
    required: true,
    trim: true,
    minlength: 5,
    maxlength: 500
  },
  status: {
    type: String,
    enum: ['pending', 'approved', 'rejected'],
    default: 'pending'
  },
  adminNote: {
    type: String,
    trim: true,
    maxlength: 500
  },
  handledBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User'
  },
  handledAt: {
    type: Date
  }
}, {
  timestamps: true
});

CooldownResetRequestSchema.index({ status: 1, createdAt: -1 });
CooldownResetRequestSchema.index({ user: 1, createdAt: -1 });

module.exports = mongoose.model('CooldownResetRequest', CooldownResetRequestSchema);
