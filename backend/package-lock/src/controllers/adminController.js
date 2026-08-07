const authService = require('../services/authService');
const { User, Booking } = require('../models');
const { Sequelize, Op } = require('sequelize');
const { resolveComplexId, isComplexAdmin, stampComplexId, assertComplexAccess } = require('../middleware/complexScope');

/**
 * Build the WHERE fragment for the user-list free-text search.
 *
 * Matches name, email OR phone number, case-insensitively, anywhere in the
 * value — and runs in SQL so it covers EVERY user, not just the page currently
 * on screen. Returns null when there is nothing to search for.
 */
function buildUserSearchWhere(rawSearch) {
  const term = String(rawSearch || '').trim();
  if (!term) return null;

  // `%` and `_` are LIKE wildcards; escape them so a literal one typed by the
  // admin doesn't silently match everything.
  const escaped = term.replace(/[\\%_]/g, (ch) => `\\${ch}`);
  const like = `%${escaped}%`;

  const or = [
    { name: { [Op.iLike]: like } },
    { email: { [Op.iLike]: like } },
    { phone_number: { [Op.iLike]: like } },
  ];

  // Numbers are stored as bare 10 digits, so a search typed with spaces, dashes
  // or a country code ("+91 98765 43210") also matches on the digits alone.
  // Anything longer than 10 digits is trimmed to the last 10, otherwise the
  // "91" prefix would be searched for literally and never match.
  let digits = term.replace(/\D/g, '');
  if (digits.length > 10) digits = digits.slice(-10);
  if (digits.length >= 3 && digits !== term) {
    or.push({ phone_number: { [Op.iLike]: `%${digits}%` } });
  }

  return { [Op.or]: or };
}

