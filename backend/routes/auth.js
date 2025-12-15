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

    // Prevent admin registration through API
    if (role === 'admin') {
      return res.status(403).json({ 
        error: 'Admin accounts cannot be created through registration. Please contact system administrator.' 
      });
    }

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
      profile,
      isEmailVerified: role === 'member', // Members don't need email verification
      isApproved: role === 'member' // Members are auto-approved
    });

    // If trainer, generate verification token
    if (role === 'trainer') {
      const verificationToken = user.generateEmailVerificationToken();
      await user.save();
      
      // TODO: Send verification email
      console.log(`Verification token for ${email}: ${verificationToken}`);
      console.log(`Verification link: http://localhost:5000/api/auth/verify-email/${verificationToken}`);
      
      return res.status(201).json({ 
        message: 'Trainer account created. Please check your email to verify your account. Admin approval is also required.',
        requiresVerification: true,
        user: {
          id: user._id,
          username: user.username,
          email: user.email,
          role: user.role,
          isEmailVerified: user.isEmailVerified,
          isApproved: user.isApproved
        }
      });
    }

    await user.save();

    // Generate JWT token for members
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

// Email Verification
router.get('/verify-email/:token', async (req, res) => {
  try {
    const { token } = req.params;
    const hashedToken = require('crypto').createHash('sha256').update(token).digest('hex');

    const user = await User.findOne({
      emailVerificationToken: hashedToken,
      emailVerificationExpires: { $gt: Date.now() }
    });

    if (!user) {
      return res.status(400).json({ error: 'Invalid or expired verification token' });
    }

    user.isEmailVerified = true;
    user.emailVerificationToken = null;
    user.emailVerificationExpires = null;
    await user.save();

    res.json({ 
      message: 'Email verified successfully. Your account is pending admin approval.',
      user: {
        id: user._id,
        email: user.email,
        isEmailVerified: user.isEmailVerified,
        isApproved: user.isApproved
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

    // Check if trainer account is verified and approved
    if (user.role === 'trainer' && !user.canAccess()) {
      if (!user.isEmailVerified) {
        return res.status(403).json({ 
          error: 'Please verify your email address before logging in. Check your email for the verification link.' 
        });
      }
      if (!user.isApproved) {
        return res.status(403).json({ 
          error: 'Your trainer account is pending admin approval. Please wait for approval.' 
        });
      }
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
        membershipExpiration: user.membershipExpiration,
        isEmailVerified: user.isEmailVerified,
        isApproved: user.isApproved
      });
    } catch (error) {
      res.status(400).json({ error: error.message });
    }
});

// Admin: Approve trainer account (Admin Only)
router.patch('/users/:userId/approve',
  verifyToken,
  checkRole(['admin']),
  async (req, res) => {
    try {
      const { userId } = req.params;
      const { isApproved } = req.body;

      const user = await User.findById(userId);

      if (!user) {
        return res.status(404).json({ error: 'User not found' });
      }

      if (user.role !== 'trainer') {
        return res.status(400).json({ error: 'Only trainer accounts can be approved' });
      }

      user.isApproved = isApproved;
      
      // When admin approves, also mark email as verified
      // This bypasses the need for email verification since admin approval is more important
      if (isApproved) {
        user.isEmailVerified = true;
        user.emailVerificationToken = null;
        user.emailVerificationExpires = null;
      }
      
      await user.save();

      res.json({
        message: `Trainer account ${isApproved ? 'approved' : 'rejected'}`,
        user: {
          id: user._id,
          username: user.username,
          email: user.email,
          role: user.role,
          isEmailVerified: user.isEmailVerified,
          isApproved: user.isApproved
        }
      });
    } catch (error) {
      res.status(500).json({ error: error.message });
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