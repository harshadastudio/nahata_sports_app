const { CoachingEnquiry, User, Batch, Sport, Coach } = require('../models');
const { Op } = require('sequelize');
const emailService = require('../services/emailService');
const { validateEmailOrThrow } = require('../utils/emailValidation');
const { resolveComplexId, isComplexScoped, stampComplexId, assertComplexAccess } = require('../middleware/complexScope');

// Reusable User attributes — uses the actual DB column name 'phone_number'
const USER_ATTRS = ['id', 'name', 'email', 'phone_number'];

// Batch attributes presented with an enquiry (Batch replaced Program: price -> fees).
const BATCH_BRIEF = ['id', 'name', 'fees', 'duration'];
const BATCH_LIST = ['id', 'name', 'fees', 'duration', 'ageGroup', 'maxStudents', 'currentStudents'];

// Generate a unique reference number: NSC-YYYYMMDD-XXXXX
const generateReferenceNumber = () => {
  const date = new Date();
  const datePart = date.getFullYear().toString() +
    String(date.getMonth() + 1).padStart(2, '0') +
    String(date.getDate()).padStart(2, '0');
  const randomPart = Math.random().toString(36).substring(2, 7).toUpperCase();
  return `NSC-${datePart}-${randomPart}`;
};

// Derive which complex a coaching enquiry belongs to from the selected batch
// (preferred) or coach. The complex is an intrinsic property of the batch/coach,
// NOT of whoever creates the enquiry — so a super admin (whose own complex is
// null) or a coach creating an enquiry for a Gangadham batch still produces a
// correctly Gangadham-scoped enquiry that the Gangadham complex admin can see.
const resolveEnquiryComplexId = async ({ batchId, coachId }) => {
  if (batchId) {
    const batch = await Batch.findByPk(batchId, { attributes: ['sportComplexId'] });
    if (batch && batch.sportComplexId != null) return Number(batch.sportComplexId);
  }
  if (coachId) {
    const coach = await Coach.findByPk(coachId, { attributes: ['sportComplexId'] });
    if (coach && coach.sportComplexId != null) return Number(coach.sportComplexId);
  }
  return null;
};

// Create a new coaching enquiry (User)
exports.createEnquiry = async (req, res) => {
  try {
    const { batchId, sportId, coachId, name, email, phone, message } = req.body;
    const userId = req.user.id;

    // Validate required fields
    if (!batchId || !name || !email || !phone) {
      return res.status(400).json({
        success: false,
        message: 'Batch ID, name, email, and phone are required'
      });
    }

    // Validate email & catch domain typos so the confirmation email doesn't bounce
    let validEmail;
    try {
      validEmail = validateEmailOrThrow(email, 'Email');
    } catch (emailErr) {
      return res.status(400).json({ success: false, message: emailErr.message });
    }

    // Generate unique reference number
    const referenceNumber = generateReferenceNumber();

    // Build payload; stampComplexId is a no-op for public/non-complex-admin users,
    // and forces the complex when an admin submits via this endpoint.
    const enquiryData = stampComplexId(req, {
      userId,
      batchId,
      sportId,
      coachId,
      name,
      email: validEmail,
      phone,
      message,
      status: 'Pending',
      referenceNumber
    });

    // The enquiry belongs to the selected batch's complex (fallback: coach's),
    // not to whoever submits it — so it scopes correctly for the complex admin.
    const derivedComplexId = await resolveEnquiryComplexId({ batchId, coachId });
    if (derivedComplexId != null) enquiryData.sportComplexId = derivedComplexId;

    // Create enquiry
    const enquiry = await CoachingEnquiry.create(enquiryData);

    // Notify admins (super admin + the enquiry's complex admin) — fire-and-forget.
    require('../services/notificationService').notifyAdmins({
      type: 'Alert',
      title: 'New Coaching Enquiry',
      message: `${name} submitted a new coaching enquiry.`,
      actionUrl: '/coaching-enquiry',
      sportComplexId: enquiryData.sportComplexId ?? null,
    });

    // Fetch the created enquiry with associations
    const createdEnquiry = await CoachingEnquiry.findByPk(enquiry.id, {
      include: [
        { model: User, as: 'user', attributes: USER_ATTRS },
        { model: Batch, as: 'batch', attributes: BATCH_BRIEF },
        { model: Sport, as: 'sport', attributes: ['id', 'name'] },
        { model: Coach, as: 'coach', attributes: ['id', 'name', 'email', 'phone'] }
      ]
    });

    // Send confirmation email to the student (non-blocking)
    emailService.sendEnquirySubmittedEmail({
      to: validEmail,
      name,
      programName: createdEnquiry.batch?.name,
      sportName: createdEnquiry.sport?.name,
      coachName: createdEnquiry.coach?.name,
      referenceNumber
    }).catch((err) => console.error('❌ Enquiry email failed:', err.message));

    // Notify the assigned coach, if one was selected and has an email (non-blocking)
    if (createdEnquiry.coach?.email) {
      emailService.sendCoachNewEnquiryEmail({
        to: createdEnquiry.coach.email,
        coachName: createdEnquiry.coach.name,
        studentName: name,
        studentEmail: validEmail,
        studentPhone: phone,
        programName: createdEnquiry.batch?.name,
        sportName: createdEnquiry.sport?.name,
        message,
        referenceNumber
      }).catch((err) => console.error('❌ Coach notification email failed:', err.message));
    }

    res.status(201).json({
      success: true,
      message: 'Your enquiry has been sent!',
      data: createdEnquiry
    });
  } catch (error) {
    console.error('Error creating coaching enquiry:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to create enquiry',
      error: error.message
    });
  }
};

