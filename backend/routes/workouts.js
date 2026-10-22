
const express = require('express');
const mongoose = require('mongoose');
const router = express.Router();
const Workout = require('../models/Workout');
const User = require('../models/User');
const emailService = require('../services/emailService');
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
    const workout = new Workout({
      title: req.body.title,
      description: req.body.description,
      exercises: req.body.exercises,
      // Picked in the app's create screen; the schema validates the values.
      category: req.body.category || undefined,
      intensity: req.body.intensity || undefined,
      duration: req.body.duration ?? undefined,
      caloriesBurned: req.body.caloriesBurned ?? undefined,
      trainer: req.user._id,
      isTemplate: true
    });
    await workout.save();
    await workout.populate('trainer', 'username _id');

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
      endDate
    } = req.query;

    const query = { user: req.user._id, isTemplate: { $ne: true } };

    if (startDate && endDate) {
      query.date = {
        $gte: new Date(startDate),
        $lte: new Date(endDate)
      };
    }

    const workouts = await Workout.find(query)
      .populate('trainer', 'username')
      .sort({ date: -1 });

    const total = await Workout.countDocuments(query);

    res.json({
      workouts,
      totalWorkouts: total,
      currentPage: 1,
      totalPages: 1
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

router.get('/trainer', verifyToken, checkRole(['trainer']), async (req, res) => {
  try {
    const workouts = await Workout.find({ trainer: req.user._id, isTemplate: true, isDeleted: { $ne: true } }).populate('trainer', 'username _id');
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
      isApproved: true // Ensure the trainer is actually approved by admin!
    }).select('username fullName email bio profile.firstName profile.lastName isApproved');

    res.json({ trainers });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Member: Get assigned workouts
router.get('/my-plan', verifyToken, checkRole(['member']), async (req, res) => {
  try {
    const workouts = await Workout.find({ assignedTo: req.user._id, isTemplate: false, isDeleted: { $ne: true } })
      .populate('trainer', 'username')
      .sort({ date: -1 });
    res.json(workouts);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Trainer: "Recently deleted" templates (own deletions and admin removals that
// were not deleted permanently). Declared before /trainer/:trainerId.
router.get('/trainer/deleted', verifyToken, checkRole(['trainer']), async (req, res) => {
  try {
    const workouts = await Workout.find({
      trainer: req.user._id,
      isTemplate: true,
      isDeleted: true,
      purgedAt: { $exists: false }
    })
      .populate('trainer', 'username _id')
      .sort({ deletedAt: -1 });
    res.json({ workouts });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get workouts by trainer (Member Route)
router.get('/trainer/:trainerId', verifyToken, checkRole(['all']), async (req, res) => {
  try {
    const { trainerId } = req.params;

    const workouts = await Workout.find({
      trainer: trainerId,
      isTemplate: true, // Templates are the public workouts for a trainer!
      isDeleted: { $ne: true } // Hide workouts removed by admin moderation
    })
      .populate('trainer', 'username')
      .sort({ createdAt: -1 });

    const total = await Workout.countDocuments({
      trainer: trainerId,
      isTemplate: true,
      isDeleted: { $ne: true }
    });

    res.json({
      workouts,
      totalWorkouts: total,
      currentPage: 1,
      totalPages: 1
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get a specific workout by ID
router.get('/:id', verifyToken, async (req, res) => {
  try {
    const workout = await Workout.findById(req.params.id)
      .populate('trainer', 'username')
      .populate('user', 'username');

    if (!workout) {
      return res.status(404).json({ error: 'We could not find this workout.' });
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
      return res.status(404).json({ error: 'We could not find this workout to update.' });
    }

    // Authorization check (copied from admin logic)
    const isOwner = workout.user?.equals(req.user._id) || workout.trainer?.equals(req.user._id);
    const canTrainerEdit = req.user.role === 'trainer' && !!workout.user;

    if (!isOwner && !canTrainerEdit) {
      return res.status(403).json({ error: 'You do not have permission to update this workout.' });
    }

    // Removed workouts can't be edited. Otherwise a trainer could clear
    // isDeleted and bring back a template an admin removed.
    if (workout.isDeleted) {
      return res.status(404).json({ error: 'We could not find this workout to update.' });
    }

    // Only content fields can be edited. Moderation, ownership and restore
    // fields (isDeleted, deletedBy, trainer, user, purgedAt, ...) cannot.
    const EDITABLE = ['title', 'description', 'exercises', 'category', 'intensity',
      'duration', 'caloriesBurned', 'notes', 'date', 'completedAt', 'isPublic'];
    const updates = {};
    for (const key of EDITABLE) {
      if (req.body[key] !== undefined) updates[key] = req.body[key];
    }
    // Older app versions send the title as `name`.
    if (updates.title === undefined && typeof req.body.name === 'string') {
      updates.title = req.body.name;
    }
    if (typeof updates.title === 'string') {
      updates.title = updates.title.trim();
      if (!updates.title) {
        return res.status(400).json({ error: 'Please provide a title for the workout.' });
      }
    }

    const updatedWorkout = await Workout.findByIdAndUpdate(
      req.params.id,
      { $set: updates },
      { new: true }
    ).populate('trainer', 'username _id');

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

    if (!workout || workout.isDeleted) {
      return res.status(404).json({ error: 'We could not find this workout to delete.' });
    }

    // Authorization check (copied from update logic)
    const isOwner = workout.user?.equals(req.user._id) || workout.trainer?.equals(req.user._id);
    const canTrainerDelete = req.user.role === 'trainer' && !!workout.user;

    if (!isOwner && !canTrainerDelete) {
      return res.status(403).json({ error: 'You do not have permission to delete this workout.' });
    }

    if (workout.isTemplate) {
      // Trainer templates are soft deleted so admins can see in Content
      // moderation that the trainer deleted them.
      workout.isDeleted = true;
      workout.deletedBy = req.user._id;
      workout.deletedByRole = 'trainer';
      workout.deletedAt = new Date();
      workout.deletionReason = 'Deleted by the trainer.';
      await workout.save({ validateBeforeSave: false });
    } else {
      // Personal workout logs are not moderated content: remove them.
      await workout.remove();
    }

    res.json({ message: 'Workout deleted successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

router.delete('/', verifyToken, checkRole(['trainer']), async (req, res) => {
  try {
    const { workoutIds } = req.body;

    if (!workoutIds || !Array.isArray(workoutIds) || workoutIds.length === 0) {
      return res.status(400).json({ error: 'Workout IDs must be a non-empty array' });
    }

    const validIds = workoutIds.filter((id) => mongoose.Types.ObjectId.isValid(id));
    // Ensure trainer can only delete their own workouts
    const ownFilter = {
      _id: { $in: validIds },
      trainer: req.user._id,
      isDeleted: { $ne: true }
    };

    // Templates are soft deleted so admins can see in Content moderation
    // that the trainer deleted them.
    const softResult = await Workout.updateMany(
      { ...ownFilter, isTemplate: true },
      {
        $set: {
          isDeleted: true,
          deletedBy: req.user._id,
          deletedByRole: 'trainer',
          deletedAt: new Date(),
          deletionReason: 'Deleted by the trainer.'
        }
      }
    );
    // Anything else (non-template copies) is removed as before.
    const hardResult = await Workout.deleteMany({ ...ownFilter, isTemplate: { $ne: true } });

    const deletedCount =
      (softResult.modifiedCount || softResult.nModified || 0) + (hardResult.deletedCount || 0);

    if (deletedCount === 0) {
      return res.status(404).json({ error: 'No matching workouts found to delete' });
    }

    console.log(`[TRAINER] ${deletedCount} workout(s) deleted by trainer ${req.user._id}`);
    res.json({ message: `${deletedCount} workouts deleted successfully`, deletedCount });

  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

function markRestored(workout, user, role) {
  workout.isDeleted = false;
  workout.deletedBy = undefined;
  workout.deletedByRole = undefined;
  workout.deletedAt = undefined;
  workout.deletionReason = undefined;
  workout.restoredAt = new Date();
  workout.restoredBy = user._id;
  workout.restoredByRole = role;
}

// Finds an own template in "Recently deleted" (not deleted permanently).
async function findOwnDeletedTemplate(req, res) {
  if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
    res.status(404).json({ error: 'We could not find this workout.' });
    return null;
  }
  const workout = await Workout.findById(req.params.id);
  if (!workout || !workout.isTemplate || !workout.trainer?.equals(req.user._id) || workout.purgedAt) {
    res.status(404).json({ error: 'We could not find this workout.' });
    return null;
  }
  if (!workout.isDeleted) {
    res.status(400).json({ error: 'This workout is not deleted.' });
    return null;
  }
  return workout;
}

// Trainer: restore a template they deleted. Members can see it again.
// Templates removed by an admin can only be restored by an admin.
router.post('/:id/restore', verifyToken, checkRole(['trainer']), async (req, res) => {
  try {
    const workout = await findOwnDeletedTemplate(req, res);
    if (!workout) return;
    if (workout.deletedByRole !== 'trainer') {
      return res.status(403).json({
        error: 'This workout was removed by an administrator. Only an admin can restore it.'
      });
    }

    markRestored(workout, req.user, 'trainer');
    await workout.save({ validateBeforeSave: false });
    console.log(`[TRAINER] Workout ${workout._id} restored by trainer ${req.user._id}`);
    res.json({ message: 'Workout restored', workout });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Trainer: delete a template in "Recently deleted" forever. It disappears from
// the trainer's app; the record stays as a tombstone (purgedAt) so admin
// moderation keeps the history.
router.delete('/:id/permanent', verifyToken, checkRole(['trainer']), async (req, res) => {
  try {
    const workout = await findOwnDeletedTemplate(req, res);
    if (!workout) return;

    workout.purgedAt = new Date();
    await workout.save({ validateBeforeSave: false });
    console.log(`[TRAINER] Workout ${workout._id} permanently deleted by trainer ${req.user._id}`);
    res.json({ message: 'Workout permanently deleted' });
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

      const query = { 
        user: req.params.userId, 
        isDeleted: { $ne: true } 
      };

      if (startDate && endDate) {
        query.date = {
          $gte: new Date(startDate),
          $lte: new Date(endDate)
        };
      }

      const workouts = await Workout.find(query)
        .populate('trainer', 'username')
        .populate('user', 'username')
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

// Mark a workout as complete
router.post('/:workoutId/complete', verifyToken, checkRole(['member']), async (req, res) => {
  try {
    const workout = await Workout.findById(req.params.workoutId);
    if (!workout) {
      return res.status(404).json({ error: 'We could not find this workout.' });
    }

    if (workout.assignedTo.toString() !== req.user._id.toString()) {
      return res.status(403).json({ error: 'You do not have permission to mark this workout as complete.' });
    }

    workout.completedAt = new Date();
    await workout.save();

    res.json({ message: 'Workout marked as complete', workout });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

const escapeHtml = (value) => String(value == null ? '' : value)
  .replace(/&/g, '&amp;')
  .replace(/</g, '&lt;')
  .replace(/>/g, '&gt;')
  .replace(/"/g, '&quot;')
  .replace(/'/g, '&#39;');

const escapeRegex = (value) => String(value).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

// Admin: list trainer-created workouts for moderation
// Query: ?status=active|deleted|trainer|all (default active), ?search=<title/trainer>, ?trainerId=<id>
// 'deleted' = every removed template, 'trainer' = only templates the trainer deleted themselves.
// Only trainer templates are listed (personal member logs are not public content).
router.get('/admin/all', verifyToken, checkRole(['admin']), async (req, res) => {
  try {
    const status = (req.query.status || 'active').toString().toLowerCase();
    if (!['active', 'deleted', 'trainer', 'all'].includes(status)) {
      return res.status(400).json({ error: 'Invalid status filter. Use active, deleted, trainer or all.' });
    }

    const query = { isTemplate: true };
    if (status === 'active') query.isDeleted = { $ne: true };
    if (status === 'deleted') query.isDeleted = true;
    if (status === 'trainer') {
      query.isDeleted = true;
      query.deletedByRole = 'trainer';
    }
    if (req.query.trainerId) {
      if (!mongoose.Types.ObjectId.isValid(req.query.trainerId)) {
        return res.status(400).json({ error: 'Invalid trainer ID.' });
      }
      query.trainer = req.query.trainerId;
    }

    const search = (req.query.search || '').toString().trim();
    if (search) {
      const rx = new RegExp(escapeRegex(search), 'i');
      const matchingTrainers = await User.find({ username: rx, role: 'trainer' }).select('_id');
      query.$or = [
        { title: rx },
        { description: rx },
        { 'exercises.name': rx },
        { trainer: { $in: matchingTrainers.map((t) => t._id) } }
      ];
    }

    const workouts = await Workout.find(query)
      .populate('trainer', 'username email')
      .populate('deletedBy', 'username')
      .populate('restoredBy', 'username')
      .sort({ createdAt: -1 })
      .limit(200)
      .lean();

    // How many members currently have a copy of each template
    const ids = workouts.map((w) => w._id);
    const assignedCounts = await Workout.aggregate([
      { $match: { sourceTemplate: { $in: ids }, isDeleted: { $ne: true } } },
      { $group: { _id: '$sourceTemplate', count: { $sum: 1 } } }
    ]);
    const countMap = new Map(assignedCounts.map((c) => [c._id.toString(), c.count]));
    workouts.forEach((w) => { w.assignedCount = countMap.get(w._id.toString()) || 0; });

    const [activeCount, deletedCount, trainerDeletedCount] = await Promise.all([
      Workout.countDocuments({ isTemplate: true, isDeleted: { $ne: true } }),
      Workout.countDocuments({ isTemplate: true, isDeleted: true }),
      Workout.countDocuments({ isTemplate: true, isDeleted: true, deletedByRole: 'trainer' })
    ]);

    res.json({ workouts, activeCount, deletedCount, trainerDeletedCount });
  } catch (error) {
    console.error('Admin workouts list error:', error);
    res.status(500).json({ error: error.message || 'Failed to load workouts for moderation' });
  }
});

// Admin only: Soft delete inappropriate workout with detailed reason
// Part of Admin Settings. Records deletionReason, deletedBy, deletedAt for audit.
// Notifies the owner/trainer with the reason. Uses soft delete so data is preserved for review.
router.delete('/admin/:id', verifyToken, checkRole(['admin']), async (req, res) => {
  try {
    const { reason } = req.body;
    if (!reason || reason.trim().length < 10) {
      return res.status(400).json({ 
        error: 'A detailed deletion reason is required (minimum 10 characters).' 
      });
    }

    const workout = await Workout.findById(req.params.id);
    if (!workout) {
      return res.status(404).json({ error: 'We could not find this workout.' });
    }

    if (workout.isDeleted) {
      return res.status(400).json({ error: 'This workout has already been deleted.' });
    }

    const trimmedReason = reason.trim().slice(0, 500);
    const deletedAt = new Date();

    // Soft delete with full audit trail
    workout.isDeleted = true;
    workout.deletionReason = trimmedReason;
    workout.deletedBy = req.user._id;
    workout.deletedByRole = 'admin';
    workout.deletedAt = deletedAt;
    await workout.save({ validateBeforeSave: false });

    // Also hide copies of this template already assigned to members (default on).
    // Legacy copies made before `sourceTemplate` existed are matched by trainer + title.
    let removedCopies = 0;
    const removeCopies = req.body.removeAssignedCopies !== false;
    if (workout.isTemplate && removeCopies) {
      const copyFilter = {
        isTemplate: { $ne: true },
        isDeleted: { $ne: true },
        $or: [
          { sourceTemplate: workout._id },
          { sourceTemplate: { $exists: false }, trainer: workout.trainer, title: workout.title, assignedTo: { $exists: true } }
        ]
      };
      const copyResult = await Workout.updateMany(copyFilter, {
        $set: {
          isDeleted: true,
          deletionReason: trimmedReason,
          deletedBy: req.user._id,
          deletedByRole: 'admin',
          deletedAt
        }
      });
      removedCopies = copyResult.modifiedCount || copyResult.nModified || 0;
    }

    // Notify the relevant user (owner or assigned trainer)
    try {
      const ownerId = workout.user || workout.assignedTo || workout.trainer;
      const owner = await User.findById(ownerId).select('email username');
      const ownerEmail = owner ? owner.email : null;
      if (ownerEmail) {
        await emailService.sendEmail(ownerEmail, 'Your workout has been removed - Moderation Notice', `
            <h2>Workout Moderation Notice</h2>
            <p>Dear ${escapeHtml(owner.username || 'User')},</p>
            <p>Your workout titled "<strong>${escapeHtml(workout.title)}</strong>" has been removed by an administrator.</p>
            <p><strong>Reason for deletion:</strong> ${escapeHtml(trimmedReason)}</p>
            <p>This action was taken to maintain appropriate content standards in the community.</p>
            <p>If you believe this was an error, please contact admin support.</p>
            <p>Workout ID: ${workout._id}</p>
            <p>Best regards,<br>LiftLog Admin Team</p>
          `);
        console.log(`Deletion notification email sent to ${owner.username || ownerEmail}`);
      }
    } catch (emailErr) {
      console.warn('Email notification for workout deletion failed (non-blocking):', emailErr.message);
    }

    console.log(`[ADMIN] Workout ${req.params.id} marked deleted by ${req.user._id}. Reason: ${trimmedReason}`);

    res.json({ 
      message: removedCopies > 0
        ? `Workout removed and hidden from ${removedCopies} member plan(s). Owner notified with reason.`
        : 'Workout successfully removed for inappropriate content. Owner notified with reason.',
      deletionReason: trimmedReason,
      workoutId: workout._id,
      removedCopies
    });
  } catch (error) {
    console.error('Admin workout delete error:', error);
    res.status(500).json({ error: error.message || 'Failed to delete workout' });
  }
});

// Admin: undo a moderation removal. Member copies hidden by that same removal
// (same deletedAt) are restored too. Templates the trainer deleted themselves
// can only be restored by that trainer.
router.post('/admin/:id/restore', verifyToken, checkRole(['admin']), async (req, res) => {
  try {
    if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
      return res.status(404).json({ error: 'We could not find this workout.' });
    }
    const workout = await Workout.findById(req.params.id);
    if (!workout) {
      return res.status(404).json({ error: 'We could not find this workout.' });
    }
    if (!workout.isDeleted) {
      return res.status(400).json({ error: 'This workout is not removed.' });
    }
    if (workout.purgedAt) {
      return res.status(410).json({ error: 'The trainer deleted this workout permanently.' });
    }
    if (workout.deletedByRole === 'trainer') {
      return res.status(403).json({
        error: 'The trainer deleted this workout. Only the trainer can restore it.'
      });
    }

    const removedAt = workout.deletedAt;
    markRestored(workout, req.user, 'admin');
    await workout.save({ validateBeforeSave: false });

    let restoredCopies = 0;
    if (workout.isTemplate && removedAt) {
      const copyResult = await Workout.updateMany(
        {
          isTemplate: { $ne: true },
          isDeleted: true,
          deletedAt: removedAt,
          $or: [
            { sourceTemplate: workout._id },
            { sourceTemplate: { $exists: false }, trainer: workout.trainer, title: workout.title, assignedTo: { $exists: true } }
          ]
        },
        {
          $set: { isDeleted: false, restoredAt: new Date(), restoredBy: req.user._id, restoredByRole: 'admin' },
          $unset: { deletedBy: '', deletedByRole: '', deletedAt: '', deletionReason: '' }
        }
      );
      restoredCopies = copyResult.modifiedCount || copyResult.nModified || 0;
    }

    try {
      const ownerId = workout.user || workout.assignedTo || workout.trainer;
      const owner = await User.findById(ownerId).select('email username');
      if (owner && owner.email) {
        await emailService.sendEmail(owner.email, 'Your workout has been restored', `
            <h2>Workout Restored</h2>
            <p>Dear ${escapeHtml(owner.username || 'User')},</p>
            <p>Your workout titled "<strong>${escapeHtml(workout.title)}</strong>" has been reviewed and restored by an administrator. It is visible again.</p>
            <p>Workout ID: ${workout._id}</p>
            <p>Best regards,<br>LiftLog Admin Team</p>
          `);
      }
    } catch (emailErr) {
      console.warn('Email notification for workout restore failed (non-blocking):', emailErr.message);
    }

    console.log(`[ADMIN] Workout ${workout._id} restored by ${req.user._id} (${restoredCopies} member copies)`);
    res.json({
      message: restoredCopies > 0
        ? `Workout restored and back in ${restoredCopies} member plan(s). Owner notified.`
        : 'Workout restored. Owner notified.',
      workoutId: workout._id,
      restoredCopies
    });
  } catch (error) {
    console.error('Admin workout restore error:', error);
    res.status(500).json({ error: error.message || 'Failed to restore workout' });
  }
});

module.exports = router;
