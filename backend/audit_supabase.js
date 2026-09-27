require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_KEY = process.env.SUPABASE_KEY;

async function auditSupabase() {
  console.log('========================================');
  console.log('SUPABASE AUDIT & HEALTH CHECK');
  console.log('========================================\n');

  if (!SUPABASE_URL || !SUPABASE_KEY) {
    console.log('ERROR: SUPABASE_URL or SUPABASE_KEY is missing in .env!');
    process.exit(1);
  }

  console.log(`Supabase URL: ${SUPABASE_URL}`);
  console.log(`Supabase Key: ${SUPABASE_KEY.substring(0, 15)}...\n`);

  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);
    console.log('✅ Client created successfully.\n');

    // 1. List Storage Buckets
    console.log('1. Checking Storage Buckets...');
    try {
      const { data: buckets, error: bucketError } = await supabase.storage.listBuckets();
      if (bucketError) throw bucketError;

      console.log(`   Total Buckets Found: ${buckets.length}`);
      if (buckets.length === 0) {
        console.log('   ⚠️  WARNING: NO BUCKETS EXIST!');
        console.log('      The app will fail to upload trainer credentials or videos.');
        console.log('      You MUST create these buckets manually in Supabase Dashboard:');
        console.log('        - "trainer-credentials" (for ID uploads)');
        console.log('        - "exercise-videos" OR "videos" (for workout video uploads)');
      } else {
        const expectedBuckets = ['trainer-credentials', 'exercise-videos', 'videos'];
        for (const b of buckets) {
          console.log(`   - 📦 ${b.name} | Public: ${b.public} | File Count: checking...`);
          try {
            const { data: files, error: fErr } = await supabase.storage.from(b.name).list();
            if (fErr) console.log(`     Warning: Could not list files: ${fErr.message}`);
            else console.log(`     Files inside: ${files.length}`);
          } catch (e) {
            console.log(`     Error listing files: ${e.message}`);
          }
        }

        console.log('\n   Checking for REQUIRED buckets...');
        const hasTrainerCreds = buckets.some(b => b.name === 'trainer-credentials');
        if (hasTrainerCreds) {
          console.log('   ✅ "trainer-credentials" bucket FOUND.');
        } else {
          console.log('   ❌ "trainer-credentials" bucket MISSING! Trainers cannot upload ID proofs.');
          console.log('   👉 Create this bucket NOW on Supabase Dashboard -> Storage -> New Bucket');
        }
      }
    } catch (e) {
      console.log(`   ❌ Failed to list buckets: ${e.message}`);
    }
    console.log('');

    // 2. Check Database Tables (optional, but useful)
    console.log('2. Checking Database Connection & Tables (via SQL query)...');
    try {
      const { data, error } = await supabase
        .from('_test_connection')
        .select('*')
        .limit(1);
      
      if (error && error.code === '42P01') { // Table doesn't exist error means we connected successfully
        console.log('   ✅ Database connection OK. (We queried a fake table to verify connectivity)');
      } else if (error && error.code !== '42P01') {
        console.log(`   ❌ Database error: ${error.message}. Code: ${error.code}`);
        if (error.code === '42501') {
          console.log('      PERMISSION ERROR: Check your anon/service role policy.');
        }
      } else {
        console.log('   ✅ Database connection OK.');
      }
    } catch (dbErr) {
      console.log(`   Warning: DB check failed: ${dbErr.message}`);
    }

    console.log('\n========================================');
    console.log('SUPABASE AUDIT COMPLETE');
    console.log('========================================');

  } catch (globalError) {
    console.error('FATAL ERROR DURING SUPABASE AUDIT:', globalError.message);
    if (globalError.message.includes('Failed to fetch') || globalError.message.includes('ENOTFOUND')) {
      console.log('Network error. Check your URL or internet connection.');
    }
    process.exit(1);
  }
}

auditSupabase();
