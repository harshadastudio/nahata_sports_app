const {
  Student,
  Coach,
  CoachingEnquiry,
  ContactUs,
  User,
  Booking,
  Payment,
  Sport,
  Batch,
  Court,
  sequelize
} = require('../models');
const { Op } = require('sequelize');
const { resolveComplexId } = require('../middleware/complexScope');

// --- Per-complex admin dashboard scoping helpers -------------------------------
// For a COMPLEX_ADMIN, resolveComplexId(req) returns their complex id; for super
// admin / others it returns null and every helper below becomes a no-op.

// Direct-column models (Coach, CoachingEnquiry have a sportComplexId column):
const withComplex = (where, complexId) =>
  complexId != null ? { ...where, sportComplexId: complexId } : where;

// Student counts scope through the Batches the student is enrolled in.
const studentScope = (complexId) =>
  complexId != null
    ? { include: [{ model: Batch, as: 'Batches', attributes: [], where: { sportComplexId: complexId }, required: true }], distinct: true, col: 'id' }
    : {};

// Booking counts scope through the booking's court.
const bookingScope = (complexId) =>
  complexId != null
    ? { include: [{ model: Court, as: 'court', attributes: [], where: { sportComplexId: complexId }, required: true }], distinct: true, col: 'id' }
    : {};

/**
 * Format a Date as YYYY-MM-DD in LOCAL time.
 *
 * `toISOString()` converts to UTC first, so local midnight in IST (UTC+5:30)
 * comes back as the previous day — which made the dashboard report a range one
 * day off from the one it actually queried.
 */
function toLocalISODate(d) {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

/**
 * Percentage change with an explicit "no baseline" signal.
 *
 * A previous period of zero used to be reported as a flat +100%, which is why
 * every card on the dashboard read "+100%" regardless of the filter. Callers can
 * now render "New" instead of a number that means nothing.
 */
function periodChange(current, previous) {
  if (previous > 0) {
    const growth = ((current - previous) / previous) * 100;
    return {
      growth: Number(growth.toFixed(1)),
      growthText: `${growth >= 0 ? '+' : ''}${growth.toFixed(1)}%`,
      isPositive: growth >= 0,
      isNew: false,
      hasBaseline: true
    };
  }
  return {
    growth: 0,
    growthText: current > 0 ? 'New' : 'No change',
    isPositive: true,
    isNew: current > 0,
    hasBaseline: false
  };
}

/**
 * Get dashboard statistics
 * @route GET /api/dashboard/stats
 *
 * Every metric is returned as { total, periodTotal, previousTotal, ... }:
 *   total        — all-time roster count (unaffected by the filter)
 *   periodTotal  — records created inside the selected range
 *   previousTotal— the same-length range immediately before it
 * The UI headlines periodTotal so the date filter visibly changes the numbers,
 * and keeps `total` as the secondary "of N all-time" figure.
 */
exports.getDashboardStats = async (req, res) => {
  try {
    const { startDate, endDate } = req.query;
    const complexId = resolveComplexId(req);

    // Resolve the selected window and the equally long window before it.
    const now = new Date();
    let periodStart, periodEnd, previousStart;

    if (startDate || endDate) {
      // A partially filled custom range is still usable: the missing side is
      // treated as "since the beginning" / "until now" instead of being ignored.
      periodStart = startDate ? new Date(`${String(startDate).slice(0, 10)}T00:00:00`) : new Date(2000, 0, 1);
      periodEnd = endDate ? new Date(`${String(endDate).slice(0, 10)}T23:59:59.999`) : new Date(now);
    } else {
      // Default: the current calendar month vs the previous one.
      periodStart = new Date(now.getFullYear(), now.getMonth(), 1);
      periodEnd = new Date(now);
    }

    if (periodEnd < periodStart) [periodStart, periodEnd] = [periodEnd, periodStart];

    const windowMs = Math.max(periodEnd - periodStart, 24 * 60 * 60 * 1000);
    previousStart = new Date(periodStart.getTime() - windowMs);
    // Previous window ends 1ms before the selected one starts, so a record on the
    // boundary is never counted in both periods.
    const previousEnd = new Date(periodStart.getTime() - 1);

    const inPeriod = { [Op.between]: [periodStart, periodEnd] };
    const inPrevious = { [Op.between]: [previousStart, previousEnd] };

    /** Build a metric block from three counts. */
    const metric = (total, periodTotal, previousTotal) => ({
      total,
      periodTotal,
      previousTotal,
      // Kept for backwards compatibility with anything still reading these.
      thisMonth: periodTotal,
      lastMonth: previousTotal,
      ...periodChange(periodTotal, previousTotal)
    });

    const [
      totalStudents, studentsThisPeriod, studentsLastPeriod,
      totalCoaches, coachesThisPeriod, coachesLastPeriod,
      totalEnquiries, enquiriesThisPeriod, enquiriesLastPeriod,
      totalContactRequests, contactThisPeriod, contactLastPeriod,
      totalBookings, bookingsThisPeriod, bookingsLastPeriod,
    ] = await Promise.all([
      // 1. Students (complex-scoped through their batches)
      Student.count({ where: { status: 'Active' }, ...studentScope(complexId) }),
      Student.count({ where: { status: 'Active', createdAt: inPeriod }, ...studentScope(complexId) }),
      Student.count({ where: { status: 'Active', createdAt: inPrevious }, ...studentScope(complexId) }),

      // 2. Coaches
      Coach.count({ where: withComplex({ status: 'Active' }, complexId) }),
      Coach.count({ where: withComplex({ status: 'Active', createdAt: inPeriod }, complexId) }),
      Coach.count({ where: withComplex({ status: 'Active', createdAt: inPrevious }, complexId) }),

      // 3. Coaching enquiries
      CoachingEnquiry.count({ where: withComplex({}, complexId) }),
      CoachingEnquiry.count({ where: withComplex({ createdAt: inPeriod }, complexId) }),
      CoachingEnquiry.count({ where: withComplex({ createdAt: inPrevious }, complexId) }),

      // 4. Contact requests
      ContactUs.count({ where: withComplex({}, complexId) }),
      ContactUs.count({ where: withComplex({ createdAt: inPeriod }, complexId) }),
      ContactUs.count({ where: withComplex({ createdAt: inPrevious }, complexId) }),

      // 5. Court bookings (complex-scoped through the court)
      Booking.count({ where: { isDeleted: false }, ...bookingScope(complexId) }),
      Booking.count({ where: { isDeleted: false, createdAt: inPeriod }, ...bookingScope(complexId) }),
      Booking.count({ where: { isDeleted: false, createdAt: inPrevious }, ...bookingScope(complexId) }),
    ]);

    const coaches = metric(totalCoaches, coachesThisPeriod, coachesLastPeriod);

    // Return dashboard stats
    res.status(200).json({
      success: true,
      data: {
        period: {
          startDate: toLocalISODate(periodStart),
          endDate: toLocalISODate(periodEnd),
          previousStartDate: toLocalISODate(previousStart),
          previousEndDate: toLocalISODate(previousEnd)
        },
        students: metric(totalStudents, studentsThisPeriod, studentsLastPeriod),
        coaches: { ...coaches, status: coaches.hasBaseline ? coaches.growthText : (coaches.isNew ? 'New' : 'Stable') },
        bookings: metric(totalBookings, bookingsThisPeriod, bookingsLastPeriod),
        enquiries: metric(totalEnquiries, enquiriesThisPeriod, enquiriesLastPeriod),
        contactRequests: metric(totalContactRequests, contactThisPeriod, contactLastPeriod)
      }
    });
  } catch (error) {
    console.error('Error fetching dashboard stats:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch dashboard statistics',
      error: error.message
    });
  }
};

