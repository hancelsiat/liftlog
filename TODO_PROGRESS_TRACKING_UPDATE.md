# Progress Tracking Update - Separate Time Restrictions

## Requirements
- **BMI**: Can only be updated once per week (7 days)
- **Calories Intake & Deficit**: Can be updated every 24 hours
- Lock input fields individually based on their respective restrictions
- Show timer/date for when each field can be updated again

## Implementation Plan

### Backend Changes

1. **backend/models/Progress.js**
   - Add `lastBmiUpdate` timestamp field
   - Add `lastCaloriesUpdate` timestamp field
   - Keep existing fields for backward compatibility
   - Add methods to check if updates are allowed

2. **backend/routes/progress.js**
   - Modify POST route to accept partial updates (BMI only, Calories only, or both)
   - Add separate validation for BMI (7 days) and Calories (24 hours)
   - Update `/can-update` endpoint to return separate status for BMI and Calories
   - Add new endpoints:
     - `POST /progress/bmi` - Update BMI only
     - `POST /progress/calories` - Update calories only
     - `GET /progress/can-update-bmi` - Check if BMI can be updated
     - `GET /progress/can-update-calories` - Check if calories can be updated

### Mobile App Changes

1. **mobile/lib/models/progress.dart**
   - Add fields for tracking update times
   - Add methods to calculate time until next update

2. **mobile/lib/services/api_service.dart**
   - Add methods for separate BMI and Calories updates
   - Add methods to check individual update status

3. **mobile/lib/screens/progress_screen.dart**
   - Split form into two sections: BMI section and Calories section
   - Add individual timers/countdown for each section
   - Lock/unlock fields independently
   - Show separate status banners for BMI and Calories
   - Update save logic to handle partial updates

## Tasks Checklist

### Backend
- [x] Update Progress model with timestamp fields
- [x] Modify progress routes for separate restrictions
- [x] Add new API endpoints for partial updates
- [x] Update can-update endpoint to return separate status

### Mobile App
- [x] Update Progress model
- [x] Add API service methods for partial updates
- [x] Redesign progress screen UI with separate sections
- [x] Add individual timers and status indicators
- [x] Implement separate save buttons for BMI and Calories

### Testing
- [ ] Test BMI update restriction (7 days)
- [ ] Test Calories update restriction (24 hours)
- [ ] Test partial updates (BMI only, Calories only)
- [ ] Test UI timers and countdowns
- [ ] Test field locking/unlocking

## Implementation Summary

### Backend Changes
1. **Progress Model** - Added `lastBmiUpdate` and `lastCaloriesUpdate` timestamp fields with helper methods
2. **Progress Routes** - Modified POST endpoint to handle partial updates with separate time restrictions
3. **Can-Update Endpoint** - Returns separate status for BMI (7 days) and Calories (24 hours)

### Mobile App Changes
1. **Progress Model** - Added nullable fields and timestamp tracking with helper methods
2. **API Service** - Added `createProgressPartial()` method for flexible updates
3. **Progress Screen** - Complete redesign with:
   - Separate BMI and Calories sections
   - Individual status banners showing lock/unlock state
   - Countdown timers (days for BMI, hours for Calories)
   - Disabled input fields when locked
   - Separate save buttons for each section
   - Auto-refresh timer every minute

### Key Features
- ✅ BMI updates restricted to once per week (7 days)
- ✅ Calories updates restricted to every 24 hours
- ✅ Visual feedback with color-coded status banners
- ✅ Countdown timers showing time until next update
- ✅ Fields automatically lock/unlock based on restrictions
- ✅ Separate save buttons for independent updates
- ✅ Real-time status updates

## Benefits
- ✅ More flexible progress tracking
- ✅ Users can update calories daily while BMI is weekly
- ✅ Clear visual feedback on when each field can be updated
- ✅ Better user experience with granular control
