const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const mongoose = require('mongoose');
const { GridFSBucket } = require('mongodb');
const { pipeline } = require('stream/promises');
const { google } = require('googleapis');
const ExerciseVideo = require('../models/ExerciseVideo');
const { verifyToken, checkRole } = require('../middleware/auth');

// Configure multer for memory storage
const storage = multer.memoryStorage();

const allowedMimes = new Set([
  'video/mp4','video/mpeg','video/quicktime','video/webm','video/ogg',
  'video/x-matroska','video/x-msvideo','application/octet-stream'
]);
const extAllowed = new Set(['mp4','mov','webm','ogg','mkv','avi','mpeg','mpg']);

const videoFilter = (req, file, cb) => {
  try {
    // Defensive — file may be undefined
    if (!file) {
      console.error('videoFilter: no file object present on request');
      return cb(new multer.MulterError('LIMIT_FIELD_VALUE', 'No file received'));
    }

    const originalname = file.originalname || '<no-originalname>';
    const mimetype = file.mimetype || '<no-mimetype>';
    console.log('videoFilter debug - originalname:', originalname);
    console.log('videoFilter debug - mimetype:', mimetype);
    console.log('videoFilter debug - req content-type:', req.headers['content-type']);

    // Accept by mimetype first
    if (allowedMimes.has(mimetype)) return cb(null, true);

    // Fallback: accept by extension
    const ext = originalname.split('.').pop().toLowerCase();
    if (ext && extAllowed.has(ext)) {
      console.warn('videoFilter: accepting by file extension fallback:', ext);
      return cb(null, true);
    }

    const err = new multer.MulterError('LIMIT_UNEXPECTED_FILE', 'video');
    err.message = 'Invalid file type. Allowed: mp4, mov, webm, ogg, mkv, avi, mpeg';
    console.error('videoFilter rejecting upload:', err.message);
    return cb(err);
  } catch (err) {
    console.error('videoFilter unexpected error:', err && err.stack ? err.stack : err);
    return cb(new Error('videoFilter failure'));
  }
};

const upload = multer({
  storage: storage,
  fileFilter: videoFilter,
  limits: {
    fileSize: 200 * 1024 * 1024 // 200MB file size limit
  }
});

// Helper function to upload to Supabase Storage
async function uploadToSupabase(req, fileBuffer, fileName, contentType) {
  const supabase = req.app.locals.supabase;
  const bucketName = process.env.SUPABASE_BUCKET_NAME || 'videos';

  const { data, error } = await supabase.storage
    .from(bucketName)
    .upload(fileName, fileBuffer, {
      contentType: contentType,
      upsert: false
    });

  if (error) {
    throw new Error('Supabase upload failed: ' + error.message);
  }

  // Get public URL
  const { data: urlData } = supabase.storage
    .from(bucketName)
    .getPublicUrl(data.path);

  return { path: data.path, url: urlData.publicUrl };
}

