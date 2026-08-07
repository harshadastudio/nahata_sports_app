'use strict';

const express = require('express');
const courtController = require('../controllers/courtController');
const { authenticateToken } = require('../middleware/authMiddleware');
const { optionalAuth } = require('../middleware/optionalAuth');
const { allowRoles } = require('../middleware/roleMiddleware');
const { requireEmployeePermission, EMPLOYEE_PERMISSIONS } = require('../middleware/employeePermission');

const router = express.Router();

// Employee module gates. Complex scoping is handled separately by complexScope,
// so these only decide WHAT an employee may manage, never WHERE.
const empCourts = requireEmployeePermission(EMPLOYEE_PERMISSIONS.COURTS);
const empSlots = requireEmployeePermission(EMPLOYEE_PERMISSIONS.SLOTS);
// The toggle is the block/unblock action, reachable from the Slot page and from
// Blocked Slots — either module's permission is enough.
const empSlotToggle = requireEmployeePermission([
  EMPLOYEE_PERMISSIONS.SLOTS,
  EMPLOYEE_PERMISSIONS.BLOCKED_SLOTS,
]);

// ── User booking routes (specific paths first to avoid :id conflict) ──────────
router.get('/bookings/my', authenticateToken, courtController.getMyBookings);
router.post('/bookings/create', authenticateToken, courtController.createBooking);
router.post('/bookings/cancel', authenticateToken, courtController.cancelBookings);
// Release an unpaid hold (checkout cancelled/dismissed/failed) — frees the slot
// immediately instead of waiting for holdExpiresAt.
router.post('/bookings/:bookingId/release', authenticateToken, courtController.releaseBooking);
router.post('/bookings/:bookingId/send-email', authenticateToken, courtController.sendPassByEmail);

// ── Booking members + scanning ────────────────────────────────────────────────
// Live stats + scan routes are public so security tablets work without login.
router.get('/bookings/scan-stats', courtController.getScanStats);
router.post('/bookings/scan', courtController.scanPass);
router.post('/members/:memberId/scan', courtController.scanMember);
router.post('/bookings/:bookingId/members', authenticateToken, courtController.saveMembers);
router.post('/bookings/:bookingId/members/:memberId/send-email', authenticateToken, courtController.sendMemberPassByEmail);

// ── Public — court-hidden availability (time-first booking) ───────────────────
// (literal paths registered before '/:id' so they aren't captured as an id)
router.get('/availability', courtController.getAvailability);
router.get('/availability/times', courtController.getAvailabilityTimes);

// ── Public — frontend reads courts & available slots ──────────────────────────
// optionalAuth: anonymous = all courts (website); logged-in COMPLEX_ADMIN = own complex only.
router.get('/', optionalAuth, courtController.getAllCourts);
router.get('/:id', optionalAuth, courtController.getCourtById);
router.get('/:id/available-slots', courtController.getAvailableSlots);

// ── Court CRUD (admin + permitted employees) ──────────────────────────────────
router.post('/', authenticateToken, allowRoles('ADMIN', 'COMPLEX_ADMIN', 'EMPLOYEE'), empCourts, courtController.createCourt);
router.put('/:id', authenticateToken, allowRoles('ADMIN', 'COMPLEX_ADMIN', 'EMPLOYEE'), empCourts, courtController.updateCourt);
router.delete('/:id', authenticateToken, allowRoles('ADMIN', 'COMPLEX_ADMIN', 'EMPLOYEE'), empCourts, courtController.deleteCourt);
router.patch('/:id/show-on-frontend', authenticateToken, allowRoles('ADMIN', 'COMPLEX_ADMIN', 'EMPLOYEE'), empCourts, courtController.toggleShowOnFrontend);

// ── CourtSlot CRUD (admin) ────────────────────────────────────────────────────
// GET    /api/courts/:id/slots               — list all slots for a court
// POST   /api/courts/:id/slots               — create a new slot for a court
// PUT    /api/courts/:id/slots/:slotId       — update a slot
// DELETE /api/courts/:id/slots/:slotId       — delete a slot
// PATCH  /api/courts/:id/slots/:slotId/toggle — toggle Active/Inactive
router.get('/:id/slots', optionalAuth, courtController.getSlotsByCourt);
router.post('/:id/slots', authenticateToken, allowRoles('ADMIN', 'COMPLEX_ADMIN', 'EMPLOYEE'), empSlots, courtController.createSlot);
router.put('/:id/slots/:slotId', authenticateToken, allowRoles('ADMIN', 'COMPLEX_ADMIN', 'EMPLOYEE'), empSlots, courtController.updateSlot);
router.delete('/:id/slots/:slotId', authenticateToken, allowRoles('ADMIN', 'COMPLEX_ADMIN', 'EMPLOYEE'), empSlots, courtController.deleteSlot);
router.patch('/:id/slots/:slotId/toggle', authenticateToken, allowRoles('ADMIN', 'COMPLEX_ADMIN', 'EMPLOYEE'), empSlotToggle, courtController.toggleSlotStatus);

// ── Date-specific block / unblock ─────────────────────────────────────────────
// POST /api/courts/:id/slots/:slotId/block    — body { date, notes? }
// POST /api/courts/:id/slots/:slotId/unblock  — body { date }
// Unlike /toggle (which flips the template for EVERY date), these affect one date.
router.post('/:id/slots/:slotId/block', authenticateToken, allowRoles('ADMIN', 'COMPLEX_ADMIN', 'EMPLOYEE'), empSlotToggle, courtController.blockSlotForDate);
router.post('/:id/slots/:slotId/unblock', authenticateToken, allowRoles('ADMIN', 'COMPLEX_ADMIN', 'EMPLOYEE'), empSlotToggle, courtController.unblockSlotForDate);

module.exports = router;
