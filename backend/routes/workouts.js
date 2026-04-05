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

// Create a new workout template (Trainer Route)
router.post('/template', verifyToken, checkRole(['trainer']), async (req, res) => {
  try {    const { title, ...rest } = req.body;
    const workoutData = {
      ...rest,
      name: title, // Map incoming 'title' to the schema's 'name' field
      trainer: req.user._id,
      isPublic: true
    };

    const workout = new Workout(workoutData);
    await workout.save();

    res.status(201).json({
      message: 'Workout template created successfully',
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
      .populate('trainer', 'username')
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

// Get available trainers for members
router.get('/trainers/available', verifyToken, checkRole(['all']), async (req, res) => {
  try {
    const User = require('../models/User');

    const trainers = await User.find({
      role: 'trainer',
      membershipExpiration: { $gt: new Date() }
    }).select('username email profile.firstName profile.lastName');

    res.json({ trainers });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get workouts by trainer (Member Route)
router.get('/trainer/:trainerId', verifyToken, checkRole(['all']), async (req, res) => {
  try {
    const { trainerId } = req.params;
    const { limit = 10, page = 1 } = req.query;

    const workouts = await Workout.find({
      trainer: trainerId,
      isPublic: true
    })
      .populate('trainer', 'username')
      .sort({ createdAt: -1 })
      .limit(Number(limit))
      .skip((page - 1) * limit);

    const total = await Workout.countDocuments({
      trainer: trainerId,
      isPublic: true
    });

    res.json({
      workouts,
      totalWorkouts: total,
      currentPage: Number(page),
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



    res.json(workout);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Update a workout
router.patch('/:id', verifyToken, checkRole(['member', 'trainer']), async (req, res) => {
  try {
    console.log(`[0] DB Connection State: ${mongoose.connection.readyState}`);
    // First, find the workout to ensure it exists and for authorization
    const workout = await Workout.findById(req.params.id);

    if (!workout) {
      return res.status(404).json({ error: 'Workout not found' });
    }

    // Authorization check (copied from admin logic)
    const isOwner = workout.user?.equals(req.user._id) || workout.trainer?.equals(req.user._id);
    const canTrainerEdit = req.user.role === 'trainer' && !!workout.user;

    if (!isOwner && !canTrainerEdit) {
      return res.status(403).json({ error: 'Unauthorized to update this workout' });
    }

    // Now, apply the updates and save
    Object.keys(req.body).forEach(key => {
      workout[key] = req.body[key];
    });

    const updatedWorkout = await workout.save();

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
    // First, find the workout to ensure it exists and for authorization
    const workout = await Workout.findById(req.params.id);

    if (!workout) {
      return res.status(404).json({ error: 'Workout not found' });
    }

    // Authorization check (copied from update logic)
    const isOwner = workout.user?.equals(req.user._id) || workout.trainer?.equals(req.user._id);
    const canTrainerDelete = req.user.role === 'trainer' && !!workout.user;

    if (!isOwner && !canTrainerDelete) {
      return res.status(403).json({ error: 'Unauthorized to delete this workout' });
    }

    // Now, remove the workout
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