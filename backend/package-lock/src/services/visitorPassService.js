'use strict';

const { Visitor, VisitorPass, EntryLog, User, SportComplex } = require('../models');
const { Op } = require('sequelize');
const crypto = require('crypto');

// ── Helpers ───────────────────────────────────────────────────────────────────

/**
 * Generate a unique pass number like VP-20260430-A3F9
 */
const generatePassNumber = () => {
  const date = new Date().toISOString().slice(0, 10).replace(/-/g, '');
  const rand = crypto.randomBytes(3).toString('hex').toUpperCase();
  return `VP-${date}-${rand}`;
};

/**
 * Build a QR code URL from pass data
 */
const buildQrUrl = (passNumber, visitorName) => {
  const data = `VISITOR|${passNumber}|${visitorName}`;
  return `https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${encodeURIComponent(data)}`;
};

/**
 * Derive the pass lifecycle state from the stored row.
 *
 * DB status  →  API status
 *   Active                       → 'active'      (QR valid — visitor may enter)
 *   CheckedIn / Used (legacy)    → 'checked_in'  (QR valid ONLY for the exit scan)
 *   CheckedOut / checkOutTime    → 'checked_out' (QR is dead — visit is over)
 *   Expired / past validUntil    → 'expired'
 *   Cancelled                    → 'cancelled'
 *
 * Expiry is computed, not just read, so a pass that ran past its validUntil
 * reads as 'expired' everywhere even if no scan has persisted that yet.
 */
const derivePassStatus = (pass) => {
  const raw = pass.status || 'Active';

  if (raw === 'Cancelled') return 'cancelled';
  if (raw === 'CheckedOut' || pass.checkOutTime) return 'checked_out';
  if (raw === 'CheckedIn' || raw === 'Used' || pass.checkInTime) return 'checked_in';
  if (raw === 'Expired') return 'expired';
  if (pass.validUntil && new Date() > new Date(pass.validUntil)) return 'expired';
  return 'active';
};

/**
 * What (if anything) the QR can still be scanned for.
 * A checked-out pass is permanently invalid — that is the whole point of the
 * check-out scan.
 */
const scanAffordance = (status) => {
  if (status === 'active') return 'entry';
  if (status === 'checked_in') return 'exit';
  return null;
};

/**
 * Normalise a VisitorPass row into the shape the frontend expects.
 */
const formatPass = (pass) => {
  const v = pass.Visitor || {};
  const status = derivePassStatus(pass);
  const validFor = scanAffordance(status);

  return {
    id: String(pass.id),
    visitorName: v.name || '',
    phoneNumber: v.phone || '',
    visitPurpose: v.purpose || '',
    passCode: pass.passNumber,
    qrData: pass.passNumber,
    qrUrl: pass.qrCode,
    // 'active' | 'checked_in' | 'checked_out' | 'expired' | 'cancelled'
    status,
    generatedAt: pass.createdAt
      ? new Date(pass.createdAt).toLocaleString('en-IN')
      : '',
    scannedAt: pass.checkInTime
      ? new Date(pass.checkInTime).toLocaleString('en-IN')
      : null,
    // ISO timestamps for the check-in / check-out lifecycle
    checkInTime: pass.checkInTime || null,
    checkOutTime: pass.checkOutTime || null,
    // Is the QR still usable, and for which direction?
    qrValid: validFor !== null,
    qrValidFor: validFor,           // 'entry' | 'exit' | null
    validFrom: pass.validFrom,
    validUntil: pass.validUntil,
    notes: pass.notes || null,
    // raw ids for internal use
    visitorId: pass.visitorId,
    issuedBy: pass.issuedBy,
    sportComplexId: pass.sportComplexId,
    sportComplex: pass.sportComplex
      ? { id: pass.sportComplex.id, name: pass.sportComplex.name }
      : null,
  };
};

// ── CRUD ──────────────────────────────────────────────────────────────────────

/**
 * List all visitor passes with pagination.
 */
