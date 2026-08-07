'use strict';

const { Op } = require('sequelize');
const { ContactUs, ContactInfo, SportComplex } = require('../models');
const emailService = require('./emailService');

/**
 * ContactUsService
 * Handles all database operations and business logic for contact form submissions.
 */
class ContactUsService {
  // ─── XSS Sanitization ──────────────────────────────────────────────────────

  /**
   * Strips HTML tags and dangerous script/iframe elements from a string.
   * Lightweight sanitizer — no external dependency required.
   * @param {string} input
   * @returns {string}
   */
  sanitize(input) {
    if (typeof input !== 'string') return input;
    return input
      .replace(/<script[\s\S]*?>[\s\S]*?<\/script>/gi, '')
      .replace(/<iframe[\s\S]*?>[\s\S]*?<\/iframe>/gi, '')
      .replace(/<[^>]+>/g, '')   // Strip all remaining HTML tags
      .trim();
  }

  // ─── Reference Number Generation ───────────────────────────────────────────

  /**
   * Generates a unique reference number in the format NS-CON-YYYY-NNNN.
   * Queries the current year's record count to determine the next sequence.
   * @returns {Promise<string>}
   */
  async generateReferenceNumber() {
    const year = new Date().getFullYear();
    const startOfYear = new Date(`${year}-01-01T00:00:00.000Z`);
    const endOfYear   = new Date(`${year}-12-31T23:59:59.999Z`);

    // Count ALL records for this year (including soft-deleted) to avoid gaps
    const count = await ContactUs.count({
      where: {
        createdAt: { [Op.between]: [startOfYear, endOfYear] },
      },
      paranoid: false,
    });

    const sequence = String(count + 1).padStart(4, '0');
    return `NS-CON-${year}-${sequence}`;
  }

  // ─── Create Submission ──────────────────────────────────────────────────────

  /**
   * Creates a new contact form submission.
   * Sanitizes text fields, generates a reference number, and optionally
   * sends an admin email notification.
   *
   * @param {object} data - { fullName, email, subject, message, ipAddress, userAgent }
   * @returns {Promise<ContactUs>}
   */
  async createSubmission(data) {
    const { fullName, email, subject, message, ipAddress, userAgent, sportComplexId } = data;

    // Normalize optional sportComplexId (website sends it; public submits may omit it)
    const normalizedComplexId =
      sportComplexId != null && sportComplexId !== '' && !Number.isNaN(Number(sportComplexId))
        ? Number(sportComplexId)
        : null;

    // Sanitize user-supplied text fields (email is not HTML-sanitized)
    const sanitizedData = {
      fullName:        this.sanitize(fullName),
      email,                                    // validated format only, no HTML sanitization
      subject:         this.sanitize(subject),
      message:         this.sanitize(message),
      ipAddress:       ipAddress || null,
      userAgent:       userAgent || null,
      sportComplexId:  normalizedComplexId,
      referenceNumber: await this.generateReferenceNumber(),
    };

    const inquiry = await ContactUs.create(sanitizedData);

    // Send confirmation email to user — fire-and-forget
    emailService.sendContactFormConfirmation({
      to: inquiry.email,
      name: inquiry.fullName,
      referenceNumber: inquiry.referenceNumber,
      subject: inquiry.subject,
    }).catch((err) => {
      console.error('⚠️  User confirmation email failed (non-fatal):', err.message);
    });

    // Optional admin email notification — fire-and-forget, never blocks response
    this._sendAdminNotification(inquiry).catch((err) => {
      console.error('⚠️  Admin notification email failed (non-fatal):', err.message);
    });

    return inquiry;
  }

  // ─── Admin Email Notification ───────────────────────────────────────────────

