const mongoose = require('mongoose');

const ProgressSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  bmi: {
    type: Number,
    required: true,
    min: 10,
    max: 50
  },
  caloriesIntake: {
    type: Number,
    required: true,
    min: 0
  },
  calorieDeficit: {
    type: Number,
    required: true
  },
  weight: {
    type: Number,
    min: 20,
    max: 300
  },
  bodyFatPercentage: {
    type: Number,
    min: 0,
    max: 100
  },
  muscleMass: {
    type: Number,
    min: 0
  },
  date: {
    type: Date,
    default: Date.now
  }
}, {
  timestamps: true
});

// Ensure only one progress entry per day per user
ProgressSchema.index({ user: 1, date: 1 }, { unique: true });

module.exports = mongoose.model('Progress', ProgressSchema);