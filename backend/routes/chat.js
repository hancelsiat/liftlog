const express = require('express');
const router = express.Router();
const Message = require('../models/Message');
const User = require('../models/User');
const { verifyToken, checkRole } = require('../middleware/auth');
const { sendEmail } = require('../services/emailService');

// Simple bad word filter (regex)
const BAD_WORDS_REGEX = /\b(bad|stupid|fuck|shit|damn)\b/gi;

const isValidChatPartner = (user, otherUser) => {
  if (user.role === 'admin') return true;
  if (user.role === 'trainer' && otherUser.trainer && otherUser.trainer.toString() === user._id.toString()) return true;
  if (user.role === 'member' && user.trainer && user.trainer.toString() === otherUser._id.toString()) return true;
  return false;
};

// Get chat history between two users (only current trainer/member pair or admin)
router.get('/history/:partnerId', verifyToken, async (req, res) => {
  try {
    const partnerId = req.params.partnerId;
    const user = req.user;
    const partner = await User.findById(partnerId);
    if (!partner || !isValidChatPartner(user, partner)) {
      return res.status(403).json({ error: 'You can only chat with your current trainer or clients.' });
    }

    const messages = await Message.find({
      $or: [
        { from: user._id, to: partnerId },
        { from: partnerId, to: user._id }
      ],
      isDeleted: false
    }).sort({ createdAt: 1 }).lean();

    res.json(messages);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Mark messages as read
router.post('/mark-read/:partnerId', verifyToken, async (req, res) => {
  try {
    const partnerId = req.params.partnerId;
    await Message.updateMany({
      to: req.user._id,
      from: partnerId,
      readBy: { $ne: req.user._id }
    }, {
      $addToSet: { readBy: req.user._id }
    });
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Soft delete message
router.delete('/:messageId', verifyToken, async (req, res) => {
  try {
    const message = await Message.findById(req.params.messageId);
    if (!message || (message.from.toString() !== req.user._id.toString() && req.user.role !== 'admin')) {
      return res.status(403).json({ error: 'Not authorized' });
    }
    message.isDeleted = true;
    await message.save();
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Report message
router.post('/:messageId/report', verifyToken, async (req, res) => {
  try {
    const { reason } = req.body;
    const message = await Message.findById(req.params.messageId);
    if (!message) return res.status(404).json({ error: 'Message not found' });
    message.reported = true;
    message.reportReason = reason || 'Reported by user';
    await message.save();
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;
