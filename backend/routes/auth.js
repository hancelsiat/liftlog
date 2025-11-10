const express = require('express');
const router = express.Router();
const User = require('../models/User');
const { verifyToken, checkRole, generateToken } = require('../middleware/auth');

// User Registration
router.post('/register', async (req, res) => {
  try {
    const { 
      username, 
      email, 
      password, 
      role = 'member', 
      membershipExpiration,
      profile 
    } = req.body;

    // Check if user already exists
    const existingUser = await User.findOne({ 
      $or: [{ email }, { username }] 
    });

    if (existingUser) {
      return res.status(400).json({ 
        error: 'User already exists with this email or username' 
      });
    }

    // Create new user
    const user = new User({
      username,
      email,
      password,
      role,
      membershipExpiration: membershipExpiration || 
        new Date(Date.now() + 30 * 24 * 60 * 60 * 1000), // Default 30 days
      profile
    });

    await user.save();

    // Generate JWT token
    const token = generateToken(user);

    res.status(201).json({ 
      message: 'User registered successfully', 
      token,
      user: {
        id: user._id,
        username: user.username,
        email: user.email,
        role: user.role
      }
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// User Login
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    // Find user by email
    const user = await User.findOne({ email });

    if (!user) {
      return res.status(401).json({ error: 'Invalid login credentials' });
    }

    // Check password
    const isMatch = await user.comparePassword(password);

    if (!isMatch) {
      return res.status(401).json({ error: 'Invalid login credentials' });
    }

    // Check membership status
    if (!user.isMembershipActive()) {
      return res.status(403).json({ error: 'Membership has expired' });
    }

    // Generate JWT token
    const token = generateToken(user);

    res.json({ 
      token,
      user: {
        id: user._id,
        username: user.username,
        email: user.email,
        role: user.role
      }
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get User Profile (Authenticated Route)
router.get('/profile', verifyToken, async (req, res) => {
  try {
    const user = await User.findById(req.user._id).select('-password');
    res.json(user);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Update User Profile (Authenticated Route)
router.patch('/profile', verifyToken, async (req, res) => {
  try {
    const updates = req.body;
    const user = await User.findByIdAndUpdate(
      req.user._id, 
      updates, 
      { new: true, runValidators: true }
    ).select('-password');

    res.json(user);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// Admin: Manage User Membership (Admin Only)
router.patch('/membership/:userId', 
  verifyToken, 
  checkRole(['admin']), 
  async (req, res) => {
    try {
      const { userId } = req.params;
      const { membershipExpiration } = req.body;

      const user = await User.findByIdAndUpdate(
        userId, 
        { membershipExpiration }, 
        { new: true, runValidators: true }
      ).select('-password');

      if (!user) {
        return res.status(404).json({ error: 'User not found' });
      }

      res.json(user);
    } catch (error) {
      res.status(400).json({ error: error.message });
    }
});

module.exports = router;