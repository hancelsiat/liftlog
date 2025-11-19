// debug-drive-gridfs.js
// Usage:
//   node debug-drive-gridfs.js <FILE_ID> <ACCESS_TOKEN> <MONGODB_URI>
// Example:
//   node debug-drive-gridfs.js 1AbC...ya "ya29.a0Af..." "mongodb+srv://user:pass@cluster0.rq5d2xo.mongodb.net/mydb?retryWrites=true&w=majority"

const { google } = require('googleapis');
const { MongoClient, GridFSBucket } = require('mongodb');
const { pipeline } = require('stream/promises');
const fs = require('fs');

async function main() {
  try {
    const [,, fileId, accessToken, mongoUri] = process.argv;
    if (!fileId || !accessToken || !mongoUri) {
      console.error('Usage: node debug-drive-gridfs.js <FILE_ID> <ACCESS_TOKEN> <MONGODB_URI>');
      process.exit(2);
    }

    console.log('[init] Starting debug script');
    console.log('[init] fileId:', fileId);

    // 1) Check Drive metadata
    const oauth2Client = new google.auth.OAuth2();
    oauth2Client.setCredentials({ access_token: accessToken });
    const drive = google.drive({ version: 'v3', auth: oauth2Client });

    let meta;
    try {
      console.log('[drive] fetching metadata...');
      const metaRes = await drive.files.get({ fileId, fields: 'id,name,mimeType,size' });
      meta = metaRes.data;
      console.log('[drive] metadata ok:', { id: meta.id, name: meta.name, mimeType: meta.mimeType, size: meta.size });
    } catch (err) {
      console.error('[drive][meta] ERROR fetching metadata');
      console.error(err && (err.stack || err));
      process.exit(10);
    }

    // 2) Attempt a small-range download (first 1 MiB) to prove Drive streaming works
    // Use headers to request a byte-range. googleapis supports passing headers via the second param.
    const RANGE_BYTES = 1024 * 1024; // 1 MiB
    let mediaRes;
    try {
      console.log(`[drive] requesting first ${RANGE_BYTES} bytes...`);
      mediaRes = await drive.files.get(
        { fileId, alt: 'media' },
        { responseType: 'stream', headers: { Range: `bytes=0-${RANGE_BYTES - 1}` } }
      );
      if (!mediaRes || !mediaRes.data) throw new Error('Drive returned no stream');
      console.log('[drive] got stream; headers:', Object.keys(mediaRes.headers || {}).length ? mediaRes.headers : '(no headers)');
    } catch (err) {
      console.error('[drive][media] ERROR fetching media (range request)');
      console.error(err && (err.stack || err));
      process.exit(11);
    }

    // 3) Connect to MongoDB Atlas
    let client;
    try {
      console.log('[mongo] connecting to', mongoUri.substring(0, 60) + '...');
      client = new MongoClient(mongoUri, { serverSelectionTimeoutMS: 10000, maxPoolSize: 10 });
      await client.connect();
      console.log('[mongo] connected ok');
    } catch (err) {
      console.error('[mongo] CONNECTION ERROR');
      console.error(err && (err.stack || err));
      process.exit(12);
    }

    const db = client.db(); // default from URI
    const bucket = new GridFSBucket(db, { bucketName: 'videos' });

    // 4) Stream partial content to GridFS (safe small write)
    try {
      const tmpName = `debug-${Date.now()}-${(meta.name || 'file').replace(/\s+/g,'_')}.part`;
      console.log('[gridfs] opening upload stream (partial test) with filename:', tmpName);
      const uploadStream = bucket.openUploadStream(tmpName, {
        metadata: { debug: true, source: 'drive-partial' },
        contentType: meta.mimeType
      });

      uploadStream.on('error', e => {
        console.error('[gridfs] uploadStream ERROR');
        console.error(e && (e.stack || e));
      });

      uploadStream.on('finish', () => {
        console.log('[gridfs] finish event — partial file saved as id:', uploadStream.id.toString());
      });

      // Pipe the Drive partial stream into GridFS
      console.log('[pipeline] piping Drive -> GridFS (partial)');
      await pipeline(mediaRes.data, uploadStream);
      console.log('[pipeline] completed without throwing');

      // Optionally fetch the stored file metadata
      const fileDoc = await db.collection('videos.files').findOne({ _id: uploadStream.id });
      console.log('[verify] files collection document:', fileDoc ? { _id: fileDoc._id.toString(), filename: fileDoc.filename, length: fileDoc.length } : 'NOT FOUND');

      console.log('[done] debug script finished successfully');
      await client.close();
      process.exit(0);
    } catch (err) {
      console.error('[gridfs|pipeline] ERROR during streaming or write');
      console.error(err && (err.stack || err));
      if (client) await client.close().catch(()=>{});
      process.exit(13);
    }

  } catch (unhandled) {
    console.error('[FATAL] unhandled exception', unhandled && (unhandled.stack || unhandled));
    process.exit(99);
  }
}

main();
