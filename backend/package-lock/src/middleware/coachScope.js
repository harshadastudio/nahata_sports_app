'use strict';

/**
 * Per-Coach scoping helpers.
 *
 * A COACH may only see / act on records that belong to their OWN batches
 * (Batch.coachId). Every other role — super admin, complex admin, employee,
 * security, user — is left completely unaffected by these helpers, so existing
 * behavior never changes.
 *
 * This sits alongside `complexScope`: a coach is BOTH complex-scoped (they only
 * see their own sports complex) and coach-scoped (within that complex, only
 * their own batches). The two are applied together, never one instead of the
 * other.
 *
 * The Coach row is linked to the login by email — the same link every other
 * coach endpoint uses (see coachDashboardController) — because the Coaches
 * table has no userId column. The resolved id is memoized on the request, so a
 * handler that needs it more than once only hits the DB once.
 */

const { Coach } = require('../models');

const COACH_ROLE = 'COACH';

const roleOf = (req) => (req && req.user && req.user.role ? String(req.user.role).toUpperCase() : '');

/** Whether the current login is a coach (and therefore coach-scoped). */
const isCoach = (req) => roleOf(req) === COACH_ROLE;

/**
 * The Coach id a query must be restricted to, or `null` when it must NOT be
 * restricted (every non-coach role).
 *
 *  - COACH → their own Coach.id, or -1 when no Coach row is linked to their
 *    login, so a misconfigured coach matches nothing rather than falling
 *    through and seeing every other coach's data.
 *  - all other roles → null.
 */
async function resolveCoachId(req) {
  if (!isCoach(req)) return null;
  if (req._scopedCoachId !== undefined) return req._scopedCoachId;

  const coach = await Coach.findOne({
    where: { email: req.user.email },
    attributes: ['id'],
  });
  req._scopedCoachId = coach ? coach.id : -1;
  return req._scopedCoachId;
}

/**
 * Whether the current user may access a record owned by the given coach id.
 * Non-coach roles: always true. A coach: only their own batches — a batch with
 * no coach assigned (null) is never "theirs".
 */
async function canAccessCoach(req, recordCoachId) {
  const coachId = await resolveCoachId(req);
  if (coachId == null) return true;
  return recordCoachId != null && Number(recordCoachId) === Number(coachId);
}

/**
 * Express guard for a single record fetched by the route handler. Pass the
 * owning Batch.coachId; sends 403 and returns false when a coach is reaching
 * outside their own batches. Returns true when access is allowed.
 */
async function assertCoachAccess(req, res, recordCoachId) {
  if (await canAccessCoach(req, recordCoachId)) return true;
  res.status(403).json({
    success: false,
    message: 'Access denied: this record belongs to a different coach.',
  });
  return false;
}

module.exports = {
  COACH_ROLE,
  isCoach,
  resolveCoachId,
  canAccessCoach,
  assertCoachAccess,
};
