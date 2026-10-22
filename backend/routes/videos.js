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
// Trainers only: the role is checked before multer reads the file, so other
// users can't upload videos by calling the API directly.
router.post('/', verifyToken, checkRole(['trainer']), upload.single('video'), async (req, res) => {
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
    if (!video || video.isDeleted) {
      return res.status(404).json({ error: 'We could not find this video to delete.' });
    }

    // Check if the user is the trainer who uploaded the video
    if (video.trainer.toString() !== req.user._id.toString()) {
      return res.status(403).json({ error: 'You do not have permission to delete this video.' });
    }

    // Soft delete: the record AND the files stay, so the trainer can restore
    // it from "Recently deleted" and admins can see it in Content moderation.
    // Files are only erased by DELETE /:id/permanent. Hidden from members.
    
    video.isDeleted = true;
    video.deletedBy = req.user._id;
    video.deletedByRole = 'trainer';
    video.deletedAt = new Date();
    video.deletionReason = 'Deleted by the trainer.';
    await video.save();
    console.log(`[TRAINER] Video ${videoId} deleted by trainer ${req.user._id}`);

    return res.json({ message: 'Video deleted successfully' });
  } catch (err) {
    console.error('videos delete error:', err && err.stack ? err.stack : err);
    return res.status(500).json({ error: 'Failed to delete video', message: err.message || String(err) });
  }
});

// Adds 1-hour signed URLs for the video file and thumbnail (if they exist).
async function withSignedUrls(video) {
  const videoObj = video.toObject();
  videoObj.videoUrl = null;
  videoObj.thumbnailUrl = null;
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
    console.error('Signed URL error:', err.message);
  }
  return videoObj;
}

// True when the video file is still in storage. Videos deleted before
// files were kept on delete have no file and cannot be restored.
async function videoFileExists(video) {
  try {
    const { data, error } = await supabase
      .storage.from(BUCKET).createSignedUrl(video.videoPath, 60);
    return !error && !!data;
  } catch (err) {
    return false;
  }
}

async function removeVideoFiles(video) {
  const files = [video.videoPath];
  if (video.thumbnailPath) files.push(video.thumbnailPath);
  const { error } = await supabase.storage.from(BUCKET).remove(files);
  if (error) console.warn('Supabase storage cleanup warning:', error);
}

function markRestored(video, user, role) {
  video.isDeleted = false;
  video.deletedBy = undefined;
  video.deletedByRole = undefined;
  video.deletedAt = undefined;
  video.deletionReason = undefined;
  video.restoredAt = new Date();
  video.restoredBy = user._id;
  video.restoredByRole = role;
}

// GET /api/videos/trainer/deleted - Trainer: "Recently deleted" (own deletions
// and admin removals that were not deleted permanently).
router.get('/trainer/deleted', verifyToken, checkRole(['trainer']), async (req, res) => {
  try {
    const videos = await ExerciseVideo.find({
      trainer: req.user._id,
      isDeleted: true,
      purgedAt: { $exists: false }
    }).sort({ deletedAt: -1 });

    const result = await Promise.all(videos.map(withSignedUrls));
    return res.json({ videos: result });
  } catch (err) {
    console.error('Trainer deleted videos error:', err);
    return res.status(500).json({ error: 'Failed to load deleted videos', message: err.message });
  }
});

// POST /api/videos/:id/restore - Trainer: restore a video they deleted.
// Videos removed by an admin can only be restored by an admin.
router.post('/:id/restore', verifyToken, checkRole(['trainer']), async (req, res) => {
  try {
    const video = await ExerciseVideo.findById(req.params.id);
    if (!video || video.trainer.toString() !== req.user._id.toString()) {
      return res.status(404).json({ error: 'We could not find this video.' });
    }
    if (!video.isDeleted) {
      return res.status(400).json({ error: 'This video is not deleted.' });
    }
    if (video.purgedAt) {
      return res.status(410).json({ error: 'This video was deleted permanently.' });
    }
    if (video.deletedByRole !== 'trainer') {
      return res.status(403).json({
        error: 'This video was removed by an administrator. Only an admin can restore it.'
      });
    }
    if (!(await videoFileExists(video))) {
      return res.status(409).json({
        error: 'The video file no longer exists, so this video cannot be restored.'
      });
    }

    markRestored(video, req.user, 'trainer');
    await video.save();
    console.log(`[TRAINER] Video ${video._id} restored by trainer ${req.user._id}`);
    return res.json({ message: 'Video restored', video: await withSignedUrls(video) });
  } catch (err) {
    console.error('Trainer restore video error:', err);
    return res.status(500).json({ error: 'Failed to restore video', message: err.message });
  }
});

