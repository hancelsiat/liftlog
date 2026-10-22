
const mongoose = require('mongoose');

const ExerciseSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
    trim: true
  },
  sets: {
    type: Number,
    required: true,
    min: 1
  },
  reps: {
    type: Number,
    required: true,
    min: 1
  },
  weight: {
    type: Number,
    default: 0
  },
  notes: {
    type: String,
    trim: true,
    maxlength: 500
  }
});

const WorkoutSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User'
  },
  trainer: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User'
  },
  date: {
    type: Date,
    default: Date.now
  },
  title: {
    type: String,
    required: true,
    trim: true
  },
  description: {
    type: String,
    trim: true,
    maxlength: 500
  },
  exercises: [ExerciseSchema],
  duration: {
    type: Number, // Duration in minutes
    min: 0
  },
  caloriesBurned: {
    type: Number,
    min: 0
  },
  intensity: {
    type: String,
    enum: ['low', 'moderate', 'high'],
    default: 'moderate'
  },
  category: {
    type: String,
    enum: ['strength', 'cardio', 'flexibility', 'mixed'],
    default: 'mixed'
  },
  isPublic: {
    type: Boolean,
    default: false
  },
  isTemplate: {
    type: Boolean,
    default: false
  },
  assignedTo: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User'
  },
  // For assigned copies: the trainer template this workout was copied from
  sourceTemplate: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Workout'
  },
  completedAt: {
    type: Date
  },
  notes: {
    type: String,
    trim: true,
    maxlength: 1000
  },
  isDeleted: {
    type: Boolean,
    default: false
  },
  deletionReason: {
    type: String,
    trim: true,
    maxlength: 500
  },
  deletedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User'
  },
  // Who removed it: the trainer who owns the template or an admin (moderation).
  // Older removals without this field were made by an admin.
  deletedByRole: {
    type: String,
    enum: ['trainer', 'admin']
  },
  deletedAt: {
    type: Date
  },
  // Set when the trainer deletes it permanently from "Recently deleted".
  // The record stays (hidden from the trainer) so admins keep the audit trail.
  purgedAt: {
    type: Date
  },
  // Last restore: the trainer restores their own deletions, an admin
  // restores moderation removals.
  restoredAt: {
    type: Date
  },
  restoredBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User'
  },
  restoredByRole: {
    type: String,
    enum: ['trainer', 'admin']
  }
}, {
  timestamps: true
});

// Performance tracking method
WorkoutSchema.methods.calculatePerformance = function() {
  return this.exercises.reduce((total, exercise) => {
    return total + (exercise.sets * exercise.reps * exercise.weight);
  }, 0);
};

const Workout = mongoose.model('Workout', WorkoutSchema);

module.exports = Workout;