exports.getAllPasses = async (filters = {}, page = 1, limit = 10) => {
  const where = {};
  if (filters.status) {
    // Accept 'active', 'Active', 'checked_in', 'checkedIn', 'used' (legacy), …
    const key = String(filters.status).toLowerCase().replace(/[^a-z]/g, '');
    const now = new Date();

    switch (key) {
      case 'active':
        // Still enterable: never scanned AND not past its validity window.
        where.status = 'Active';
        where.validUntil = { [Op.gte]: now };
        break;
      case 'checkedin':
      case 'used': // legacy filter value — same set of passes
        where.status = { [Op.in]: ['CheckedIn', 'Used'] };
        where.checkOutTime = { [Op.is]: null };
        break;
      case 'checkedout':
        where[Op.or] = [{ status: 'CheckedOut' }, { checkOutTime: { [Op.ne]: null } }];
        break;
      case 'expired':
        // Persisted as Expired, or simply run past validUntil without a scan.
        where[Op.or] = [
          { status: 'Expired' },
          { status: 'Active', validUntil: { [Op.lt]: now } },
        ];
        break;
      case 'cancelled':
        where.status = 'Cancelled';
        break;
      default:
        break;
    }
  }

  // Per-complex admin scoping (no-op when not provided)
  if (filters.sportComplexId != null) {
    where.sportComplexId = filters.sportComplexId;
  }

  // Date filter — match passes created on a specific date
  if (filters.date) {
    const start = new Date(filters.date);
    start.setHours(0, 0, 0, 0);
    const end = new Date(filters.date);
    end.setHours(23, 59, 59, 999);
    where.createdAt = { [Op.between]: [start, end] };
  }

  const visitorWhere = {};
  if (filters.search) {
    visitorWhere[Op.or] = [
      { name: { [Op.iLike]: `%${filters.search}%` } },
      { phone: { [Op.iLike]: `%${filters.search}%` } },
    ];
  }

  const offset = (page - 1) * limit;

  const { count, rows } = await VisitorPass.findAndCountAll({
    where,
    include: [
      {
        model: Visitor,
        where: Object.keys(visitorWhere).length ? visitorWhere : undefined,
        required: Object.keys(visitorWhere).length > 0,
      },
      { model: SportComplex, as: 'sportComplex', attributes: ['id', 'name'], required: false },
    ],
    order: [['createdAt', 'DESC']],
    limit,
    offset,
  });

  return {
    passes: rows.map(formatPass),
    currentPage: page,
    totalPages: Math.ceil(count / limit),
    totalItems: count,
    itemsPerPage: limit,
  };
};

/**
 * Get a single pass by id or passNumber.
 */
exports.getPassById = async (id) => {
  // Try numeric id first, then passNumber
  const pass = isNaN(id)
    ? await VisitorPass.findOne({ where: { passNumber: id }, include: [Visitor] })
    : await VisitorPass.findByPk(id, { include: [Visitor] });

  return pass ? formatPass(pass) : null;
};

/**
 * Generate a new visitor pass.
 * Creates a Visitor record + a VisitorPass record in one transaction.
 */
exports.generatePass = async ({ visitorName, phoneNumber, visitPurpose, issuedBy, sportComplexId }) => {
  // Normalise purpose to match the ENUM
  const purposeMap = {
    'sports activity': 'Visit',
    'meeting': 'Meeting',
    'event': 'Visit',
    'training': 'Visit',
    'maintenance': 'Service',
    'other': 'Other',
    'delivery': 'Delivery',
  };
  const normPurpose = purposeMap[(visitPurpose || '').toLowerCase()] || 'Visit';

  // Create visitor
  const visitor = await Visitor.create({
    name: visitorName,
    phone: phoneNumber,
    purpose: normPurpose,
    status: 'Expected',
  });

  const passNumber = generatePassNumber();
  const now = new Date();
  const validUntil = new Date(now);
  validUntil.setHours(23, 59, 59, 999); // valid until end of today

  const qrCode = buildQrUrl(passNumber, visitorName);

  const pass = await VisitorPass.create({
    visitorId: visitor.id,
    passNumber,
    validFrom: now,
    validUntil,
    issuedBy: issuedBy || 1, // fallback to admin id=1 if not provided
    sportComplexId: sportComplexId != null ? sportComplexId : null, // Per-complex admin scoping
    qrCode,
    status: 'Active',
  });

  // Reload with association
  const full = await VisitorPass.findByPk(pass.id, { include: [Visitor] });
  return formatPass(full);
};

