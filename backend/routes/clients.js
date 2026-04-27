
const express = require('express');
const router = express.Router();
const User = require('../models/User');
const Workout = require('../models/Workout');
const WorkoutPlan = require('../models/WorkoutPlan');
const { verifyToken, checkRole } = require('../middleware/auth');

// Get all clients for the logged-in trainer
router.get('/', verifyToken, checkRole(['trainer']), async (req, res) => {
  try {
    const trainer = await User.findById(req.user._id).populate('clients');
    res.json(trainer.clients);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Assign a workout plan to a client
router.post('/:memberId/assign-plan', verifyToken, checkRole(['trainer']), async (req, res) => {
  try {
    const { planId } = req.body;
    const member = await User.findById(req.params.memberId);
    const plan = await WorkoutPlan.findById(planId);

    if (!member || !plan) {
      return res.status(404).json({ error: 'Member or Plan not found' });
    }

    member.trainer = req.user._id;
    await member.save();

    // Create workout instances from the plan's templates
    for (const week of plan.weeks) {
      for (const day of week.workouts) {
        const template = await Workout.findById(day.workout);
        if (template) {
          const workoutInstance = new Workout({
            ...template.toObject(),
            _id: undefined, // Create a new ID
            isTemplate: false,
            assignedTo: member._id,
            date: new Date(), // Or calculate based on week/day
          });
          await workoutInstance.save();
        }
      }
    }

    res.json({ message: 'Plan assigned successfully' });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// Get a client's progress
router.get('/:memberId/progress', verifyToken, checkRole(['trainer']), async (req, res) => {
  try {
    const progress = await Workout.find({ assignedTo: req.params.memberId });
    res.json(progress);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Add/update private notes for a client
router.post('/:memberId/notes', verifyToken, checkRole(['trainer']), async (req, res) => {
  try {
    const { notes } = req.body;
    const client = await User.findById(req.params.memberId);
    if (!client) {
      return res.status(404).json({ error: 'Client not found' });
    }
    client.privateNotes = notes;
    await client.save();
    res.json(client);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

module.exports = router;
