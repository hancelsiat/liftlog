const mongoose = require('mongoose');
const { createClient } = require('@supabase/supabase-js');
const ffmpeg = require('fluent-ffmpeg');
const fs = require('fs');
const path = require('path');
const os = require('os');
require('dotenv').config();

// Import the ExerciseVideo model
const ExerciseVideo = require('../models/ExerciseVideo');

// Initialize Supabase
const SUPABASE_URL = process.env.SUPABASE_URL;
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const BUCKET = process.env.SUPABASE_BUCKET || 'video';

if (!SUPABASE_URL || !SERVICE_KEY) {
  console.error('Missing Supabase credentials');
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SERVICE_KEY);

// Helper function to generate thumbnail from video buffer
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

async function regenerateThumbnails() {
  try {
    // Connect to MongoDB
    const MONGODB_URI = process.env.MONGODB_URI;
    if (!MONGODB_URI) {
      console.error('MONGODB_URI not found in environment variables');
      process.exit(1);
    }

    console.log('Connecting to MongoDB...');
    await mongoose.connect(MONGODB_URI);
    console.log('Connected to MongoDB');

    // Find all videos without thumbnails
    const videosWithoutThumbnails = await ExerciseVideo.find({
      $or: [
        { thumbnailUrl: { $exists: false } },
        { thumbnailUrl: null },
        { thumbnailUrl: '' }
      ]
    });

    console.log(`Found ${videosWithoutThumbnails.length} videos without thumbnails`);

    let successCount = 0;
    let failCount = 0;

    for (const video of videosWithoutThumbnails) {
      try {
        console.log(`\nProcessing video: ${video.title} (${video._id})`);
        console.log(`Video path: ${video.videoPath}`);

        // Download video from Supabase
        const { data: videoData, error: downloadError } = await supabase
          .storage
          .from(BUCKET)
          .download(video.videoPath);

        if (downloadError) {
          console.error(`Failed to download video: ${downloadError.message}`);
          failCount++;
          continue;
        }

        // Convert blob to buffer
        const videoBuffer = Buffer.from(await videoData.arrayBuffer());
        console.log(`Downloaded video: ${videoBuffer.length} bytes`);

        // Generate thumbnail
        console.log('Generating thumbnail...');
        const thumbnailBuffer = await generateThumbnail(videoBuffer);
        console.log(`Generated thumbnail: ${thumbnailBuffer.length} bytes`);

        // Upload thumbnail to Supabase
        const videoFileName = path.basename(video.videoPath);
        const thumbFileName = videoFileName.replace(/\.[^.]+$/, '-thumb.jpg');
        const thumbPathKey = `thumbnails/${thumbFileName}`;

        const { data: thumbUploadData, error: thumbUploadError } = await supabase
          .storage
          .from(BUCKET)
          .upload(thumbPathKey, thumbnailBuffer, {
            contentType: 'image/jpeg',
            upsert: true // Overwrite if exists
          });

        if (thumbUploadError) {
          console.error(`Failed to upload thumbnail: ${thumbUploadError.message}`);
          failCount++;
          continue;
        }

        // Update video document with thumbnail info
        const thumbnailUrl = `${SUPABASE_URL.replace(/\/$/, '')}/storage/v1/object/public/${BUCKET}/${encodeURIComponent(thumbPathKey.replace(/^\/+/, ''))}`;
        
        video.thumbnailUrl = thumbnailUrl;
        video.thumbnailPath = thumbPathKey;
        await video.save();

        console.log(`✅ Successfully generated thumbnail for: ${video.title}`);
        console.log(`Thumbnail URL: ${thumbnailUrl}`);
        successCount++;

      } catch (err) {
        console.error(`❌ Failed to process video ${video.title}:`, err.message);
        failCount++;
      }
    }

    console.log('\n=== Summary ===');
    console.log(`Total videos processed: ${videosWithoutThumbnails.length}`);
    console.log(`✅ Successful: ${successCount}`);
    console.log(`❌ Failed: ${failCount}`);

  } catch (error) {
    console.error('Error in regenerateThumbnails:', error);
  } finally {
    // Close MongoDB connection
    await mongoose.connection.close();
    console.log('\nMongoDB connection closed');
  }
}

// Run the script
regenerateThumbnails()
  .then(() => {
    console.log('\n✅ Thumbnail regeneration complete!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n❌ Thumbnail regeneration failed:', error);
    process.exit(1);
  });
