const bookingService = require('../services/bookingService');
const notificationService = require('../services/notificationService');
const { resolveComplexId, isComplexScoped, assertComplexAccess } = require('../middleware/complexScope');

// A booking's complex is reached through its court: booking.court.SportComplex.id
const bookingComplexId = (booking) =>
  booking && booking.court && booking.court.SportComplex ? booking.court.SportComplex.id : null;

class BookingController {
  async createBooking(req, res) {
    try {
      const { userId, sportId, courtId, date, startTime, endTime, bookingSource, transactionId } = req.body;

      // Validate required fields
      if (!userId || !sportId || !courtId || !date || !startTime || !endTime) {
        return res.status(400).json({
          success: false,
          message: 'Missing required fields: userId, sportId, courtId, date, startTime, endTime'
        });
      }

      // Create booking
      const booking = await bookingService.createBooking(req.body);

      // Send booking confirmation notification to the user
      try {
        const sportName = booking.sport?.name || `Sport #${sportId}`;
        const courtName = booking.court?.name || `Court #${courtId}`;
        await notificationService.createNotification({
          userId,
          title: 'Booking Confirmed',
          message: `Your booking for ${sportName} at ${courtName} on ${date} from ${startTime} to ${endTime} has been confirmed.`,
          type: 'Booking',
          actionUrl: `/bookings/${booking.id}`
        });
      } catch (notifErr) {
        // Non-fatal: log but don't fail the booking response
        console.warn('⚠️ Could not create booking notification:', notifErr.message);
      }

      res.status(201).json({
        success: true,
        message: 'Booking created successfully',
        data: booking
      });
    } catch (error) {
      // Determine status code based on error message
      const statusCode = error.message.includes('conflict') ? 409 :
                         error.message.includes('not found') ? 404 :
                         error.message.includes('Validation') || error.message.includes('past') || error.message.includes('before') ? 400 : 500;

      res.status(statusCode).json({
        success: false,
        message: error.message
      });
    }
  }

  async getAllBookings(req, res) {
    try {
      const filters = {
        date: req.query.date,
        userId: req.query.userId,
        sportId: req.query.sportId,
        courtId: req.query.courtId,
        paymentStatus: req.query.paymentStatus,
        bookingStatus: req.query.bookingStatus,
        bookingSource: req.query.bookingSource,
        page: req.query.page || 1,
        limit: req.query.limit || 10
      };

      // Per-complex admin scoping (via the booking's court). null = all complexes.
      const complexId = resolveComplexId(req);
      if (complexId != null) filters.sportComplexId = complexId;

      const result = await bookingService.getAllBookings(filters);

      // Return format that matches frontend expectations
      res.status(200).json({
        success: true,
        bookings: result.bookings,  // ← Changed from 'data' to 'bookings'
        total: result.totalCount,    // ← Added 'total' at root level
        totalPages: result.totalPages,
        currentPage: result.currentPage,
        pagination: {
          currentPage: result.currentPage,
          totalPages: result.totalPages,
          totalCount: result.totalCount,
          limit: parseInt(filters.limit)
        }
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        message: 'Failed to retrieve bookings',
        error: error.message
      });
    }
  }

  async getBookingById(req, res) {
    try {
      const { id } = req.params;

      if (!id) {
        return res.status(400).json({
          success: false,
          message: 'Booking ID is required'
        });
      }

      const booking = await bookingService.getBookingById(id);

      // Complex admins can only view bookings in their own complex
      if (!assertComplexAccess(req, res, bookingComplexId(booking))) return;

      res.status(200).json({
        success: true,
        data: booking
      });
    } catch (error) {
      const statusCode = error.message.includes('not found') ? 404 : 500;

      res.status(statusCode).json({
        success: false,
        message: error.message
      });
    }
  }

  async updateBooking(req, res) {
    try {
      const { id } = req.params;

      if (!id) {
        return res.status(400).json({
          success: false,
          message: 'Booking ID is required'
        });
      }

      // Check ownership for USER role
      if (req.user && req.user.role === 'USER') {
        const booking = await bookingService.getBookingById(id);
        if (booking.userId !== req.user.id) {
          return res.status(403).json({
            success: false,
            message: 'You can only update your own bookings'
          });
        }
      }

      // Complex admins may only update bookings in their own complex
      // Complex-scoped staff (complex admin, employee, coach, security) may only
      // touch bookings in their own complex.
      if (isComplexScoped(req)) {
        const booking = await bookingService.getBookingById(id);
        if (!assertComplexAccess(req, res, bookingComplexId(booking))) return;
      }

      const updatedBooking = await bookingService.updateBooking(id, req.body);

      // Notify user if booking status changed
      if (req.body.bookingStatus && updatedBooking.userId) {
        try {
          const statusMessages = {
            Confirmed: 'Your booking has been confirmed.',
            Cancelled: 'Your booking has been cancelled.',
            Completed: 'Your booking has been marked as completed.',
            Pending: 'Your booking is pending confirmation.'
          };
          const statusMsg = statusMessages[req.body.bookingStatus] || `Your booking status has been updated to ${req.body.bookingStatus}.`;
          await notificationService.createNotification({
            userId: updatedBooking.userId,
            title: `Booking ${req.body.bookingStatus}`,
            message: statusMsg,
            type: 'Booking',
            actionUrl: `/bookings/${id}`
          });
        } catch (notifErr) {
          console.warn('⚠️ Could not create booking status notification:', notifErr.message);
        }
      }

      res.status(200).json({
        success: true,
        message: 'Booking updated successfully',
        data: updatedBooking
      });
    } catch (error) {
      const statusCode = error.message.includes('conflict') ? 409 :
                         error.message.includes('not found') ? 404 :
                         error.message.includes('Validation') || error.message.includes('past') || error.message.includes('before') ? 400 : 500;

      res.status(statusCode).json({
        success: false,
        message: error.message
      });
    }
  }

  async deleteBooking(req, res) {
    try {
      const { id } = req.params;

      if (!id) {
        return res.status(400).json({
          success: false,
          message: 'Booking ID is required'
        });
      }

      // Check ownership for USER role
      if (req.user && req.user.role === 'USER') {
        const booking = await bookingService.getBookingById(id);
        if (booking.userId !== req.user.id) {
          return res.status(403).json({
            success: false,
            message: 'You can only cancel your own bookings'
          });
        }
      }

      // Complex admins may only cancel bookings in their own complex
      // Complex-scoped staff (complex admin, employee, coach, security) may only
      // touch bookings in their own complex.
      if (isComplexScoped(req)) {
        const booking = await bookingService.getBookingById(id);
        if (!assertComplexAccess(req, res, bookingComplexId(booking))) return;
      }

      const result = await bookingService.deleteBooking(id);

      res.status(200).json({
        success: true,
        message: result.message
      });
    } catch (error) {
      const statusCode = error.message.includes('not found') ? 404 :
                         error.message.includes('already cancelled') ? 400 : 500;

      res.status(statusCode).json({
        success: false,
        message: error.message
      });
    }
  }

  async getBookingStats(req, res) {
    try {
      const stats = await bookingService.getBookingStats(resolveComplexId(req));

      res.status(200).json({
        success: true,
        data: stats
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        message: 'Failed to retrieve booking statistics',
        error: error.message
      });
    }
  }

  async getCurrentBookings(req, res) {
    try {
      const bookings = await bookingService.getCurrentBookings(resolveComplexId(req));

      res.status(200).json({
        success: true,
        data: bookings
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        message: 'Failed to retrieve current bookings',
        error: error.message
      });
    }
  }
}

module.exports = new BookingController();