/**
 * Get enrollment trends for the dashboard sparklines / charts
 * @route GET /api/dashboard/enrollment-trends
 *
 * Walks the months of the SELECTED range (the old version always walked back
 * from today and merely skipped months outside the range, so a range in the past
 * returned nothing). Returns one series per metric so each stat card can show its
 * own sparkline instead of all five sharing the student curve.
 *
 * Values are per-month counts, not running totals — a cumulative series only ever
 * slopes upwards and told the reader nothing.
 */
exports.getEnrollmentTrends = async (req, res) => {
  try {
    const { startDate, endDate } = req.query;
    const complexId = resolveComplexId(req);

    const now = new Date();
    const rangeEnd = endDate ? new Date(`${String(endDate).slice(0, 10)}T23:59:59.999`) : new Date(now);
    let rangeStart = startDate ? new Date(`${String(startDate).slice(0, 10)}T00:00:00`) : null;
    if (!rangeStart) {
      // No explicit range → the last 6 months, ending with the range end.
      rangeStart = new Date(rangeEnd.getFullYear(), rangeEnd.getMonth() - 5, 1);
    }
    if (rangeEnd < rangeStart) return res.status(200).json({ success: true, data: [] });

    // Cap the number of buckets so a multi-year range stays one readable chart.
    const MAX_BUCKETS = 12;
    let cursor = new Date(rangeStart.getFullYear(), rangeStart.getMonth(), 1);
    const buckets = [];
    while (cursor <= rangeEnd && buckets.length < MAX_BUCKETS) {
      const monthStart = new Date(cursor.getFullYear(), cursor.getMonth(), 1);
      const monthEnd = new Date(cursor.getFullYear(), cursor.getMonth() + 1, 0, 23, 59, 59, 999);
      buckets.push({
        // Clamp to the range so the first/last bucket only counts days inside it.
        from: monthStart < rangeStart ? rangeStart : monthStart,
        to: monthEnd > rangeEnd ? rangeEnd : monthEnd,
        name: cursor.toLocaleString('en-US', { month: 'short' }),
        key: `${cursor.getFullYear()}-${String(cursor.getMonth() + 1).padStart(2, '0')}`
      });
      cursor = new Date(cursor.getFullYear(), cursor.getMonth() + 1, 1);
    }

    const data = await Promise.all(buckets.map(async (b) => {
      const range = { [Op.between]: [b.from, b.to] };
      const [students, enquiries, bookings, coaches, contactRequests] = await Promise.all([
        Student.count({ where: { status: 'Active', createdAt: range }, ...studentScope(complexId) }),
        CoachingEnquiry.count({ where: withComplex({ createdAt: range }, complexId) }),
        Booking.count({ where: { isDeleted: false, createdAt: range }, ...bookingScope(complexId) }),
        Coach.count({ where: withComplex({ status: 'Active', createdAt: range }, complexId) }),
        ContactUs.count({ where: withComplex({ createdAt: range }, complexId) })
      ]);
      return { name: b.name, month: b.key, students, enquiries, bookings, coaches, contactRequests };
    }));

    res.status(200).json({
      success: true,
      data
    });
  } catch (error) {
    console.error('Error fetching enrollment trends:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch enrollment trends',
      error: error.message
    });
  }
};

