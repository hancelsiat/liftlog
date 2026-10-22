
require('dotenv').config(); // LOAD ENV VARS FIRST

const express = require('express');
const mongoose = require('mongoose');
const { MongoClient } = require('mongodb');
const cors = require('cors');
const path = require('path');
const http = require('http');
const { Server } = require('socket.io');
const { createClient } = require('@supabase/supabase-js');
const User = require('./models/User');
const Message = require('./models/Message');
const { sendEmail } = require('./services/emailService');

// Bad words filter and chat partner validator (moved to top for scope in socket handlers)
const BAD_WORDS_REGEX = /\b(bad|stupid|fuck|shit|damn|idiot)\b/gi;

const isValidChatPartnerForSocket = (user, otherUser) => {
  if (user.role === 'admin') return true;
  if (user.role === 'trainer' && otherUser.trainer?.toString() === user._id.toString()) return true;
  if (user.role === 'member' && user.trainer?.toString() === otherUser._id.toString()) return true;
  return false;
};

const app = express();
const PORT = process.env.PORT || 10000;

// Middleware
app.set('trust proxy', true);
app.use(cors({
  origin: '*', // Allow all origins
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));
app.use(express.json());
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.path} from ${req.ip}`);
  next();
});

// Function to create default admin if it doesn't exist
const createDefaultAdmin = async () => {
  try {
    // Check if admin already exists
    const existingAdmin = await User.findOne({ email: 'admin@gmail.com' });
    
    if (existingAdmin) {
      console.log('[Init] Default admin account already exists');
      return;
    }

    // Create default admin account
    const admin = new User({
      username: 'admin',
      email: 'admin@gmail.com',
      password: 'admin123',
      role: 'admin',
      isEmailVerified: true,
      isApproved: true,
      membershipExpiration: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000), // 1 year
      profile: {
        firstName: 'System',
        lastName: 'Administrator'
      }
    });

    await admin.save();
    console.log('[Init] ✅ Default admin account created successfully!');
    console.log('[Init] Email: admin@gmail.com | Password: admin123');
    console.log('[Init] ⚠️  IMPORTANT: Change the password after first login!');
  } catch (error) {
    console.error('[Init] Error creating default admin:', error.message);
  }
};

// Database Connection (skip in test environment)
if (process.env.NODE_ENV !== 'test') {
  // Connect with Mongoose for schemas
  mongoose.connect(process.env.MONGODB_URI, {
    useNewUrlParser: true,
    useUnifiedTopology: true,
    serverSelectionTimeoutMS: 5000, // Timeout after 5s instead of 30s
    socketTimeoutMS: 45000, // Close sockets after 45s of inactivity
  })
  .then(async () => {
    console.log('MongoDB connected successfully');
    // Create default admin after successful connection
    await createDefaultAdmin();
  })
  .catch((err) => console.error('MongoDB connection error:', err));

  // Also initialize MongoClient for any remaining GridFS needs (if any)
  const initMongo = async () => {
    const uri = process.env.MONGODB_URI;
    if (!uri) {
      console.error('MONGODB_URI missing');
      process.exit(1);
    }
    const client = new MongoClient(uri, { maxPoolSize: 20, serverSelectionTimeoutMS: 10000 });
    await client.connect();
    console.log('[init] MongoClient connected');
    const db = client.db(); // default DB name from URI
    app.locals.mongoClient = client;
    app.locals.mongoDb = db;
  };

  initMongo().catch(err => {
    console.error('[init] MongoClient init failed', err && (err.stack || err.message));
    process.exit(1);
  });
}

// Initialize Supabase client
const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_KEY);

// Make Supabase client available in app locals
app.locals.supabase = supabase;

// Import Routes
const authRoutes = require('./routes/auth');
const workoutRoutes = require('./routes/workouts');
const videoRoutes = require('./routes/videos');
const progressRoutes = require('./routes/progress');
const presignRoutes = require('./routes/presign');
const planRoutes = require('./routes/plans');
const clientRoutes = require('./routes/clients');
const memberRoutes = require('./routes/member');
const ratingRoutes = require('./routes/ratings');
const chatRoutes = require('./routes/chat');
// const videosCompleteRoutes = require('./routes/videos_complete');

// Use Routes
app.use('/api/auth', authRoutes);
app.use('/api/workouts', workoutRoutes);
app.use('/api/videos', videoRoutes);
app.use('/api/progress', progressRoutes);
app.use('/api', presignRoutes);
app.use('/api/plans', planRoutes);
app.use('/api/clients', clientRoutes);
app.use('/api/member', memberRoutes);
app.use('/api/ratings', ratingRoutes);
app.use('/api/chat', chatRoutes);
// app.use('/api', videosCompleteRoutes);

// Serve static files for uploaded videos
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// 404 handler for unmatched API routes (must come after all other routes)
// This prevents HTML "Cannot GET /..." responses that trigger generic client errors.
// Provides clear JSON message directing to redeploy when admin routes are missing on live.
app.use((req, res, next) => {
  if (req.path.startsWith('/api/')) {
    return res.status(404).json({
      error: `Route not found: ${req.method} ${req.path}. ` +
             'This usually means the backend on Render is running stale code. ' +
             'Please trigger a redeploy in the Render dashboard (or push a commit).'
    });
  }
  next();
});

// Improved Error Handling Middleware
// Now returns structured JSON for all /api calls so that the Flutter ApiService._handleResponse
// can parse errorData['error'] and show specific messages instead of 
// "We encountered an unexpected error. Please check your connection"
app.use((err, req, res, next) => {
  console.error(`[${new Date().toISOString()}] Error:`, err.stack);
  const isApi = req.path.startsWith('/api/') || 
                (req.headers.accept && req.headers.accept.includes('application/json'));
  if (isApi) {
    res.status(500).json({
      error: err.message || 'Internal server error. Please check the Render service logs for details.',
      timestamp: new Date().toISOString()
    });
  } else {
    res.status(500).send('Something broke!');
  }
});

// Socket.IO setup for realtime 1:1 messaging (after all routes)
// Limited to current trainer/member pair or admin. Uses Mongo TTL for 14-day auto-delete.
// Presence in-memory (lost on Render sleep). Client must reconnect on disconnect.
const httpServer = http.createServer(app);
const io = new Server(httpServer, {
  cors: { origin: '*', methods: ['GET', 'POST'] },
  pingTimeout: 60000,
  pingInterval: 25000
});

app.locals.io = io;

const onlineUsers = new Map();

io.use(async (socket, next) => {
  try {
    const token = socket.handshake.auth?.token || socket.handshake.query?.token;
    if (!token) return next(new Error('Authentication error'));

    const jwt = require('jsonwebtoken');
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const user = await User.findById(decoded.userId).select('+lastSeen');
    // canAccess is a method: without the call it was always truthy, so the
    // check never denied anyone (e.g. unapproved trainers).
    if (!user || !user.canAccess()) return next(new Error('Access denied'));
    socket.user = user;
    socket.userId = user._id.toString();
    next();
  } catch (err) {
    console.error('[Socket Auth Error]', err.message);
    next(new Error('Authentication error'));
  }
});

io.on('connection', (socket) => {
  const userId = socket.userId;
  console.log(`[Socket] User ${socket.user.username} (${userId}) connected`);

  onlineUsers.set(userId, socket.id);
  socket.user.lastSeen = new Date();
  socket.user.save().catch(console.error);

  socket.join(userId);

  socket.on('joinChat', (partnerId) => {
    const sorted = [userId, partnerId].sort();
    const room = sorted.join('-');
    socket.join(room);
    socket.to(room).emit('userOnline', { userId, lastSeen: socket.user.lastSeen });
  });

  socket.on('sendMessage', async ({ to, content }) => {
    try {
      const partner = await User.findById(to);
      if (!partner || !isValidChatPartnerForSocket(socket.user, partner)) {
        return socket.emit('error', { message: 'Chat not allowed with this user.' });
      }

      let filteredContent = content.replace(BAD_WORDS_REGEX, '[filtered]');

      const message = new Message({
        from: userId,
        to,
        content: filteredContent,
        expiresAt: new Date(Date.now() + 14 * 24 * 60 * 60 * 1000),
      });
      await message.save();

      const populated = await Message.findById(message._id).populate('from', 'username').populate('to', 'username').lean();

      const room = [userId, to].sort().join('-');
      io.to(room).emit('newMessage', populated);

      if (!onlineUsers.has(to.toString())) {
        const html = `
          <h2>New Message from ${socket.user.username}</h2>
          <p>You have an unread message in LiftLog. Log in to view and reply.</p>
          <p>Message preview: ${filteredContent.substring(0, 100)}...</p>
        `;
        sendEmail(partner.email, 'Unread Message - LiftLog', html).catch(console.error);
      }
    } catch (err) {
      socket.emit('error', { message: 'Failed to send message' });
    }
  });

  socket.on('typing', ({ to, isTyping }) => {
    const room = [userId, to].sort().join('-');
    socket.to(room).emit('userTyping', { from: userId, isTyping });
  });

  socket.on('markRead', async ({ from }) => {
    await Message.updateMany({ to: userId, from, readBy: { $ne: userId } }, { $addToSet: { readBy: userId } });
    const room = [userId, from].sort().join('-');
    io.to(room).emit('messagesRead', { by: userId, from });
  });
// Helpers (BAD_WORDS_REGEX, isValidChatPartnerForSocket) moved to top of file for proper scope in socket handlers.
// Duplicate 404, error middleware, and static serve removed (first improved versions before Socket.IO setup are kept).
// Socket.IO is fully functional with rooms, auth, filtering, read receipts, typing, presence, emails, and TTL index.

// Helpers moved to top. Duplicate middleware/static/404/error blocks removed (kept the first improved versions + final listen).
// Socket.IO fully wired with per-pair rooms, validation, filtering, read receipts, typing, emails, TTL.



  socket.on('disconnect', () => {
    onlineUsers.delete(userId);
    if (socket.user) {
      socket.user.lastSeen = new Date();
      socket.user.save().catch(console.error);
    }
    console.log(`[Socket] User ${userId} disconnected`);
  });
});



// Helpers (BAD_WORDS_REGEX, isValidChatPartnerForSocket) moved to top. Duplicates cleaned. Socket.IO ready.

// Start Server (use httpServer for Socket.IO, skip in test)
if (process.env.NODE_ENV !== 'test') {
  httpServer.listen(PORT, '0.0.0.0', () => {
    console.log(`Server running on port ${PORT} with Socket.IO`);
    console.log('[Socket] Realtime chat enabled. Note: Free Render tier will sleep after 15min inactivity - clients must reconnect.');
  });
}

module.exports = app;
