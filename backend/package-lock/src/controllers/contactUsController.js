'use strict';

const contactUsService = require('../services/contactUsService');
const {
  resolveComplexId,
  stampComplexId,
  assertComplexAccess,
} = require('../middleware/complexScope');

/**
 * ContactUsController
 * Handles HTTP request/response logic for all contact-us endpoints.
 * Delegates all business logic and DB operations to ContactUsService.
 */
class ContactUsController {
  // ─── Public: Submit Contact Form ───────────────────────────────────────────

  /**
   * POST /api/v1/contact-us
   * Publicly accessible — no authentication required.
   * Captures IP address and User-Agent metadata from the request.
   */
  async submitContactForm(req, res, next) {
    try {
      const { fullName, email, subject, message, sportComplexId } = req.body;

      // Resolve client IP — trust X-Forwarded-For when behind a proxy/load balancer
      const ipAddress =
        (req.headers['x-forwarded-for'] || '').split(',')[0].trim() ||
        req.ip ||
        null;

      const userAgent = req.headers['user-agent'] || null;

      const inquiry = await contactUsService.createSubmission({
        fullName,
        email,
        subject,
        message,
        ipAddress,
        userAgent,
        sportComplexId, // optional — website sends it; sanitized in service
      });

      return res.status(201).json({
        success: true,
        message: 'Your message has been sent successfully.',
        data: {
          referenceNumber: inquiry.referenceNumber,
        },
      });
    } catch (error) {
      next(error);
    }
  }

  // ─── Admin: List Inquiries ──────────────────────────────────────────────────

  /**
   * GET /api/v1/admin/contact-us
   * Returns a paginated, searchable, filterable list of inquiries.
   * Query params: page, limit, search, status, sortBy, sortOrder
   */
  async listInquiries(req, res, next) {
    try {
      const { page, limit, search, status, sortBy, sortOrder } = req.query;

      const complexId = resolveComplexId(req);

      const result = await contactUsService.listInquiries({
        page,
        limit,
        search,
        status,
        sortBy,
        sortOrder,
        complexId,
      });

      return res.status(200).json({
        success: true,
        data: result,
      });
    } catch (error) {
      next(error);
    }
  }

  // ─── Admin: Get Single Inquiry ──────────────────────────────────────────────

  /**
   * GET /api/v1/admin/contact-us/:id
   * Returns full details of a single inquiry including metadata.
   */
  async getInquiry(req, res, next) {
    try {
      const { id } = req.params;

      const inquiry = await contactUsService.getInquiryById(id);

      if (!inquiry) {
        return res.status(404).json({
          success: false,
          message: 'Inquiry not found.',
        });
      }

      // Per-complex guard for complex admins
      if (!assertComplexAccess(req, res, inquiry.sportComplexId)) return;

      // Format createdAt for display
      const formattedInquiry = {
        ...inquiry.toJSON(),
        createdAtFormatted: new Date(inquiry.createdAt).toLocaleString('en-IN', {
          timeZone: 'Asia/Kolkata',
          dateStyle: 'medium',
          timeStyle: 'short',
        }),
      };

      return res.status(200).json({
        success: true,
        data: { inquiry: formattedInquiry },
      });
    } catch (error) {
      next(error);
    }
  }

  // ─── Admin: Update Status ───────────────────────────────────────────────────

  /**
   * PATCH /api/v1/admin/contact-us/:id/status
   * Updates the lifecycle status of an inquiry.
   */
  async updateStatus(req, res, next) {
    try {
      const { id } = req.params;
      const { status } = req.body;

      // Load first so a complex admin can be guarded before mutating
      const existing = await contactUsService.getInquiryById(id);

      if (!existing) {
        return res.status(404).json({
          success: false,
          message: 'Inquiry not found.',
        });
      }

      // Per-complex guard for complex admins
      if (!assertComplexAccess(req, res, existing.sportComplexId)) return;

      const inquiry = await contactUsService.updateStatus(id, status);

      if (!inquiry) {
        return res.status(404).json({
          success: false,
          message: 'Inquiry not found.',
        });
      }

      return res.status(200).json({
        success: true,
        message: 'Status updated successfully.',
        data: { inquiry },
      });
    } catch (error) {
      next(error);
    }
  }

  // ─── Admin: Soft Delete ─────────────────────────────────────────────────────

  /**
   * DELETE /api/v1/admin/contact-us/:id
   * Soft-deletes an inquiry (sets deletedAt, record is preserved for audit).
   */
  async deleteInquiry(req, res, next) {
    try {
      const { id } = req.params;

      // Load first so a complex admin can be guarded before deleting
      const existing = await contactUsService.getInquiryById(id);

      if (!existing) {
        return res.status(404).json({
          success: false,
          message: 'Inquiry not found.',
        });
      }

      // Per-complex guard for complex admins
      if (!assertComplexAccess(req, res, existing.sportComplexId)) return;

      const deleted = await contactUsService.deleteInquiry(id);

      if (!deleted) {
        return res.status(404).json({
          success: false,
          message: 'Inquiry not found.',
        });
      }

      return res.status(200).json({
        success: true,
        message: 'Inquiry deleted successfully.',
      });
    } catch (error) {
      next(error);
    }
  }

  // ─── Public: Get Contact Information ───────────────────────────────────────

  /**
   * GET /api/v1/contact-us/info
   * Returns active contact information for frontend display.
   */
  async getContactInfo(req, res, next) {
    try {
      // Public endpoint — optional ?sportComplexId= narrows to one complex.
      const raw = req.query.sportComplexId;
      const complexId =
        raw !== undefined && raw !== null && raw !== '' && !Number.isNaN(Number(raw))
          ? Number(raw)
          : null;

      const contactInfo = await contactUsService.getActiveContactInfo(complexId);

      if (!contactInfo) {
        return res.status(404).json({
          success: false,
          message: 'Contact information not found.',
        });
      }

      return res.status(200).json({
        success: true,
        data: { contactInfo },
      });
    } catch (error) {
      next(error);
    }
  }

