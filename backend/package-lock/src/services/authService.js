const { Op } = require('sequelize');
const { User, RefreshToken } = require('../models');
const {
  generateAccessToken,
  generateRefreshToken,
  verifyRefreshToken,
  calculateExpiryDate
} = require('../utils/tokenUtils');
const { validatePhoneNumberOrThrow, toE164 } = require('../utils/phoneValidation');

const {
  generateSecureToken, 
  hashToken, 
  verifyHashedToken,
  calculateTokenExpiry,
  isTokenExpired 
} = require('../utils/cryptoUtils');
const emailService = require('./emailService');

class AuthService {
  async register(userData) {
    const { name, phone_number, email, password, role } = userData;

    // Check if user already exists
    const existingUser = await User.findOne({ where: { email } });
    if (existingUser) {
      throw new Error('User with this email already exists');
    }

    // Phone / WhatsApp number is REQUIRED for new signups and must be unique
    // (it doubles as a login identifier). Validated + normalized to 10 digits.
    const cleanedPhone = validatePhoneNumberOrThrow(phone_number, 'WhatsApp number');
    const phoneTaken = await User.findOne({ where: { phone_number: cleanedPhone } });
    if (phoneTaken) {
      throw new Error('This WhatsApp number is already registered. Please log in instead.');
    }

    // Create new user with the specified role (default to USER if not provided)
    const user = await User.create({
      name,
      phone_number: cleanedPhone,
      email,
      password,
      role: role || 'USER' // Use provided role or default to USER
    });

    // Generate tokens
    const accessToken = generateAccessToken(user);
    const refreshToken = generateRefreshToken(user);

    // Store refresh token in database
    const expiryDate = calculateExpiryDate(process.env.REFRESH_TOKEN_EXPIRY || '7d');
    await RefreshToken.create({
      token: refreshToken,
      userId: user.id,
      expiryDate
    });

    // Send welcome email (non-blocking)
    emailService.sendWelcomeEmail({ to: user.email, name: user.name })
      .catch((err) => console.error('❌ Welcome email error:', err.message));

    return {
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        role: user.role,
        phone_number: user.phone_number
      },
      accessToken,
      refreshToken
    };
  }

  /**
   * Log in with EITHER an email OR a WhatsApp number, plus password.
   * @param {string} identifier email address or Indian mobile number
   * @param {string} password
   */
  async login(identifier, password) {
    const id = String(identifier || '').trim();
    let user = null;

    if (id.includes('@')) {
      // Email login
      user = await User.findOne({ where: { email: id } });
    } else {
      // WhatsApp-number login. Normalize to the stored 10-digit local number.
      const e164 = toE164(id);
      if (e164) {
        const local = e164.slice(3); // strip "+91"
        user = await User.findOne({ where: { phone_number: local } });
      }
    }

    if (!user) {
      throw new Error('Invalid email/number or password');
    }

    // Check password
    const isPasswordValid = await user.comparePassword(password);
    if (!isPasswordValid) {
      throw new Error('Invalid email/number or password');
    }

    // Reject disabled accounts (e.g. a deleted security guard, or any user the
    // admin has blocked). Without this, a blocked/orphaned login still works.
    if (user.status === 'Blocked') {
      throw new Error('Your account has been disabled. Please contact the administrator.');
    }

    // Generate tokens
    const accessToken = generateAccessToken(user);
    const refreshToken = generateRefreshToken(user);

    // Store refresh token in database
    const expiryDate = calculateExpiryDate(process.env.REFRESH_TOKEN_EXPIRY || '7d');
    await RefreshToken.create({
      token: refreshToken,
      userId: user.id,
      expiryDate
    });

    // ✅ Fetch permissions from Roles table based on user's role
    const { Role } = require('../models');
    let userPermissions = null;
    
    try {
      const role = await Role.findOne({ 
        where: { name: user.role.toUpperCase() } 
      });
      
      if (role && role.permissions) {
        // Permissions from Roles table
        userPermissions = typeof role.permissions === 'string' 
          ? JSON.parse(role.permissions) 
          : role.permissions;
        console.log(`✅ Loaded permissions from Roles table for ${user.role}:`, userPermissions);
      } else {
        console.warn(`⚠️  No role found in Roles table for ${user.role}, checking user.permissions`);
        
        // Fallback to user.permissions if role not found
        if (user.permissions) {
          userPermissions = typeof user.permissions === 'string' 
            ? JSON.parse(user.permissions) 
            : user.permissions;
          console.log(`✅ Using permissions from User record:`, userPermissions);
        }
      }
    } catch (e) {
      console.error('Error fetching role permissions:', e);
      
      // Fallback to user.permissions
      if (user.permissions) {
        try {
          userPermissions = typeof user.permissions === 'string' 
            ? JSON.parse(user.permissions) 
            : user.permissions;
        } catch (parseError) {
          console.error('Error parsing user permissions:', parseError);
          userPermissions = null;
        }
      }
    }

    // For a complex admin, attach their complex's name/city for UI branding.
    let sportComplex = null;
    if (user.sportComplexId) {
      const { SportComplex } = require('../models');
      const sc = await SportComplex.findByPk(user.sportComplexId, { attributes: ['id', 'name', 'city'] });
      if (sc) sportComplex = { id: sc.id, name: sc.name, city: sc.city };
    }

    return {
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        role: user.role,
        phone_number: user.phone_number,
        sportComplexId: user.sportComplexId, // home complex for a COMPLEX_ADMIN
        sportComplex,                         // { id, name, city } for UI branding
        permissions: userPermissions
      },
      accessToken,
      refreshToken
    };
  }

  async googleLogin(googleData) {
    const { email, name, googleId, avatar } = googleData;

    // 1. Find or create user
    let user = await User.findOne({ where: { email } });

    if (user) {
      // Update existing user with googleId if not already set
      if (!user.googleId) {
        await user.update({ googleId, isGoogleUser: true, avatar: user.avatar || avatar });
      }
    } else {
      // Create new user
      user = await User.create({
        name,
        email,
        googleId,
        isGoogleUser: true,
        avatar,
        role: 'USER', // Default role for Google signups
        isEmailVerified: true // Google emails are already verified
      });
    }

    // 2. Generate tokens
    const accessToken = generateAccessToken(user);
    const refreshToken = generateRefreshToken(user);

    // 3. Store refresh token
    const expiryDate = calculateExpiryDate(process.env.REFRESH_TOKEN_EXPIRY || '7d');
    await RefreshToken.create({
      token: refreshToken,
      userId: user.id,
      expiryDate
    });

    // 4. Get permissions
    const { Role } = require('../models');
    let userPermissions = null;
    try {
      const role = await Role.findOne({ where: { name: user.role.toUpperCase() } });
      if (role && role.permissions) {
        userPermissions = typeof role.permissions === 'string' ? JSON.parse(role.permissions) : role.permissions;
      }
    } catch (e) {
      console.error('Error fetching role permissions:', e);
    }

    return {
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        role: user.role,
        avatar: user.avatar,
        phone_number: user.phone_number || null,
        // Google sign-ups have no phone yet → the UI prompts them to add one.
        needsPhone: !user.phone_number,
        sportComplexId: user.sportComplexId,
        permissions: userPermissions
      },
      accessToken,
      refreshToken
    };
  }

  async refreshToken(refreshTokenString) {
    try {
      // Verify refresh token
      const decoded = verifyRefreshToken(refreshTokenString);
      
      // Find user
      const user = await User.findByPk(decoded.id);
      if (!user) {
        throw new Error('User not found');
      }

      // Find refresh token in database
      const storedRefreshToken = await RefreshToken.findOne({
        where: { userId: user.id, isRevoked: false }
      });

      if (!storedRefreshToken) {
        throw new Error('Refresh token not found');
      }

      // Check if token matches
      const isTokenValid = await storedRefreshToken.compareToken(refreshTokenString);
      if (!isTokenValid) {
        throw new Error('Invalid refresh token');
      }

      // Check if token is expired
      if (RefreshToken.isExpired(storedRefreshToken)) {
        throw new Error('Refresh token expired');
      }

      // Revoke old refresh token
      await storedRefreshToken.update({ isRevoked: true });

      // Generate new tokens
      const newAccessToken = generateAccessToken(user);
      const newRefreshToken = generateRefreshToken(user);

      // Store new refresh token
      const expiryDate = calculateExpiryDate(process.env.REFRESH_TOKEN_EXPIRY || '7d');
      await RefreshToken.create({
        token: newRefreshToken,
        userId: user.id,
        expiryDate
      });

      return {
        accessToken: newAccessToken,
        refreshToken: newRefreshToken
      };
    } catch (error) {
      throw new Error('Invalid refresh token');
    }
  }

  async logout(userId) {
    // Revoke all refresh tokens for the user
    await RefreshToken.update(
      { isRevoked: true },
      { where: { userId } }
    );
  }

  async getUserById(userId) {
    const user = await User.findByPk(userId, {
      attributes: { exclude: ['password', 'staff_password_enc', 'phone_verify_otp'] }
    });
    
    if (!user) {
      return null;
    }

    // Fetch permissions from Roles table based on user's role
    const { Role } = require('../models');
    let userPermissions = null;
    
    try {
      const role = await Role.findOne({ 
        where: { name: user.role.toUpperCase() } 
      });
      
      if (role && role.permissions) {
        // Permissions from Roles table
        userPermissions = typeof role.permissions === 'string' 
          ? JSON.parse(role.permissions) 
          : role.permissions;
        console.log(`✅ Loaded permissions for ${user.role}:`, userPermissions);
      } else if (user.permissions) {
        // Fallback to user.permissions
        userPermissions = typeof user.permissions === 'string' 
          ? JSON.parse(user.permissions) 
          : user.permissions;
      }
    } catch (e) {
      console.error('Error fetching role permissions:', e);
      
      // Fallback to user.permissions
      if (user.permissions) {
        try {
          userPermissions = typeof user.permissions === 'string' 
            ? JSON.parse(user.permissions) 
            : user.permissions;
        } catch (parseError) {
          console.error('Error parsing user permissions:', parseError);
        }
      }
    }

    // Return user with permissions
    const userData = user.toJSON();
    userData.permissions = userPermissions;

    // Provide aliases so both naming conventions work across the two frontends:
    // backend model uses `avatar`/`dob`; admin panel expects `profile_picture`/`date_of_birth`.
    userData.profile_picture = userData.avatar || null;
    userData.date_of_birth = userData.dob || null;

    // For a complex admin, attach their complex's name/city for UI branding.
    userData.sportComplex = null;
    if (userData.sportComplexId) {
      const { SportComplex } = require('../models');
      const sc = await SportComplex.findByPk(userData.sportComplexId, { attributes: ['id', 'name', 'city'] });
      if (sc) userData.sportComplex = { id: sc.id, name: sc.name, city: sc.city };
    }

    return userData;
  }

  async forgotPassword(email) {
    // Always return success message to prevent user enumeration
    const user = await User.findOne({ where: { email } });
    
    if (user) {
      // Generate reset token
      const resetToken = generateSecureToken();
      const hashedToken = hashToken(resetToken);
      const expiryDate = calculateTokenExpiry(15); // 15 minutes

      // Save hashed token and expiry to user
      await user.update({
        resetPasswordToken: hashedToken,
        resetPasswordExpires: expiryDate
      });

      // Send reset email
      try {
        await emailService.sendPasswordResetEmail(email, resetToken);
      } catch (error) {
        console.error('Failed to send password reset email:', error);
        // Don't throw error to prevent user enumeration
      }
    }

    return { message: 'If an account with that email exists, a password reset link has been sent.' };
  }

  async resetPassword(token, newPassword) {
    // Hash the incoming token to compare with stored hash
    const hashedToken = hashToken(token);

    // Find user by hashed token and expiry
    const user = await User.findOne({
      where: {
        resetPasswordToken: hashedToken,
        resetPasswordExpires: {
          [User.sequelize.Sequelize.Op.gt]: new Date()
        }
      }
    });

    if (!user) {
      throw new Error('Invalid or expired reset token');
    }

    // Update password and clear reset fields
    await user.update({
      password: newPassword, // Will be hashed by the model hook
      resetPasswordToken: null,
      resetPasswordExpires: null
    });

    return { message: 'Password reset successfully' };
  }

  async setPassword(token, password) {
    // Hash the incoming token to compare with stored hash
    const hashedToken = hashToken(token);

    // Find user by hashed token and expiry (using reset fields for setup tokens)
    const user = await User.findOne({
      where: {
        resetPasswordToken: hashedToken,
        resetPasswordExpires: {
          [User.sequelize.Sequelize.Op.gt]: new Date()
        }
      }
    });

    if (!user) {
      throw new Error('Invalid or expired setup token');
    }

    // Update password, clear reset fields, and mark email as verified
    await user.update({
      password: password, // Will be hashed by the model hook
      resetPasswordToken: null,
      resetPasswordExpires: null,
      isEmailVerified: true
    });

    // Generate tokens for immediate login
    const accessToken = generateAccessToken(user);
    const refreshToken = generateRefreshToken(user);

    // Store refresh token in database
    const expiryDate = calculateExpiryDate(process.env.REFRESH_TOKEN_EXPIRY || '7d');
    await RefreshToken.create({
      token: refreshToken,
      userId: user.id,
      expiryDate
    });

    return {
      message: 'Password set successfully',
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        role: user.role,
        phone_number: user.phone_number,
        isEmailVerified: user.isEmailVerified
      },
      accessToken,
      refreshToken
    };
  }

  // Fields a user is allowed to change on their own profile.
  // Role, email, permissions, status etc. are intentionally excluded (admin-only).
  async updateProfile(userId, data) {
    const user = await User.findByPk(userId);
    if (!user) {
      throw new Error('User not found');
    }

    // Accept both naming conventions: backend uses `dob`/`avatar`,
    // admin panel sends `date_of_birth`/`profile_picture`.
    const normalized = {
      ...data,
      dob: data.dob !== undefined ? data.dob : data.date_of_birth,
      avatar: data.avatar !== undefined ? data.avatar : data.profile_picture,
    };

    const allowedFields = ['name', 'phone_number', 'dob', 'gender', 'blood_group', 'avatar'];
    const updates = {};
    for (const field of allowedFields) {
      if (normalized[field] !== undefined) {
        updates[field] = normalized[field] === '' ? null : normalized[field];
      }
    }

    // Phone / WhatsApp number: validate and enforce uniqueness across accounts.
    // Legacy accounts predate the uniqueness rule and can share a number, so the
    // duplicate check only runs when the user is actually CHANGING their number.
    // Re-saving the number they already have must never block the profile save.
    if ('phone_number' in updates && updates.phone_number != null) {
      const cleaned = validatePhoneNumberOrThrow(updates.phone_number, 'WhatsApp number');
      if (cleaned !== user.phone_number) {
        const taken = await User.findOne({ where: { phone_number: cleaned, id: { [Op.ne]: userId } } });
        if (taken) {
          throw new Error('This WhatsApp number is already registered to another account.');
        }
      }
      updates.phone_number = cleaned;
    }

    // Validate gender against the model ENUM
    if (updates.gender != null && !['Male', 'Female', 'Other'].includes(updates.gender)) {
      throw new Error('Invalid gender value');
    }

    await user.update(updates);

    // Return the fresh profile (with permissions, no password)
    return this.getUserById(userId);
  }

  async changePassword(userId, currentPassword, newPassword) {
    const user = await User.findByPk(userId);
    if (!user) {
      throw new Error('User not found');
    }

    if (user.isGoogleUser && !user.password) {
      throw new Error('Password change is not available for Google accounts');
    }

    const isPasswordValid = await user.comparePassword(currentPassword);
    if (!isPasswordValid) {
      throw new Error('Current password is incorrect');
    }

    // Model beforeUpdate hook hashes the password
    await user.update({ password: newPassword });

    return { message: 'Password changed successfully' };
  }

  async createUserByAdmin(userData) {
    const { 
      name, 
      email, 
      role, 
      phone_number, 
      membership_type, 
      status, 
      employee_id, 
      department, 
      assigned_sports, 
      assigned_location,
      permissions
    } = userData;

    // Check if user already exists
    const existingUser = await User.findOne({ where: { email } });
    if (existingUser) {
      throw new Error('User with this email already exists');
    }

    // Generate a default password (will be hashed by model hook)
    const defaultPassword = `Welcome@${Math.random().toString(36).slice(-8)}`;

    // Get default permissions for the role
    const { getDefaultPermissions, mergePermissions } = require('../config/rolePermissions');
    const userRole = role || 'USER';
    const userPermissions = permissions 
      ? mergePermissions(userRole, permissions)
      : getDefaultPermissions(userRole);

    // Create user with all fields
    const user = await User.create({
      name,
      email,
      password: defaultPassword,
      role: userRole,
      phone_number,
      membership_type: membership_type || null,
      status: status || 'Active',
      employee_id: employee_id || null,
      department: department || null,
      assigned_sports: assigned_sports || null,
      assigned_location: assigned_location || null,
      permissions: userPermissions,
      join_date: new Date(),
      isEmailVerified: false // Will be set to true when password is set
    });

    // ✅ AUTO-SYNC: Create corresponding record in Employee/Coach/SecurityGuard table
    const { Employee, Coach, SecurityGuard } = require('../models');
    
    if (userRole === 'EMPLOYEE') {
      // Map department to valid ENUM value
      const validDepartments = ['Operations', 'Front Desk', 'Maintenance', 'Housekeeping', 'Accounts', 'Customer Service'];
      const mappedDepartment = validDepartments.includes(department) ? department : 'Operations';
      
      // Map designation to valid ENUM value (default to Staff)
      const validDesignations = ['Manager', 'Supervisor', 'Staff', 'Technician', 'Accountant', 'Receptionist'];
      const mappedDesignation = 'Staff';
      
      await Employee.create({
        userId: user.id,
        employeeId: employee_id || `EMP${user.id}`,
        department: mappedDepartment,
        designation: mappedDesignation,
        joiningDate: new Date().toISOString().split('T')[0],
        shift: 'Morning',
        status: 'Active',
        phone: user.phone_number
      });
      console.log(`✅ Created Employee record for user ${user.id}`);
    } else if (userRole === 'COACH') {
      // Link by email: reuse an existing Coach with this email instead of failing
      // on the unique-email constraint (a coach may already exist from the Coaches module).
      const coachPhone = /^[0-9]{10}$/.test(String(user.phone_number || '')) ? user.phone_number : null;
      const [coach, created] = await Coach.findOrCreate({
        where: { email: user.email },
        defaults: {
          name: user.name,
          phone: coachPhone,
          email: user.email,
          specialization: 'General',
          experience: '0 years',
          status: 'Active'
        }
      });
      console.log(`✅ ${created ? 'Created' : 'Linked existing'} Coach record (ID: ${coach.id}) for user ${user.id}`);
    } else if (userRole === 'SECURITY') {
      // Map shift to valid ENUM value
      const validShifts = ['Morning', 'Evening', 'Night'];
      const mappedShift = 'Morning';
      
      // Map assigned area to valid ENUM value
      const validAreas = ['Main Gate', 'Parking', 'Courts', 'Building', 'Perimeter'];
      const mappedArea = validAreas.includes(assigned_location) ? assigned_location : 'Main Gate';
      
      await SecurityGuard.create({
        userId: user.id,
        guardId: `GUARD${user.id}`,
        shift: mappedShift,
        assignedArea: mappedArea,
        joiningDate: new Date().toISOString().split('T')[0],
        status: 'Active'
      });
      console.log(`✅ Created SecurityGuard record for user ${user.id}`);
    }

    // Generate setup token
    const setupToken = generateSecureToken();
    const hashedToken = hashToken(setupToken);
    const expiryDate = calculateTokenExpiry(24 * 60); // 24 hours for setup

    // Save setup token
    await user.update({
      resetPasswordToken: hashedToken,
      resetPasswordExpires: expiryDate
    });

    // Send invitation email
    try {
      await emailService.sendUserInvitationEmail(email, setupToken, name);
    } catch (error) {
      console.error('Failed to send invitation email:', error);
      // Don't rollback - user is created, just log the error
    }

    return {
      message: 'User created successfully. Invitation email sent.',
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        role: user.role,
        phone_number: user.phone_number,
        membership_type: user.membership_type,
        status: user.status,
        employee_id: user.employee_id,
        department: user.department,
        assigned_sports: user.assigned_sports,
        assigned_location: user.assigned_location,
        permissions: user.permissions
      }
    };
  }
}

module.exports = new AuthService();