/**
 * Get sport distribution for pie chart
 * @route GET /api/dashboard/sport-distribution
 */
exports.getSportDistribution = async (req, res) => {
  try {
    const { startDate, endDate } = req.query;
    
    // Build where clause for date filtering
    const complexId = resolveComplexId(req);
    const whereClause = {
      sportId: {
        [Op.ne]: null
      }
    };

    if (complexId != null) whereClause.sportComplexId = complexId;

    if (startDate && endDate) {
      const rangeEnd = new Date(endDate);
      rangeEnd.setUTCHours(23, 59, 59, 999); // include the whole end day
      whereClause.createdAt = {
        [Op.between]: [new Date(startDate), rangeEnd]
      };
    }
    
    // Get sport distribution from coaching enquiries using Sequelize
    const sportDistribution = await CoachingEnquiry.findAll({
      attributes: [
        [sequelize.fn('COUNT', sequelize.col('CoachingEnquiry.id')), 'value']
      ],
      include: [
        {
          model: Sport,
          as: 'sport',
          attributes: ['id', 'name'],
          where: {
            status: 'Active'
          }
        }
      ],
      where: whereClause,
      group: ['sport.id', 'sport.name'],
      order: [[sequelize.literal('value'), 'DESC']],
      limit: 4,
      raw: true
    });
    
    // Define colors for sports
    const colors = ['#2563eb', '#0891b2', '#059669', '#e11d48', '#f59e0b', '#8b5cf6'];
    
    const formattedData = sportDistribution.map((item, index) => ({
      name: item['sport.name'],
      value: parseInt(item.value),
      color: colors[index % colors.length]
    }));
    
    // Calculate total
    const total = formattedData.reduce((sum, item) => sum + item.value, 0);
    
    res.status(200).json({
      success: true,
      data: {
        distribution: formattedData,
        total: total
      }
    });
  } catch (error) {
    console.error('Error fetching sport distribution:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch sport distribution',
      error: error.message
    });
  }
};

/**
 * Get recent live enquiries
 * @route GET /api/dashboard/live-enquiries
 */
exports.getLiveEnquiries = async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 4;
    const complexId = resolveComplexId(req);

    // Get recent enquiries with user and sport details
    const enquiries = await CoachingEnquiry.findAll({
      where: withComplex({
        status: 'Pending'
      }, complexId),
      include: [
        {
          model: User,
          as: 'user',
          attributes: ['id', 'name', 'email', 'avatar']
        },
        {
          model: Sport,
          as: 'sport',
          attributes: ['id', 'name']
        }
      ],
      order: [['createdAt', 'DESC']],
      limit: limit
    });
    
    // Format the data
    const formattedEnquiries = enquiries.map(enquiry => {
      const now = new Date();
      const createdAt = new Date(enquiry.createdAt);
      const diffInMinutes = Math.floor((now - createdAt) / (1000 * 60));
      
      let timeAgo;
      if (diffInMinutes < 1) {
        timeAgo = 'Just now';
      } else if (diffInMinutes < 60) {
        timeAgo = `${diffInMinutes} min${diffInMinutes > 1 ? 's' : ''} ago`;
      } else if (diffInMinutes < 1440) {
        const hours = Math.floor(diffInMinutes / 60);
        timeAgo = `${hours} hour${hours > 1 ? 's' : ''} ago`;
      } else {
        const days = Math.floor(diffInMinutes / 1440);
        timeAgo = `${days} day${days > 1 ? 's' : ''} ago`;
      }
      
      return {
        id: enquiry.id,
        name: enquiry.user?.name || enquiry.name,
        email: enquiry.user?.email || enquiry.email,
        avatar: enquiry.user?.avatar || null,
        sport: enquiry.sport?.name || 'General',
        timeAgo: timeAgo,
        status: enquiry.status
      };
    });
    
    res.status(200).json({
      success: true,
      data: formattedEnquiries
    });
  } catch (error) {
    console.error('Error fetching live enquiries:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch live enquiries',
      error: error.message
    });
  }
};
