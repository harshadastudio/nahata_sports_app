const employeeService = require('../services/employeeService');
const { resolveComplexId, isComplexAdmin, stampComplexId, assertComplexAccess } = require('../middleware/complexScope');
const { resolveStaffComplexId, emailStaffCredentials, revealStaffPassword, setStaffPassword, findStaffUser, formatSalary } = require('../utils/staffAccount');

class EmployeeController {
  // Reveal the stored login password for an employee (ADMIN / COMPLEX_ADMIN only).
  async revealPassword(req, res) {
    try {
      const employee = await employeeService.getEmployeeById(req.params.id);
      if (!employee) return res.status(404).json({ success: false, message: 'Employee not found' });
      if (isComplexAdmin(req) && !assertComplexAccess(req, res, employee.sportComplexId)) return;

      const user = await findStaffUser({ userId: employee.userId || employee.user?.id }, { withSecret: true });
      const password = revealStaffPassword(user);
      if (!password) {
        return res.status(404).json({
          success: false,
          message: 'No stored password for this employee. Use "Reset Password" to set a new one.',
        });
      }
      res.status(200).json({ success: true, data: { email: user.email, password } });
    } catch (error) {
      console.error('Error revealing employee password:', error);
      res.status(500).json({ success: false, message: 'Internal server error', error: error.message });
    }
  }

  // Reset an employee's login password to a new admin-set value (and re-email it).
  async resetPassword(req, res) {
    try {
      const { password } = req.body;
      if (!password || String(password).length < 6) {
        return res.status(400).json({ success: false, message: 'Password is required (min 6 characters)' });
      }
      const employee = await employeeService.getEmployeeById(req.params.id);
      if (!employee) return res.status(404).json({ success: false, message: 'Employee not found' });
      if (isComplexAdmin(req) && !assertComplexAccess(req, res, employee.sportComplexId)) return;

      const user = await findStaffUser({ userId: employee.userId || employee.user?.id }, { withSecret: true });
      if (!user) return res.status(404).json({ success: false, message: 'Login account not found for this employee' });

      await setStaffPassword(user, password);
      await emailStaffCredentials({
        to: user.email, name: user.name, email: user.email, password,
        roleKey: 'EMPLOYEE', sportComplexId: employee.sportComplexId,
        details: [
          { label: 'Phone', value: employee.phone || user.phone_number },
          { label: 'Employee ID', value: employee.employeeId },
          { label: 'Department', value: employee.department },
          { label: 'Designation', value: employee.designation },
          { label: 'Shift', value: employee.shift },
          { label: 'Salary', value: formatSalary(employee.salary) },
          { label: 'Joining Date', value: employee.joiningDate },
        ],
      });
      res.status(200).json({ success: true, message: 'Password reset and emailed to the employee' });
    } catch (error) {
      console.error('Error resetting employee password:', error);
      res.status(500).json({ success: false, message: 'Internal server error', error: error.message });
    }
  }

  // Get all employees
  async getAllEmployees(req, res) {
    try {
      const { page = 1, limit = 10, search = '', department = '', status = '' } = req.query;

      // Per-complex admin scoping (null for super admin = all complexes)
      const complexId = resolveComplexId(req);

      const result = await employeeService.getAllEmployees(page, limit, search, department, status, complexId);

      res.status(200).json({
        success: true,
        data: result.data,
        pagination: result.pagination
      });
    } catch (error) {
      console.error('Error fetching employees:', error);
      res.status(500).json({
        success: false,
        message: 'Internal server error',
        error: error.message
      });
    }
  }

  // Get single employee
  async getEmployeeById(req, res) {
    try {
      const { id } = req.params;

      const employee = await employeeService.getEmployeeById(id);

      // Complex admins can only view employees in their own complex
      if (!assertComplexAccess(req, res, employee.sportComplexId)) return;

      res.status(200).json({
        success: true,
        data: employee
      });
    } catch (error) {
      console.error('Error fetching employee:', error);
      
      if (error.message === 'Employee not found') {
        return res.status(404).json({
          success: false,
          message: 'Employee not found'
        });
      }

      res.status(500).json({
        success: false,
        message: 'Internal server error',
        error: error.message
      });
    }
  }

