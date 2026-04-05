const https = require('https');

const RENDER_URL = 'https://liftlog-7.onrender.com';
const ADMIN_EMAIL = 'admin@gmail.com';
const ADMIN_PASSWORD = 'admin123';

// Function to make HTTP requests
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
          resolve(JSON.parse(body));
        } catch (e) {
          resolve(body);
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

async function fixDatabase() {
  try {
    console.log('Step 1: Logging in as admin...');
    const loginResponse = await makeRequest(
      `${RENDER_URL}/api/auth/login`,
      'POST',
      { email: ADMIN_EMAIL, password: ADMIN_PASSWORD }
    );

    if (!loginResponse.token) {
      console.error('Login failed:', loginResponse);
      return;
    }

    console.log('✅ Login successful!');
    console.log('Token:', loginResponse.token.substring(0, 20) + '...');

    console.log('\nStep 2: Fixing database schema...');
    const fixResponse = await makeRequest(
      `${RENDER_URL}/api/progress/admin/fix-schema`,
      'POST',
      {},
      loginResponse.token
    );

    console.log('\n✅ Database fix response:');
    console.log(JSON.stringify(fixResponse, null, 2));

    if (fixResponse.success) {
      console.log('\n🎉 SUCCESS! The database schema has been fixed!');
      console.log('You can now update BMI and calories without validation errors.');
    } else {
      console.log('\n⚠️ Response received but check the message above.');
    }

  } catch (error) {
    console.error('Error:', error.message);
  }
}

fixDatabase();
