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
  thumbnailUrl: {
    type: String,
    default: null
  },
  thumbnailPath: {
    type: String,
    default: null
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
  // Who removed it: the uploading trainer or an admin (moderation).
  // Older removals without this field were made by an admin.
  deletedByRole: {
    type: String,
    enum: ['trainer', 'admin']
  },
  deletedAt: {
    type: Date
  },
  // Set when the trainer deletes it permanently from "Recently deleted".
  // The files are erased; the record stays so admins keep the audit trail.
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
});


// Update the updatedAt field and normalize exerciseType before saving
exerciseVideoSchema.pre('save', function(next) {
  this.updatedAt = Date.now();
  // Normalize exerciseType to lowercase to handle case-insensitive input
  if (this.exerciseType) {
    this.exerciseType = this.exerciseType.toLowerCase();
  }
  next();
});

module.exports = mongoose.model('ExerciseVideo', exerciseVideoSchema);