// Create a new coaching enquiry by Admin
exports.createEnquiryByAdmin = async (req, res) => {
  try {
    const { batchId, sportId, coachId, name, email, phone, message, userId: providedUserId } = req.body;

    // Use provided userId or the admin's userId as fallback
    const userId = providedUserId || req.user.id;

    // Validate required fields
    if (!batchId || !name || !email || !phone) {
      return res.status(400).json({
        success: false,
        message: 'Batch ID, name, email, and phone are required'
      });
    }

    // Force the complex for a complex admin; honor explicit value for super admin
    const enquiryData = stampComplexId(req, {
      userId,
      batchId,
      sportId,
      coachId,
      name,
      email,
      phone,
      message,
      status: 'Pending'
    });

    // Scope the enquiry to the selected batch's complex (fallback: coach's), so a
    // super admin creating it for a Gangadham batch still produces a Gangadham
    // enquiry that the Gangadham complex admin can see.
    const derivedComplexId = await resolveEnquiryComplexId({ batchId, coachId });
    if (derivedComplexId != null) enquiryData.sportComplexId = derivedComplexId;

    // Create enquiry
    const enquiry = await CoachingEnquiry.create(enquiryData);

    // Fetch the created enquiry with associations
    const createdEnquiry = await CoachingEnquiry.findByPk(enquiry.id, {
      include: [
        { model: User, as: 'user', attributes: USER_ATTRS },
        { model: Batch, as: 'batch', attributes: BATCH_BRIEF },
        { model: Sport, as: 'sport', attributes: ['id', 'name'] },
        { model: Coach, as: 'coach', attributes: ['id', 'name', 'email', 'phone'] }
      ]
    });

    res.status(201).json({
      success: true,
      message: 'Enquiry created successfully!',
      data: createdEnquiry
    });
  } catch (error) {
    console.error('Error creating coaching enquiry by admin:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to create enquiry',
      error: error.message
    });
  }
};

