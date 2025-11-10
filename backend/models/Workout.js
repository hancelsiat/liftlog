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
    ref: 'User',
    required: true
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
  notes: {
    type: String,
    trim: true,
    maxlength: 1000
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