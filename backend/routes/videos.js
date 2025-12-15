const express = require('express');
const router = express.Router();
const multer = require('multer');
const { createClient } = require('@supabase/supabase-js');
const mime = require('mime-types');
const fs = require('fs');
const path = require('path');
const os = require('os');
const child_process = require('child_process');
const ffmpeg = require('fluent-ffmpeg');
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

// Helper function to generate thumbnail from video
async function generateThumbnail(videoBuffer) {
  return new Promise((resolve, reject) => {
    const tempVideoPath = path.join(os.tmpdir(), `video-${Date.now()}.mp4`);
    const tempThumbnailPath = path.join(os.tmpdir(), `thumb-${Date.now()}.jpg`);

    try {
      // Write video buffer to temp file
      fs.writeFileSync(tempVideoPath, videoBuffer);

      // Generate thumbnail at 1 second mark
      ffmpeg(tempVideoPath)
        .screenshots({
          timestamps: ['00:00:01.000'],
          filename: path.basename(tempThumbnailPath),
          folder: path.dirname(tempThumbnailPath),
          size: '1280x720'
        })
        .on('end', () => {
          try {
            // Read the generated thumbnail
            const thumbnailBuffer = fs.readFileSync(tempThumbnailPath);
            
            // Clean up temp files
            fs.unlinkSync(tempVideoPath);
            fs.unlinkSync(tempThumbnailPath);
            
            resolve(thumbnailBuffer);
          } catch (err) {
            console.error('Error reading thumbnail:', err);
            reject(err);
          }
        })
        .on('error', (err) => {
          console.error('FFmpeg error:', err);
          // Clean up temp files
          try {
            if (fs.existsSync(tempVideoPath)) fs.unlinkSync(tempVideoPath);
            if (fs.existsSync(tempThumbnailPath)) fs.unlinkSync(tempThumbnailPath);
          } catch (cleanupErr) {
            console.error('Cleanup error:', cleanupErr);
          }
          reject(err);
        });
    } catch (err) {
      console.error('Error in generateThumbnail:', err);
      reject(err);
    }
  });
}

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

    // Prepare safe names
    const origName = req.file.originalname || 'video.mp4';
    const cleanedName = origName.replace(/\s+/g, '_').replace(/[^a-zA-Z0-9\-_\.]/g, '');
    const safeName = `${Date.now()}-${Math.floor(Math.random()*1e9)}-${cleanedName}`;
    const finalPathKey = `videos/${safeName}`;

    // temp files
    const tmpDir = os.tmpdir();
    const tmpIn = path.join(tmpDir, `in-${safeName}`);
    const tmpOut = path.join(tmpDir, `out-${safeName}.mp4`);

    // write buffer to temp file
    fs.writeFileSync(tmpIn, req.file.buffer);

    // First try a fast remux (cheap, preserves quality)
    try {
      child_process.execFileSync('ffmpeg', ['-y', '-i', tmpIn, '-c', 'copy', '-movflags', '+faststart', tmpOut], { stdio: 'inherit', timeout: 120000 });
    } catch (e) {
      // if remux fails, fallback to full re-encode
      console.warn('Remux failed, doing full re-encode', e);
      child_process.execFileSync('ffmpeg', [
        '-y', '-i', tmpIn,
        '-c:v', 'libx264', '-profile:v', 'baseline', '-level', '3.0', '-pix_fmt', 'yuv420p',
        '-preset', 'fast', '-crf', '23',
        '-c:a', 'aac', '-b:a', '128k',
        '-movflags', '+faststart',
        tmpOut
      ], { stdio: 'inherit', timeout: 180000 });
    }

    // read fixed buffer and upload to Supabase
    const fixedBuffer = fs.readFileSync(tmpOut);
    const contentType = 'video/mp4'; // final file is mp4

    const { data: upData, error: upErr } = await supabase
      .storage
      .from(BUCKET)
      .upload(finalPathKey, fixedBuffer, { contentType, upsert: false });

    if (upErr) {
      console.error('Supabase upload error after reencode:', upErr);
      // cleanup
      try { fs.unlinkSync(tmpIn); fs.unlinkSync(tmpOut); } catch(e) {}
      return res.status(500).json({ error: 'upload_failed', message: upErr.message || upErr });
    }

    // build public url
    const videoUrl = `${SUPABASE_URL.replace(/\/$/, '')}/storage/v1/object/public/${BUCKET}/${encodeURIComponent(finalPathKey.replace(/^\/+/, ''))}`;

    // Generate thumbnail
    let thumbnailUrl = null;
    let thumbnailPath = null;
    try {
      console.log('Generating thumbnail...');
      const thumbnailBuffer = await generateThumbnail(fixedBuffer);
      
      // Upload thumbnail to Supabase
      const thumbFileName = `${safeName.replace(/\.[^.]+$/, '')}-thumb.jpg`;
      const thumbPathKey = `thumbnails/${thumbFileName}`;
      
      const { data: thumbUploadData, error: thumbUploadError } = await supabase
        .storage
        .from(BUCKET)
        .upload(thumbPathKey, thumbnailBuffer, {
          contentType: 'image/jpeg',
          upsert: false
        });

      if (thumbUploadError) {
        console.error('Thumbnail upload error:', thumbUploadError);
      } else {
        thumbnailPath = thumbPathKey;
        thumbnailUrl = `${SUPABASE_URL.replace(/\/$/, '')}/storage/v1/object/public/${BUCKET}/${encodeURIComponent(thumbPathKey.replace(/^\/+/, ''))}`;
        console.log('Thumbnail uploaded:', thumbnailUrl);
      }
    } catch (thumbErr) {
      console.error('Error generating/uploading thumbnail:', thumbErr);
      // Continue without thumbnail - not a critical error
    }

    // cleanup temp files
    try { fs.unlinkSync(tmpIn); fs.unlinkSync(tmpOut); } catch(e) {}

    const parsedTags = tags ? (Array.isArray(tags) ? tags : String(tags).split(',').map(t=>t.trim()).filter(Boolean)) : [];

    const doc = new ExerciseVideo({
      title: parsedTitle.trim(),
      description: description || '',
      trainer: req.user._id,
      videoUrl,
      videoPath: finalPathKey,
      thumbnailUrl,
      thumbnailPath,
      exerciseType: parsedExerciseType,
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

    // Generate signed URLs for each video
    const videosWithSignedUrls = await Promise.all(videos.map(async (video) => {
      try {
        const { data, error } = await supabase
          .storage
          .from(BUCKET)
          .createSignedUrl(video.videoPath, 3600); // 1 hour expiry

        if (error) {
          console.error('Error creating signed URL for video:', video._id, error);
          return { ...video.toObject(), videoUrl: video.videoUrl }; // fallback to original
        }

        return { ...video.toObject(), videoUrl: data.signedUrl };
      } catch (err) {
        console.error('Exception creating signed URL:', err);
        return { ...video.toObject(), videoUrl: video.videoUrl };
      }
    }));

    return res.json({ videos: videosWithSignedUrls });
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
    const filesToDelete = [video.videoPath];
    if (video.thumbnailPath) {
      filesToDelete.push(video.thumbnailPath);
    }
    
    const { error: deleteError } = await supabase
      .storage
      .from(BUCKET)
      .remove(filesToDelete);

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
