const { Coach, Student, Attendance, Performance, Batch, BatchCoaches, StudentBatches, User, Sport, Court, CoachingEnquiry } = require('../models');
const { Op } = require('sequelize');
const sequelize = require('../models').sequelize;

/**
 * Get Coach Dashboard Statistics
 * Returns real-time stats for the coach dashboard
 */
exports.getDashboardStats = async (req, res) => {
  try {
    const userEmail = req.user.email;

    // Find coach by email
    const coach = await Coach.findOne({
      where: { email: userEmail }
    });

    if (!coach) {
      return res.status(404).json({
        success: false,
        message: 'Coach profile not found. Please contact admin to link your account.'
      });
    }

    // Get today's date
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);

    // Get all batches for this coach
    const coachBatches = await Batch.findAll({
      where: { coachId: coach.id },
      attributes: ['id']
    });
    const batchIds = coachBatches.map(b => b.id);

    // Count total students assigned to this coach (through batches)
    const totalStudents = batchIds.length > 0 ? await StudentBatches.count({
      where: { batchId: { [Op.in]: batchIds } },
      distinct: true,
      col: 'studentId'
    }) : 0;

    // Count students present today (using batch relationship)
    const presentToday = batchIds.length > 0 ? await Attendance.count({
      where: {
        batchId: { [Op.in]: batchIds },
        date: {
          [Op.gte]: today,
          [Op.lt]: tomorrow
        },
        status: 'Present'
      }
    }) : 0;

    // Count sessions/batches today (batches that are active)
    const sessionsToday = await Batch.count({
      where: {
        coachId: coach.id,
        status: 'Active'
      }
    });

    // Average performance — only across THIS coach's own students (Performance has
    // no coachId), otherwise the figure reflects every coach's records.
    let coachStudentIds = [];
    if (batchIds.length > 0) {
      const sbs = await StudentBatches.findAll({
        where: { batchId: { [Op.in]: batchIds } },
        attributes: ['studentId'],
        group: ['studentId'],
        raw: true,
      });
      coachStudentIds = sbs.map((s) => s.studentId);
    }

    const performanceResult = coachStudentIds.length > 0 ? await Performance.findOne({
      attributes: [
        [sequelize.fn('AVG', sequelize.col('fitnessScore')), 'avgScore']
      ],
      where: { studentId: { [Op.in]: coachStudentIds } },
      raw: true
    }) : null;

    const avgPerformance = performanceResult?.avgScore
      ? Math.round(parseFloat(performanceResult.avgScore) * 10) / 10
      : 0;

    // Count total batches
    const totalBatches = await Batch.count({
      where: { coachId: coach.id }
    });

    // Count active enquiries
    const activeEnquiries = await CoachingEnquiry.count({
      where: {
        coachId: coach.id,
        status: {
          [Op.in]: ['Pending', 'Reviewed', 'Contacted']
        }
      }
    });

    res.status(200).json({
      success: true,
      data: {
        totalStudents,
        presentToday,
        sessionsToday,
        avgPerformance,
        totalBatches,
        activeEnquiries
      }
    });
  } catch (error) {
    console.error('Error fetching coach dashboard stats:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch dashboard statistics',
      error: error.message
    });
  }
};

/**
 * Get Today's Schedule for Coach
 * Returns batches scheduled for today
 */
exports.getTodaySchedule = async (req, res) => {
  try {
    const userEmail = req.user.email;

    const coach = await Coach.findOne({
      where: { email: userEmail }
    });

    if (!coach) {
      return res.status(404).json({
        success: false,
        message: 'Coach profile not found'
      });
    }

    // Get today's batches
    const batches = await Batch.findAll({
      where: {
        coachId: coach.id,
        status: 'Active'
      },
      include: [
        {
          model: Sport,
          as: 'sport',
          attributes: ['id', 'name']
        }
      ],
      order: [['startDate', 'ASC']]
    });

    // Format schedule data
    const schedule = batches.map(batch => ({
      id: batch.id,
      batchName: batch.name,
      startTime: batch.schedule || '10:00',
      endTime: batch.schedule || '11:30',
      court: 'TBD',
      status: batch.status,
      studentCount: batch.currentStudents || 0,
      sport: batch.sport,
      program: null
    }));

    res.status(200).json({
      success: true,
      data: schedule
    });
  } catch (error) {
    console.error('Error fetching today\'s schedule:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch today\'s schedule',
      error: error.message
    });
  }
};

/**
 * Get Top Performing Students
 * Returns top 5 students based on performance scores
 */
