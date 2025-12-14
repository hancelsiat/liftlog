# Weekly Progress Tracking Feature

## Overview
Members can now only update their BMI, calories intake, and calorie deficit **once per week**. This ensures consistent tracking and prevents data spam.

## Features Implemented

### Backend (Node.js/Express)

#### 1. Weekly Restriction Logic (`backend/routes/progress.js`)
- **POST /api/progress**: Creates new progress entry with 7-day restriction
  - Checks if user has updated in the last 7 days
  - Returns error with days remaining if too soon
  - Returns next allowed date on successful save

- **GET /api/progress/can-update**: New endpoint to check update eligibility
  - Returns `canUpdate` boolean
  - Returns `daysUntilNextUpdate` 
  - Returns `nextAllowedDate`
  - Returns helpful message

#### 2. Error Response Format
```json
{
  "error": "You can only update your progress once per week",
  "message": "Please wait 5 more day(s) before updating again",
  "lastUpdateDate": "2024-01-15T10:30:00.000Z",
  "nextAllowedDate": "2024-01-22T10:30:00.000Z",
  "canUpdateIn": 5
}
```

### Frontend (Flutter/Dart)

#### 1. API Service (`mobile/lib/services/api_service.dart`)
- Added `canUpdateProgress()` method to check update status

#### 2. Progress Screen (`mobile/lib/screens/progress_screen.dart`)
- **Visual Indicators**:
  - 🟠 **Orange Warning Banner**: Shows when update is not allowed
    - Displays days until next update
    - Shows exact date when update will be available
  
  - 🟢 **Green Success Banner**: Shows when update is available
    - Encourages user to update their progress

- **Form Behavior**:
  - Form is dimmed (50% opacity) when update not allowed
  - Input fields remain accessible for viewing
  - Save button is disabled when update not allowed
  - Button text changes to "Update Not Available"

- **User Feedback**:
  - Clear error messages if user tries to update too soon
  - Success message shows "Next update available in 7 days"
  - Real-time status checking on screen load

## User Experience Flow

### First Time User
1. Opens Progress screen
2. Sees green "Ready to Update" banner
3. Fills in BMI, calories intake, calorie deficit
4. Clicks "Save Progress"
5. Success message: "Progress saved successfully! Next update available in 7 days."

### User Trying to Update Too Soon (e.g., Day 3)
1. Opens Progress screen
2. Sees orange "Weekly Update Limit" banner
3. Banner shows: "Next update available in 4 day(s)"
4. Banner shows: "Available on: 22/1/2024"
5. Form is dimmed, button disabled
6. If user somehow clicks button: Orange snackbar with error message

### User After 7 Days
1. Opens Progress screen
2. Sees green "Ready to Update" banner again
3. Can update progress normally
4. Cycle repeats

## Benefits

### For Users
- ✅ Consistent weekly tracking
- ✅ Clear visual feedback on update status
- ✅ No confusion about when they can update
- ✅ Prevents accidental duplicate entries

### For Trainers
- ✅ Reliable weekly progress data
- ✅ Better trend analysis
- ✅ Easier to track member progress over time

### For System
- ✅ Prevents database spam
- ✅ Reduces unnecessary API calls
- ✅ Cleaner data for charts and analytics

## Technical Details

### Time Calculation
- Uses 7-day (168-hour) window from last update
- Calculates days remaining: `7 - daysSinceLastUpdate`
- Server-side validation prevents bypassing client restrictions

### Database
- Existing unique index on `(user, date)` prevents duplicate entries per day
- Weekly restriction adds additional business logic layer

### Error Handling
- Graceful degradation if API call fails
- User can still view progress history
- Clear error messages guide user behavior

## Testing Scenarios

1. **First Update**: Should allow immediately
2. **Second Update (Same Day)**: Should block with "0 days" message
3. **Update After 3 Days**: Should block with "4 days remaining"
4. **Update After 7 Days**: Should allow
5. **Update After 10 Days**: Should allow (no penalty for waiting longer)

## Future Enhancements

- [ ] Email notification when update becomes available
- [ ] Push notification reminder
- [ ] Customizable update frequency (admin setting)
- [ ] Progress streak tracking
- [ ] Weekly progress summary report