/**
 * Find a pass by passNumber (primary lookup) or numeric id.
 */
const findPass = async (passCode) => {
  let pass = await VisitorPass.findOne({
    where: { passNumber: passCode },
    include: [Visitor],
  });

  if (!pass && !isNaN(passCode)) {
    pass = await VisitorPass.findByPk(passCode, { include: [Visitor] });
  }

  return pass;
};

const timeLabel = (value) => (value ? new Date(value).toLocaleString('en-IN') : '');

/**
 * Scan a pass at the gate.
 *
 * `scanType` decides the direction:
 *   'In'  → first scan. Marks the pass CheckedIn and opens an EntryLog.
 *   'Out' → closing scan. Marks the pass CheckedOut, closes the EntryLog, and
 *           permanently invalidates the QR.
 *
 * A checked-out pass is rejected in both directions — that is what makes the QR
 * single-visit. An exit scan is deliberately allowed after validUntil: a visitor
 * who is already inside must always be able to leave.
 */
exports.verifyPass = async (passCode, scannedBy, scanType = 'In') => {
  const direction = String(scanType).toLowerCase() === 'out' ? 'Out' : 'In';

  const pass = await findPass(passCode);
  if (!pass) {
    return { valid: false, message: 'Pass not found in the system.' };
  }

  const now = new Date();
  const state = derivePassStatus(pass);

  if (state === 'cancelled') {
    return { valid: false, message: 'This pass has been cancelled.', data: formatPass(pass) };
  }

  // The visit is over — the QR is dead in both directions.
  if (state === 'checked_out') {
    return {
      valid: false,
      message: `This pass was already checked out${pass.checkOutTime ? ' at ' + timeLabel(pass.checkOutTime) : ''}. The QR code is no longer valid.`,
      data: formatPass(pass),
    };
  }

  // ── OUT scan ──────────────────────────────────────────────────────────────
  if (direction === 'Out') {
    if (state !== 'checked_in') {
      return {
        valid: false,
        message: 'This visitor has not checked in yet. Scan IN first.',
        data: formatPass(pass),
      };
    }

    await pass.update({ status: 'CheckedOut', checkOutTime: now });

    // Close the open entry log, or record a standalone exit if none exists
    // (e.g. a legacy pass marked Used before entry logging was reliable).
    const openLog = await EntryLog.findOne({
      where: { visitorPassId: pass.id, exitTime: { [Op.is]: null } },
      order: [['entryTime', 'DESC']],
    });

    if (openLog) {
      await openLog.update({ exitTime: now, scanType: 'Both' });
    } else {
      await EntryLog.create({
        visitorPassId: pass.id,
        entryTime: pass.checkInTime || now,
        exitTime: now,
        scanType: 'Exit',
        securityGuardId: scannedBy || null,
      });
    }

    await Visitor.update({ status: 'CheckedOut' }, { where: { id: pass.visitorId } });

    const updated = await VisitorPass.findByPk(pass.id, { include: [Visitor] });
    return {
      valid: true,
      direction: 'Out',
      message: 'Check-out recorded. This pass is now closed and the QR is no longer valid.',
      data: formatPass(updated),
    };
  }

  // ── IN scan ───────────────────────────────────────────────────────────────
  if (state === 'checked_in') {
    return {
      valid: false,
      message: `This visitor is already checked in${pass.checkInTime ? ' at ' + timeLabel(pass.checkInTime) : ''}. Scan OUT to close the visit.`,
      data: formatPass(pass),
    };
  }

  if (state === 'expired') {
    // Persist the expiry so the pass stops showing as Active.
    if (pass.status === 'Active') await pass.update({ status: 'Expired' });
    return { valid: false, message: 'This pass has expired.', data: formatPass(pass) };
  }

  await pass.update({ status: 'CheckedIn', checkInTime: now });

  // NOTE: EntryLog.userId is a FK to Users — pass.visitorId is a Visitors id, so
  // it is deliberately left null. The visitor is reachable via visitorPassId.
  await EntryLog.create({
    visitorPassId: pass.id,
    entryTime: now,
    scanType: 'Entry',
    securityGuardId: scannedBy || null,
  });

  await Visitor.update({ status: 'CheckedIn' }, { where: { id: pass.visitorId } });

  const updated = await VisitorPass.findByPk(pass.id, { include: [Visitor] });
  return {
    valid: true,
    direction: 'In',
    message: 'Check-in recorded. Entry granted.',
    data: formatPass(updated),
  };
};