// Get all enquiries (Admin only)
exports.getAllEnquiries = async (req, res) => {
  try {
    const {
      status,
      sportId,
      batchId,
      search,
      fromDate,
      toDate,
      page = 1,
      limit = 10
    } = req.query;

    // Build where clause
    const where = {};

    if (status) {
      where.status = status;
    }

    if (sportId) {
      where.sportId = sportId;
    }

    if (batchId) {
      where.batchId = batchId;
    }

    // Per-complex admin scoping (null for super admin = all complexes)
    const complexId = resolveComplexId(req);
    if (complexId != null) {
      where.sportComplexId = complexId;
    }

    if (search) {
      where[Op.or] = [
        { name: { [Op.like]: `%${search}%` } },
        { email: { [Op.like]: `%${search}%` } },
        { phone: { [Op.like]: `%${search}%` } }
      ];
    }

    if (fromDate || toDate) {
      where.createdAt = {};
      if (fromDate) {
        where.createdAt[Op.gte] = new Date(fromDate);
      }
      if (toDate) {
        where.createdAt[Op.lte] = new Date(toDate);
      }
    }

    // Calculate pagination
    const offset = (page - 1) * limit;

    // Fetch enquiries
    const { count, rows: enquiries } = await CoachingEnquiry.findAndCountAll({
      where,
      include: [
        { model: User, as: 'user', attributes: USER_ATTRS },
        { model: Batch, as: 'batch', attributes: BATCH_LIST },
        { model: Sport, as: 'sport', attributes: ['id', 'name', 'image'] },
        { model: Coach, as: 'coach', attributes: ['id', 'name', 'email', 'phone'] }
      ],
      order: [['createdAt', 'DESC']],
      limit: parseInt(limit),
      offset: parseInt(offset)
    });

    res.status(200).json({
      success: true,
      data: {
        enquiries,
        total: count,
        page: parseInt(page),
        limit: parseInt(limit),
        totalPages: Math.ceil(count / limit)
      }
    });
  } catch (error) {
    console.error('Error fetching coaching enquiries:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch enquiries',
      error: error.message
    });
  }
};

// Get enquiry by ID
exports.getEnquiryById = async (req, res) => {
  try {
    const { id } = req.params;

    const enquiry = await CoachingEnquiry.findByPk(id, {
      include: [
        { model: User, as: 'user', attributes: USER_ATTRS },
        { model: Batch, as: 'batch', attributes: ['id', 'name', 'fees', 'duration', 'ageGroup', 'description'] },
        { model: Sport, as: 'sport', attributes: ['id', 'name', 'image'] }
      ]
    });

    if (!enquiry) {
      return res.status(404).json({
        success: false,
        message: 'Enquiry not found'
      });
    }

    // Complex admins can only view enquiries in their own complex
    if (!assertComplexAccess(req, res, enquiry.sportComplexId)) return;

    res.status(200).json({
      success: true,
      data: enquiry
    });
  } catch (error) {
    console.error('Error fetching enquiry:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch enquiry',
      error: error.message
    });
  }
};

// Get enquiries for a specific user
exports.getUserEnquiries = async (req, res) => {
  try {
    const userId = req.user.id;
    const { page = 1, limit = 10 } = req.query;

    const offset = (page - 1) * limit;

    const { count, rows: enquiries } = await CoachingEnquiry.findAndCountAll({
      where: { userId },
      include: [
        { model: Batch, as: 'batch', attributes: BATCH_BRIEF },
        { model: Sport, as: 'sport', attributes: ['id', 'name', 'image'] },
        { model: Coach, as: 'coach', attributes: ['id', 'name', 'email', 'phone'] }
      ],
      order: [['createdAt', 'DESC']],
      limit: parseInt(limit),
      offset: parseInt(offset)
    });

    res.status(200).json({
      success: true,
      data: {
        enquiries,
        total: count,
        page: parseInt(page),
        limit: parseInt(limit),
        totalPages: Math.ceil(count / limit)
      }
    });
  } catch (error) {
    console.error('Error fetching user enquiries:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch enquiries',
      error: error.message
    });
  }
};

