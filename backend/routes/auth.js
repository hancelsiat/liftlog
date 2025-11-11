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
    const { email, password, role } = req.body;

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

    // Make role check optional and more flexible
    if (role && role !== 'all' && user.role !== role) {
      return res.status(403).json({
        error: `Access denied. You are registered as a ${user.role}, not as a ${role}.`
      });
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

// Admin: Get all users (Admin Only)
router.get('/users',
  verifyToken,
  checkRole(['admin']),
  async (req, res) => {
    try {
      const {
        page = 1,
        limit = 10,
        role,
        search
      } = req.query;

      const query = {};

      if (role) query.role = role;
      if (search) {
        query.$or = [
          { username: { $regex: search, $options: 'i' } },
          { email: { $regex: search, $options: 'i' } }
        ];
      }

      const users = await User.find(query)
        .select('-password')
        .limit(Number(limit))
        .skip((page - 1) * limit)
        .sort({ createdAt: -1 });

      const total = await User.countDocuments(query);

      res.json({
        users,
        totalUsers: total,
        currentPage: Number(page),
        totalPages: Math.ceil(total / limit)
      });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
});

// Admin: Update user details (Admin Only)
router.patch('/users/:userId',
  verifyToken,
  checkRole(['admin']),
  async (req, res) => {
    try {
      const { userId } = req.params;
      const updates = req.body;

      // Allow password updates for admin
      const user = await User.findById(userId);

      if (!user) {
        return res.status(404).json({ error: 'User not found' });
      }

      // If password is being updated, hash it
      if (updates.password) {
        user.password = updates.password;
        await user.save();
        delete updates.password; // Remove from updates to avoid double processing
      }

      // Update other fields
      Object.keys(updates).forEach(key => {
        if (key !== 'password') {
          user[key] = updates[key];
        }
      });

      await user.save();

      res.json({
        id: user._id,
        username: user.username,
        email: user.email,
        role: user.role,
        profile: user.profile,
        membershipExpiration: user.membershipExpiration
      });
    } catch (error) {
      res.status(400).json({ error: error.message });
    }
});

// Admin: Delete user (Admin Only)
router.delete('/users/:userId',
  verifyToken,
  checkRole(['admin']),
  async (req, res) => {
    try {
      const { userId } = req.params;

      const user = await User.findById(userId);

      if (!user) {
        return res.status(404).json({ error: 'User not found' });
      }

      // Prevent admin from deleting themselves
      if (userId === req.user._id.toString()) {
        return res.status(400).json({ error: 'Cannot delete your own account' });
      }

      await user.remove();

      res.json({ message: 'User deleted successfully' });
    } catch (error) {
      res.status(500).json({ error: error.message });
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