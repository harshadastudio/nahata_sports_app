const db = require('../models');
const { Employee, User, SportComplex } = db;
const { Op } = require('sequelize');
const bcrypt = require('bcrypt');
const { getDefaultPermissions } = require('../config/rolePermissions');
const { encryptSecret } = require('../utils/secretCrypto');
const { demoteStaffUserToUser } = require('../utils/staffAccount');

class EmployeeService {
  // Get all employees with pagination and filters
  async getAllEmployees(page = 1, limit = 10, search = '', department = '', status = '', sportComplexId = null) {
    const offset = (page - 1) * limit;
    
    // Build where clause for Employee
    const employeeWhere = {};
    if (department) {
      employeeWhere.department = department;
    }
    if (status) {
      employeeWhere.status = status;
    }
    // Per-complex admin scoping (no-op when not provided)
    if (sportComplexId != null) {
      employeeWhere.sportComplexId = sportComplexId;
    }

    // Build where clause for User (for search)
    const userWhere = {};
    if (search) {
      userWhere[Op.or] = [
        { name: { [Op.iLike]: `%${search}%` } },
        { email: { [Op.iLike]: `%${search}%` } },
        { phone_number: { [Op.iLike]: `%${search}%` } }
      ];
    }

    // Also search in employeeId
    if (search) {
      employeeWhere[Op.or] = [
        { employeeId: { [Op.iLike]: `%${search}%` } }
      ];
    }

    const { count, rows } = await Employee.findAndCountAll({
      where: employeeWhere,
      include: [
        {
          model: User,
          as: 'user',
          where: Object.keys(userWhere).length > 0 ? userWhere : undefined,
          attributes: ['id', 'name', 'email', 'phone_number', 'role', 'status']
        },
        {
          model: SportComplex,
          as: 'sportComplex',
          attributes: ['id', 'name', 'city']
        }
      ],
      limit: parseInt(limit),
      offset: parseInt(offset),
      order: [['createdAt', 'DESC']],
      distinct: true
    });

    return {
      data: rows,
      pagination: {
        currentPage: parseInt(page),
        totalPages: Math.ceil(count / limit),
        total: count,
        itemsPerPage: parseInt(limit)
      }
    };
  }

  // Get single employee by ID
  async getEmployeeById(id) {
    const employee = await Employee.findByPk(id, {
      include: [{
        model: User,
        as: 'user',
        attributes: ['id', 'name', 'email', 'phone_number', 'role', 'status']
      }]
    });

    if (!employee) {
      throw new Error('Employee not found');
    }

    return employee;
  }

  // Create new employee (also creates the EMPLOYEE login account)
  async createEmployee(data) {
    const { fullName, email, phone, password, employeeId, department, designation, joiningDate, salary, shift, address } = data;

    if (!password || String(password).length < 6) {
      throw new Error('Password is required and must be at least 6 characters');
    }

    // Check if email already exists
    const existingUser = await User.findOne({ where: { email } });
    if (existingUser) {
      throw new Error('Email already exists');
    }

    // Check if employeeId already exists
    const existingEmployee = await Employee.findOne({ where: { employeeId } });
    if (existingEmployee) {
      throw new Error('Employee ID already exists');
    }

    // Start transaction
    const transaction = await Employee.sequelize.transaction();

    try {
      // Create the login user with the admin-assigned password (hashed by model hook)
      const user = await User.create({
        name: fullName,
        email,
        phone_number: phone,
        password,
        // Keep a recoverable copy so an admin can view this staff login later.
        staff_password_enc: encryptSecret(password),
        role: 'EMPLOYEE',
        status: 'Active',
        sportComplexId: data.sportComplexId || null,
        permissions: getDefaultPermissions('EMPLOYEE'),
        isEmailVerified: true,
        join_date: new Date(),
      }, { transaction });

      // Create employee
      const employee = await Employee.create({
        userId: user.id,
        employeeId,
        department,
        designation,
        joiningDate,
        salary: salary || null,
        shift: shift || null,
        phone: phone || null,
        address: address || null,
        sportComplexId: data.sportComplexId, // Per-complex admin scoping
        status: 'Active'
      }, { transaction });

      await transaction.commit();

      // Fetch the created employee with user data
      return await this.getEmployeeById(employee.id);
    } catch (error) {
      await transaction.rollback();
      throw error;
    }
  }

  // Update employee
  async updateEmployee(id, data) {
    const { name, phone, department, designation, joiningDate, salary, shift, status, address, sportComplexId } = data;

    const employee = await Employee.findByPk(id, {
      include: [{ model: User, as: 'user' }]
    });

    if (!employee) {
      throw new Error('Employee not found');
    }

    // Start transaction
    const transaction = await Employee.sequelize.transaction();

    try {
      // Update user data
      if (name || phone) {
        await employee.user.update({
          name: name || employee.user.name,
          phone_number: phone || employee.user.phone_number
        }, { transaction });
      }

      // Update employee data
      await employee.update({
        department: department || employee.department,
        designation: designation || employee.designation,
        joiningDate: joiningDate || employee.joiningDate,
        salary: salary !== undefined ? salary : employee.salary,
        shift: shift || employee.shift,
        status: status || employee.status,
        phone: phone || employee.phone,
        address: address !== undefined ? address : employee.address,
        sportComplexId: sportComplexId !== undefined ? sportComplexId : employee.sportComplexId
      }, { transaction });

      await transaction.commit();

      // Fetch updated employee with user data
      return await this.getEmployeeById(id);
    } catch (error) {
      await transaction.rollback();
      throw error;
    }
  }

  // Delete employee
  async deleteEmployee(id) {
    const employee = await Employee.findByPk(id, {
      include: [{ model: User, as: 'user' }]
    });

    if (!employee) {
      throw new Error('Employee not found');
    }

    // Start transaction
    const transaction = await Employee.sequelize.transaction();

    try {
      const userId = employee.userId;

      // Delete employee record first
      await employee.destroy({ transaction });

      // Downgrade the linked login to a normal USER so the person can still sign
      // in as a regular user (not the employee dashboard), instead of deleting it.
      if (userId) {
        await demoteStaffUserToUser(userId, { transaction });
      }

      await transaction.commit();

      return { message: 'Employee deleted successfully' };
    } catch (error) {
      await transaction.rollback();
      throw error;
    }
  }
}

module.exports = new EmployeeService();
