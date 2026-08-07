console.log('🔧 roleMiddleware.js loaded');

const allowRoles = (...allowedRoles) => {
  return (req, res, next) => {
    console.log('🔍 allowRoles called with:', allowedRoles);
    
    if (!req.user) {
      console.log('❌ No req.user');
      return res.status(401).json({
        success: false,
        message: 'Authentication required'
      });
    }

    // Handle both plain objects and Sequelize model instances
    const userObj = req.user.toJSON ? req.user.toJSON() : req.user;
    const userRole = (userObj.role || '').toUpperCase();
    const normalizedAllowed = allowedRoles.map(r => r.toUpperCase());

    console.log('🔍 User role:', userRole, 'Allowed:', normalizedAllowed, 'Match:', normalizedAllowed.includes(userRole));

    if (!normalizedAllowed.includes(userRole)) {
      console.log('❌ Access denied');
      return res.status(403).json({
        success: false,
        message: 'Access denied. Insufficient permissions.'
      });
    }

    console.log('✅ Access granted');
    next();
  };
};

// Predefined role checkers
const isAdmin = allowRoles('ADMIN');
const isEmployee = allowRoles('ADMIN', 'EMPLOYEE');
const isCoach = allowRoles('ADMIN', 'COACH');
const isSecurity = allowRoles('ADMIN', 'SECURITY');

module.exports = {
  allowRoles,
  isAdmin,
  isEmployee,
  isCoach,
  isSecurity
};
