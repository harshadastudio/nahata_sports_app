const { Op, fn, col, literal } = require('sequelize');
const { 
  User,
  Booking,
  Membership,
  Payment,
  StudentBatches,
  SportComplex,
  Court,
  Sport,
  Coach,
  Student,
  Batch
} = require('../models');

// --- Per-complex admin reporting scoping helpers -------------------------------
// `complexId` is the id a COMPLEX_ADMIN must be restricted to (or a super-admin
// opt-in filter). When it is null/undefined every helper is a no-op, so super
// admin / other roles behave exactly as before.

// Direct-column models (have a sportComplexId column: Batch, Coach, Court, ...).
const withComplex = (where, complexId) =>
  complexId != null ? { ...where, sportComplexId: complexId } : where;

// Booking counts/aggregates scope through the booking's Court.
// For count({distinct,col,include}) the col must be UNqualified ('id') — Sequelize
// resolves it against the main model alias; a qualified 'Booking.id' breaks the SQL.
const bookingScope = (complexId) =>
  complexId != null
    ? { include: [{ model: Court, as: 'court', attributes: [], where: { sportComplexId: complexId }, required: true }], distinct: true, col: 'id' }
    : {};

/**
 * Total collected revenue between two dates (both optional = all time).
 *
 * The Payments table is never written to by the app, so revenue is summed from
 * the records that actually hold the money — the same three sources the admin
 * Payments page aggregates:
 *   1. Bookings.totalAmount        where paymentStatus = 'Paid'   (court bookings)
 *   2. EventPassBookings.totalAmount where status = 'Confirmed'   (event passes)
 *   3. StudentBatches.amountPaid                                  (coaching fees)
 *
 * `complexId` scopes court bookings through Court.sportComplexId and coaching
 * fees through Batch.sportComplexId. Event bookings carry the complex on the
 * event, so they are scoped through EventPass.sportComplexId.
 */
async function computeTotalRevenue(startDate, endDate, complexId = null) {
  const { EventPassBooking, EventPass } = require('../models');
  const inRange = startDate && endDate ? { [Op.between]: [startDate, endDate] } : undefined;

  // 1. Court bookings
  const courtWhere = { isDeleted: false, isBlocked: false, paymentStatus: 'Paid' };
  if (inRange) courtWhere.createdAt = inRange;
  const courtRevenue = await Booking.sum('totalAmount', {
    where: courtWhere,
    ...(complexId != null
      ? { include: [{ model: Court, as: 'court', attributes: [], where: { sportComplexId: complexId }, required: true }] }
      : {}),
  });

  // 2. Event pass bookings
  const eventWhere = { status: 'Confirmed' };
  if (inRange) eventWhere.createdAt = inRange;
  const eventRevenue = await EventPassBooking.sum('totalAmount', {
    where: eventWhere,
    ...(complexId != null
      ? { include: [{ model: EventPass, as: 'event', attributes: [], where: { sportComplexId: complexId }, required: true }] }
      : {}),
  });

  // 3. Coaching fees actually collected
  const feeWhere = {};
  if (inRange) feeWhere.createdAt = inRange;
  const feeRevenue = await StudentBatches.sum('amountPaid', {
    where: feeWhere,
    ...(complexId != null
      ? { include: [{ model: Batch, as: 'batch', attributes: [], where: { sportComplexId: complexId }, required: true }] }
      : {}),
  });

  return (
    parseFloat(courtRevenue || 0) +
    parseFloat(eventRevenue || 0) +
    parseFloat(feeRevenue || 0)
  );
}

// Student counts/aggregates scope through the Batches the student is enrolled in.
const studentScope = (complexId) =>
  complexId != null
    ? { include: [{ model: Batch, as: 'Batches', attributes: [], where: { sportComplexId: complexId }, required: true }], distinct: true, col: 'id' }
    : {};

// StudentBatches (enrollments) scope through the related Batch (alias 'batch').
const enrollmentScope = (complexId) =>
  complexId != null
    ? { include: [{ model: Batch, as: 'batch', attributes: [], where: { sportComplexId: complexId }, required: true }], distinct: true, col: 'id' }
    : {};

// --- Shared small helpers ------------------------------------------------------

/**
 * Percentage change with an explicit "no baseline" signal.
 *
 * Returning a flat +100% whenever the previous period was empty made every card
 * on a young dataset read "+100%", which is what made the dashboard look stale.
 * `hasBaseline: false` lets the UI print "New" instead of a meaningless number.
 */
function pctChange(current, previous) {
  if (previous > 0) {
    return { value: ((current - previous) / previous) * 100, hasBaseline: true };
  }
  return { value: 0, hasBaseline: false, isNew: current > 0 };
}

/**
 * Format a Date as YYYY-MM-DD in LOCAL time. `toISOString()` shifts to UTC, so
 * local midnight in IST would be reported as the previous day.
 */
