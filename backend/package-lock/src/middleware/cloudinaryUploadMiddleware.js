'use strict';

/**
 * Image upload middleware — LOCAL SERVER STORAGE.
 *
 * Images are stored on the server's own disk under `<project>/uploads/nahata-sports/<folder>/`
 * and served statically by Express at `/uploads/...` (see server.js).
 *
 * NOTE: the export names (`upload`, `uploadToCloudinaryMiddleware`) and the
 * `req.cloudinaryResult` shape are kept identical to the previous Cloudinary
 * implementation so that every route/controller keeps working unchanged.
 */

const multer = require('multer');
const fs = require('fs');
const path = require('path');

// Root of the publicly-served uploads directory (matches express.static in server.js).
const UPLOAD_ROOT = path.join(__dirname, '../../uploads');

// Keep files in memory until they pass the filter/size limit, then write to disk.
const storage = multer.memoryStorage();

// File filter for images only
const fileFilter = (_req, file, cb) => {
  const allowed = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];
  if (allowed.includes(file.mimetype)) {
    cb(null, true);
  } else {
    cb(new Error('Only JPEG, PNG and WebP images are allowed'), false);
  }
};

// Create multer upload middleware
const upload = multer({
  storage,
  fileFilter,
  limits: { fileSize: 2 * 1024 * 1024 }, // 2 MB
});

const MIME_EXT = {
  'image/jpeg': '.jpg',
  'image/jpg': '.jpg',
  'image/png': '.png',
  'image/webp': '.webp',
};

// Build the public origin of THIS API server so stored image URLs are absolute
// (mirrors the previous Cloudinary absolute-URL behaviour).
//
// IMPORTANT: derive the origin from the *incoming request*, i.e. the server that
// actually received the upload and wrote the file to its own disk — NOT from a
// hardcoded env var. Using a fixed API_BASE_URL breaks local development (a file
// saved on localhost would get a production URL that 404s). Behind a proxy
// (Render/Nginx) we honour X-Forwarded-Proto so production URLs stay https.
const getServerOrigin = (req) => {
  const proto = String(req.headers['x-forwarded-proto'] || req.protocol || 'http')
    .split(',')[0]
    .trim();
  const host = req.get('host');
  return `${proto}://${host}`;
};

// Middleware to persist the uploaded file to local disk after multer parses it.
const uploadToCloudinaryMiddleware = (folderName) => {
  return async (req, res, next) => {
    try {
      if (!req.file) {
        return next();
      }

      const safeFolder = String(folderName).replace(/[^a-z0-9/_-]/gi, '-');
      const dir = path.join(UPLOAD_ROOT, 'nahata-sports', safeFolder);
      fs.mkdirSync(dir, { recursive: true });

      // Determine extension from the original name, falling back to the mimetype.
      let ext = path.extname(req.file.originalname || '').toLowerCase();
      if (!ext) ext = MIME_EXT[req.file.mimetype] || '.jpg';

      const prefix = safeFolder.split('/').pop();
      const filename = `${prefix}-${Date.now()}-${Math.round(Math.random() * 1e9)}${ext}`;
      const absPath = path.join(dir, filename);

      fs.writeFileSync(absPath, req.file.buffer);

      // publicId = path relative to the uploads root (used for deletion later).
      const publicId = `nahata-sports/${safeFolder}/${filename}`;
      const relativeUrl = `/uploads/${publicId}`;

      req.cloudinaryResult = {
        url: `${getServerOrigin(req)}${relativeUrl}`,
        publicId,
        relativeUrl,
        format: ext.replace('.', ''),
        width: null,
        height: null,
      };

      next();
    } catch (error) {
      console.error('Local image upload error:', error);
      return res.status(500).json({
        success: false,
        message: 'Failed to save image to server storage',
        error: error.message,
      });
    }
  };
};

module.exports = {
  upload,
  uploadToCloudinaryMiddleware,
};
