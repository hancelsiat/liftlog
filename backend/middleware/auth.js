const jwt = require('jsonwebtoken');
const User = require('../models/User');

// Middleware to verify JWT token
const verifyToken = async (req, res, next) => {
  try {
    const token = req.header('Authorization')?.replace('Bearer ', '');
    
    if (!token) {
      return res.status(401).json({ error: 'Please log in to access this feature.' });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    if (!decoded || !decoded.userId) {
      throw new Error();
    }

    const user = await User.findById(decoded.userId);


    if (!user) {
      return res.status(401).json({ error: 'Your session has expired. Please log in again.' });
    }

    req.user = user;
    next();
  } catch (error) {
    res.status(401).json({ error: 'Please log in to continue.' });
  }
};

// Middleware to check user role
const checkRole = (roles) => {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ error: 'Please log in to access this feature.' });
    }

    const userRole = req.user.role.toLowerCase();
    const allowedRoles = roles.map(r => r.toLowerCase());

    if (allowedRoles.includes('all') || allowedRoles.includes(userRole)) {
      next();
    } else {
      return res.status(403).json({ error: 'You do not have permission to perform this action.' });
    }
  };
};

// Generate JWT Token
const generateToken = (user) => {
  return jwt.sign(
    { 
      userId: user._id, 
      role: user.role 
    }, 
    process.env.JWT_SECRET, 
    { expiresIn: '7d' }
  );
};

module.exports = {
  verifyToken,
  checkRole,
  generateToken
};