'use strict';

const { StudentBatches, Student, Batch, User, Sport, Coach, Attendance, StudentPassScanLog } = require('../models');
const { Op } = require('sequelize');
const { resolveComplexId, isComplexScoped, assertComplexAccess } = require('../middleware/complexScope');
// NOTE: `isCoach` is deliberately NOT imported — several handlers below declare
// a local `const isCoach = ...`, and importing the name would shadow/TDZ-clash.
const { resolveCoachId, assertCoachAccess } = require('../middleware/coachScope');

const STUDENT_USER_ATTRS = ['id', 'name', 'email', 'phone_number', 'blood_group', 'dob'];

// Batch attributes used when presenting a fee record / gate pass.
// (Batch replaced Program: price -> fees, batchDays -> days.)
const BATCH_ATTRS = ['id', 'name', 'fees', 'duration', 'days', 'startTime', 'endTime', 'endDate'];

/**
 * Builds the gate pass code for a StudentBatches record.
 * Matches the format used in the admin panel ApproveStudents page.
 */
function buildPassCode(recordId) {
  return `GATEPASS-${new Date().getFullYear()}-${String(recordId).padStart(6, '0')}`;
}

function buildQrUrl(passCode) {
  return `https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${encodeURIComponent(passCode)}&format=png&margin=10`;
}

/**
 * The `where` applied to the Batch join when listing / counting fee records.
 * Both scopes stack: a coach is complex-bound AND limited to their own batches.
 * An empty object means "no restriction" (super admin).
 */
function buildBatchScopeWhere(complexId, coachId) {
  const where = {};
  if (complexId != null) where.sportComplexId = complexId;
  if (coachId != null) where.coachId = coachId;
  return where;
}

/**
 * Per-record complex gate for any complex-scoped role (Complex Admin, Employee,
 * Coach, Security). Fetches the fee record's batch complex (Batch.sportComplexId)
 * and 403s if it is outside the caller's own complex. No-op for super admin.
 * Returns true when access is allowed.
 */
async function assertFeeComplexAccess(req, res, recordId) {
  if (!isComplexScoped(req)) return true;
  const row = await StudentBatches.findByPk(recordId, {
    attributes: ['id', 'batchId'],
    include: [{ model: Batch, as: 'batch', attributes: ['id', 'sportComplexId'] }],
  });
  // Record-not-found is handled by the caller; only gate when the row exists.
  if (!row) return true;
  return assertComplexAccess(req, res, row.batch ? row.batch.sportComplexId : null);
}

/**
 * Per-record coach gate. A COACH may only touch fee records whose batch is one
 * of their OWN (Batch.coachId) — an enrollment approved into another coach's
 * batch is not theirs to see or edit. No-op for every other role.
 * Returns true when access is allowed.
 */
async function assertFeeCoachAccess(req, res, recordId) {
  const coachId = await resolveCoachId(req);
  if (coachId == null) return true;
  const row = await StudentBatches.findByPk(recordId, {
    attributes: ['id', 'batchId'],
    include: [{ model: Batch, as: 'batch', attributes: ['id', 'coachId'] }],
  });
  // Record-not-found is handled by the caller; only gate when the row exists.
  if (!row) return true;
  return assertCoachAccess(req, res, row.batch ? row.batch.coachId : null);
}

/**
 * GET /api/fees/my
 * User: get own approved gate passes (StudentBatches records with approvalStatus = 'Approved')
 */
