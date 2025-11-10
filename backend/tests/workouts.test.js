const request = require('supertest');
const mongoose = require('mongoose');
const app = require('../server.js');
const User = require('../models/User.js');
const Workout = require('../models/Workout.js');

describe('Workout Routes', () => {
  let memberUser;
  let trainerUser;
  let memberToken;
  let trainerToken;
  let testWorkout;

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
    // Clear collections
    await User.deleteMany({});
    await Workout.deleteMany({});

    // Create a member user
    memberUser = new User({
      username: 'memberuser',
      email: 'member@example.com',
      password: 'password123',
      role: 'member',
      membershipExpiration: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)
    });
    await memberUser.save();

    // Create a trainer user
    trainerUser = new User({
      username: 'traineruser',
      email: 'trainer@example.com',
      password: 'password123',
      role: 'trainer',
      membershipExpiration: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)
    });
    await trainerUser.save();

    // Login and get tokens
    const memberLogin = await request(app)
      .post('/api/auth/login')
      .send({
        email: 'member@example.com',
        password: 'password123'
      });

    const trainerLogin = await request(app)
      .post('/api/auth/login')
      .send({
        email: 'trainer@example.com',
        password: 'password123'
      });

    memberToken = memberLogin.body.token;
    trainerToken = trainerLogin.body.token;

    // Create a test workout
    testWorkout = new Workout({
      user: memberUser._id,
      title: 'Test Workout',
      date: new Date(),
      exercises: [{
        name: 'Bench Press',
        sets: 3,
        reps: 10,
        weight: 135
      }],
      duration: 60,
      intensity: 'moderate'
    });
    await testWorkout.save();
  });

  describe('POST /api/workouts', () => {
    it('should create a new workout for a member', async () => {
      const res = await request(app)
        .post('/api/workouts')
        .set('Authorization', `Bearer ${memberToken}`)
        .send({
          title: 'Leg Day',
          exercises: [{
            name: 'Squats',
            sets: 4,
            reps: 8,
            weight: 225
          }],
          duration: 75,
          intensity: 'high'
        });

      expect(res.statusCode).toBe(201);
      expect(res.body.workout).toHaveProperty('title', 'Leg Day');
      expect(res.body.workout.exercises[0]).toHaveProperty('name', 'Squats');
    });

    it('should not allow unauthorized users to create workouts', async () => {
      const res = await request(app)
        .post('/api/workouts')
        .send({
          title: 'Unauthorized Workout'
        });

      expect(res.statusCode).toBe(401);
    });
  });

  describe('GET /api/workouts', () => {
    it('should retrieve member\'s own workouts', async () => {
      const res = await request(app)
        .get('/api/workouts')
        .set('Authorization', `Bearer ${memberToken}`);

      expect(res.statusCode).toBe(200);
      expect(res.body.workouts).toHaveLength(1);
      expect(res.body.workouts[0].title).toBe('Test Workout');
    });

    it('should filter workouts by date range', async () => {
      const startDate = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString();
      const endDate = new Date().toISOString();

      const res = await request(app)
        .get(`/api/workouts?startDate=${startDate}&endDate=${endDate}`)
        .set('Authorization', `Bearer ${memberToken}`);

      expect(res.statusCode).toBe(200);
      expect(res.body.workouts).toHaveLength(1);
    });
  });

  describe('GET /api/workouts/:id', () => {
    it('should retrieve a specific workout', async () => {
      const res = await request(app)
        .get(`/api/workouts/${testWorkout._id}`)
        .set('Authorization', `Bearer ${memberToken}`);

      expect(res.statusCode).toBe(200);
      expect(res.body).toHaveProperty('title', 'Test Workout');
    });

    it('should allow trainer to view member\'s workout', async () => {
      const res = await request(app)
        .get(`/api/workouts/${testWorkout._id}`)
        .set('Authorization', `Bearer ${trainerToken}`);

      expect(res.statusCode).toBe(200);
    });
  });

  describe('PATCH /api/workouts/:id', () => {
    it('should update a member\'s own workout', async () => {
      const res = await request(app)
        .patch(`/api/workouts/${testWorkout._id}`)
        .set('Authorization', `Bearer ${memberToken}`)
        .send({
          title: 'Updated Workout',
          duration: 90
        });

      expect(res.statusCode).toBe(200);
      expect(res.body.workout).toHaveProperty('title', 'Updated Workout');
      expect(res.body.workout).toHaveProperty('duration', 90);
    });

    it('should allow trainer to update member\'s workout', async () => {
      const res = await request(app)
        .patch(`/api/workouts/${testWorkout._id}`)
        .set('Authorization', `Bearer ${trainerToken}`)
        .send({
          title: 'Trainer Updated Workout'
        });

      expect(res.statusCode).toBe(200);
      expect(res.body.workout).toHaveProperty('title', 'Trainer Updated Workout');
    });
  });

  describe('DELETE /api/workouts/:id', () => {
    it('should delete a member\'s own workout', async () => {
      const res = await request(app)
        .delete(`/api/workouts/${testWorkout._id}`)
        .set('Authorization', `Bearer ${memberToken}`);

      expect(res.statusCode).toBe(200);
      expect(res.body).toHaveProperty('message', 'Workout deleted successfully');
    });

    it('should allow trainer to delete member\'s workout', async () => {
      // Create a new workout to delete
      const newWorkout = new Workout({
        user: memberUser._id,
        title: 'Workout to Delete',
        exercises: []
      });
      await newWorkout.save();

      const res = await request(app)
        .delete(`/api/workouts/${newWorkout._id}`)
        .set('Authorization', `Bearer ${trainerToken}`);

      expect(res.statusCode).toBe(200);
      expect(res.body).toHaveProperty('message', 'Workout deleted successfully');
    });
  });
});