
const express = require('express');
const router = express.Router();
const path = require('path');
const multer = require('multer');
const { createClient } = require('@supabase/supabase-js');
const User = require('../models/User');
const { verifyToken, checkRole, generateToken } = require('../middleware/auth');
const { sendVerificationEmail } = require('../services/emailService');

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

module.exports = router;
