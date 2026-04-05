# Testing Progress 7-Day Restriction

## Issue
Member can save progress multiple times without waiting 7 days.

## Root Cause Analysis

The backend code in `backend/routes/progress.js` is correct and uses `createdAt` timestamp for the 7-day check. However, the restriction might not be working due to:

1. **Render hasn't deployed yet** - Check Render dashboard for deployment status
2. **Old progress entries** - Existing progress entries might not have `createdAt` field
3. **Time zone issues** - Server time vs local time mismatch

## How to Verify Backend Deployment

### Option 1: Check Render Dashboard
1. Go to your Render dashboard
2. Check the "Events" tab for your backend service
3. Look for "Deploy succeeded" message with timestamp after `fd4da79` commit
4. Check logs for the console.log messages we added

### Option 2: Test the API Directly

**Test 1: Check if you can update**
```bash
curl -X GET "https://your-render-url.onrender.com/api/progress/can-update" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

Expected response if restriction is working:
```json
{
  "canUpdate": false,
  "lastUpdateDate": "2024-01-15T10:30:00.000Z",
  "nextAllowedDate": "2024-01-22T10:30:00.000Z",
  "daysUntilNextUpdate": 5,
  "message": "You can update your progress in 5 day(s)"
}
```

**Test 2: Try to save progress**
```bash
curl -X POST "https://your-render-url.onrender.com/api/progress" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "bmi": 25.5,
    "caloriesIntake": 2000,
    "calorieDeficit": 500
  }'
```

Expected response if restriction is working:
```json
{
  "error": "You can only update your progress once per week",
  "message": "Please wait 5 more day(s) before updating again",
  "lastUpdateDate": "2024-01-15T10:30:00.000Z",
  "nextAllowedDate": "2024-01-22T10:30:00.000Z",
  "canUpdateIn": 5
}
```

## Debugging Steps

### Step 1: Check Render Logs
1. Go to Render dashboard → Your backend service → Logs
2. Look for these console.log messages when you try to save progress:
   ```
   Checking progress for user: [user_id]
   Current time: [timestamp]
   Seven days ago: [timestamp]
   Recent progress found: [progress_object or null]
   Days since last update: [number]
   Days until next update: [number]
   ```

### Step 2: Check Database
The issue might be that old progress entries don't have `createdAt`. Check your MongoDB:

```javascript
// In MongoDB shell or Compass
db.progresses.find({ user: ObjectId("YOUR_USER_ID") }).sort({ createdAt: -1 }).limit(5)
```

Look for:
- Does each progress entry have a `createdAt` field?
- Is `createdAt` recent (within last 7 days)?

### Step 3: Manual Database Fix (if needed)
If old entries don't have `createdAt`, you can set it from the `date` field:

```javascript
// In MongoDB shell
db.progresses.updateMany(
  { createdAt: { $exists: false } },
  [{ $set: { createdAt: "$date", updatedAt: "$date" } }]
)
```

## Quick Fix Options

### Option A: Wait for Render Deployment
- Check Render dashboard
- Wait 2-3 minutes for auto-deployment
- Test again

### Option B: Manual Render Redeploy
1. Go to Render dashboard
2. Click "Manual Deploy" → "Deploy latest commit"
3. Wait for deployment to complete
4. Test again

### Option C: Clear Old Progress Entries (Testing Only)
If you're just testing, you can delete all progress entries for your test user:

```javascript
// In MongoDB
db.progresses.deleteMany({ user: ObjectId("YOUR_TEST_USER_ID") })
```

Then try saving progress again - it should work the first time, but block the second attempt.

## Expected Behavior After Fix

1. **First save**: ✅ Success - Form disappears, orange banner shows "Next update in 7 days"
2. **Immediate second save attempt**: ❌ Blocked - Orange banner remains, form stays hidden
3. **After 7 days**: ✅ Success - Green banner appears, form reappears, can save again

## Mobile App Behavior

The mobile app checks `canUpdate` status on screen load:
- If `canUpdate = false`: Form is hidden, orange warning banner shows
- If `canUpdate = true`: Form is visible, green success banner shows (if not first time)

The form also checks before saving:
- If `canUpdate = false`: Shows error snackbar, doesn't submit
- If `canUpdate = true`: Submits to backend

## Next Steps

1. Check Render deployment status
2. Look at Render logs when you try to save progress
3. Verify the console.log messages appear
4. If logs show correct behavior but mobile still allows multiple saves, the issue is in the mobile app
5. If logs don't appear, Render hasn't deployed the changes yet
