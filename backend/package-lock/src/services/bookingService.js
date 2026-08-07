const { Booking, User, Sport, Court, SportComplex } = require('../models');
const { Op } = require('sequelize');

class BookingService {
  // Create a new booking
  async createBooking(bookingData) {
    try {
      // Validate booking data
      await this.validateBookingData(bookingData);

      // Check for booking conflicts
      const conflict = await this.checkBookingConflict(
        bookingData.courtId,
        bookingData.date,
        bookingData.startTime,
        bookingData.endTime
      );

      if (conflict.hasConflict) {
        throw new Error(
          `Booking conflict detected. Court is already booked from ${conflict.conflictingBooking.startTime} to ${conflict.conflictingBooking.endTime}`
        );
      }

      // Verify court exists and is available
      const court = await Court.findByPk(bookingData.courtId);
      if (!court) {
        throw new Error('Court not found');
      }

      // Create booking
      const booking = await Booking.create({
        ...bookingData,
        paymentStatus: bookingData.paymentStatus || 'Pending',
        isDeleted: false
      });

      // Keep user's total_bookings counter in sync
      await User.increment('total_bookings', { where: { id: bookingData.userId } });

      // Staff-created bookings are Confirmed (and usually already Paid), so the
      // pass can be issued right away. An unpaid Pending row gets none — it only
      // earns a pass once the payment lands (see updateBooking).
      if (booking.paymentStatus === 'Paid' || booking.bookingStatus === 'Confirmed') {
        await require('./courtService').issueBookingPass(booking);
      }

      // Return booking with associations
      return await this.getBookingById(booking.id);
    } catch (error) {
      throw new Error(`Failed to create booking: ${error.message}`);
    }
  }

  // Get all bookings with optional filters
  async getAllBookings(filters = {}) {
    try {
      const { 
        date, 
        userId, 
        sportId, 
        courtId, 
        paymentStatus,
        bookingStatus,  // ← Added bookingStatus filter
        bookingSource,
        sportComplexId, // Per-complex admin scoping (via the booking's court)
        page = 1,
        limit = 10
      } = filters;

      // Slot blocks live in this table but are not bookings — nobody reserved
      // them and no money is attached, so they never belong in this list.
      const whereClause = { isDeleted: false, isBlocked: false };

      if (date) whereClause.date = date;
      if (userId) whereClause.userId = userId;
      if (sportId) whereClause.sportId = sportId;
      if (courtId) whereClause.courtId = courtId;
      if (paymentStatus) whereClause.paymentStatus = paymentStatus;
      if (bookingStatus) whereClause.bookingStatus = bookingStatus;  // ← Added bookingStatus filter
      if (bookingSource) whereClause.bookingSource = bookingSource;

      const offset = (parseInt(page) - 1) * parseInt(limit);

      // A booking belongs to a complex through its court. When scoped, constrain the
      // court include to that complex and make it required so non-matching bookings drop.
      const courtInclude = {
        model: Court,
        as: 'court',
        attributes: ['id', 'name', 'hourlyRate', 'status'],
        include: [{ model: SportComplex, attributes: ['id', 'name', 'city'] }],
      };
      if (sportComplexId != null) {
        courtInclude.where = { sportComplexId };
        courtInclude.required = true;
      }

      const { count, rows } = await Booking.findAndCountAll({
        where: whereClause,
        include: [
          {
            model: User,
            as: 'user',
            attributes: ['id', 'name', 'email', 'phone_number']
          },
          {
            model: Sport,
            as: 'sport',
            attributes: ['id', 'name', 'category', 'image']
          },
          courtInclude
        ],
        limit: parseInt(limit),
        offset: parseInt(offset),
        order: [['createdAt', 'DESC']],
        distinct: true
      });

      return {
        bookings: rows,
        totalCount: count,
        currentPage: parseInt(page),
        totalPages: Math.ceil(count / parseInt(limit))
      };
    } catch (error) {
      throw new Error(`Failed to fetch bookings: ${error.message}`);
    }
  }

  // Get booking by ID
  async getBookingById(id) {
    try {
      const booking = await Booking.findOne({
        where: { id, isDeleted: false },
        include: [
          {
            model: User,
            as: 'user',
            attributes: ['id', 'name', 'email', 'phone_number']
          },
          {
            model: Sport,
            as: 'sport',
            attributes: ['id', 'name', 'category', 'image']
          },
          {
            model: Court,
            as: 'court',
            attributes: ['id', 'name', 'hourlyRate', 'status'],
            include: [{ model: SportComplex, attributes: ['id', 'name', 'city'] }],
          }
        ]
      });

      if (!booking) {
        throw new Error('Booking not found');
      }

      return booking;
    } catch (error) {
      throw new Error(`Failed to fetch booking: ${error.message}`);
    }
  }

