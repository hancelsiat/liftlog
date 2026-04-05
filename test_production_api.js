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

async function testAPI() {
  try {
    console.log('=== TESTING PRODUCTION API ===\n');
    
    // Step 1: Login
    console.log('Step 1: Logging in...');
    const loginResponse = await makeRequest(
      `${RENDER_URL}/api/auth/login`,
      'POST',
      { email: ADMIN_EMAIL, password: ADMIN_PASSWORD }
    );

    if (!loginResponse.data.token) {
      console.error('❌ Login failed:', loginResponse);
      return;
    }
    console.log('✅ Login successful\n');

    const token = loginResponse.data.token;

    // Step 2: Test BMI only update
    console.log('Step 2: Testing BMI only update...');
    const bmiOnlyResponse = await makeRequest(
      `${RENDER_URL}/api/progress`,
      'POST',
      { bmi: 25.5 },
      token
    );
    console.log('Status:', bmiOnlyResponse.status);
    console.log('Response:', JSON.stringify(bmiOnlyResponse.data, null, 2));
    console.log('');

    // Step 3: Test Calories only update
    console.log('Step 3: Testing Calories only update...');
    const caloriesOnlyResponse = await makeRequest(
      `${RENDER_URL}/api/progress`,
      'POST',
      { caloriesIntake: 2000, calorieDeficit: 500 },
      token
    );
    console.log('Status:', caloriesOnlyResponse.status);
    console.log('Response:', JSON.stringify(caloriesOnlyResponse.data, null, 2));
    console.log('');

    // Step 4: Test both together
    console.log('Step 4: Testing BMI + Calories together...');
    const bothResponse = await makeRequest(
      `${RENDER_URL}/api/progress`,
      'POST',
      { bmi: 26, caloriesIntake: 2200, calorieDeficit: 400 },
      token
    );
    console.log('Status:', bothResponse.status);
    console.log('Response:', JSON.stringify(bothResponse.data, null, 2));
    console.log('');

    console.log('=== TEST COMPLETE ===');

  } catch (error) {
    console.error('Error:', error.message);
  }
}

testAPI();