exports.getTopPerformers = async (req, res) => {
  try {
    const userEmail = req.user.email;

    const coach = await Coach.findOne({
      where: { email: userEmail }
    });

    if (!coach) {
      return res.status(404).json({
        success: false,
        message: 'Coach profile not found'
      });
    }

    // Scope to THIS coach's students (Performance has no coachId) — otherwise the
    // top performers come from every coach's records, not the logged-in coach's.
    const coachBatches = await Batch.findAll({ where: { coachId: coach.id }, attributes: ['id'] });
    const batchIds = coachBatches.map((b) => b.id);
    let coachStudentIds = [];
    if (batchIds.length > 0) {
      const sbs = await StudentBatches.findAll({
        where: { batchId: { [Op.in]: batchIds } },
        attributes: ['studentId'],
        group: ['studentId'],
        raw: true,
      });
      coachStudentIds = sbs.map((s) => s.studentId);
    }

    if (coachStudentIds.length === 0) {
      return res.status(200).json({ success: true, data: [] });
    }

    // Get latest performance for each student (using fitnessScore)
    const topPerformers = await Performance.findAll({
      where: { studentId: { [Op.in]: coachStudentIds } },
      include: [
        {
          model: Student,
          as: 'student',
          include: [{
            model: User,
            as: 'User',
            attributes: ['id', 'name', 'email']
          }]
        },
        {
          model: Sport,
          as: 'sport',
          attributes: ['id', 'name']
        }
      ],
      order: [['fitnessScore', 'DESC']],
      limit: 5
    });

    const performers = topPerformers.map(perf => ({
      id: perf.student?.id,
      name: perf.student?.User?.name || 'Unknown',
      performance: perf.fitnessScore || 0,
      detail: perf.coachNotes || `${perf.sport?.name || 'General'} Performance`,
      sport: perf.sport?.name || 'General',
      color: perf.fitnessScore >= 90 ? 'green' : perf.fitnessScore >= 80 ? 'blue' : 'orange'
    }));

    res.status(200).json({
      success: true,
      data: performers
    });
  } catch (error) {
    console.error('Error fetching top performers:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch top performers',
      error: error.message
    });
  }
};

/**
 * Get My Students
 * Returns all students assigned to this coach
 */
exports.getMyStudents = async (req, res) => {
  try {
    const userEmail = req.user.email;
    const { page = 1, limit = 10, search = '', status = '' } = req.query;

    const coach = await Coach.findOne({
      where: { email: userEmail }
    });

    if (!coach) {
      return res.status(404).json({
        success: false,
        message: 'Coach profile not found'
      });
    }

    console.log(`🔵 Fetching students for coach: ${coach.name} (ID: ${coach.id}, Email: ${userEmail})`);

    // Get all batches assigned to this coach (offerings + attendance source)
    const coachBatches = await Batch.findAll({
      where: { coachId: coach.id },
      attributes: ['id', 'name']
    });

    if (coachBatches.length === 0) {
      console.log('⚠️  Coach has no batches assigned');
      return res.json({
        success: true,
        data: {
          students: [],
          total: 0,
          page: parseInt(page),
          limit: parseInt(limit),
          totalPages: 0
        }
      });
    }

    const batchIds = coachBatches.map(b => b.id);
    console.log(`✅ Coach has ${batchIds.length} batches:`, batchIds);

    // Build where clause for StudentBatches
    const where = {
      batchId: { [Op.in]: batchIds }
    };
    if (status) {
      where.status = status;
    }

    // Build user where clause for search
    const userWhere = search ? {
      name: { [Op.like]: `%${search}%` }
    } : {};

    // Get student batch enrollments
    const { count, rows: studentBatches } = await StudentBatches.findAndCountAll({
      where,
      include: [
        {
          model: Student,
          as: 'student',
          include: [{
            model: User,
            as: 'User',
            attributes: ['id', 'name', 'email', 'phone_number'],
            where: userWhere,
            required: true
          }],
          required: true
        },
        {
          model: Batch,
          as: 'batch',
          attributes: ['id', 'name']
        }
      ],
      limit: parseInt(limit),
      offset: (parseInt(page) - 1) * parseInt(limit),
      order: [['enrollmentDate', 'DESC']],
      distinct: true
    });

    console.log(`✅ Found ${count} student enrollments`);

    // Get all student IDs for bulk queries
    const studentIds = studentBatches.map(sp => sp.studentId);

    // Bulk fetch attendance stats for all students
    const attendanceStats = await Attendance.findAll({
      where: {
        studentId: { [Op.in]: studentIds },
        batchId: { [Op.in]: batchIds }
      },
      attributes: [
        'studentId',
        [sequelize.fn('COUNT', sequelize.col('id')), 'total'],
        [sequelize.fn('SUM', sequelize.literal("CASE WHEN status = 'Present' THEN 1 ELSE 0 END")), 'present']
      ],
      group: ['studentId'],
      raw: true
    });

    // Create a map for quick lookup
    const attendanceMap = {};
    attendanceStats.forEach(stat => {
      const total = parseInt(stat.total) || 0;
      const present = parseInt(stat.present) || 0;
      attendanceMap[stat.studentId] = total > 0 ? Math.round((present / total) * 100) : 0;
    });

    // Bulk fetch latest performance for all students
    const performances = await Performance.findAll({
      where: {
        studentId: { [Op.in]: studentIds }
      },
      attributes: [
        'studentId',
        'fitnessScore',
        'assessmentDate'
      ],
      order: [['assessmentDate', 'DESC']],
      raw: true
    });

    // Create a map for latest performance per student
    const performanceMap = {};
    performances.forEach(perf => {
      if (!performanceMap[perf.studentId]) {
        performanceMap[perf.studentId] = perf.fitnessScore;
      }
    });

    // Map the data without additional queries
    const studentsWithStats = studentBatches.map(sp => {
      const attendancePercentage = attendanceMap[sp.studentId] || 0;
      const fitnessScore = performanceMap[sp.studentId];

      return {
        id: sp.student?.id,
        name: sp.student?.User?.name || 'Unknown',
        email: sp.student?.User?.email || '',
        phone: sp.student?.User?.phone_number || '',
        program: sp.batch?.name || '',
        batch: sp.batch?.name || 'Not Assigned',
        enrollmentDate: sp.enrollmentDate,
        status: sp.status,
        attendance: `${attendancePercentage}%`,
        performance: fitnessScore ? `${fitnessScore}%` : 'N/A'
      };
    });

    res.status(200).json({
      success: true,
      data: {
        students: studentsWithStats,
        total: count,
        page: parseInt(page),
        limit: parseInt(limit),
        totalPages: Math.ceil(count / parseInt(limit))
      }
    });
  } catch (error) {
    console.error('Error fetching my students:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch students',
      error: error.message
    });
  }
};

