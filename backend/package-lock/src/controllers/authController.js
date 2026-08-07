const authService = require('../services/authService');
const { OAuth2Client } = require('google-auth-library');
const { validateEmailOrThrow } = require('../utils/emailValidation');
const client = new OAuth2Client(process.env.GOOGLE_CLIENT_ID);

// Staff logins whose profile + password are admin-managed and read-only to them.
const MANAGED_STAFF_ROLES = ['EMPLOYEE', 'SECURITY', 'COACH'];

// Roles whose PASSWORD is managed by a higher admin (so they cannot self-change
// it), but who may still edit their own profile (name/phone). A COMPLEX_ADMIN's
// password is set/reset only by the Super Admin via the Complex Admins page.
const PASSWORD_MANAGED_ROLES = [...MANAGED_STAFF_ROLES, 'COMPLEX_ADMIN'];

// Roles allowed to sign in through the ADMIN PORTAL. Everyone else (User, Coach,
// Employee, Security) must use the public website.
const ADMIN_PORTAL_ROLES = ['ADMIN', 'COMPLEX_ADMIN'];

/**
 * Enforce which login surface ("portal") a given role may use.
 *  - portal 'admin' → only administrators (ADMIN / COMPLEX_ADMIN)
 *  - portal 'main'  → everyone EXCEPT administrators (they belong in the admin portal)
 *  - any other/absent value → no restriction (backwards compatible with older clients)
 * Returns a user-facing error message when access is denied, otherwise null.
 */
function portalAccessError(portal, role) {
  const isAdmin = ADMIN_PORTAL_ROLES.includes(String(role || '').toUpperCase());
  if (portal === 'admin' && !isAdmin) {
    return 'This portal is for administrators only. Please log in through the main Nahata Sports website.';
  }
  if (portal === 'main' && isAdmin) {
    return 'Administrator accounts must log in through the Nahata Sports Admin Portal.';
  }
  return null;
}

class AuthController {
  async register(req, res) {
    try {
      const { name, phone_number, email, password, role } = req.body;

      // Validate input — phone / WhatsApp number is now required at signup.
      if (!name || !email || !password || !phone_number) {
        return res.status(400).json({
          success: false,
          message: 'Name, email, WhatsApp number, and password are required'
        });
      }

      // Validate email format & catch common domain typos (e.g. "gamil.com").
      // A bad address bounces and the user never gets their welcome/booking
      // emails, so reject it up front with a helpful suggestion.
      let normalizedEmail;
      try {
        normalizedEmail = validateEmailOrThrow(email, 'Email');
      } catch (emailErr) {
        return res.status(400).json({
          success: false,
          message: emailErr.message
        });
      }

      if (password.length < 6) {
        return res.status(400).json({
          success: false,
          message: 'Password must be at least 6 characters long'
        });
      }

      // Validate role if provided
      const validRoles = ['USER', 'ADMIN', 'EMPLOYEE', 'COACH', 'SECURITY'];
      if (role && !validRoles.includes(role.toUpperCase())) {
        return res.status(400).json({
          success: false,
          message: 'Invalid role. Must be one of: USER, ADMIN, EMPLOYEE, COACH, SECURITY'
        });
      }

      const result = await authService.register({
        name,
        phone_number,
        email: normalizedEmail,
        password,
        role: role ? role.toUpperCase() : 'USER' // Convert to uppercase and default to USER
      });

      // Set HTTP-only cookies
      res.cookie('accessToken', result.accessToken, {
        httpOnly: true,
        secure: process.env.NODE_ENV === 'production',
        sameSite: 'strict',
        maxAge: 15 * 60 * 1000 // 15 minutes
      });

      res.cookie('refreshToken', result.refreshToken, {
        httpOnly: true,
        secure: process.env.NODE_ENV === 'production',
        sameSite: 'strict',
        maxAge: 7 * 24 * 60 * 60 * 1000 // 7 days
      });

      res.status(201).json({
        success: true,
        message: 'User registered successfully',
        data: {
          user: result.user,
          accessToken: result.accessToken,
          refreshToken: result.refreshToken
        }
      });
    } catch (error) {
      res.status(400).json({
        success: false,
        message: error.message
      });
    }
  }

