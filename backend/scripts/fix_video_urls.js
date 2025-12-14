const mongoose = require('mongoose');
const ExerciseVideo = require('../models/ExerciseVideo');
require('dotenv').config();

const SUPABASE_URL = process.env.SUPABASE_URL;
const BUCKET = process.env.SUPABASE_BUCKET;

async function main() {
  await mongoose.connect(process.env.MONGODB_URI);
  console.log('Connected to MongoDB');

  const videos = await ExerciseVideo.find({});
  console.log('Found videos:', videos.length);

  for (const v of videos) {
    if (!v.videoPath) continue;

    let fixedPath = v.videoPath.replace(/\s+/g, ''); // remove all spaces
    fixedPath = fixedPath.replace(/^\/+/, ''); // remove leading slashes

    const fixedUrl =
      `${SUPABASE_URL.replace(/\/$/, '')}/storage/v1/object/public/${BUCKET}/${encodeURIComponent(fixedPath)}`;

    console.log('Fixing:', v._id, '→', fixedUrl);

    v.videoPath = fixedPath;
    v.videoUrl = fixedUrl;

    await v.save();
  }

  console.log('DONE fixing URLs.');
  process.exit(0);
}

main().catch(e => {
  console.error(e);
  process.exit(1);
});
