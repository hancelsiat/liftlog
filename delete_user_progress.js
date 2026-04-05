const https = require('https');

const BASE_URL = 'liftlog-7.onrender.com';

// Admin credentials
const ADMIN_EMAIL = 'admin@gmail.com';
const ADMIN_PASSWORD = 'admin123';

function makeRequest(method, path, data = null, token = null) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: BASE_URL,
      port: 443,
      path: path,
      method: method,
      headers: {
        'Content-Type': 'application/json',
      }
    };

    if (token) {
      options.headers['Authorization'] = `Bearer ${token}`;
    }

    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => body += chunk);
      res.on('end', () => {
        try {
          const parsed = JSON.parse(body);
          resolve({ status: res.statusCode, data: parsed });
        } catch (e) {
          resolve({ status: res.statusCode, data: body });
        }
      });
    });

    req.on('error', reject);
    
    if (data) {
      req.write(JSON.stringify(data));
    }
    
    req.end();
  });
}

async function main() {
  console.log('=== DELETE USER PROGRESS ===\n');
  
  // Step 1: Login
  console.log('Step 1: Logging in as admin...');
  const loginRes = await makeRequest('POST', '/api/auth/login', {
    email: ADMIN_EMAIL,
    password: ADMIN_PASSWORD
  });
  
  if (loginRes.status !== 200) {
    console.log('❌ Login failed:', loginRes.data);
    return;
  }
  
  const token = loginRes.data.token;
  console.log('✅ Login successful\n');
  
  // Step 2: Delete all progress
  console.log('Step 2: Deleting all progress entries...');
  const deleteRes = await makeRequest('DELETE', '/api/progress/admin/delete-all', null, token);
  console.log('Status:', deleteRes.status);
  console.log('Response:', deleteRes.data);
  console.log('');
  
  // Step 3: Test BMI only
  console.log('Step 3: Testing BMI only update (fresh)...');
  const bmiRes = await makeRequest('POST', '/api/progress', {
    bmi: 25.5
  }, token);
  console.log('Status:', bmiRes.status);
  if (bmiRes.status === 201) {
    console.log('✅ BMI only update WORKS!\n');
  } else {
    console.log('❌ BMI only update FAILED');
    console.log('Error:', bmiRes.data);
    console.log('');
  }
  
  // Step 4: Test Calories only (new user scenario)
  console.log('Step 4: Deleting progress again for calories test...');
  await makeRequest('DELETE', '/api/progress/admin/delete-all', null, token);
  
  console.log('Step 5: Testing Calories only update (fresh)...');
  const calRes = await makeRequest('POST', '/api/progress', {
    caloriesIntake: 2000,
    calorieDeficit: 500
  }, token);
  console.log('Status:', calRes.status);
  if (calRes.status === 201) {
    console.log('✅ Calories only update WORKS!\n');
  } else {
    console.log('❌ Calories only update FAILED');
    console.log('Error:', calRes.data);
    console.log('');
  }
  
  console.log('=== TEST COMPLETE ===');
}

main().catch(console.error);
