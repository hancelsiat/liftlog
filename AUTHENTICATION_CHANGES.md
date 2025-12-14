# Authentication & Registration Changes

## Overview
This document outlines the changes made to the authentication and registration system for LiftLog.

## Changes Implemented

### 1. **Removed Admin Registration from Sign-Up**
- Admin role option has been removed from the registration screen
- Users can only register as **Member** or **Trainer**
- Admin accounts can only be created through the backend script

### 2. **Default Admin Account**
A default admin account has been created with the following credentials:

```
Email: admin@gmail.com
Password: admin123
```

**⚠️ IMPORTANT SECURITY NOTE:**
- Change this password immediately after first login
- This is a default account for initial setup only

#### Creating the Admin Account
Run the following command in the backend directory:

```bash
cd backend
npm run create-admin
```

This will create the default admin account if it doesn't already exist.

### 3. **Trainer Email Verification**
Trainers now require email verification before they can access the system:

#### Registration Flow for Trainers:
1. Trainer registers with email and password
2. System generates a verification token
3. Verification link is logged to console (email integration pending)
4. Trainer must click the verification link
5. After email verification, trainer account is marked as "pending admin approval"
6. Admin must approve the trainer account
7. Only then can the trainer log in and access the system

#### Verification Process:
- Verification tokens expire after 24 hours
- Verification link format: `http://localhost:5000/api/auth/verify-email/{token}`
- Token is hashed and stored securely in the database

### 4. **Member Registration**
Members can register and access the system immediately:
- No email verification required
- Auto-approved upon registration
- Can log in immediately after registration

## Database Schema Changes

### User Model Updates
New fields added to the User schema:

```javascript
{
  isEmailVerified: {
    type: Boolean,
    default: false
  },
  emailVerificationToken: {
    type: String,
    default: null
  },
  emailVerificationExpires: {
    type: Date,
    default: null
  },
  isApproved: {
    type: Boolean,
    default: true // Members auto-approved, trainers need approval
  }
}
```

### New Methods:
- `generateEmailVerificationToken()` - Generates secure verification token
- `canAccess()` - Checks if user can access the system based on role and verification status

## API Endpoints

### New Endpoints:

#### 1. Email Verification
```
GET /api/auth/verify-email/:token
```
Verifies a trainer's email address using the verification token.

**Response:**
```json
{
  "message": "Email verified successfully. Your account is pending admin approval.",
  "user": {
    "id": "user_id",
    "email": "trainer@example.com",
    "isEmailVerified": true,
    "isApproved": false
  }
}
```

#### 2. Approve Trainer Account (Admin Only)
```
PATCH /api/auth/users/:userId/approve
Authorization: Bearer {admin_token}
```

**Request Body:**
```json
{
  "isApproved": true
}
```

**Response:**
```json
{
  "message": "Trainer account approved",
  "user": {
    "id": "user_id",
    "username": "trainer_username",
    "email": "trainer@example.com",
    "role": "trainer",
    "isEmailVerified": true,
    "isApproved": true
  }
}
```

### Modified Endpoints:

#### Registration
```
POST /api/auth/register
```

**Changes:**
- Prevents admin role registration (returns 403 error)
- For trainers: generates verification token and returns different response
- For members: works as before with immediate access

**Trainer Registration Response:**
```json
{
  "message": "Trainer account created. Please check your email to verify your account. Admin approval is also required.",
  "requiresVerification": true,
  "user": {
    "id": "user_id",
    "username": "trainer_username",
    "email": "trainer@example.com",
    "role": "trainer",
    "isEmailVerified": false,
    "isApproved": false
  }
}
```

#### Login
```
POST /api/auth/login
```

**Changes:**
- Checks if trainer account is verified and approved
- Returns specific error messages for unverified or unapproved trainers

**Error Responses for Trainers:**
```json
// If email not verified
{
  "error": "Please verify your email address before logging in. Check your email for the verification link."
}

// If not approved by admin
{
  "error": "Your trainer account is pending admin approval. Please wait for approval."
}
```

## UI Changes

### Register Screen
- Removed admin role chip
- Added info message for trainers about verification requirement
- Shows blue info box when trainer role is selected
- Only displays Member and Trainer options

### Mobile App Updates
The register screen now shows:
- Two role options: Member and Trainer
- Info message for trainers: "Trainer accounts require email verification before activation."

## Admin Dashboard Features

Admins can now:
1. View all pending trainer accounts
2. Approve or reject trainer registrations
3. See verification status of all users
4. Manage user accounts with new fields (isEmailVerified, isApproved)

## Testing

### Test Scenarios:

#### 1. Member Registration
```bash
# Should work immediately
POST /api/auth/register
{
  "username": "testmember",
  "email": "member@test.com",
  "password": "password123",
  "role": "member"
}
# Can login immediately
```

#### 2. Trainer Registration
```bash
# Step 1: Register
POST /api/auth/register
{
  "username": "testtrainer",
  "email": "trainer@test.com",
  "password": "password123",
  "role": "trainer"
}
# Returns verification token in console

# Step 2: Verify email (use token from console)
GET /api/auth/verify-email/{token}

# Step 3: Admin approves (requires admin token)
PATCH /api/auth/users/{userId}/approve
Authorization: Bearer {admin_token}
{
  "isApproved": true
}

# Step 4: Trainer can now login
POST /api/auth/login
{
  "email": "trainer@test.com",
  "password": "password123"
}
```

#### 3. Admin Login
```bash
POST /api/auth/login
{
  "email": "admin@gmail.com",
  "password": "admin123"
}
```

#### 4. Attempt Admin Registration (Should Fail)
```bash
POST /api/auth/register
{
  "username": "newadmin",
  "email": "admin2@test.com",
  "password": "password123",
  "role": "admin"
}
# Returns 403 error
```

## Security Considerations

1. **Verification Tokens**: 
   - Tokens are hashed using SHA-256 before storage
   - Tokens expire after 24 hours
   - One-time use only

2. **Admin Account**:
   - Default password should be changed immediately
   - Consider implementing password change enforcement on first login

3. **Email Verification**:
   - Currently logs to console (development)
   - TODO: Integrate with email service (SendGrid, AWS SES, etc.)

4. **Trainer Approval**:
   - Two-step verification (email + admin approval)
   - Prevents unauthorized trainer accounts

## Future Enhancements

1. **Email Integration**:
   - Integrate with email service provider
   - Send professional verification emails
   - Add email templates

2. **Password Reset**:
   - Implement forgot password functionality
   - Use similar token-based verification

3. **Admin Notifications**:
   - Notify admins when new trainers register
   - Dashboard alerts for pending approvals

4. **Trainer Application**:
   - Add trainer application form
   - Collect credentials, certifications
   - Document upload for verification

5. **Audit Log**:
   - Track admin approvals/rejections
   - Log verification attempts
   - Monitor suspicious activities

## Migration Notes

If you have existing data:

1. Run database migration to add new fields
2. Set `isEmailVerified = true` for existing users
3. Set `isApproved = true` for existing trainers
4. Create admin account using the script

```bash
# In backend directory
npm run create-admin
```

## Support

For issues or questions:
- Check console logs for verification tokens (development)
- Verify database connection
- Ensure all dependencies are installed
- Check that MongoDB is running

## Changelog

### Version 1.1.0
- Added email verification for trainers
- Removed admin registration from public API
- Created default admin account script
- Updated User model with verification fields
- Enhanced login validation
- Added admin approval endpoint
- Updated mobile UI to reflect changes