class AdminController {
  async createUser(req, res) {
    try {
      const { name, email, role, phone_number, membership_type, status, employee_id, department, assigned_sports, assigned_location } = req.body;

      // Validate input
      if (!name || !email) {
        return res.status(400).json({
          success: false,
          message: 'Name and email are required'
        });
      }

      // Validate role if provided
      const validRoles = ['ADMIN', 'USER', 'EMPLOYEE', 'COACH', 'SECURITY'];
      if (role && !validRoles.includes(role)) {
        return res.status(400).json({
          success: false,
          message: 'Invalid role. Must be one of: ADMIN, USER, EMPLOYEE, COACH, SECURITY'
        });
      }

      const result = await authService.createUserByAdmin({
        name,
        email,
        role: role || 'USER',
        phone_number,
        membership_type,
        status: status || 'Active',
        employee_id,
        department,
        assigned_sports,
        assigned_location
      });

      res.status(201).json({
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

  async getAllUsers(req, res) {
    try {
      const { role, status, membership_type, search, limit = 100, page = 1 } = req.query;

      const where = {};
      if (role) {
        where.role = role;
      }
      if (status) {
        where.status = status;
      }
      if (membership_type) {
        where.membership_type = membership_type;
      }

      // Free-text search across name / email / phone. Applied in SQL alongside
      // the filters above, so it spans all users and the pagination totals below
      // reflect the matches rather than the whole table.
      const searchWhere = buildUserSearchWhere(search);
      if (searchWhere) {
        Object.assign(where, searchWhere);
      }

      const offset = (parseInt(page) - 1) * parseInt(limit);

      // Subquery to count active (non-deleted) bookings per user
      const bookingCountLiteral = [
        Sequelize.literal(`(
          SELECT COUNT(*)
          FROM "Bookings" AS b
          WHERE b."userId" = "User"."id"
            AND b."isDeleted" = false
        )`),
        'bookingCount'
      ];
      
      const { count, rows } = await User.findAndCountAll({
        where,
        attributes: {
          exclude: ['password', 'resetPasswordToken'],
          include: [bookingCountLiteral]
        },
        order: [['createdAt', 'DESC']],
        limit: parseInt(limit),
        offset
      });
      
      // Format users for frontend
      const formattedUsers = rows.map(user => {
        const userData = user.toJSON();
        // Prefer live count from subquery; fall back to stored total_bookings
        const liveCount = parseInt(userData.bookingCount) || 0;
        return {
          id: userData.id.toString(),
          name: userData.name,
          phoneNumber: userData.phone_number || '',
          email: userData.email,
          role: userData.role === 'SECURITY' ? 'Security Guard' : userData.role.charAt(0) + userData.role.slice(1).toLowerCase(),
          totalBookings: liveCount,
          membershipType: userData.membership_type,
          status: userData.status,
          joinDate: userData.join_date || userData.createdAt.toISOString().split('T')[0],
          lastActive: userData.last_active || userData.updatedAt.toISOString().split('T')[0],
          avatar: userData.avatar,
          employeeId: userData.employee_id,
          department: userData.department,
          assignedSports: userData.assigned_sports,
          assignedLocation: userData.assigned_location
        };
      });

      res.status(200).json({
        success: true,
        data: formattedUsers,
        pagination: {
          currentPage: parseInt(page),
          totalPages: Math.ceil(count / parseInt(limit)),
          totalItems: count,
          itemsPerPage: parseInt(limit)
        }
      });
    } catch (error) {
      console.error('Error in getAllUsers:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to retrieve users',
        error: error.message
      });
    }
  }

  async getUserById(req, res) {
    try {
      const { id } = req.params;

      const user = await User.findByPk(id, {
        attributes: { exclude: ['password', 'resetPasswordToken'] }
      });

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
        message: 'Failed to retrieve user'
      });
    }
  }

  async updateUser(req, res) {
    try {
      const { id } = req.params;
      const { name, role, phone_number, isEmailVerified, membership_type, status, employee_id, department, assigned_sports, assigned_location } = req.body;

      const user = await User.findByPk(id);
      if (!user) {
        return res.status(404).json({
          success: false,
          message: 'User not found'
        });
      }

      // Store old role for comparison
      const oldRole = user.role;

      // Validate role if provided
      if (role) {
        const validRoles = ['ADMIN', 'USER', 'EMPLOYEE', 'COACH', 'SECURITY'];
        if (!validRoles.includes(role)) {
          return res.status(400).json({
            success: false,
            message: 'Invalid role. Must be one of: ADMIN, USER, EMPLOYEE, COACH, SECURITY'
          });
        }
      }

      // Update user
      const updateData = {};
      if (name !== undefined) updateData.name = name;
      if (role !== undefined) updateData.role = role;
      if (phone_number !== undefined) updateData.phone_number = phone_number;
      if (isEmailVerified !== undefined) updateData.isEmailVerified = isEmailVerified;
      if (membership_type !== undefined) updateData.membership_type = membership_type;
      if (status !== undefined) updateData.status = status;
      if (employee_id !== undefined) updateData.employee_id = employee_id;
      if (department !== undefined) updateData.department = department;
      if (assigned_sports !== undefined) updateData.assigned_sports = assigned_sports;
      if (assigned_location !== undefined) updateData.assigned_location = assigned_location;
      
      // Update last_active timestamp
      updateData.last_active = new Date().toISOString().split('T')[0];

      await user.update(updateData);

      // ✅ AUTO-SYNC: If role changed, sync with Employee/Coach/SecurityGuard tables
      if (role && role !== oldRole) {
        console.log(`🔄 Role changed from ${oldRole} to ${role} for user ${user.id}`);
        
        const { Employee, Coach, SecurityGuard } = require('../models');
        
        // Remove from old role table
        if (oldRole === 'EMPLOYEE') {
          await Employee.destroy({ where: { userId: user.id } });
          console.log(`🗑️  Removed from Employee table`);
        } else if (oldRole === 'COACH') {
          // Coaches has no userId column — match by email
          await Coach.destroy({ where: { email: user.email } });
          console.log(`🗑️  Removed from Coach table`);
        } else if (oldRole === 'SECURITY') {
          await SecurityGuard.destroy({ where: { userId: user.id } });
          console.log(`🗑️  Removed from SecurityGuard table`);
        }
        
        // Add to new role table
        if (role === 'EMPLOYEE') {
          // Map department to valid ENUM value
          const validDepartments = ['Operations', 'Front Desk', 'Maintenance', 'Housekeeping', 'Accounts', 'Customer Service'];
          const mappedDepartment = validDepartments.includes(department) ? department : 'Operations';
          
          // Map designation to valid ENUM value
          const validDesignations = ['Manager', 'Supervisor', 'Staff', 'Technician', 'Accountant', 'Receptionist'];
          const mappedDesignation = validDesignations.includes(updateData.designation) ? updateData.designation : 'Staff';
          
          const [employee, created] = await Employee.findOrCreate({
            where: { userId: user.id },
            defaults: {
              userId: user.id,
              employeeId: employee_id || `EMP${user.id}`,
              department: mappedDepartment,
              designation: mappedDesignation,
              joiningDate: new Date().toISOString().split('T')[0],
              shift: 'Morning',
              status: 'Active',
              phone: user.phone_number
            }
          });
          console.log(`✅ ${created ? 'Created' : 'Updated'} Employee record`);
        } else if (role === 'COACH') {
          // Match by email so an existing Coach (created via the Coaches module) is reused
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
          console.log(`✅ ${created ? 'Created' : 'Linked existing'} Coach record (ID: ${coach.id})`);
        } else if (role === 'SECURITY') {
          // Map shift to valid ENUM value
          const validShifts = ['Morning', 'Evening', 'Night'];
          const mappedShift = validShifts.includes(updateData.shift) ? updateData.shift : 'Morning';
          
          // Map assigned area to valid ENUM value
          const validAreas = ['Main Gate', 'Parking', 'Courts', 'Building', 'Perimeter'];
          const mappedArea = validAreas.includes(assigned_location) ? assigned_location : 'Main Gate';
          
          const [guard, created] = await SecurityGuard.findOrCreate({
            where: { userId: user.id },
            defaults: {
              userId: user.id,
              guardId: `GUARD${user.id}`,
              shift: mappedShift,
              assignedArea: mappedArea,
              joiningDate: new Date().toISOString().split('T')[0],
              status: 'Active'
            }
          });
          console.log(`✅ ${created ? 'Created' : 'Updated'} SecurityGuard record`);
        }
      }

      res.status(200).json({
        success: true,
        message: 'User updated successfully',
        user: {
          id: user.id,
          name: user.name,
          email: user.email,
          role: user.role,
          phone_number: user.phone_number,
          isEmailVerified: user.isEmailVerified,
          membership_type: user.membership_type,
          status: user.status,
          employee_id: user.employee_id,
          department: user.department,
          assigned_sports: user.assigned_sports,
          assigned_location: user.assigned_location
        }
      });
    } catch (error) {
      console.error('❌ Error updating user:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to update user',
        error: error.message
      });
    }
  }

