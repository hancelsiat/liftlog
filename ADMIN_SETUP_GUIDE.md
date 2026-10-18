# Admin Account Setup Guide

## Default Admin Credentials

**Email:** admin@gmail.com  
**Password:** admin123

⚠️ **IMPORTANT:** Change the password after first login for security!

---

## How the Admin Account Works

### 1. Automatic Creation on Server Startup
The server automatically creates the default admin account when it starts up if one doesn't already exist. This ensures that:
- Fresh deployments always have an admin account
- No manual intervention needed for initial setup
- The admin account is created with proper permissions

### 2. Manual Creation Script
You can also manually create or reset the admin account using:

```bash
cd backend
npm run create-admin
```

This script will:
- Check if an admin already exists
- Create a new admin if none exists
- Display the credentials in the console

### 3. Password Reset Script
If you need to reset the admin password back to default:

```bash
cd backend
npm run reset-admin
```

This will reset the password to `admin123` and ensure all flags are properly set.

---

## Admin Account Details

The default admin account is created with:

- **Username:** admin
- **Email:** admin@gmail.com
- **Password:** admin123 (hashed with bcrypt)
- **Role:** admin
- **Email Verified:** Yes
- **Approved:** Yes
- **Membership:** 1 year from creation
- **Profile:**
  - First Name: System
  - Last Name: Administrator

---

## Admin Permissions

The admin account has full system access including:

✅ User Management
- View all users
- Approve/reject trainer accounts
- Update user details
- Delete users
- Manage memberships

✅ Content Management
- Upload training videos
- Create workout templates
- Manage exercises
- View all progress data

✅ System Administration
- Full API access
- No approval requirements
- Bypass all restrictions

---

## Security Recommendations

1. **Change Default Password**
   - Login immediately after setup
   - Navigate to settings
   - Change password to a strong, unique password

2. **Limit Admin Access**
   - Only create admin accounts for trusted personnel
   - Admin accounts cannot be created through the registration API
   - Must be created via scripts or server initialization

3. **Monitor Admin Activity**
   - Review admin actions regularly
   - Check server logs for admin operations

4. **Backup Admin Access**
   - Keep the reset script available
   - Document admin credentials securely
   - Have a recovery plan

---

## Troubleshooting

### Admin Account Not Working?

1. **Check if admin exists:**
   ```bash
   cd backend
   npm run create-admin
   ```
   This will tell you if an admin already exists.

2. **Reset admin password:**
   ```bash
   cd backend
   npm run reset-admin
   ```

3. **Check server logs:**
   Look for `[Init]` messages when server starts to confirm admin creation.

### Can't Login?

- Verify email: admin@gmail.com (all lowercase)
- Verify password: admin123
- Check that server is running
- Check MongoDB connection
- Review server logs for errors

---

## Technical Implementation

### Server Initialization (backend/server.js)
The `createDefaultAdmin()` function runs automatically when the server connects to MongoDB. It:
1. Checks for existing admin account
2. Creates admin if none exists
3. Logs the result to console

### Manual Scripts
- `backend/scripts/create_admin.js` - Creates admin account
- `backend/scripts/reset_admin_password.js` - Resets admin password

### User Model (backend/models/User.js)
- Password is automatically hashed using bcrypt before saving
- Admin role has special permissions in middleware
- Admin accounts bypass approval requirements

---

## For Developers

### Adding Admin Functionality
When adding new features that require admin access:

1. Use the `checkRole(['admin'])` middleware:
   ```javascript
   router.get('/admin-only-route',
     verifyToken,
     checkRole(['admin']),
     async (req, res) => {
       // Admin-only logic
     }
   );
   ```

2. Check role in code:
   ```javascript
   if (req.user.role === 'admin') {
     // Admin-specific logic
   }
   ```

### Preventing Admin Creation via API
The registration endpoint explicitly blocks admin role registration:
```javascript
if (role === 'admin') {
  return res.status(403).json({
    error: 'Admin accounts cannot be created through registration.'
  });
}
```

---

## Quick Reference

| Action | Command |
|--------|---------|
| Create Admin | `cd backend && npm run create-admin` |
| Reset Admin Password | `cd backend && npm run reset-admin` |
| Start Server (auto-creates admin) | `cd backend && npm start` |
| Login Email | admin@gmail.com |
| Default Password | admin123 |

---

**Last Updated:** 2026-10-18
**Version:** 2.1.0 (Admin Moderation, Cooldown Reset, Trainer Bio/Feedback Visibility)

## New Admin Settings & Features

