 // backend/routes/videos.js
const express = require('express');
const router = express.Router();
const multer = require('multer');
const { createClient } = require('@supabase/supabase-js');
const ExerciseVideo = require('../models/ExerciseVideo'); // adjust if model path differs
const { verifyToken } = require('../middleware/auth'); // adjust to your auth middleware

// init supabase
const SUPABASE_URL = process.env.SUPABASE_URL;
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const BUCKET = process.env.SUPABASE_BUCKET || 'video';

if (!SUPABASE_URL || !SERVICE_KEY) {
  console.error('Supabase env missing: SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
}
const supabase = createClient(SUPABASE_URL, SERVICE_KEY);

// Add a startup log so we can confirm the deployed file is used
console.log('routes/videos.js loaded (Option B) - memory->Supabase upload route');

const storage = multer.memoryStorage();
const upload = multer({
  storage,
  limits: { fileSize: 500 * 1024 * 1024 } // 500MB
});

// POST /api/videos
router.post('/', verifyToken, upload.single('video'), async (req, res) => {
  try {
    console.log('Incoming request: POST /api/videos from', req.ip);
    console.log('DEBUG content-type:', req.headers['content-type']);
    console.log('DEBUG body keys:', Object.keys(req.body || {}));
    console.log('DEBUG body content:', req.body);
    console.log('DEBUG file info:', req.file ? {
      originalname: req.file.originalname,
      mimetype: req.file.mimetype,
      size: req.file.buffer?.length
    } : 'NO FILE RECEIVED');

    if (!req.file || !req.file.buffer) {
      console.error('No file or buffer present');
      return res.status(400).json({ error: 'No video file uploaded (field name must be "video")' });
    }

    const { title, exerciseType, description, difficulty, duration, tags, isPublic } = req.body;
    const parsedIsPublic = isPublic == null ? true : (isPublic === 'true' || isPublic === true);
    const parsedTitle = title ? String(title).trim() : '';
    const parsedExerciseType = exerciseType ? String(exerciseType).trim() : 'strength'; // default

    if (!parsedTitle) {
      return res.status(400).json({ error: 'title required' });
    }
    if (!req.user || !req.user._id) {
      return res.status(401).json({ error: 'Unauthorized: no user' });
    }

    const origName = req.file.originalname || 'video.mp4';
    const safeName = `${Date.now()}-${Math.floor(Math.random()*1e9)}-${origName}`;
    const path = safeName; // optionally prefix: `videos/${safeName}`

    const contentType = req.file.mimetype || 'video/mp4'
    // upload to supabase
    const { data, error: uploadError } = await supabase
      .storage
      .from(BUCKET)
      .upload(path, req.file.buffer, { contentType });

    if (uploadError) {
      console.error('Supabase upload error:', uploadError);
      return res.status(500).json({ error: 'upload_failed', message: uploadError.message || uploadError });
    }

    const videoUrl = `${SUPABASE_URL.replace(/\/$/, '')}/storage/v1/object/public/${encodeURIComponent(BUCKET)}/${encodeURIComponent(path)}`;

    const parsedTags = tags ? (Array.isArray(tags) ? tags : String(tags).split(',').map(t=>t.trim()).filter(Boolean)) : [];

    const doc = new ExerciseVideo({
      title: title.trim(),
      description: description || '',
      trainer: req.user._id,
      videoUrl,
      videoPath: path,
      exerciseType,
      difficulty: difficulty || 'beginner',
      duration: duration ? Number(duration) : 0,
      tags: parsedTags,
      isPublic: parsedIsPublic
    });

    await doc.save();
    console.log('Video saved to DB:', doc._id);

    return res.status(201).json({ message: 'Video uploaded', video: doc });
  } catch (err) {
    console.error('videos upload error:', err && err.stack ? err.stack : err);
    return res.status(500).json({ error: 'Video upload failed', message: err.message || String(err) });
  }
});

// GET /api/videos/trainer - Get videos uploaded by the current trainer
router.get('/trainer', verifyToken, async (req, res) => {
  try {
    if (!req.user || !req.user._id) {
      return res.status(401).json({ error: 'Unauthorized: no user' });
    }

    const videos = await ExerciseVideo.find({ trainer: req.user._id }).sort({ createdAt: -1 });
    console.log(`Found ${videos.length} videos for trainer ${req.user._id}`);

    return res.json({ videos });
  } catch (err) {
    console.error('videos trainer get error:', err && err.stack ? err.stack : err);
    return res.status(500).json({ error: 'Failed to fetch trainer videos', message: err.message || String(err) });
  }
});

// GET /api/videos - Get public videos for members
router.get('/', verifyToken, async (req, res) => {
  try {
    const videos = await ExerciseVideo.find({ isPublic: true }).sort({ createdAt: -1 });
    console.log(`Found ${videos.length} public videos`);
    console.log('Returning videos:', videos.map(v => ({ id: v._id, videoUrl: v.videoUrl })));

    return res.json({ videos });
  } catch (err) {
    console.error('videos get error:', err && err.stack ? err.stack : err);
    return res.status(500).json({ error: 'Failed to fetch videos', message: err.message || String(err) });
  }
});

// DELETE /api/videos/:id - Delete a video (trainer only)
router.delete('/:id', verifyToken, async (req, res) => {
  try {
    const videoId = req.params.id;
    if (!req.user || !req.user._id) {
      return res.status(401).json({ error: 'Unauthorized: no user' });
    }

    const video = await ExerciseVideo.findById(videoId);
    if (!video) {
      return res.status(404).json({ error: 'Video not found' });
    }

    // Check if the user is the trainer who uploaded the video
    if (video.trainer.toString() !== req.user._id.toString()) {
      return res.status(403).json({ error: 'Forbidden: You can only delete your own videos' });
    }

    // Delete from Supabase storage
    const { error: deleteError } = await supabase
      .storage
      .from(BUCKET)
      .remove([video.videoPath]);

    if (deleteError) {
      console.error('Supabase delete error:', deleteError);
      // Continue with DB deletion even if storage deletion fails
    }

    // Delete from database
    await ExerciseVideo.findByIdAndDelete(videoId);
    console.log('Video deleted:', videoId);

    return res.json({ message: 'Video deleted successfully' });
  } catch (err) {
    console.error('videos delete error:', err && err.stack ? err.stack : err);
    return res.status(500).json({ error: 'Failed to delete video', message: err.message || String(err) });
  }
});

module.exports = router;