/**
 * READ-ONLY validity check by passNumber / id.
 *
 * Unlike verifyPass, this NEVER mutates the pass — it does not mark it Used,
 * does not auto-expire, and writes no EntryLog. Used by the "Verify Pass" screen
 * so a guard can inspect a pass's validity/details without consuming it.
 * Returns the pass details (when found) regardless of validity so the UI can
 * show the current status (Active / Used / Expired).
 */
exports.lookupPass = async (passCode) => {
  const pass = await findPass(passCode);

  if (!pass) {
    return { valid: false, message: 'Pass not found in the system.' };
  }

  const formatted = formatPass(pass);

  switch (formatted.status) {
    case 'cancelled':
      return { valid: false, message: 'This pass has been cancelled.', data: formatted };
    case 'checked_out':
      return {
        valid: false,
        message: `This visitor checked out${pass.checkOutTime ? ' at ' + timeLabel(pass.checkOutTime) : ''}. The QR code is no longer valid.`,
        data: formatted,
      };
    case 'checked_in':
      // Still a live pass — it just can't be used for another entry.
      return {
        valid: true,
        message: `Visitor is currently checked in${pass.checkInTime ? ' since ' + timeLabel(pass.checkInTime) : ''}. The QR is valid for the check-out scan.`,
        data: formatted,
      };
    case 'expired':
      // Report expiry WITHOUT persisting a status change (read-only).
      return { valid: false, message: 'This pass has expired.', data: formatted };
    default:
      return {
        valid: true,
        message: 'Pass is valid and active. (Not consumed — use Entry Scanner to record check-in.)',
        data: formatted,
      };
  }
};

/**
 * Email a visitor pass (with its QR) to a recipient.
 */
exports.sendPassByEmail = async (id, recipientEmail, recipientName) => {
  const pass = await VisitorPass.findByPk(id, {
    include: [Visitor, { model: SportComplex, as: 'sportComplex', attributes: ['id', 'name'], required: false }],
  });
  if (!pass) throw new Error('Visitor pass not found');

  const v = pass.Visitor || {};
  const emailService = require('./emailService');
  await emailService.sendVisitorPassEmail({
    to: recipientEmail,
    name: recipientName || v.name || 'Visitor',
    passCode: pass.passNumber,
    qrCodeUrl: pass.qrCode || buildQrUrl(pass.passNumber, v.name || ''),
    purpose: v.purpose || '',
    complexName: pass.sportComplex ? pass.sportComplex.name : '',
    validFrom: pass.validFrom,
    validUntil: pass.validUntil,
  });

  return { message: 'Visitor pass emailed successfully' };
};

/**
 * Delete a visitor pass (and its visitor record).
 */
exports.deletePass = async (id) => {
  const pass = await VisitorPass.findByPk(id);
  if (!pass) return false;
  const visitorId = pass.visitorId;
  await pass.destroy();
  // Clean up orphan visitor
  await Visitor.destroy({ where: { id: visitorId } });
  return true;
};