// Upload a new exercise video (Trainer only)
router.post('/',
  verifyToken,
  checkRole(['trainer']),
  (req, res, next) => {
    upload.single('video')(req, res, (err) => {
      if (err) {
        console.error('Multer error during upload:', err);
        if (err.code === 'LIMIT_FILE_SIZE') {
          return res.status(400).json({ error: 'File too large. Max size is 200MB.' });
        }
        if (err.code === 'LIMIT_UNEXPECTED_FILE') {
          return res.status(400).json({ error: err.message });
        }
        return res.status(400).json({ error: err.message || 'File upload error' });
      }
      next();
    });
  },
  async (req, res) => {
    try {
      if (!req.file) return res.status(400).json({ error: 'No video file uploaded (field name must be "video")' });

      const { title, exerciseType, description, difficulty, duration, tags, isPublic } = req.body;

      // early validation with clear errors
      if (!title || !title.trim()) return res.status(400).json({ error: 'title is required' });
      if (!exerciseType) return res.status(400).json({ error: 'exerciseType is required' });

      // convert tags if sent as JSON string or csv
      let parsedTags = [];
      if (tags) {
        try { parsedTags = JSON.parse(tags); }
        catch (_) { parsedTags = String(tags).split(',').map(t => t.trim()).filter(Boolean); }
      }

      // ensure auth provided req.user
      if (!req.user || !req.user._id) {
        console.error('Auth error: req.user is missing', req.user);
        return res.status(401).json({ error: 'Unauthorized: no user found' });
      }

      // Upload file to Supabase
      console.log('Starting Supabase upload for file:', req.file.originalname, 'size:', req.file.size);

      const fileName = `${Date.now()}-${Math.floor(Math.random() * 1e9)}-${req.file.originalname}`;
      const uploadResult = await uploadToSupabase(req, req.file.buffer, fileName, req.file.mimetype);

      console.log('Supabase upload completed successfully, path:', uploadResult.path);

      const doc = new ExerciseVideo({
        title: title.trim(),
        description: description ? String(description).trim() : '',
        trainer: req.user._id,
        videoUrl: uploadResult.url,
        videoPath: uploadResult.path,
        exerciseType,
        difficulty: difficulty || 'beginner',
        duration: duration ? parseInt(duration, 10) : 0,
        tags: parsedTags,
        isPublic: isPublic === 'true'
      });

      await doc.save();

      res.status(201).json({
        message: 'Video uploaded successfully',
        video: {
          ...doc.toObject(),
          videoUrl: `/api/videos/${doc._id}/stream`
        }
      });
    } catch (error) {
      console.error('Video upload error (save/other):', error);
      console.error('Error stack:', error.stack);

      // Clean up Supabase file if it was uploaded but document save failed
      if (uploadResult && uploadResult.path) {
        try {
          const supabase = req.app.locals.supabase;
          const bucketName = process.env.SUPABASE_BUCKET_NAME || 'videos';
          await supabase.storage.from(bucketName).remove([uploadResult.path]);
          console.log('Cleaned up Supabase file due to document save failure');
        } catch (cleanupError) {
          console.error('Failed to cleanup Supabase file:', cleanupError);
        }
      }

      if (error.name === 'ValidationError') {
        const details = Object.values(error.errors).map(e => e.message);
        return res.status(400).json({ error: 'Validation failed', details });
      }

      // Provide more specific error messages
      let errorMessage = 'Something broke!';
      if (error.message.includes('Supabase upload failed')) {
        errorMessage = 'File storage failed';
      } else if (error.message) {
        errorMessage = error.message;
      }

      return res.status(500).json({ error: 'Video upload failed: ' + errorMessage });
    }
  }
);

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

    // Add videoUrl to each video
    const videosWithUrl = videos.map(video => ({
      ...video.toObject(),
      videoUrl: video.videoUrl || `/api/videos/${video._id}/stream`
    }));

    const total = await ExerciseVideo.countDocuments(query);

    res.json({
      videos: videosWithUrl,
      totalVideos: total,
      currentPage: Number(page),
      totalPages: Math.ceil(total / limit)
    });
  } catch (error) {
    console.error('Error retrieving videos:', error);
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
      let parsedTags = video.tags;
      if (tags) {
        try {
          parsedTags = JSON.parse(tags);
        } catch (e) {
          parsedTags = tags.split(',').map(tag => tag.trim());
        }
      }
      video.tags = parsedTags;
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

      // Delete video file from Supabase if it exists
      if (video.videoPath) {
        const supabase = req.app.locals.supabase;
        const bucketName = process.env.SUPABASE_BUCKET_NAME || 'videos';
        await supabase.storage.from(bucketName).remove([video.videoPath]);
      }

      await video.remove();

      res.json({ message: 'Video deleted successfully' });
    } catch (error) {
      console.error('Video delete error:', error);
      res.status(500).json({ error: 'Failed to delete video' });
    }
});

// Get trainer's uploaded videos
router.get('/trainer', verifyToken, checkRole(['trainer']), async (req, res) => {
  try {
    const { page = 1, limit = 10 } = req.query;

    const videos = await ExerciseVideo.find({ trainer: req.user._id })
      .populate('trainer', 'username')
      .limit(Number(limit))
      .skip((page - 1) * limit)
      .sort({ createdAt: -1 });

    // Add videoUrl to each video
    const videosWithUrl = videos.map(video => ({
      ...video.toObject(),
      videoUrl: video.videoUrl || `/api/videos/${video._id}/stream`
    }));

    const total = await ExerciseVideo.countDocuments({ trainer: req.user._id });

    res.json({
      videos: videosWithUrl,
      totalVideos: total,
      currentPage: Number(page),
      totalPages: Math.ceil(total / limit)
    });
  } catch (error) {
    console.error('Error retrieving trainer videos:', error);
    res.status(500).json({ error: 'Failed to retrieve trainer videos' });
  }
});