  /**
   * Sends an admin notification email when a new inquiry is submitted.
   * Only fires when ADMIN_EMAIL_NOTIFY=true is set in environment variables.
   * @param {ContactUs} inquiry
   */
  async _sendAdminNotification(inquiry) {
    if (process.env.ADMIN_EMAIL_NOTIFY !== 'true') return;

    const adminEmail = process.env.ADMIN_NOTIFY_EMAIL;
    if (!adminEmail) {
      console.warn('⚠️  ADMIN_EMAIL_NOTIFY is true but ADMIN_NOTIFY_EMAIL is not set.');
      return;
    }

    const formattedDate = new Date(inquiry.createdAt).toLocaleString('en-IN', {
      timeZone: 'Asia/Kolkata',
      dateStyle: 'medium',
      timeStyle: 'short',
    });

    const mailOptions = {
      from:    process.env.EMAIL_FROM || process.env.EMAIL_USER,
      to:      adminEmail,
      subject: `New Contact Inquiry [${inquiry.referenceNumber}] - Nahata Sports`,
      html: `
        <div style="max-width:600px;margin:0 auto;padding:20px;font-family:Arial,sans-serif;">
          <h2 style="color:#333;">New Contact Form Submission</h2>
          <table style="width:100%;border-collapse:collapse;">
            <tr><td style="padding:8px;font-weight:bold;width:160px;">Reference</td><td style="padding:8px;">${inquiry.referenceNumber}</td></tr>
            <tr style="background:#f9f9f9;"><td style="padding:8px;font-weight:bold;">Name</td><td style="padding:8px;">${inquiry.fullName}</td></tr>
            <tr><td style="padding:8px;font-weight:bold;">Email</td><td style="padding:8px;">${inquiry.email}</td></tr>
            <tr style="background:#f9f9f9;"><td style="padding:8px;font-weight:bold;">Subject</td><td style="padding:8px;">${inquiry.subject}</td></tr>
            <tr><td style="padding:8px;font-weight:bold;">Submitted</td><td style="padding:8px;">${formattedDate}</td></tr>
          </table>
          <h3 style="color:#555;margin-top:20px;">Message</h3>
          <p style="background:#f5f5f5;padding:15px;border-radius:4px;white-space:pre-wrap;">${inquiry.message}</p>
          <hr style="border:1px solid #eee;margin:30px 0;">
          <p style="color:#999;font-size:12px;">Nahata Sports — Admin Notification</p>
        </div>
      `,
    };

    await emailService.transporter.sendMail(mailOptions);
    console.log(`✅ Admin notification sent for inquiry ${inquiry.referenceNumber}`);
  }

  // ─── Admin: List Inquiries ──────────────────────────────────────────────────

  /**
   * Returns a paginated, searchable, filterable list of inquiries for admin.
   * Also returns status counts for the dashboard.
   *
   * @param {object} options - { page, limit, search, status, sortBy, sortOrder }
   * @returns {Promise<{ inquiries, pagination, statusCounts }>}
   */
  async listInquiries({ page = 1, limit = 10, search, status, sortBy = 'createdAt', sortOrder = 'DESC', complexId = null }) {
    // Clamp limit to max 100
    const safeLimit = Math.min(parseInt(limit, 10) || 10, 100);
    const safePage  = Math.max(parseInt(page, 10) || 1, 1);
    const offset    = (safePage - 1) * safeLimit;

    // Whitelist sortBy to prevent injection via query param
    const ALLOWED_SORT_FIELDS = ['createdAt', 'updatedAt', 'fullName', 'email', 'status', 'referenceNumber'];
    const safeSortBy    = ALLOWED_SORT_FIELDS.includes(sortBy) ? sortBy : 'createdAt';
    const safeSortOrder = sortOrder.toUpperCase() === 'ASC' ? 'ASC' : 'DESC';

    // Build WHERE clause
    const where = {};

    if (search && search.trim()) {
      where[Op.or] = [
        { fullName: { [Op.iLike]: `%${search.trim()}%` } },
        { email:    { [Op.iLike]: `%${search.trim()}%` } },
        { subject:  { [Op.iLike]: `%${search.trim()}%` } },
      ];
    }

    if (status && status.trim()) {
      where.status = status.trim();
    }

    // Per-complex scoping (null = no restriction → super admin / unscoped)
    if (complexId != null) {
      where.sportComplexId = complexId;
    }

    // Paginated query
    const { count: total, rows: inquiries } = await ContactUs.findAndCountAll({
      where,
      include: [{
        model: SportComplex,
        as: 'sportComplex',
        attributes: ['id', 'name', 'city'],
      }],
      order:  [[safeSortBy, safeSortOrder]],
      limit:  safeLimit,
      offset,
    });

    // Status counts for dashboard widget (scoped to the same complex as the list)
    const statusCounts = await this._getStatusCounts(complexId);

    return {
      inquiries,
      pagination: {
        total,
        page:       safePage,
        limit:      safeLimit,
        totalPages: Math.ceil(total / safeLimit),
      },
      statusCounts,
    };
  }

