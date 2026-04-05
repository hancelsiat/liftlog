const axios = require('axios');

// --- Configuration ---
const API_BASE_URL = 'https://liftlog-7.onrender.com/api';
const TRAINER_EMAIL = 'james@mail.com';
const TRAINER_PASSWORD = 'james123';
// ---------------------

const api = axios.create({
  baseURL: API_BASE_URL,
  timeout: 15000, // Increased timeout for Render cold starts
});

async function login() {
  console.log('[1/6] Attempting to log in as trainer...');
  try {
    const response = await api.post('/auth/login', {
      email: TRAINER_EMAIL,
      password: TRAINER_PASSWORD,
    });
    const token = response.data.token;
    if (!token) {
      throw new Error('Login failed: No token received.');
    }
    console.log('      -> Login successful.');
    api.defaults.headers.common['Authorization'] = `Bearer ${token}`;
  } catch (error) {
    console.error('      -> Error during login:', error.response ? error.response.data : error.message);
    throw error;
  }
}

async function createTestWorkout() {
  const initialName = `Test Workout ${Date.now()}`;
  const workoutData = {
    title: initialName, // Corrected from 'name' to 'title' to match schema
    description: 'This is an automated test workout for update/delete.',
    exercises: [{ name: 'Test Exercise', sets: 1, reps: 1, rest: 1 }],
    isPublic: true,
  };

  console.log(`[2/6] Creating test workout: "${workoutData.name}"...`);
  try {
    const response = await api.post('/workouts/template', workoutData);
    console.log('      -> Test workout created successfully.');
    return response.data.workout;
  } catch (error) {
    console.error('      -> Error creating workout:', error.response ? error.response.data : error.message);
    throw error;
  }
}

async function updateTestWorkout(workoutId) {
  const updatedName = `Updated Workout ${Date.now()}`;
  console.log(`[3/6] Updating workout ID ${workoutId} with new name: "${updatedName}"...`);
  try {
    const response = await api.patch(`/workouts/${workoutId}`, {
      name: updatedName,
      description: 'This workout has been updated.'
    });
    console.log('      -> Workout updated successfully.');
    return response.data.workout;
  } catch (error) {
    console.error('      -> Error updating workout:', error.response ? error.response.data : error.message);
    throw error;
  }
}

async function verifyUpdate(workoutId, expectedName) {
    console.log(`[4/6] Verifying update for workout ID ${workoutId}...`);
    try {
        const response = await api.get(`/workouts/${workoutId}`);
        const fetchedWorkout = response.data;
        if (fetchedWorkout.name === expectedName) {
            console.log(`      -> SUCCESS: Workout name correctly updated to "${fetchedWorkout.name}"`);
        } else {
            throw new Error(`Verification failed. Expected name '${expectedName}' but got '${fetchedWorkout.name}'`);
        }
    } catch (error) {
        console.error('      -> Error verifying update:', error.response ? error.response.data : error.message);
        throw error;
    }
}

async function deleteTestWorkout(workoutId) {
  console.log(`[5/6] Deleting workout ID ${workoutId}...`);
  try {
    await api.delete(`/workouts/${workoutId}`);
    console.log('      -> Workout deleted successfully.');
  } catch (error) {
    console.error('      -> Error deleting workout:', error.response ? error.response.data : error.message);
    throw error;
  }
}

async function verifyDelete(workoutId) {
    console.log(`[6/6] Verifying deletion of workout ID ${workoutId}...`);
    try {
        await api.get(`/workouts/${workoutId}`);
        // If the above line does not throw an error, the workout was not deleted.
        throw new Error('Verification failed. Workout still exists in the database.');
    } catch (error) {
        if (error.response && error.response.status === 404) {
            console.log('      -> SUCCESS: Workout was correctly removed from the database (received 404 Not Found).');
        } else {
            console.error('      -> Error verifying deletion:', error.message);
            throw error;
        }
    }
}

async function runFullTest() {
  let createdWorkout;
  try {
    await login();
    createdWorkout = await createTestWorkout();
    
    // Test Update
    const updatedWorkout = await updateTestWorkout(createdWorkout._id);
    await verifyUpdate(createdWorkout._id, updatedWorkout.name);

    // Test Delete
    await deleteTestWorkout(createdWorkout._id);
    await verifyDelete(createdWorkout._id);

    console.log('\n\[TEST PASSED] ✅ All create, update, and delete operations are working correctly.');

  } catch (error) {
    console.error('\n\[TEST FAILED] ❌ An error occurred during the test execution.');
    // If a workout was created but the test failed, try to clean it up.
    if (createdWorkout && createdWorkout._id) {
        console.log(`      -> Attempting to clean up created workout (ID: ${createdWorkout._id})...`);
        await deleteTestWorkout(createdWorkout._id).catch(() => console.log('      -> Cleanup failed, workout may already be deleted.'));
    }
  }
}

runFullTest();
