
const express = require('express');
const router = express.Router();
const WorkoutPlan = require('../models/WorkoutPlan');
const { verifyToken, checkRole } = require('../middleware/auth');

// Create a new workout plan
router.post('/', verifyToken, checkRole(['trainer']), async (req, res) => {
  try {
    const { name, description, weeks } = req.body;
    const plan = new WorkoutPlan({
      name,
      description,
      weeks,
      trainer: req.user._id
    });
    await plan.save();
    res.status(201).json(plan);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// Get all workout plans for the logged-in trainer
router.get('/', verifyToken, checkRole(['trainer']), async (req, res) => {
  try {
    const plans = await WorkoutPlan.find({ trainer: req.user._id });
    res.json(plans);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;