### 1. Deletion of Inappropriate Uploaded Videos and Workouts with Reason
- **Endpoints**: `DELETE /api/videos/admin/:id` and `DELETE /api/workouts/admin/:id` (admin JWT required, body must include `reason`)
- Soft-delete implemented with new schema fields (`isDeleted`, `deletionReason`, `deletedBy`, `deletedAt`).
- Files removed from Supabase; email sent to owner with the reason using `emailService`.
- List endpoints updated to exclude deleted items.
- Perfect for admin moderation panel.
- **Admin listing endpoints**:
  - `GET /api/videos/admin/all?status=active|deleted|all&search=...` returns all trainer videos, public and private, with signed playback URLs, plus `activeCount` and `deletedCount`.
  - `GET /api/workouts/admin/all?status=active|deleted|all&search=...` returns trainer workout templates with their exercises and `assignedCount`, plus the counts.
- **App UI**: on the Admin Dashboard, the **Trainer Videos** and **Trainer Workouts** cards open the `AdminContentModerationScreen` tabs. From there an admin can search, filter, preview a video or expand a workout, then tap **Remove**, pick a preset reason or Other (custom, min 10 chars), and confirm.
- Removing a workout template also hides the copies already assigned to members. Send `removeAssignedCopies: false` in the body to keep them. New assignments record `sourceTemplate`, and older copies are matched by trainer and title.
- Removed templates no longer appear in trainer lists, member trainer-browse lists or `my-plan`, and they can't be assigned again.

### 2. Member Visibility of Feedback Notes Before Choosing Trainer
- Added `bio` field to `User` model for trainers (public self-description and feedback notes).
- New `GET /api/clients/trainers` endpoint returns approved trainers with `bio`.
- Members can now review bios, ratings, and feedback notes **before** selecting a trainer.
- Integrates with existing `Rating.feedback`.

### 3. Admin Cooldown Reset for BMI & Calorie Tracking
- **In the app**: Admin Dashboard → Manage Users → Members → orange **↻ (Reset BMI / Calorie Cooldown)** button on a member card.
  The dialog shows the member's current BMI (7-day) and calorie (24-hour) cooldown with time remaining, lets the admin reset **BMI only**, **Calories only** or **Both** (only options with an active cooldown are enabled), requires a reason (preset or custom, min 5 chars) and lists the last 5 resets.
- **Endpoints**:
  - `GET /api/progress/admin/:userId/cooldown-status` – current cooldown state + recent resets.
  - `POST /api/progress/admin/:userId/reset-cooldown` – body `{ "type": "bmi" | "calories" | "both", "reason": "..." }` (`type` defaults to `both`).
- Clears only the selected timestamp(s) on the latest progress entry, logs `{resetAt, reason, type, admin}` to `cooldownResets`, and emails the client (reason is HTML-escaped).
- Returns 400 if the user has no progress entries yet (nothing to reset), 404 if the user doesn't exist.
- Fully integrated with existing restriction logic (`canUpdateBmi()` etc.) and partial update pattern.
- DB connected via Mongoose with `validateBeforeSave: false`.

All changes align with existing patterns (role middleware, emailService, Supabase, progress fixes). See TODO.md for remaining items. Mobile UI updates recommended for new admin buttons/dialogs (reason input) and trainer list (show `bio`).

## Quick Reference (Updated)
| Action | Endpoint/Command |
|--------|------------------|
| Admin Delete Video | DELETE /api/videos/admin/:id {reason: "..."} |
| Admin Delete Workout | DELETE /api/workouts/admin/:id {reason: "..."} |
| View Cooldown Status | GET /api/progress/admin/:userId/cooldown-status |
| Reset Cooldown | POST /api/progress/admin/:userId/reset-cooldown {type: "bmi"\|"calories"\|"both", reason: "..."} |
| List Trainers w/ Notes | GET /api/clients/trainers |
| Create Admin | `npm run create-admin` |

## Member Cooldown Reset Requests

Members who misclick BMI or calorie updates can ask an admin for a reset instead of waiting out the cooldown.

**Member (Progress screen):** while BMI or Calories is locked, a **Request Reset** card appears under the Calories section. The member picks BMI / Calories / Both and a reason (preset or custom, min 5 chars). Only one pending request is allowed at a time, and it can be cancelled. The card shows when the request was approved or declined (for 3 days).

**Admin (Dashboard > Reset Requests):** filter Pending / Approved / Rejected / All. **Approve & Reset** clears the selected cooldown(s) and emails the member. **Reject** requires a note, which is emailed to the member. A direct reset from User Management also auto-approves that member's pending request.

| Method | Endpoint | Role | Notes |
|---|---|---|---|
| POST | `/api/progress/reset-requests` | member | `{type, reason}`. 400 if not on cooldown, 409 if a request is already pending |
| GET | `/api/progress/reset-requests/mine` | any | Latest request or `null` |
| DELETE | `/api/progress/reset-requests/mine` | any | Cancel pending request |
| GET | `/api/progress/admin/reset-requests?status=pending` | admin | `{requests, pendingCount}` |
| PATCH | `/api/progress/admin/reset-requests/:requestId` | admin | `{action:'approve'|'reject', note}`. Note required for reject. 409 if already handled |