// DELETE /api/videos/:id/permanent - Trainer: delete a video in
// "Recently deleted" forever. The files are erased; the record is kept as a
// tombstone (purgedAt) so admin moderation keeps the history.
router.delete('/:id/permanent', verifyToken, checkRole(['trainer']), async (req, res) => {
  try {
    const video = await ExerciseVideo.findById(req.params.id);
    if (!video || video.trainer.toString() !== req.user._id.toString() || video.purgedAt) {
      return res.status(404).json({ error: 'We could not find this video.' });
    }
    if (!video.isDeleted) {
      return res.status(400).json({ error: 'Delete the video first, then delete it permanently.' });
    }

    await removeVideoFiles(video);
    video.purgedAt = new Date();
    await video.save();
    console.log(`[TRAINER] Video ${video._id} permanently deleted by trainer ${req.user._id}`);
    return res.json({ message: 'Video permanently deleted' });
  } catch (err) {
    console.error('Trainer permanent delete video error:', err);
    return res.status(500).json({ error: 'Failed to delete video permanently', message: err.message });
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
// Query: ?status=active|deleted|trainer|all (default active), ?search=<title/trainer>, ?trainerId=<id>
// 'deleted' = every removed video, 'trainer' = only videos the trainer deleted themselves.
router.get('/admin/all', verifyToken, checkRole(['admin']), async (req, res) => {
  try {
    const status = (req.query.status || 'active').toString().toLowerCase();
    if (!['active', 'deleted', 'trainer', 'all'].includes(status)) {
      return res.status(400).json({ error: 'Invalid status filter. Use active, deleted, trainer or all.' });
    }

    const query = {};
    if (status === 'active') query.isDeleted = { $ne: true };
    if (status === 'deleted') query.isDeleted = true;
    if (status === 'trainer') {
      query.isDeleted = true;
      query.deletedByRole = 'trainer';
    }
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
      .populate('restoredBy', 'username')
      .sort({ createdAt: -1 })
      .limit(200);

    // Signed URLs for every video whose files still exist. Removed videos keep
    // their files (so they can be reviewed / restored) unless the trainer
    // deleted them permanently, or they were removed before files were kept
    // (then videoUrl stays null).
    const result = await Promise.all(videos.map(async (video) => {
      if (video.purgedAt) {
        const videoObj = video.toObject();
        videoObj.videoUrl = null;
        videoObj.thumbnailUrl = null;
        return videoObj;
      }
      return withSignedUrls(video);
    }));

    const [activeCount, deletedCount, trainerDeletedCount] = await Promise.all([
      // Counts ignore the trainerId/search filters (whole-platform totals).
      ExerciseVideo.countDocuments({ isDeleted: { $ne: true } }),
      ExerciseVideo.countDocuments({ isDeleted: true }),
      ExerciseVideo.countDocuments({ isDeleted: true, deletedByRole: 'trainer' })
    ]);

    return res.json({ videos: result, activeCount, deletedCount, trainerDeletedCount });
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
    video.deletedByRole = 'admin';
    video.deletedAt = new Date();
    await video.save();

    // Files are kept so an admin can review the video and restore it
    // (POST /admin/:id/restore). It is hidden from the trainer and members.

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

// POST /api/videos/admin/:id/restore - Admin: undo a moderation removal.
// Videos the trainer deleted themselves can only be restored by that trainer.
router.post('/admin/:id/restore', verifyToken, checkRole(['admin']), async (req, res) => {
  try {
    const video = await ExerciseVideo.findById(req.params.id);
    if (!video) {
      return res.status(404).json({ error: 'We could not find this video.' });
    }
    if (!video.isDeleted) {
      return res.status(400).json({ error: 'This video is not removed.' });
    }
    if (video.purgedAt) {
      return res.status(410).json({ error: 'The trainer deleted this video permanently.' });
    }
    if (video.deletedByRole === 'trainer') {
      return res.status(403).json({
        error: 'The trainer deleted this video. Only the trainer can restore it.'
      });
    }
    if (!(await videoFileExists(video))) {
      return res.status(409).json({
        error: 'The video file was erased when it was removed, so it cannot be restored.'
      });
    }

    markRestored(video, req.user, 'admin');
    await video.save();

    try {
      const trainerUser = await User.findById(video.trainer).select('email username');
      if (trainerUser && trainerUser.email) {
        await emailService.sendEmail(trainerUser.email, 'Your video has been restored', `
            <h2>Video Restored</h2>
            <p>Dear ${escapeHtml(trainerUser.username || 'Trainer')},</p>
            <p>Your video titled "<strong>${escapeHtml(video.title)}</strong>" has been reviewed and restored by an administrator. It is visible again.</p>
            <p>Video ID: ${video._id}</p>
            <p>Best regards,<br>LiftLog Admin Team</p>
          `);
      }
    } catch (emailErr) {
      console.warn('Email notification for video restore failed (non-blocking):', emailErr.message);
    }

    console.log(`[ADMIN] Video ${video._id} restored by ${req.user._id}`);
    res.json({ message: 'Video restored. The trainer was notified.', videoId: video._id });
  } catch (error) {
    console.error('Admin video restore error:', error);
    res.status(500).json({ error: error.message || 'Failed to restore video' });
  }
});

module.exports = router;
