# Deploy Backend Fixes to Render

## ⚠️ CRITICAL: Weekly Progress Fix Not Working Yet

The backend code has been updated locally, but **Render is still running the old code**. You need to deploy the changes.

---

## Quick Deploy Steps

### 1. Check Git Status
```bash
git status
```

### 2. Add All Changes
```bash
git add .
```

### 3. Commit Changes
```bash
git commit -m "Fix: Weekly progress restriction now enforces 7-day limit using createdAt timestamp"
```

### 4. Push to GitHub
```bash
git push origin main
```
(Replace `main` with your branch name if different)

### 5. Render Will Auto-Deploy
- Go to your Render dashboard
- Watch the deployment logs
- Wait for "Deploy succeeded" message

---

## Verify the Fix is Deployed

### Check Render Logs

After deployment, test the progress save and check Render logs for these messages:

```
Checking progress for user: [user_id]
Current time: [timestamp]
Seven days ago: [timestamp]
Recent progress found: [progress object or null]
Days since last update: [number]
Days until next update: [number]
```

If you see these logs, the new code is deployed! ✅

---

## Test the Weekly Restriction

### Test Steps:

1. **Login as member**
2. **Save progress** (first time)
   - Should succeed
   - See: "Progress logged successfully"
   
3. **Try to save again immediately**
   - Should FAIL with error
   - Should see: "Please wait X more day(s)"
   - Orange warning banner should appear
   - Save button should be disabled

4. **Check Render logs**
   - Should show: "Days until next update: 7" (or 6, 5, etc.)

---

## About Email Verification

### Current Status: ⚠️ Emails Not Actually Sent

The backend currently **only logs the verification link to the console**. It doesn't send actual emails.

**What happens now:**
1. Trainer registers
2. Backend generates verification token
3. Token is logged to Render console (not emailed)
4. Trainer sees "check your email" message
5. **But no email is actually sent**

### Workaround for Now:

**Option 1: Skip Email Verification (Recommended for Testing)**
- Admin can approve trainer directly in User Management
- Trainer can then login without email verification

**Option 2: Get Token from Render Logs**
- Check Render logs after trainer registration
- Look for: `Verification token for [email]: [token]`
- Manually construct URL: `http://localhost:5000/api/auth/verify-email/[token]`
- Visit URL to verify email

### To Add Real Email Sending (Future):

You'll need to:
1. Set up email service (SendGrid, Mailgun, etc.)
2. Add email credentials to Render environment variables
3. Update `backend/routes/auth.js` to actually send emails

---

## Current File Changes

### Backend:
- ✅ `backend/routes/progress.js` - Fixed weekly restriction

### Frontend:
- ✅ `mobile/lib/screens/workouts_screen.dart` - Removed duplicate back button
- ✅ `mobile/lib/screens/register_screen.dart` - Added trainer approval flow + clarified email message

---

## After Deployment

### 1. Test Progress Restriction
```bash
# Try to save progress twice in a row
# Second attempt should fail
```

### 2. Check Logs
```bash
# In Render dashboard, view logs
# Look for "Days until next update" messages
```

### 3. Verify Error Response
The API should return:
```json
{
  "error": "You can only update your progress once per week",
  "message": "Please wait 7 more day(s) before updating again",
  "canUpdateIn": 7
}
```

---

## Troubleshooting

### If Progress Still Saves Twice:

1. **Check Render deployment status**
   - Make sure deployment succeeded
   - Check deployment logs for errors

2. **Verify code is deployed**
   - Check Render logs for the new console.log messages
   - If you don't see them, code isn't deployed yet

3. **Clear old progress entries (if testing)**
   ```bash
   # Connect to MongoDB
   # Delete test progress entries
   db.progresses.deleteMany({ user: ObjectId("your_user_id") })
   ```

4. **Check MongoDB connection**
   - Make sure Render can connect to MongoDB
   - Check environment variables are set

---

## Summary

**To fix the weekly progress issue:**
1. ✅ Code is ready (already updated locally)
2. ⏳ **YOU NEED TO**: Push to Git
3. ⏳ **RENDER WILL**: Auto-deploy
4. ⏳ **THEN TEST**: Try saving progress twice

**About email verification:**
- Currently not sending real emails (just logging)
- Trainers can be approved by admin without email verification
- This is OK for testing/development
