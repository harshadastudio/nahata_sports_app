'use strict';

const multer = require('multer');
const path = require('path');
const fs = require('fs');

// Create a flexible upload middleware factory
const createUploadMiddleware = (uploadType = 'general') => {
  // Ensure uploads directory exists
  const uploadDir = path.join(__dirname, `../../uploads/${uploadType}`);
  if (!fs.existsSync(uploadDir)) {
    fs.mkdirSync(uploadDir, { recursive: true });
  }

  const storage = multer.diskStorage({
    destination: (_req, _file, cb) => {
      cb(null, uploadDir);
    },
    filename: (_req, file, cb) => {
      const ext = path.extname(file.originalname).toLowerCase();
      const prefix = uploadType.replace(/s$/, ''); // Remove trailing 's' for singular
      const uniqueName = `${prefix}-${Date.now()}-${Math.round(Math.random() * 1e6)}${ext}`;
      cb(null, uniqueName);
    },
  });

  const fileFilter = (_req, file, cb) => {
    const allowed = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];
    if (allowed.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error('Only JPEG, PNG and WebP images are allowed'), false);
    }
  };

  return multer({
    storage,
    fileFilter,
    limits: { fileSize: 2 * 1024 * 1024 }, // 2 MB
  });
};

// Default export for sports-complexes (backward compatibility)
const upload = createUploadMiddleware('sports-complexes');

// Export both the default and the factory
module.exports = upload;
module.exports.createUploadMiddleware = createUploadMiddleware;
