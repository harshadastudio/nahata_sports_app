'use strict';

const { User, Student, Notification, sequelize } = require('../models');
const bcrypt = require('bcrypt');
const path = require('path');
const fs = require('fs');
const emailService = require('../services/emailService');
const { resolveComplexId, isComplexAdmin, assertComplexAccess } = require('../middleware/complexScope');
const { validatePhoneNumberOrThrow } = require('../utils/phoneValidation');

/**
 * Whether the given student (by Student id) is enrolled in at least one batch
 * belonging to `complexId`. Used to gate per-record access for a complex admin.
 * The complex is reached through StudentBatches → Batch.sportComplexId.
 */
async function studentInComplex(studentId, complexId) {
  const { Student, StudentBatches, Batch } = require('../models');
  // Direct home complex (set at registration / backfilled) takes precedence.
  const student = await Student.findByPk(studentId, { attributes: ['sportComplexId'] });
  if (student && Number(student.sportComplexId) === Number(complexId)) return true;
  // Fall back to batch enrollment in the complex.
  const count = await StudentBatches.count({
    where: { studentId },
    include: [
      {
        model: Batch,
        as: 'batch',
        attributes: [],
        where: { sportComplexId: complexId },
        required: true,
      },
    ],
  });
  return count > 0;
}

/**
 * Register a new student (public endpoint).
 * Creates a User record (role=USER) + a linked Student record in one transaction.
 */
const registerStudent = async (req, res) => {
  try {
    const {
      name,
      email,
      password,
      phone_number,
      dob,
      gender,
      blood_group,
      // Student-specific
      parentName,
      parentPhone,
      parentEmail,
      schoolName,
      grade,
      medicalConditions,
      allergies,
      sportComplexId,
    } = req.body;

    // ── Basic validation ──────────────────────────────────────────────────────
    if (!name || !email || !password || !phone_number) {
      return res.status(400).json({
        success: false,
        message: 'Name, email, WhatsApp number, and password are required.',
      });
    }

    if (password.length < 6) {
      return res.status(400).json({
        success: false,
        message: 'Password must be at least 6 characters.',
      });
    }

    // ── WhatsApp number: validate + normalize (10-digit) ──────────────────────
    let cleanedPhone;
    try {
      cleanedPhone = validatePhoneNumberOrThrow(phone_number, 'WhatsApp number');
    } catch (phoneErr) {
      return res.status(400).json({ success: false, message: phoneErr.message });
    }

    // ── Check duplicate email ─────────────────────────────────────────────────
    const existing = await User.findOne({ where: { email } });
    if (existing) {
      return res.status(409).json({
        success: false,
        message: 'An account with this email already exists.',
      });
    }

    // ── Check duplicate WhatsApp number (it doubles as a login identifier) ─────
    const phoneTaken = await User.findOne({ where: { phone_number: cleanedPhone } });
    if (phoneTaken) {
      return res.status(409).json({
        success: false,
        message: 'This WhatsApp number is already registered. Please log in instead.',
      });
    }

    // ── Handle photo upload (Cloudinary) ──────────────────────────────────────
    let avatarPath = null;
    if (req.cloudinaryResult) {
      avatarPath = req.cloudinaryResult.url;
    }

    // ── Create User + Student atomically ──────────────────────────────────────
    // Both rows must succeed together. Without a transaction, a failure on the
    // Student insert leaves an orphaned User — the email is then "taken" so the
    // person can never re-register, yet has no student profile.
    const complexId = sportComplexId ? Number(sportComplexId) : null;
    const { user, student } = await sequelize.transaction(async (tx) => {
      const user = await User.create({
        name,
        email,
        password,          // hashed by model beforeCreate hook
        phone_number: cleanedPhone,   // WhatsApp number (required) — passes go here
        role: 'USER',
        status: 'Active',
        join_date: new Date(),
        dob: dob || null,
        gender: gender || null,
        blood_group: blood_group || null,
        avatar: avatarPath,
      }, { transaction: tx });

      const student = await Student.create({
        userId: user.id,
        sportComplexId: complexId, // home complex chosen at registration
        parentName: parentName || null,
        parentPhone: parentPhone || null,
        parentEmail: parentEmail || null,
        schoolName: schoolName || null,
        grade: grade || null,
        medicalConditions: medicalConditions || null,
        allergies: allergies || null,
        enrollmentDate: new Date(),
        status: 'Active',
      }, { transaction: tx });

      return { user, student };
    });

    // ── Send welcome email (non-blocking) ────────────────────────────────────
    emailService.sendWelcomeEmail({ to: user.email, name: user.name })
      .catch((err) => console.error('❌ Welcome email error:', err.message));

    // ── Response (never return password) ─────────────────────────────────────
    return res.status(201).json({
      success: true,
      message: 'Student registered successfully.',
      data: {
        user: {
          id: user.id,
          name: user.name,
          email: user.email,
          phone_number: user.phone_number,
          dob: user.dob,
          gender: user.gender,
          blood_group: user.blood_group,
          avatar: user.avatar,
          role: user.role,
          status: user.status,
          join_date: user.join_date,
        },
        student: {
          id: student.id,
          parentName: student.parentName,
          parentPhone: student.parentPhone,
          parentEmail: student.parentEmail,
          schoolName: student.schoolName,
          grade: student.grade,
          enrollmentDate: student.enrollmentDate,
          status: student.status,
        },
      },
    });
  } catch (error) {
    console.error('❌ registerStudent error:', error);
    return res.status(500).json({
      success: false,
      message: error.message || 'Internal server error.',
    });
  }
};

