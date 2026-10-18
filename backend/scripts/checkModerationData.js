// Diagnostic: confirms the admin moderation queries see the existing data.
// Usage (from backend/): node scripts/checkModerationData.js
require('dotenv').config();
const mongoose = require('mongoose');
const ExerciseVideo = require('../models/ExerciseVideo');
const Workout = require('../models/Workout');
const User = require('../models/User');
const CooldownResetRequest = require('../models/CooldownResetRequest');

(async () => {
  try {
    await mongoose.connect(process.env.MONGODB_URI, { serverSelectionTimeoutMS: 15000 });
    console.log('Connected to MongoDB database:', mongoose.connection.name);

    const videosTotal = await ExerciseVideo.countDocuments({});
    const videosNoFlag = await ExerciseVideo.countDocuments({ isDeleted: { $exists: false } });
    const videosActive = await ExerciseVideo.countDocuments({ isDeleted: { $ne: true } });
    const videosDeleted = await ExerciseVideo.countDocuments({ isDeleted: true });
    console.log(`Videos: total=${videosTotal} active=${videosActive} removed=${videosDeleted} (old docs without isDeleted field=${videosNoFlag})`);

    const tplTotal = await Workout.countDocuments({ isTemplate: true });
    const tplActive = await Workout.countDocuments({ isTemplate: true, isDeleted: { $ne: true } });
    const tplNoFlag = await Workout.countDocuments({ isTemplate: true, isDeleted: { $exists: false } });
    const allWorkouts = await Workout.countDocuments({});
    console.log(`Workout templates: total=${tplTotal} active=${tplActive} (old docs without isDeleted=${tplNoFlag}); all workout docs=${allWorkouts}`);

    const sampleVideos = await ExerciseVideo.find({ isDeleted: { $ne: true } })
      .populate('trainer', 'username').sort({ createdAt: -1 }).limit(5).lean();
    sampleVideos.forEach((v) => console.log(`  video: "${v.title}" by ${v.trainer ? v.trainer.username : '(missing trainer)'}`));

    const sampleTpl = await Workout.find({ isTemplate: true, isDeleted: { $ne: true } })
      .populate('trainer', 'username').sort({ createdAt: -1 }).limit(5).lean();
    sampleTpl.forEach((w) => console.log(`  workout: "${w.title}" by ${w.trainer ? w.trainer.username : '(missing trainer)'}`));

    const pending = await CooldownResetRequest.countDocuments({ status: 'pending' });
    const trainers = await User.countDocuments({ role: 'trainer' });
    console.log(`Trainers=${trainers}, pending reset requests=${pending}`);
  } catch (err) {
    console.error('Check failed:', err.message);
    process.exitCode = 1;
  } finally {
    await mongoose.disconnect();
  }
})();
