# LiftLog Backend

## Overview
LiftLog is a fitness tracking application designed to help gym members, trainers, and administrators manage workout logs, track performance, and monitor membership.

## Features
- User Authentication (Members, Trainers, Admins)
- Workout Logging
- Membership Management
- Role-based Access Control
- Performance Tracking

## Technology Stack
- Node.js
- Express.js
- MongoDB
- Mongoose
- JSON Web Tokens (JWT)

## Prerequisites
- Node.js (v14+ recommended)
- MongoDB
- npm or yarn

## Installation

1. Clone the repository
```bash
git clone https://github.com/yourusername/LiftLog.git
cd LiftLog/backend
```

2. Install dependencies
```bash
npm install
```

3. Create a `.env` file in the backend directory with the following variables:
```
PORT=5000
MONGODB_URI=mongodb://localhost:27017/liftlog
JWT_SECRET=your_secret_key
NODE_ENV=development
```

4. Start the development server
```bash
npm run dev
```

## API Endpoints

### Authentication
- `POST /api/auth/register`: Register a new user
- `POST /api/auth/login`: User login
- `GET /api/auth/profile`: Get user profile
- `PATCH /api/auth/profile`: Update user profile

### Workouts
- `POST /api/workouts`: Log a new workout
- `GET /api/workouts`: Retrieve user's workouts
- `GET /api/workouts/:id`: Get a specific workout
- `PATCH /api/workouts/:id`: Update a workout
- `DELETE /api/workouts/:id`: Delete a workout

### Admin/Trainer Routes
- `GET /api/workouts/user/:userId`: Get workouts for a specific user
- `PATCH /api/auth/membership/:userId`: Update user membership

## User Roles
- **Member**: Can log workouts, view personal workouts
- **Trainer**: Can view member workouts, assign programs
- **Admin**: Manage memberships, user accounts

## Security
- Password hashing with bcrypt
- JWT-based authentication
- Role-based access control

## Testing
```bash
npm test
```

## Deployment
Ensure all environment variables are set in your production environment.

## Contributing
1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License
MIT License