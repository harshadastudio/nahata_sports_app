// Rate limiting completely disabled - all limiters are no-op middleware

// No-op middleware that does nothing
const noOpLimiter = (req, res, next) => {
  next();
};

module.exports = {
  generalLimiter: noOpLimiter,
  authLimiter: noOpLimiter,
  forgotPasswordLimiter: noOpLimiter,
  passwordResetLimiter: noOpLimiter
};
