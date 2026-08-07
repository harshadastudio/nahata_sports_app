const reportsService = require('../services/reportsService');
const { resolveComplexId } = require('../middleware/complexScope');

class ReportsController {
  /**
   * Get dashboard overview
   * GET /api/reports/overview
   */
  async getDashboardOverview(req, res) {
    try {
      const { startDate, endDate } = req.query;
      
      const dateRange = {};
      if (startDate) dateRange.startDate = new Date(startDate);
      if (endDate) dateRange.endDate = new Date(endDate);

      const complexId = resolveComplexId(req);
      const data = await reportsService.getDashboardOverview(dateRange, complexId);
      
      res.status(200).json({
        success: true,
        data
      });
    } catch (error) {
      console.error('Error fetching dashboard overview:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to fetch dashboard overview',
        error: error.message
      });
    }
  }

  /**
   * Get revenue analytics
   * GET /api/reports/revenue
   */
  async getRevenueAnalytics(req, res) {
    try {
      const { startDate, endDate } = req.query;
      
      const dateRange = {};
      if (startDate) dateRange.startDate = new Date(startDate);
      if (endDate) dateRange.endDate = new Date(endDate);

      const complexId = resolveComplexId(req);
      const data = await reportsService.getRevenueAnalytics(dateRange, complexId);
      
      res.status(200).json({
        success: true,
        data
      });
    } catch (error) {
      console.error('Error fetching revenue analytics:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to fetch revenue analytics',
        error: error.message
      });
    }
  }

  /**
   * Get booking analytics
   * GET /api/reports/bookings
   */
  async getBookingAnalytics(req, res) {
    try {
      const { startDate, endDate } = req.query;
      
      const dateRange = {};
      if (startDate) dateRange.startDate = new Date(startDate);
      if (endDate) dateRange.endDate = new Date(endDate);

      const complexId = resolveComplexId(req);
      const data = await reportsService.getBookingAnalytics(dateRange, complexId);
      
      res.status(200).json({
        success: true,
        data
      });
    } catch (error) {
      console.error('Error fetching booking analytics:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to fetch booking analytics',
        error: error.message
      });
    }
  }

  /**
   * Get membership analytics
   * GET /api/reports/memberships
   */
  async getMembershipAnalytics(req, res) {
    try {
      const { startDate, endDate } = req.query;
      
      const dateRange = {};
      if (startDate) dateRange.startDate = new Date(startDate);
      if (endDate) dateRange.endDate = new Date(endDate);

      const complexId = resolveComplexId(req);
      const data = await reportsService.getMembershipAnalytics(dateRange, complexId);
      
      res.status(200).json({
        success: true,
        data
      });
    } catch (error) {
      console.error('Error fetching membership analytics:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to fetch membership analytics',
        error: error.message
      });
    }
  }

  /**
   * Get user analytics
   * GET /api/reports/users
   */
  async getUserAnalytics(req, res) {
    try {
      const { startDate, endDate } = req.query;
      
      const dateRange = {};
      if (startDate) dateRange.startDate = new Date(startDate);
      if (endDate) dateRange.endDate = new Date(endDate);

      const complexId = resolveComplexId(req);
      const data = await reportsService.getUserAnalytics(dateRange, complexId);
      
      res.status(200).json({
        success: true,
        data
      });
    } catch (error) {
      console.error('Error fetching user analytics:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to fetch user analytics',
        error: error.message
      });
    }
  }

  /**
   * Get coaching analytics
   * GET /api/reports/coaching
   */
  async getCoachingAnalytics(req, res) {
    try {
      const { startDate, endDate } = req.query;
      
      const dateRange = {};
      if (startDate) dateRange.startDate = new Date(startDate);
      if (endDate) dateRange.endDate = new Date(endDate);

      const complexId = resolveComplexId(req);
      const data = await reportsService.getCoachingAnalytics(dateRange, complexId);
      
      res.status(200).json({
        success: true,
        data
      });
    } catch (error) {
      console.error('Error fetching coaching analytics:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to fetch coaching analytics',
        error: error.message
      });
    }
  }

  /**
   * Get facility analytics
   * GET /api/reports/facilities
   */
  async getFacilityAnalytics(req, res) {
    try {
      const { startDate, endDate } = req.query;
      
      const dateRange = {};
      if (startDate) dateRange.startDate = new Date(startDate);
      if (endDate) dateRange.endDate = new Date(endDate);

      const complexId = resolveComplexId(req);
      const data = await reportsService.getFacilityAnalytics(dateRange, complexId);
      
      res.status(200).json({
        success: true,
        data
      });
    } catch (error) {
      console.error('Error fetching facility analytics:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to fetch facility analytics',
        error: error.message
      });
    }
  }

  /**
   * Get all bookings with filters
   * GET /api/reports/bookings/all
   */
  async getAllBookings(req, res) {
    try {
      const { month, year, sportComplexId, sportId, bookingSource, page, limit } = req.query;
      
      const filters = {};
      if (month) filters.month = parseInt(month);
      if (year) filters.year = parseInt(year);
      if (sportComplexId) filters.sportComplexId = parseInt(sportComplexId);
      if (sportId) filters.sportId = parseInt(sportId);
      if (bookingSource) filters.bookingSource = bookingSource;
      if (page) filters.page = parseInt(page);
      if (limit) filters.limit = parseInt(limit);

      const complexId = resolveComplexId(req);
      const data = await reportsService.getAllBookings(filters, complexId);
      
      res.status(200).json({
        success: true,
        data
      });
    } catch (error) {
      console.error('Error fetching all bookings:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to fetch bookings',
        error: error.message
      });
    }
  }

  /**
   * Get filter options for bookings
   * GET /api/reports/bookings/filter-options
   */
  async getBookingFilterOptions(req, res) {
    try {
      const complexId = resolveComplexId(req);
      const data = await reportsService.getBookingFilterOptions(complexId);
      
      res.status(200).json({
        success: true,
        data
      });
    } catch (error) {
      console.error('Error fetching booking filter options:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to fetch filter options',
        error: error.message
      });
    }
  }

  /**
   * Get all students with filters
   * GET /api/reports/students/all
   */
  async getAllStudents(req, res) {
    try {
      const { month, batchId, sportComplexId, status, page, limit } = req.query;
      
      const filters = {};
      if (month) filters.month = parseInt(month);
      if (batchId) filters.batchId = parseInt(batchId);
      if (sportComplexId) filters.sportComplexId = parseInt(sportComplexId);
      if (status) filters.status = status;
      if (page) filters.page = parseInt(page);
      if (limit) filters.limit = parseInt(limit);

      const complexId = resolveComplexId(req);
      const data = await reportsService.getAllStudents(filters, complexId);
      
      res.status(200).json({
        success: true,
        data
      });
    } catch (error) {
      console.error('Error fetching all students:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to fetch students',
        error: error.message
      });
    }
  }

  /**
   * Get filter options for students
   * GET /api/reports/students/filter-options
   */
  async getStudentFilterOptions(req, res) {
    try {
      const complexId = resolveComplexId(req);
      const data = await reportsService.getStudentFilterOptions(complexId);
      
      res.status(200).json({
        success: true,
        data
      });
    } catch (error) {
      console.error('Error fetching student filter options:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to fetch filter options',
        error: error.message
      });
    }
  }

  /**
   * Get new students with retention rate
   * GET /api/reports/students/new
   */
  async getNewStudents(req, res) {
    try {
      const { month, batchId, sportComplexId, sportId, retentionRatio, page, limit } = req.query;
      
      const filters = {};
      if (month) filters.month = parseInt(month);
      if (batchId) filters.batchId = parseInt(batchId);
      if (sportComplexId) filters.sportComplexId = parseInt(sportComplexId);
      if (sportId) filters.sportId = parseInt(sportId);
      if (retentionRatio) filters.retentionRatio = retentionRatio;
      if (page) filters.page = parseInt(page);
      if (limit) filters.limit = parseInt(limit);

      const complexId = resolveComplexId(req);
      const data = await reportsService.getNewStudents(filters, complexId);
      
      res.status(200).json({
        success: true,
        data
      });
    } catch (error) {
      console.error('Error fetching new students:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to fetch new students',
        error: error.message
      });
    }
  }

  /**
   * Get filter options for new students
   * GET /api/reports/students/new/filter-options
   */
  async getNewStudentFilterOptions(req, res) {
    try {
      const complexId = resolveComplexId(req);
      const data = await reportsService.getNewStudentFilterOptions(complexId);
      
      res.status(200).json({
        success: true,
        data
      });
    } catch (error) {
      console.error('Error fetching new student filter options:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to fetch filter options',
        error: error.message
      });
    }
  }

  /**
   * Coach-wise student retention ratio
   * GET /api/reports/coaches/retention
   */
  async getCoachRetention(req, res) {
    try {
      const { month, year, batchId, sportComplexId, sportId, retentionRatio } = req.query;

      const filters = {};
      if (month) filters.month = parseInt(month);
      if (year) filters.year = parseInt(year);
      if (batchId) filters.batchId = parseInt(batchId);
      if (sportComplexId) filters.sportComplexId = parseInt(sportComplexId);
      if (sportId) filters.sportId = parseInt(sportId);
      if (retentionRatio) filters.retentionRatio = retentionRatio;

      const complexId = resolveComplexId(req);
      const data = await reportsService.getCoachRetention(filters, complexId);

      res.status(200).json({
        success: true,
        data
      });
    } catch (error) {
      console.error('Error fetching coach retention:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to fetch coach retention',
        error: error.message
      });
    }
  }

  /**
   * Get all coaches with filters
   * GET /api/reports/coaches/all
   */
  async getAllCoaches(req, res) {
    try {
      const { month, year, batchId, page, limit } = req.query;
      
      const filters = {};
      if (month) filters.month = parseInt(month);
      if (year) filters.year = parseInt(year);
      if (batchId) filters.batchId = parseInt(batchId);
      if (page) filters.page = parseInt(page);
      if (limit) filters.limit = parseInt(limit);

      const complexId = resolveComplexId(req);
      const data = await reportsService.getAllCoaches(filters, complexId);
      
      res.status(200).json({
        success: true,
        data
      });
    } catch (error) {
      console.error('Error fetching all coaches:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to fetch coaches',
        error: error.message
      });
    }
  }

  /**
   * Get filter options for coaches
   * GET /api/reports/coaches/filter-options
   */
  async getCoachFilterOptions(req, res) {
    try {
      const complexId = resolveComplexId(req);
      const data = await reportsService.getCoachFilterOptions(complexId);
      
      res.status(200).json({
        success: true,
        data
      });
    } catch (error) {
      console.error('Error fetching coach filter options:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to fetch filter options',
        error: error.message
      });
    }
  }
  /**
   * Get booking trends for chart
   * GET /api/reports/booking-trends
   */
  async getBookingTrends(req, res) {
    try {
      const { range = '30days' } = req.query;
      
      const complexId = resolveComplexId(req);
      const data = await reportsService.getBookingTrends(range, complexId);
      
      res.status(200).json({
        success: true,
        data
      });
    } catch (error) {
      console.error('Error fetching booking trends:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to fetch booking trends',
        error: error.message
      });
    }
  }

  /**
   * Get revenue by court for chart
   * GET /api/reports/revenue-by-court
   */
  async getRevenueByCourtChart(req, res) {
    try {
      const { range = '30days' } = req.query;
      
      const complexId = resolveComplexId(req);
      const data = await reportsService.getRevenueByCourtChart(range, complexId);
      
      res.status(200).json({
        success: true,
        data
      });
    } catch (error) {
      console.error('Error fetching revenue by court:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to fetch revenue by court',
        error: error.message
      });
    }
  }

  /**
   * Get peak hours analysis for chart
   * GET /api/reports/peak-hours
   */
  async getPeakHours(req, res) {
    try {
      const { range = '30days' } = req.query;
      
      const complexId = resolveComplexId(req);
      const data = await reportsService.getPeakHours(range, complexId);
      
      res.status(200).json({
        success: true,
        data
      });
    } catch (error) {
      console.error('Error fetching peak hours:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to fetch peak hours',
        error: error.message
      });
    }
  }

  /**
   * Get court performance table data
   * GET /api/reports/court-performance
   */
  async getCourtPerformance(req, res) {
    try {
      const { range = '30days', courtId } = req.query;
      
      const complexId = resolveComplexId(req);
      const data = await reportsService.getCourtPerformance(range, courtId, complexId);
      
      res.status(200).json({
        success: true,
        data
      });
    } catch (error) {
      console.error('Error fetching court performance:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to fetch court performance',
        error: error.message
      });
    }
  }
}

module.exports = new ReportsController();
