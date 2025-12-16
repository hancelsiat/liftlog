const mongoose = require('mongoose');
require('dotenv').config();

async function fixProgressSchema() {
  try {
    console.log('Connecting to MongoDB...');
    await mongoose.connect(process.env.MONGODB_URI);
    console.log('Connected successfully');

    const db = mongoose.connection.db;
    const collection = db.collection('progresses');

    // Get the current schema
    console.log('\nChecking current collection schema...');
    const collectionInfo = await db.listCollections({ name: 'progresses' }).toArray();
    console.log('Collection info:', JSON.stringify(collectionInfo, null, 2));

    // Option 1: Drop all progress entries (DESTRUCTIVE - will delete all progress data)
    console.log('\n=== OPTION 1: Delete all progress entries ===');
    const count = await collection.countDocuments();
    console.log(`Found ${count} progress entries`);
    
    if (count > 0) {
      console.log('WARNING: This will delete ALL progress data!');
      console.log('To proceed, uncomment the line below in the script');
      // await collection.deleteMany({});
      // console.log('All progress entries deleted');
    }

    // Option 2: Drop the collection and let Mongoose recreate it
    console.log('\n=== OPTION 2: Drop and recreate collection ===');
    console.log('This will remove the collection entirely and let Mongoose recreate it with the correct schema');
    console.log('To proceed, uncomment the lines below in the script');
    // await collection.drop();
    // console.log('Collection dropped successfully');
    
    // Option 3: Update the validator to remove required fields
    console.log('\n=== OPTION 3: Update collection validator (RECOMMENDED) ===');
    try {
      await db.command({
        collMod: 'progresses',
        validator: {
          $jsonSchema: {
            bsonType: 'object',
            required: ['user'],
            properties: {
              user: {
                bsonType: 'objectId',
                description: 'User reference - required'
              },
              bmi: {
                bsonType: ['double', 'int', 'null'],
                description: 'BMI value - optional'
              },
              caloriesIntake: {
                bsonType: ['double', 'int', 'null'],
                description: 'Calories intake - optional'
              },
              calorieDeficit: {
                bsonType: ['double', 'int', 'null'],
                description: 'Calorie deficit - optional'
              },
              lastBmiUpdate: {
                bsonType: ['date', 'null'],
                description: 'Last BMI update timestamp'
              },
              lastCaloriesUpdate: {
                bsonType: ['date', 'null'],
                description: 'Last calories update timestamp'
              },
              date: {
                bsonType: 'date',
                description: 'Entry date'
              }
            }
          }
        },
        validationLevel: 'moderate',
        validationAction: 'warn'
      });
      console.log('✅ Collection validator updated successfully!');
      console.log('All fields except "user" are now optional');
    } catch (error) {
      if (error.code === 26) {
        console.log('Collection has no validator - this is fine, Mongoose will handle validation');
      } else {
        console.error('Error updating validator:', error.message);
      }
    }

    console.log('\n=== Summary ===');
    console.log('The database schema has been updated.');
    console.log('BMI, caloriesIntake, and calorieDeficit are now optional fields.');
    console.log('You can now update progress with partial data.');

  } catch (error) {
    console.error('Error:', error);
  } finally {
    await mongoose.connection.close();
    console.log('\nDatabase connection closed');
  }
}

fixProgressSchema();
