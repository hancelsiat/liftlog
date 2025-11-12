const express = require('express');
const router = express.Router();
const Progress = require('../models/Progress');
const { verifyToken, checkRole } = require('../middleware/auth');

// Create a new progress entry
router.post('/', verifyToken, async (req, res) => {
  try {
    const progressData = {
      ...req.body,
      user: req.user._id
    };

    const progress = new Progress(progressData);
    await progress.save();

    res.status(201).json({
      message: 'Progress logged successfully',
      progress
    });
  } catch (error) {
    if (error.code === 11000) {
      res.status(400).json({ error: 'Progress entry already exists for this date' });
    } else {
      res.status(400).json({ error: error.message });
    }
  }
});

// Get user's progress history
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

    const progress = await Progress.find(query)
      .sort({ date: -1 })
      .limit(Number(limit))
      .skip((page - 1) * limit);

    const total = await Progress.countDocuments(query);

    res.json({
      progress,
      totalProgress: total,
      currentPage: page,
      totalPages: Math.ceil(total / limit)
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get a specific progress entry by ID
router.get('/:id', verifyToken, async (req, res) => {
  try {
    const progress = await Progress.findById(req.params.id);

    if (!progress) {
      return res.status(404).json({ error: 'Progress entry not found' });
    }

    // Ensure user can only access their own progress
    if (progress.user.toString() !== req.user._id.toString()) {
      return res.status(403).json({ error: 'Unauthorized access' });
    }

    res.json(progress);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Update a progress entry
router.patch('/:id', verifyToken, async (req, res) => {
  try {
    const progress = await Progress.findById(req.params.id);

    if (!progress) {
      return res.status(404).json({ error: 'Progress entry not found' });
    }

    // Ensure user can only update their own progress
    if (progress.user.toString() !== req.user._id.toString()) {
      return res.status(403).json({ error: 'Unauthorized to update this progress entry' });
    }

    const updatedProgress = await Progress.findByIdAndUpdate(
      req.params.id,
      req.body,
      { new: true, runValidators: true }
    );

    res.json({
      message: 'Progress updated successfully',
      progress: updatedProgress
    });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// Delete a progress entry
router.delete('/:id', verifyToken, async (req, res) => {
  try {
    const progress = await Progress.findById(req.params.id);

    if (!progress) {
      return res.status(404).json({ error: 'Progress entry not found' });
    }

    // Ensure user can only delete their own progress
    if (progress.user.toString() !== req.user._id.toString()) {
      return res.status(403).json({ error: 'Unauthorized to delete this progress entry' });
    }

    await progress.remove();

    res.json({ message: 'Progress entry deleted successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Trainer: Get progress for a specific user
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

      const progress = await Progress.find(query)
        .sort({ date: -1 })
        .limit(Number(limit))
        .skip((page - 1) * limit);

      const total = await Progress.countDocuments(query);

      res.json({
        progress,
        totalProgress: total,
        currentPage: page,
        totalPages: Math.ceil(total / limit)
      });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
});

module.exports = router;