/**
 * Get Attendance Records
 * Returns attendance records for coach's students
 */
exports.getAttendanceRecords = async (req, res) => {
  try {
    const userEmail = req.user.email;
    const { page = 1, limit = 10, date = '', status = '', batchId = '' } = req.query;

    const coach = await Coach.findOne({
      where: { email: userEmail }
    });

    if (!coach) {
      return res.status(404).json({
        success: false,
        message: 'Coach profile not found'
      });
    }

    // Get all batches for this coach
    const coachBatches = await Batch.findAll({
      where: { coachId: coach.id },
      attributes: ['id']
    });

    const batchIds = coachBatches.map(b => b.id);

    if (batchIds.length === 0) {
      return res.status(200).json({
        success: true,
        data: {
          records: [],
          total: 0,
          page: parseInt(page),
          limit: parseInt(limit),
          totalPages: 0
        }
      });
    }

    // Build where clause for attendance
    const where = { 
      batchId: { [Op.in]: batchIds }
    };
    
    if (date) {
      const selectedDate = new Date(date);
      selectedDate.setHours(0, 0, 0, 0);
      const nextDay = new Date(selectedDate);
      nextDay.setDate(nextDay.getDate() + 1);
      
      where.date = {
        [Op.gte]: selectedDate,
        [Op.lt]: nextDay
      };
    }
    
    if (status) {
      where.status = status;
    }
    
    if (batchId) {
      where.batchId = parseInt(batchId);
    }

    const { count, rows: attendance } = await Attendance.findAndCountAll({
      where,
      include: [
        {
          model: Student,
          as: 'student',
          include: [{
            model: User,
            as: 'User',
            attributes: ['id', 'name', 'email']
          }]
        },
        {
          model: Batch,
          as: 'batch',
          attributes: ['id', 'name']
        }
      ],
      limit: parseInt(limit),
      offset: (parseInt(page) - 1) * parseInt(limit),
      order: [['date', 'DESC'], ['createdAt', 'DESC']]
    });

    const records = attendance.map(att => ({
      id: att.id,
      date: att.date,
      studentName: att.student?.User?.name || 'Unknown',
      studentEmail: att.student?.User?.email || '',
      batchName: att.batch?.name || 'N/A',
      status: att.status,
      markedBy: coach.name,
      markedAt: att.createdAt
    }));

    res.status(200).json({
      success: true,
      data: {
        records,
        total: count,
        page: parseInt(page),
        limit: parseInt(limit),
        totalPages: Math.ceil(count / parseInt(limit))
      }
    });
  } catch (error) {
    console.error('Error fetching attendance records:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch attendance records',
      error: error.message
    });
  }
};

/**
 * Get Student Progress/Performance
 * Returns performance data for coach's students
 */
