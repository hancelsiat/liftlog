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
const ExerciseVideo = require('../models/ExerciseVideo');
const User = require('../models/User');
const { verifyToken, checkRole } = require('../middleware/auth');
const emailService = require('../services/emailService');

// init supabase
const SUPABASE_URL = process.env.SUPABASE_URL;
const SERVICE_KEY = process.env.SUPABASE_KEY;
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
      return res.status(400).json({ error: 'Please select a video file to upload.' });
    }

    const { title, exerciseType, description, difficulty, duration, tags, isPublic } = req.body;
    const parsedIsPublic = isPublic == null ? true : (isPublic === 'true' || isPublic === true);
    const parsedTitle = title ? String(title).trim() : '';
    const parsedExerciseType = exerciseType ? String(exerciseType).trim().toLowerCase() : 'strength'; // default, convert to lowercase

    if (!parsedTitle) {
      return res.status(400).json({ error: 'Please provide a title for the video.' });
    }
    if (!req.user || !req.user._id) {
      return res.status(401).json({ error: 'Please log in to upload videos.' });
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
      return res.status(401).json({ error: 'Please log in to view your videos.' });
    }

    const videos = await ExerciseVideo.find({ 
      trainer: req.user._id, 
      isDeleted: { $ne: true } 
    }).sort({ createdAt: -1 });
    console.log(`Found ${videos.length} videos for trainer ${req.user._id}`);

    // Generate signed URLs for videos and thumbnails
    const videosWithSignedUrls = await Promise.all(videos.map(async (video) => {
      try {
        const videoObj = video.toObject();
        
        // Generate signed URL for video
        const { data: videoData, error: videoError } = await supabase
          .storage
          .from(BUCKET)
          .createSignedUrl(video.videoPath, 3600); // 1 hour expiry

        if (!videoError && videoData) {
          videoObj.videoUrl = videoData.signedUrl;
        }

        // Generate signed URL for thumbnail if it exists
        if (video.thumbnailPath) {
          const { data: thumbData, error: thumbError } = await supabase
            .storage
            .from(BUCKET)
            .createSignedUrl(video.thumbnailPath, 3600); // 1 hour expiry

          if (!thumbError && thumbData) {
            videoObj.thumbnailUrl = thumbData.signedUrl;
          }
        }

        return videoObj;
      } catch (err) {
        console.error('Exception creating signed URLs:', err);
        return video.toObject();
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
    const videos = await ExerciseVideo.find({ 
      isPublic: true, 
      isDeleted: { $ne: true } 
    })
      .populate('trainer', 'username email')
      .sort({ createdAt: -1 });
    console.log(`Found ${videos.length} public videos`);

    // Generate signed URLs for videos and thumbnails
    const videosWithSignedUrls = await Promise.all(videos.map(async (video) => {
      try {
        const videoObj = video.toObject();
        
        // Generate signed URL for video
        const { data: videoData, error: videoError } = await supabase
          .storage
          .from(BUCKET)
          .createSignedUrl(video.videoPath, 3600); // 1 hour expiry

        if (!videoError && videoData) {
          videoObj.videoUrl = videoData.signedUrl;
        }

        // Generate signed URL for thumbnail if it exists
        if (video.thumbnailPath) {
          const { data: thumbData, error: thumbError } = await supabase
            .storage
            .from(BUCKET)
            .createSignedUrl(video.thumbnailPath, 3600); // 1 hour expiry

          if (!thumbError && thumbData) {
            videoObj.thumbnailUrl = thumbData.signedUrl;
          }
        }

        return videoObj;
      } catch (err) {
        console.error('Exception creating signed URLs:', err);
        return video.toObject();
      }
    }));

    console.log('Returning videos with thumbnails:', videosWithSignedUrls.map(v => ({ 
      id: v._id, 
      title: v.title,
      hasThumbnail: !!v.thumbnailUrl 
    })));

    return res.json({ videos: videosWithSignedUrls });
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
      return res.status(401).json({ error: 'Please log in to delete videos.' });
    }

    const video = await ExerciseVideo.findById(videoId);
    if (!video) {
      return res.status(404).json({ error: 'We could not find this video to delete.' });
    }

    // Check if the user is the trainer who uploaded the video
    if (video.trainer.toString() !== req.user._id.toString()) {
      return res.status(403).json({ error: 'You do not have permission to delete this video.' });
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

const escapeHtml = (value) => String(value == null ? '' : value)
  .replace(/&/g, '&amp;')
  .replace(/</g, '&lt;')
  .replace(/>/g, '&gt;')
  .replace(/"/g, '&quot;')
  .replace(/'/g, '&#39;');

const escapeRegex = (value) => String(value).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

// GET /api/videos/admin/all - Admin: list ALL trainer uploads (public and private) for moderation
// Query: ?status=active|deleted|all (default active), ?search=<title/trainer>, ?trainerId=<id>
router.get('/admin/all', verifyToken, checkRole(['admin']), async (req, res) => {
  try {
    const status = (req.query.status || 'active').toString().toLowerCase();
    if (!['active', 'deleted', 'all'].includes(status)) {
      return res.status(400).json({ error: 'Invalid status filter. Use active, deleted or all.' });
    }

    const query = {};
    if (status === 'active') query.isDeleted = { $ne: true };
    if (status === 'deleted') query.isDeleted = true;
    if (req.query.trainerId) query.trainer = req.query.trainerId;

    const search = (req.query.search || '').toString().trim();
    if (search) {
      const rx = new RegExp(escapeRegex(search), 'i');
      const matchingTrainers = await User.find({ username: rx, role: 'trainer' }).select('_id');
      query.$or = [
        { title: rx },
        { description: rx },
        { trainer: { $in: matchingTrainers.map((t) => t._id) } }
      ];
    }

    const videos = await ExerciseVideo.find(query)
      .populate('trainer', 'username email')
      .populate('deletedBy', 'username')
      .sort({ createdAt: -1 })
      .limit(200);

    // Signed URLs only for videos whose files still exist (removed videos are purged from storage)
    const result = await Promise.all(videos.map(async (video) => {
      const videoObj = video.toObject();
      if (video.isDeleted) {
        videoObj.videoUrl = null;
        videoObj.thumbnailUrl = null;
        return videoObj;
      }
      try {
        const { data: videoData, error: videoError } = await supabase
          .storage.from(BUCKET).createSignedUrl(video.videoPath, 3600);
        if (!videoError && videoData) videoObj.videoUrl = videoData.signedUrl;

        if (video.thumbnailPath) {
          const { data: thumbData, error: thumbError } = await supabase
            .storage.from(BUCKET).createSignedUrl(video.thumbnailPath, 3600);
          if (!thumbError && thumbData) videoObj.thumbnailUrl = thumbData.signedUrl;
        }
      } catch (err) {
        console.error('Admin list: signed URL error:', err.message);
      }
      return videoObj;
    }));

    const [activeCount, deletedCount] = await Promise.all([
      ExerciseVideo.countDocuments({ isDeleted: { $ne: true } }),
      ExerciseVideo.countDocuments({ isDeleted: true })
    ]);

    return res.json({ videos: result, activeCount, deletedCount });
  } catch (err) {
    console.error('Admin videos list error:', err);
    return res.status(500).json({ error: 'Failed to load videos for moderation', message: err.message });
  }
});

// Admin only: Soft delete inappropriate video with detailed reason
// This is part of Admin Settings for content moderation. Records reason for audit and user notification.
// Updates DB with deletion metadata, optionally cleans storage, and logs action.
router.delete('/admin/:id', verifyToken, checkRole(['admin']), async (req, res) => {
  try {
    const { reason } = req.body;
    if (!reason || reason.trim().length < 10) {
      return res.status(400).json({ 
        error: 'A detailed deletion reason is required (minimum 10 characters).' 
      });
    }

    const video = await ExerciseVideo.findById(req.params.id);
    if (!video) {
      return res.status(404).json({ error: 'We could not find this video.' });
    }

    if (video.isDeleted) {
      return res.status(400).json({ error: 'This video has already been deleted.' });
    }

    const trimmedReason = reason.trim().slice(0, 500);

    // Soft delete with reason for audit and transparency
    video.isDeleted = true;
    video.deletionReason = trimmedReason;
    video.deletedBy = req.user._id;
    video.deletedAt = new Date();
    await video.save();

    // Clean up storage (Supabase) for inappropriate content (similar to trainer delete)
    const filesToDelete = [video.videoPath];
    if (video.thumbnailPath) {
      filesToDelete.push(video.thumbnailPath);
    }
    const { error: deleteError } = await supabase
      .storage
      .from(BUCKET)
      .remove(filesToDelete);

    if (deleteError) {
      console.warn('Supabase storage cleanup warning for admin delete:', deleteError);
      // Continue anyway - DB is the source of truth
    }

    // Send notification to trainer (using existing service)
    try {
      const trainerUser = await User.findById(video.trainer).select('email username');
      const trainerEmail = trainerUser ? trainerUser.email : null;
      if (trainerEmail) {
        await emailService.sendEmail(trainerEmail, 'Your video has been removed - Moderation Notice', `
            <h2>Video Moderation Notice</h2>
            <p>Dear ${escapeHtml(trainerUser.username || 'Trainer')},</p>
            <p>Your video titled "<strong>${escapeHtml(video.title)}</strong>" has been removed by an administrator.</p>
            <p><strong>Reason for deletion:</strong> ${escapeHtml(trimmedReason)}</p>
            <p>This action was taken to maintain appropriate content standards in the community.</p>
            <p>If you believe this was an error, please contact admin support.</p>
            <p>Video ID: ${video._id}</p>
            <p>Best regards,<br>LiftLog Admin Team</p>
          `);
        console.log(`Deletion notification email sent to trainer ${trainerUser.username || trainerEmail}`);
      }
    } catch (emailErr) {
      console.warn('Email notification for video deletion failed (non-blocking):', emailErr.message);
    }

    console.log(`[ADMIN] Video ${req.params.id} marked deleted by ${req.user._id}. Reason: ${trimmedReason}`);

    res.json({ 
      message: 'Video successfully removed for inappropriate content. Trainer notified with reason.',
      deletionReason: trimmedReason,
      videoId: video._id
    });
  } catch (error) {
    console.error('Admin video delete error:', error);
    res.status(500).json({ error: error.message || 'Failed to delete video' });
  }
});

module.exports = router;
