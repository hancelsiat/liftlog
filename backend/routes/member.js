
const express = require('express');
const router = express.Router();
const User = require('../models/User');
const { verifyToken, checkRole } = require('../middleware/auth');

// Member leaves a trainer
router.post('/leave-trainer', verifyToken, checkRole(['member']), async (req, res) => {
  try {
    const member = await User.findById(req.user._id);
    if (!member.trainer) {
      return res.status(400).json({ error: 'You do not have a trainer.' });
    }

    // const trainer = await User.findById(member.trainer);
    // if (trainer) {
    //   trainer.clients.pull(member._id);
    //   await trainer.save();
    // }

    member.trainer = null;
    await member.save();

    res.json({ message: 'You have successfully left your trainer.' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;