exports.getStudentProgress = async (req, res) => {
  try {
    const userEmail = req.user.email;
    const { page = 1, limit = 10, studentId = '', sportId = '' } = req.query;

    const coach = await Coach.findOne({
      where: { email: userEmail }
    });

    if (!coach) {
      return res.status(404).json({
        success: false,
        message: 'Coach profile not found'
      });
    }

    // Performance has no coachId, so scope by THIS coach's students (the students
    // enrolled in the coach's batches). Without this, a coach saw every coach's
    // performance records.
    const coachBatches = await Batch.findAll({
      where: { coachId: coach.id },
      attributes: ['id'],
    });
    const batchIds = coachBatches.map((b) => b.id);

    let coachStudentIds = [];
    if (batchIds.length > 0) {
      const sbs = await StudentBatches.findAll({
        where: { batchId: { [Op.in]: batchIds } },
        attributes: ['studentId'],
        group: ['studentId'],
        raw: true,
      });
      coachStudentIds = sbs.map((s) => s.studentId);
    }

    // No students → nothing to show.
    if (coachStudentIds.length === 0) {
      return res.status(200).json({
        success: true,
        data: { progress: [], total: 0, page: parseInt(page), limit: parseInt(limit), totalPages: 0 },
      });
    }

    // Build where clause, always restricted to the coach's own students.
    const where = { studentId: { [Op.in]: coachStudentIds } };

    if (studentId) {
      const sid = parseInt(studentId);
      // A student outside the coach's roster yields no rows.
      if (!coachStudentIds.includes(sid)) {
        return res.status(200).json({
          success: true,
          data: { progress: [], total: 0, page: parseInt(page), limit: parseInt(limit), totalPages: 0 },
        });
      }
      where.studentId = sid;
    }

    if (sportId) {
      where.sportId = parseInt(sportId);
    }

    const { count, rows: performances } = await Performance.findAndCountAll({
      where,
      include: [
        {
          model: Student,
          as: 'student',
          include: [{
            model: User,
            as: 'User',
            attributes: ['id', 'name', 'email']
          }]
        },
        {
          model: Sport,
          as: 'sport',
          attributes: ['id', 'name']
        }
      ],
      limit: parseInt(limit),
      offset: (parseInt(page) - 1) * parseInt(limit),
      order: [['assessmentDate', 'DESC']]
    });

    // Get all student IDs and sport IDs for bulk queries
    const studentIds = [...new Set(performances.map(p => p.studentId))];
    const sportIds = [...new Set(performances.map(p => p.sportId))];

    // Bulk fetch all previous performances. Order by (date, id) DESC so that
    // multiple assessments on the SAME day still have a well-defined order — the
    // id (creation order) breaks the tie, otherwise same-day records show no
    // improvement at all.
    const allPreviousPerfs = await Performance.findAll({
      where: {
        studentId: { [Op.in]: studentIds },
        sportId: { [Op.in]: sportIds }
      },
      attributes: ['id', 'studentId', 'sportId', 'assessmentDate', 'fitnessScore'],
      order: [['assessmentDate', 'DESC'], ['id', 'DESC']],
      raw: true
    });

    // Create a map for previous performances
    const previousPerfMap = {};
    allPreviousPerfs.forEach(perf => {
      const key = `${perf.studentId}-${perf.sportId}`;
      if (!previousPerfMap[key]) {
        previousPerfMap[key] = [];
      }
      previousPerfMap[key].push(perf);
    });

    // Bulk fetch student batch enrollments
    const studentBatches = await StudentBatches.findAll({
      where: {
        studentId: { [Op.in]: studentIds },
        status: 'Active'
      },
      include: [{
        model: Batch,
        as: 'batch',
        attributes: ['id', 'name']
      }],
      order: [['enrollmentDate', 'DESC']],
      raw: true
    });

    // Create a map for student batches (offering name)
    const programMap = {};
    studentBatches.forEach(sp => {
      if (!programMap[sp.studentId]) {
        programMap[sp.studentId] = sp['batch.name'];
      }
    });

    // Map the data without additional queries
    const progressData = performances.map(perf => {
      const key = `${perf.studentId}-${perf.sportId}`;
      const previousPerfs = previousPerfMap[key] || [];
      
      // The "previous" assessment is the most recent one strictly before this
      // record by (assessmentDate, id). Using id as the tiebreaker means two
      // assessments recorded on the same day still compute an improvement.
      const curDate = String(perf.assessmentDate);
      const previousPerf = previousPerfs.find((p) => {
        const pDate = String(p.assessmentDate);
        return pDate < curDate || (pDate === curDate && p.id < perf.id);
      });

      const improvement = previousPerf 
        ? Math.round((perf.fitnessScore - previousPerf.fitnessScore) * 10) / 10
        : 0;

      return {
        id: perf.id,
        studentId: perf.studentId,
        sportId: perf.sportId,
        studentName: perf.student?.User?.name || 'Unknown',
        sport: perf.sport?.name || 'General',
        program: programMap[perf.studentId] || 'N/A',
        currentScore: perf.fitnessScore || 0,
        skillLevel: perf.skillLevel || 'Beginner',
        previousScore: previousPerf ? previousPerf.fitnessScore : null,
        improvement: improvement > 0 ? `+${improvement}` : improvement < 0 ? `${improvement}` : '0',
        lastUpdated: perf.assessmentDate,
        notes: perf.coachNotes || ''
      };
    });

    res.status(200).json({
      success: true,
      data: {
        progress: progressData,
        total: count,
        page: parseInt(page),
        limit: parseInt(limit),
        totalPages: Math.ceil(count / parseInt(limit))
      }
    });
  } catch (error) {
    console.error('Error fetching student progress:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch student progress',
      error: error.message
    });
  }
};

/**
 * Record a new student progress / performance assessment (Coach).
 * Creates a Performance row for one of the coach's OWN students. Each call adds a
 * new dated assessment; "improvement" is then computed against the prior one.
 */
exports.recordStudentProgress = async (req, res) => {
  try {
    const userEmail = req.user.email;
    const coach = await Coach.findOne({ where: { email: userEmail } });
    if (!coach) {
      return res.status(404).json({ success: false, message: 'Coach profile not found' });
    }

    const {
      studentId,
      sportId,
      fitnessScore,
      skillLevel,
      coachNotes,
      improvementAreas,
      assessmentDate,
      nextAssessmentDate,
    } = req.body;

    // ── Validation ────────────────────────────────────────────────────────────
    if (!studentId || !sportId || fitnessScore === undefined || fitnessScore === null || fitnessScore === '') {
      return res.status(400).json({
        success: false,
        message: 'Student, sport and fitness score are required.',
      });
    }
    const score = Number(fitnessScore);
    if (Number.isNaN(score) || score < 0 || score > 100) {
      return res.status(400).json({ success: false, message: 'Fitness score must be between 0 and 100.' });
    }
    const validLevels = ['Beginner', 'Intermediate', 'Advanced', 'Expert'];
    if (skillLevel && !validLevels.includes(skillLevel)) {
      return res.status(400).json({ success: false, message: 'Invalid skill level.' });
    }

    // ── Security: the student must be enrolled in one of this coach's batches ──
    const coachBatches = await Batch.findAll({ where: { coachId: coach.id }, attributes: ['id'] });
    const batchIds = coachBatches.map((b) => b.id);
    const enrolled = batchIds.length > 0
      ? await StudentBatches.count({ where: { batchId: { [Op.in]: batchIds }, studentId: parseInt(studentId) } })
      : 0;
    if (!enrolled) {
      return res.status(403).json({
        success: false,
        message: 'You can only record progress for your own students.',
      });
    }

    const record = await Performance.create({
      studentId: parseInt(studentId),
      sportId: parseInt(sportId),
      fitnessScore: score,
      skillLevel: skillLevel || 'Beginner',
      coachNotes: coachNotes || null,
      improvementAreas: improvementAreas || null,
      assessmentDate: assessmentDate || new Date(),
      nextAssessmentDate: nextAssessmentDate || null,
    });

    return res.status(201).json({
      success: true,
      message: 'Progress recorded successfully.',
      data: record,
    });
  } catch (error) {
    console.error('Error recording student progress:', error);
    return res.status(500).json({ success: false, message: 'Failed to record progress', error: error.message });
  }
};

