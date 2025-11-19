const mongoose = require('mongoose');

const exerciseVideoSchema = new mongoose.Schema({
  title: {
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
  videoUrl: {
    type: String,
    required: true
  },
  videoPath: {
    type: String,
    required: true
  },
  exerciseType: {
    type: String,
    required: true,
    enum: ['cardio', 'strength', 'flexibility', 'balance', 'sports', 'other']
  },
  difficulty: {
    type: String,
    enum: ['beginner', 'intermediate', 'advanced'],
    default: 'beginner'
  },
  duration: {
    type: Number, // in seconds
    default: 0
  },
  tags: [{
    type: String,
    trim: true
  }],
  isPublic: {
    type: Boolean,
    default: false
  },
  status: {
    type: String,
    enum: ['uploading', 'ready', 'failed'],
    default: 'ready'
  },
  errorDetails: {
    type: String,
    default: null
  },
  createdAt: {
    type: Date,
    default: Date.now
  },
  updatedAt: {
    type: Date,
    default: Date.now
  }
});

// Update the updatedAt field before saving
exerciseVideoSchema.pre('save', function(next) {
  this.updatedAt = Date.now();
  next();
});

module.exports = mongoose.model('ExerciseVideo', exerciseVideoSchema);
