const request = require('supertest');
const mongoose = require('mongoose');
const app = require('../server.js');
const User = require('../models/User.js');

describe('Authentication Routes', () => {
  let testUser;
  let authToken;

  beforeAll(async () => {
    // Connect to a test database
    await mongoose.connect(process.env.MONGODB_TEST_URI || 'mongodb://localhost:27017/liftlog_test', {
      useNewUrlParser: true,
      useUnifiedTopology: true,
    });
  });

  afterAll(async () => {
    // Disconnect from test database
    await mongoose.connection.close();
  });

  beforeEach(async () => {
    // Clear the users collection before each test
    await User.deleteMany({});

    // Create a test user
    testUser = new User({
      username: 'testuser',
      email: 'test@example.com',
      password: 'password123',
      role: 'member',
      membershipExpiration: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)
    });
    await testUser.save();
  });

  describe('POST /api/auth/register', () => {
    it('should register a new user', async () => {
      const res = await request(app)
        .post('/api/auth/register')
        .send({
          username: 'newuser',
          email: 'newuser@example.com',
          password: 'password123',
          role: 'member'
        });

      expect(res.statusCode).toBe(201);
      expect(res.body.user).toHaveProperty('username', 'newuser');
      expect(res.body).toHaveProperty('token');
    });

    it('should not register a user with existing email', async () => {
      const res = await request(app)
        .post('/api/auth/register')
        .send({
          username: 'testuser2',
          email: 'test@example.com',
          password: 'password123'
        });

      expect(res.statusCode).toBe(400);
      expect(res.body).toHaveProperty('error');
    });
  });

  describe('POST /api/auth/login', () => {
    it('should login with valid credentials', async () => {
      const res = await request(app)
        .post('/api/auth/login')
        .send({
          email: 'test@example.com',
          password: 'password123'
        });

      expect(res.statusCode).toBe(200);
      expect(res.body).toHaveProperty('token');
      authToken = res.body.token;
    });

    it('should not login with invalid credentials', async () => {
      const res = await request(app)
        .post('/api/auth/login')
        .send({
          email: 'test@example.com',
          password: 'wrongpassword'
        });

      expect(res.statusCode).toBe(401);
      expect(res.body).toHaveProperty('error');
    });
  });

  describe('GET /api/auth/profile', () => {
    it('should retrieve user profile for authenticated user', async () => {
      // First, login to get the token
      const loginRes = await request(app)
        .post('/api/auth/login')
        .send({
          email: 'test@example.com',
          password: 'password123'
        });

      const res = await request(app)
        .get('/api/auth/profile')
        .set('Authorization', `Bearer ${loginRes.body.token}`);

      expect(res.statusCode).toBe(200);
      expect(res.body).toHaveProperty('username', 'testuser');
      expect(res.body).not.toHaveProperty('password');
    });

    it('should not allow access without authentication', async () => {
      const res = await request(app)
        .get('/api/auth/profile');

      expect(res.statusCode).toBe(401);
    });
  });
});