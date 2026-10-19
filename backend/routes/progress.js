const express = require('express');
const mongoose = require('mongoose');
const router = express.Router();
const Progress = require('../models/Progress');
const CooldownResetRequest = require('../models/CooldownResetRequest');
const User = require('../models/User');
const emailService = require('../services/emailService');
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
    console.log('Code Version: v2.1 - Fixed time restrictions');

    // Get or create user's progress document
    let progress = await Progress.findOne({ user: req.user._id }).sort({ createdAt: -1 });
    
    if (progress) {
      console.log('Found existing progress:');
      console.log('  _id:', progress._id);
      console.log('  lastBmiUpdate:', progress.lastBmiUpdate);
      console.log('  lastCaloriesUpdate:', progress.lastCaloriesUpdate);
      console.log('  Full document:', JSON.stringify(progress.toObject()));
    } else {
      console.log('No existing progress found - first time user');
    }
    
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
      
      // Reload from database to confirm it was saved
      progress = await Progress.findById(progress._id);
      console.log('First progress saved and reloaded:');
      console.log('  lastBmiUpdate:', progress.lastBmiUpdate);
      console.log('  lastCaloriesUpdate:', progress.lastCaloriesUpdate);
      
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
        error: 'You need to wait before updating this information again.',
        restrictions
      });
    }

    // If no fields to update, return error
    if (Object.keys(updateData).length === 0) {
      return res.status(400).json({
        error: 'Please provide at least one piece of information to update.'
      });
    }

    // Create a new history entry holding only the values entered now.
    // The other tracker's values are NOT copied forward: copying them made old
    // (or reset) values reappear and every value show up twice in the history
    // and charts. Only the update timestamps are carried forward, because the
    // cooldown checks always read them from the latest entry.
    const newProgressData = {
      user: req.user._id,
      lastBmiUpdate: updateData.lastBmiUpdate || progress.lastBmiUpdate,
      lastCaloriesUpdate: updateData.lastCaloriesUpdate || progress.lastCaloriesUpdate
    };

    if (updateData.bmi !== undefined) {
      newProgressData.bmi = updateData.bmi;
    }
    if (updateData.caloriesIntake !== undefined) {
      newProgressData.caloriesIntake = updateData.caloriesIntake;
      newProgressData.calorieDeficit = updateData.calorieDeficit;
    }

    const newProgress = new Progress(newProgressData);
    await newProgress.save({ validateBeforeSave: false });

    console.log('Progress updated successfully:', newProgress._id);
    console.log('New progress data before save:', newProgressData);
    console.log('New progress after save - lastBmiUpdate:', newProgress.lastBmiUpdate);
    console.log('New progress after save - lastCaloriesUpdate:', newProgress.lastCaloriesUpdate);

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
      return res.status(404).json({ error: 'We could not find this progress entry.' });
    }

    // Ensure user can only access their own progress
    if (progress.user.toString() !== req.user._id.toString()) {
      return res.status(403).json({ error: 'You do not have permission to view this progress entry.' });
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
      return res.status(404).json({ error: 'We could not find this progress entry to update.' });
    }

    // Ensure user can only update their own progress
    if (progress.user.toString() !== req.user._id.toString()) {
      return res.status(403).json({ error: 'You do not have permission to update this progress entry.' });
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
      return res.status(404).json({ error: 'We could not find this progress entry to delete.' });
    }

    // Ensure user can only delete their own progress
    if (progress.user.toString() !== req.user._id.toString()) {
      return res.status(403).json({ error: 'You do not have permission to delete this progress entry.' });
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

// Admin: Reset BMI and calorie tracking cooldown for a user (by client request e.g. misclick)
// This overrides the 7-day/24h restrictions. Logs the reset with reason for audit in cooldownResets array.
// Connected directly to MongoDB via Mongoose. Uses partial update pattern for compatibility.
const BMI_COOLDOWN_MS = 7 * 24 * 60 * 60 * 1000;
const CALORIES_COOLDOWN_MS = 24 * 60 * 60 * 1000;

// Escape user-supplied text before putting it into an HTML email
const escapeHtml = (value) => String(value)
  .replace(/&/g, '&amp;')
  .replace(/</g, '&lt;')
  .replace(/>/g, '&gt;')
  .replace(/"/g, '&quot;')
  .replace(/'/g, '&#39;');

// Build the cooldown status for one tracker from its last update timestamp
const buildCooldownStatus = (lastUpdate, cooldownMs, now) => {
  if (!lastUpdate) {
    return { active: false, lastUpdate: null, nextAllowedDate: null, remainingMs: 0 };
  }
  const nextAllowed = new Date(new Date(lastUpdate).getTime() + cooldownMs);
  const remainingMs = Math.max(0, nextAllowed.getTime() - now.getTime());
  return {
    active: remainingMs > 0,
    lastUpdate,
    nextAllowedDate: nextAllowed,
    remainingMs
  };
};

// Validate the target user for admin cooldown operations
const findCooldownTarget = async (userId) => {
  if (!mongoose.Types.ObjectId.isValid(userId)) {
    return { error: { status: 400, message: 'Invalid user ID.' } };
  }
  const user = await User.findById(userId).select('email username role');
  if (!user) {
    return { error: { status: 404, message: 'User not found.' } };
  }
  return { user };
};

const typeLabel = (type) => (type === 'both' ? 'BMI and calorie' : type === 'bmi' ? 'BMI' : 'calorie');
const capitalize = (s) => s.charAt(0).toUpperCase() + s.slice(1);

// The two trackers on a progress entry. Each has its own fields, its own
// "last update" timestamp and its own cooldown.
const TRACKERS = {
  bmi: { fields: ['bmi'], stamp: 'lastBmiUpdate', other: 'lastCaloriesUpdate', cooldownMs: BMI_COOLDOWN_MS },
  calories: {
    fields: ['caloriesIntake', 'calorieDeficit'],
    stamp: 'lastCaloriesUpdate',
    other: 'lastBmiUpdate',
    cooldownMs: CALORIES_COOLDOWN_MS
  }
};

const hasValue = (v) => v !== undefined && v !== null;

// Remove the member's mistaken entry for one tracker (BMI or calories) from
// their history. Used when a cooldown reset is approved.
//
// The mistaken entry is the one that was locking the member out at
// `referenceTime` (when the member asked for the reset, or now for a direct
// admin reset): the update timestamp on the latest entry at that time, if it
// was still inside its cooldown. If that tracker was not locked, nothing is
// removed, so older correct values are never touched.
//
// Each save creates a new progress document that carries the previous values
// forward, so later documents that copied the wrong values are reverted to the
// values from before the mistake.
// Returns { removed: false } or { removed: true, values, deletedEntry }.
const removeLatestTrackerEntry = async (userId, trackerName, referenceTime) => {
  const { fields, stamp, other, cooldownMs } = TRACKERS[trackerName];
  const ref = new Date(referenceTime);

  // Latest entry as it was when the reset was asked for
  const anchor = await Progress.findOne({ user: userId, createdAt: { $lte: ref } }).sort({ createdAt: -1 });
  if (!anchor || !anchor[stamp]) return { removed: false };
  const wrongTime = new Date(anchor[stamp]);
  const stillLocked = wrongTime.getTime() <= ref.getTime() &&
    ref.getTime() - wrongTime.getTime() < cooldownMs;
  if (!stillLocked) return { removed: false };

  // The document where that value was actually entered is the earliest one
  // carrying this timestamp.
  const entry = await Progress.findOne({ user: userId, [stamp]: wrongTime }).sort({ createdAt: 1 });
  if (!entry || !fields.some((f) => hasValue(entry[f]))) return { removed: false };

  // The last correct values (if any) come from the document before that entry.
  const previous = await Progress.findOne({ user: userId, createdAt: { $lt: entry.createdAt } })
    .sort({ createdAt: -1 });

  // Remove the wrong values and point the timer back to before the mistake.
  // Values are never copied into other entries (that caused duplicates), so the
  // previous correct values simply stay in their own earlier entry.
  const $unset = {};
  for (const f of fields) $unset[f] = 1;
  const revert = {
    $set: { [stamp]: previous && previous[stamp] ? previous[stamp] : null },
    $unset
  };

  // Later entries (e.g. updates of the other tracker) still carry the wrong
  // timestamp, and older entries may also hold a copy of the wrong values.
  await Progress.updateMany(
    { user: userId, createdAt: { $gt: entry.createdAt }, [stamp]: wrongTime },
    revert
  );

  const values = {};
  for (const f of fields) if (hasValue(entry[f])) values[f] = entry[f];

  // If the other tracker was saved in the same entry, keep the entry and only
  // drop this tracker's values. Otherwise delete the whole entry.
  const otherSavedTogether = !!entry[other] &&
    new Date(entry[other]).getTime() === new Date(wrongTime).getTime() &&
    TRACKERS[trackerName === 'bmi' ? 'calories' : 'bmi'].fields.some((f) => hasValue(entry[f]));

  if (otherSavedTogether) {
    await Progress.updateOne({ _id: entry._id }, revert);
  } else {
    // Keep the reset audit trail if it lived on the entry being deleted
    if (previous && Array.isArray(entry.cooldownResets) && entry.cooldownResets.length) {
      await Progress.updateOne(
        { _id: previous._id },
        { $push: { cooldownResets: { $each: entry.cooldownResets.map((r) => r.toObject()) } } }
      );
    }
    await Progress.deleteOne({ _id: entry._id });
  }

  console.log(`[RESET] Removed ${trackerName} ${JSON.stringify(values)} (entered ${new Date(wrongTime).toISOString()}) ` +
    `for user ${userId}${otherSavedTogether ? ' - entry kept for its other data' : ' - entry deleted'}`);

  return { removed: true, values, deletedEntry: !otherSavedTogether };
};

// Human readable summary of what a reset removed, e.g.
// "BMI 33 and calories 1000 kcal (deficit 500)". Empty string if nothing.
const describeRemoval = (removal) => {
  const parts = [];
  if (removal.bmi && removal.bmi.removed) {
    parts.push(`BMI ${removal.bmi.values.bmi}`);
  }
  if (removal.calories && removal.calories.removed) {
    const v = removal.calories.values;
    let text = `calories ${hasValue(v.caloriesIntake) ? `${v.caloriesIntake} kcal` : ''}`.trim();
    if (hasValue(v.calorieDeficit)) text += ` (deficit ${v.calorieDeficit})`;
    parts.push(text);
  }
  return parts.join(' and ');
};

// Every reset covers BMI and calories together
const RESET_TYPE = 'both';

// " Wrong values (...) removed from history." for API messages, or ''
const removedMessage = (result) => (result.removedText
  ? ` Wrong values (${result.removedText}) removed from history.`
  : '');

// Shared reset logic used by the direct admin reset and by approving a member request.
// For every tracker covered by `type`, the mistaken entry still on cooldown is
// removed from the member's history and its update timer is cleared, so the
// member can enter the correct value right away.
// `referenceTime` is when the member asked for the reset (or now).
// Returns { progress, label, removal, removedText } or { error: { status, message } }.
const performCooldownReset = async (client, type, reason, adminId, referenceTime = new Date()) => {
  // Cooldowns are always read from the latest progress entry
  let progress = await Progress.findOne({ user: client._id }).sort({ createdAt: -1 });
  if (!progress) {
    return { error: { status: 400, message: 'This user has no progress entries yet, so there is no cooldown to reset.' } };
  }

  const trackers = type === 'both' ? ['bmi', 'calories'] : [type];
  const removal = { bmi: { removed: false }, calories: { removed: false } };
  for (const tracker of trackers) {
    removal[tracker] = await removeLatestTrackerEntry(client._id, tracker, referenceTime);
  }
  // The latest entry may have been deleted or changed
  progress = await Progress.findOne({ user: client._id }).sort({ createdAt: -1 });

  // If the wrong values were the member's only entry, nothing is left and there
  // is no cooldown anymore; otherwise clear the timers on the latest entry
  // (the entry every cooldown check reads from).
  if (progress) {
    for (const tracker of trackers) progress[TRACKERS[tracker].stamp] = null;

    if (!progress.cooldownResets) progress.cooldownResets = [];
    progress.cooldownResets.push({ resetAt: new Date(), reason, type, admin: adminId });
    await progress.save({ validateBeforeSave: false });
  }

  const label = typeLabel(type);
  const removedText = describeRemoval(removal);
  const removedNote = removedText
    ? `<p>The values you entered by mistake (${escapeHtml(removedText)}) have been removed from your progress history.</p>`
    : '';

  // Notify the client (non-blocking)
  try {
    if (client.email) {
      await emailService.sendEmail(client.email, 'Your Progress Tracking Cooldown Has Been Reset', `
          <h2>Progress Cooldown Reset</h2>
          <p>Dear ${escapeHtml(client.username || 'User')},</p>
          <p>Your ${label} tracking cooldown has been reset by an administrator per your request.</p>
          <p><strong>Reason:</strong> ${escapeHtml(reason)}</p>
          ${removedNote}
          <p>You can now update your ${label} data immediately.</p>
          <p>Thank you for using LiftLog.</p>
          <p>LiftLog Admin Team</p>
        `);
    }
  } catch (emailErr) {
    console.warn('Notification for cooldown reset failed (non-blocking):', emailErr.message);
  }

  console.log(`[ADMIN] ${label} cooldown reset for user ${client._id} by admin ${adminId}. Reason: ${reason}`);
  return { progress, label, removal, removedText };
};

// Admin: View a user's current BMI / calorie cooldown status before resetting
router.get('/admin/:userId/cooldown-status', verifyToken, checkRole(['admin']), async (req, res) => {
  try {
    const { user, error } = await findCooldownTarget(req.params.userId);
    if (error) return res.status(error.status).json({ error: error.message });

    const progress = await Progress.findOne({ user: user._id })
      .sort({ createdAt: -1 })
      .populate('cooldownResets.admin', 'username');

    const now = new Date();
    const resets = progress && Array.isArray(progress.cooldownResets)
      ? progress.cooldownResets
          .slice(-5)
          .reverse()
          .map((r) => ({
            resetAt: r.resetAt,
            reason: r.reason,
            type: r.type || 'both',
            admin: r.admin && r.admin.username ? r.admin.username : null
          }))
      : [];

    res.json({
      user: { _id: user._id, username: user.username, email: user.email },
      hasProgress: !!progress,
      bmi: buildCooldownStatus(progress && progress.lastBmiUpdate, BMI_COOLDOWN_MS, now),
      calories: buildCooldownStatus(progress && progress.lastCaloriesUpdate, CALORIES_COOLDOWN_MS, now),
      recentResets: resets
    });
  } catch (error) {
    console.error('Admin cooldown status error:', error);
    res.status(500).json({ error: error.message || 'Failed to load cooldown status' });
  }
});

// Body: { reason: string (min 5 chars) }
// A reset always covers both BMI and calories (any `type` sent by older app
// versions is ignored) so the two trackers never get out of sync.
router.post('/admin/:userId/reset-cooldown', verifyToken, checkRole(['admin']), async (req, res) => {
  try {
    const { reason } = req.body;
    const type = RESET_TYPE;

    if (!reason || reason.trim().length < 5) {
      return res.status(400).json({ 
        error: 'A reason for the cooldown reset is required (e.g. "Client misclicked update button").' 
      });
    }

    const trimmedReason = reason.trim().slice(0, 500);
    const { user: client, error } = await findCooldownTarget(req.params.userId);
    if (error) return res.status(error.status).json({ error: error.message });

    const result = await performCooldownReset(client, type, trimmedReason, req.user._id);
    if (result.error) return res.status(result.error.status).json({ error: result.error.message });

    // A direct reset also resolves any pending request from this member
    await CooldownResetRequest.updateMany(
      { user: client._id, status: 'pending' },
      { status: 'approved', handledBy: req.user._id, handledAt: new Date(), adminNote: 'Resolved by direct admin reset.' }
    );

    res.json({
      message: `${capitalize(result.label)} cooldown successfully reset.${removedMessage(result)} Client notified.`,
      type,
      progressId: result.progress ? result.progress._id : null,
      reason: trimmedReason,
      cooldownResets: result.progress ? result.progress.cooldownResets.length : 0,
      bmiRemoved: result.removal.bmi.removed,
      removedBmi: result.removal.bmi.removed ? result.removal.bmi.values.bmi : null,
      caloriesRemoved: result.removal.calories.removed,
      removedCalories: result.removal.calories.removed ? result.removal.calories.values : null
    });
  } catch (error) {
    console.error('Admin cooldown reset error:', error);
    res.status(500).json({ error: error.message || 'Failed to reset cooldown' });
  }
});

// ============ MEMBER RESET REQUESTS ============
// NOTE: GET routes here use 2+ path segments so they don't collide with GET '/:id'.

// Member: submit a request for the admin to reset their cooldown (e.g. misclick)
// Body: { reason: string (min 5 chars) }
// A request always covers both BMI and calories (any `type` sent by older app
// versions is ignored).
router.post('/reset-requests', verifyToken, checkRole(['member']), async (req, res) => {
  try {
    const type = RESET_TYPE;
    const reason = (req.body.reason || '').toString().trim();

    if (reason.length < 5) {
      return res.status(400).json({ error: 'Please explain what happened (at least 5 characters).' });
    }

    const progress = await Progress.findOne({ user: req.user._id }).sort({ createdAt: -1 });
    const now = new Date();
    const bmiActive = buildCooldownStatus(progress && progress.lastBmiUpdate, BMI_COOLDOWN_MS, now).active;
    const caloriesActive = buildCooldownStatus(progress && progress.lastCaloriesUpdate, CALORIES_COOLDOWN_MS, now).active;

    if (!bmiActive && !caloriesActive) {
      return res.status(400).json({ error: 'You can already update this. No reset is needed.' });
    }

    const existing = await CooldownResetRequest.findOne({ user: req.user._id, status: 'pending' });
    if (existing) {
      return res.status(409).json({
        error: 'You already have a pending reset request. Please wait for an admin to review it.'
      });
    }

    const request = await CooldownResetRequest.create({
      user: req.user._id,
      type,
      reason: reason.slice(0, 500)
    });

    console.log(`[RESET REQUEST] Member ${req.user._id} requested ${type} cooldown reset.`);

    res.status(201).json({
      message: 'Your reset request was sent to the admin.',
      request
    });
  } catch (error) {
    console.error('Create reset request error:', error);
    res.status(500).json({ error: error.message || 'Failed to send reset request' });
  }
});

// Member: get my latest reset request (to show pending / approved / rejected status)
router.get('/reset-requests/mine', verifyToken, async (req, res) => {
  try {
    const request = await CooldownResetRequest.findOne({ user: req.user._id })
      .sort({ createdAt: -1 })
      .select('type reason status adminNote createdAt handledAt');
    res.json({ request: request || null });
  } catch (error) {
    res.status(500).json({ error: error.message || 'Failed to load reset request' });
  }
});

// Member: cancel my pending request
router.delete('/reset-requests/mine', verifyToken, async (req, res) => {
  try {
    const result = await CooldownResetRequest.deleteOne({ user: req.user._id, status: 'pending' });
    if (result.deletedCount === 0) {
      return res.status(404).json({ error: 'You have no pending reset request.' });
    }
    res.json({ message: 'Reset request cancelled.' });
  } catch (error) {
    res.status(500).json({ error: error.message || 'Failed to cancel reset request' });
  }
});

// Admin: list reset requests. Query: ?status=pending|approved|rejected|all (default pending)
router.get('/admin/reset-requests', verifyToken, checkRole(['admin']), async (req, res) => {
  try {
    const status = (req.query.status || 'pending').toString().toLowerCase();
    if (status !== 'all' && !['pending', 'approved', 'rejected'].includes(status)) {
      return res.status(400).json({ error: 'Invalid status filter.' });
    }
    const query = status === 'all' ? {} : { status };

    const requests = await CooldownResetRequest.find(query)
      .sort({ createdAt: -1 })
      .limit(100)
      .populate('user', 'username email')
      .populate('handledBy', 'username')
      .lean();

    const pendingCount = await CooldownResetRequest.countDocuments({ status: 'pending' });

    res.json({ requests, pendingCount });
  } catch (error) {
    console.error('List reset requests error:', error);
    res.status(500).json({ error: error.message || 'Failed to load reset requests' });
  }
});

// Admin: approve or reject a member's reset request
// Body: { action: 'approve' | 'reject', note?: string (required for reject) }
router.patch('/admin/reset-requests/:requestId', verifyToken, checkRole(['admin']), async (req, res) => {
  try {
    const { requestId } = req.params;
    if (!mongoose.Types.ObjectId.isValid(requestId)) {
      return res.status(400).json({ error: 'Invalid request ID.' });
    }

    const action = (req.body.action || '').toString().toLowerCase();
    const note = (req.body.note || '').toString().trim().slice(0, 500);
    if (!['approve', 'reject'].includes(action)) {
      return res.status(400).json({ error: 'Action must be "approve" or "reject".' });
    }
    if (action === 'reject' && note.length < 5) {
      return res.status(400).json({
        error: 'Please give the member a reason for rejecting (at least 5 characters).'
      });
    }

    const request = await CooldownResetRequest.findById(requestId);
    if (!request) return res.status(404).json({ error: 'Reset request not found.' });
    if (request.status !== 'pending') {
      return res.status(409).json({ error: `This request was already ${request.status}.` });
    }

    const { user: client, error } = await findCooldownTarget(request.user.toString());
    if (error) return res.status(error.status).json({ error: error.message });

    let removedMsg = '';
    if (action === 'approve') {
      const auditReason = `Member request: ${request.reason}${note ? ` | Admin note: ${note}` : ''}`.slice(0, 500);
      // Every request resets both trackers (older requests may still say 'bmi'
      // or 'calories'). The mistaken values are the ones that were locking the
      // member when they sent the request.
      const result = await performCooldownReset(client, RESET_TYPE, auditReason, req.user._id, request.createdAt);
      if (result.error) return res.status(result.error.status).json({ error: result.error.message });
      removedMsg = removedMessage(result);
    } else {
      // Notify member of rejection (non-blocking)
      try {
        if (client.email) {
          await emailService.sendEmail(client.email, 'Your Cooldown Reset Request', `
              <h2>Cooldown Reset Request Declined</h2>
              <p>Dear ${escapeHtml(client.username || 'User')},</p>
              <p>Your request to reset your ${typeLabel(RESET_TYPE)} tracking cooldown was not approved.</p>
              <p><strong>Admin note:</strong> ${escapeHtml(note)}</p>
              <p>LiftLog Admin Team</p>
            `);
        }
      } catch (emailErr) {
        console.warn('Rejection email failed (non-blocking):', emailErr.message);
      }
    }

    request.status = action === 'approve' ? 'approved' : 'rejected';
    if (note) request.adminNote = note;
    request.handledBy = req.user._id;
    request.handledAt = new Date();
    await request.save();

    res.json({
      message: action === 'approve'
        ? `Request approved. ${capitalize(typeLabel(RESET_TYPE))} cooldown reset.${removedMsg} Member notified.`
        : 'Request rejected and member notified.',
      request
    });
  } catch (error) {
    console.error('Handle reset request error:', error);
    res.status(500).json({ error: error.message || 'Failed to handle reset request' });
  }
});

 // Admin schema fix and delete routes have been removed after successful deployment of the Progress collection fixes.
 // The database validator issues on Render have been resolved. Partial updates for BMI/calories now work reliably.
 // See FIX_RENDER_DATABASE.md and PROGRESS_UPDATE_FIX.md for details. New admin cooldown reset and content moderation features added.

module.exports = router;
