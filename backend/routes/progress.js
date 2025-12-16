const express = require('express');
const router = express.Router();
const Progress = require('../models/Progress');
const { verifyToken, checkRole } = require('../middleware/auth');

// Create or update progress entry with separate time restrictions
// BMI: 7 days, Calories: 24 hours
router.post('/', verifyToken, async (req, res) => {
  try {
    const { bmi, caloriesIntake, calorieDeficit } = req.body;
    const now = new Date();

    console.log('=== PROGRESS UPDATE REQUEST ===');
    console.log('User:', req.user._id);
    console.log('BMI:', bmi);
    console.log('Calories Intake:', caloriesIntake);
    console.log('Calorie Deficit:', calorieDeficit);
    console.log('Code Version: v2.0 - Fixed null validation');

    // Get or create user's progress document
    let progress = await Progress.findOne({ user: req.user._id }).sort({ createdAt: -1 });
    
    if (!progress) {
      // First time user - create new progress
      // Only include fields that have actual values
      const firstProgressData = {
        user: req.user._id,
        lastBmiUpdate: bmi ? now : null,
        lastCaloriesUpdate: (caloriesIntake || calorieDeficit) ? now : null
      };

      // Only add fields if they have values
      if (bmi !== null && bmi !== undefined) {
        firstProgressData.bmi = bmi;
      }
      if (caloriesIntake !== null && caloriesIntake !== undefined) {
        firstProgressData.caloriesIntake = caloriesIntake;
      }
      if (calorieDeficit !== null && calorieDeficit !== undefined) {
        firstProgressData.calorieDeficit = calorieDeficit;
      }

      progress = new Progress(firstProgressData);
      await progress.save({ validateBeforeSave: false });
      
      return res.status(201).json({
        message: 'Progress logged successfully',
        progress,
        bmiNextUpdate: bmi ? new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000) : null,
        caloriesNextUpdate: (caloriesIntake || calorieDeficit) ? new Date(now.getTime() + 24 * 60 * 60 * 1000) : null
      });
    }

    // Check restrictions for existing user
    const updateData = {};
    const restrictions = {};

    // Check BMI restriction (7 days)
    if (bmi !== undefined && bmi !== null) {
      // Manual check if methods don't exist
      const canUpdateBmi = progress.lastBmiUpdate 
        ? (now - new Date(progress.lastBmiUpdate)) / (1000 * 60 * 60 * 24) >= 7
        : true;
      
      if (!canUpdateBmi) {
        const daysSinceUpdate = (now - new Date(progress.lastBmiUpdate)) / (1000 * 60 * 60 * 24);
        const daysUntil = Math.max(0, Math.ceil(7 - daysSinceUpdate));
        restrictions.bmi = {
          canUpdate: false,
          message: `BMI can be updated in ${daysUntil} day(s)`,
          nextAllowedDate: new Date(progress.lastBmiUpdate.getTime() + 7 * 24 * 60 * 60 * 1000),
          daysUntilNext: daysUntil
        };
      } else {
        updateData.bmi = bmi;
        updateData.lastBmiUpdate = now;
      }
    }

    // Check Calories restriction (24 hours)
    // Both caloriesIntake and calorieDeficit must be provided together
    const hasCaloriesData = (caloriesIntake !== undefined && caloriesIntake !== null) || 
                            (calorieDeficit !== undefined && calorieDeficit !== null);
    
    if (hasCaloriesData) {
      // Validate that both fields are provided
      if ((caloriesIntake === undefined || caloriesIntake === null) || 
          (calorieDeficit === undefined || calorieDeficit === null)) {
        return res.status(400).json({
          error: 'Both caloriesIntake and calorieDeficit are required when updating calories'
        });
      }

      // Manual check if methods don't exist
      const canUpdateCalories = progress.lastCaloriesUpdate
        ? (now - new Date(progress.lastCaloriesUpdate)) / (1000 * 60 * 60) >= 24
        : true;
      
      if (!canUpdateCalories) {
        const hoursSinceUpdate = (now - new Date(progress.lastCaloriesUpdate)) / (1000 * 60 * 60);
        const hoursUntil = Math.max(0, Math.ceil(24 - hoursSinceUpdate));
        restrictions.calories = {
          canUpdate: false,
          message: `Calories can be updated in ${hoursUntil} hour(s)`,
          nextAllowedDate: new Date(progress.lastCaloriesUpdate.getTime() + 24 * 60 * 60 * 1000),
          hoursUntilNext: hoursUntil
        };
      } else {
        updateData.caloriesIntake = caloriesIntake;
        updateData.calorieDeficit = calorieDeficit;
        updateData.lastCaloriesUpdate = now;
      }
    }

    // If there are any restrictions, return error immediately
    if (Object.keys(restrictions).length > 0) {
      return res.status(400).json({
        error: 'Update restricted',
        restrictions
      });
    }

    // If no fields to update, return error
    if (Object.keys(updateData).length === 0) {
      return res.status(400).json({
        error: 'No fields to update'
      });
    }

    // Create new progress entry with updated values
    // Only include fields that have actual values (not null/undefined)
    const newProgressData = {
      user: req.user._id,
      lastBmiUpdate: updateData.lastBmiUpdate || progress.lastBmiUpdate,
      lastCaloriesUpdate: updateData.lastCaloriesUpdate || progress.lastCaloriesUpdate
    };

    // Only add BMI if it has a value
    const bmiValue = updateData.bmi !== undefined ? updateData.bmi : progress.bmi;
    if (bmiValue !== null && bmiValue !== undefined) {
      newProgressData.bmi = bmiValue;
    }

    // Only add calories fields if they have values
    const caloriesIntakeValue = updateData.caloriesIntake !== undefined ? updateData.caloriesIntake : progress.caloriesIntake;
    if (caloriesIntakeValue !== null && caloriesIntakeValue !== undefined) {
      newProgressData.caloriesIntake = caloriesIntakeValue;
    }

    const calorieDeficitValue = updateData.calorieDeficit !== undefined ? updateData.calorieDeficit : progress.calorieDeficit;
    if (calorieDeficitValue !== null && calorieDeficitValue !== undefined) {
      newProgressData.calorieDeficit = calorieDeficitValue;
    }

    const newProgress = new Progress(newProgressData);
    await newProgress.save({ validateBeforeSave: false });

    console.log('Progress updated successfully:', newProgress._id);

    res.status(201).json({
      message: 'Progress updated successfully',
      progress: newProgress,
      updated: Object.keys(updateData),
      restrictions: Object.keys(restrictions).length > 0 ? restrictions : undefined,
      bmiNextUpdate: updateData.lastBmiUpdate ? new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000) : null,
      caloriesNextUpdate: updateData.lastCaloriesUpdate ? new Date(now.getTime() + 24 * 60 * 60 * 1000) : null
    });
  } catch (error) {
    console.error('Error updating progress:', error);
    res.status(400).json({ error: error.message });
  }
});

