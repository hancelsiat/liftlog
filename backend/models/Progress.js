const mongoose = require('mongoose');

const ProgressSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  bmi: {
    type: Number,
    max: 300
  },
  caloriesIntake: {
    type: Number
  },
  calorieDeficit: {
    type: Number
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
  // Separate tracking for last update times
  lastBmiUpdate: {
    type: Date
  },
  lastCaloriesUpdate: {
    type: Date
  },
  date: {
    type: Date,
    default: Date.now
  }
}, {
  timestamps: true
});

// Index for efficient queries
ProgressSchema.index({ user: 1, createdAt: -1 });

// Method to check if BMI can be updated (7 days restriction)
ProgressSchema.methods.canUpdateBmi = function() {
  if (!this.lastBmiUpdate) return true;
  
  const now = new Date();
  const daysSinceLastUpdate = (now - this.lastBmiUpdate) / (1000 * 60 * 60 * 24);
  return daysSinceLastUpdate >= 7;
};

// Method to check if Calories can be updated (24 hours restriction)
ProgressSchema.methods.canUpdateCalories = function() {
  if (!this.lastCaloriesUpdate) return true;
  
  const now = new Date();
  const hoursSinceLastUpdate = (now - this.lastCaloriesUpdate) / (1000 * 60 * 60);
  return hoursSinceLastUpdate >= 24;
};

// Method to get days until next BMI update
ProgressSchema.methods.daysUntilNextBmiUpdate = function() {
  if (!this.lastBmiUpdate) return 0;
  
  const now = new Date();
  const daysSinceLastUpdate = (now - this.lastBmiUpdate) / (1000 * 60 * 60 * 24);
  return Math.max(0, Math.ceil(7 - daysSinceLastUpdate));
};

// Method to get hours until next Calories update
ProgressSchema.methods.hoursUntilNextCaloriesUpdate = function() {
  if (!this.lastCaloriesUpdate) return 0;
  
  const now = new Date();
  const hoursSinceLastUpdate = (now - this.lastCaloriesUpdate) / (1000 * 60 * 60);
  return Math.max(0, Math.ceil(24 - hoursSinceLastUpdate));
};

module.exports = mongoose.model('Progress', ProgressSchema);
