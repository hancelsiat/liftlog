
const express = require('express');
const mongoose = require('mongoose');
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
    const { memberId } = req.params;
    if (!mongoose.Types.ObjectId.isValid(memberId)) {
      return res.status(404).json({ error: 'We could not find this client in our records.' });
    }

    // Only the member's current trainer, or a trainer who still has them in
    // their client list (e.g. the member left), can see their plan.
    const [trainer, member] = await Promise.all([
      User.findById(req.user._id).select('clients'),
      User.findById(memberId).select('trainer')
    ]);
    if (!member) {
      return res.status(404).json({ error: 'We could not find this client in our records.' });
    }
    const trainerId = String(req.user._id);
    const isCurrentTrainer = String(member.trainer) === trainerId;
    const isInClientList = !!trainer && (trainer.clients || []).some((c) => String(c) === memberId);
    if (!isCurrentTrainer && !isInClientList) {
      return res.status(403).json({ error: 'This member is not one of your clients.' });
    }

    // Hide copies removed by admin moderation (or by the trainer deleting a
    // template with its copies), same as the member's own plan (/workouts/my-plan).
    const progress = await Workout.find({
      assignedTo: memberId,
      isTemplate: { $ne: true },
      isDeleted: { $ne: true }
    })
      .populate('trainer', 'username')
      .sort({ date: -1 });
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
      return res.status(404).json({ error: 'We could not find this client in our records.' });
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

    if (!member || !workoutTemplate || workoutTemplate.isDeleted) {
      return res.status(404).json({ error: 'The requested member or workout could not be found.' });
    }

    // Trainers can only assign their own templates, and only to their own clients.
    const trainerId = String(req.user._id);
    if (!workoutTemplate.isTemplate || String(workoutTemplate.trainer) !== trainerId) {
      return res.status(403).json({ error: 'You can only assign your own workouts.' });
    }
    if (String(member.trainer) !== trainerId) {
      return res.status(403).json({ error: 'This member is not one of your clients.' });
    }

    const workoutInstance = new Workout({
      ...workoutTemplate.toObject(),
      _id: undefined,
      createdAt: undefined,
      updatedAt: undefined,
      sourceTemplate: workoutTemplate._id,
      isTemplate: false,
      assignedTo: member._id,
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
      return res.status(404).json({ error: 'We could not find this member in our records.' });
    }

    // Remove client from trainer's list
    trainer.clients.pull(req.params.memberId);
    await trainer.save();

    // Clear trainer from member's profile, but only if it is this trainer.
    // Otherwise any trainer could unlink another trainer's client.
    if (String(member.trainer) === String(req.user._id)) {
      member.trainer = null;
      await member.save();
    }

    res.json({ message: 'Client removed successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Public trainer browser for members: See trainer bio/feedback notes BEFORE choosing a trainer
// Returns approved trainers with their public bio (notes/feedback). Ratings and detailed feedback
// can be fetched separately via the ratings route for full transparency before selection.
router.get('/trainers', verifyToken, async (req, res) => {
  try {
    const trainers = await User.find({
      role: 'trainer',
      isApproved: true,
      isEmailVerified: true
    })
    .select('username fullName bio profile.firstName profile.lastName email') // public fields only (no privateNotes)
    .sort({ createdAt: -1 });

    res.json({ 
      trainers,
      message: 'Trainers loaded successfully. Review bios and feedback before selecting a trainer.'
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;
