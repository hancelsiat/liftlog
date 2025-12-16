# Fix Render Database Schema for Progress Collection

## Problem
The MongoDB database on Render has the Progress collection with fields marked as required at the database level, causing validation errors even though the Mongoose model doesn't require them.

## Solution
Run the database schema fix script on Render to update the collection validator.

## Steps to Fix on Render

### Option 1: Using Render Shell (Recommended)
1. Go to your Render dashboard
2. Select your backend service
3. Click on "Shell" tab
4. Run the following command:
   ```bash
   node scripts/fix_progress_schema.js
   ```
5. You should see: "✅ Collection validator updated successfully!"

### Option 2: Using Render One-off Job
1. Go to your Render dashboard
2. Select your backend service
3. Go to "Jobs" section
4. Create a new one-off job with command:
   ```bash
   node scripts/fix_progress_schema.js
   ```
5. Run the job and check the logs

### Option 3: Temporary Route (If Shell access is not available)
If you can't access the Render shell, I can create a temporary admin route that runs this script via an API call. Let me know if you need this option.

## What the Script Does
The script updates the MongoDB collection validator to make all fields optional except the `user` field:
- `bmi` - optional
- `caloriesIntake` - optional  
- `calorieDeficit` - optional
- `lastBmiUpdate` - optional
- `lastCaloriesUpdate` - optional

## Verification
After running the script:
1. Try updating BMI only in your mobile app
2. Try updating calories only in your mobile app
3. Both should work without validation errors

## Alternative: Delete Progress Data (If needed)
If the above doesn't work, you can delete all progress entries:
1. Edit `backend/scripts/fix_progress_schema.js`
2. Uncomment line 36: `// await collection.deleteMany({});`
3. Run the script again
4. This will delete all progress data but fix the issue permanently

## Date
December 16, 2025