  async login(req, res) {
    try {
      // Accept EITHER an email OR a WhatsApp number as the identifier. `identifier`
      // is the new field; `email` is kept for backward compatibility (the admin
      // panel and older clients still send `email`).
      const identifier = req.body.identifier ?? req.body.email;
      const { password, portal } = req.body;

      // Validate input
      if (!identifier || !password) {
        return res.status(400).json({
          success: false,
          message: 'Email or WhatsApp number, and password are required'
        });
      }

      const result = await authService.login(identifier, password);

      // Enforce which portal this role may sign in from (admin panel vs website).
      const accessDenied = portalAccessError(portal, result.user.role);
      if (accessDenied) {
        return res.status(403).json({ success: false, message: accessDenied });
      }

      // Set HTTP-only cookies
      res.cookie('accessToken', result.accessToken, {
        httpOnly: true,
        secure: process.env.NODE_ENV === 'production',
        sameSite: 'strict',
        maxAge: 15 * 60 * 1000 // 15 minutes
      });

      res.cookie('refreshToken', result.refreshToken, {
        httpOnly: true,
        secure: process.env.NODE_ENV === 'production',
        sameSite: 'strict',
        maxAge: 7 * 24 * 60 * 60 * 1000 // 7 days
      });

      res.status(200).json({
        success: true,
        message: 'Login successful',
        data: {
          user: result.user,
          accessToken: result.accessToken,
          refreshToken: result.refreshToken
        }
      });
    } catch (error) {
      res.status(401).json({
        success: false,
        message: error.message
      });
    }
  }

  async googleLogin(req, res) {
    try {
      const { credential, portal } = req.body;

      if (!credential) {
        return res.status(400).json({
          success: false,
          message: 'Google credential is required'
        });
      }

      // Verify Google token
      const ticket = await client.verifyIdToken({
        idToken: credential,
        audience: process.env.GOOGLE_CLIENT_ID
      });

      const payload = ticket.getPayload();
      const { sub: googleId, email, name, picture: avatar } = payload;

      const result = await authService.googleLogin({
        googleId,
        email,
        name,
        avatar
      });

      // Enforce portal access (Google sign-in is only offered on the website).
      const accessDenied = portalAccessError(portal, result.user.role);
      if (accessDenied) {
        return res.status(403).json({ success: false, message: accessDenied });
      }

      // Set HTTP-only cookies
      res.cookie('accessToken', result.accessToken, {
        httpOnly: true,
        secure: process.env.NODE_ENV === 'production',
        sameSite: 'none',
        maxAge: 15 * 60 * 1000 // 15 minutes
      });

      res.cookie('refreshToken', result.refreshToken, {
        httpOnly: true,
        secure: process.env.NODE_ENV === 'production',
        sameSite: 'none',
        maxAge: 7 * 24 * 60 * 60 * 1000 // 7 days
      });

      res.status(200).json({
        success: true,
        message: 'Google login successful',
        data: {
          user: result.user,
          accessToken: result.accessToken,
          refreshToken: result.refreshToken
        }
      });
    } catch (error) {
      console.error('Google Auth Error:', error);
      res.status(401).json({
        success: false,
        message: 'Google authentication failed'
      });
    }
  }

  async refreshToken(req, res) {
    try {
      // Accept refresh token from cookie OR request body (for cross-origin clients)
      const refreshToken = req.cookies.refreshToken || req.body.refreshToken;

      if (!refreshToken) {
        return res.status(401).json({
          success: false,
          message: 'Refresh token not provided'
        });
      }

      const result = await authService.refreshToken(refreshToken);

      // Set new HTTP-only cookies (for same-origin clients)
      res.cookie('accessToken', result.accessToken, {
        httpOnly: true,
        secure: process.env.NODE_ENV === 'production',
        sameSite: 'none',
        maxAge: 15 * 60 * 1000 // 15 minutes
      });

      res.cookie('refreshToken', result.refreshToken, {
        httpOnly: true,
        secure: process.env.NODE_ENV === 'production',
        sameSite: 'none',
        maxAge: 7 * 24 * 60 * 60 * 1000 // 7 days
      });

      res.status(200).json({
        success: true,
        message: 'Token refreshed successfully',
        data: {
          accessToken: result.accessToken,
          refreshToken: result.refreshToken
        }
      });
    } catch (error) {
      res.status(401).json({
        success: false,
        message: error.message
      });
    }
  }

  async logout(req, res) {
    try {
      const userId = req.user?.id;

      if (userId) {
        await authService.logout(userId);
      }

      // Clear cookies
      res.cookie('accessToken', '', {
        httpOnly: true,
        secure: process.env.NODE_ENV === 'production',
        sameSite: 'strict',
        maxAge: 0
      });

      res.cookie('refreshToken', '', {
        httpOnly: true,
        secure: process.env.NODE_ENV === 'production',
        sameSite: 'strict',
        maxAge: 0
      });

      res.status(200).json({
        success: true,
        message: 'Logout successful'
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        message: 'Logout failed'
      });
    }
  }

  async getProfile(req, res) {
    try {
      const user = await authService.getUserById(req.user.id);
      
      if (!user) {
        return res.status(404).json({
          success: false,
          message: 'User not found'
        });
      }

      res.status(200).json({
        success: true,
        user
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        message: 'Failed to get user profile'
      });
    }
  }

