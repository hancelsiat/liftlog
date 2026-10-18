// Calls the admin moderation endpoints on a running server with a real admin token.
// Usage (from backend/): node scripts/testModerationEndpoints.js [baseUrl]
// Default baseUrl: http://localhost:5055/api
require('dotenv').config();
const http = require('http');
const https = require('https');
const mongoose = require('mongoose');
const User = require('../models/User');
const { generateToken } = require('../middleware/auth');

const base = process.argv[2] || 'http://localhost:5055/api';

function get(url, token) {
  return new Promise((resolve) => {
    const lib = url.startsWith('https') ? https : http;
    const req = lib.get(url, { headers: { Authorization: `Bearer ${token}` } }, (res) => {
      let body = '';
      res.on('data', (c) => { body += c; });
      res.on('end', () => resolve({ status: res.statusCode, body }));
    });
    req.on('error', (e) => resolve({ status: 0, body: e.message }));
    req.setTimeout(90000, () => { req.destroy(new Error('timeout')); });
  });
}

(async () => {
  await mongoose.connect(process.env.MONGODB_URI, { serverSelectionTimeoutMS: 15000 });
  const admin = await User.findOne({ role: 'admin' });
  await mongoose.disconnect();
  if (!admin) {
    console.log('No admin user found');
    return;
  }
  const token = generateToken(admin);

  const checks = [
    ['videos/admin/all?status=active', 'videos'],
    ['videos/admin/all?status=all', 'videos'],
    ['workouts/admin/all?status=active', 'workouts'],
    ['workouts/admin/all?status=active&search=push', 'workouts'],
    ['progress/admin/reset-requests?status=pending', 'requests'],
    ['progress/admin/reset-requests?status=all', 'requests'],
  ];

  for (const [path, key] of checks) {
    const r = await get(`${base}/${path}`, token);
    let summary = r.body.slice(0, 150);
    try {
      const json = JSON.parse(r.body);
      if (Array.isArray(json[key])) {
        const titles = json[key].slice(0, 3).map((x) => x.title || (x.user && x.user.username) || x._id);
        summary = `${key}=${json[key].length} ${JSON.stringify(titles)}`
          + (json.activeCount !== undefined ? ` active=${json.activeCount} removed=${json.deletedCount}` : '')
          + (json.pendingCount !== undefined ? ` pending=${json.pendingCount}` : '')
          + (key === 'videos' && json[key][0] ? ` firstHasUrl=${!!json[key][0].videoUrl}` : '');
      }
    } catch (_) { /* non-JSON body */ }
    console.log(`${r.status}  GET /${path}  ->  ${summary}`);
  }
})().catch((e) => { console.error(e); process.exitCode = 1; });
