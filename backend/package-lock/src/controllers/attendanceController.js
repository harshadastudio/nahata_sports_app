'use strict';

const { Attendance, Student, Batch, User, Sport } = require('../models');
const { Op } = require('sequelize');
const { resolveComplexId, isComplexAdmin, assertComplexAccess } = require('../middleware/complexScope');

const STUDENT_USER_ATTRS = ['id', 'name', 'email', 'phone_number', 'blood_group', 'dob'];

/**
 * GET /api/attendance/my
 * User: get the logged-in user's own attendance records
 */
exports.getMyAttendance = async (req, res) => {
  try {
    // Find the Student record linked to this user, or create one lazily so that
    // attendance marked by a coach can always be retrieved by the user.
    let [student, created] = await Student.findOrCreate({
      where: { userId: req.user.id },
      defaults: {
        enrollmentDate: new Date(),
        status: 'Active',
      },
    });

    if (created) {
      console.log(`ℹ️  Auto-created Student profile for userId=${req.user.id}`);
    }

    const { fromDate, toDate, status, batchId } = req.query;

    const where = { studentId: student.id };
    if (status) where.status = status;
    if (batchId) where.batchId = batchId;
    if (fromDate || toDate) {
      where.date = {};
      if (fromDate) where.date[Op.gte] = fromDate;
      if (toDate) where.date[Op.lte] = toDate;
    }

    const records = await Attendance.findAll({
      where,
      include: [
        {
          model: Batch,
          as: 'batch',
          attributes: ['id', 'name', 'schedule', 'days'],
          include: [{ model: Sport, as: 'sport', attributes: ['id', 'name'] }],
        },
      ],
      order: [['date', 'DESC']],
    });

    // Shape the response to match what the frontend expects
    const data = records.map((r) => ({
      id: r.id,
      date: r.date,
      sport: r.batch?.sport?.name ?? null,
      batch: r.batch?.name ?? null,
      status: r.status,
      checkInTime: r.checkInTime,
      checkOutTime: r.checkOutTime,
      notes: r.notes,
    }));

    return res.json({ success: true, data });
  } catch (error) {
    console.error('❌ getMyAttendance error:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * GET /api/attendance
 * Admin: list all attendance records with filters
 */
exports.getAllAttendance = async (req, res) => {
  try {
    const {
      page = 1,
      limit = 20,
      studentId,
      batchId,
      date,
      fromDate,
      toDate,
      status,
      search,
    } = req.query;

    const where = {};

    if (studentId) where.studentId = studentId;
    if (batchId) where.batchId = batchId;
    if (status) where.status = status;

    if (date) {
      where.date = date;
    } else if (fromDate || toDate) {
      where.date = {};
      if (fromDate) where.date[Op.gte] = fromDate;
      if (toDate) where.date[Op.lte] = toDate;
    }

    const offset = (parseInt(page) - 1) * parseInt(limit);

    // Build student include with optional name search
    const studentInclude = {
      model: Student,
      as: 'student',
      required: !!search,
      include: [
        {
          model: User,
          as: 'User',
          attributes: STUDENT_USER_ATTRS,
          ...(search
            ? { where: { name: { [Op.iLike]: `%${search}%` } } }
            : {}),
        },
      ],
    };

    // Per-complex admin scoping: restrict to attendance whose batch is in the
    // admin's complex. null (super admin / coach) → no restriction.
    const complexId = resolveComplexId(req);

    const { count, rows } = await Attendance.findAndCountAll({
      where,
      include: [
        studentInclude,
        {
          model: Batch,
          as: 'batch',
          attributes: ['id', 'name', 'schedule', 'days'],
          required: complexId != null,
          ...(complexId != null ? { where: { sportComplexId: complexId } } : {}),
          include: [{ model: Sport, as: 'sport', attributes: ['id', 'name'] }],
        },
        {
          model: User,
          as: 'marker',
          attributes: ['id', 'name', 'role'],
        },
      ],
      order: [['date', 'DESC'], ['createdAt', 'DESC']],
      limit: parseInt(limit),
      offset,
      distinct: true,
    });

    return res.json({
      success: true,
      data: {
        attendance: rows,
        total: count,
        page: parseInt(page),
        limit: parseInt(limit),
        totalPages: Math.ceil(count / parseInt(limit)),
      },
    });
  } catch (error) {
    console.error('❌ getAllAttendance error:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * GET /api/attendance/stats
 * Admin: summary stats for dashboard
 */
exports.getAttendanceStats = async (req, res) => {
  try {
    const today = new Date().toISOString().split('T')[0];
    const startOfMonth = new Date(new Date().getFullYear(), new Date().getMonth(), 1)
      .toISOString().split('T')[0];

    // Per-complex admin scoping: every count/group joins the batch and requires
    // it to belong to that complex. null (super admin / employee) → no restriction.
    const complexId = resolveComplexId(req);
    const scopeInclude = complexId != null
      ? [{ model: Batch, as: 'batch', attributes: [], where: { sportComplexId: complexId }, required: true }]
      : [];
    const countExtra = complexId != null ? { distinct: true, col: 'id' } : {};

    const [totalToday, totalMonth, byStatus] = await Promise.all([
      Attendance.count({ where: { date: today }, include: scopeInclude, ...countExtra }),
      Attendance.count({ where: { date: { [Op.gte]: startOfMonth } }, include: scopeInclude, ...countExtra }),
      Attendance.findAll({
        attributes: [
          'status',
          [require('sequelize').fn('COUNT', require('sequelize').col('Attendance.id')), 'count'],
        ],
        include: scopeInclude,
        group: ['Attendance.status'],
        raw: true,
      }),
    ]);

    const statusMap = {};
    byStatus.forEach((r) => { statusMap[r.status] = parseInt(r.count); });

    return res.json({
      success: true,
      data: {
        totalToday,
        totalMonth,
        present: statusMap['Present'] || 0,
        absent: statusMap['Absent'] || 0,
        late: statusMap['Late'] || 0,
        leave: statusMap['Leave'] || 0,
      },
    });
  } catch (error) {
    console.error('❌ getAttendanceStats error:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * POST /api/attendance
 * Admin/Coach: mark attendance for a student
 */
exports.markAttendance = async (req, res) => {
  try {
    let { studentId, studentName, batchId, batchName, date, status, checkInTime, checkOutTime, notes } = req.body;

    // Validate required fields
    if (!date || !status) {
      return res.status(400).json({
        success: false,
        message: 'date and status are required',
      });
    }

    // If studentName is provided instead of studentId, look it up
    if (!studentId && studentName) {
      const user = await User.findOne({
        where: { name: { [Op.iLike]: studentName.trim() } },
        attributes: ['id']
      });
      
      if (!user) {
        return res.status(400).json({
          success: false,
          message: `Student "${studentName}" not found`,
        });
      }

      const student = await Student.findOne({
        where: { userId: user.id },
        attributes: ['id']
      });

      if (!student) {
        return res.status(400).json({
          success: false,
          message: `Student profile not found for "${studentName}"`,
        });
      }

      studentId = student.id;
    }

    // If batchName is provided instead of batchId, look it up
    if (!batchId && batchName) {
      const batch = await Batch.findOne({
        where: { name: { [Op.iLike]: batchName.trim() } },
        attributes: ['id']
      });

      if (!batch) {
        return res.status(400).json({
          success: false,
          message: `Batch "${batchName}" not found`,
        });
      }

      batchId = batch.id;
    }

    // Final validation
    if (!studentId || !batchId) {
      return res.status(400).json({
        success: false,
        message: 'studentId/studentName and batchId/batchName are required',
      });
    }

    const validStatuses = ['Present', 'Absent', 'Late', 'Leave'];
    if (!validStatuses.includes(status)) {
      return res.status(400).json({ success: false, message: 'Invalid status value' });
    }

    // Complex admins may only mark attendance for a batch in their own complex.
    if (isComplexAdmin(req)) {
      const targetBatch = await Batch.findByPk(batchId, { attributes: ['id', 'sportComplexId'] });
      if (!assertComplexAccess(req, res, targetBatch ? targetBatch.sportComplexId : null)) return;
    }

    // Upsert — one record per student per batch per date
    const [record, created] = await Attendance.findOrCreate({
      where: { studentId, batchId, date },
      defaults: {
        status,
        checkInTime: checkInTime || null,
        checkOutTime: checkOutTime || null,
        notes: notes || null,
        markedBy: req.user.id,
      },
    });

    if (!created) {
      await record.update({
        status,
        checkInTime: checkInTime || record.checkInTime,
        checkOutTime: checkOutTime || record.checkOutTime,
        notes: notes !== undefined ? notes : record.notes,
        markedBy: req.user.id,
      });
    }

    const updated = await Attendance.findByPk(record.id, {
      include: [
        {
          model: Student,
          as: 'student',
          include: [{ model: User, as: 'User', attributes: STUDENT_USER_ATTRS }],
        },
        { model: Batch, as: 'batch', attributes: ['id', 'name'] },
      ],
    });

    return res.status(created ? 201 : 200).json({
      success: true,
      message: created ? 'Attendance marked successfully' : 'Attendance updated successfully',
      data: updated,
    });
  } catch (error) {
    console.error('❌ markAttendance error:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * PATCH /api/attendance/:id
 * Admin/Coach: update a single attendance record
 */
exports.updateAttendance = async (req, res) => {
  try {
    const record = await Attendance.findByPk(req.params.id, {
      include: isComplexAdmin(req)
        ? [{ model: Batch, as: 'batch', attributes: ['id', 'sportComplexId'] }]
        : [],
    });
    if (!record) {
      return res.status(404).json({ success: false, message: 'Attendance record not found' });
    }

    // Complex admins may only update attendance whose batch is in their complex.
    if (isComplexAdmin(req) &&
      !assertComplexAccess(req, res, record.batch ? record.batch.sportComplexId : null)) {
      return;
    }

    const { status, checkInTime, checkOutTime, notes } = req.body;
    await record.update({
      ...(status && { status }),
      ...(checkInTime !== undefined && { checkInTime }),
      ...(checkOutTime !== undefined && { checkOutTime }),
      ...(notes !== undefined && { notes }),
      markedBy: req.user.id,
    });

    return res.json({ success: true, message: 'Attendance updated', data: record });
  } catch (error) {
    console.error('❌ updateAttendance error:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * DELETE /api/attendance/:id
 * Admin: delete an attendance record
 */
exports.deleteAttendance = async (req, res) => {
  try {
    const record = await Attendance.findByPk(req.params.id, {
      include: isComplexAdmin(req)
        ? [{ model: Batch, as: 'batch', attributes: ['id', 'sportComplexId'] }]
        : [],
    });
    if (!record) {
      return res.status(404).json({ success: false, message: 'Attendance record not found' });
    }

    // Complex admins may only delete attendance whose batch is in their complex.
    if (isComplexAdmin(req) &&
      !assertComplexAccess(req, res, record.batch ? record.batch.sportComplexId : null)) {
      return;
    }

    await record.destroy();
    return res.json({ success: true, message: 'Attendance record deleted' });
  } catch (error) {
    console.error('❌ deleteAttendance error:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};
