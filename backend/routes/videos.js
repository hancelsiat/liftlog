const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const ExerciseVideo = require('../models/ExerciseVideo');
const { verifyToken, checkRole } = require('../middleware/auth');

// Configure multer for video upload
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const uploadDir = path.join(__dirname, '../uploads/videos');
    
    // Create directory if it doesn't exist
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true });
    }
    
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, `${file.fieldname}-${uniqueSuffix}${path.extname(file.originalname)}`);
  }
});

// File filter for video uploads
const videoFilter = (req, file, cb) => {
  const allowedTypes = ['video/mp4', 'video/mpeg', 'video/quicktime'];
  
  if (allowedTypes.includes(file.mimetype)) {
    cb(null, true);
  } else {
    cb(new Error('Invalid file type. Only MP4, MPEG, and QuickTime videos are allowed.'), false);
  }
};

const upload = multer({ 
  storage: storage,
  fileFilter: videoFilter,
  limits: { 
    fileSize: 50 * 1024 * 1024 // 50MB file size limit
  }
});

// Upload a new exercise video (Trainer only)
router.post('/', 
  verifyToken, 
  checkRole(['trainer']), 
  upload.single('video'), 
  async (req, res) => {
    try {
      if (!req.file) {
        return res.status(400).json({ error: 'No video file uploaded' });
      }

      const { 
        title, 
        description, 
        exerciseType, 
        difficulty, 
        duration,
        tags,
        isPublic 
      } = req.body;

      const videoUrl = `/uploads/videos/${req.file.filename}`;

      const exerciseVideo = new ExerciseVideo({
        title,
        description,
        trainer: req.user._id,
        videoUrl,
        exerciseType,
        difficulty: difficulty || 'beginner',
        duration: parseInt(duration) || 0,
        tags: tags ? tags.split(',').map(tag => tag.trim()) : [],
        isPublic: isPublic === 'true'
      });

      await exerciseVideo.save();

      res.status(201).json({
        message: 'Video uploaded successfully',
        video: exerciseVideo
      });
    } catch (error) {
      console.error('Video upload error:', error);
      res.status(500).json({ error: 'Failed to upload video' });
    }
});

// Get all videos (public or owned by trainer)
router.get('/', verifyToken, async (req, res) => {
  try {
    const { 
      page = 1, 
      limit = 10, 
      exerciseType, 
      difficulty 
    } = req.query;

    const query = {
      $or: [
        { isPublic: true },
        { trainer: req.user._id }
      ]
    };

    if (exerciseType) query.exerciseType = exerciseType;
    if (difficulty) query.difficulty = difficulty;

    const videos = await ExerciseVideo.find(query)
      .populate('trainer', 'username')
      .limit(Number(limit))
      .skip((page - 1) * limit)
      .sort({ createdAt: -1 });

    const total = await ExerciseVideo.countDocuments(query);

    res.json({
      videos,
      totalVideos: total,
      currentPage: Number(page),
      totalPages: Math.ceil(total / limit)
    });
  } catch (error) {
    res.status(500).json({ error: 'Failed to retrieve videos' });
  }
});

// Get a specific video
router.get('/:id', verifyToken, async (req, res) => {
  try {
    const video = await ExerciseVideo.findById(req.params.id).populate('trainer', 'username');

    if (!video) {
      return res.status(404).json({ error: 'Video not found' });
    }

    // Check if video is public or owned by the user
    if (!video.isPublic && 
        video.trainer._id.toString() !== req.user._id.toString() && 
        req.user.role !== 'trainer') {
      return res.status(403).json({ error: 'Unauthorized to view this video' });
    }

    res.json(video);
  } catch (error) {
    res.status(500).json({ error: 'Failed to retrieve video' });
  }
});

// Update a video (Trainer only)
router.patch('/:id', 
  verifyToken, 
  checkRole(['trainer']), 
  async (req, res) => {
    try {
      const { 
        title, 
        description, 
        exerciseType, 
        difficulty, 
        duration,
        tags,
        isPublic 
      } = req.body;

      const video = await ExerciseVideo.findById(req.params.id);

      if (!video) {
        return res.status(404).json({ error: 'Video not found' });
      }

      // Ensure trainer can only update their own videos
      if (video.trainer.toString() !== req.user._id.toString()) {
        return res.status(403).json({ error: 'Unauthorized to update this video' });
      }

      video.title = title || video.title;
      video.description = description || video.description;
      video.exerciseType = exerciseType || video.exerciseType;
      video.difficulty = difficulty || video.difficulty;
      video.duration = duration ? parseInt(duration) : video.duration;
      video.tags = tags ? tags.split(',').map(tag => tag.trim()) : video.tags;
      video.isPublic = isPublic !== undefined ? isPublic === 'true' : video.isPublic;

      await video.save();

      res.json({
        message: 'Video updated successfully',
        video
      });
    } catch (error) {
      res.status(500).json({ error: 'Failed to update video' });
    }
});

// Delete a video (Trainer only)
router.delete('/:id', 
  verifyToken, 
  checkRole(['trainer']), 
  async (req, res) => {
    try {
      const video = await ExerciseVideo.findById(req.params.id);

      if (!video) {
        return res.status(404).json({ error: 'Video not found' });
      }

      // Ensure trainer can only delete their own videos
      if (video.trainer.toString() !== req.user._id.toString()) {
        return res.status(403).json({ error: 'Unauthorized to delete this video' });
      }

      // Delete video file from filesystem
      const videoPath = path.join(__dirname, `../uploads/videos/${path.basename(video.videoUrl)}`);
      if (fs.existsSync(videoPath)) {
        fs.unlinkSync(videoPath);
      }

      await video.remove();

      res.json({ message: 'Video deleted successfully' });
    } catch (error) {
      res.status(500).json({ error: 'Failed to delete video' });
    }
});

// Get trainer's uploaded videos
router.get('/trainer', verifyToken, checkRole(['all']), async (req, res) => {
  try {
    const { page = 1, limit = 10 } = req.query;

    const videos = await ExerciseVideo.find({ trainer: req.user._id })
      .populate('trainer', 'username')
      .limit(Number(limit))
      .skip((page - 1) * limit)
      .sort({ createdAt: -1 });

    const total = await ExerciseVideo.countDocuments({ trainer: req.user._id });

    res.json({
      videos,
      totalVideos: total,
      currentPage: Number(page),
      totalPages: Math.ceil(total / limit)
    });
  } catch (error) {
    res.status(500).json({ error: 'Failed to retrieve trainer videos' });
  }
});

module.exports = router;

