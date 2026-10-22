const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const { verifyToken, checkRole } = require('../middleware/auth');
const Rating = require('../models/rating');
const User = require('../models/User');

// Submit a rating for a trainer (members only; the app asks for it after a
// member leaves their trainer).
router.post('/', verifyToken, checkRole(['member']), async (req, res) => {
  try {
    const { trainerId, rating, feedback } = req.body;
    const memberId = req.user._id;

    // Only real trainers can be rated (not members, admins or unknown ids).
    const trainer = mongoose.Types.ObjectId.isValid(trainerId)
      ? await User.findById(trainerId).select('role')
      : null;
    if (!trainer || trainer.role !== 'trainer') {
      return res.status(404).json({ error: 'We could not find this trainer.' });
    }

    const newRating = new Rating({
      trainer: trainerId,
      member: memberId,
      rating,
      feedback,
    });

    await newRating.save();
    res.status(201).json(newRating);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// Get all ratings for the logged-in trainer
router.get('/', verifyToken, async (req, res) => {
  try {
    const trainerId = req.user._id;
    // Anonymous: do not expose which member wrote the feedback
    const ratings = await Rating.find({ trainer: trainerId })
      .select('rating feedback createdAt')
      .sort({ createdAt: -1 });

    if (ratings.length === 0) {
      return res.json({
        ratings: [],
        averageRating: 0,
        totalRatings: 0,
        ratingPercentage: 0,
      });
    }

    const totalRatings = ratings.length;
    const sumOfRatings = ratings.reduce((acc, curr) => acc + curr.rating, 0);
    const averageRating = sumOfRatings / totalRatings;
    const ratingPercentage = (averageRating / 5) * 100;
    console.log(`[ratings.js] trainerId: ${trainerId}, ratingPercentage: ${ratingPercentage}`);

    res.json({
      ratings,
      averageRating: parseFloat(averageRating.toFixed(2)),
      totalRatings,
      ratingPercentage: parseFloat(ratingPercentage.toFixed(2)),
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get all ratings for a specific trainer (used by members when choosing a trainer).
// Feedback is ANONYMOUS: the member reference/username is never sent to the client.
router.get('/trainer/:trainerId', async (req, res) => {
  try {
    const { trainerId } = req.params;
    const rawRatings = await Rating.find({ trainer: trainerId })
      .select('rating feedback createdAt')
      .sort({ createdAt: -1 })
      .lean();

    // Strip any identifying information before sending
    const ratings = rawRatings.map((r) => ({
      _id: r._id,
      rating: r.rating,
      feedback: r.feedback || '',
      createdAt: r.createdAt,
    }));

    if (ratings.length === 0) {
      return res.json({
        ratings: [],
        averageRating: 0,
        totalRatings: 0,
        ratingPercentage: 0,
      });
    }

    const totalRatings = ratings.length;
    const sumOfRatings = ratings.reduce((acc, curr) => acc + curr.rating, 0);
    const averageRating = sumOfRatings / totalRatings;
    const ratingPercentage = (averageRating / 5) * 100;
    console.log(`[ratings.js] trainerId: ${trainerId}, ratingPercentage: ${ratingPercentage}`);

    res.json({
      ratings,
      averageRating: parseFloat(averageRating.toFixed(2)),
      totalRatings,
      ratingPercentage: parseFloat(ratingPercentage.toFixed(2)),
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;
