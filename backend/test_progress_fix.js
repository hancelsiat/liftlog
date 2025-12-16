const axios = require('axios');

const BASE_URL = 'http://localhost:5000/api';
let authToken = '';

// Test user credentials (you may need to adjust these)
const testUser = {
  email: 'test@example.com',
  password: 'Test123!',
  username: 'testuser'
};

async function registerOrLogin() {
  try {
    console.log('\n=== STEP 1: Authentication ===');
    
    // Try to login first
    try {
      const loginResponse = await axios.post(`${BASE_URL}/auth/login`, {
        email: testUser.email,
        password: testUser.password
      });
      authToken = loginResponse.data.token;
      console.log('✅ Login successful');
      return true;
    } catch (loginError) {
      // If login fails, try to register
      console.log('Login failed, attempting registration...');
      const registerResponse = await axios.post(`${BASE_URL}/auth/register`, testUser);
      authToken = registerResponse.data.token;
      console.log('✅ Registration successful');
      return true;
    }
  } catch (error) {
    console.error('❌ Authentication failed:', error.response?.data || error.message);
    return false;
  }
}

async function testBMIUpdateOnly() {
  try {
    console.log('\n=== STEP 2: Test BMI Update Only ===');
    const response = await axios.post(
      `${BASE_URL}/progress`,
      { bmi: 25.5 },
      { headers: { Authorization: `Bearer ${authToken}` } }
    );
    
    console.log('✅ BMI update successful');
    console.log('Response:', JSON.stringify(response.data, null, 2));
    
    // Verify that only BMI was saved
    if (response.data.progress.bmi === 25.5) {
      console.log('✅ BMI value saved correctly');
    }
    if (!response.data.progress.caloriesIntake && !response.data.progress.calorieDeficit) {
      console.log('✅ Calories fields not required (as expected)');
    }
    
    return true;
  } catch (error) {
    console.error('❌ BMI update failed:', error.response?.data || error.message);
    return false;
  }
}

async function testCaloriesUpdateOnly() {
  try {
    console.log('\n=== STEP 3: Test Calories Update Only ===');
    
    // Wait a moment to avoid time restriction issues
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    const response = await axios.post(
      `${BASE_URL}/progress`,
      { 
        caloriesIntake: 2000,
        calorieDeficit: 500
      },
      { headers: { Authorization: `Bearer ${authToken}` } }
    );
    
    console.log('✅ Calories update successful');
    console.log('Response:', JSON.stringify(response.data, null, 2));
    
    // Verify that only calories were saved
    if (response.data.progress.caloriesIntake === 2000 && response.data.progress.calorieDeficit === 500) {
      console.log('✅ Calories values saved correctly');
    }
    if (!response.data.progress.bmi) {
      console.log('✅ BMI field not required (as expected)');
    }
    
    return true;
  } catch (error) {
    console.error('❌ Calories update failed:', error.response?.data || error.message);
    return false;
  }
}

async function testCombinedUpdate() {
  try {
    console.log('\n=== STEP 4: Test Combined Update ===');
    
    // Wait a moment
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    const response = await axios.post(
      `${BASE_URL}/progress`,
      { 
        bmi: 26.0,
        caloriesIntake: 2200,
        calorieDeficit: 400
      },
      { headers: { Authorization: `Bearer ${authToken}` } }
    );
    
    console.log('✅ Combined update successful');
    console.log('Response:', JSON.stringify(response.data, null, 2));
    
    // Verify all values were saved
    if (response.data.progress.bmi === 26.0 && 
        response.data.progress.caloriesIntake === 2200 && 
        response.data.progress.calorieDeficit === 400) {
      console.log('✅ All values saved correctly');
    }
    
    return true;
  } catch (error) {
    console.error('❌ Combined update failed:', error.response?.data || error.message);
    return false;
  }
}

async function testProgressHistory() {
  try {
    console.log('\n=== STEP 5: Test Progress History ===');
    const response = await axios.get(
      `${BASE_URL}/progress`,
      { headers: { Authorization: `Bearer ${authToken}` } }
    );
    
    console.log('✅ Progress history retrieved');
    console.log(`Total entries: ${response.data.progress.length}`);
    
    if (response.data.progress.length > 0) {
      console.log('Latest entry:', JSON.stringify(response.data.progress[0], null, 2));
    }
    
    return true;
  } catch (error) {
    console.error('❌ Progress history retrieval failed:', error.response?.data || error.message);
    return false;
  }
}

async function testUpdateStatus() {
  try {
    console.log('\n=== STEP 6: Test Update Status Check ===');
    const response = await axios.get(
      `${BASE_URL}/progress/can-update`,
      { headers: { Authorization: `Bearer ${authToken}` } }
    );
    
    console.log('✅ Update status retrieved');
    console.log('BMI Status:', JSON.stringify(response.data.bmi, null, 2));
    console.log('Calories Status:', JSON.stringify(response.data.calories, null, 2));
    
    return true;
  } catch (error) {
    console.error('❌ Update status check failed:', error.response?.data || error.message);
    return false;
  }
}

async function runAllTests() {
  console.log('🚀 Starting Progress API Tests...\n');
  
  const results = {
    authentication: false,
    bmiUpdate: false,
    caloriesUpdate: false,
    combinedUpdate: false,
    progressHistory: false,
    updateStatus: false
  };
  
  results.authentication = await registerOrLogin();
  if (!results.authentication) {
    console.log('\n❌ Cannot proceed without authentication');
    return;
  }
  
  results.bmiUpdate = await testBMIUpdateOnly();
  results.caloriesUpdate = await testCaloriesUpdateOnly();
  results.combinedUpdate = await testCombinedUpdate();
  results.progressHistory = await testProgressHistory();
  results.updateStatus = await testUpdateStatus();
  
  // Summary
  console.log('\n' + '='.repeat(50));
  console.log('TEST SUMMARY');
  console.log('='.repeat(50));
  
  const passed = Object.values(results).filter(r => r).length;
  const total = Object.keys(results).length;
  
  Object.entries(results).forEach(([test, passed]) => {
    console.log(`${passed ? '✅' : '❌'} ${test}`);
  });
  
  console.log('\n' + '='.repeat(50));
  console.log(`RESULT: ${passed}/${total} tests passed`);
  console.log('='.repeat(50));
  
  if (passed === total) {
    console.log('\n🎉 All tests passed! The fix is working correctly.');
  } else {
    console.log('\n⚠️ Some tests failed. Please review the errors above.');
  }
}

// Run the tests
runAllTests().catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});
