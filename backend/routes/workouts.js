const express = require('express');
const router = express.Router();
const Workout = require('../models/Workout');
const { verifyToken, checkRole } = require('../middleware/auth');

// Create a new workout (Member Route)
router.post('/', verifyToken, checkRole(['member', 'trainer']), async (req, res) => {
  try {
    const workoutData = {
      ...req.body,
      user: req.user._id
    };

    const workout = new Workout(workoutData);
    await workout.save();

    res.status(201).json({
      message: 'Workout logged successfully',
      workout
    });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// Get user's workouts (Member Route)
router.get('/', verifyToken, async (req, res) => {
  try {
    const { 
      startDate, 
      endDate, 
      limit = 10, 
      page = 1 
    } = req.query;

    const query = { user: req.user._id };

    if (startDate && endDate) {
      query.date = {
        $gte: new Date(startDate),
        $lte: new Date(endDate)
      };
    }

    const workouts = await Workout.find(query)
      .sort({ date: -1 })
      .limit(Number(limit))
      .skip((page - 1) * limit);

    const total = await Workout.countDocuments(query);

    res.json({
      workouts,
      totalWorkouts: total,
      currentPage: page,
      totalPages: Math.ceil(total / limit)
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get a specific workout by ID
router.get('/:id', verifyToken, async (req, res) => {
  try {
    const workout = await Workout.findById(req.params.id);

    if (!workout) {
      return res.status(404).json({ error: 'Workout not found' });
    }

    // Ensure user can only access their own workouts or trainer can view
    if (
      workout.user.toString() !== req.user._id.toString() && 
      req.user.role !== 'trainer'
    ) {
      return res.status(403).json({ error: 'Unauthorized access' });
    }

    res.json(workout);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Update a workout
router.patch('/:id', verifyToken, checkRole(['member', 'trainer']), async (req, res) => {
  try {
    const workout = await Workout.findById(req.params.id);

    if (!workout) {
      return res.status(404).json({ error: 'Workout not found' });
    }

    // Ensure user can only update their own workouts or trainer can update
    if (
      workout.user.toString() !== req.user._id.toString() && 
      req.user.role !== 'trainer'
    ) {
      return res.status(403).json({ error: 'Unauthorized to update this workout' });
    }

    const updatedWorkout = await Workout.findByIdAndUpdate(
      req.params.id, 
      req.body, 
      { new: true, runValidators: true }
    );

    res.json({
      message: 'Workout updated successfully',
      workout: updatedWorkout
    });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// Delete a workout
router.delete('/:id', verifyToken, checkRole(['member', 'trainer']), async (req, res) => {
  try {
    const workout = await Workout.findById(req.params.id);

    if (!workout) {
      return res.status(404).json({ error: 'Workout not found' });
    }

    // Ensure user can only delete their own workouts or trainer can delete
    if (
      workout.user.toString() !== req.user._id.toString() && 
      req.user.role !== 'trainer'
    ) {
      return res.status(403).json({ error: 'Unauthorized to delete this workout' });
    }

    await workout.remove();

    res.json({ message: 'Workout deleted successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Trainer: Get workouts for a specific user
router.get('/user/:userId', 
  verifyToken, 
  checkRole(['trainer', 'admin']), 
  async (req, res) => {
    try {
      const { 
        startDate, 
        endDate, 
        limit = 10, 
        page = 1 
      } = req.query;

      const query = { user: req.params.userId };

      if (startDate && endDate) {
        query.date = {
          $gte: new Date(startDate),
          $lte: new Date(endDate)
        };
      }

      const workouts = await Workout.find(query)
        .sort({ date: -1 })
        .limit(Number(limit))
        .skip((page - 1) * limit);

      const total = await Workout.countDocuments(query);

      res.json({
        workouts,
        totalWorkouts: total,
        currentPage: page,
        totalPages: Math.ceil(total / limit)
      });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
});

module.exports = router;