// Check if user can update progress (separate for BMI and Calories)
router.get('/can-update', verifyToken, async (req, res) => {
  try {
    const progress = await Progress.findOne({ user: req.user._id }).sort({ createdAt: -1 });

    if (!progress) {
      // First time user - can update everything
      return res.json({
        bmi: {
          canUpdate: true,
          message: 'You can update your BMI now'
        },
        calories: {
          canUpdate: true,
          message: 'You can update your calories now'
        }
      });
    }

    // Check BMI status (7 days restriction) - manual calculation
    const now = new Date();
    const canUpdateBmi = progress.lastBmiUpdate 
      ? (now - new Date(progress.lastBmiUpdate)) / (1000 * 60 * 60 * 24) >= 7
      : true;
    
    const daysSinceLastBmiUpdate = progress.lastBmiUpdate
      ? (now - new Date(progress.lastBmiUpdate)) / (1000 * 60 * 60 * 24)
      : 0;
    const daysUntilBmi = Math.max(0, Math.ceil(7 - daysSinceLastBmiUpdate));
    
    const bmiNextUpdate = progress.lastBmiUpdate 
      ? new Date(progress.lastBmiUpdate.getTime() + 7 * 24 * 60 * 60 * 1000)
      : null;

    // Check Calories status (24 hours restriction) - manual calculation
    const canUpdateCalories = progress.lastCaloriesUpdate
      ? (now - new Date(progress.lastCaloriesUpdate)) / (1000 * 60 * 60) >= 24
      : true;
    
    const hoursSinceLastCaloriesUpdate = progress.lastCaloriesUpdate
      ? (now - new Date(progress.lastCaloriesUpdate)) / (1000 * 60 * 60)
      : 0;
    const hoursUntilCalories = Math.max(0, Math.ceil(24 - hoursSinceLastCaloriesUpdate));
    
    const caloriesNextUpdate = progress.lastCaloriesUpdate
      ? new Date(progress.lastCaloriesUpdate.getTime() + 24 * 60 * 60 * 1000)
      : null;

    res.json({
      bmi: {
        canUpdate: canUpdateBmi,
        lastUpdate: progress.lastBmiUpdate,
        nextAllowedDate: bmiNextUpdate,
        daysUntilNext: daysUntilBmi,
        message: canUpdateBmi 
          ? 'You can update your BMI now'
          : `BMI can be updated in ${daysUntilBmi} day(s)`
      },
      calories: {
        canUpdate: canUpdateCalories,
        lastUpdate: progress.lastCaloriesUpdate,
        nextAllowedDate: caloriesNextUpdate,
        hoursUntilNext: hoursUntilCalories,
        message: canUpdateCalories
          ? 'You can update your calories now'
          : `Calories can be updated in ${hoursUntilCalories} hour(s)`
      }
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

// TEMPORARY: Admin route to delete all progress (for testing)
router.delete('/admin/delete-all', verifyToken, checkRole(['admin']), async (req, res) => {
  try {
    const result = await Progress.deleteMany({});
    
    res.json({
      success: true,
      message: `Deleted ${result.deletedCount} progress entries. You can now create fresh progress data.`
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// TEMPORARY: Admin route to fix database schema
router.post('/admin/fix-schema', verifyToken, checkRole(['admin']), async (req, res) => {
  try {
    const mongoose = require('mongoose');
    const db = mongoose.connection.db;
    
    console.log('Attempting to fix Progress collection schema...');
    
    // OPTION 1: Try to remove validator completely
    try {
      await db.command({
        collMod: 'progresses',
        validator: {},
        validationLevel: 'off'
      });
      console.log('✅ Validator removed completely!');
      
      return res.json({
        success: true,
        message: 'Database validator removed. Mongoose will handle all validation now.'
      });
    } catch (error1) {
      console.log('Could not remove validator, trying to update it...', error1.message);
      
      // OPTION 2: Update validator to make fields optional
      try {
        await db.command({
          collMod: 'progresses',
          validator: {
            $jsonSchema: {
              bsonType: 'object',
              required: ['user'],
              properties: {
                user: {
                  bsonType: 'objectId'
                }
              }
            }
          },
          validationLevel: 'moderate',
          validationAction: 'warn'
        });
        console.log('✅ Validator updated to minimal schema!');
        
        return res.json({
          success: true,
          message: 'Database validator updated. Only user field is required now.'
        });
      } catch (error2) {
        console.log('Could not update validator:', error2.message);
        
        if (error2.code === 26) {
          return res.json({
            success: true,
            message: 'Collection has no validator - Mongoose handles validation.'
          });
        }
        
        throw error2;
      }
    }
  } catch (error) {
    console.error('Error fixing schema:', error);
    
    res.status(500).json({
      success: false,
      error: error.message,
      details: 'Try deleting all progress entries and recreating them.'
    });
  }
});

module.exports = router;