// Whether `studentId` is enrolled in one of this coach's batches.
async function studentBelongsToCoach(coachId, studentId) {
  const coachBatches = await Batch.findAll({ where: { coachId }, attributes: ['id'] });
  const batchIds = coachBatches.map((b) => b.id);
  if (batchIds.length === 0) return false;
  const n = await StudentBatches.count({ where: { batchId: { [Op.in]: batchIds }, studentId } });
  return n > 0;
}

/**
 * Update an existing progress/assessment (Coach, own students only).
 * PUT /api/coach/dashboard/performance/progress/:id
 */
exports.updateStudentProgress = async (req, res) => {
  try {
    const coach = await Coach.findOne({ where: { email: req.user.email } });
    if (!coach) return res.status(404).json({ success: false, message: 'Coach profile not found' });

    const record = await Performance.findByPk(req.params.id);
    if (!record) return res.status(404).json({ success: false, message: 'Progress record not found' });

    if (!(await studentBelongsToCoach(coach.id, record.studentId))) {
      return res.status(403).json({ success: false, message: 'You can only edit progress for your own students.' });
    }

    const { fitnessScore, skillLevel, coachNotes, improvementAreas, assessmentDate, sportId } = req.body;

    if (fitnessScore !== undefined && fitnessScore !== null && fitnessScore !== '') {
      const score = Number(fitnessScore);
      if (Number.isNaN(score) || score < 0 || score > 100) {
        return res.status(400).json({ success: false, message: 'Fitness score must be between 0 and 100.' });
      }
      record.fitnessScore = score;
    }
    if (skillLevel !== undefined) {
      const valid = ['Beginner', 'Intermediate', 'Advanced', 'Expert'];
      if (skillLevel && !valid.includes(skillLevel)) {
        return res.status(400).json({ success: false, message: 'Invalid skill level.' });
      }
      if (skillLevel) record.skillLevel = skillLevel;
    }
    if (coachNotes !== undefined) record.coachNotes = coachNotes || null;
    if (improvementAreas !== undefined) record.improvementAreas = improvementAreas || null;
    if (assessmentDate) record.assessmentDate = assessmentDate;
    if (sportId) record.sportId = parseInt(sportId);

    await record.save();
    return res.status(200).json({ success: true, message: 'Progress updated successfully.', data: record });
  } catch (error) {
    console.error('Error updating student progress:', error);
    return res.status(500).json({ success: false, message: 'Failed to update progress', error: error.message });
  }
};

/**
 * Delete a progress/assessment (Coach, own students only).
 * DELETE /api/coach/dashboard/performance/progress/:id
 */
exports.deleteStudentProgress = async (req, res) => {
  try {
    const coach = await Coach.findOne({ where: { email: req.user.email } });
    if (!coach) return res.status(404).json({ success: false, message: 'Coach profile not found' });

    const record = await Performance.findByPk(req.params.id);
    if (!record) return res.status(404).json({ success: false, message: 'Progress record not found' });

    if (!(await studentBelongsToCoach(coach.id, record.studentId))) {
      return res.status(403).json({ success: false, message: 'You can only delete progress for your own students.' });
    }

    await record.destroy();
    return res.status(200).json({ success: true, message: 'Progress deleted successfully.' });
  } catch (error) {
    console.error('Error deleting student progress:', error);
    return res.status(500).json({ success: false, message: 'Failed to delete progress', error: error.message });
  }
};

/**
 * Get My Batches/Schedule
 * Returns all batches assigned to this coach
 */
exports.getMyBatches = async (req, res) => {
  try {
    const userEmail = req.user.email;
    const { page = 1, limit = 10, status = '', sportId = '' } = req.query;

    const coach = await Coach.findOne({
      where: { email: userEmail }
    });

    if (!coach) {
      return res.status(404).json({
        success: false,
        message: 'Coach profile not found'
      });
    }

    console.log(`🔵 Fetching batches for coach: ${coach.name} (ID: ${coach.id})`);

    // Build where clause for batches - query directly on Batch table
    const batchWhere = { coachId: coach.id };
    if (status) {
      batchWhere.status = status;
    }
    if (sportId) {
      batchWhere.sportId = parseInt(sportId);
    }

    const { count, rows: batches } = await Batch.findAndCountAll({
      where: batchWhere,
      include: [
        {
          model: Sport,
          as: 'sport',
          attributes: ['id', 'name']
        }
      ],
      limit: parseInt(limit),
      offset: (parseInt(page) - 1) * parseInt(limit),
      order: [['startDate', 'DESC']]
    });

    console.log(`✅ Found ${count} batches`);

    const batchesData = batches.map(batch => {
      return {
        id: batch.id,
        name: batch.name,
        program: batch.name,
        sport: batch.sport?.name || 'N/A',
        schedule: batch.schedule || 'TBD',
        days: batch.days || 'TBD',
        court: 'TBD', // Court not in Batch model
        studentCount: batch.currentStudents || 0,
        maxStudents: batch.maxStudents || 0,
        status: batch.status,
        startDate: batch.startDate,
        endDate: batch.endDate,
        fees: batch.fees || 0
      };
    });

    res.status(200).json({
      success: true,
      data: {
        batches: batchesData,
        total: count,
        page: parseInt(page),
        limit: parseInt(limit),
        totalPages: Math.ceil(count / parseInt(limit))
      }
    });
  } catch (error) {
    console.error('Error fetching my batches:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch batches',
      error: error.message
    });
  }
};

