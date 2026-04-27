
const mongoose = require('mongoose');

const WorkoutPlanSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
    trim: true
  },
  description: {
    type: String,
    trim: true
  },
  trainer: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  weeks: [{
    weekNumber: {
      type: Number,
      required: true
    },
    workouts: [{
      day: {
        type: String,
        enum: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'],
        required: true
      },
      workout: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Workout',
        required: true
      }
    }]
  }]
}, { timestamps: true });

const WorkoutPlan = mongoose.model('WorkoutPlan', WorkoutPlanSchema);
module.exports = WorkoutPlan;