  // Create employee
  async createEmployee(req, res) {
    try {
      const { fullName, email, phone, password, employeeId, department, designation, joiningDate, shift } = req.body;

      // Validate required fields
      if (!fullName || !email || !phone || !employeeId || !department || !designation || !joiningDate || !shift) {
        return res.status(400).json({
          success: false,
          message: 'Missing required fields: fullName, email, phone, employeeId, department, designation, joiningDate, shift'
        });
      }
      if (!password || String(password).length < 6) {
        return res.status(400).json({ success: false, message: 'Password is required (min 6 characters)' });
      }

      // Resolve the complex: complex admin → own; super admin → must pick one.
      const complexId = resolveStaffComplexId(req);
      if (!complexId) {
        return res.status(400).json({ success: false, message: 'Please assign the employee to a sports complex' });
      }
      req.body.sportComplexId = complexId;

      const employee = await employeeService.createEmployee(req.body);

      // Email the login credentials + full Add-form details (non-fatal if it fails).
      await emailStaffCredentials({
        to: email, name: fullName, email, password, roleKey: 'EMPLOYEE', sportComplexId: complexId,
        details: [
          { label: 'Phone', value: req.body.phone },
          { label: 'Employee ID', value: req.body.employeeId },
          { label: 'Department', value: req.body.department },
          { label: 'Designation', value: req.body.designation },
          { label: 'Shift', value: req.body.shift },
          { label: 'Salary', value: formatSalary(req.body.salary) },
          { label: 'Joining Date', value: req.body.joiningDate },
          { label: 'Address', value: req.body.address },
        ],
      });

      res.status(201).json({
        success: true,
        data: employee,
        message: 'Employee created successfully'
      });
    } catch (error) {
      console.error('Error creating employee:', error);

      if (error.message === 'Email already exists' || error.message === 'Employee ID already exists') {
        return res.status(400).json({
          success: false,
          message: error.message
        });
      }

      res.status(500).json({
        success: false,
        message: 'Internal server error',
        error: error.message
      });
    }
  }

  // Update employee
  async updateEmployee(req, res) {
    try {
      const { id } = req.params;

      // Complex admins may only edit employees in their own complex, and cannot
      // move an employee to a different complex.
      if (isComplexAdmin(req)) {
        const existing = await employeeService.getEmployeeById(id);
        if (!assertComplexAccess(req, res, existing.sportComplexId)) return;
        stampComplexId(req, req.body);
      }

      const employee = await employeeService.updateEmployee(id, req.body);

      res.status(200).json({
        success: true,
        data: employee,
        message: 'Employee updated successfully'
      });
    } catch (error) {
      console.error('Error updating employee:', error);

      if (error.message === 'Employee not found') {
        return res.status(404).json({
          success: false,
          message: 'Employee not found'
        });
      }

      res.status(500).json({
        success: false,
        message: 'Internal server error',
        error: error.message
      });
    }
  }

  // Delete employee
  async deleteEmployee(req, res) {
    try {
      const { id } = req.params;

      // Complex admins may only delete employees in their own complex
      if (isComplexAdmin(req)) {
        const existing = await employeeService.getEmployeeById(id);
        if (!assertComplexAccess(req, res, existing.sportComplexId)) return;
      }

      const result = await employeeService.deleteEmployee(id);

      res.status(200).json({
        success: true,
        message: result.message
      });
    } catch (error) {
      console.error('Error deleting employee:', error);

      if (error.message === 'Employee not found') {
        return res.status(404).json({
          success: false,
          message: 'Employee not found'
        });
      }

      res.status(500).json({
        success: false,
        message: 'Internal server error',
        error: error.message
      });
    }
  }
}

module.exports = new EmployeeController();