// Helper function to determine session status
function determineSessionStatus(startTime, endTime) {
  if (!startTime || !endTime) return 'Upcoming';
  
  const now = new Date();
  const currentTime = now.getHours() * 60 + now.getMinutes();
  
  const [startHour, startMin] = startTime.split(':').map(Number);
  const [endHour, endMin] = endTime.split(':').map(Number);
  
  const startMinutes = startHour * 60 + startMin;
  const endMinutes = endHour * 60 + endMin;
  
  if (currentTime >= startMinutes && currentTime <= endMinutes) {
    return 'In Progress';
  } else if (currentTime < startMinutes) {
    return 'Upcoming';
  } else {
    return 'Completed';
  }
}

module.exports = exports;


/**
 * Get Students Autocomplete
 * Returns student names for autocomplete
 */
exports.getStudentsAutocomplete = async (req, res) => {
  try {
    const userEmail = req.user.email;
    const { search = '' } = req.query;

    const coach = await Coach.findOne({
      where: { email: userEmail }
    });

    if (!coach) {
      return res.status(404).json({
        success: false,
        message: 'Coach profile not found'
      });
    }

    // Get coach's batches
    const coachBatches = await Batch.findAll({
      where: { coachId: coach.id },
      attributes: ['id']
    });

    const batchIds = coachBatches.map(b => b.id);

    if (batchIds.length === 0) {
      return res.json({ success: true, data: [] });
    }

    // Build search condition
    const userWhere = search ? {
      name: { [Op.like]: `%${search}%` }
    } : {};

    // Get students enrolled in coach's batches
    const studentBatches = await StudentBatches.findAll({
      where: {
        batchId: { [Op.in]: batchIds },
        status: 'Active'
      },
      include: [{
        model: Student,
        as: 'student',
        include: [{
          model: User,
          as: 'User',
          attributes: ['id', 'name'],
          where: userWhere,
          required: true
        }],
        required: true
      }],
      attributes: ['studentId'],
      group: ['studentId', 'student.id', 'student->User.id'],
      limit: 20
    });

    const students = studentBatches.map(sp => ({
      id: sp.student.id,
      name: sp.student.User.name
    }));

    res.json({
      success: true,
      data: students
    });
  } catch (error) {
    console.error('Error fetching students autocomplete:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch students',
      error: error.message
    });
  }
};

/**
 * Get Sports Autocomplete
 * Returns sports for autocomplete
 */
exports.getSportsAutocomplete = async (req, res) => {
  try {
    const userEmail = req.user.email;
    const { search = '' } = req.query;

    const coach = await Coach.findOne({
      where: { email: userEmail }
    });

    if (!coach) {
      return res.status(404).json({
        success: false,
        message: 'Coach profile not found'
      });
    }

    // Get all batches for this coach with their sports
    const batches = await Batch.findAll({
      where: { coachId: coach.id },
      include: [{
        model: Sport,
        as: 'sport',
        attributes: ['id', 'name'],
        where: search ? { name: { [Op.like]: `%${search}%` } } : {},
        required: true
      }],
      attributes: ['id', 'sportId']
    });

    // Extract unique sports
    const sportsMap = new Map();
    batches.forEach(batch => {
      if (batch.sport) {
        sportsMap.set(batch.sport.id, {
          id: batch.sport.id,
          name: batch.sport.name
        });
      }
    });

    const sports = Array.from(sportsMap.values());

    console.log(`[Sports Autocomplete] Coach: ${coach.email}, Found ${sports.length} sports`);

    res.json({
      success: true,
      data: sports
    });
  } catch (error) {
    console.error('Error fetching sports autocomplete:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch sports',
      error: error.message
    });
  }
};

/**
 * Get Batches Autocomplete
 * Returns batches for autocomplete
 */
exports.getBatchesAutocomplete = async (req, res) => {
  try {
    const userEmail = req.user.email;
    const { search = '' } = req.query;

    const coach = await Coach.findOne({
      where: { email: userEmail }
    });

    if (!coach) {
      return res.status(404).json({
        success: false,
        message: 'Coach profile not found'
      });
    }

    const where = { coachId: coach.id, status: 'Active' };
    if (search) {
      where.name = { [Op.like]: `%${search}%` };
    }

    const batches = await Batch.findAll({
      where,
      attributes: ['id', 'name'],
      limit: 20
    });

    console.log(`[Batches Autocomplete] Coach: ${coach.email}, Found ${batches.length} batches`);

    res.json({
      success: true,
      data: batches.map(b => ({ id: b.id, name: b.name }))
    });
  } catch (error) {
    console.error('Error fetching batches autocomplete:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch batches',
      error: error.message
    });
  }
};

