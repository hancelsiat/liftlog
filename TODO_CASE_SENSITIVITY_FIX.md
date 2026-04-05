# Case Sensitivity Fix for Exercise Type

## Problem
Exercise type input is case-sensitive, causing validation failures when users input "Strength", "CARDIO", etc. instead of lowercase values.

## Tasks

### Backend Fixes
- [x] Fix `backend/routes/videos.js` - Convert exerciseType to lowercase (line 113)
- [x] Fix `backend/models/ExerciseVideo.js` - Add pre-save hook for lowercase conversion

### Mobile App Improvements
- [x] Update `mobile/lib/screens/video_upload_screen.dart` - Replace text input with dropdown
- [x] Update `mobile/lib/services/api_service.dart` - Add defensive lowercase conversion

### Testing
- [ ] Test video upload with various case inputs
- [ ] Verify dropdown works correctly
- [ ] Confirm backend validation passes

## Valid Exercise Types
- cardio
- strength
- flexibility
- balance
- sports
- other

## Changes Made

### Backend (Node.js/Express)
1. **backend/routes/videos.js**
   - Added `.toLowerCase()` to exerciseType parsing on line 104
   - Ensures all incoming exercise types are normalized to lowercase before validation

2. **backend/models/ExerciseVideo.js**
   - Added pre-save hook to automatically convert exerciseType to lowercase
   - Provides additional safety layer for any direct database operations

### Mobile App (Flutter/Dart)
1. **mobile/lib/services/api_service.dart**
   - Added `.toLowerCase()` to exerciseType in uploadVideo method
   - Defensive programming to ensure lowercase values are sent to backend

2. **mobile/lib/screens/video_upload_screen.dart**
   - Replaced free-text TextFormField with DropdownButtonFormField
   - Added predefined list of valid exercise types
   - Displays options in uppercase for better readability
   - Stores and sends values in lowercase
   - Prevents user input errors entirely

## Benefits
- ✅ Case-insensitive exercise type input
- ✅ Better user experience with dropdown selector
- ✅ Prevents validation errors
- ✅ Multiple layers of protection (client + server)
- ✅ Clear visual feedback of available options