  // ─── Admin: Get Contact Information for Management ─────────────────────────

  /**
   * GET /api/v1/admin/contact-us/info
   * Returns contact information for admin management.
   */
  async getContactInfoAdmin(req, res, next) {
    try {
      const complexId = resolveComplexId(req);
      const contactInfo = await contactUsService.getContactInfo(complexId);

      if (!contactInfo) {
        return res.status(404).json({
          success: false,
          message: 'Contact information not found.',
        });
      }

      return res.status(200).json({
        success: true,
        data: contactInfo,
      });
    } catch (error) {
      next(error);
    }
  }

  // ─── Admin: List All Contact Information ───────────────────────────────────

  /**
   * GET /api/v1/admin/contact-us/info/list
   * Returns all contact information entries for admin management.
   */
  async listAllContactInfo(req, res, next) {
    try {
      const complexId = resolveComplexId(req);
      const contactInfoList = await contactUsService.listAllContactInfo(complexId);

      return res.status(200).json({
        success: true,
        data: contactInfoList,
      });
    } catch (error) {
      next(error);
    }
  }

  // ─── Admin: Get Contact Information By ID ──────────────────────────────────

  /**
   * GET /api/v1/admin/contact-us/info/:id
   * Returns a single contact information entry by ID.
   */
  async getContactInfoById(req, res, next) {
    try {
      const { id } = req.params;

      const contactInfo = await contactUsService.getContactInfoById(id);

      if (!contactInfo) {
        return res.status(404).json({
          success: false,
          message: 'Contact information not found.',
        });
      }

      // Per-complex guard for complex admins
      if (!assertComplexAccess(req, res, contactInfo.sportComplexId)) return;

      return res.status(200).json({
        success: true,
        data: contactInfo,
      });
    } catch (error) {
      next(error);
    }
  }

  // ─── Admin: Create Contact Information ─────────────────────────────────────

  /**
   * POST /api/v1/admin/contact-us/info
   * Creates a new contact information entry.
   */
  async createContactInfo(req, res, next) {
    try {
      const { image, address, phone, email, hours, mapEmbedUrl, description, isActive } = req.body;

      // Force the complex for a complex admin; honor body value for super admin
      const data = stampComplexId(req, {
        image,
        address,
        phone,
        email,
        hours,
        mapEmbedUrl,
        description,
        isActive,
      });

      const contactInfo = await contactUsService.createContactInfo(data);

      return res.status(201).json({
        success: true,
        message: 'Contact information created successfully.',
        data: contactInfo,
      });
    } catch (error) {
      next(error);
    }
  }

  // ─── Admin: Update Contact Information ─────────────────────────────────────

  /**
   * PUT /api/v1/admin/contact-us/info/:id
   * Updates the contact information by ID.
   */
  async updateContactInfoById(req, res, next) {
    try {
      const { id } = req.params;
      const { image, address, phone, email, hours, mapEmbedUrl, description, isActive } = req.body;

      // Load first so a complex admin can be guarded before mutating
      const existing = await contactUsService.getContactInfoById(id);

      if (!existing) {
        return res.status(404).json({
          success: false,
          message: 'Contact information not found.',
        });
      }

      // Per-complex guard for complex admins
      if (!assertComplexAccess(req, res, existing.sportComplexId)) return;

      // stampComplexId forces a complex admin's complex (cannot move the record);
      // super admin may move it via body.sportComplexId.
      const data = stampComplexId(req, {
        image,
        address,
        phone,
        email,
        hours,
        mapEmbedUrl,
        description,
        isActive,
      });

      const contactInfo = await contactUsService.updateContactInfo(id, data);

      return res.status(200).json({
        success: true,
        message: 'Contact information updated successfully.',
        data: contactInfo,
      });
    } catch (error) {
      next(error);
    }
  }

  // ─── Admin: Update Contact Information (Legacy) ────────────────────────────

  /**
   * PUT /api/v1/admin/contact-us/info
   * Updates the active contact information (legacy endpoint).
   */
  async updateContactInfo(req, res, next) {
    try {
      const { image, address, phone, email, hours, mapEmbedUrl, description } = req.body;

      const contactInfo = await contactUsService.updateContactInfo(null, {
        image,
        address,
        phone,
        email,
        hours,
        mapEmbedUrl,
        description,
      });

      return res.status(200).json({
        success: true,
        message: 'Contact information updated successfully.',
        data: contactInfo,
      });
    } catch (error) {
      next(error);
    }
  }

  // ─── Admin: Delete Contact Information ─────────────────────────────────────

  /**
   * DELETE /api/v1/admin/contact-us/info/:id
   * Deletes a contact information entry.
   */
  async deleteContactInfo(req, res, next) {
    try {
      const { id } = req.params;

      // Load first so a complex admin can be guarded before deleting
      const existing = await contactUsService.getContactInfoById(id);

      if (!existing) {
        return res.status(404).json({
          success: false,
          message: 'Contact information not found.',
        });
      }

      // Per-complex guard for complex admins
      if (!assertComplexAccess(req, res, existing.sportComplexId)) return;

      const deleted = await contactUsService.deleteContactInfo(id);

      if (!deleted) {
        return res.status(404).json({
          success: false,
          message: 'Contact information not found.',
        });
      }

      return res.status(200).json({
        success: true,
        message: 'Contact information deleted successfully.',
      });
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new ContactUsController();
