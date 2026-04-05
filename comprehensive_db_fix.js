const https = require('https');

const RENDER_URL = 'https://liftlog-7.onrender.com';
const ADMIN_EMAIL = 'admin@gmail.com';
const ADMIN_PASSWORD = 'admin123';

function makeRequest(url, method, data, token = null) {
  return new Promise((resolve, reject) => {
    const urlObj = new URL(url);
    const options = {
      hostname: urlObj.hostname,
      port: 443,
      path: urlObj.pathname,
      method: method,
      headers: {
        'Content-Type': 'application/json',
      }
    };

    if (token) {
      options.headers['Authorization'] = `Bearer ${token}`;
    }

    if (data) {
      const postData = JSON.stringify(data);
      options.headers['Content-Length'] = Buffer.byteLength(postData);
    }

    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => body += chunk);
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, data: JSON.parse(body) });
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

async function comprehensiveFix() {
  try {
    console.log('=== COMPREHENSIVE DATABASE FIX ===\n');
    
    // Step 1: Login
    console.log('Step 1: Logging in as admin...');
    const loginResponse = await makeRequest(
      `${RENDER_URL}/api/auth/login`,
      'POST',
      { email: ADMIN_EMAIL, password: ADMIN_PASSWORD }
    );

    if (!loginResponse.data.token) {
      console.error('❌ Login failed');
      return;
    }
    console.log('✅ Login successful\n');

    const token = loginResponse.data.token;

    // Step 2: Run schema fix again (in case it didn't fully apply)
    console.log('Step 2: Running database schema fix...');
    const fixResponse = await makeRequest(
      `${RENDER_URL}/api/progress/admin/fix-schema`,
      'POST',
      {},
      token
    );
    console.log('Status:', fixResponse.status);
    console.log('Response:', JSON.stringify(fixResponse.data, null, 2));
    console.log('');

    // Step 3: Test BMI only
    console.log('Step 3: Testing BMI only update...');
    const bmiTest = await makeRequest(
      `${RENDER_URL}/api/progress`,
      'POST',
      { bmi: 24.5 },
      token
    );
    console.log('Status:', bmiTest.status);
    if (bmiTest.status === 201 || bmiTest.status === 200) {
      console.log('✅ BMI only update WORKS!');
    } else {
      console.log('❌ BMI only update FAILED');
      console.log('Error:', JSON.stringify(bmiTest.data, null, 2));
    }
    console.log('');

    // Step 4: Test Calories only
    console.log('Step 4: Testing Calories only update...');
    const caloriesTest = await makeRequest(
      `${RENDER_URL}/api/progress`,
      'POST',
      { caloriesIntake: 1800, calorieDeficit: 300 },
      token
    );
    console.log('Status:', caloriesTest.status);
    if (caloriesTest.status === 201 || caloriesTest.status === 200) {
      console.log('✅ Calories only update WORKS!');
    } else {
      console.log('❌ Calories only update FAILED');
      console.log('Error:', JSON.stringify(caloriesTest.data, null, 2));
    }
    console.log('');

    console.log('=== FIX COMPLETE ===');

  } catch (error) {
    console.error('Error:', error.message);
  }
}

comprehensiveFix();
