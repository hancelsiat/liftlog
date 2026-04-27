
const express = require('express');
const router = express.Router();
const path = require('path');
const multer = require('multer');
const { createClient } = require('@supabase/supabase-js');
const User = require('../models/User');
const Workout = require('../models/Workout');
const ExerciseVideo = require('../models/ExerciseVideo');
const { verifyToken, checkRole, generateToken } = require('../middleware/auth');
const { sendVerificationEmail, sendApprovalEmail, sendRejectionEmail } = require('../services/emailService');

// Initialize Supabase
const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_KEY);

// Set up multer for file uploads
const storage = multer.memoryStorage();
const upload = multer({ storage: storage });

// User Registration
router.post('/register', upload.single('credential'), async (req, res) => {
  try {
    const { 
      username, 
      email, 
      password, 
      role = 'member', 
      membershipExpiration,
      profile 
    } = req.body;

    if (role === 'admin') {
      return res.status(403).json({ 
        error: 'Admin accounts cannot be created through registration.' 
      });
    }

    const existingUser = await User.findOne({ $or: [{ email }, { username }] });
    if (existingUser) {
      return res.status(400).json({ 
        error: 'User already exists with this email or username' 
      });
    }

    let credentialImageUrl = '';
    if (role === 'trainer') {
      if (!req.file) {
        return res.status(400).json({ error: 'Trainer credential is required.' });
      }

      const file = req.file;
      const fileName = `${Date.now()}_${file.originalname}`;
      const { data, error } = await supabase.storage
        .from('trainer-credentials')
        .upload(fileName, file.buffer, {
          contentType: file.mimetype,
        });

      if (error) {
        throw new Error(`Supabase upload error: ${error.message}`);
      }

      const { data: publicUrlData } = supabase.storage
        .from('trainer-credentials')
        .getPublicUrl(fileName);

      credentialImageUrl = publicUrlData.publicUrl;
    }

    const user = new User({
      username,
      email,
      password,
      role,
      membershipExpiration: membershipExpiration || new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
      profile,
      isEmailVerified: false,
      isApproved: role === 'member',
      credentialImageUrl: credentialImageUrl,
    });

    const verificationToken = user.generateEmailVerificationToken();
    await user.save();
    await sendVerificationEmail(user.email, verificationToken);

    let responseMessage = 'User registered successfully. Please check your email to verify your account.';
    if (role === 'trainer') {
      responseMessage = 'Trainer account created. Please verify your email. Your account is also pending admin approval.';
    }

    res.status(201).json({ 
      message: responseMessage,
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
      return res.status(400).sendFile(path.join(__dirname, '..', 'templates', 'verificationExpired.html'));
    }

    user.isEmailVerified = true;
    user.emailVerificationToken = null;
    user.emailVerificationExpires = null;
    await user.save();

    res.sendFile(path.join(__dirname, '..', 'templates', 'verificationSuccess.html'));
  } catch (error) {
    res.status(500).send('<h1>Error</h1><p>An error occurred during verification.</p>');
  }
});

// User Login
router.post('/login', async (req, res) => {
  try {
    const { email, password, role } = req.body;
    const user = await User.findOne({ email });

    if (!user || !(await user.comparePassword(password))) {
      return res.status(401).json({ error: 'Invalid login credentials' });
    }

    if (role && role !== 'all' && user.role !== role) {
      return res.status(403).json({
        error: `Access denied. You are registered as a ${user.role}, not as a ${role}.`
      });
    }

    if (!user.isEmailVerified) {
      return res.status(401).json({ 
        error: 'Please verify your email address before logging in.',
        emailNotVerified: true
      });
    }

    if (user.role === 'trainer' && !user.isApproved) {
      return res.status(403).json({ 
        error: 'Your trainer account is pending admin approval.' 
      });
    }

    if (!user.isMembershipActive()) {
      return res.status(403).json({ error: 'Membership has expired' });
    }

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

// Admin: Update user
router.patch('/users/:id', verifyToken, checkRole(['admin']), async (req, res) => {
  try {
    const user = await User.findByIdAndUpdate(req.params.id, req.body, { new: true, runValidators: true });
    if (!user) return res.status(404).json({ error: 'User not found' });
    res.json(user);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// Admin: Delete user
router.delete('/users/:id', verifyToken, checkRole(['admin']), async (req, res) => {
  try {
    const userId = req.params.id;

    // Find and delete the user
    const user = await User.findByIdAndDelete(userId);
    if (!user) return res.status(404).json({ error: 'User not found' });

    // Delete all workouts created by this user
    await Workout.deleteMany({ user: userId });

    // Delete all videos uploaded by this user
    await ExerciseVideo.deleteMany({ uploadedBy: userId });

    res.json({ message: 'User and all associated data deleted successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Admin: Approve/Reject trainer
router.patch('/users/:id/approve', verifyToken, checkRole(['admin']), async (req, res) => {
  try {
    const { isApproved, rejectionReason } = req.body;
    const user = await User.findById(req.params.id);

    if (!user || user.role !== 'trainer') {
      return res.status(404).json({ error: 'Trainer not found' });
    }

    if (isApproved) {
      user.isApproved = true;
      await user.save();
      await sendApprovalEmail(user.email, user.username);
      res.json({ message: 'Trainer has been approved.', user });
    } else {
      await sendRejectionEmail(user.email, user.username, rejectionReason || 'No reason provided.');
      await User.findByIdAndDelete(req.params.id);
      await Workout.deleteMany({ user: req.params.id });
      await ExerciseVideo.deleteMany({ uploadedBy: req.params.id });
      res.json({ message: 'Trainer has been rejected and their data deleted.' });
    }
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