// Get enquiries assigned to a coach (Coach role)
// This fetches ALL enquiries where the coach is assigned (coachId matches)
exports.getCoachEnquiries = async (req, res) => {
  try {
    const userEmail = req.user.email; // Get logged-in user's email
    const {
      status,
      sportId,
      batchId,
      search,
      fromDate,
      toDate,
      page = 1,
      limit = 10
    } = req.query;

    // Find the coach record by matching email
    const coach = await Coach.findOne({
      where: { email: userEmail }
    });

    // If no coach profile is linked to this account, return empty results gracefully
    if (!coach) {
      console.warn(`⚠️ No coach profile found for email: ${userEmail}. Returning empty enquiries.`);
      return res.status(200).json({
        success: true,
        data: {
          enquiries: [],
          total: 0,
          page: parseInt(page),
          limit: parseInt(limit),
          totalPages: 0
        }
      });
    }

    // Build where clause
    const where = {
      coachId: coach.id // Filter by coach ID - this shows enquiries assigned to this coach
    };

    if (status) {
      where.status = status;
    }

    if (sportId) {
      where.sportId = sportId;
    }

    if (batchId) {
      where.batchId = batchId;
    }

    if (search) {
      where[Op.or] = [
        { name: { [Op.like]: `%${search}%` } },
        { email: { [Op.like]: `%${search}%` } },
        { phone: { [Op.like]: `%${search}%` } }
      ];
    }

    if (fromDate || toDate) {
      where.createdAt = {};
      if (fromDate) {
        where.createdAt[Op.gte] = new Date(fromDate);
      }
      if (toDate) {
        where.createdAt[Op.lte] = new Date(toDate);
      }
    }

    // Calculate pagination
    const offset = (page - 1) * limit;

    // Fetch enquiries
    const { count, rows: enquiries } = await CoachingEnquiry.findAndCountAll({
      where,
      include: [
        { model: User, as: 'user', attributes: USER_ATTRS },
        { model: Batch, as: 'batch', attributes: BATCH_LIST },
        { model: Sport, as: 'sport', attributes: ['id', 'name', 'image'] },
        { model: Coach, as: 'coach', attributes: ['id', 'name', 'email', 'phone'] }
      ],
      order: [['createdAt', 'DESC']],
      limit: parseInt(limit),
      offset: parseInt(offset)
    });

    res.status(200).json({
      success: true,
      data: {
        enquiries,
        total: count,
        page: parseInt(page),
        limit: parseInt(limit),
        totalPages: Math.ceil(count / limit)
      }
    });
  } catch (error) {
    console.error('Error fetching coach enquiries:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch enquiries',
      error: error.message
    });
  }
};

// Create a new coaching enquiry by Coach (sends to admin)
exports.createEnquiryByCoach = async (req, res) => {
  try {
    const { batchId, sportId, coachId, name, email, phone, message } = req.body;
    const userEmail = req.user.email;

    console.log('🔵 Coach creating enquiry:', {
      userEmail,
      batchId,
      name,
      email,
      phone
    });

    // Find the coach record by matching email
    const coach = await Coach.findOne({
      where: { email: userEmail }
    });

    if (!coach) {
      console.error('❌ Coach profile not found for email:', userEmail);
      return res.status(404).json({
        success: false,
        message: `Coach profile not found for email: ${userEmail}. Please contact admin to link your account.`
      });
    }

    console.log('✅ Coach found:', { id: coach.id, name: coach.name, email: coach.email });

    // Validate required fields
    if (!batchId || !name || !email || !phone) {
      return res.status(400).json({
        success: false,
        message: 'Batch ID, name, email, and phone are required'
      });
    }

    // Generate unique reference number
    const referenceNumber = generateReferenceNumber();

    // Scope to the batch's complex (fallback: the coach's own complex) so the
    // enquiry is visible to the right complex admin. Previously this path stamped
    // nothing, leaving sportComplexId NULL → invisible to every complex admin.
    const effectiveCoachId = coachId || coach.id;
    let derivedComplexId = await resolveEnquiryComplexId({ batchId, coachId: effectiveCoachId });
    if (derivedComplexId == null && coach.sportComplexId != null) {
      derivedComplexId = Number(coach.sportComplexId);
    }

    // Create enquiry with coach's ID
    const enquiry = await CoachingEnquiry.create({
      userId: req.user.id, // Coach's user ID
      batchId,
      sportId,
      coachId: effectiveCoachId, // Use provided coachId or default to current coach
      name,
      email,
      phone,
      message,
      status: 'Pending',
      referenceNumber,
      sportComplexId: derivedComplexId
    });

    // Notify admins (super admin + the enquiry's complex admin) — fire-and-forget.
    require('../services/notificationService').notifyAdmins({
      type: 'Alert',
      title: 'New Coaching Enquiry',
      message: `${name} submitted a new coaching enquiry (via coach ${coach.name}).`,
      actionUrl: '/coaching-enquiry',
      sportComplexId: derivedComplexId ?? null,
    });

    console.log('✅ Enquiry created:', { id: enquiry.id, referenceNumber });

    // Fetch the created enquiry with associations
    const createdEnquiry = await CoachingEnquiry.findByPk(enquiry.id, {
      include: [
        { model: User, as: 'user', attributes: USER_ATTRS },
        { model: Batch, as: 'batch', attributes: BATCH_BRIEF },
        { model: Sport, as: 'sport', attributes: ['id', 'name'] },
        { model: Coach, as: 'coach', attributes: ['id', 'name', 'email', 'phone'] }
      ]
    });

    // Send confirmation email (non-blocking)
    emailService.sendEnquirySubmittedEmail({
      to: email,
      name,
      programName: createdEnquiry.batch?.name,
      sportName: createdEnquiry.sport?.name,
      coachName: createdEnquiry.coach?.name,
      referenceNumber
    }).catch((err) => console.error('❌ Coach enquiry email failed:', err.message));

    res.status(201).json({
      success: true,
      message: 'Enquiry sent to admin successfully!',
      data: createdEnquiry
    });
  } catch (error) {
    console.error('❌ Error creating coaching enquiry by coach:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to create enquiry',
      error: error.message
    });
  }
};

