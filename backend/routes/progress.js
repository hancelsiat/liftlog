const express = require('express');
const router = express.Router();
const Progress = require('../models/Progress');
const { verifyToken, checkRole } = require('../middleware/auth');

// Create a new progress entry (Weekly limit - ENFORCED)
router.post('/', verifyToken, async (req, res) => {
  try {
    // Check if user has a progress entry in the last 7 days
    const now = new Date();
    const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);

    console.log('=== PROGRESS RESTRICTION CHECK ===');
    console.log('Checking progress for user:', req.user._id);
    console.log('Current time:', now);
    console.log('Seven days ago:', sevenDaysAgo);

    const recentProgress = await Progress.findOne({
      user: req.user._id,
      createdAt: { $gte: sevenDaysAgo }
    }).sort({ createdAt: -1 });

    console.log('Recent progress found:', recentProgress);

    if (recentProgress) {
      const timeSinceLastUpdate = now - recentProgress.createdAt;
      const daysSinceLastUpdate = Math.floor(timeSinceLastUpdate / (1000 * 60 * 60 * 24));
      const daysUntilNextUpdate = Math.max(0, 7 - daysSinceLastUpdate);

      console.log('Days since last update:', daysSinceLastUpdate);
      console.log('Days until next update:', daysUntilNextUpdate);

      if (daysUntilNextUpdate > 0) {
        return res.status(400).json({
          error: 'You can only update your progress once per week',
          message: `Please wait ${daysUntilNextUpdate} more day(s) before updating again`,
          lastUpdateDate: recentProgress.createdAt,
          nextAllowedDate: new Date(recentProgress.createdAt.getTime() + 7 * 24 * 60 * 60 * 1000),
          canUpdateIn: daysUntilNextUpdate
        });
      }
    }

    const progressData = {
      ...req.body,
      user: req.user._id
    };

    const progress = new Progress(progressData);
    await progress.save();

    console.log('Progress saved successfully:', progress._id);

    res.status(201).json({
      message: 'Progress logged successfully',
      progress,
      nextAllowedDate: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)
    });
  } catch (error) {
    console.error('Error creating progress:', error);
    if (error.code === 11000) {
      res.status(400).json({ error: 'Progress entry already exists for this date' });
    } else {
      res.status(400).json({ error: error.message });
    }
  }
});

// Check if user can update progress
router.get('/can-update', verifyToken, async (req, res) => {
  try {
    const now = new Date();
    const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);

    const recentProgress = await Progress.findOne({
      user: req.user._id,
      createdAt: { $gte: sevenDaysAgo }
    }).sort({ createdAt: -1 });

    if (recentProgress) {
      const timeSinceLastUpdate = now - recentProgress.createdAt;
      const daysSinceLastUpdate = Math.floor(timeSinceLastUpdate / (1000 * 60 * 60 * 24));
      const daysUntilNextUpdate = Math.max(0, 7 - daysSinceLastUpdate);

      return res.json({
        canUpdate: daysUntilNextUpdate === 0,
        lastUpdateDate: recentProgress.createdAt,
        nextAllowedDate: new Date(recentProgress.createdAt.getTime() + 7 * 24 * 60 * 60 * 1000),
        daysUntilNextUpdate,
        message: daysUntilNextUpdate > 0 
          ? `You can update your progress in ${daysUntilNextUpdate} day(s)`
          : 'You can update your progress now'
      });
    }

    res.json({
      canUpdate: true,
      message: 'You can update your progress now'
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
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