/**
 * Get Programs Autocomplete
 * Returns programs for autocomplete
 */
exports.getProgramsAutocomplete = async (req, res) => {
  try {
    const userEmail = req.user.email;
    const { search = '' } = req.query;

    const coach = await Coach.findOne({
      where: { email: userEmail }
    });

    if (!coach) {
      return res.status(404).json({
        success: false,
        message: 'Coach profile not found'
      });
    }

    const where = { coachId: coach.id, status: 'Active' };
    if (search) {
      where.name = { [Op.like]: `%${search}%` };
    }

    const batches = await Batch.findAll({
      where,
      attributes: ['id', 'name'],
      limit: 20
    });

    res.json({
      success: true,
      data: batches.map(b => ({ id: b.id, name: b.name }))
    });
  } catch (error) {
    console.error('Error fetching programs autocomplete:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch programs',
      error: error.message
    });
  }
};

/**
 * Get Student Enrollments grouped by month
 *
 * GET /api/coach/dashboard/students/enrollments-by-month?month=YYYY-MM&search=&status=
 *
 * Answers "which students joined which of my batches in a given month?".
 * Returns the students enrolled in the requested month grouped batch-wise,
 * plus the list of every month that has enrollments (with counts) so the UI
 * can offer a month picker without a second round-trip.
 *
 * A student is listed in every month their enrollment is *live*, not only the
 * month they joined: the window runs from `enrollmentDate` to `validTill`
 * (falling back to the batch end date, and open-ended when neither is set). So
 * someone who joins on 31 Jul with validity to 15 Aug appears in both July and
 * August, flagged "new" in July and "continuing" in August.
 *
 * The month bucketing is done in JS on the coach's own rows rather than with
 * DATE_FORMAT/TO_CHAR so the query stays dialect-independent.
 */

/** Enrollments in these states stop carrying forward past the month they ended. */
const NON_CARRYING_ENROLLMENT_STATUSES = ['Dropped', 'Transferred'];
/** Never project an enrollment window further than this past the current month. */
const MAX_MONTHS_AHEAD = 24;

