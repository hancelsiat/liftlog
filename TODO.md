# Fix LiftLog Errors

## 1. BMI Validation Error
- Error: Progress validation failed: bmi (61) is more than maximum allowed value (50)
- Fix: Set max: Infinity for bmi field in backend/models/Progress.js

## 2. Workout Template Creation 404
- Error: Cannot POST /api/workouts/template
- Investigation: Route exists in backend/routes/workouts.js
- Possible fixes: Check server registration, URL in mobile, or restart server

## 3. Training Videos Load 500
- Error: Failed to retrieve video
- Fix: Change error message in backend/routes/videos.js GET / from "Failed to retrieve videos" to "Failed to retrieve video"

## 4. Video Upload Failure
- Error: Video upload failed: Something broke!
- Fix: Ensure POST / in videos.js returns JSON errors instead of triggering general error handler

## Steps to Implement
- [x] Update Progress.js for BMI max
- [x] Update videos.js error messages
- [ ] Test workout template route
- [ ] Test video upload and load
- [ ] Restart server if needed