  // Update booking
  async updateBooking(id, updateData) {
    try {
      const booking = await Booking.findOne({
        where: { id, isDeleted: false }
      });

      if (!booking) {
        throw new Error('Booking not found');
      }

      // A blank customerName clears the override so the booking falls back to
      // the linked account's name, rather than showing an empty name.
      if (Object.prototype.hasOwnProperty.call(updateData, 'customerName')) {
        const trimmed = typeof updateData.customerName === 'string' ? updateData.customerName.trim() : '';
        updateData.customerName = trimmed ? trimmed.slice(0, 120) : null;
      }

      // If time slot is being changed, check for conflicts
      if (updateData.date || updateData.startTime || updateData.endTime) {
        const courtId = updateData.courtId || booking.courtId;
        const date = updateData.date || booking.date;
        const startTime = updateData.startTime || booking.startTime;
        const endTime = updateData.endTime || booking.endTime;

        const conflict = await this.checkBookingConflict(
          courtId,
          date,
          startTime,
          endTime,
          id // Exclude current booking from conflict check
        );

        if (conflict.hasConflict) {
          throw new Error(
            `Booking conflict detected. Court is already booked from ${conflict.conflictingBooking.startTime} to ${conflict.conflictingBooking.endTime}`
          );
        }
      }

      // Update booking
      await booking.update(updateData);

      // ── Pass issuance on manual confirmation ────────────────────────────────
      // A booking pass is minted only once the booking is really paid (online
      // verification, or staff marking an offline/cash booking as Paid here) or
      // staff explicitly confirm it. An unpaid Pending hold stays pass-less.
      //
      // Uses courtService.isPassEligible rather than its own condition so this
      // agrees with the gate scanner. The old inline check accepted any
      // Confirmed booking, which meant clicking Refund (paymentStatus only,
      // bookingStatus untouched) MINTED a pass for a booking already refunded.
      const courtService = require('./courtService');
      const isPaid = booking.paymentStatus === 'Paid';

      if (isPaid && booking.holdExpiresAt) {
        // Payment settled → the slot hold becomes a permanent booking.
        await booking.update({ holdExpiresAt: null });
      }
      if (courtService.isPassEligible(booking)) {
        await courtService.issueBookingPass(booking);
      }

      // Return updated booking with associations
      return await this.getBookingById(id);
    } catch (error) {
      throw new Error(`Failed to update booking: ${error.message}`);
    }
  }

  // Soft delete booking
  async deleteBooking(id) {
    try {
      const booking = await Booking.findByPk(id);

      if (!booking) {
        throw new Error('Booking not found');
      }

      if (booking.isDeleted) {
        throw new Error('Booking is already cancelled');
      }

      await booking.update({ isDeleted: true });

      // Keep user's total_bookings counter in sync (don't go below 0)
      await User.decrement('total_bookings', {
        where: { id: booking.userId, total_bookings: { [Op.gt]: 0 } }
      });

      return { message: 'Booking cancelled successfully' };
    } catch (error) {
      throw new Error(`Failed to cancel booking: ${error.message}`);
    }
  }

  // Get booking statistics
  async getBookingStats(sportComplexId = null) {
    try {
      // When scoped to a complex, every count/group joins the booking's court and
      // requires it to belong to that complex.
      const scopeInclude = sportComplexId != null
        ? [{ model: Court, as: 'court', attributes: [], where: { sportComplexId }, required: true }]
        : [];
      // Slot blocks are rows in this table but not bookings — excluded from every
      // count below so blocking a court never inflates the dashboard numbers.
      const scoped = (where) => ({
        where: { ...where, isBlocked: false },
        include: scopeInclude,
        ...(sportComplexId != null ? { distinct: true, col: 'id' } : {}),
      });

      const totalBookings = await Booking.count(scoped({ isDeleted: false }));

      // Today's bookings
      const today = new Date().toISOString().split('T')[0];
      const todayBookings = await Booking.count(scoped({
        date: today,
        isDeleted: false
      }));

      // Current month's bookings
      const currentDate = new Date();
      const firstDayOfMonth = new Date(currentDate.getFullYear(), currentDate.getMonth(), 1);
      const lastDayOfMonth = new Date(currentDate.getFullYear(), currentDate.getMonth() + 1, 0);

      const monthBookings = await Booking.count(scoped({
        date: {
          [Op.between]: [
            firstDayOfMonth.toISOString().split('T')[0],
            lastDayOfMonth.toISOString().split('T')[0]
          ]
        },
        isDeleted: false
      }));

      // Group by payment status
      const paymentStatusStats = await Booking.findAll({
        attributes: [
          'paymentStatus',
          [Booking.sequelize.fn('COUNT', Booking.sequelize.col('Booking.id')), 'count']
        ],
        where: { isDeleted: false, isBlocked: false },
        include: scopeInclude,
        group: ['paymentStatus']
      });

      const byPaymentStatus = {};
      paymentStatusStats.forEach(stat => {
        byPaymentStatus[stat.paymentStatus] = parseInt(stat.dataValues.count);
      });

      // Group by booking source
      const bookingSourceStats = await Booking.findAll({
        attributes: [
          'bookingSource',
          [Booking.sequelize.fn('COUNT', Booking.sequelize.col('Booking.id')), 'count']
        ],
        where: { isDeleted: false, isBlocked: false },
        include: scopeInclude,
        group: ['bookingSource']
      });

      const byBookingSource = {};
      bookingSourceStats.forEach(stat => {
        byBookingSource[stat.bookingSource] = parseInt(stat.dataValues.count);
      });

      return {
        totalBookings,
        todayBookings,
        monthBookings,
        byPaymentStatus,
        byBookingSource
      };
    } catch (error) {
      throw new Error(`Failed to fetch booking statistics: ${error.message}`);
    }
  }