// Serve video file from Supabase or redirect to videoUrl
router.get('/:id/stream', verifyToken, async (req, res) => {
  try {
    const video = await ExerciseVideo.findById(req.params.id);

    if (!video) {
      return res.status(404).json({ error: 'Video not found' });
    }

    // Check if user can access this video (public or owned by trainer)
    if (!video.isPublic && video.trainer.toString() !== req.user._id.toString()) {
      return res.status(403).json({ error: 'Unauthorized to access this video' });
    }

    // If video has a videoUrl (Supabase), redirect to it
    if (video.videoUrl) {
      return res.redirect(video.videoUrl);
    }

    // Fallback to GridFS if no videoUrl (legacy videos)
    const bucket = getGridFSBucket(req);

    // Get file info
    const files = await bucket.find({ _id: video.videoFileId }).toArray();
    if (files.length === 0) {
      return res.status(404).json({ error: 'Video file not found' });
    }

    const file = files[0];

    // Set headers for video streaming
    res.set({
      'Content-Type': file.contentType,
      'Content-Length': file.length,
      'Accept-Ranges': 'bytes'
    });

    // Handle range requests for video seeking
    const range = req.headers.range;
    if (range) {
      const parts = range.replace(/bytes=/, '').split('-');
      const start = parseInt(parts[0], 10);
      const end = parts[1] ? parseInt(parts[1], 10) : file.length - 1;
      const chunkSize = (end - start) + 1;

      res.status(206).set({
        'Content-Range': `bytes ${start}-${end}/${file.length}`,
        'Content-Length': chunkSize
      });

      const downloadStream = bucket.openDownloadStream(file._id, { start, end: end + 1 });
      downloadStream.pipe(res);
    } else {
      const downloadStream = bucket.openDownloadStream(file._id);
      downloadStream.pipe(res);
    }
  } catch (error) {
    console.error('Video streaming error:', error);
    res.status(500).json({ error: 'Failed to stream video' });
  }
});

const MAX_DRIVE_RETRIES = 2;

// Helper to fetch drive media with retries
async function fetchDriveMediaWithRetries(drive, fileId) {
  let lastErr = null;
  for (let attempt = 0; attempt <= MAX_DRIVE_RETRIES; attempt++) {
    if (attempt > 0) console.log(`[drive] retry attempt ${attempt} for fileId=${fileId}`);
    try {
      const res = await drive.files.get({ fileId, alt: 'media' }, { responseType: 'stream' });
      return res;
    } catch (err) {
      lastErr = err;
      console.warn('[drive] media fetch failed', { attempt, code: err.code || err.response?.status, message: err.message });
      await new Promise(r => setTimeout(r, 500 * (attempt + 1)));
    }
  }
  const e = new Error('Drive media fetch failed after retries');
  e.cause = lastErr;
  throw e;
}

async function uploadFromDriveToSupabase(req, { drive, fileId, accessToken, userId }) {
  // Validate inputs
  if (!fileId) throw new Error('missing fileId');
  if (!accessToken) throw new Error('missing accessToken');

  // 1) metadata
  let meta;
  try {
    const metaRes = await drive.files.get({ fileId, fields: 'id,name,mimeType,size' });
    meta = metaRes.data;
    console.log('[drive] metadata', { id: meta.id, name: meta.name, mimeType: meta.mimeType, size: meta.size });
  } catch (err) {
    console.error('[drive][meta] failed to fetch metadata', err && (err.stack || err.message));
    throw new Error('Drive metadata fetch failed: ' + (err.message || 'unknown'));
  }

  // 2) get media stream
  let media;
  try {
    media = await fetchDriveMediaWithRetries(drive, fileId);
    if (!media || !media.data) throw new Error('Drive returned no stream');
    console.log('[drive] got media stream');
  } catch (err) {
    console.error('[drive][media] failed', err && (err.stack || err.message));
    throw new Error('Drive media download failed: ' + (err.message || 'unknown'));
  }

  // 3) collect buffer from stream
  const chunks = [];
  return new Promise(async (resolve, reject) => {
    media.data.on('data', chunk => chunks.push(chunk));
    media.data.on('end', async () => {
      try {
        const buffer = Buffer.concat(chunks);
        console.log('[drive] collected buffer, size:', buffer.length);

        // Upload to Supabase
        const fileName = `${Date.now()}-${Math.floor(Math.random() * 1e9)}-${meta.name || `drive-${fileId}`}`;
        const uploadResult = await uploadToSupabase(req, buffer, fileName, meta.mimeType);

        console.log('[supabase] upload completed, path:', uploadResult.path);
        resolve(uploadResult);
      } catch (err) {
        console.error('[supabase] upload error:', err && (err.stack || err.message));
        reject(new Error('Supabase upload failed: ' + (err.message || 'unknown')));
      }
    });
    media.data.on('error', err => {
      console.error('[drive][stream] stream error', err && (err.stack || err.message));
      reject(new Error('Google Drive stream error: ' + (err.message || 'unknown')));
    });
  });
}