exports.getEnrollmentsByMonth = async (req, res) => {
  try {
    const userEmail = req.user.email;
    const { month = '', search = '', status = '' } = req.query;

    const coach = await Coach.findOne({ where: { email: userEmail } });

    if (!coach) {
      return res.status(404).json({
        success: false,
        message: 'Coach profile not found'
      });
    }

    const pad = (n) => String(n).padStart(2, '0');
    /** Normalise a DATEONLY / Date / null into 'YYYY-MM-DD'. */
    const dateStr = (d) => {
      if (!d) return null;
      if (d instanceof Date) return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
      const s = String(d).slice(0, 10);
      return /^\d{4}-\d{2}-\d{2}$/.test(s) ? s : null;
    };
    const monthKey = (d) => (dateStr(d) || '').slice(0, 7) || null;
    const monthLabel = (key) => {
      if (!/^\d{4}-\d{2}$/.test(key)) return key;
      const [y, m] = key.split('-').map(Number);
      return new Date(y, m - 1, 1).toLocaleDateString('en-IN', { month: 'long', year: 'numeric' });
    };
    const shiftMonth = (key, delta) => {
      const [y, m] = key.split('-').map(Number);
      const dt = new Date(y, (m - 1) + delta, 1);
      return `${dt.getFullYear()}-${pad(dt.getMonth() + 1)}`;
    };
    const currentMonth = (() => {
      const now = new Date();
      return `${now.getFullYear()}-${pad(now.getMonth() + 1)}`;
    })();
    const horizonMonth = shiftMonth(currentMonth, MAX_MONTHS_AHEAD);

    const emptySummary = {
      totalStudents: 0, totalBatches: 0, newThisMonth: 0,
      continuing: 0, expiring: 0, active: 0, paid: 0, pending: 0
    };

    // Every batch this coach runs — the enrollment universe for this screen.
    const coachBatches = await Batch.findAll({
      where: { coachId: coach.id },
      attributes: ['id', 'name', 'schedule', 'days', 'startTime', 'endTime', 'status', 'fees', 'maxStudents', 'endDate'],
      include: [{ model: Sport, as: 'sport', attributes: ['id', 'name'] }]
    });

    if (coachBatches.length === 0) {
      const fallback = /^\d{4}-\d{2}$/.test(month) ? month : currentMonth;
      return res.json({
        success: true,
        data: {
          month: fallback,
          label: monthLabel(fallback),
          months: [],
          summary: emptySummary,
          batches: []
        }
      });
    }

    const batchIds = coachBatches.map((b) => b.id);
    const batchMap = new Map(coachBatches.map((b) => [b.id, b]));

    const where = { batchId: { [Op.in]: batchIds } };
    if (status) where.status = status;

    const enrollments = await StudentBatches.findAll({
      where,
      include: [{
        model: Student,
        as: 'student',
        required: true,
        include: [{
          model: User,
          as: 'User',
          attributes: ['id', 'name', 'email', 'phone_number'],
          required: true
        }]
      }],
      order: [['enrollmentDate', 'DESC'], ['id', 'DESC']]
    });

    // Resolve each enrollment's live window: [joined month … valid-till month].
    const windows = enrollments.map((e) => {
      const startDate = dateStr(e.enrollmentDate);
      const ownValidTill = dateStr(e.validTill);
      const batch = batchMap.get(e.batchId);
      const batchEnd = dateStr(batch?.endDate);
      // The coach's per-student validity wins; the batch end date is the fallback.
      let endDate = ownValidTill || batchEnd || null;
      const validTillSource = ownValidTill ? 'enrollment' : (batchEnd ? 'batch' : null);

      // A validity earlier than the join date is bad data — never let it hide
      // the student from the month they actually joined.
      if (endDate && startDate && endDate < startDate) endDate = startDate;

      const startKey = startDate ? startDate.slice(0, 7) : null;
      let endKey = endDate ? endDate.slice(0, 7) : null;

      // Dropped / transferred students do not keep showing up in later months.
      if (NON_CARRYING_ENROLLMENT_STATUSES.includes(e.status)) endKey = startKey;

      return { row: e, startDate, endDate, startKey, endKey, validTillSource };
    }).filter((w) => w.startKey);

    // Month index — every month any enrollment is live in, newest first.
    // Open-ended enrollments are projected only up to the current month, so the
    // picker never runs away into the future.
    const monthCounts = new Map();
    windows.forEach((w) => {
      let last = w.endKey || (w.startKey > currentMonth ? w.startKey : currentMonth);
      if (last > horizonMonth) last = horizonMonth;
      for (let key = w.startKey; key <= last; key = shiftMonth(key, 1)) {
        monthCounts.set(key, (monthCounts.get(key) || 0) + 1);
      }
    });
    const months = [...monthCounts.entries()]
      .sort((a, b) => b[0].localeCompare(a[0]))
      .map(([key, count]) => ({ month: key, label: monthLabel(key), count }));

    // Requested month, else the current month when it has students, else the
    // most recent month that does.
    const selectedMonth = /^\d{4}-\d{2}$/.test(month)
      ? month
      : (monthCounts.has(currentMonth) ? currentMonth : (months[0]?.month || currentMonth));

    const term = String(search).trim().toLowerCase();
    const matchesSearch = (u) =>
      !term ||
      (u?.name || '').toLowerCase().includes(term) ||
      (u?.email || '').toLowerCase().includes(term) ||
      (u?.phone_number || '').toLowerCase().includes(term);

    const coversMonth = (w) =>
      w.startKey <= selectedMonth && (!w.endKey || w.endKey >= selectedMonth);

    const monthRows = windows.filter(
      (w) => coversMonth(w) && matchesSearch(w.row.student?.User)
    );

    // Group batch-wise.
    const grouped = new Map();
    monthRows.forEach((w) => {
      const e = w.row;
      const batch = batchMap.get(e.batchId);
      if (!grouped.has(e.batchId)) {
        grouped.set(e.batchId, {
          id: e.batchId,
          name: batch?.name || 'Unknown Batch',
          sport: batch?.sport?.name || '—',
          schedule: batch?.schedule || '',
          days: batch?.days || '',
          startTime: batch?.startTime || null,
          endTime: batch?.endTime || null,
          batchStatus: batch?.status || '',
          fees: batch?.fees != null ? Number(batch.fees) : null,
          maxStudents: batch?.maxStudents ?? null,
          students: []
        });
      }
      grouped.get(e.batchId).students.push({
        enrollmentId: e.id,
        id: e.student?.id,
        name: e.student?.User?.name || 'Unknown',
        email: e.student?.User?.email || '',
        phone: e.student?.User?.phone_number || '',
        enrollmentDate: w.startDate,
        /** Effective validity — the student's own date, else the batch end date. */
        validTill: w.endDate,
        validTillSource: w.validTillSource,
        /** Joined during the selected month (vs. carried over from an earlier one). */
        isNew: w.startKey === selectedMonth,
        /** Validity runs out inside the selected month — renewal due. */
        expiring: w.endKey === selectedMonth,
        status: e.status,
        paymentStatus: e.paymentStatus,
        approvalStatus: e.approvalStatus,
        amountPaid: e.amountPaid != null ? Number(e.amountPaid) : 0,
        feesPaid: Boolean(e.feesPaid)
      });
    });

    const batches = [...grouped.values()]
      .map((b) => ({
        ...b,
        count: b.students.length,
        newCount: b.students.filter((s) => s.isNew).length,
        students: b.students.sort(
          (x, y) =>
            Number(y.isNew) - Number(x.isNew) ||
            String(y.enrollmentDate).localeCompare(String(x.enrollmentDate)) ||
            x.name.localeCompare(y.name)
        )
      }))
      .sort((a, b) => b.count - a.count || a.name.localeCompare(b.name));

    const summary = {
      totalStudents: monthRows.length,
      totalBatches: batches.length,
      newThisMonth: monthRows.filter((w) => w.startKey === selectedMonth).length,
      continuing: monthRows.filter((w) => w.startKey !== selectedMonth).length,
      expiring: monthRows.filter((w) => w.endKey === selectedMonth).length,
      active: monthRows.filter((w) => w.row.status === 'Active').length,
      paid: monthRows.filter((w) => w.row.paymentStatus === 'Paid').length,
      pending: monthRows.filter((w) => w.row.paymentStatus !== 'Paid').length
    };

    res.status(200).json({
      success: true,
      data: {
        month: selectedMonth,
        label: monthLabel(selectedMonth),
        months,
        summary,
        batches
      }
    });
  } catch (error) {
    console.error('Error fetching enrollments by month:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch student enrollments',
      error: error.message
    });
  }
};