  // Check for booking conflicts
  async checkBookingConflict(courtId, date, startTime, endTime, excludeBookingId = null) {
    try {
      const whereClause = {
        courtId,
        date,
        isDeleted: false
      };

      if (excludeBookingId) {
        whereClause.id = { [Op.ne]: excludeBookingId };
      }

      const existingBookings = await Booking.findAll({
        where: whereClause
      });

      // Check for time overlap
      for (const booking of existingBookings) {
        const requestStart = new Date(`1970-01-01T${startTime}`);
        const requestEnd = new Date(`1970-01-01T${endTime}`);
        const existingStart = new Date(`1970-01-01T${booking.startTime}`);
        const existingEnd = new Date(`1970-01-01T${booking.endTime}`);

        // Conflict if: requestStart < existingEnd AND requestEnd > existingStart
        if (requestStart < existingEnd && requestEnd > existingStart) {
          return {
            hasConflict: true,
            conflictingBooking: booking
          };
        }
      }

      return { hasConflict: false };
    } catch (error) {
      throw new Error(`Failed to check booking conflict: ${error.message}`);
    }
  }

  // Validate booking data
  async validateBookingData(bookingData) {
    const errors = [];

    // Required fields
    if (!bookingData.userId) errors.push('User ID is required');
    if (!bookingData.sportId) errors.push('Sport ID is required');
    if (!bookingData.courtId) errors.push('Court ID is required');
    if (!bookingData.date) errors.push('Date is required');
    if (!bookingData.startTime) errors.push('Start time is required');
    if (!bookingData.endTime) errors.push('End time is required');

    if (errors.length > 0) {
      throw new Error(`Validation failed: ${errors.join(', ')}`);
    }

    // Validate date is not in the past
    const bookingDate = new Date(bookingData.date);
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    if (bookingDate < today) {
      throw new Error('Booking date cannot be in the past');
    }

    // Validate startTime < endTime
    const startTime = new Date(`1970-01-01T${bookingData.startTime}`);
    const endTime = new Date(`1970-01-01T${bookingData.endTime}`);

    if (startTime >= endTime) {
      throw new Error('Start time must be before end time');
    }

    // Verify foreign keys exist
    const user = await User.findByPk(bookingData.userId);
    if (!user) {
      throw new Error('User not found');
    }

    const sport = await Sport.findByPk(bookingData.sportId);
    if (!sport) {
      throw new Error('Sport not found');
    }

    const court = await Court.findByPk(bookingData.courtId);
    if (!court) {
      throw new Error('Court not found');
    }

    return true;
  }

  // Get current/today's bookings for dashboard
  async getCurrentBookings(sportComplexId = null) {
    try {
      const today = new Date().toISOString().split('T')[0];

      const courtInclude = {
        model: Court,
        as: 'court',
        attributes: ['id', 'name'],
        include: [
          {
            model: SportComplex,
            attributes: ['id', 'name', 'city']
          }
        ]
      };
      if (sportComplexId != null) {
        courtInclude.where = { sportComplexId };
        courtInclude.required = true;
      }

      const bookings = await Booking.findAll({
        where: {
          date: today,
          isDeleted: false,
          bookingStatus: {
            [Op.in]: ['Confirmed', 'Pending']
          }
        },
        include: [
          {
            model: User,
            as: 'user',
            attributes: ['id', 'name', 'email', 'phone_number']
          },
          courtInclude,
          {
            model: Sport,
            as: 'sport',
            attributes: ['id', 'name']
          }
        ],
        order: [['startTime', 'ASC']],
        limit: 10 // Show only first 10 bookings
      });

      return bookings;
    } catch (error) {
      throw new Error(`Failed to fetch current bookings: ${error.message}`);
    }
  }
}

module.exports = new BookingService();

