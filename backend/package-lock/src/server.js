require('dotenv').config();
const express = require('express');
const cors = require('cors');
const cookieParser = require('cookie-parser');
const { sequelize } = require('./models');
const logger = require('./utils/logger');
// const { generalLimiter, authLimiter, forgotPasswordLimiter, passwordResetLimiter } = require('./middleware/rateLimitMiddleware');

// Validate required environment variables
const requiredEnvVars = ['JWT_ACCESS_SECRET', 'JWT_REFRESH_SECRET', 'DB_HOST', 'DB_USER', 'DB_PASSWORD', 'DB_NAME'];
const missingEnvVars = requiredEnvVars.filter(key => !process.env[key]);

if (missingEnvVars.length > 0) {
  console.error('❌ Missing required environment variables:');
  missingEnvVars.forEach(key => {
    console.error(`   - ${key}`);
  });
  console.error('\n📝 Please add these variables to your .env file');
  console.error('📄 Copy .env.example to .env and fill in the values');
  process.exit(1);
}

const app = express();
const PORT = process.env.PORT || 5050;

// Trust the first proxy hop (Render, Railway, Vercel, etc.)
// This ensures req.ip and rate limiters see the real client IP, not the proxy IP
app.set('trust proxy', 1);

console.log('✅ Environment variables validated');
console.log(`🔧 Environment: ${process.env.NODE_ENV || 'development'}`);

// NOTE: The previous startup routine printed EVERY environment variable (DB
// password, JWT secrets, Razorpay secret, etc.) to the logs when NODE_ENV was
// 'development'. That has been removed — secrets must never be logged.

// ── CORS (strict allow-list) ──────────────────────────────────────────────────
// Trusted browser origins are configured explicitly via env. There is NO
// substring/wildcard matching: an origin is allowed only if it exactly equals a
// configured origin (or is localhost outside production, for local dev).
//
// Configure:
//   FRONTEND_URL           production customer site (e.g. https://nahatasports.in)
//   ADMIN_URL              production admin panel   (e.g. https://admin.nahatasports.com)
//   CORS_ALLOWED_ORIGINS   comma-separated extra trusted origins (incl. any Vercel
//                          preview URLs you want to allow — add them explicitly)
const isProd = process.env.NODE_ENV === 'production';

const allowedOrigins = new Set(
  [
    process.env.FRONTEND_URL,
    process.env.ADMIN_URL,
    ...(process.env.CORS_ALLOWED_ORIGINS || '').split(','),
  ]
    .filter(Boolean)
    .map((u) => u.trim().replace(/\/$/, ''))
);

function isAllowedOrigin(origin) {
  if (allowedOrigins.has(origin)) return true;
  // Localhost is permitted only OUTSIDE production (covers local dev and the
  // current staging setup that serves a localhost frontend).
  if (!isProd) {
    try {
      const host = new URL(origin).hostname.toLowerCase();
      if (host === 'localhost' || host === '127.0.0.1') return true;
    } catch (_e) {
      /* malformed origin → not allowed */
    }
  }
  return false;
}

// Middleware
app.use((req, res, next) => {
  res.setHeader('Cross-Origin-Opener-Policy', 'same-origin-allow-popups');
  next();
});
app.use(cors({
  origin: function (origin, callback) {
    // No Origin header → non-browser client (server-to-server, curl, Postman,
    // KheloMore/Huddle partner APIs). CORS is a browser protection; these are
    // unaffected and allowed.
    if (!origin) return callback(null, true);

    if (isAllowedOrigin(origin)) return callback(null, true);

    logger.warn('cors.blocked', { origin });
    return callback(new Error('Not allowed by CORS'));
  },
  credentials: true,
  methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
  // x-client-platform lets a client declare itself as web/android/ios — see
  // utils/clientPlatform.js (used by platform-restricted coupons).
  allowedHeaders: ["Content-Type", "Authorization", "x-webhook-token", "x-client-platform", "x-platform", "x-app-platform"],
}));
app.use(cookieParser());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Serve uploaded files
app.use('/uploads', express.static(require('path').join(__dirname, '../uploads')));

// Apply general rate limiting to all requests
// app.use(generalLimiter);

// Routes
app.use('/api/auth', require('./routes/authRoutes'));
app.use('/api/admin', require('./routes/adminRoutes'));
app.use('/api/memberships', require('./routes/membershipRoutes'));
app.use('/api/blogs', require('./routes/blogRoutes'));
app.use('/api/sports', require('./routes/sportRoutes'));
app.use('/api/coaches', require('./routes/coachRoutes'));
app.use('/api/batches', require('./routes/batchRoutes'));
app.use('/api/sports-complexes', require('./routes/sportsComplexRoutes'));
app.use('/api/permissions', require('./routes/permissionsRoutes'));
app.use('/api/announcements', require('./routes/announcementRoutes'));
app.use('/api/event-passes', require('./routes/eventPassRoutes'));
app.use('/api/courts', require('./routes/courtRoutes'));
app.use('/api/bookings', require('./routes/bookingRoutes'));

