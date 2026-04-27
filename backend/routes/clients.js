
const express = require('express');
const router = express.Router();
const User = require('../models/User');
const Workout = require('../models/Workout');
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

// Assign a workout to a client
router.post('/:memberId/assign-workout', verifyToken, checkRole(['trainer']), async (req, res) => {
  try {
    const { workoutId } = req.body;
    const member = await User.findById(req.params.memberId);
    const workoutTemplate = await Workout.findById(workoutId);

    if (!member || !workoutTemplate) {
      return res.status(404).json({ error: 'Member or Workout not found' });
    }

    const workoutInstance = new Workout({
      ...workoutTemplate.toObject(),
      _id: undefined,
      isTemplate: false,
      user: member._id,
      date: new Date(),
    });

    await workoutInstance.save();

    res.json({ message: 'Workout assigned successfully' });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// Remove a client from a trainer
router.delete('/:memberId/remove', verifyToken, checkRole(['trainer']), async (req, res) => {
  try {
    const trainer = await User.findById(req.user._id);
    const member = await User.findById(req.params.memberId);

    if (!member) {
      return res.status(404).json({ error: 'Member not found' });
    }

    // Remove client from trainer's list
    trainer.clients.pull(req.params.memberId);
    await trainer.save();

    // Clear trainer from member's profile
    member.trainer = null;
    await member.save();

    res.json({ message: 'Client removed successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;