  /**
   * Returns counts of inquiries grouped by status.
   * Scoped to a complex when complexId is provided (null = all complexes).
   * @param {number|null} complexId
   * @returns {Promise<{ new, read, replied, total }>}
   */
  async _getStatusCounts(complexId = null) {
    const scope = complexId != null ? { sportComplexId: complexId } : {};
    const [newCount, readCount, repliedCount, total] = await Promise.all([
      ContactUs.count({ where: { ...scope, status: 'new' } }),
      ContactUs.count({ where: { ...scope, status: 'read' } }),
      ContactUs.count({ where: { ...scope, status: 'replied' } }),
      ContactUs.count({ where: { ...scope } }),
    ]);

    return { new: newCount, read: readCount, replied: repliedCount, total };
  }

  // ─── Admin: Get Single Inquiry ──────────────────────────────────────────────

  /**
   * Retrieves a single inquiry by primary key.
   * Returns null if not found or soft-deleted.
   * @param {string} id - UUID
   * @returns {Promise<ContactUs|null>}
   */
  async getInquiryById(id) {
    return ContactUs.findByPk(id);
  }

  // ─── Admin: Update Status ───────────────────────────────────────────────────

  /**
   * Updates the status of an inquiry.
   * @param {string} id - UUID
   * @param {string} status - 'new' | 'read' | 'replied'
   * @returns {Promise<ContactUs|null>} Updated inquiry, or null if not found.
   */
  async updateStatus(id, status) {
    const inquiry = await ContactUs.findByPk(id);
    if (!inquiry) return null;

    await inquiry.update({ status });
    return inquiry;
  }

  // ─── Admin: Soft Delete ─────────────────────────────────────────────────────

  /**
   * Soft-deletes an inquiry by setting the deletedAt timestamp.
   * @param {string} id - UUID
   * @returns {Promise<boolean>} true if deleted, false if not found.
   */
  async deleteInquiry(id) {
    const inquiry = await ContactUs.findByPk(id);
    if (!inquiry) return false;

    await inquiry.destroy(); // Sequelize paranoid soft delete
    return true;
  }

  // ─── CMS: Get Active Contact Information ───────────────────────────────────

  /**
   * Returns the active contact information for display on frontend.
   * When a complexId is provided, returns that complex's active entry;
   * otherwise keeps the global "most recent active" behavior.
   * @param {number|null} complexId
   * @returns {Promise<ContactInfo|null>}
   */
  async getActiveContactInfo(complexId = null) {
    const where = { isActive: true };
    if (complexId != null) {
      where.sportComplexId = complexId;
    }
    return ContactInfo.findOne({
      where,
      order: [['updatedAt', 'DESC']],
    });
  }

  // ─── Admin: Get Contact Information ────────────────────────────────────────

  /**
   * Returns the contact information for admin management.
   * Scoped to a complex when complexId is provided.
   * @param {number|null} complexId
   * @returns {Promise<ContactInfo|null>}
   */
  async getContactInfo(complexId = null) {
    const where = { isActive: true };
    if (complexId != null) {
      where.sportComplexId = complexId;
    }
    return ContactInfo.findOne({
      where,
      order: [['updatedAt', 'DESC']],
    });
  }

  // ─── Admin: List All Contact Information ───────────────────────────────────

  /**
   * Returns all contact information entries for admin management.
   * Scoped to a complex when complexId is provided.
   * @param {number|null} complexId
   * @returns {Promise<ContactInfo[]>}
   */
  async listAllContactInfo(complexId = null) {
    const where = {};
    if (complexId != null) {
      where.sportComplexId = complexId;
    }
    return ContactInfo.findAll({
      where,
      order: [['createdAt', 'DESC']],
    });
  }

  // ─── Admin: Get Contact Information By ID ──────────────────────────────────

  /**
   * Returns a single contact information entry by ID.
   * @param {string} id - UUID
   * @returns {Promise<ContactInfo|null>}
   */
  async getContactInfoById(id) {
    return ContactInfo.findByPk(id);
  }

  // ─── Admin: Create Contact Information ─────────────────────────────────────

