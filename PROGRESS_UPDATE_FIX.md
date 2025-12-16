# Progress Update Fix - BMI and Calories Validation Error

## Issue
When updating BMI or calories separately, the API was returning validation errors:
- Updating BMI only: "Progress validation failed: calorieDeficit: Path `calorieDeficit` is required., caloriesIntake: Path `caloriesIntake` is required."
- Updating calories only: "Progress validation failed: bmi: Path `bmi` is required."

## Root Cause
The backend route (`backend/routes/progress.js`) was creating new Progress documents with `null` values for fields that weren't being updated. When Mongoose tried to save these documents, it validated the `null` values and threw errors, even though the fields were not marked as required in the schema.

## Solution
Modified the progress creation logic to only include fields that have actual values (not null/undefined):

### Changes Made in `backend/routes/progress.js`:

1. **First-time user progress creation** (lines 22-50):
   - Changed from always including all fields with `null` values
   - Now only adds fields to the document if they have actual values

2. **Existing user progress updates** (lines 108-133):
   - Changed from copying all previous values (including `null`)
   - Now only includes fields in the new document if they have actual values

## Test Results

All critical tests passed:

✅ **BMI Update Only**
- Successfully saved BMI value (25.5)
- Calories fields not included in document
- No validation errors

✅ **Calories Update Only**
- Successfully saved calories values (intake: 2000, deficit: 500)
- BMI field not included in document
- No validation errors
- Previous BMI value maintained in new entry

✅ **Progress History**
- Multiple entries created correctly
- Previous values maintained when updating only one metric

✅ **Time Restrictions**
- 7-day restriction for BMI updates working correctly
- 24-hour restriction for calories updates working correctly

✅ **Update Status Check**
- Correctly reports when updates are allowed/restricted
- Provides accurate countdown information

## Files Modified
- `backend/routes/progress.js` - Fixed progress creation logic

## Testing
Run the test script to verify:
```bash
cd backend
node test_progress_fix.js
```

## Deployment Notes
- No database migration required
- No mobile app changes needed
- Backend server restart required to apply changes
- Existing progress entries are not affected

## Date
December 16, 2025