function toLocalISODate(d) {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

/** 'HH:MM[:SS]' (Sequelize TIME) → minutes past midnight; null when unparseable. */
function timeToMinutes(t) {
  if (t == null) return null;
  if (t instanceof Date) return t.getHours() * 60 + t.getMinutes();
  const m = /^(\d{1,2}):(\d{2})/.exec(String(t));
  if (!m) return null;
  return Number(m[1]) * 60 + Number(m[2]);
}

/** Duration of a booking in hours, defaulting to 1h when the times are unusable. */
function bookingHours(booking) {
  const start = timeToMinutes(booking.startTime);
  const end = timeToMinutes(booking.endTime);
  if (start == null || end == null) return 1;
  // An end before the start means the slot crosses midnight.
  const minutes = end > start ? end - start : end + 24 * 60 - start;
  return minutes > 0 ? minutes / 60 : 1;
}

class ReportsService {
  /**
   * Get dashboard overview with KPIs
   */
  async getDashboardOverview(dateRange = {}, complexId = null) {
    const { startDate, endDate } = dateRange;

    // Total users (website-level, not complex-scoped). The card is labelled
    // "Total Active App Users", so Blocked accounts must not be counted.
    const totalUsers = await User.count({ where: { status: 'Active' } });

    // Total students - directly from Students table (scoped through Batches)
    const totalStudents = await Student.count({ ...studentScope(complexId) });

    // New students. Counted over the selected range when one is supplied, else
    // the last 30 days. `enrollmentDate` is null on legacy student rows, so fall
    // back to createdAt — otherwise those students silently vanish from the count.
    const newFrom = startDate ? new Date(startDate) : (() => {
      const d = new Date(); d.setDate(d.getDate() - 30); return d;
    })();
    const newTo = endDate ? new Date(endDate) : new Date();

    const newStudentsCount = await Student.count({
      where: {
        [Op.or]: [
          { enrollmentDate: { [Op.between]: [newFrom, newTo] } },
          { enrollmentDate: null, createdAt: { [Op.between]: [newFrom, newTo] } }
        ]
      },
      ...studentScope(complexId)
    });

    // Calculate new students percentage (new students / total students * 100)
    const newStudentsPercentage = totalStudents > 0 
      ? ((newStudentsCount / totalStudents) * 100).toFixed(1)
      : 0;

    // Active memberships
    const activeMemberships = await Membership.count({
      where: { 
        status: 'Active'
      }
    });

    // Total bookings (for date range if provided)
    const bookingWhere = { isDeleted: false, isBlocked: false };
    if (startDate && endDate) {
      bookingWhere.date = {
        [Op.between]: [startDate, endDate]
      };
    }
    const totalBookings = await Booking.count({ where: bookingWhere, ...bookingScope(complexId) });

    // Total revenue.
    //
    // Summed from the records that actually hold the money, NOT the Payments
    // table: nothing in the app writes Payment rows (it is empty in production),
    // so the old `Payment.paymentStatus = 'Completed'` sum always returned 0 and
    // the dashboard reported ₹0 revenue. These are the same three sources the
    // admin Payments page aggregates, so the two screens now agree:
    //   1. court bookings marked Paid
    //   2. event pass bookings marked Confirmed
    //   3. coaching fees collected against an enrollment
    const totalRevenue = await computeTotalRevenue(startDate, endDate, complexId);

    // Today's bookings
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);
    
    const todayBookings = await Booking.count({
      where: {
        date: {
          [Op.between]: [today, tomorrow]
        },
        isDeleted: false, isBlocked: false
      },
      ...bookingScope(complexId)
    });

    // Upcoming bookings (next 7 days)
    const next7Days = new Date(today);
    next7Days.setDate(next7Days.getDate() + 7);
    
    const upcomingBookings = await Booking.count({
      where: {
        date: {
          [Op.between]: [tomorrow, next7Days]
        },
        isDeleted: false, isBlocked: false
      },
      ...bookingScope(complexId)
    });

    // Active coaching enrollments (scoped through the enrollment's Batch)
    const activeEnrollments = await StudentBatches.count({
      where: { status: 'Active' },
      ...enrollmentScope(complexId)
    });

    // Active sports complexes and courts
    const activeSportsComplexes = await SportComplex.count({
      where: { status: 'Active' }
    });

    const totalCourts = await Court.count({ where: withComplex({}, complexId) });

    // Total coaches
    const totalCoaches = await Coach.count({ where: withComplex({}, complexId) });

    // --- Comparison window -----------------------------------------------------
    // Every % badge on this page compares the selected window against the equally
    // long window immediately before it. With no explicit range that is the last
    // 30 days vs the prior 30, which is what the card copy claims.
    const trendNow = new Date();
    const windowStart = startDate ? new Date(startDate) : (() => {
      const d = new Date(trendNow); d.setDate(d.getDate() - 30); return d;
    })();
    const windowEnd = endDate ? new Date(endDate) : trendNow;
    const windowMs = Math.max(windowEnd - windowStart, 24 * 60 * 60 * 1000);
    const priorStart = new Date(windowStart.getTime() - windowMs);

    const recentRange = { [Op.between]: [windowStart, windowEnd] };
    const priorRange  = { [Op.between]: [priorStart, windowStart] };

    // Revenue for the window vs the one before it (previously only computed when
    // an explicit range was passed, so the card always showed 0.0%).
    const previousPeriodRevenue = await computeTotalRevenue(priorStart, windowStart, complexId);
    const windowRevenue = startDate && endDate
      ? totalRevenue
      : await computeTotalRevenue(windowStart, windowEnd, complexId);
    const revenueChange = pctChange(windowRevenue, previousPeriodRevenue);

    const [
      bookingsRecent, bookingsPrior,
      studentsRecent, studentsPrior,
      usersRecent,    usersPrior,
      coachesRecent,  coachesPrior,
    ] = await Promise.all([
      Booking.count({ where: { isDeleted: false, isBlocked: false, createdAt: recentRange }, ...bookingScope(complexId) }),
      Booking.count({ where: { isDeleted: false, isBlocked: false, createdAt: priorRange  }, ...bookingScope(complexId) }),
      Student.count({ where: { createdAt: recentRange }, ...studentScope(complexId) }),
      Student.count({ where: { createdAt: priorRange  }, ...studentScope(complexId) }),
      User.count({ where: { status: 'Active', createdAt: recentRange } }),
      User.count({ where: { status: 'Active', createdAt: priorRange  } }),
      Coach.count({ where: withComplex({ createdAt: recentRange }, complexId) }),
      Coach.count({ where: withComplex({ createdAt: priorRange  }, complexId) }),
    ]);

    const bookingsChange = pctChange(bookingsRecent, bookingsPrior);
    const studentsChange = pctChange(studentsRecent, studentsPrior);
    const usersChange    = pctChange(usersRecent, usersPrior);
    const coachesChange  = pctChange(coachesRecent, coachesPrior);

    return {
      totalUsers,
      totalStudents,
      newStudentsCount,
      newStudentsPercentage,
      activeMemberships,
      totalBookings,
      totalRevenue,
      todayBookings,
      upcomingBookings,
      activeEnrollments,
      activeSportsComplexes,
      totalCourts,
      totalCoaches,
      // The window each % badge is measured over, so the UI can label it.
      period: {
        startDate: toLocalISODate(windowStart),
        endDate: toLocalISODate(windowEnd),
        comparedToStart: toLocalISODate(priorStart),
      },
      // Raw counts behind each badge — useful for tooltips and for spotting
      // "no baseline" cases instead of printing a fake +100%.
      periodCounts: {
        bookings: bookingsRecent, bookingsPrior,
        students: studentsRecent, studentsPrior,
        users: usersRecent,       usersPrior,
        coaches: coachesRecent,   coachesPrior,
        revenue: windowRevenue,   revenuePrior: previousPeriodRevenue,
      },
      revenueChange: revenueChange.value.toFixed(2),
      revenueTrendIsNew: !revenueChange.hasBaseline && Boolean(revenueChange.isNew),
      bookingsTrend: bookingsChange.value.toFixed(1),
      bookingsTrendIsNew: !bookingsChange.hasBaseline && Boolean(bookingsChange.isNew),
      studentsTrend: studentsChange.value.toFixed(1),
      studentsTrendIsNew: !studentsChange.hasBaseline && Boolean(studentsChange.isNew),
      usersTrend:    usersChange.value.toFixed(1),
      usersTrendIsNew: !usersChange.hasBaseline && Boolean(usersChange.isNew),
      coachesTrend:  coachesChange.value.toFixed(1),
      coachesTrendIsNew: !coachesChange.hasBaseline && Boolean(coachesChange.isNew),
    };
  }

  /**
   * Get revenue analytics
   */
  async getRevenueAnalytics(dateRange = {}, complexId = null) {
    // PAYMENT FALLBACK: every metric here is Payment-based. Payment has no direct
    // sportComplexId and only some payments tie to a Booking (bookingId is null
    // for membership/coaching payments), so scoping via Booking->Court would
    // silently drop legitimate revenue. Left UNSCOPED intentionally; complexId is
    // accepted for signature parity but not applied. See report.
    const { startDate, endDate } = dateRange;
    const whereClause = {
      paymentStatus: 'Completed',
      ...(startDate && endDate && {
        createdAt: {
          [Op.between]: [startDate, endDate]
        }
      })
    };

    // Total revenue
    const totalRevenueResult = await Payment.findOne({
      attributes: [[fn('SUM', col('amount')), 'total']],
      where: whereClause,
      raw: true
    });
    const totalRevenue = parseFloat(totalRevenueResult?.total || 0);

    // Revenue by payment method
    const revenueByMethod = await Payment.findAll({
      attributes: [
        'paymentMethod',
        [fn('SUM', col('amount')), 'total'],
        [fn('COUNT', col('id')), 'count']
      ],
      where: whereClause,
      group: ['paymentMethod'],
      raw: true
    });

    // Revenue by source. The Payment model has no `type` column (original bug);
    // derive a source from whether the payment is tied to a court booking.
    const sourceExpr = literal(`CASE WHEN "bookingId" IS NOT NULL THEN 'Booking' ELSE 'Other' END`);
    const revenueBySource = await Payment.findAll({
      attributes: [
        [sourceExpr, 'type'],
        [fn('SUM', col('amount')), 'total'],
        [fn('COUNT', col('id')), 'count']
      ],
      where: whereClause,
      group: [sourceExpr],
      raw: true
    });

    // Payment status distribution
    const paymentStatusDist = await Payment.findAll({
      attributes: [
        'paymentStatus',
        [fn('COUNT', col('id')), 'count']
      ],
      where: startDate && endDate ? {
        createdAt: {
          [Op.between]: [startDate, endDate]
        }
      } : {},
      group: ['paymentStatus'],
      raw: true
    });

    // Average transaction value
    const avgTransactionResult = await Payment.findOne({
      attributes: [[fn('AVG', col('amount')), 'average']],
      where: whereClause,
      raw: true
    });
    const avgTransaction = parseFloat(avgTransactionResult?.average || 0);

    // Daily revenue trends
    const dailyRevenue = await Payment.findAll({
      attributes: [
        [fn('DATE', col('createdAt')), 'date'],
        [fn('SUM', col('amount')), 'revenue']
      ],
      where: whereClause,
      group: [fn('DATE', col('createdAt'))],
      order: [[fn('DATE', col('createdAt')), 'ASC']],
      raw: true
    });

    // Total transactions
    const totalTransactions = await Payment.count({ where: whereClause });

    // Success rate
    const successfulPayments = await Payment.count({
      where: {
        ...whereClause,
        paymentStatus: 'Completed'
      }
    });
    const totalPaymentAttempts = await Payment.count({
      where: startDate && endDate ? {
        createdAt: {
          [Op.between]: [startDate, endDate]
        }
      } : {}
    });
    const successRate = totalPaymentAttempts > 0 
      ? ((successfulPayments / totalPaymentAttempts) * 100).toFixed(2)
      : 0;

    return {
      totalRevenue,
      revenueByMethod,
      revenueBySource,
      paymentStatusDist,
      avgTransaction,
      dailyRevenue,
      totalTransactions,
      successRate
    };
  }

  /**
   * Get booking analytics
   */
  async getBookingAnalytics(dateRange = {}, complexId = null) {
    const { startDate, endDate } = dateRange;
    const whereClause = {
      isDeleted: false, isBlocked: false,
      ...(startDate && endDate && {
        date: {
          [Op.between]: [startDate, endDate]
        }
      })
    };

    // Complex scoping is applied via the booking's Court (alias 'court').
    // For grouped aggregates we add a required court include; for that reason all
    // COUNTs below qualify the column to 'Booking.id' to avoid ambiguity.
    const scopedCourtInclude = complexId != null
      ? [{ model: Court, as: 'court', attributes: [], where: { sportComplexId: complexId }, required: true }]
      : [];

    // Total bookings
    const totalBookings = await Booking.count({ where: whereClause, ...bookingScope(complexId) });

    // Bookings by status
    const bookingsByStatus = await Booking.findAll({
      attributes: [
        'bookingStatus',
        [fn('COUNT', col('Booking.id')), 'count']
      ],
      include: scopedCourtInclude,
      where: whereClause,
      group: ['bookingStatus'],
      raw: true
    });

    // Bookings by source
    const bookingsBySource = await Booking.findAll({
      attributes: [
        'bookingSource',
        [fn('COUNT', col('Booking.id')), 'count']
      ],
      include: scopedCourtInclude,
      where: whereClause,
      group: ['bookingSource'],
      raw: true
    });

    // Bookings by sport. Court→Sport has no association alias, so Sequelize joins it
    // under the default alias 'Sport' — the column/group refs must match ('court.Sport').
    const bookingsBySport = await Booking.findAll({
      attributes: [
        [col('court.Sport.name'), 'sportName'],
        [fn('COUNT', col('Booking.id')), 'count']
      ],
      include: [{
        model: Court,
        as: 'court',
        attributes: [],
        ...(complexId != null && { where: { sportComplexId: complexId }, required: true }),
        include: [{
          model: Sport,
          attributes: []
        }]
      }],
      where: whereClause,
      group: [col('court.Sport.name')],
      raw: true
    });

    // Average booking duration and total hours.
    // Postgres: startTime/endTime are `time` columns; subtract → interval, then
    // EXTRACT(EPOCH)/3600 → hours. (The original used MySQL's TIMESTAMPDIFF.)
    const durationHoursExpr = 'EXTRACT(EPOCH FROM ("Booking"."endTime" - "Booking"."startTime")) / 3600';
    const durationStats = await Booking.findOne({
      attributes: [
        [literal(`AVG(${durationHoursExpr})`), 'avgDuration'],
        [literal(`SUM(${durationHoursExpr})`), 'totalHours']
      ],
      include: scopedCourtInclude,
      where: whereClause,
      raw: true
    });

    // Cancellation rate
    const cancelledBookings = await Booking.count({
      where: {
        ...whereClause,
        bookingStatus: 'Cancelled'
      },
      ...bookingScope(complexId)
    });
    const cancellationRate = totalBookings > 0 
      ? ((cancelledBookings / totalBookings) * 100).toFixed(2)
      : 0;

    return {
      totalBookings,
      bookingsByStatus,
      bookingsBySource,
      bookingsBySport,
      avgDuration: parseFloat(durationStats?.avgDuration || 0).toFixed(2),
      totalHours: parseInt(durationStats?.totalHours || 0),
      cancellationRate
    };
  }

  /**
   * Get membership analytics
   */
  async getMembershipAnalytics(dateRange = {}, complexId = null) {
    // Memberships are website-level (no sportComplexId) and are intentionally
    // NOT complex-scoped. complexId accepted for signature parity only.
    const { startDate, endDate } = dateRange;

    // NOTE: Membership is paranoid (soft delete via deletedAt) — Sequelize excludes
    // deleted rows automatically, so no isDeleted filter is needed. The grouping
    // column is `planName` (the model has no `planType`).

    // Active memberships
    const activeMemberships = await Membership.count({
      where: { status: 'Active' }
    });

    // Memberships by plan
    const membershipsByPlan = await Membership.findAll({
      attributes: [
        'planName',
        [fn('COUNT', col('id')), 'count']
      ],
      group: ['planName'],
      raw: true
    });

    // Memberships by status
    const membershipsByStatus = await Membership.findAll({
      attributes: [
        'status',
        [fn('COUNT', col('id')), 'count']
      ],
      group: ['status'],
      raw: true
    });

    // New enrollments over time
    const enrollmentTrends = await Membership.findAll({
      attributes: [
        [fn('DATE', col('startDate')), 'date'],
        [fn('COUNT', col('id')), 'count']
      ],
      where: {
        ...(startDate && endDate && {
          startDate: {
            [Op.between]: [startDate, endDate]
          }
        })
      },
      group: [fn('DATE', col('startDate'))],
      order: [[fn('DATE', col('startDate')), 'ASC']],
      raw: true
    });

    // Upcoming expirations (next 30 days)
    const today = new Date();
    const next30Days = new Date(today);
    next30Days.setDate(next30Days.getDate() + 30);

    const upcomingExpirations = await Membership.count({
      where: {
        status: 'Active',
        endDate: {
          [Op.between]: [today, next30Days]
        }
      }
    });

    // Revenue by plan
    const revenueByPlan = await Membership.findAll({
      attributes: [
        'planName',
        [fn('SUM', col('price')), 'revenue']
      ],
      where: { status: 'Active' },
      group: ['planName'],
      raw: true
    });

    return {
      activeMemberships,
      membershipsByPlan,
      membershipsByStatus,
      enrollmentTrends,
      upcomingExpirations,
      revenueByPlan
    };
  }

  /**
   * Get user analytics
   */
  async getUserAnalytics(dateRange = {}, complexId = null) {
    // Users are global/website-level and intentionally NOT complex-scoped, except
    // topUsers which is Booking-derived and IS scoped through the booking's Court.
    const { startDate, endDate } = dateRange;

    // NOTE: User has no soft-delete column, so no isDeleted filter is applied.

    // Total users
    const totalUsers = await User.count();

    // Users by role
    const usersByRole = await User.findAll({
      attributes: [
        'role',
        [fn('COUNT', col('id')), 'count']
      ],
      group: ['role'],
      raw: true
    });

    // Users by status
    const usersByStatus = await User.findAll({
      attributes: [
        'status',
        [fn('COUNT', col('id')), 'count']
      ],
      group: ['status'],
      raw: true
    });

    // New registrations over time
    const registrationTrends = await User.findAll({
      attributes: [
        [fn('DATE', col('createdAt')), 'date'],
        [fn('COUNT', col('id')), 'count']
      ],
      where: {
        ...(startDate && endDate && {
          createdAt: {
            [Op.between]: [startDate, endDate]
          }
        })
      },
      group: [fn('DATE', col('createdAt'))],
      order: [[fn('DATE', col('createdAt')), 'ASC']],
      raw: true
    });

    // Top 10 most active users by booking count
    const topUsers = await Booking.findAll({
      attributes: [
        'userId',
        [fn('COUNT', col('Booking.id')), 'bookingCount']
      ],
      include: [
        {
          model: User,
          as: 'user',
          attributes: ['name', 'email']
        },
        ...(complexId != null
          ? [{ model: Court, as: 'court', attributes: [], where: { sportComplexId: complexId }, required: true }]
          : [])
      ],
      where: { isDeleted: false, isBlocked: false },
      group: ['userId', 'user.id', 'user.name', 'user.email'],
      order: [[fn('COUNT', col('Booking.id')), 'DESC']],
      limit: 10,
      raw: true
    });

    return {
      totalUsers,
      usersByRole,
      usersByStatus,
      registrationTrends,
      topUsers
    };
  }

  /**
   * Get coaching analytics
   */
  async getCoachingAnalytics(dateRange = {}, complexId = null) {
    // Coaching offerings are now Batches. Output keys are kept (activePrograms,
    // enrollmentsByProgram, programsManaged, ...) for reporting-UI compatibility.
    // Batch has a direct sportComplexId column; enrollments scope through 'batch'.

    // Active batches
    const activePrograms = await Batch.count({
      where: withComplex({ status: 'Active' }, complexId)
    });

    // Total enrollments (scoped through the enrollment's Batch)
    const totalEnrollments = await StudentBatches.count({
      where: { status: 'Active' },
      ...enrollmentScope(complexId)
    });

    // Batches by sport
    const programsBySport = await Batch.findAll({
      attributes: [
        [col('sport.name'), 'sportName'],
        [fn('COUNT', col('Batch.id')), 'count']
      ],
      include: [{
        model: Sport,
        as: 'sport',
        attributes: []
      }],
      where: withComplex({}, complexId),
      group: [col('sport.name')],
      raw: true
    });

    // Enrollment count per batch (output keyed as programId/programName for UI compat)
    const enrollmentsByProgram = await StudentBatches.findAll({
      attributes: [
        ['batchId', 'programId'],
        [col('batch.name'), 'programName'],
        [fn('COUNT', col('StudentBatches.id')), 'enrollmentCount']
      ],
      include: [{
        model: Batch,
        as: 'batch',
        attributes: [],
        ...(complexId != null && { where: { sportComplexId: complexId }, required: true })
      }],
      where: { status: 'Active' },
      group: ['batchId', col('batch.name')],
      raw: true
    });

    // Batches by status
    const programsByStatus = await Batch.findAll({
      attributes: [
        'status',
        [fn('COUNT', col('id')), 'count']
      ],
      where: withComplex({}, complexId),
      group: ['status'],
      raw: true
    });

    // Coach performance metrics (batches managed, under legacy key programsManaged)
    // Coach has a direct sportComplexId column; the counted Batches are also
    // constrained to the complex so a complex admin sees only in-complex figures.
    const coachMetrics = await Coach.findAll({
      attributes: [
        'id',
        'name',
        [fn('COUNT', col('Batches.id')), 'programsManaged']
      ],
      include: [{
        model: Batch,
        as: 'Batches',
        attributes: [],
        ...(complexId != null && { where: { sportComplexId: complexId } })
      }],
      where: withComplex({}, complexId),
      group: ['Coach.id'],
      raw: true
    });

    return {
      activePrograms,
      totalEnrollments,
      programsBySport,
      enrollmentsByProgram,
      programsByStatus,
      coachMetrics
    };
  }

  /**
   * Get facility utilization analytics
   */
  async getFacilityAnalytics(dateRange = {}, complexId = null) {
    const { startDate, endDate } = dateRange;

    // Sports complexes by status — the SportComplex entity itself is website-level
    // and intentionally NOT complex-scoped.
    const complexesByStatus = await SportComplex.findAll({
      attributes: [
        'status',
        [fn('COUNT', col('id')), 'count']
      ],
      group: ['status'],
      raw: true
    });

    // Courts by sport (Court has a direct sportComplexId column)
    const courtsBySport = await Court.findAll({
      attributes: [
        [col('Sport.name'), 'sportName'],
        [fn('COUNT', col('Court.id')), 'count']
      ],
      include: [{
        model: Sport,
        attributes: []
      }],
      where: withComplex({}, complexId),
      group: [col('Sport.name')],
      raw: true
    });

    // Booking count per sports complex (scoped through the booking's Court)
    const bookingsByComplex = await Booking.findAll({
      attributes: [
        [col('court.SportComplex.name'), 'complexName'],
        [fn('COUNT', col('Booking.id')), 'bookingCount']
      ],
      include: [{
        model: Court,
        as: 'court',
        attributes: [],
        ...(complexId != null && { where: { sportComplexId: complexId }, required: true }),
        include: [{
          model: SportComplex,
          attributes: []
        }]
      }],
      where: {
        isDeleted: false, isBlocked: false,
        ...(startDate && endDate && {
          date: {
            [Op.between]: [startDate, endDate]
          }
        })
      },
      group: [col('court.SportComplex.name')],
      raw: true
    });

    // Total courts
    const totalCourts = await Court.count({ where: withComplex({}, complexId) });

    return {
      complexesByStatus,
      courtsBySport,
      bookingsByComplex,
      totalCourts
    };
  }
  /**
   * Get all bookings with filters
   */
  async getAllBookings(filters = {}, complexId = null) {
    const {
      month,
      year,
      sportComplexId,
      sportId,
      bookingSource,
      page = 1,
      limit = 50
    } = filters;

    const whereClause = { isDeleted: false, isBlocked: false };
    const include = [
      {
        model: User,
        as: 'user',
        attributes: ['id', 'name', 'email', 'phone_number']
      },
      {
        model: Sport,
        as: 'sport',
        attributes: ['id', 'name', 'image']
      },
      {
        model: Court,
        as: 'court',
        attributes: ['id', 'name', 'sportComplexId'],
        include: [{
          model: SportComplex,
          attributes: ['id', 'name', 'address', 'city']
        }]
      }
    ];

    // Filter by month and year
    if (month && year) {
      const startDate = new Date(year, month - 1, 1);
      const endDate = new Date(year, month, 0);
      whereClause.date = {
        [Op.between]: [startDate, endDate]
      };
    }

    // Filter by booking source
    if (bookingSource) {
      whereClause.bookingSource = bookingSource;
    }

    // Filter by sport
    if (sportId) {
      whereClause.sportId = sportId;
    }

    // Filter by sports complex (through court).
    // A complex admin's complexId always wins and cannot be widened by the param.
    const effectiveComplexId = complexId != null ? complexId : sportComplexId;
    if (effectiveComplexId) {
      include[2].where = { sportComplexId: effectiveComplexId };
      include[2].required = true;
    }

    const offset = (page - 1) * limit;

    const { count, rows } = await Booking.findAndCountAll({
      where: whereClause,
      include,
      limit,
      offset,
      order: [['date', 'DESC'], ['startTime', 'DESC']],
      distinct: true
    });

    return {
      bookings: rows,
      total: count,
      page,
      totalPages: Math.ceil(count / limit)
    };
  }

  /**
   * Get filter options for bookings
   */
  async getBookingFilterOptions(complexId = null) {
    // Get unique booking sources (scoped through the booking's Court)
    const sources = await Booking.findAll({
      attributes: [[fn('DISTINCT', col('bookingSource')), 'source']],
      include: complexId != null
        ? [{ model: Court, as: 'court', attributes: [], where: { sportComplexId: complexId }, required: true }]
        : [],
      where: { isDeleted: false, isBlocked: false },
      raw: true
    });

    // Get sports complexes (a complex admin only sees their own)
    const complexes = await SportComplex.findAll({
      attributes: ['id', 'name', 'city'],
      where: complexId != null ? { status: 'Active', id: complexId } : { status: 'Active' },
      order: [['name', 'ASC']]
    });

    // Get sports (Sport has a direct sportComplexId column)
    const sports = await Sport.findAll({
      attributes: ['id', 'name'],
      where: withComplex({ status: 'Active' }, complexId),
      order: [['name', 'ASC']]
    });

    return {
      sources: sources.map(s => s.source).filter(Boolean),
      complexes,
      sports
    };
  }

  /**
   * Get all students with filters
   */
  async getAllStudents(filters = {}, complexId = null) {
    const {
      month,
      batchId,
      sportComplexId,
      status,
      page = 1,
      limit = 50
    } = filters;

    const whereClause = {};
    const include = [
      {
        model: User,
        as: 'User',
        attributes: ['id', 'name', 'email', 'phone_number', 'dob', 'gender']
      }
    ];

    // Filter by enrollment month (current year)
    if (month) {
      const currentYear = new Date().getFullYear();
      const startDate = new Date(currentYear, month - 1, 1);
      const endDate = new Date(currentYear, month, 0);
      whereClause.enrollmentDate = {
        [Op.between]: [startDate, endDate]
      };
    }

    // Filter by status
    if (status) {
      whereClause.status = status;
    }

    // Build batch include - optional, not required
    const batchInclude = {
      model: Batch,
      through: { attributes: [] },
      required: false, // Show all students, even those not in batches
      attributes: ['id', 'name', 'schedule', 'days', 'sportComplexId'],
      include: [{
        model: Sport,
        as: 'sport',
        attributes: ['id', 'name']
      }, {
        model: SportComplex,
        as: 'sportComplex',
        attributes: ['id', 'name', 'city']
      }]
    };

    // Build batch where clause for filters
    const batchWhere = {};
    
    // Filter by specific batch
    if (batchId) {
      batchWhere.id = batchId;
      batchInclude.required = true; // When filtering by batch, require the batch
    }

    // Filter by sports complex. A complex admin's complexId always wins and
    // forces the Batch include to be required so out-of-complex students drop.
    const effectiveComplexId = complexId != null ? complexId : sportComplexId;
    if (effectiveComplexId) {
      batchWhere.sportComplexId = effectiveComplexId;
      batchInclude.required = true; // When filtering by complex, require the batch
    }

    // Apply batch where clause if any filters are set
    if (Object.keys(batchWhere).length > 0) {
      batchInclude.where = batchWhere;
    }

    include.push(batchInclude);

    const offset = (page - 1) * limit;

    const { count, rows } = await Student.findAndCountAll({
      where: whereClause,
      include,
      limit,
      offset,
      order: [['enrollmentDate', 'DESC']],
      distinct: true
    });

    return {
      students: rows,
      total: count,
      page,
      totalPages: Math.ceil(count / limit)
    };
  }

  /**
   * Get filter options for students
   */
  async getStudentFilterOptions(complexId = null) {
    // Get active batches with sport complex info (Batch has a direct sportComplexId)
    const batches = await Batch.findAll({
      attributes: ['id', 'name', 'schedule', 'days', 'sportComplexId'],
      where: withComplex({ status: 'Active' }, complexId),
      include: [{
        model: Sport,
        as: 'sport',
        attributes: ['id', 'name']
      }, {
        model: SportComplex,
        as: 'sportComplex',
        attributes: ['id', 'name', 'city']
      }],
      order: [['name', 'ASC']]
    });

    // Get sports complexes (a complex admin only sees their own)
    const complexes = await SportComplex.findAll({
      attributes: ['id', 'name', 'city'],
      where: complexId != null ? { status: 'Active', id: complexId } : { status: 'Active' },
      order: [['name', 'ASC']]
    });

    // Get student statuses
    const statuses = ['Active', 'Inactive', 'Graduated', 'Transferred'];

    return {
      batches,
      complexes,
      statuses
    };
  }

  /**
   * Get new students with retention rate calculation
   * Retention Rate (%) = (Students Continued This Month ÷ Students Enrolled Last Month) × 100
   */
  async getNewStudents(filters = {}, complexId = null) {
    const {
      month,
      batchId,
      sportComplexId,
      sportId,
      retentionRatio,
      page = 1,
      limit = 50
    } = filters;

    // Calculate date ranges
    const currentDate = new Date();
    const currentYear = currentDate.getFullYear();
    const currentMonth = currentDate.getMonth() + 1;
    
    // Last month date range (for retention calculation)
    const lastMonthDate = new Date(currentYear, currentMonth - 2, 1);
    const lastMonthStart = new Date(lastMonthDate.getFullYear(), lastMonthDate.getMonth(), 1);
    const lastMonthEnd = new Date(lastMonthDate.getFullYear(), lastMonthDate.getMonth() + 1, 0);
    
    // This month date range (for retention calculation)
    const thisMonthStart = new Date(currentYear, currentMonth - 1, 1);

    // Build batch include for retention calculation
    const batchIncludeForRetention = {
      model: Batch,
      through: { attributes: [] },
      required: false, // Make it optional to get all students
      attributes: ['id', 'name', 'schedule', 'days', 'sportComplexId', 'sportId'],
      include: [{
        model: Sport,
        as: 'sport',
        attributes: ['id', 'name']
      }, {
        model: SportComplex,
        as: 'sportComplex',
        attributes: ['id', 'name', 'city']
      }]
    };

    // Build batch where clause for filters
    const batchWhere = {};
    
    if (batchId) {
      batchWhere.id = batchId;
    }

    // A complex admin's complexId always wins over any param value.
    const effectiveComplexId = complexId != null ? complexId : sportComplexId;
    if (effectiveComplexId) {
      batchWhere.sportComplexId = effectiveComplexId;
    }

    if (sportId) {
      batchWhere.sportId = sportId;
    }

    // Apply batch filters if any
    if (Object.keys(batchWhere).length > 0) {
      batchIncludeForRetention.where = batchWhere;
      batchIncludeForRetention.required = true;
    }

    // Get students enrolled last month (for retention calculation)
    const studentsEnrolledLastMonth = await Student.findAll({
      where: {
        enrollmentDate: {
          [Op.between]: [lastMonthStart, lastMonthEnd]
        }
      },
      include: [batchIncludeForRetention],
      distinct: true
    });

    const enrolledLastMonthCount = studentsEnrolledLastMonth.length;

    // Check which students continued this month (still Active)
    const continuedStudentIds = studentsEnrolledLastMonth
      .filter(s => s.status === 'Active')
      .map(s => s.id);

    const continuedThisMonthCount = continuedStudentIds.length;

    // Calculate retention rate
    const retentionRate = enrolledLastMonthCount > 0 
      ? (continuedThisMonthCount / enrolledLastMonthCount) * 100 
      : 0;

    // Now build the main query for displaying students
    // If month filter is provided, show students from that month
    // Otherwise, show all students (or students from current month)
    let displayWhereClause = {};
    
    if (month) {
      const displayStart = new Date(currentYear, month - 1, 1);
      const displayEnd = new Date(currentYear, month, 0);
      displayWhereClause.enrollmentDate = {
        [Op.between]: [displayStart, displayEnd]
      };
    }
    // If no month filter, show all students or apply other filters

    // Build batch include for main query
    const batchInclude = {
      model: Batch,
      through: { attributes: [] },
      required: Object.keys(batchWhere).length > 0, // Required only if filtering by batch/complex/sport
      attributes: ['id', 'name', 'schedule', 'days', 'sportComplexId', 'sportId'],
      include: [{
        model: Sport,
        as: 'sport',
        attributes: ['id', 'name']
      }, {
        model: SportComplex,
        as: 'sportComplex',
        attributes: ['id', 'name', 'city']
      }]
    };

    if (Object.keys(batchWhere).length > 0) {
      batchInclude.where = batchWhere;
    }

    // Build include for main query
    const include = [
      {
        model: User,
        as: 'User',
        attributes: ['id', 'name', 'email', 'phone_number', 'dob', 'gender']
      },
      batchInclude
    ];

    // Apply retention ratio filter
    // This filters the displayed students by their current status, not by last month's retention
    if (retentionRatio === 'continued') {
      displayWhereClause.status = 'Active';
    } else if (retentionRatio === 'discontinued') {
      displayWhereClause.status = { [Op.ne]: 'Active' };
    }

    const offset = (page - 1) * limit;

    const { count, rows } = await Student.findAndCountAll({
      where: displayWhereClause,
      include,
      limit,
      offset,
      order: [['enrollmentDate', 'DESC']],
      distinct: true
    });

    // Add 'continued' flag to each student based on their current status
    const studentsWithContinuedFlag = rows.map(student => ({
      ...student.toJSON(),
      continued: student.status === 'Active'
    }));

    return {
      students: studentsWithContinuedFlag,
      total: count,
      page,
      totalPages: Math.ceil(count / limit),
      retentionRate,
      enrolledLastMonth: enrolledLastMonthCount,
      continuedThisMonth: continuedThisMonthCount
    };
  }

  /**
   * Get filter options for new students
   */
  async getNewStudentFilterOptions(complexId = null) {
    // Get active batches (Batch has a direct sportComplexId column)
    const batches = await Batch.findAll({
      attributes: ['id', 'name', 'schedule', 'days', 'sportComplexId', 'sportId'],
      where: withComplex({ status: 'Active' }, complexId),
      include: [{
        model: Sport,
        as: 'sport',
        attributes: ['id', 'name']
      }, {
        model: SportComplex,
        as: 'sportComplex',
        attributes: ['id', 'name', 'city']
      }],
      order: [['name', 'ASC']]
    });

    // Get sports complexes (a complex admin only sees their own)
    const complexes = await SportComplex.findAll({
      attributes: ['id', 'name', 'city'],
      where: complexId != null ? { status: 'Active', id: complexId } : { status: 'Active' },
      order: [['name', 'ASC']]
    });

    // Get sports (Sport has a direct sportComplexId column)
    const sports = await Sport.findAll({
      attributes: ['id', 'name'],
      where: withComplex({ status: 'Active' }, complexId),
      order: [['name', 'ASC']]
    });

    return {
      batches,
      complexes,
      sports
    };
  }

  /**
   * Get all coaches with filters and calculate revenue/students
   */
  async getAllCoaches(filters = {}, complexId = null) {
    const {
      month,
      year,
      batchId,
      page = 1,
      limit = 50
    } = filters;

    // Coach has a direct sportComplexId column.
    const whereClause = withComplex({}, complexId);

    // Filter by joining month and year
    if (month || year) {
      const dateFilter = {};
      
      if (year && month) {
        const startDate = new Date(year, month - 1, 1);
        const endDate = new Date(year, month, 0);
        dateFilter[Op.between] = [startDate, endDate];
      } else if (year) {
        const startDate = new Date(year, 0, 1);
        const endDate = new Date(year, 11, 31);
        dateFilter[Op.between] = [startDate, endDate];
      } else if (month) {
        // Filter by month across all years
        whereClause[Op.and] = literal(`MONTH(createdAt) = ${month}`);
      }
      
      if (Object.keys(dateFilter).length > 0) {
        whereClause.createdAt = dateFilter;
      }
    }

    // Build batch include - Coach doesn't have direct association, so we'll query separately
    const offset = (page - 1) * limit;

    const { count, rows } = await Coach.findAndCountAll({
      where: whereClause,
      limit,
      offset,
      order: [['createdAt', 'DESC']],
      distinct: true
    });

    // For each coach, get their batches and calculate stats
    const coachesWithStats = await Promise.all(rows.map(async (coach) => {
      const coachData = coach.toJSON();
      
      // Get batches for this coach (also constrained to the complex)
      const batchWhere = withComplex({
        coachId: coach.id,
        status: 'Active'
      }, complexId);

      if (batchId) {
        batchWhere.id = batchId;
      }
      
      const batches = await Batch.findAll({
        where: batchWhere,
        attributes: ['id', 'name', 'fees', 'currentStudents'],
        include: [{
          model: Sport,
          as: 'sport',
          attributes: ['id', 'name']
        }]
      });
      
      // Calculate total students and revenue from batches
      let totalStudents = 0;
      let totalRevenue = 0;
      
      batches.forEach(batch => {
        const batchData = batch.toJSON();
        totalStudents += batchData.currentStudents || 0;
        totalRevenue += (batchData.currentStudents || 0) * parseFloat(batchData.fees || 0);
      });
      
      return {
        ...coachData,
        Batches: batches.map(b => b.toJSON()),
        totalStudents,
        totalRevenue
      };
    }));

    // Filter out coaches with no batches if batchId filter is applied
    const filteredCoaches = batchId 
      ? coachesWithStats.filter(coach => coach.Batches.length > 0)
      : coachesWithStats;

    // Calculate overall totals
    const totalStudentsAll = filteredCoaches.reduce((sum, coach) => sum + coach.totalStudents, 0);
    const totalRevenueAll = filteredCoaches.reduce((sum, coach) => sum + coach.totalRevenue, 0);

    return {
      coaches: filteredCoaches,
      total: batchId ? filteredCoaches.length : count,
      page,
      totalPages: Math.ceil((batchId ? filteredCoaches.length : count) / limit),
      totalStudents: totalStudentsAll,
      totalRevenue: totalRevenueAll
    };
  }

  /**
   * Get filter options for coaches
   */
  async getCoachFilterOptions(complexId = null) {
    // Get active batches (Batch has a direct sportComplexId column)
    const batches = await Batch.findAll({
      attributes: ['id', 'name'],
      where: withComplex({ status: 'Active' }, complexId),
      include: [{
        model: Sport,
        as: 'sport',
        attributes: ['id', 'name']
      }],
      order: [['name', 'ASC']]
    });

    return {
      batches
    };
  }
  /**
   * Get booking trends for chart
   */
  async getBookingTrends(range = '30days', complexId = null) {
    const days = range === '7days' ? 7 : range === '90days' ? 90 : 30;
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - days);

    // Booking trends scope through the booking's Court (alias 'court').
    const scopedCourtInclude = complexId != null
      ? [{ model: Court, as: 'court', attributes: [], where: { sportComplexId: complexId }, required: true }]
      : [];

    try {
      // Count and revenue in ONE grouped query. The old version ran a follow-up
      // query per date (N+1) and summed EVERY booking's amount — including
      // Pending/Failed ones — so the trend line disagreed with Total Revenue.
      const rows = await Booking.findAll({
        attributes: [
          [fn('DATE', col('Booking.date')), 'date'],
          [fn('COUNT', col('Booking.id')), 'bookings'],
          [
            fn('SUM', literal(`CASE WHEN "Booking"."paymentStatus" = 'Paid' THEN "Booking"."totalAmount" ELSE 0 END`)),
            'revenue'
          ]
        ],
        include: scopedCourtInclude,
        where: {
          isDeleted: false, isBlocked: false,
          date: {
            [Op.gte]: startDate
          }
        },
        group: [fn('DATE', col('Booking.date'))],
        order: [[fn('DATE', col('Booking.date')), 'ASC']],
        raw: true
      });

      return rows.map((r) => ({
        date: typeof r.date === 'string' ? r.date.slice(0, 10) : new Date(r.date).toISOString().slice(0, 10),
        bookings: parseInt(r.bookings, 10) || 0,
        revenue: parseFloat(r.revenue || 0)
      }));
    } catch (error) {
      console.error('Error fetching booking trends:', error);
      return [];
    }
  }

  /**
   * Get revenue by court for chart
   */
  async getRevenueByCourtChart(range = '30days', complexId = null) {
    const days = range === '7days' ? 7 : range === '90days' ? 90 : 30;
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - days);

    try {
      const courtRevenue = await Booking.findAll({
        attributes: [
          [col('court.name'), 'courtName'],
          // Collected money only, so the bars match the Total Revenue card.
          [
            fn('SUM', literal(`CASE WHEN "Booking"."paymentStatus" = 'Paid' THEN "Booking"."totalAmount" ELSE 0 END`)),
            'revenue'
          ],
          [fn('COUNT', col('Booking.id')), 'bookings']
        ],
        include: [{
          model: Court,
          as: 'court',
          attributes: [],
          ...(complexId != null && { where: { sportComplexId: complexId }, required: true })
        }],
        where: {
          isDeleted: false, isBlocked: false,
          date: {
            [Op.gte]: startDate
          }
        },
        group: [col('court.name')],
        order: [[literal(`SUM(CASE WHEN "Booking"."paymentStatus" = 'Paid' THEN "Booking"."totalAmount" ELSE 0 END)`), 'DESC']],
        raw: true
      });

      return courtRevenue.map(item => ({
        courtName: item.courtName || 'Unknown Court',
        revenue: parseFloat(item.revenue || 0),
        bookings: parseInt(item.bookings || 0)
      }));
    } catch (error) {
      console.error('Error fetching revenue by court:', error);
      return [];
    }
  }

  /**
   * Get peak hours analysis for chart
   */
  async getPeakHours(range = '30days', complexId = null) {
    const days = range === '7days' ? 7 : range === '90days' ? 90 : 30;
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - days);

    // Peak hours scope through the booking's Court (alias 'court').
    const scopedCourtInclude = complexId != null
      ? [{ model: Court, as: 'court', attributes: [], where: { sportComplexId: complexId }, required: true }]
      : [];

    try {
      // Get bookings grouped by hour
      const hourlyData = await Booking.findAll({
        attributes: [
          [fn('EXTRACT', literal('HOUR FROM "startTime"')), 'hour'],
          [fn('COUNT', col('Booking.id')), 'bookings'],
          // Paid-only, matching the other revenue figures on the page.
          [
            fn('SUM', literal(`CASE WHEN "Booking"."paymentStatus" = 'Paid' THEN "Booking"."totalAmount" ELSE 0 END`)),
            'revenue'
          ]
        ],
        include: scopedCourtInclude,
        where: {
          isDeleted: false, isBlocked: false,
          date: {
            [Op.gte]: startDate
          }
        },
        group: [fn('EXTRACT', literal('HOUR FROM "startTime"'))],
        order: [[fn('EXTRACT', literal('HOUR FROM "startTime"')), 'ASC']],
        raw: true
      });

      // Create array for all 24 hours
      const allHours = [];
      for (let i = 0; i < 24; i++) {
        const hourStr = i.toString().padStart(2, '0') + ':00';
        const hourData = hourlyData.find(h => parseInt(h.hour) === i);
        
        allHours.push({
          hour: hourStr,
          bookings: hourData ? parseInt(hourData.bookings) : 0,
          revenue: hourData ? parseFloat(hourData.revenue || 0) : 0
        });
      }

      return allHours;
    } catch (error) {
      console.error('Error fetching peak hours:', error);
      return [];
    }
  }

  /**
   * Get court performance table data
   */
  async getCourtPerformance(range = '30days', courtId = null, complexId = null) {
    const days = range === '7days' ? 7 : range === '90days' ? 90 : 30;
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - days);

    try {
      // Build where clause for courts (Court has a direct sportComplexId column).
      // Per-court bookings below are filtered by courtId, so they inherit the scope.
      const courtWhere = withComplex({}, complexId);
      if (courtId) {
        courtWhere.id = courtId;
      }

      // Get all courts
      const courts = await Court.findAll({
        where: courtWhere,
        include: [{
          model: SportComplex,
          attributes: ['id', 'name']
        }],
        order: [['name', 'ASC']]
      });

      // Bookable hours per court per day, taken from the court's own slot grid
      // instead of a hard-coded 12h day. CourtSlots rows are 1-hour, but the same
      // hour can appear more than once (one row per availableDays combination),
      // so the open-hours-per-day figure is the count of DISTINCT start times.
      // Courts with no slot grid fall back to DEFAULT_OPEN_HOURS.
      const { CourtSlot } = require('../models');
      const DEFAULT_OPEN_HOURS = 12;
      let slotsByCourt = new Map();
      try {
        const slotCounts = await CourtSlot.findAll({
          attributes: ['courtId', [fn('COUNT', fn('DISTINCT', col('startTime'))), 'slots']],
          where: { courtId: { [Op.in]: courts.map((c) => c.id) }, status: 'Active' },
          group: ['courtId'],
          raw: true,
        });
        slotsByCourt = new Map(slotCounts.map((s) => [s.courtId, parseInt(s.slots, 10)]));
      } catch {
        // No slot grid configured — the default open-hours fallback still works.
      }

      // For each court, calculate bookings, revenue, and utilization
      const courtPerformance = await Promise.all(courts.map(async (court) => {
        const courtData = court.toJSON();

        // Get bookings for this court
        const bookings = await Booking.findAll({
          where: {
            courtId: court.id,
            isDeleted: false, isBlocked: false,
            date: {
              [Op.gte]: startDate
            }
          }
        });

        const totalBookings = bookings.length;
        // Only money actually collected counts as revenue, so this column agrees
        // with the Total Revenue card instead of counting unpaid bookings.
        const revenue = bookings
          .filter((b) => b.paymentStatus === 'Paid')
          .reduce((sum, booking) => sum + parseFloat(booking.totalAmount || 0), 0);

        // startTime/endTime are TIME columns ('08:00:00'), NOT timestamps — the
        // old `new Date(startTime)` produced Invalid Date, so every court with
        // bookings reported NaN% utilisation.
        const openHoursPerDay = slotsByCourt.get(court.id) || DEFAULT_OPEN_HOURS;
        const totalAvailableHours = days * openHoursPerDay;
        const totalBookedHours = bookings.reduce((sum, b) => sum + bookingHours(b), 0);

        const utilization = totalAvailableHours > 0
          ? Math.round((totalBookedHours / totalAvailableHours) * 100)
          : 0;

        return {
          id: courtData.id,
          courtName: courtData.name,
          sportComplexName: courtData.SportComplex?.name || 'N/A',
          totalBookings,
          bookedHours: Math.round(totalBookedHours * 10) / 10,
          openHoursPerDay,
          revenue,
          utilization: Math.min(utilization, 100) // Cap at 100%
        };
      }));

      return courtPerformance;
    } catch (error) {
      console.error('Error fetching court performance:', error);
      return [];
    }
  }

  /**
   * Coach-wise student retention.
   *
   * Answers "which coach keeps their students?" for a chosen month M.
   *
   *   base      = students whose enrollment in that coach's batch was live in M-1
   *   retained  = of those, still live in M (same enrollment still valid, or the
   *               student re-enrolled with the same coach during M)
   *   dropped   = base - retained
   *   ratio     = retained / base × 100
   *
   * "Live in month X" uses the enrollment's own window — enrollmentDate through
   * validTill, falling back to the batch end date and treating a missing end as
   * ongoing — which is the same rule the coach panel's Student Enrollments screen
   * uses, so the two screens never disagree. Dropped/Transferred enrollments stop
   * at the month they ended.
   *
   * Filters mirror the New Students report: month, batchId, sportComplexId,
   * sportId and retentionRatio ('continued' | 'discontinued').
   */
  async getCoachRetention(filters = {}, complexId = null) {
    const { month, year, batchId, sportComplexId, sportId, retentionRatio } = filters;
    const { Coach: CoachModel } = require('../models');

    const pad = (n) => String(n).padStart(2, '0');
    const monthKeyOf = (d) => (d ? String(d).slice(0, 7) : null);
    const shiftMonth = (key, delta) => {
      const [y, m] = key.split('-').map(Number);
      const dt = new Date(y, (m - 1) + delta, 1);
      return `${dt.getFullYear()}-${pad(dt.getMonth() + 1)}`;
    };
    const labelOf = (key) => {
      const [y, m] = key.split('-').map(Number);
      return new Date(y, m - 1, 1).toLocaleDateString('en-IN', { month: 'long', year: 'numeric' });
    };

    const now = new Date();
    const targetYear = Number(year) || now.getFullYear();
    const selectedMonth = month
      ? `${targetYear}-${pad(Number(month))}`
      : `${now.getFullYear()}-${pad(now.getMonth() + 1)}`;
    const previousMonth = shiftMonth(selectedMonth, -1);

    // --- Batch scope (identical semantics to getNewStudents) -------------------
    const batchWhere = {};
    if (batchId) batchWhere.id = batchId;
    const effectiveComplexId = complexId != null ? complexId : sportComplexId;
    if (effectiveComplexId) batchWhere.sportComplexId = effectiveComplexId;
    if (sportId) batchWhere.sportId = sportId;

    const enrollments = await StudentBatches.findAll({
      include: [
        {
          model: Batch,
          as: 'batch',
          required: true,
          where: Object.keys(batchWhere).length ? batchWhere : undefined,
          attributes: ['id', 'name', 'endDate', 'coachId', 'sportId', 'sportComplexId'],
          include: [
            { model: Sport, as: 'sport', attributes: ['id', 'name'] },
            { model: SportComplex, as: 'sportComplex', attributes: ['id', 'name', 'city'] },
            { model: CoachModel, as: 'coach', attributes: ['id', 'name', 'email', 'phone'] }
          ]
        },
        {
          model: Student,
          as: 'student',
          required: true,
          attributes: ['id', 'status'],
          include: [{ model: User, as: 'User', attributes: ['id', 'name', 'email', 'phone_number'] }]
        }
      ],
      order: [['enrollmentDate', 'DESC']]
    });

    const NON_CARRYING = ['Dropped', 'Transferred'];

    /** Enrollment → { startKey, endKey } month window, or null when unusable. */
    const windowOf = (e) => {
      const start = e.enrollmentDate ? String(e.enrollmentDate).slice(0, 10) : null;
      if (!start) return null;
      const own = e.validTill ? String(e.validTill).slice(0, 10) : null;
      const batchEnd = e.batch?.endDate ? String(e.batch.endDate).slice(0, 10) : null;
      let end = own || batchEnd || null;
      if (end && end < start) end = start;
      const startKey = start.slice(0, 7);
      let endKey = end ? end.slice(0, 7) : null;
      if (NON_CARRYING.includes(e.status)) endKey = startKey;
      return { startKey, endKey, start, end };
    };
    const liveIn = (w, key) => w && w.startKey <= key && (!w.endKey || w.endKey >= key);

    // --- Roll up per coach -----------------------------------------------------
    const byCoach = new Map();
    const coachEntry = (coach, batch) => {
      const id = coach?.id ?? 0;
      if (!byCoach.has(id)) {
        byCoach.set(id, {
          coachId: coach?.id ?? null,
          coachName: coach?.name || 'Unassigned',
          email: coach?.email || '',
          phone: coach?.phone || '',
          sportComplex: batch?.sportComplex?.name || '',
          sports: new Set(),
          batches: new Set(),
          baseStudents: new Set(),
          retainedStudents: new Set(),
          newStudents: new Set(),
          activeStudents: new Set(),
          students: new Map()
        });
      }
      const entry = byCoach.get(id);
      if (batch?.sport?.name) entry.sports.add(batch.sport.name);
      if (batch?.id) entry.batches.add(batch.id);
      return entry;
    };

    enrollments.forEach((e) => {
      const w = windowOf(e);
      if (!w) return;
      const batch = e.batch;
      const entry = coachEntry(batch?.coach, batch);
      const studentId = e.studentId;

      const inPrev = liveIn(w, previousMonth);
      const inSel = liveIn(w, selectedMonth);
      const joinedInSel = w.startKey === selectedMonth;

      if (inPrev) entry.baseStudents.add(studentId);
      if (inSel) entry.activeStudents.add(studentId);
      if (inPrev && inSel) entry.retainedStudents.add(studentId);
      // A fresh enrollment with the same coach during the month counts as a
      // renewal, even when the previous enrollment row already expired.
      if (inPrev === false && joinedInSel) entry.newStudents.add(studentId);

      const prior = entry.students.get(studentId);
      const row = {
        studentId,
        name: e.student?.User?.name || 'Unknown',
        email: e.student?.User?.email || '',
        phone: e.student?.User?.phone_number || '',
        batch: batch?.name || '',
        sport: batch?.sport?.name || '',
        sportComplex: batch?.sportComplex?.name || '',
        enrollmentDate: w.start,
        validTill: w.end,
        status: e.status,
        inPrevMonth: Boolean(prior?.inPrevMonth) || inPrev,
        inSelectedMonth: Boolean(prior?.inSelectedMonth) || inSel,
        joinedThisMonth: Boolean(prior?.joinedThisMonth) || joinedInSel
      };
      entry.students.set(studentId, row);
    });

    // A student who was in the base and re-enrolled during the month is retained.
    byCoach.forEach((entry) => {
      entry.students.forEach((row, studentId) => {
        if (row.inPrevMonth && (row.inSelectedMonth || row.joinedThisMonth)) {
          entry.retainedStudents.add(studentId);
        }
      });
    });

    const rate = (retained, base) => (base > 0 ? (retained / base) * 100 : 0);

    let coaches = [...byCoach.values()].map((entry) => {
      const base = entry.baseStudents.size;
      const retained = entry.retainedStudents.size;
      const students = [...entry.students.values()]
        .filter((s) => s.inPrevMonth || s.inSelectedMonth)
        .map((s) => ({
          ...s,
          retained: s.inPrevMonth && (s.inSelectedMonth || s.joinedThisMonth),
          isNew: !s.inPrevMonth && s.joinedThisMonth
        }))
        .filter((s) => {
          if (retentionRatio === 'continued') return s.retained;
          if (retentionRatio === 'discontinued') return s.inPrevMonth && !s.retained;
          return true;
        })
        .sort((a, b) => Number(b.retained) - Number(a.retained) || a.name.localeCompare(b.name));

      return {
        coachId: entry.coachId,
        coachName: entry.coachName,
        email: entry.email,
        phone: entry.phone,
        sportComplex: entry.sportComplex,
        sports: [...entry.sports],
        batchCount: entry.batches.size,
        base,
        retained,
        dropped: Math.max(base - retained, 0),
        newJoiners: entry.newStudents.size,
        activeThisMonth: entry.activeStudents.size,
        retentionRate: Number(rate(retained, base).toFixed(1)),
        students
      };
    });

    // When filtering by retention status, coaches with nothing left to show are
    // noise — drop them so the list answers the question that was asked.
    if (retentionRatio) coaches = coaches.filter((c) => c.students.length > 0);

    // Best retention first; coaches with no base sink to the bottom so a 0/0
    // never outranks a real 5/5.
    coaches.sort(
      (a, b) =>
        (b.base > 0 ? 1 : 0) - (a.base > 0 ? 1 : 0) ||
        b.retentionRate - a.retentionRate ||
        b.retained - a.retained ||
        a.coachName.localeCompare(b.coachName)
    );

    const overallBase = coaches.reduce((n, c) => n + c.base, 0);
    const overallRetained = coaches.reduce((n, c) => n + c.retained, 0);

    return {
      month: selectedMonth,
      monthLabel: labelOf(selectedMonth),
      previousMonth,
      previousMonthLabel: labelOf(previousMonth),
      overall: {
        coaches: coaches.length,
        coachesWithBase: coaches.filter((c) => c.base > 0).length,
        base: overallBase,
        retained: overallRetained,
        dropped: Math.max(overallBase - overallRetained, 0),
        newJoiners: coaches.reduce((n, c) => n + c.newJoiners, 0),
        activeThisMonth: coaches.reduce((n, c) => n + c.activeThisMonth, 0),
        retentionRate: Number(rate(overallRetained, overallBase).toFixed(1)),
        bestCoach: coaches.find((c) => c.base > 0)?.coachName || null
      },
      coaches
    };
  }
}

module.exports = new ReportsService();