  /**
   * Creates a new contact information entry.
   * @param {object} data - { image, address, phone, email, hours, mapEmbedUrl, description, isActive }
   * @returns {Promise<ContactInfo>}
   */
  async createContactInfo(data) {
    const { image, address, phone, email, hours, mapEmbedUrl, description, isActive, sportComplexId } = data;

    const normalizedComplexId = sportComplexId != null ? Number(sportComplexId) : null;

    // If this is being set as active, deactivate only other entries
    // belonging to the SAME complex (one active per complex).
    if (isActive) {
      const deactivateWhere = { isActive: true };
      if (normalizedComplexId != null) {
        deactivateWhere.sportComplexId = normalizedComplexId;
      }
      await ContactInfo.update(
        { isActive: false },
        { where: deactivateWhere }
      );
    }

    const contactInfo = await ContactInfo.create({
      image: image || null,
      address,
      phone,
      email,
      hours,
      mapEmbedUrl: mapEmbedUrl || null,
      description: description || null,
      isActive: isActive !== undefined ? isActive : true,
      sportComplexId: normalizedComplexId,
    });

    return contactInfo;
  }

  // ─── Admin: Update Contact Information ─────────────────────────────────────

  /**
   * Updates the contact information.
   * @param {string} id - UUID (optional, if not provided updates the active one)
   * @param {object} data - { image, address, phone, email, hours, mapEmbedUrl, description, isActive }
   * @returns {Promise<ContactInfo>}
   */
  async updateContactInfo(id, data) {
    const { image, address, phone, email, hours, mapEmbedUrl, description, isActive, sportComplexId } = data;

    let contactInfo;

    if (id) {
      // Update specific contact info by ID
      contactInfo = await ContactInfo.findByPk(id);
      if (!contactInfo) {
        throw new Error('Contact information not found');
      }

      // The complex this record belongs to — honor a stamped value if provided
      // (super admin may move it; complex admin's value is forced upstream),
      // otherwise fall back to the record's existing complex.
      const targetComplexId =
        sportComplexId !== undefined && sportComplexId !== null
          ? Number(sportComplexId)
          : contactInfo.sportComplexId;

      // If setting this as active, deactivate only other entries belonging to
      // the SAME complex (one active per complex).
      if (isActive && !contactInfo.isActive) {
        const deactivateWhere = { isActive: true };
        if (targetComplexId != null) {
          deactivateWhere.sportComplexId = targetComplexId;
        }
        await ContactInfo.update(
          { isActive: false },
          { where: deactivateWhere }
        );
      }

      await contactInfo.update({
        ...(image !== undefined && { image }),
        ...(address !== undefined && { address }),
        ...(phone !== undefined && { phone }),
        ...(email !== undefined && { email }),
        ...(hours !== undefined && { hours }),
        ...(mapEmbedUrl !== undefined && { mapEmbedUrl }),
        ...(description !== undefined && { description }),
        ...(isActive !== undefined && { isActive }),
        ...(sportComplexId !== undefined && { sportComplexId: sportComplexId != null ? Number(sportComplexId) : null }),
      });
    } else {
      // Legacy behavior: Get existing active contact info or create new one
      contactInfo = await ContactInfo.findOne({
        where: { isActive: true },
      });

      if (contactInfo) {
        // Update existing
        await contactInfo.update({
          ...(image !== undefined && { image }),
          address,
          phone,
          email,
          hours,
          ...(mapEmbedUrl !== undefined && { mapEmbedUrl }),
          ...(description !== undefined && { description }),
        });
      } else {
        // Create new
        contactInfo = await ContactInfo.create({
          image: image || null,
          address,
          phone,
          email,
          hours,
          mapEmbedUrl: mapEmbedUrl || null,
          description: description || null,
          isActive: true,
        });
      }
    }

    return contactInfo;
  }

  // ─── Admin: Delete Contact Information ─────────────────────────────────────

  /**
   * Deletes a contact information entry.
   * @param {string} id - UUID
   * @returns {Promise<boolean>} true if deleted, false if not found.
   */
  async deleteContactInfo(id) {
    const contactInfo = await ContactInfo.findByPk(id);
    if (!contactInfo) return false;

    await contactInfo.destroy();
    return true;
  }
}

module.exports = new ContactUsService();
