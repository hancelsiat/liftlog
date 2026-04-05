
const mongoose = require('mongoose');
const dotenv = require('dotenv');
const Workout = require('./models/Workout');
const User = require('./models/User');

dotenv.config();

const migrateWorkouts = async () => {
  try {
    // Connect to the database
    await mongoose.connect(process.env.MONGODB_URI, {
      useNewUrlParser: true,
      useUnifiedTopology: true,
    });
    console.log('MongoDB connected for migration...');

    // --- IMPORTANT --- 
    // Find the specific trainer to assign the workouts to.
    // Replace 'trainer@example.com' with the actual email of the trainer account.
    const trainer = await User.findOne({ email: 'hancel.siat@gmail.com' });

    if (!trainer) {
      console.error('Migration failed: Trainer not found. Please check the email address.');
      process.exit(1);
    }

    console.log(`Found trainer: ${trainer.username} (ID: ${trainer._id})`);

    // Find all workouts that don't have a trainer assigned or the trainer is null
    const result = await Workout.updateMany(
      { 
        $or: [
          { trainer: { $exists: false } },
          { trainer: null }
        ]
      },
      { 
        $set: { trainer: trainer._id } // Assign the found trainer's ID
      }
    );

    console.log('Migration complete!');
    console.log(`Workouts matched: ${result.matchedCount}`);
    console.log(`Workouts modified: ${result.modifiedCount}`);

    if (result.matchedCount === 0) {
        console.log('No unassigned workout templates found to migrate.');
    }

  } catch (error) {
    console.error('An error occurred during migration:', error);
  } finally {
    // Close the database connection
    await mongoose.connection.close();
    console.log('MongoDB connection closed.');
  }
};

migrateWorkouts();