async function uploadFromDriveToGridFS({ drive, db, fileId, accessToken, userId }) {
  // Validate inputs
  if (!fileId) throw new Error('missing fileId');
  if (!accessToken) throw new Error('missing accessToken');

  // 1) metadata
  let meta;
  try {
    const metaRes = await drive.files.get({ fileId, fields: 'id,name,mimeType,size' });
    meta = metaRes.data;
    console.log('[drive] metadata', { id: meta.id, name: meta.name, mimeType: meta.mimeType, size: meta.size });
  } catch (err) {
    console.error('[drive][meta] failed to fetch metadata', err && (err.stack || err.message));
    throw new Error('Drive metadata fetch failed: ' + (err.message || 'unknown'));
  }

  // 2) get media stream
  let media;
  try {
    media = await fetchDriveMediaWithRetries(drive, fileId);
    if (!media || !media.data) throw new Error('Drive returned no stream');
    console.log('[drive] got media stream');
  } catch (err) {
    console.error('[drive][media] failed', err && (err.stack || err.message));
    throw new Error('Drive media download failed: ' + (err.message || 'unknown'));
  }

  // 3) stream to GridFS
  return new Promise(async (resolve, reject) => {
    try {
      const bucket = new GridFSBucket(db, { bucketName: 'videos' });
      const filename = meta.name || `drive-${fileId}`;
      console.log('[gridfs] opening upload stream', { filename });

      const uploadStream = bucket.openUploadStream(filename, {
        metadata: { source: 'google-drive', owner: userId || null, driveFileId: fileId },
        contentType: meta.mimeType
      });

      uploadStream.on('error', err => {
        console.error('[gridfs] uploadStream error', err && (err.stack || err.message));
        reject(new Error('GridFS uploadStream error: ' + (err.message || 'unknown')));
      });

      uploadStream.on('finish', () => {
        console.log('[gridfs] finish event: file saved', { gridfsId: uploadStream.id.toString() });
        resolve({ gridfsId: uploadStream.id, filename, size: meta.size });
      });

      media.data.on('error', err => {
        console.error('[drive][stream] stream error', err && (err.stack || err.message));
        reject(new Error('Google Drive stream error: ' + (err.message || 'unknown')));
      });

      await pipeline(media.data, uploadStream);
    } catch (err) {
      console.error('[pipeline] failed', err && (err.stack || err.message));
      reject(new Error('Pipeline failed: ' + (err.message || 'unknown')));
    }
  });
}

// Route: POST /videos/upload-drive
// expects JSON { fileId, accessToken, userId, title, description, exerciseType, difficulty, duration, tags, isPublic }
router.post('/upload-drive',
  verifyToken,
  checkRole(['trainer']),
  async (req, res) => {
  const startedAt = Date.now();
  try {
    const {
      fileId,
      accessToken,
      userId,
      title,
      description,
      exerciseType,
      difficulty,
      duration,
      tags,
      isPublic
    } = req.body;

    if (!fileId || !accessToken) return res.status(400).json({ error: 'fileId and accessToken required' });
    if (!title) return res.status(400).json({ error: 'title is required' });

    // get mongo db instance injected from server.js
    const db = req.app.locals.mongoDb;
    if (!db) {
      console.error('[upload] missing db in app.locals');
      return res.status(500).json({ error: 'Server misconfiguration: missing DB' });
    }

    // build an oauth2 client with the given token
    const oauth2Client = new google.auth.OAuth2();
    oauth2Client.setCredentials({ access_token: accessToken });
    const drive = google.drive({ version: 'v3', auth: oauth2Client });

    console.log('[req] upload request', { fileId, userId, title });

    const result = await uploadFromDriveToSupabase(req, { drive, fileId, accessToken, userId });

    console.log('[req] upload success', { fileId, path: result.path, tookMs: Date.now() - startedAt });

    // Create proper ExerciseVideo document
    let parsedTags = [];
    if (tags) {
      try {
        parsedTags = JSON.parse(tags);
      } catch (e) {
        parsedTags = tags.split(',').map(tag => tag.trim());
      }
    }

    const exerciseVideo = new ExerciseVideo({
      title,
      description: description || '',
      trainer: req.user._id,
      videoUrl: result.url,
      videoPath: result.path,
      exerciseType: exerciseType || 'strength',
      difficulty: difficulty || 'beginner',
      duration: parseInt(duration) || 0,
      tags: parsedTags,
      isPublic: isPublic === 'true' || isPublic === true
    });

    await exerciseVideo.save();

    console.log('[meta] created ExerciseVideo document', { id: exerciseVideo._id });

    return res.status(201).json({
      message: 'Video uploaded successfully from Google Drive',
      video: {
        ...exerciseVideo.toObject(),
        videoUrl: exerciseVideo.videoUrl || `/api/videos/${exerciseVideo._id}/stream`
      }
    });
  } catch (err) {
    console.error('[req] UPLOAD FAILED', { message: err.message, stack: err.stack?.split('\n').slice(0,6).join('\n') });
    // return helpful details (but not secrets)
    return res.status(500).json({ error: 'Upload failed', details: err.message });
  }
});

module.exports = router;

