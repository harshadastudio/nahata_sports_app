'use strict';

/**
 * Complex Admin management — SUPER ADMIN (role ADMIN) ONLY.
 *
 * A "complex admin" is a User with role = 'COMPLEX_ADMIN' and a non-null
 * sportComplexId. The super admin creates/lists/updates/deactivates them here.
 * Route-level allowRoles('ADMIN') guarantees only a super admin reaches these.
 */

const { User, SportComplex } = require('../models');
const { getDefaultPermissions } = require('../config/rolePermissions');

const PUBLIC_ATTRS = { exclude: ['password', 'staff_password_enc', 'resetPasswordToken', 'resetPasswordExpires'] };

// Shape a user row for the admin panel.
const format = (u) => {
  const d = u.toJSON ? u.toJSON() : u;
  return {
    id: d.id,
    name: d.name,
    email: d.email,
    phoneNumber: d.phone_number || '',
    role: d.role,
    status: d.status,
    sportComplexId: d.sportComplexId,
    sportComplex: d.sportComplex
      ? { id: d.sportComplex.id, name: d.sportComplex.name, city: d.sportComplex.city }
      : null,
    createdAt: d.createdAt,
  };
};

const withComplex = () => ([{ model: SportComplex, as: 'sportComplex', attributes: ['id', 'name', 'city'] }]);

exports.listComplexAdmins = async (req, res) => {
  try {
    const where = { role: 'COMPLEX_ADMIN' };
    if (req.query.sportComplexId) where.sportComplexId = Number(req.query.sportComplexId);

    const admins = await User.findAll({
      where,
      attributes: PUBLIC_ATTRS,
      include: withComplex(),
      order: [['createdAt', 'DESC']],
    });

    res.status(200).json({ success: true, data: admins.map(format) });
  } catch (error) {
    console.error('Error listing complex admins:', error);
    res.status(500).json({ success: false, message: 'Failed to list complex admins', error: error.message });
  }
};

exports.createComplexAdmin = async (req, res) => {
  try {
    const { name, email, password, phone_number, sportComplexId } = req.body;

    if (!name || !email || !password || !sportComplexId) {
      return res.status(400).json({
        success: false,
        message: 'name, email, password and sportComplexId are required',
      });
    }
    if (String(password).length < 6) {
      return res.status(400).json({ success: false, message: 'Password must be at least 6 characters' });
    }

    // The complex must exist.
    const complex = await SportComplex.findByPk(sportComplexId);
    if (!complex) {
      return res.status(404).json({ success: false, message: 'Sports complex not found' });
    }

    // Email must be unique.
    const existing = await User.findOne({ where: { email } });
    if (existing) {
      return res.status(400).json({ success: false, message: 'A user with this email already exists' });
    }

    const user = await User.create({
      name,
      email,
      password, // hashed by the model's beforeCreate hook
      role: 'COMPLEX_ADMIN',
      phone_number: phone_number || null,
      sportComplexId: Number(sportComplexId),
      status: 'Active',
      permissions: getDefaultPermissions('COMPLEX_ADMIN'),
      join_date: new Date(),
      isEmailVerified: true,
    });

    const created = await User.findByPk(user.id, { attributes: PUBLIC_ATTRS, include: withComplex() });
    res.status(201).json({ success: true, message: 'Complex admin created', data: format(created) });
  } catch (error) {
    console.error('Error creating complex admin:', error);
    res.status(400).json({ success: false, message: error.message });
  }
};

exports.updateComplexAdmin = async (req, res) => {
  try {
    const { id } = req.params;
    const { name, phone_number, sportComplexId, status, password } = req.body;

    const user = await User.findOne({ where: { id, role: 'COMPLEX_ADMIN' } });
    if (!user) {
      return res.status(404).json({ success: false, message: 'Complex admin not found' });
    }

    if (sportComplexId !== undefined) {
      const complex = await SportComplex.findByPk(sportComplexId);
      if (!complex) {
        return res.status(404).json({ success: false, message: 'Sports complex not found' });
      }
      user.sportComplexId = Number(sportComplexId);
    }
    if (name !== undefined) user.name = name;
    if (phone_number !== undefined) user.phone_number = phone_number;
    if (status !== undefined) user.status = status; // 'Active' | 'Blocked'
    if (password) {
      if (String(password).length < 6) {
        return res.status(400).json({ success: false, message: 'Password must be at least 6 characters' });
      }
      user.password = password; // re-hashed by beforeUpdate hook
    }

    await user.save();

    const updated = await User.findByPk(user.id, { attributes: PUBLIC_ATTRS, include: withComplex() });
    res.status(200).json({ success: true, message: 'Complex admin updated', data: format(updated) });
  } catch (error) {
    console.error('Error updating complex admin:', error);
    res.status(400).json({ success: false, message: error.message });
  }
};

// Soft "deactivate" by blocking the account (keeps history). Pass ?hard=true to delete.
exports.deactivateComplexAdmin = async (req, res) => {
  try {
    const { id } = req.params;
    const user = await User.findOne({ where: { id, role: 'COMPLEX_ADMIN' } });
    if (!user) {
      return res.status(404).json({ success: false, message: 'Complex admin not found' });
    }

    if (req.query.hard === 'true') {
      await user.destroy();
      return res.status(200).json({ success: true, message: 'Complex admin deleted' });
    }

    user.status = 'Blocked';
    await user.save();
    res.status(200).json({ success: true, message: 'Complex admin deactivated' });
  } catch (error) {
    console.error('Error deactivating complex admin:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};