  /**
   * GET /api/auth/staff-details
   *
   * The admin-entered record behind a staff login, so an EMPLOYEE or COACH can
   * see their own details on My Profile. Read-only by design — these fields are
   * maintained by the admin, not the staff member.
   *
   * Pay is deliberately excluded (Employee.salary, Coach.price): a staff member
   * viewing their own profile should not surface compensation here.
   *
   * Returns { role, sections: [{ title, fields: [{ label, value }] }] } so the
   * UI can render whatever exists without knowing each model's shape.
   */
  async getStaffDetails(req, res) {
    try {
      const { Employee, Coach, Sport, SportComplex, User } = require('../models');
      const role = String(req.user.role || '').toUpperCase();

      const fmtDate = (d) => (d ? new Date(d).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' }) : null);
      // Drop empty values so the UI never renders a row with nothing in it.
      const clean = (fields) => fields.filter((f) => f.value !== null && f.value !== undefined && String(f.value).trim() !== '');

      const sections = [];

      if (role === 'EMPLOYEE') {
        const emp = await Employee.findOne({
          where: { userId: req.user.id },
          include: [{ model: SportComplex, as: 'sportComplex', attributes: ['name'], required: false }],
        });
        const account = await User.findByPk(req.user.id, {
          attributes: ['employee_id', 'department', 'assigned_location', 'assigned_sports', 'join_date', 'status'],
        });

        if (emp) {
          sections.push({
            title: 'Employment Details',
            fields: clean([
              { label: 'Employee ID', value: emp.employeeId },
              { label: 'Designation', value: emp.designation },
              { label: 'Department', value: emp.department },
              { label: 'Shift', value: emp.shift },
              { label: 'Joining Date', value: fmtDate(emp.joiningDate) },
              { label: 'Status', value: emp.status },
              { label: 'Sports Complex', value: emp.sportComplex ? emp.sportComplex.name : null },
              { label: 'Contact Number', value: emp.phone },
              { label: 'Address', value: emp.address },
            ]),
          });
        }

        if (account) {
          const assigned = Array.isArray(account.assigned_sports)
            ? account.assigned_sports.join(', ')
            : account.assigned_sports;
          const accountFields = clean([
            { label: 'Employee ID', value: emp ? null : account.employee_id },
            { label: 'Department', value: emp ? null : account.department },
            { label: 'Assigned Location', value: account.assigned_location },
            { label: 'Assigned Sports', value: assigned },
            { label: 'Joined On', value: fmtDate(account.join_date) },
            { label: 'Account Status', value: account.status },
          ]);
          if (accountFields.length > 0) sections.push({ title: 'Account', fields: accountFields });
        }
      } else if (role === 'COACH') {
        // Coaches link to their login by email — the Coaches table has no userId.
        const coach = await Coach.findOne({
          where: { email: req.user.email },
          include: [
            { model: Sport, as: 'sport', attributes: ['name'], required: false },
            { model: SportComplex, as: 'sportComplex', attributes: ['name'], required: false },
          ],
        });

        if (coach) {
          sections.push({
            title: 'Coaching Details',
            fields: clean([
              { label: 'Sport', value: coach.sport ? coach.sport.name : null },
              { label: 'Sports Complex', value: coach.sportComplex ? coach.sportComplex.name : null },
              { label: 'Ground', value: coach.ground },
              // `experience` is free text and often already carries its unit
              // ("10 year"), so only append "years" when it is a bare number.
              {
                label: 'Experience',
                value: coach.experience == null || String(coach.experience).trim() === ''
                  ? null
                  : /^\d+(\.\d+)?$/.test(String(coach.experience).trim())
                    ? `${String(coach.experience).trim()} years`
                    : String(coach.experience).trim(),
              },
              { label: 'Specialization', value: coach.specialization },
              { label: 'Availability', value: coach.availability },
              { label: 'Status', value: coach.status },
              { label: 'Contact Number', value: coach.phone },
            ]),
          });
          const quals = clean([
            { label: 'Certification', value: coach.certification },
            { label: 'Qualifications', value: coach.qualifications },
            { label: 'About', value: coach.bio },
          ]);
          if (quals.length > 0) sections.push({ title: 'Qualifications', fields: quals });
        }
      }

      return res.status(200).json({ success: true, data: { role, sections } });
    } catch (error) {
      console.error('❌ getStaffDetails error:', error);
      return res.status(500).json({ success: false, message: error.message });
    }
  }

  async updateProfile(req, res) {
    try {
      // Staff logins (Employee / Security / Coach) have admin-managed profiles
      // that are read-only to themselves; an admin maintains their details.
      if (MANAGED_STAFF_ROLES.includes(String(req.user?.role || '').toUpperCase())) {
        return res.status(403).json({
          success: false,
          message: 'Your profile is managed by your administrator and cannot be edited here.'
        });
      }

      const updatedUser = await authService.updateProfile(req.user.id, req.body);

      res.status(200).json({
        success: true,
        message: 'Profile updated successfully',
        user: updatedUser,
        // `data.user` mirrors `user` for the admin panel's expected response shape
        data: { user: updatedUser }
      });
    } catch (error) {
      res.status(400).json({
        success: false,
        message: error.message
      });
    }
  }

  async changePassword(req, res) {
    try {
      // Staff logins AND complex admins have admin-managed passwords: they cannot
      // change their own. A higher admin must reset it instead (the Super Admin
      // resets a complex admin's password from the Complex Admins page).
      if (PASSWORD_MANAGED_ROLES.includes(String(req.user?.role || '').toUpperCase())) {
        return res.status(403).json({
          success: false,
          message: 'Your password is managed by your administrator and cannot be changed here. Please contact them to reset it.'
        });
      }

      const { currentPassword, newPassword } = req.body;

      if (!currentPassword || !newPassword) {
        return res.status(400).json({
          success: false,
          message: 'Current password and new password are required'
        });
      }

      if (newPassword.length < 6) {
        return res.status(400).json({
          success: false,
          message: 'New password must be at least 6 characters long'
        });
      }

      const result = await authService.changePassword(
        req.user.id,
        currentPassword,
        newPassword
      );

      res.status(200).json({
        success: true,
        ...result
      });
    } catch (error) {
      res.status(400).json({
        success: false,
        message: error.message
      });
    }
  }

  async uploadProfilePicture(req, res) {
    try {
      // Staff logins have admin-managed, read-only profiles.
      if (MANAGED_STAFF_ROLES.includes(String(req.user?.role || '').toUpperCase())) {
        return res.status(403).json({
          success: false,
          message: 'Your profile is managed by your administrator and cannot be edited here.'
        });
      }

      if (!req.cloudinaryResult || !req.cloudinaryResult.url) {
        return res.status(400).json({
          success: false,
          message: 'No image file provided'
        });
      }

      const url = req.cloudinaryResult.url;
      await authService.updateProfile(req.user.id, { avatar: url });

      res.status(200).json({
        success: true,
        message: 'Profile picture updated successfully',
        data: { url }
      });
    } catch (error) {
      res.status(400).json({
        success: false,
        message: error.message
      });
    }
  }

  async forgotPassword(req, res) {
    try {
      const { email } = req.body;

      // Validate input
      if (!email) {
        return res.status(400).json({
          success: false,
          message: 'Email is required'
        });
      }

      const result = await authService.forgotPassword(email);

      res.status(200).json({
        success: true,
        ...result
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        message: 'Failed to process forgot password request'
      });
    }
  }

  async resetPassword(req, res) {
    try {
      const { token, newPassword } = req.body;

      // Validate input
      if (!token || !newPassword) {
        return res.status(400).json({
          success: false,
          message: 'Token and new password are required'
        });
      }

      if (newPassword.length < 6) {
        return res.status(400).json({
          success: false,
          message: 'Password must be at least 6 characters long'
        });
      }

      const result = await authService.resetPassword(token, newPassword);

      res.status(200).json({
        success: true,
        ...result
      });
    } catch (error) {
      res.status(400).json({
        success: false,
        message: error.message
      });
    }
  }

  async setPassword(req, res) {
    try {
      const { token, password } = req.body;

      // Validate input
      if (!token || !password) {
        return res.status(400).json({
          success: false,
          message: 'Token and password are required'
        });
      }

      if (password.length < 6) {
        return res.status(400).json({
          success: false,
          message: 'Password must be at least 6 characters long'
        });
      }

      const result = await authService.setPassword(token, password);

      // Set HTTP-only cookies for immediate login
      res.cookie('accessToken', result.accessToken, {
        httpOnly: true,
        secure: process.env.NODE_ENV === 'production',
        sameSite: 'strict',
        maxAge: 15 * 60 * 1000 // 15 minutes
      });

      res.cookie('refreshToken', result.refreshToken, {
        httpOnly: true,
        secure: process.env.NODE_ENV === 'production',
        sameSite: 'strict',
        maxAge: 7 * 24 * 60 * 60 * 1000 // 7 days
      });

      res.status(200).json({
        success: true,
        ...result
      });
    } catch (error) {
      res.status(400).json({
        success: false,
        message: error.message
      });
    }
  }

}

module.exports = new AuthController();
