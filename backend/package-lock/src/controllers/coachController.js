const coachService = require('../services/coachService');
const { resolveComplexId, isComplexAdmin, stampComplexId, assertComplexAccess } = require('../middleware/complexScope');
const { resolveStaffComplexId, emailStaffCredentials, revealStaffPassword, setStaffPassword, findStaffUser } = require('../utils/staffAccount');

// Reveal the stored login password for a coach (ADMIN / COMPLEX_ADMIN only).
// Coach has no userId FK — the login User is linked by matching email.
exports.revealPassword = async (req, res) => {
  try {
    const coach = await coachService.getCoachById(req.params.id);
    if (!coach) return res.status(404).json({ success: false, message: 'Coach not found' });
    if (isComplexAdmin(req) && !assertComplexAccess(req, res, coach.sportComplexId)) return;

    const user = await findStaffUser({ email: coach.email }, { withSecret: true });
    const password = revealStaffPassword(user);
    if (!password) {
      return res.status(404).json({
        success: false,
        message: 'No stored password for this coach. Use "Reset Password" to set a new one.',
      });
    }
    res.status(200).json({ success: true, data: { email: user.email, password } });
  } catch (error) {
    console.error('Error revealing coach password:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

// Reset a coach's login password to a new admin-set value (and re-email it).
exports.resetPassword = async (req, res) => {
  try {
    const { password } = req.body;
    if (!password || String(password).length < 6) {
      return res.status(400).json({ success: false, message: 'Password is required (min 6 characters)' });
    }
    const coach = await coachService.getCoachById(req.params.id);
    if (!coach) return res.status(404).json({ success: false, message: 'Coach not found' });
    if (isComplexAdmin(req) && !assertComplexAccess(req, res, coach.sportComplexId)) return;

    const user = await findStaffUser({ email: coach.email }, { withSecret: true });
    if (!user) return res.status(404).json({ success: false, message: 'Login account not found for this coach' });

    await setStaffPassword(user, password);
    await emailStaffCredentials({
      to: user.email, name: user.name, email: user.email, password,
      roleKey: 'COACH', sportComplexId: coach.sportComplexId,
      details: [{ label: 'Specialization', value: coach.specialization }],
    });
    res.status(200).json({ success: true, message: 'Password reset and emailed to the coach' });
  } catch (error) {
    console.error('Error resetting coach password:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

// Get all coaches
exports.getAllCoaches = async (req, res) => {
  try {
    const { status, sportId, ground, search, page = 1, limit = 10 } = req.query;

    const filters = {};
    if (status) filters.status = status;
    if (sportId) filters.sportId = sportId;
    if (ground) filters.ground = ground;
    if (search) filters.search = search;

    // Per-complex admin scoping (null for super admin = all complexes)
    const complexId = resolveComplexId(req);
    if (complexId != null) filters.sportComplexId = complexId;

    const result = await coachService.getAllCoaches(
      filters,
      parseInt(page),
      parseInt(limit)
    );
    
    res.status(200).json({
      success: true,
      data: result,
    });
  } catch (error) {
    console.error('Error fetching coaches:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch coaches',
      error: error.message,
    });
  }
};

// Get coach by ID
exports.getCoachById = async (req, res) => {
  try {
    const { id } = req.params;
    const { includePrograms } = req.query;
    
    const coach = await coachService.getCoachById(id, {
      includePrograms: includePrograms === 'true',
    });

    if (!coach) {
      return res.status(404).json({
        success: false,
        message: 'Coach not found',
      });
    }

    // Complex admins can only view coaches in their own complex
    if (!assertComplexAccess(req, res, coach.sportComplexId)) return;

    res.status(200).json({
      success: true,
      data: coach,
    });
  } catch (error) {
    console.error('Error fetching coach:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch coach',
      error: error.message,
    });
  }
};

// Create a new coach
exports.createCoach = async (req, res) => {
  try {
    const coachData = req.body;

    // Validate required fields
    if (!coachData.name) {
      return res.status(400).json({
        success: false,
        message: 'Coach name is required',
      });
    }

    // A coach now gets a login account, so email + password are required.
    if (!coachData.email) {
      return res.status(400).json({ success: false, message: 'Email is required' });
    }
    if (!coachData.password || String(coachData.password).length < 6) {
      return res.status(400).json({ success: false, message: 'Password is required (min 6 characters)' });
    }

    // Resolve the complex: complex admin → own; super admin → must pick one.
    const complexId = resolveStaffComplexId(req);
    if (!complexId) {
      return res.status(400).json({ success: false, message: 'Please assign the coach to a sports complex' });
    }
    coachData.sportComplexId = complexId;

    const newCoach = await coachService.createCoach(coachData);

    await emailStaffCredentials({
      to: coachData.email, name: coachData.name, email: coachData.email,
      password: coachData.password, roleKey: 'COACH', sportComplexId: complexId,
      details: [
        { label: 'Phone', value: coachData.phone },
        { label: 'Ground', value: coachData.ground },
        { label: 'Specialization', value: coachData.specialization },
        { label: 'Experience', value: coachData.experience },
      ],
    });

    res.status(201).json({
      success: true,
      message: 'Coach created successfully',
      data: newCoach,
    });
  } catch (error) {
    console.error('Error creating coach:', error);

    // Handle unique constraint errors
    if (error.name === 'SequelizeUniqueConstraintError' || error.message === 'Email already exists') {
      return res.status(400).json({
        success: false,
        message: 'Email already exists',
        error: error.message,
      });
    }

    res.status(500).json({
      success: false,
      message: 'Failed to create coach',
      error: error.message,
    });
  }
};

// Update coach
exports.updateCoach = async (req, res) => {
  try {
    const { id } = req.params;
    const updateData = req.body;

    // Complex admins may only edit coaches in their own complex, and cannot move
    // a coach to a different complex.
    if (isComplexAdmin(req)) {
      const existing = await coachService.getCoachById(id);
      if (!existing) {
        return res.status(404).json({ success: false, message: 'Coach not found' });
      }
      if (!assertComplexAccess(req, res, existing.sportComplexId)) return;
      stampComplexId(req, updateData);
    }

    const updatedCoach = await coachService.updateCoach(id, updateData);
    
    if (!updatedCoach) {
      return res.status(404).json({
        success: false,
        message: 'Coach not found',
      });
    }
    
    res.status(200).json({
      success: true,
      message: 'Coach updated successfully',
      data: updatedCoach,
    });
  } catch (error) {
    console.error('Error updating coach:', error);
    
    // Handle unique constraint errors
    if (error.name === 'SequelizeUniqueConstraintError') {
      return res.status(400).json({
        success: false,
        message: 'Email already exists',
        error: error.message,
      });
    }
    
    res.status(500).json({
      success: false,
      message: 'Failed to update coach',
      error: error.message,
    });
  }
};

// Update coach status
exports.updateCoachStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;
    
    if (!status || !['Active', 'Inactive'].includes(status)) {
      return res.status(400).json({
        success: false,
        message: 'Valid status is required (Active or Inactive)',
      });
    }

    if (isComplexAdmin(req)) {
      const existing = await coachService.getCoachById(id);
      if (!existing) {
        return res.status(404).json({ success: false, message: 'Coach not found' });
      }
      if (!assertComplexAccess(req, res, existing.sportComplexId)) return;
    }

    const updatedCoach = await coachService.updateCoachStatus(id, status);
    
    if (!updatedCoach) {
      return res.status(404).json({
        success: false,
        message: 'Coach not found',
      });
    }
    
    res.status(200).json({
      success: true,
      message: 'Coach status updated successfully',
      data: updatedCoach,
    });
  } catch (error) {
    console.error('Error updating coach status:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to update coach status',
      error: error.message,
    });
  }
};

// Delete coach
exports.deleteCoach = async (req, res) => {
  try {
    const { id } = req.params;

    if (isComplexAdmin(req)) {
      const existing = await coachService.getCoachById(id);
      if (!existing) {
        return res.status(404).json({ success: false, message: 'Coach not found' });
      }
      if (!assertComplexAccess(req, res, existing.sportComplexId)) return;
    }

    const deleted = await coachService.deleteCoach(id);
    
    if (!deleted) {
      return res.status(404).json({
        success: false,
        message: 'Coach not found',
      });
    }
    
    res.status(200).json({
      success: true,
      message: 'Coach deleted successfully',
    });
  } catch (error) {
    console.error('Error deleting coach:', error);
    
    if (error.message.includes('active batches')) {
      return res.status(400).json({
        success: false,
        message: error.message,
      });
    }
    
    res.status(500).json({
      success: false,
      message: 'Failed to delete coach',
      error: error.message,
    });
  }
};

// Get coaches by sport
exports.getCoachesBySport = async (req, res) => {
  try {
    const { sportId } = req.params;
    
    const coaches = await coachService.getCoachesBySport(sportId);
    
    res.status(200).json({
      success: true,
      data: coaches,
    });
  } catch (error) {
    console.error('Error fetching coaches by sport:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch coaches',
      error: error.message,
    });
  }
};

// Get coach statistics
exports.getCoachStats = async (req, res) => {
  try {
    const { id } = req.params;
    
    const stats = await coachService.getCoachStats(id);
    
    res.status(200).json({
      success: true,
      data: stats,
    });
  } catch (error) {
    console.error('Error fetching coach stats:', error);
    
    if (error.message === 'Coach not found') {
      return res.status(404).json({
        success: false,
        message: error.message,
      });
    }
    
    res.status(500).json({
      success: false,
      message: 'Failed to fetch coach statistics',
      error: error.message,
    });
  }
};
