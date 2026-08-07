'use strict';

/**
 * Local image storage helpers.
 *
 * Cloudinary has been removed — images are stored on the server's own disk under
 * `<project>/uploads/...` and served at `/uploads/...`. The export names are kept
 * (`deleteFromCloudinary`, `extractPublicId`, `uploadToCloudinary`) so existing
 * imports keep working without changes.
 */

const fs = require('fs');
const path = require('path');

const UPLOAD_ROOT = path.join(__dirname, '../../uploads');

/**
 * Extract the storage "public id" (path relative to the uploads root) from an
 * image URL. Works for both absolute (`https://host/uploads/foo/bar.jpg`) and
 * relative (`/uploads/foo/bar.jpg`) URLs. Returns null for non-local URLs
 * (e.g. legacy Cloudinary links), which simply means "nothing local to delete".
 */
const extractPublicId = (url) => {
  if (!url || typeof url !== 'string') return null;
  const idx = url.indexOf('/uploads/');
  if (idx === -1) return null;
  // Strip the `/uploads/` prefix and any query string.
  return url.slice(idx + '/uploads/'.length).split('?')[0];
};

/**
 * Delete a locally-stored image given its public id (path relative to uploads root).
 * Safe no-op if the file/publicId is missing or outside the uploads directory.
 */
const deleteFromCloudinary = async (publicId) => {
  if (!publicId) return { result: 'not found' };
  // Prevent path traversal — resolve and ensure it stays inside UPLOAD_ROOT.
  const target = path.resolve(UPLOAD_ROOT, publicId);
  if (!target.startsWith(path.resolve(UPLOAD_ROOT))) {
    return { result: 'invalid path' };
  }
  try {
    await fs.promises.unlink(target);
    return { result: 'ok' };
  } catch (error) {
    if (error.code === 'ENOENT') return { result: 'not found' };
    console.error('Error deleting local image:', error.message);
    return { result: 'error', error: error.message };
  }
};

/**
 * Deprecated — kept only so any stray import does not crash. Uploads now go
 * through the local-disk upload middleware, not this function.
 */
const uploadToCloudinary = () => {
  throw new Error('uploadToCloudinary is removed — images are stored locally via the upload middleware.');
};

module.exports = {
  uploadToCloudinary,
  deleteFromCloudinary,
  extractPublicId,
};