// Update enquiry status (Admin only)
exports.updateEnquiryStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;

    // Validate status
    const validStatuses = ['Pending', 'Reviewed', 'Approved', 'Rejected', 'Contacted'];
    if (!validStatuses.includes(status)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid status value'
      });
    }

    const enquiry = await CoachingEnquiry.findByPk(id);

    if (!enquiry) {
      return res.status(404).json({
        success: false,
        message: 'Enquiry not found'
      });
    }

    // Complex admins can only act on enquiries in their own complex
    if (!assertComplexAccess(req, res, enquiry.sportComplexId)) return;

    enquiry.status = status;
    await enquiry.save();

    // Fetch updated enquiry with associations
    const updatedEnquiry = await CoachingEnquiry.findByPk(id, {
      include: [
        { model: User, as: 'user', attributes: USER_ATTRS },
        { model: Batch, as: 'batch', attributes: BATCH_BRIEF },
        { model: Sport, as: 'sport', attributes: ['id', 'name'] }
      ]
    });

    // Send rejection email if status changed to Rejected
    if (status === 'Rejected') {
      emailService.sendEnquiryRejectedEmail({
        to: enquiry.email,
        name: enquiry.name,
        programName: updatedEnquiry.batch?.name,
        referenceNumber: enquiry.referenceNumber || `NSC-${enquiry.id}`
      }).catch((err) => console.error('❌ Rejection email failed:', err.message));
    }

    res.status(200).json({
      success: true,
      message: 'Enquiry status updated successfully',
      data: updatedEnquiry
    });
  } catch (error) {
    console.error('Error updating enquiry status:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to update enquiry status',
      error: error.message
    });
  }
};

// Update enquiry status by Coach (Coach role)
exports.updateEnquiryStatusByCoach = async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;
    const userEmail = req.user.email;

    // Find the coach record
    const coach = await Coach.findOne({
      where: { email: userEmail }
    });

    if (!coach) {
      return res.status(404).json({
        success: false,
        message: 'Coach profile not found'
      });
    }

    // Validate status - coaches can only mark as Reviewed, Contacted, or Rejected
    const validStatuses = ['Pending', 'Reviewed', 'Contacted', 'Rejected'];
    if (!validStatuses.includes(status)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid status value. Coaches can only mark enquiries as Reviewed, Contacted, or Rejected.'
      });
    }

    const enquiry = await CoachingEnquiry.findByPk(id);

    if (!enquiry) {
      return res.status(404).json({
        success: false,
        message: 'Enquiry not found'
      });
    }

    // Verify this enquiry belongs to the coach
    if (enquiry.coachId !== coach.id) {
      return res.status(403).json({
        success: false,
        message: 'You can only update enquiries assigned to you'
      });
    }

    enquiry.status = status;
    await enquiry.save();

    // Fetch updated enquiry with associations
    const updatedEnquiry = await CoachingEnquiry.findByPk(id, {
      include: [
        { model: User, as: 'user', attributes: USER_ATTRS },
        { model: Batch, as: 'batch', attributes: BATCH_BRIEF },
        { model: Sport, as: 'sport', attributes: ['id', 'name'] },
        { model: Coach, as: 'coach', attributes: ['id', 'name', 'email', 'phone'] }
      ]
    });

    // Send rejection email if status changed to Rejected
    if (status === 'Rejected') {
      emailService.sendEnquiryRejectedEmail({
        to: enquiry.email,
        name: enquiry.name,
        programName: updatedEnquiry.batch?.name,
        referenceNumber: enquiry.referenceNumber || `NSC-${enquiry.id}`
      }).catch((err) => console.error('❌ Rejection email failed:', err.message));
    }

    res.status(200).json({
      success: true,
      message: 'Enquiry status updated successfully',
      data: updatedEnquiry
    });
  } catch (error) {
    console.error('Error updating enquiry status by coach:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to update enquiry status',
      error: error.message
    });
  }
};

