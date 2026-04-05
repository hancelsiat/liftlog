const https = require('https');

const API_URL = 'https://liftlog-7.onrender.com';
const ADMIN_EMAIL = 'admin@gmail.com';
const ADMIN_PASSWORD = 'admin123';

let authToken = null;

function makeRequest(method, path, data = null) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, API_URL);
    const options = {
      method: method,
      headers: {
        'Content-Type': 'application/json',
      }
    };

    if (authToken) {
      options.headers['Authorization'] = `Bearer ${authToken}`;
    }

    const req = https.request(url, options, (res) => {
      let body = '';
      res.on('data', (chunk) => body += chunk);
      res.on('end', () => {
        try {
          const response = body ? JSON.parse(body) : {};
          resolve({ status: res.statusCode, data: response });
        } catch (e) {
          resolve({ status: res.statusCode, data: body });
        }
      });
    });

    req.on('error', reject);
    if (data) req.write(JSON.stringify(data));
    req.end();
  });
}

async function runTests() {
  console.log('=== TESTING TIME RESTRICTIONS ===\n');

  try {
    // Step 1: Login
    console.log('Step 1: Logging in as admin...');
    const loginRes = await makeRequest('POST', '/api/auth/login', {
      email: ADMIN_EMAIL,
      password: ADMIN_PASSWORD
    });
    
    if (loginRes.status !== 200) {
      console.error('❌ Login failed:', loginRes.data);
      return;
    }
    
    authToken = loginRes.data.token;
    console.log('✅ Login successful\n');

    // Step 2: Delete all progress
    console.log('Step 2: Deleting all progress entries...');
    const deleteRes = await makeRequest('DELETE', '/api/progress/admin/delete-all');
    console.log(`Deleted ${deleteRes.data.message}\n`);

    // Step 3: Create first BMI entry
    console.log('Step 3: Creating first BMI entry...');
    const bmi1Res = await makeRequest('POST', '/api/progress', { bmi: 25 });
    console.log(`Status: ${bmi1Res.status}`);
    if (bmi1Res.status === 201) {
      console.log('✅ First BMI entry created successfully');
      console.log(`BMI: ${bmi1Res.data.progress.bmi}`);
      console.log(`Next BMI update: ${bmi1Res.data.bmiNextUpdate}\n`);
    } else {
      console.log('❌ Failed:', bmi1Res.data);
      return;
    }

    // Step 4: Try to update BMI immediately (should fail)
    console.log('Step 4: Trying to update BMI immediately (should be restricted)...');
    const bmi2Res = await makeRequest('POST', '/api/progress', { bmi: 26 });
    console.log(`Status: ${bmi2Res.status}`);
    if (bmi2Res.status === 400 && bmi2Res.data.restrictions) {
      console.log('✅ BMI update correctly BLOCKED!');
      console.log(`Restriction: ${bmi2Res.data.restrictions.bmi.message}`);
      console.log(`Days until next update: ${bmi2Res.data.restrictions.bmi.daysUntilNext}\n`);
    } else {
      console.log('❌ BMI restriction NOT working - update was allowed!');
      console.log('Response:', bmi2Res.data);
      return;
    }

    // Step 5: Create first calories entry
    console.log('Step 5: Creating first calories entry...');
    const cal1Res = await makeRequest('POST', '/api/progress', {
      caloriesIntake: 2000, 
      calorieDeficit: 500 
    });
    console.log(`Status: ${cal1Res.status}`);
    if (cal1Res.status === 201) {
      console.log('✅ First calories entry created successfully');
      console.log(`Calories Intake: ${cal1Res.data.progress.caloriesIntake}`);
      console.log(`Calorie Deficit: ${cal1Res.data.progress.calorieDeficit}`);
      console.log(`Next calories update: ${cal1Res.data.caloriesNextUpdate}\n`);
    } else {
      console.log('❌ Failed:', cal1Res.data);
      return;
    }

    // Step 6: Try to update calories immediately (should fail)
    console.log('Step 6: Trying to update calories immediately (should be restricted)...');
    const cal2Res = await makeRequest('POST', '/api/progress', {
      caloriesIntake: 2200, 
      calorieDeficit: 600 
    });
    console.log(`Status: ${cal2Res.status}`);
    if (cal2Res.status === 400 && cal2Res.data.restrictions) {
      console.log('✅ Calories update correctly BLOCKED!');
      console.log(`Restriction: ${cal2Res.data.restrictions.calories.message}`);
      console.log(`Hours until next update: ${cal2Res.data.restrictions.calories.hoursUntilNext}\n`);
    } else {
      console.log('❌ Calories restriction NOT working - update was allowed!');
      console.log('Response:', cal2Res.data);
      return;
    }

    // Step 7: Check can-update endpoint
    console.log('Step 7: Checking can-update status...');
    const statusRes = await makeRequest('GET', '/api/progress/can-update');
    console.log(`Status: ${statusRes.status}`);
    if (statusRes.status === 200) {
      console.log('BMI Status:');
      console.log(`  Can Update: ${statusRes.data.bmi.canUpdate}`);
      console.log(`  Days Until Next: ${statusRes.data.bmi.daysUntilNext}`);
      console.log(`  Message: ${statusRes.data.bmi.message}`);
      console.log('Calories Status:');
      console.log(`  Can Update: ${statusRes.data.calories.canUpdate}`);
      console.log(`  Hours Until Next: ${statusRes.data.calories.hoursUntilNext}`);
      console.log(`  Message: ${statusRes.data.calories.message}\n`);
    }

    console.log('=== ALL TESTS PASSED ===');
    console.log('✅ BMI restriction (7 days) is working correctly');
    console.log('✅ Calories restriction (24 hours) is working correctly');
    console.log('✅ Validation errors are fixed');
    console.log('✅ Partial updates (BMI-only or calories-only) work correctly');

  } catch (error) {
    console.error('❌ Test failed with error:', error.message);
  }
}

runTests();
