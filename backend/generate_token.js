require('dotenv').config();
const jwt = require('jsonwebtoken');

const userId = '69d266cac921c4f6cd544bda'; // The ID for james@mail.com
const userRole = 'trainer';
const secret = process.env.JWT_SECRET;

const token = jwt.sign(
    { userId: userId, role: userRole },
    secret,
    { expiresIn: '1h' }
);

console.log(token);