// Delete enquiry (Admin only - soft delete)
exports.deleteEnquiry = async (req, res) => {
  try {
    const { id } = req.params;

    const enquiry = await CoachingEnquiry.findByPk(id);

    if (!enquiry) {
      return res.status(404).json({
        success: false,
        message: 'Enquiry not found'
      });
    }

    // Complex admins can only delete enquiries in their own complex
    if (!assertComplexAccess(req, res, enquiry.sportComplexId)) return;

    await enquiry.destroy(); // Soft delete

    res.status(200).json({
      success: true,
      message: 'Enquiry deleted successfully'
    });
  } catch (error) {
    console.error('Error deleting enquiry:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to delete enquiry',
      error: error.message
    });
  }
};

// Delete enquiry by Coach (Coach role - soft delete)
exports.deleteEnquiryByCoach = async (req, res) => {
  try {
    const { id } = req.params;
    const userEmail = req.user.email;

    // Find the coach record
    const coach = await Coach.findOne({
      where: { email: userEmail }
    });

    if (!coach) {
      return res.status(404).json({
        success: false,
        message: 'Coach profile not found'
      });
    }

    const enquiry = await CoachingEnquiry.findByPk(id);

    if (!enquiry) {
      return res.status(404).json({
        success: false,
        message: 'Enquiry not found'
      });
    }

    // Verify this enquiry belongs to the coach
    if (enquiry.coachId !== coach.id) {
      return res.status(403).json({
        success: false,
        message: 'You can only delete enquiries assigned to you'
      });
    }

    await enquiry.destroy(); // Soft delete

    res.status(200).json({
      success: true,
      message: 'Enquiry deleted successfully'
    });
  } catch (error) {
    console.error('Error deleting enquiry by coach:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to delete enquiry',
      error: error.message
    });
  }
};

