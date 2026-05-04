const express = require('express');
const router = express.Router();
const { verifyToken } = require('../middleware/auth');
const Rating = require('../models/rating');

// Submit a rating for a trainer
router.post('/', verifyToken, async (req, res) => {
  try {
    const { trainerId, rating, feedback } = req.body;
    const memberId = req.user._id;

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
    const ratings = await Rating.find({ trainer: trainerId }).populate('member', 'username');

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