/**
 * GET /api/students/coach/my-students  — Coach: get students enrolled in their programs.
 */
const getCoachStudents = async (req, res) => {
  try {
    const { Coach, Batch, StudentBatches } = require('../models');
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const offset = (page - 1) * limit;

    // Find coach by logged-in user's email
    const coach = await Coach.findOne({
      where: { email: req.user.email }
    });

    // If no coach profile is linked to this account, return empty results gracefully
    if (!coach) {
      console.warn(`⚠️ No coach profile found for email: ${req.user.email}. Returning empty students list.`);
      return res.json({
        success: true,
        data: {
          students: [],
          total: 0,
          page,
          totalPages: 0,
        },
      });
    }

    console.log(`🔵 Coach ${coach.name} (ID: ${coach.id}) fetching students`);

    // Find all batches assigned to this coach
    const batches = await Batch.findAll({
      where: { coachId: coach.id },
      attributes: ['id', 'name']
    });

    if (batches.length === 0) {
      console.log('⚠️  Coach has no batches assigned');
      return res.json({
        success: true,
        data: {
          students: [],
          total: 0,
          page,
          totalPages: 0,
        },
      });
    }

    const batchIds = batches.map(b => b.id);
    console.log(`✅ Coach has ${batches.length} batches:`, batchIds);

    // Find all student enrollments in these batches
    const { count, rows: enrollments } = await StudentBatches.findAndCountAll({
      where: { batchId: batchIds },
      include: [
        {
          model: Student,
          as: 'student',
          include: [
            {
              model: User,
              as: 'User',
              attributes: [
                'id', 'name', 'email', 'phone_number',
                'dob', 'gender', 'blood_group', 'avatar',
                'status', 'join_date',
              ],
            },
          ],
        },
        {
          model: Batch,
          as: 'batch',
          attributes: ['id', 'name'],
        },
      ],
      limit,
      offset,
      order: [['createdAt', 'DESC']],
    });

    // Transform to match expected format (enrolledProgram kept for UI compatibility)
    const students = enrollments.map(enrollment => ({
      ...enrollment.student.toJSON(),
      enrolledProgram: enrollment.batch,
      enrollmentStatus: enrollment.status,
      enrollmentDate: enrollment.enrollmentDate,
    }));

    console.log(`✅ Found ${count} student enrollments for coach`);

    return res.json({
      success: true,
      data: {
        students,
        total: count,
        page,
        totalPages: Math.ceil(count / limit),
      },
    });
  } catch (error) {
    console.error('❌ getCoachStudents error:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * GET /api/students  — Admin: list all students with user info.
 */
const getAllStudents = async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const offset = (page - 1) * limit;

    // Per-complex admin scoping: restrict to students whose home complex matches.
    // Each student now carries a direct sportComplexId (set at registration, and
    // backfilled from batch enrollments), so we scope by the column. null (super
    // admin / coach) → no restriction, no behavior change.
    const complexId = resolveComplexId(req);
    const where = complexId != null ? { sportComplexId: complexId } : {};

    const { count, rows } = await Student.findAndCountAll({
      where,
      include: [
        {
          model: User, as: 'User',
          attributes: [
            'id', 'name', 'email', 'phone_number',
            'dob', 'gender', 'blood_group', 'avatar',
            'status', 'join_date',
          ],
        },
      ],
      limit,
      offset,
      order: [['createdAt', 'DESC']],
      distinct: true,
    });

    return res.json({
      success: true,
      data: {
        students: rows,
        total: count,
        page,
        totalPages: Math.ceil(count / limit),
      },
    });
  } catch (error) {
    console.error('❌ getAllStudents error:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * GET /api/students/me  — Logged-in user: get own student profile.
 */
const getMyStudentProfile = async (req, res) => {
  try {
    const student = await Student.findOne({
      where: { userId: req.user.id },
      include: [
        {
          model: User, as: 'User',
          attributes: [
            'id', 'name', 'email', 'phone_number',
            'dob', 'gender', 'blood_group', 'avatar',
            'status', 'join_date',
          ],
        },
      ],
    });

    if (!student) {
      return res.status(404).json({
        success: false,
        message: 'Student profile not found.',
      });
    }

    return res.json({ success: true, data: student });
  } catch (error) {
    console.error('❌ getMyStudentProfile error:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * GET /api/students/me/enrollments — Logged-in student: own batch enrollment
 * history (every StudentBatches row), newest first.
 *
 * `isActive` is derived, not stored: an enrollment counts as active only while
 * its row status is 'Active' AND it has not expired yet. validTill is the
 * per-student date the coach entered on the fee record, falling back to the
 * batch end date; with neither the enrollment never expires. Everything else
 * is previous history.
 */
const getMyEnrollments = async (req, res) => {
  try {
    const { StudentBatches, Batch, Sport, Coach, SportComplex } = require('../models');

    const student = await Student.findOne({
      where: { userId: req.user.id },
      attributes: ['id'],
    });

    // No student profile → no enrollments (not an error).
    if (!student) {
      return res.json({ success: true, data: [] });
    }

    const rows = await StudentBatches.findAll({
      where: { studentId: student.id },
      include: [
        {
          model: Batch,
          as: 'batch',
          attributes: ['id', 'name', 'startDate', 'endDate', 'schedule', 'days', 'startTime', 'endTime', 'fees'],
          include: [
            { model: Sport, as: 'sport', attributes: ['id', 'name'] },
            { model: Coach, as: 'coach', attributes: ['id', 'name'] },
            { model: SportComplex, as: 'sportComplex', attributes: ['id', 'name'] },
          ],
        },
      ],
      order: [['enrollmentDate', 'DESC'], ['createdAt', 'DESC']],
    });

    // Compare DATEONLY strings (YYYY-MM-DD) so this is timezone-independent.
    const today = new Date().toISOString().slice(0, 10);

    const data = rows.map((r) => {
      // Per-student validity entered by the coach on the fee record wins; the
      // batch end date is only the fallback when the coach left it empty.
      const validTill = r.validTill ?? r.batch?.endDate ?? null;
      const notExpired = !validTill || String(validTill) >= today;
      return {
        id: r.id,
        batchId: r.batchId,
        batchName: r.batch?.name ?? '—',
        sportName: r.batch?.sport?.name ?? '—',
        coachName: r.batch?.coach?.name ?? '—',
        complexName: r.batch?.sportComplex?.name ?? null,
        enrollmentDate: r.enrollmentDate,
        validTill,
        status: r.status,
        approvalStatus: r.approvalStatus,
        paymentStatus: r.paymentStatus,
        isActive: r.status === 'Active' && notExpired,
      };
    });

    return res.json({ success: true, data });
  } catch (error) {
    console.error('❌ getMyEnrollments error:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * GET /api/students/:id  — Admin: get single student by student ID.
 */
const getStudentById = async (req, res) => {
  try {
    const student = await Student.findByPk(req.params.id, {
      include: [
        {
          model: User, as: 'User',
          attributes: [
            'id', 'name', 'email', 'phone_number',
            'dob', 'gender', 'blood_group', 'avatar',
            'status', 'join_date',
          ],
        },
      ],
    });

    if (!student) {
      return res.status(404).json({ success: false, message: 'Student not found.' });
    }

    // Complex admins may only view students enrolled in a batch of their complex.
    if (isComplexAdmin(req)) {
      const allowed = await studentInComplex(student.id, resolveComplexId(req));
      if (!assertComplexAccess(req, res, allowed ? resolveComplexId(req) : -1)) return;
    }

    return res.json({ success: true, data: student });
  } catch (error) {
    console.error('❌ getStudentById error:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

// exports moved to bottom of file

/**
 * POST /api/students/:id/feedback  — Admin sends feedback to a student.
 * :id is the Student table ID (not userId).
 */
const sendFeedbackToStudent = async (req, res) => {
  try {
    const { title, message } = req.body;

    if (!message || !message.trim()) {
      return res.status(400).json({ success: false, message: 'Message is required.' });
    }

    // Find the student to get their userId
    const student = await Student.findByPk(req.params.id, {
      include: [{ model: User, as: 'User', attributes: ['id', 'name', 'email'] }],
    });

    if (!student) {
      return res.status(404).json({ success: false, message: 'Student not found.' });
    }

    // Complex admins may only send feedback to students in a batch of their complex.
    if (isComplexAdmin(req)) {
      const allowed = await studentInComplex(student.id, resolveComplexId(req));
      if (!assertComplexAccess(req, res, allowed ? resolveComplexId(req) : -1)) return;
    }

    // Create a Notification for the student's userId
    const notification = await Notification.create({
      userId: student.userId,
      title: title || 'Feedback from Admin',
      message: message.trim(),
      type: 'Feedback',
      isRead: false,
      sentAt: new Date(),
    });

    return res.status(201).json({
      success: true,
      message: `Feedback sent to ${student.User.name}.`,
      data: notification,
    });
  } catch (error) {
    console.error('❌ sendFeedbackToStudent error:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * GET /api/students/feedback  — Logged-in student gets their received feedback.
 */
const getMyFeedback = async (req, res) => {
  try {
    const notifications = await Notification.findAll({
      where: { userId: req.user.id, type: 'Feedback' },
      order: [['createdAt', 'DESC']],
    });

    return res.json({ success: true, data: notifications });
  } catch (error) {
    console.error('❌ getMyFeedback error:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * POST /api/students/feedback/read  — Mark all feedback notifications as read.
 */
const markFeedbackRead = async (req, res) => {
  try {
    await Notification.update(
      { isRead: true },
      { where: { userId: req.user.id, type: 'Feedback', isRead: false } }
    );
    return res.json({ success: true, message: 'All feedback marked as read.' });
  } catch (error) {
    console.error('❌ markFeedbackRead error:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

module.exports = {
  registerStudent,
  getAllStudents,
  getCoachStudents,
  getMyStudentProfile,
  getMyEnrollments,
  getStudentById,
  sendFeedbackToStudent,
  getMyFeedback,
  markFeedbackRead,
};


