
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

// Full name rules (kept in sync with register_screen.dart): letters, spaces,
// periods, apostrophes and hyphens, at least first + last name, max 100.
const FULL_NAME_RE = /^\p{L}[\p{L} .'-]*$/u;
const validateFullName = (raw) => {
  const name = String(raw || '').trim().replace(/\s+/g, ' ');
  if (!name) return { error: 'Please enter your full name as it appears on your credential.' };
  if (name.length > 100) return { error: 'Your full name must be 100 characters or fewer.' };
  if (!FULL_NAME_RE.test(name)) {
    return { error: 'Your full name can only contain letters, spaces, periods, apostrophes and hyphens.' };
  }
  if (name.split(' ').filter((p) => /\p{L}/u.test(p)).length < 2) {
    return { error: 'Please enter your first and last name.' };
  }
  return { name };
};

// User Registration
router.post('/register', upload.single('credential'), async (req, res) => {
  try {
    const { 
      username, 
      email, 
      password, 
      role = 'member', 
      profile 
    } = req.body;

    if (role === 'admin') {
      return res.status(403).json({ 
        error: 'Admin accounts cannot be created through registration.' 
      });
    }

    // Trainers must give their legal name so the admin can match it to the
    // credential photo. Checked before the upload so a bad name doesn't
    // leave an orphaned file in storage.
    let fullName = '';
    if (role === 'trainer') {
      const checked = validateFullName(req.body.fullName);
      if (checked.error) return res.status(400).json({ error: checked.error });
      fullName = checked.name;
    }

    if (password) {
      const passwordRegex = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{6,}$/;
      if (!passwordRegex.test(password)) {
        return res.status(400).json({ 
          error: 'Your password must be at least 6 characters long and contain at least one uppercase letter, one lowercase letter, and one number.' 
        });
      }
    }

    const existingUser = await User.findOne({ $or: [{ email }, { username }] });
    if (existingUser) {
      if (!existingUser.isEmailVerified) {
        // If the existing user hasn't verified their email, delete the old unverified account
        // so they can register again
        await User.findByIdAndDelete(existingUser._id);
      } else {
        return res.status(400).json({ 
          error: 'An account with this email or username already exists. Please try logging in or use a different one.' 
        });
      }
    }

    let credentialImageUrl = '';
    if (role === 'trainer') {
      if (!req.file) {
        return res.status(400).json({ error: 'Please upload your trainer credentials to continue.' });
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
      fullName,
      email,
      password,
      role,
      profile,
      isEmailVerified: false,
      isApproved: role === 'member',
      credentialImageUrl: credentialImageUrl,
    });

    const verificationToken = user.generateEmailVerificationToken();
    await user.save();

    let emailResult = null;
    try {
      emailResult = await sendVerificationEmail(user.email, verificationToken);
    } catch (emailError) {
      console.error('Failed to send verification email:', emailError);
      emailResult = { success: false, errors: [emailError.message] };
    }

    let responseMessage = 'User registered successfully. Please check your email to verify your account.';
    if (role === 'trainer') {
      responseMessage = 'Trainer account created. Please verify your email. Your account is also pending admin approval.';
    }

    if (!emailResult || !emailResult.success) {
      responseMessage += ' (Note: Verification email failed to send. Please try resending.)';
    }

    res.status(201).json({ 
      message: responseMessage,
      user: {
        id: user._id,
        username: user.username,
        fullName: user.fullName,
        email: user.email,
        role: user.role
      },
      emailDebug: emailResult
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

    if (!user) {
      return res.status(401).json({ error: 'The email or password you entered is incorrect. Please check for typos and try again.' });
    }

    const isPasswordValid = await user.comparePassword(password);
    if (!isPasswordValid) {
      return res.status(401).json({ error: 'The email or password you entered is incorrect. Please check for typos and try again.' });
    }

    if (role && role !== 'all' && user.role !== role) {
      return res.status(403).json({
        error: `You are trying to log in as a ${role}, but your account is registered as a ${user.role}.`
      });
    }

    if (!user.isEmailVerified) {
      return res.status(401).json({ 
        error: 'Please verify your email address before logging in.',
        emailNotVerified: true
      });
    }

    // EXPLICIT Pending Admin Approval Check
    if (user.role === 'trainer' && !user.isApproved) {
      return res.status(403).json({ 
        error: 'Your trainer account is pending admin approval. Please wait for an administrator to review and approve your application.',
        pendingApproval: true
      });
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
    const updates = { ...req.body };
    // Users can't change their own role, approval or verification state, or
    // the identity fields the admin checked (full name and credential photo).
    // Only an admin can change these, via PATCH /users/:id.
    for (const key of ['role', 'isApproved', 'isEmailVerified', 'emailVerificationToken',
      'emailVerificationExpires', 'credentialImageUrl', 'fullName', 'clients', '_id']) {
      delete updates[key];
    }
    if (updates.password) {
      const passwordRegex = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{6,}$/;
      if (!passwordRegex.test(updates.password)) {
        return res.status(400).json({ 
          error: 'Your new password must be at least 6 characters long and contain at least one uppercase letter, one lowercase letter, and one number.' 
        });
      }
      const bcrypt = require('bcryptjs');
      updates.password = await bcrypt.hash(updates.password, 10);
    }
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
          { fullName: { $regex: search, $options: 'i' } },
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
    // An admin may fix a trainer's full name (blank is allowed for older
    // accounts); otherwise it uses the same rules as sign-up.
    if (req.body.fullName !== undefined) {
      const raw = String(req.body.fullName || '').trim();
      if (raw) {
        const checked = validateFullName(raw);
        if (checked.error) return res.status(400).json({ error: checked.error });
        req.body.fullName = checked.name;
      } else {
        req.body.fullName = '';
      }
    }
    if (req.body.password) {
      const passwordRegex = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{6,}$/;
      if (!passwordRegex.test(req.body.password)) {
        return res.status(400).json({ 
          error: 'The new password must be at least 6 characters long and contain at least one uppercase letter, one lowercase letter, and one number.' 
        });
      }
      const bcrypt = require('bcryptjs');
      req.body.password = await bcrypt.hash(req.body.password, 10);
    }
    const user = await User.findByIdAndUpdate(req.params.id, req.body, { new: true, runValidators: true }).select('-password');
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
    await ExerciseVideo.deleteMany({ trainer: userId });

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

    // Never send the password hash back to the app.
    const safeUser = () => {
      const obj = user.toObject();
      delete obj.password;
      return obj;
    };

    if (isApproved) {
      user.isApproved = true;
      await user.save();
      try {
        await sendApprovalEmail(user.email, user.fullName || user.username);
      } catch (emailErr) {
        console.warn('Approval email failed (non-blocking):', emailErr.message);
      }
      res.json({ message: 'Trainer has been approved.', user: safeUser() });
    } else {
      // Email first (needs the user's details), but never let it block the reject.
      try {
        await sendRejectionEmail(user.email, user.fullName || user.username, rejectionReason || 'No reason provided.');
      } catch (emailErr) {
        console.warn('Rejection email failed (non-blocking):', emailErr.message);
      }
      const rejected = safeUser();
      await User.findByIdAndDelete(req.params.id);
      await Workout.deleteMany({ user: req.params.id });
      await ExerciseVideo.deleteMany({ trainer: req.params.id });
      // `user` is included so older app versions that always parse it don't crash.
      res.json({ message: 'Trainer has been rejected and their data deleted.', user: rejected });
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

    const emailResult = await sendVerificationEmail(user.email, verificationToken);

    if (!emailResult || !emailResult.success) {
      return res.status(500).json({ 
        error: 'Failed to send verification email.',
        emailDebug: emailResult
      });
    }

    res.json({ 
      message: 'Verification email resent successfully.',
      emailDebug: emailResult
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Member: Select a trainer - FIXED: cleanup previous trainer, check approval/status
router.post('/select-trainer', verifyToken, checkRole(['member']), async (req, res) => {
  try {
    const { trainerId } = req.body;
    const member = await User.findById(req.user._id);
    const trainer = await User.findById(trainerId);
    
    if (!trainer || trainer.role !== 'trainer' || !trainer.isApproved || !trainer.isEmailVerified) {
      return res.status(404).json({ error: 'Trainer not found or not approved.' });
    }

    // Clean up previous trainer relationship if switching
    if (member.trainer && member.trainer.toString() !== trainerId.toString()) {
      const oldTrainer = await User.findById(member.trainer);
      if (oldTrainer) {
        oldTrainer.clients.pull(member._id);
        await oldTrainer.save();
      }
    }

    member.trainer = trainerId;
    await member.save();

    if (!trainer.clients.includes(member._id)) {
      trainer.clients.push(member._id);
    }
    await trainer.save();

    res.json({ message: 'Trainer selected successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;