// Khelomore court-specified booking surface (JWT Bearer auth). Separate from the
// website's court-hidden /api/courts flow: every booking names an explicit
// courtId here. See routes/khelomoreBookingRoutes.js.
app.use('/api/nahatasports', require('./routes/khelomoreBookingRoutes'));

// Khelomore aggregator adapter (court-wise booking surface for the 3rd party).
// Mounted at '/' with a per-route X-Khelomore-Key guard; passes through all
// non-Khelomore paths, so it does not affect any existing route.
app.use('/', require('./routes/khelomoreRoutes'));


app.use('/api/admin/complex-admins', require('./routes/complexAdminRoutes'));
app.use('/api/admin/employees', require('./routes/employeeRoutes'));
app.use('/api/admin/coupons', require('./routes/couponRoutes'));

// Public coupon route — accessible to any authenticated user (USER role included)
// POST /api/coupons/validate  → validate code & return discount details
app.use('/api/coupons', require('./routes/couponRoutes'));

app.use('/api/students', require('./routes/studentRoutes'));
app.use('/api/contact-us', require('./routes/contactUsRoutes'));
app.use('/api/user-feedback', require('./routes/userFeedbackRoutes'));
app.use('/api/student-parent-features', require('./routes/studentParentFeatureRoutes'));
app.use('/api/faqs', require('./routes/faqRoutes'));
app.use('/api/legal', require('./routes/legalPageRoutes'));
app.use('/api/about', require('./routes/aboutPageRoutes'));
app.use('/api/page-seo', require('./routes/pageSeoRoutes'));
app.use('/api/hero-slides', require('./routes/heroSlideRoutes'));
app.use('/api/cms-sports', require('./routes/cmsSportRoutes'));
app.use('/api/cms-courts', require('./routes/cmsCourtRoutes'));
app.use('/api/visitor-passes', require('./routes/visitorPassRoutes'));


app.use('/api/coaching-enquiries', require('./routes/coachingEnquiryRoutes'));

app.use('/api/attendance', require('./routes/attendanceRoutes'));
app.use('/api/fees', require('./routes/feesRoutes'));

app.use('/api/payments', require('./routes/paymentRoutes'));

app.use('/api/notifications', require('./routes/notificationRoutes'));
app.use('/api/reports', require('./routes/reportsRoutes'));
app.use('/api/settings', require('./routes/settingsRoutes'));
app.use('/api/dashboard', require('./routes/dashboardRoutes'));

// Coach Dashboard Routes
app.use('/api/coach/dashboard', require('./routes/coachDashboardRoutes'));



// Apply specific rate limiting to sensitive endpoints
// app.post('/api/auth/forgot-password', forgotPasswordLimiter);
// app.post('/api/auth/reset-password', passwordResetLimiter);
// app.post('/api/auth/set-password', passwordResetLimiter);

// Test route
app.get('/', (req, res) => {
  res.json({ message: 'Welcome to Nahata Sports API' });
});

// ─── Centralized Error Handler ────────────────────────────────────────────────
// Must be defined after all routes. Catches errors passed via next(error).
const multer = require('multer');

app.use((err, req, res, next) => {
  console.error('❌ Unhandled error:', err.message);

  // Image-upload errors must NOT be masked as a generic 500 — the client needs
  // to know the photo was too large / the wrong type so it can be re-picked.
  // (Multer rejections reach here via next(err), bypassing the route handler.)
  if (err instanceof multer.MulterError) {
    const msg = err.code === 'LIMIT_FILE_SIZE'
      ? 'Image is too large. Please upload an image under 2 MB.'
      : err.code === 'LIMIT_UNEXPECTED_FILE'
        ? 'Unexpected file field in upload.'
        : 'Image upload failed. Please try a different image.';
    return res.status(400).json({ success: false, message: msg });
  }
  // The image fileFilter rejects unsupported types with a plain Error.
  if (err.message && /Only JPEG, PNG and WebP images are allowed/i.test(err.message)) {
    return res.status(400).json({ success: false, message: err.message });
  }

  // Never expose stack traces or DB internals in production
  const isDev = process.env.NODE_ENV === 'development';

  return res.status(err.status || 500).json({
    success: false,
    message: isDev ? err.message : 'Internal server error.',
    ...(isDev && { stack: err.stack }),
  });
});

// Database connection and server start
const startServer = async () => {
  try {
    await sequelize.authenticate();
    console.log('Database connection has been established successfully.');
    
    // Don't sync database - we use migrations instead
    // await sequelize.sync({ alter: true });
    console.log('✅ Using migrations for database schema management.');
    console.log('💡 Run "npx sequelize-cli db:migrate" to apply migrations.');
    
    app.listen(PORT, () => {
      console.log(`🚀 Server is running on port ${PORT}`);
      console.log(`📍 API URL: http://localhost:${PORT}`);
      console.log(`🌐 Frontend URL: ${process.env.FRONTEND_URL || 'http://localhost:3000'}`);
    });
  } catch (error) {
    console.error('Unable to connect to the database:', error);
    if (error.message.includes('does not exist')) {
      console.log('Please create the database first or check your .env configuration.');
    }
    process.exit(1);
  }
};

startServer();

module.exports = app;


// stage
