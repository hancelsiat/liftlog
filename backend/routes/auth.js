
const express = require('express');
const router = express.Router();
const path = require('path'); // Import path module
const User = require('../models/User');
const { verifyToken, checkRole, generateToken } = require('../middleware/auth');
const { sendVerificationEmail } = require('../services/emailService');

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
      isEmailVerified: false, // Email verification is now required
      isApproved: role === 'member' // Members are auto-approved, trainers need admin approval
    });

    const verificationToken = user.generateEmailVerificationToken();
    await user.save();

    await sendVerificationEmail(user.email, verificationToken);

    // If trainer, return message about pending approval
    if (role === 'trainer') {
      return res.status(201).json({ 
        message: 'Trainer account created successfully. Please check your email to verify your account. Your account is also pending admin approval.',
        requiresApproval: true,
        requiresEmailVerification: true,
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

    res.status(201).json({ 
      message: 'User registered successfully. Please check your email to verify your account.', 
      requiresEmailVerification: true,
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
      return res.status(400).send('<h1>Error</h1><p>Invalid or expired verification link.</p>');
    }

    user.isEmailVerified = true;
    user.emailVerificationToken = null;
    user.emailVerificationExpires = null;
    await user.save();

    // Send the beautiful success page
    res.sendFile(path.join(__dirname, '..', 'templates', 'verificationSuccess.html'));

  } catch (error) {
    res.status(500).send('<h1>Error</h1><p>An error occurred during verification. Please try again later.</p>');
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

    // Check if email is verified
    if (!user.isEmailVerified) {
      return res.status(401).json({ 
        error: 'Please verify your email address before logging in.',
        emailNotVerified: true
      });
    }

    // Check if trainer account is approved (no email verification needed)
    if (user.role === 'trainer' && !user.isApproved) {
      return res.status(403).json({ 
        error: 'Your trainer account is pending admin approval. Please wait for approval.' 
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

// Resend Verification Email
router.post('/resend-verification', async (req, res) => {
  try {
    const { email } = req.body;
    const user = await User.findOne({ email });

    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    if (user.isEmailVerified) {
      return res.status(400).json({ error: 'Email is already verified' });
    }

    const verificationToken = user.generateEmailVerificationToken();
    await user.save();

    await sendVerificationEmail(user.email, verificationToken);

    res.json({ message: 'Verification email resent successfully.' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;
