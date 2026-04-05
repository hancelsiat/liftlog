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
  try {
    const { name, ...workoutDetails } = req.body; // Separate name from the rest

    const workoutData = {
      ...workoutDetails,
      title: name, // Map the incoming 'name' to the schema's 'title' field
      trainer: req.user._id, // Securely assign the trainer from the token
      isPublic: true // Templates are always public
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

// Trainer: Get all workouts they have created
router.get('/my-creations', verifyToken, checkRole(['trainer']), async (req, res) => {
  try {
    const workouts = await Workout.find({ trainer: req.user._id })
      .sort({ createdAt: -1 });

    res.json({ workouts });
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

    // AUTH-CHECK: User can update their own workout. A trainer can update any user's workout, but only their own template.
    const isOwner = (workout.user && workout.user.toString() === req.user._id.toString()) || 
                    (workout.trainer && workout.trainer.toString() === req.user._id.toString());

    // A trainer is also allowed to edit any workout that is a user's log (not another trainer's template).
    const canTrainerEdit = req.user.role === 'trainer' && !!workout.user;

    if (!isOwner && !canTrainerEdit) {
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

    // AUTH-CHECK: User can delete their own workout. A trainer can delete any user's workout, or their own template.
    const isOwner = (workout.user && workout.user.toString() === req.user._id.toString()) || 
                    (workout.trainer && workout.trainer.toString() === req.user._id.toString());

    // A trainer is also allowed to delete any workout that is a user's log (not another trainer's template).
    const canTrainerDelete = req.user.role === 'trainer' && !!workout.user;

    if (!isOwner && !canTrainerDelete) {
      return res.status(403).json({ error: 'Unauthorized to delete this workout' });
    }

    await Workout.findByIdAndDelete(req.params.id);

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