// Approve enquiry AND enroll student in one action (Admin only)
// This function now automatically creates User and Student records if they don't exist
exports.approveAndEnroll = async (req, res) => {
  const { Student, StudentBatches, Batch } = require('../models');
  const sequelize = require('../models').sequelize;
  const bcrypt = require('bcrypt');
  const t = await sequelize.transaction();

  try {
    const { id } = req.params;
    const { paymentStatus = 'Pending', amountPaid = 0, notes } = req.body;

    // 1. Find the enquiry
    const enquiry = await CoachingEnquiry.findByPk(id, {
      include: [
        { model: Batch, as: 'batch', attributes: ['id', 'name', 'maxStudents', 'currentStudents', 'fees', 'duration'] },
        { model: Sport, as: 'sport', attributes: ['id', 'name'] },
        { model: Coach, as: 'coach', attributes: ['id', 'name', 'email', 'phone'] }
      ],
      transaction: t
    });

    if (!enquiry) {
      await t.rollback();
      return res.status(404).json({ success: false, message: 'Enquiry not found' });
    }

    // Complex-scoped roles (Complex Admin, Coach, Employee, Security) can only
    // act on enquiries in their own complex.
    if (isComplexScoped(req) && Number(enquiry.sportComplexId) !== Number(req.user.sportComplexId)) {
      await t.rollback();
      return res.status(403).json({
        success: false,
        message: 'Access denied: this record belongs to a different sports complex.'
      });
    }

    if (enquiry.status === 'Approved') {
      await t.rollback();
      return res.status(400).json({ success: false, message: 'Enquiry is already approved' });
    }

    // 2. Check batch capacity
    const batch = enquiry.batch;
    if (!batch) {
      await t.rollback();
      return res.status(400).json({ success: false, message: 'Batch not found for this enquiry' });
    }

    if (batch.currentStudents >= batch.maxStudents) {
      await t.rollback();
      return res.status(400).json({ success: false, message: 'Batch is full — cannot enroll' });
    }

    // 3. CREATE OR FIND STUDENT RECORD
    let studentId;
    let isNewUser = false;
    let defaultPassword = null;

    // Check if user already exists with this email
    let user = await User.findOne({
      where: { email: enquiry.email },
      transaction: t
    });

    if (!user) {
      // Create new user account
      defaultPassword = 'Student@123'; // Default password for new students
      const hashedPassword = await bcrypt.hash(defaultPassword, 10);

      user = await User.create({
        name: enquiry.name,
        email: enquiry.email,
        password: hashedPassword,
        phone_number: enquiry.phone,
        role: 'USER',
        status: 'Active',
        join_date: new Date()
      }, { transaction: t });

      isNewUser = true;
      console.log(`✅ Created new User account for ${enquiry.email}`);
    } else {
      console.log(`✅ Found existing User account for ${enquiry.email}`);
    }

    // Check if student record exists
    let student = await Student.findOne({
      where: { userId: user.id },
      transaction: t
    });

    if (!student) {
      // Create student record
      student = await Student.create({
        userId: user.id,
        status: 'Active'
      }, { transaction: t });
      console.log(`✅ Created new Student record for User ID ${user.id}`);
    } else {
      console.log(`✅ Found existing Student record for User ID ${user.id}`);
    }

    studentId = student.id;

    // 4. Create StudentBatches enrollment
    const existing = await StudentBatches.findOne({
      where: { batchId: enquiry.batchId, studentId },
      transaction: t
    });

    if (!existing) {
      await StudentBatches.create({
        batchId: enquiry.batchId,
        studentId,
        enrollmentDate: new Date(),
        status: 'Active',
        paymentStatus,
        amountPaid,
        feesPaid: paymentStatus === 'Paid',
        notes
      }, { transaction: t });

      // Increment currentStudents
      await Batch.increment('currentStudents', {
        where: { id: enquiry.batchId },
        transaction: t
      });

      console.log(`✅ Enrolled Student ID ${studentId} in Batch ID ${enquiry.batchId}`);
    } else {
      console.log(`⚠️ Student ID ${studentId} already enrolled in Batch ID ${enquiry.batchId}`);
    }

    // 5. Update enquiry status and link to student
    enquiry.status = 'Approved';
    enquiry.studentId = studentId; // Link enquiry to created student
    await enquiry.save({ transaction: t });

    await t.commit();

    // Return updated enquiry with associations
    const updatedEnquiry = await CoachingEnquiry.findByPk(id, {
      include: [
        { model: User, as: 'user', attributes: USER_ATTRS },
        { model: Batch, as: 'batch', attributes: BATCH_BRIEF },
        { model: Sport, as: 'sport', attributes: ['id', 'name'] },
        { model: Coach, as: 'coach', attributes: ['id', 'name', 'email', 'phone'] }
      ]
    });

    // 6. Send approval email (non-blocking)
    const emailData = {
      to: enquiry.email,
      name: enquiry.name,
      programName: batch?.name,
      sportName: enquiry.sport?.name,
      coachName: enquiry.coach?.name,
      coachPhone: enquiry.coach?.phone,
      coachEmail: enquiry.coach?.email,
      referenceNumber: enquiry.referenceNumber || `NSC-${enquiry.id}`,
      programPrice: batch?.fees,
      programDuration: batch?.duration
    };

    // Include default password in email if new user was created
    if (isNewUser && defaultPassword) {
      emailData.defaultPassword = defaultPassword;
      emailData.loginUrl = process.env.FRONTEND_URL || 'http://localhost:5173';
    }

    emailService.sendEnquiryApprovedEmail(emailData)
      .catch((err) => console.error('❌ Approval email failed:', err.message));

    res.status(200).json({
      success: true,
      message: 'Enquiry approved, student created, and enrolled successfully',
      data: {
        enquiry: updatedEnquiry,
        studentId,
        userId: user.id,
        isNewUser
      }
    });
  } catch (error) {
    await t.rollback();
    console.error('❌ Error in approveAndEnroll:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to approve and enroll',
      error: error.message
    });
  }
};
