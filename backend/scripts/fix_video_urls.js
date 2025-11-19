// backend/scripts/fix_video_urls.js
const mongoose = require('mongoose');
const ExerciseVideo = require('../models/ExerciseVideo'); // adjust path
require('dotenv').config({ path: '../.env' });

const SUPABASE_URL = process.env.SUPABASE_URL;
const BUCKET = process.env.SUPABASE_BUCKET || 'video';

async function main(){
  await mongoose.connect(process.env.MONGODB_URI, { });
  console.log('Connected to MongoDB');
  const cursor = ExerciseVideo.find({ videoPath: { $exists: true } }).cursor();
  let updated = 0;
  for (let doc = await cursor.next(); doc != null; doc = await cursor.next()){
    const path = doc.videoPath;
    if (!path) continue;
    // If videoPath already contains bucket prefix, remove it first:
    const maybePath = path.startsWith(`${BUCKET}/`) ? path.slice(BUCKET.length + 1) : path;
    const encoded = encodeURIComponent(maybePath);
    const publicUrl = `${SUPABASE_URL.replace(/\/$/, '')}/storage/v1/object/public/${encodeURIComponent(BUCKET)}/${encoded}`;
    doc.videoUrl = publicUrl;
    await doc.save();
    updated++;
    console.log('Updated', doc._id, publicUrl);
  }
  console.log('Done. Updated', updated);
  process.exit(0);
}

main().catch(e => {
  console.error(e);
  process.exit(1);
});
