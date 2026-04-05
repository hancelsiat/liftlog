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

**Last Updated:** 2024
**Version:** 1.0.0