exports.getMyGatePasses = async (req, res) => {
  try {
    // Find the Student record linked to this user
    const student = await Student.findOne({
      where: { userId: req.user.id },
      include: [{ model: User, as: 'User', attributes: STUDENT_USER_ATTRS }],
    });

    if (!student) {
      return res.json({ success: true, data: [] });
    }

    const records = await StudentBatches.findAll({
      where: {
        studentId: student.id,
        approvalStatus: 'Approved',
      },
      include: [
        {
          model: Batch,
          as: 'batch',
          attributes: BATCH_ATTRS,
          include: [
            { model: Sport, as: 'sport', attributes: ['id', 'name', 'image'] },
            { model: Coach, as: 'coach', attributes: ['id', 'name', 'phone'] },
          ],
        },
      ],
      order: [['approvedAt', 'DESC'], ['createdAt', 'DESC']],
    });

    const data = records.map((r) => {
      const passCode = buildPassCode(r.id);
      return {
        id: r.id,
        passCode,
        qrCode: buildQrUrl(passCode),
        studentName: student.User?.name ?? '',
        studentPhone: student.User?.phone_number ?? '',
        bloodGroup: student.User?.blood_group ?? '',
        dob: student.User?.dob ?? '',
        batchId: r.batchId,
        batchName: r.batch?.name ?? '',
        sportName: r.batch?.sport?.name ?? '',
        sportImage: r.batch?.sport?.image ?? null,
        coachName: r.batch?.coach?.name ?? '',
        amountPaid: r.amountPaid,
        batchFee: r.batch?.fees ?? 0,
        paymentStatus: r.paymentStatus,
        approvalStatus: r.approvalStatus,
        enrollmentDate: r.enrollmentDate,
        // Per-student validity entered by the coach; the batch end date is the
        // fallback so an older record without one still shows an expiry.
        validTill: r.validTill ?? r.batch?.endDate ?? null,
        approvedAt: r.approvedAt,
        status: r.status,
        notes: r.notes,
        batchDays: r.batch?.days ?? '',
        startTime: r.batch?.startTime ?? '',
        endTime: r.batch?.endTime ?? '',
      };
    });

    return res.json({ success: true, data });
  } catch (error) {
    console.error('❌ getMyGatePasses error:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * POST /api/fees/scan-pass
 * Scan a student gate pass (GATEPASS-<year>-<StudentBatches id>) at the gate.
 * Decodes the pass → validates the enrollment is Approved → returns the
 * student/batch details to the scanner. Attendance is only marked when a
 * COACH scans (they're running the session); every other role (Security,
 * Employee, Admin, Complex Admin) only verifies the pass and sees the
 * student's name — no attendance side effect. Every scan, regardless of
 * role, is logged to StudentPassScanLogs for the date-wise scan log.
 */
exports.scanStudentPass = async (req, res) => {
  try {
    const { passCode } = req.body;
    if (!passCode || typeof passCode !== 'string') {
      return res.status(400).json({ success: false, message: 'Pass code is required.' });
    }

    // The StudentBatches id is the trailing number of GATEPASS-YYYY-000042.
    // Tolerant of a bare id or extra surrounding text from a QR reader.
    const match = passCode.trim().toUpperCase().match(/(\d+)\s*$/);
    const recordId = match ? parseInt(match[1], 10) : NaN;
    if (!recordId || Number.isNaN(recordId)) {
      return res.status(400).json({ success: false, message: 'Invalid pass code format.' });
    }

    const record = await StudentBatches.findByPk(recordId, {
      include: [
        {
          model: Batch,
          as: 'batch',
          attributes: ['id', 'name', 'days', 'startTime', 'endTime', 'sportComplexId'],
          include: [
            { model: Sport, as: 'sport', attributes: ['id', 'name', 'image'] },
            { model: Coach, as: 'coach', attributes: ['id', 'name'] },
          ],
        },
      ],
    });

    if (!record) {
      return res.status(404).json({ success: false, message: 'Invalid pass — no matching enrollment found.' });
    }

    // A coach / security guard / complex admin may only scan their own complex.
    if (!assertComplexAccess(req, res, record.batch ? record.batch.sportComplexId : null)) return;

    // The pass is only valid once the enrollment/fee has been Approved.
    if (record.approvalStatus !== 'Approved') {
      return res.status(409).json({
        success: false,
        message: `Pass not valid — enrollment is "${record.approvalStatus || 'Pending'}", not Approved.`,
      });
    }

    const student = await Student.findByPk(record.studentId, {
      include: [
        { model: User, as: 'User', attributes: ['id', 'name', 'phone_number', 'blood_group', 'dob', 'avatar'] },
      ],
    });

    const now = new Date();
    const dateStr = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;
    const timeStr = `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}:${String(now.getSeconds()).padStart(2, '0')}`;
    const markedBy = req.user ? req.user.id : null;
    const scannerRole = req.user ? String(req.user.role).toUpperCase() : null;

    // Only a COACH scan marks attendance — they're the one running the
    // session. Security / Employee / Admin / Complex Admin scans only verify
    // the pass and show the student's name at the gate.
    const shouldMarkAttendance = scannerRole === 'COACH';

    let attendanceState; // 'marked' (new) | 'updated' (was absent/late) | 'already' | 'verified' (no mark)
    let checkInTime = null;

    if (shouldMarkAttendance) {
      const [attendance, created] = await Attendance.findOrCreate({
        where: { studentId: record.studentId, batchId: record.batchId, date: dateStr },
        defaults: { status: 'Present', checkInTime: timeStr, markedBy },
      });

      if (created) {
        attendanceState = 'marked';
      } else if (attendance.status === 'Present') {
        attendanceState = 'already';
      } else {
        await attendance.update({ status: 'Present', checkInTime: attendance.checkInTime || timeStr, markedBy });
        attendanceState = 'updated';
      }
      checkInTime = attendance.checkInTime || timeStr;
    } else {
      attendanceState = 'verified';
    }

    // Log every scan (regardless of role) for the date-wise scan log.
    await StudentPassScanLog.create({
      studentBatchId: record.id,
      scannedBy: markedBy,
      scannerRole,
      attendanceMarked: shouldMarkAttendance,
      sportComplexId: record.batch ? record.batch.sportComplexId : null,
    });

    const studentName = student?.User?.name || 'Student';
    const message = !shouldMarkAttendance
      ? `Pass verified — ${studentName}.`
      : attendanceState === 'already'
        ? `${studentName} is already marked Present today.`
        : `Entry granted — ${studentName} marked Present.`;

    return res.status(200).json({
      success: true,
      message,
      data: {
        passCode: buildPassCode(record.id),
        attendanceState,
        date: dateStr,
        checkInTime,
        student: {
          name: studentName,
          phone: student?.User?.phone_number || '',
          bloodGroup: student?.User?.blood_group || '',
          dob: student?.User?.dob || '',
          avatar: student?.User?.avatar || null,
        },
        batchName: record.batch?.name || '',
        sportName: record.batch?.sport?.name || '',
        sportImage: record.batch?.sport?.image || null,
        coachName: record.batch?.coach?.name || '',
        batchDays: record.batch?.days || '',
        startTime: record.batch?.startTime || '',
        endTime: record.batch?.endTime || '',
      },
    });
  } catch (error) {
    console.error('❌ scanStudentPass error:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * GET /api/fees/scan-logs
 * Date-wise log of every student gate-pass scan (Security, Coach, Employee,
 * Admin, Complex Admin) — who scanned, when, and whether it marked
 * attendance. Complex-scoped for complex-bound roles; a super admin sees
 * every complex (optionally filtered via ?sportComplexId=).
 */
exports.getScanLogs = async (req, res) => {
  try {
    const { page = 1, limit = 50, date, scannerRole } = req.query;

    const where = {};
    if (date) {
      const dayStart = new Date(`${date}T00:00:00`);
      const dayEnd = new Date(`${date}T23:59:59.999`);
      where.createdAt = { [Op.between]: [dayStart, dayEnd] };
    }
    if (scannerRole) {
      where.scannerRole = String(scannerRole).toUpperCase();
    }

    const complexId = resolveComplexId(req);
    if (complexId != null) {
      where.sportComplexId = complexId;
    }

    const offset = (parseInt(page) - 1) * parseInt(limit);

    const { count, rows } = await StudentPassScanLog.findAndCountAll({
      where,
      include: [
        {
          model: StudentBatches,
          as: 'studentBatch',
          attributes: ['id', 'studentId', 'batchId'],
          include: [
            {
              model: Student,
              as: 'student',
              include: [{ model: User, as: 'User', attributes: ['id', 'name', 'phone_number'] }],
            },
            { model: Batch, as: 'batch', attributes: ['id', 'name'] },
          ],
        },
        { model: User, as: 'scanner', attributes: ['id', 'name', 'role'] },
      ],
      order: [['createdAt', 'DESC']],
      limit: parseInt(limit),
      offset,
      distinct: true,
    });

    const data = rows.map((r) => ({
      id: r.id,
      scannedAt: r.createdAt,
      attendanceMarked: r.attendanceMarked,
      scannerRole: r.scannerRole,
      scannerName: r.scanner?.name || 'Unknown',
      studentName: r.studentBatch?.student?.User?.name || 'Unknown',
      studentPhone: r.studentBatch?.student?.User?.phone_number || '',
      batchName: r.studentBatch?.batch?.name || '',
      passCode: r.studentBatch ? buildPassCode(r.studentBatch.id) : null,
    }));

    return res.json({
      success: true,
      data: {
        logs: data,
        total: count,
        page: parseInt(page),
        limit: parseInt(limit),
        totalPages: Math.ceil(count / parseInt(limit)),
      },
    });
  } catch (error) {
    console.error('❌ getScanLogs error:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * GET /api/fees
 * Admin: list all student-batch fee records
 */
exports.getAllFees = async (req, res) => {
  try {
    const {
      page = 1,
      limit = 20,
      paymentStatus,
      approvalStatus,
      batchId,
      search,
      sportId,
      month,
      batch,
    } = req.query;

    const where = {};
    if (paymentStatus) where.paymentStatus = paymentStatus;
    if (approvalStatus) where.approvalStatus = approvalStatus;
    if (batchId) where.batchId = batchId;

    // Month filter - filter by enrollment month
    if (month) {
      const monthNum = parseInt(month);
      where.enrollmentDate = {
        [Op.and]: [
          { [Op.gte]: new Date(new Date().getFullYear(), monthNum - 1, 1) },
          { [Op.lt]: new Date(new Date().getFullYear(), monthNum, 1) }
        ]
      };
    }

    const offset = (parseInt(page) - 1) * parseInt(limit);

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

    const batchWhere = {};
    if (batch) {
      batchWhere.name = { [Op.iLike]: `%${batch}%` };
    }
    if (sportId) {
      batchWhere.sportId = sportId;
    }
    // Per-complex admin scoping: restrict fees to those whose batch is in the
    // admin's complex. null (super admin) → no restriction.
    const complexId = resolveComplexId(req);
    if (complexId != null) {
      batchWhere.sportComplexId = complexId;
    }
    // Per-coach scoping: a coach only ever sees fee records for students in
    // their OWN batches, so a student approved from a Coaching Enquiry shows up
    // for that batch's coach alone. null (every other role) → no restriction.
    const coachId = await resolveCoachId(req);
    if (coachId != null) {
      batchWhere.coachId = coachId;
    }

    const { count, rows } = await StudentBatches.findAndCountAll({
      where,
      include: [
        studentInclude,
        {
          model: Batch,
          as: 'batch',
          attributes: BATCH_ATTRS,
          where: Object.keys(batchWhere).length > 0 ? batchWhere : undefined,
          required: Object.keys(batchWhere).length > 0,
          include: [
            { model: Sport, as: 'sport', attributes: ['id', 'name'] },
            { model: Coach, as: 'coach', attributes: ['id', 'name', 'phone'] },
          ],
        },
      ],
      order: [['createdAt', 'DESC']],
      limit: parseInt(limit),
      offset,
      distinct: true,
    });

    return res.json({
      success: true,
      data: {
        fees: rows,
        total: count,
        page: parseInt(page),
        limit: parseInt(limit),
        totalPages: Math.ceil(count / parseInt(limit)),
      },
    });
  } catch (error) {
    console.error('❌ getAllFees error:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * GET /api/fees/stats
 * Admin: summary stats
 */
exports.getFeesStats = async (req, res) => {
  try {
    // Scoping: every count joins the batch and requires it to belong to the
    // caller's complex (complex-bound roles) and, for a coach, to be one of
    // their own batches — so the stat cards match the rows they can see.
    const batchScopeWhere = buildBatchScopeWhere(resolveComplexId(req), await resolveCoachId(req));
    const isScoped = Object.keys(batchScopeWhere).length > 0;
    const scopeInclude = isScoped
      ? [{ model: Batch, as: 'batch', attributes: [], where: batchScopeWhere, required: true }]
      : [];
    const countExtra = isScoped ? { distinct: true, col: 'id' } : {};
    const scoped = (where) => ({ ...(where ? { where } : {}), include: scopeInclude, ...countExtra });

    const [total, paid, unpaid, overdue, pendingApproval] = await Promise.all([
      StudentBatches.count(scoped()),
      StudentBatches.count(scoped({ paymentStatus: 'Paid' })),
      StudentBatches.count(scoped({ paymentStatus: 'Pending' })),
      StudentBatches.count(scoped({ paymentStatus: 'Overdue' })),
      StudentBatches.count(scoped({ approvalStatus: 'Pending' })),
    ]);

    return res.json({
      success: true,
      data: { total, paid, unpaid, overdue, pendingApproval },
    });
  } catch (error) {
    console.error('❌ getFeesStats error:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * GET /api/fees/debug-stats
 * Admin: detailed stats for debugging
 */
exports.getDebugStats = async (req, res) => {
  try {
    // Same complex + coach scoping as getFeesStats, so the debug numbers match
    // what the caller actually sees.
    const batchScopeWhere = buildBatchScopeWhere(resolveComplexId(req), await resolveCoachId(req));
    const isScoped = Object.keys(batchScopeWhere).length > 0;
    const scopeInclude = isScoped
      ? [{ model: Batch, as: 'batch', attributes: [], where: batchScopeWhere, required: true }]
      : [];
    const countExtra = isScoped ? { distinct: true, col: 'id' } : {};
    const scoped = (where) => ({ ...(where ? { where } : {}), include: scopeInclude, ...countExtra });

    // Get all records with their approval status
    const allRecords = await StudentBatches.findAll({
      attributes: ['id', 'approvalStatus', 'paymentStatus', 'enrollmentDate'],
      include: [
        {
          model: Student,
          as: 'student',
          include: [{ model: User, as: 'User', attributes: ['name'] }],
        },
        ...scopeInclude,
      ],
      raw: true,
      nest: true,
    });

    // Count by approval status
    const approvalStatusCounts = {};
    const paymentStatusCounts = {};

    allRecords.forEach(record => {
      const approval = record.approvalStatus || 'NULL';
      const payment = record.paymentStatus || 'NULL';

      approvalStatusCounts[approval] = (approvalStatusCounts[approval] || 0) + 1;
      paymentStatusCounts[payment] = (paymentStatusCounts[payment] || 0) + 1;
    });

    // Get official counts
    const [total, paid, unpaid, overdue, pendingApproval, approvedCount, rejectedCount] = await Promise.all([
      StudentBatches.count(scoped()),
      StudentBatches.count(scoped({ paymentStatus: 'Paid' })),
      StudentBatches.count(scoped({ paymentStatus: 'Pending' })),
      StudentBatches.count(scoped({ paymentStatus: 'Overdue' })),
      StudentBatches.count(scoped({ approvalStatus: 'Pending' })),
      StudentBatches.count(scoped({ approvalStatus: 'Approved' })),
      StudentBatches.count(scoped({ approvalStatus: 'Rejected' })),
    ]);

    return res.json({
      success: true,
      data: {
        officialCounts: {
          total,
          paid,
          unpaid,
          overdue,
          pendingApproval,
          approvedCount,
          rejectedCount,
        },
        manualCounts: {
          approvalStatus: approvalStatusCounts,
          paymentStatus: paymentStatusCounts,
        },
        samplePendingRecords: allRecords
          .filter(r => r.approvalStatus === 'Pending')
          .slice(0, 5)
          .map(r => ({
            id: r.id,
            studentName: r.student?.User?.name || 'Unknown',
            approvalStatus: r.approvalStatus,
            paymentStatus: r.paymentStatus,
            enrollmentDate: r.enrollmentDate,
          })),
      },
    });
  } catch (error) {
    console.error('❌ getDebugStats error:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * POST /api/fees
 * Admin: create a new fee record (StudentBatches enrollment)
 */
exports.createFeeRecord = async (req, res) => {
  try {
    const { studentId, batchId, enrollmentDate, validTill, paymentStatus, amountPaid, paymentMode, notes } = req.body;

    if (!studentId || !batchId) {
      return res.status(400).json({
        success: false,
        message: 'studentId and batchId are required',
      });
    }

    // Complex-scoped roles (Complex Admin, Coach, Employee, Security) may only
    // create fee records for a batch in their own complex; a Coach is further
    // restricted to their own batches.
    const coachScopeId = await resolveCoachId(req);
    if (isComplexScoped(req) || coachScopeId != null) {
      const targetBatch = await Batch.findByPk(batchId, {
        attributes: ['id', 'sportComplexId', 'coachId'],
      });
      if (isComplexScoped(req) &&
        !assertComplexAccess(req, res, targetBatch ? targetBatch.sportComplexId : null)) {
        return;
      }
      if (coachScopeId != null &&
        !(await assertCoachAccess(req, res, targetBatch ? targetBatch.coachId : null))) {
        return;
      }
    }

    const existing = await StudentBatches.findOne({ where: { studentId, batchId } });
    if (existing) {
      return res.status(409).json({
        success: false,
        message: 'This student is already enrolled in this batch',
      });
    }

    // A Coach can record the fee as Paid immediately (they collected it in
    // person) — but approvalStatus always starts Pending regardless of role,
    // since only Admin/Employee approval unlocks the student's gate pass QR.
    const record = await StudentBatches.create({
      studentId,
      batchId,
      enrollmentDate: enrollmentDate || new Date(),
      validTill: validTill || null,
      status: 'Active',
      paymentStatus: paymentStatus || 'Pending',
      approvalStatus: 'Pending',
      amountPaid: amountPaid || 0,
      paymentMode: paymentMode || null,
      receivedBy: req.user ? req.user.id : null,
      notes: notes || null,
    });

    const created = await StudentBatches.findByPk(record.id, {
      include: [
        {
          model: Student,
          as: 'student',
          include: [{ model: User, as: 'User', attributes: STUDENT_USER_ATTRS }],
        },
        {
          model: Batch,
          as: 'batch',
          attributes: ['id', 'name', 'fees', 'duration'],
          include: [{ model: Sport, as: 'sport', attributes: ['id', 'name'] }],
        },
      ],
    });

    return res.status(201).json({
      success: true,
      message: 'Fee record created successfully',
      data: created,
    });
  } catch (error) {
    console.error('❌ createFeeRecord error:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * PATCH /api/fees/:id/payment
 * Admin: mark a fee as paid or unpaid
 */
exports.updatePaymentStatus = async (req, res) => {
  try {
    const record = await StudentBatches.findByPk(req.params.id);
    if (!record) {
      return res.status(404).json({ success: false, message: 'Fee record not found' });
    }

    // Complex-scoped roles may only act on fee records whose batch is in their complex.
    if (!(await assertFeeComplexAccess(req, res, record.id))) return;
    // A Coach may only act on fee records for their own batches.
    if (!(await assertFeeCoachAccess(req, res, record.id))) return;

    const { paymentStatus, amountPaid, paymentMode, notes } = req.body;
    const isCoach = req.user && String(req.user.role).toUpperCase() === 'COACH';

    // A Coach can mark a fee Paid directly — they collected it. But that
    // never implies approval: a coach's update always resets approvalStatus
    // to Pending, so the gate-pass QR only unlocks once Admin/Employee
    // separately approves it (also re-queues a previously-Rejected record).
    const validStatuses = ['Pending', 'Paid', 'Partial', 'Overdue'];
    if (paymentStatus && !validStatuses.includes(paymentStatus)) {
      return res.status(400).json({ success: false, message: 'Invalid payment status' });
    }

    await record.update({
      ...(paymentStatus && { paymentStatus }),
      ...(amountPaid !== undefined && { amountPaid }),
      ...(paymentMode !== undefined && { paymentMode }),
      ...(isCoach && { receivedBy: req.user.id, approvalStatus: 'Pending' }),
      ...(notes !== undefined && { notes }),
    });

    const updated = await StudentBatches.findByPk(record.id, {
      include: [
        {
          model: Student,
          as: 'student',
          include: [{ model: User, as: 'User', attributes: STUDENT_USER_ATTRS }],
        },
        {
          model: Batch,
          as: 'batch',
          attributes: ['id', 'name', 'fees', 'duration'],
          include: [{ model: Sport, as: 'sport', attributes: ['id', 'name'] }],
        },
      ],
    });

    return res.json({
      success: true,
      message: 'Payment status updated',
      data: updated,
    });
  } catch (error) {
    console.error('❌ updatePaymentStatus error:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * PATCH /api/fees/:id/approve
 * Admin: approve a pending fee payment
 */
exports.approveFeePayment = async (req, res) => {
  try {
    const record = await StudentBatches.findByPk(req.params.id, {
      include: [
        {
          model: Student,
          as: 'student',
          include: [{ model: User, as: 'User', attributes: STUDENT_USER_ATTRS }],
        },
        {
          model: Batch,
          as: 'batch',
          attributes: ['id', 'name', 'fees', 'duration', 'sportComplexId'],
        },
      ],
    });

    if (!record) {
      return res.status(404).json({ success: false, message: 'Fee record not found' });
    }

    // Complex-scoped approvers (Complex Admin, Employee) may only approve fee
    // records whose batch is in their own complex.
    if (isComplexScoped(req) &&
      !assertComplexAccess(req, res, record.batch ? record.batch.sportComplexId : null)) {
      return;
    }

    await record.update({
      approvalStatus: 'Approved',
      paymentStatus: 'Paid',
      feesPaid: true,
      approvedBy: req.user.id,
      approvedAt: new Date(),
    });

    return res.json({
      success: true,
      message: 'Fee payment approved',
      data: record,
    });
  } catch (error) {
    console.error('❌ approveFeePayment error:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * PATCH /api/fees/:id/reject
 * Admin: reject a pending fee payment
 */
exports.rejectFeePayment = async (req, res) => {
  try {
    const record = await StudentBatches.findByPk(req.params.id);
    if (!record) {
      return res.status(404).json({ success: false, message: 'Fee record not found' });
    }

    // Complex admins may only reject fee records whose batch is in their complex.
    if (!(await assertFeeComplexAccess(req, res, record.id))) return;

    await record.update({
      approvalStatus: 'Rejected',
      paymentStatus: 'Pending',
      feesPaid: false,
      approvedBy: req.user.id,
      approvedAt: new Date(),
    });

    return res.json({
      success: true,
      message: 'Fee payment rejected',
      data: record,
    });
  } catch (error) {
    console.error('❌ rejectFeePayment error:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * PUT /api/fees/:id
 * Admin: update a fee record (including student name, batch name, and fees)
 */
exports.updateFeeRecord = async (req, res) => {
  try {
    const record = await StudentBatches.findByPk(req.params.id, {
      include: [
        {
          model: Student,
          as: 'student',
          include: [{ model: User, as: 'User', attributes: STUDENT_USER_ATTRS }],
        },
        {
          model: Batch,
          as: 'batch',
        },
      ],
    });

    if (!record) {
      return res.status(404).json({ success: false, message: 'Fee record not found' });
    }

    // Complex-scoped roles may only update fee records whose batch is in their complex.
    if (isComplexScoped(req) &&
      !assertComplexAccess(req, res, record.batch ? record.batch.sportComplexId : null)) {
      return;
    }

    // A Coach may only update fee records for their own batches. `record.batch`
    // is already loaded in full above, so no extra query is needed.
    const coachScopeId = await resolveCoachId(req);
    if (coachScopeId != null &&
      !(await assertCoachAccess(req, res, record.batch ? record.batch.coachId : null))) {
      return;
    }

    const {
      studentId,
      studentName,
      batchId,
      batchName,
      batchFee,
      amountPaid,
      paymentMode,
      enrollmentDate,
      validTill,
      paymentStatus,
      notes
    } = req.body;

    // A complex-scoped role must not re-point a fee record to a batch outside
    // their complex, and a coach must not hand it to another coach's batch.
    if ((isComplexScoped(req) || coachScopeId != null) && batchId && Number(batchId) !== record.batchId) {
      const targetBatch = await Batch.findByPk(batchId, {
        attributes: ['id', 'sportComplexId', 'coachId'],
      });
      if (isComplexScoped(req) &&
        !assertComplexAccess(req, res, targetBatch ? targetBatch.sportComplexId : null)) {
        return;
      }
      if (coachScopeId != null &&
        !(await assertCoachAccess(req, res, targetBatch ? targetBatch.coachId : null))) {
        return;
      }
    }

    // Update student name if provided
    if (studentName && record.student?.User) {
      await User.update(
        { name: studentName },
        { where: { id: record.student.User.id } }
      );
    }

    // Update batch name if provided
    if (batchName && record.batch) {
      await Batch.update(
        { name: batchName },
        { where: { id: record.batch.id } }
      );
    }

    // Update batch fee if provided
    if (batchFee && record.batch) {
      await Batch.update(
        { fees: batchFee },
        { where: { id: record.batch.id } }
      );
    }

    // A Coach can mark a fee Paid directly — but it always re-queues
    // approvalStatus to Pending, since only Admin/Employee approval unlocks
    // the gate-pass QR.
    const isCoach = req.user && String(req.user.role).toUpperCase() === 'COACH';

    // Update StudentBatches record
    await record.update({
      ...(studentId && { studentId: parseInt(studentId) }),
      ...(batchId && { batchId: parseInt(batchId) }),
      ...(amountPaid !== undefined && { amountPaid }),
      ...(paymentMode !== undefined && { paymentMode }),
      ...(enrollmentDate && { enrollmentDate }),
      // Sent as '' when the coach clears the field → store NULL (no expiry).
      ...(validTill !== undefined && { validTill: validTill || null }),
      ...(paymentStatus && { paymentStatus }),
      ...(isCoach && { receivedBy: req.user.id, approvalStatus: 'Pending' }),
      ...(notes !== undefined && { notes }),
    });

    // Fetch updated record with all relations
    const updated = await StudentBatches.findByPk(record.id, {
      include: [
        {
          model: Student,
          as: 'student',
          include: [{ model: User, as: 'User', attributes: STUDENT_USER_ATTRS }],
        },
        {
          model: Batch,
          as: 'batch',
          attributes: ['id', 'name', 'fees', 'duration'],
          include: [{ model: Sport, as: 'sport', attributes: ['id', 'name'] }],
        },
      ],
    });

    return res.json({
      success: true,
      message: 'Fee record updated successfully',
      data: updated,
    });
  } catch (error) {
    console.error('❌ updateFeeRecord error:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * DELETE /api/fees/:id
 * Admin: delete a fee record
 */
exports.deleteFeeRecord = async (req, res) => {
  try {
    const record = await StudentBatches.findByPk(req.params.id);
    if (!record) {
      return res.status(404).json({ success: false, message: 'Fee record not found' });
    }

    // Complex admins may only delete fee records whose batch is in their complex.
    if (!(await assertFeeComplexAccess(req, res, record.id))) return;

    await record.destroy();
    return res.json({ success: true, message: 'Fee record deleted' });
  } catch (error) {
    console.error('❌ deleteFeeRecord error:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * GET /api/fees/retention-stats
 * Admin: get retention statistics by sport (with optional filters)
 * Retention Rate (%) = (Students Continued This Month ÷ Students Enrolled Last Month) × 100
 * Example: If 90 out of 120 students continued: Retention Rate = (90 ÷ 120) × 100 = 75%
 */
exports.getRetentionStats = async (req, res) => {
  try {
    const { sportId, month, batch, paymentStatus } = req.query;

    // Build where clause for StudentBatches based on filters
    const studentBatchWhere = {};

    // Month filter
    if (month) {
      const monthNum = parseInt(month);
      studentBatchWhere.enrollmentDate = {
        [Op.and]: [
          { [Op.gte]: new Date(new Date().getFullYear(), monthNum - 1, 1) },
          { [Op.lt]: new Date(new Date().getFullYear(), monthNum, 1) }
        ]
      };
    }

    // Payment status filter (for total count)
    if (paymentStatus) {
      studentBatchWhere.paymentStatus = paymentStatus;
    }

    // Get sports to calculate retention for
    const sportsWhere = {};
    if (sportId) {
      sportsWhere.id = sportId;
    }

    const sports = await Sport.findAll({
      where: sportsWhere,
      attributes: ['id', 'name']
    });

    const retentionStats = {};

    // Calculate date ranges for retention calculation
    const currentDate = new Date();
    const currentYear = currentDate.getFullYear();
    const currentMonth = currentDate.getMonth(); // 0-indexed

    // Last month date range
    const lastMonthStart = new Date(currentYear, currentMonth - 1, 1);
    const lastMonthEnd = new Date(currentYear, currentMonth, 0);

    // This month date range
    const thisMonthStart = new Date(currentYear, currentMonth, 1);

    // Per-complex admin scoping: only count batches in the admin's complex.
    // A coach's retention is likewise computed from their own batches only.
    const complexId = resolveComplexId(req);
    const coachId = await resolveCoachId(req);

    for (const sport of sports) {
      // Get all batches for this sport
      const batchWhere = { sportId: sport.id };

      // Batch name filter
      if (batch) {
        batchWhere.name = { [Op.iLike]: `%${batch}%` };
      }

      if (complexId != null) {
        batchWhere.sportComplexId = complexId;
      }
      if (coachId != null) {
        batchWhere.coachId = coachId;
      }

      const batches = await Batch.findAll({
        where: batchWhere,
        attributes: ['id']
      });

      const batchIds = batches.map(b => b.id);

      if (batchIds.length === 0) {
        continue;
      }

      // Students enrolled LAST MONTH in this sport
      const lastMonthWhere = {
        batchId: { [Op.in]: batchIds },
        enrollmentDate: {
          [Op.between]: [lastMonthStart, lastMonthEnd]
        }
      };

      const studentsEnrolledLastMonth = await StudentBatches.count({
        where: lastMonthWhere,
        distinct: true,
        col: 'studentId'
      });

      // Students who continued THIS MONTH (still active from last month's enrollment)
      const continuedWhere = {
        batchId: { [Op.in]: batchIds },
        enrollmentDate: {
          [Op.between]: [lastMonthStart, lastMonthEnd]
        },
        status: 'Active',
        paymentStatus: { [Op.in]: ['Paid', 'Partial'] }
      };

      const studentsContinuedThisMonth = await StudentBatches.count({
        where: continuedWhere,
        distinct: true,
        col: 'studentId'
      });

      // Calculate retention rate: (Students Continued This Month ÷ Students Enrolled Last Month) × 100
      if (studentsEnrolledLastMonth > 0) {
        const retentionRate = Math.round((studentsContinuedThisMonth / studentsEnrolledLastMonth) * 100);

        retentionStats[sport.name] = {
          enrolledLastMonth: studentsEnrolledLastMonth,
          continuedThisMonth: studentsContinuedThisMonth,
          retentionRate: retentionRate
        };
      }
    }

    return res.json({
      success: true,
      data: retentionStats
    });
  } catch (error) {
    console.error('❌ getRetentionStats error:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};
