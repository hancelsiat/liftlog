// backend/routes/presign.js
const express = require('express');
const router = express.Router();
const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = process.env.SUPABASE_URL;
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const BUCKET = process.env.SUPABASE_BUCKET || 'videos';

if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
  console.error('presign route: missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
}

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

// POST /api/presign
// body: { filename, contentType, expiresIn (optional seconds) }
router.post('/presign', async (req, res) => {
  try {
    const { filename, contentType, expiresIn = 600 } = req.body;
    if (!filename || !contentType) {
      return res.status(400).json({ error: 'filename and contentType required' });
    }

    const key = `videos/${Date.now()}-${Math.floor(Math.random()*1e9)}-${filename}`;

    const { data, error } = await supabase
      .storage
      .from(BUCKET)
      .createSignedUploadUrl(key, expiresIn);

    if (error) {
      console.error('Supabase presign error:', error);
      return res.status(500).json({ error: 'presign_failed', message: error.message || error });
    }

    return res.json({ signedUploadUrl: data.signedUrl, token: data.token, path: key });
  } catch (err) {
    console.error('presign exception:', err);
    return res.status(500).json({ error: 'presign_exception', message: err.message || String(err) });
  }
});

module.exports = router;
