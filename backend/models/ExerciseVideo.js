const mongoose = require('mongoose');

const ExerciseVideoSchema = new mongoose.Schema({
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
  trainer: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  videoUrl: {
    type: String,
    required: true
  },
  thumbnailUrl: {
    type: String
  },
  exerciseType: {
    type: String,
    enum: [
      'strength', 
      'cardio', 
      'flexibility', 
      'bodyweight', 
      'weightlifting'
    ],
    required: true
  },
  difficulty: {
    type: String,
    enum: ['beginner', 'intermediate', 'advanced'],
    default: 'beginner'
  },
  duration: {
    type: Number, // Duration in seconds
    min: 0
  },
  tags: [{
    type: String,
    trim: true
  }],
  isPublic: {
    type: Boolean,
    default: false
  }
}, {
  timestamps: true
});

const ExerciseVideo = mongoose.model('ExerciseVideo', ExerciseVideoSchema);

module.exports = ExerciseVideo;