  async deleteUser(req, res) {
    try {
      const { id } = req.params;

      // Prevent admin from deleting themselves
      if (id == req.user.id) {
        return res.status(400).json({
          success: false,
          message: 'Cannot delete your own account'
        });
      }

      const user = await User.findByPk(id);
      if (!user) {
        return res.status(404).json({
          success: false,
          message: 'User not found'
        });
      }

      const db = require('../models');
      const { sequelize, EntryLog, VisitorPass, RefreshToken } = db;

      const transaction = await sequelize.transaction();
      try {
        // A user is referenced by audit/history rows whose foreign keys would
        // otherwise block the delete (e.g. a former security guard's scan logs).
        // Detach the nullable references (preserve the logs) and reassign the
        // not-null ones to the acting admin, then remove the account.
        await EntryLog.update({ securityGuardId: null }, { where: { securityGuardId: id }, transaction });
        await EntryLog.update({ userId: null }, { where: { userId: id }, transaction });
        // VisitorPass.issuedBy is NOT NULL → reassign issued passes to this admin.
        await VisitorPass.update({ issuedBy: req.user.id }, { where: { issuedBy: id }, transaction });
        // Clear sessions.
        await RefreshToken.destroy({ where: { userId: id }, transaction });

        await user.destroy({ transaction });
        await transaction.commit();

        return res.status(200).json({
          success: true,
          message: 'User deleted successfully'
        });
      } catch (innerErr) {
        await transaction.rollback();
        // Still blocked by some other related data → tell the admin which one,
        // instead of a generic 500.
        if (innerErr.name === 'SequelizeForeignKeyConstraintError') {
          const tbl = innerErr.table || (innerErr.original && innerErr.original.table) || 'related records';
          return res.status(409).json({
            success: false,
            message: `Cannot delete this user — they still have associated records in "${tbl}". Remove or reassign those first.`
          });
        }
        throw innerErr;
      }
    } catch (error) {
      console.error('Error in deleteUser:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to delete user'
      });
    }
  }

  async getStats(req, res) {
    try {
      const totalUsers = await User.count();
      const verifiedUsers = await User.count({ where: { isEmailVerified: true } });
      
      const roleStats = await User.findAll({
        attributes: [
          'role',
          [User.sequelize.Sequelize.fn('COUNT', User.sequelize.Sequelize.col('id')), 'count']
        ],
        group: ['role']
      });

      const stats = {
        totalUsers,
        verifiedUsers,
        unverifiedUsers: totalUsers - verifiedUsers,
        roleBreakdown: roleStats.map(stat => ({
          role: stat.role,
          count: parseInt(stat.dataValues.count)
        }))
      };

      res.status(200).json({
        success: true,
        stats
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        message: 'Failed to retrieve statistics'
      });
    }
  }

  // Save role permissions
  async saveRolePermissions(req, res) {
    try {
      const { role } = req.params;
      const { permissions } = req.body;

      console.log('📝 Saving permissions for role:', role);
      console.log('📝 Permissions to save:', permissions);

      // Validate role
      const validRoles = ['EMPLOYEE', 'COACH', 'SECURITY', 'USER'];
      if (!validRoles.includes(role.toUpperCase())) {
        return res.status(400).json({
          success: false,
          message: 'Invalid role. Must be one of: EMPLOYEE, COACH, SECURITY, USER'
        });
      }

      // Validate permissions array
      if (!Array.isArray(permissions)) {
        return res.status(400).json({
          success: false,
          message: 'Permissions must be an array'
        });
      }

      // ✅ Save to Roles table (primary storage)
      const { Role, RolePermission } = require('../models');
      const permissionsJson = JSON.stringify(permissions);
      
      const [roleRecord, created] = await Role.findOrCreate({
        where: { name: role.toUpperCase() },
        defaults: {
          name: role.toUpperCase(),
          display_name: role.charAt(0) + role.slice(1).toLowerCase(),
          description: `${role.charAt(0) + role.slice(1).toLowerCase()} role`,
          permissions: permissionsJson,
          is_active: true,
          is_system: false
        }
      });

      if (!created) {
        // Update existing role
        await roleRecord.update({ permissions: permissionsJson });
        console.log(`✅ Updated permissions in Roles table for ${role.toUpperCase()}`);
      } else {
        console.log(`✅ Created new role in Roles table: ${role.toUpperCase()}`);
      }

      // ✅ Sync to RolePermissions table so GET /api/permissions/:role returns the updated set
      // Map admin-panel role names (SECURITY) to the format used by permissionsController (security_guard)
      const roleToPermKey = {
        SECURITY: 'security_guard',
        EMPLOYEE: 'employee',
        COACH: 'coach',
        USER: 'user',
      };
      const permRole = roleToPermKey[role.toUpperCase()];
      if (permRole) {
        await RolePermission.destroy({ where: { role: permRole } });
        if (permissions.length > 0) {
          await RolePermission.bulkCreate(
            permissions.map((permission) => ({ role: permRole, permission, isActive: true })),
            { ignoreDuplicates: true }
          );
        }
        console.log(`✅ Synced ${permissions.length} permissions to RolePermissions table for "${permRole}"`);
      }

      // ✅ Also update Users table for backward compatibility (optional)
      const [updatedCount] = await User.update(
        { permissions: permissionsJson },
        { where: { role: role.toUpperCase() } }
      );

      console.log(`✅ Updated ${updatedCount} user(s) with role ${role.toUpperCase()}`);

      // Verify the update
      const updatedRole = await Role.findOne({
        where: { name: role.toUpperCase() }
      });

      console.log('✅ Verified role permissions:', {
        role: updatedRole.name,
        permissions: updatedRole.permissions
      });

      res.status(200).json({
        success: true,
        message: `Permissions saved successfully for ${role.toUpperCase()} role`,
        data: {
          role: role.toUpperCase(),
          permissions,
          updatedUserCount: updatedCount
        }
      });
    } catch (error) {
      console.error('❌ Error saving role permissions:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to save role permissions',
        error: error.message
      });
    }
  }

  // Get role permissions
  async getRolePermissions(req, res) {
    try {
      const { role } = req.params;

      // Validate role
      const validRoles = ['EMPLOYEE', 'COACH', 'SECURITY', 'USER'];
      if (!validRoles.includes(role.toUpperCase())) {
        return res.status(400).json({
          success: false,
          message: 'Invalid role. Must be one of: EMPLOYEE, COACH, SECURITY, USER'
        });
      }

      // ✅ Fetch from Roles table (primary source)
      const { Role } = require('../models');
      const roleRecord = await Role.findOne({
        where: { name: role.toUpperCase() }
      });

      let permissions = [];
      
      if (roleRecord && roleRecord.permissions) {
        permissions = typeof roleRecord.permissions === 'string' 
          ? JSON.parse(roleRecord.permissions) 
          : roleRecord.permissions;
        console.log(`✅ Loaded permissions from Roles table for ${role.toUpperCase()}:`, permissions);
      } else {
        console.warn(`⚠️  No role found in Roles table for ${role.toUpperCase()}, checking Users table`);
        
        // Fallback to Users table
        const user = await User.findOne({
          where: { role: role.toUpperCase() },
          attributes: ['permissions']
        });

        if (user && user.permissions) {
          permissions = typeof user.permissions === 'string'
            ? JSON.parse(user.permissions)
            : user.permissions;
          console.log(`✅ Loaded permissions from Users table for ${role.toUpperCase()}:`, permissions);
        }
      }

      res.status(200).json({
        success: true,
        data: {
          role: role.toUpperCase(),
          permissions
        }
      });
    } catch (error) {
      console.error('Error getting role permissions:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to get role permissions',
        error: error.message
      });
    }
  }

  // Security Guard CRUD operations
  async getAllSecurityGuards(req, res) {
    try {
      const securityGuardService = require('../services/securityGuardService');
      const { page = 1, limit = 10, search = '' } = req.query;

      // Per-complex admin scoping (null for super admin = all complexes)
      const complexId = resolveComplexId(req);

      const result = await securityGuardService.getAllSecurityGuards(page, limit, search, complexId);
      
      res.status(200).json({
        success: true,
        data: result.guards,
        pagination: result.pagination
      });
    } catch (error) {
      console.error('Error in getAllSecurityGuards:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to retrieve security guards',
        error: error.message
      });
    }
  }

  async getSecurityGuardById(req, res) {
    try {
      const securityGuardService = require('../services/securityGuardService');
      const { id } = req.params;
      
      const guard = await securityGuardService.getSecurityGuardById(id);

      // Complex admins can only view guards in their own complex
      if (!assertComplexAccess(req, res, guard.sportComplexId)) return;

      res.status(200).json({
        success: true,
        data: guard
      });
    } catch (error) {
      console.error('Error in getSecurityGuardById:', error);
      res.status(error.message === 'Security guard not found' ? 404 : 500).json({
        success: false,
        message: error.message
      });
    }
  }

  async createSecurityGuard(req, res) {
    try {
      const securityGuardService = require('../services/securityGuardService');
      const { resolveStaffComplexId, emailStaffCredentials, formatSalary } = require('../utils/staffAccount');
      const { fullName, email, phone, password, guardId } = req.body;

      if (!fullName || !email || !phone || !guardId) {
        return res.status(400).json({ success: false, message: 'Missing required fields: fullName, email, phone, guardId' });
      }
      if (!password || String(password).length < 6) {
        return res.status(400).json({ success: false, message: 'Password is required (min 6 characters)' });
      }

      // Resolve the complex: complex admin → own; super admin → must pick one.
      const complexId = resolveStaffComplexId(req);
      if (!complexId) {
        return res.status(400).json({ success: false, message: 'Please assign the guard to a sports complex' });
      }
      req.body.sportComplexId = complexId;

      const guard = await securityGuardService.createSecurityGuard(req.body);

      await emailStaffCredentials({
        to: email, name: fullName, email, password, roleKey: 'SECURITY', sportComplexId: complexId,
        details: [
          { label: 'Phone', value: req.body.phone },
          { label: 'Guard ID', value: req.body.guardId },
          { label: 'Shift', value: req.body.shift },
          { label: 'Assigned Area', value: req.body.assignedArea },
          { label: 'Salary', value: formatSalary(req.body.salary) },
          { label: 'Joining Date', value: req.body.joiningDate },
          { label: 'Address', value: req.body.address },
        ],
      });

      res.status(201).json({
        success: true,
        message: 'Security guard created successfully',
        data: guard
      });
    } catch (error) {
      console.error('Error in createSecurityGuard:', error);
      res.status(400).json({
        success: false,
        message: error.message
      });
    }
  }

  async updateSecurityGuard(req, res) {
    try {
      const securityGuardService = require('../services/securityGuardService');
      const { id } = req.params;

      // Complex admins may only edit guards in their own complex, and cannot
      // move a guard to a different complex.
      if (isComplexAdmin(req)) {
        const existing = await securityGuardService.getSecurityGuardById(id);
        if (!assertComplexAccess(req, res, existing.sportComplexId)) return;
        stampComplexId(req, req.body);
      }

      const guard = await securityGuardService.updateSecurityGuard(id, req.body);
      
      res.status(200).json({
        success: true,
        message: 'Security guard updated successfully',
        data: guard
      });
    } catch (error) {
      console.error('Error in updateSecurityGuard:', error);
      res.status(error.message === 'Security guard not found' ? 404 : 400).json({
        success: false,
        message: error.message
      });
    }
  }

  async deleteSecurityGuard(req, res) {
    try {
      const securityGuardService = require('../services/securityGuardService');
      const { id } = req.params;

      // Complex admins may only delete guards in their own complex
      if (isComplexAdmin(req)) {
        const existing = await securityGuardService.getSecurityGuardById(id);
        if (!assertComplexAccess(req, res, existing.sportComplexId)) return;
      }

      const result = await securityGuardService.deleteSecurityGuard(id);

      res.status(200).json({
        success: true,
        message: result.message
      });
    } catch (error) {
      console.error('Error in deleteSecurityGuard:', error);
      res.status(error.message === 'Security guard not found' ? 404 : 500).json({
        success: false,
        message: error.message
      });
    }
  }

  // Reveal the stored login password for a security guard (ADMIN / COMPLEX_ADMIN only).
  async revealSecurityGuardPassword(req, res) {
    try {
      const securityGuardService = require('../services/securityGuardService');
      const { revealStaffPassword, findStaffUser } = require('../utils/staffAccount');
      const guard = await securityGuardService.getSecurityGuardById(req.params.id);
      if (!guard) return res.status(404).json({ success: false, message: 'Security guard not found' });
      if (isComplexAdmin(req) && !assertComplexAccess(req, res, guard.sportComplexId)) return;

      const user = await findStaffUser({ userId: guard.userId || guard.user?.id }, { withSecret: true });
      const password = revealStaffPassword(user);
      if (!password) {
        return res.status(404).json({
          success: false,
          message: 'No stored password for this guard. Use "Reset Password" to set a new one.',
        });
      }
      res.status(200).json({ success: true, data: { email: user.email, password } });
    } catch (error) {
      console.error('Error revealing security guard password:', error);
      res.status(500).json({ success: false, message: error.message });
    }
  }

  // Reset a security guard's login password to a new admin-set value (and re-email it).
  async resetSecurityGuardPassword(req, res) {
    try {
      const securityGuardService = require('../services/securityGuardService');
      const { setStaffPassword, findStaffUser, emailStaffCredentials, formatSalary } = require('../utils/staffAccount');
      const { password } = req.body;
      if (!password || String(password).length < 6) {
        return res.status(400).json({ success: false, message: 'Password is required (min 6 characters)' });
      }
      const guard = await securityGuardService.getSecurityGuardById(req.params.id);
      if (!guard) return res.status(404).json({ success: false, message: 'Security guard not found' });
      if (isComplexAdmin(req) && !assertComplexAccess(req, res, guard.sportComplexId)) return;

      const user = await findStaffUser({ userId: guard.userId || guard.user?.id }, { withSecret: true });
      if (!user) return res.status(404).json({ success: false, message: 'Login account not found for this guard' });

      await setStaffPassword(user, password);
      await emailStaffCredentials({
        to: user.email, name: user.name, email: user.email, password,
        roleKey: 'SECURITY', sportComplexId: guard.sportComplexId,
        details: [
          { label: 'Phone', value: user.phone_number },
          { label: 'Guard ID', value: guard.guardId },
          { label: 'Shift', value: guard.shift },
          { label: 'Assigned Area', value: guard.assignedArea },
          { label: 'Salary', value: formatSalary(guard.salary) },
          { label: 'Joining Date', value: guard.joiningDate },
        ],
      });
      res.status(200).json({ success: true, message: 'Password reset and emailed to the guard' });
    } catch (error) {
      console.error('Error resetting security guard password:', error);
      res.status(500).json({ success: false, message: error.message });
    }
  }
}

module.exports = new AdminController();
