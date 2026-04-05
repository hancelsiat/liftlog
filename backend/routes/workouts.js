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
  try {    const workout = new Workout({
      name: req.body.title,
      description: req.body.description,
      exercises: req.body.exercises,
      trainer: req.user._id,
      isPublic: true
    });
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
  console.log('--- DEBUG: PATCH ROUTE START ---');
  try {
    console.log(`[1] Finding workout with ID: ${req.params.id}`);
    const workout = await Workout.findById(req.params.id);
    console.log(`[2] Workout found in DB: ${workout ? workout._id : 'null'}`);

    if (!workout) {
      console.log('[2a] Workout not found, sending 404.');
      return res.status(404).json({ error: 'Workout not found' });
    }

    console.log('[3] Checking authorization...');
    const isUserOwner = workout.user?.equals(req.user._id);
    const isTrainerOwner = workout.trainer?.equals(req.user._id);
    const isAuthorized = isUserOwner || isTrainerOwner;
    console.log(`[3a] isUserOwner: ${isUserOwner}, isTrainerOwner: ${isTrainerOwner}, isAuthorized: ${isAuthorized}`);

    if (!isAuthorized) {
      console.log('[3b] User is not direct owner. Checking if trainer can modify...');
      if (req.user.role === 'trainer' && workout.user) {
        console.log('[3c] Trainer is allowed to modify this member workout.');
      } else {
        console.log('[3d] Unauthorized, sending 403.');
        return res.status(403).json({ error: 'Unauthorized to update this workout' });
      }
    }

    console.log('[4] Updating workout with body:', req.body);
    const updatedWorkout = await Workout.findByIdAndUpdate(
      req.params.id,
      { $set: req.body },
      { new: true, runValidators: true }
    );
    console.log('[5] Workout updated in DB:', updatedWorkout);

    res.json(updatedWorkout);
    console.log('--- DEBUG: PATCH ROUTE END ---');

  } catch (error) {
    console.error('--- DEBUG: PATCH ROUTE ERROR ---', error);
    res.status(500).json({ error: error.message });
  }
});

// Delete a workout
router.delete('/:id', verifyToken, checkRole(['member', 'trainer']), async (req, res) => {
  try {
    const workout = await Workout.findById(req.params.id);

    if (!workout) {
      return res.status(404).json({ error: 'Workout not found' });
    }

    // AUTH-CHECK: A user can delete their own workout. A trainer can delete their own
    // template, or any member's workout.
    const isUserOwner = workout.user?.equals(req.user._id);
    const isTrainerOwner = workout.trainer?.equals(req.user._id);
    const isTrainerAndMemberWorkout = req.user.role === 'trainer' && workout.user;

    const isAuthorized = isUserOwner || isTrainerOwner || isTrainerAndMemberWorkout;

    if (!isAuthorized) {
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