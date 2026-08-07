'use strict';

/**
 * Per-Complex Admin scoping helpers.
 *
 * A COMPLEX_ADMIN may only see / act on records belonging to their own
 * `sportComplexId`. An ADMIN (super admin) — and every other role — is left
 * completely unaffected by these helpers, so existing behavior never changes.
 *
 * Two kinds of resources:
 *   - Direct-scoped  → the table itself has a `sportComplexId` column.
 *                      Use `complexWhere(req)` in the query `where`.
 *   - Join-scoped    → the complex is reached through an association
 *                      (e.g. Booking → Court.sportComplexId).
 *                      Use `resolveComplexId(req)` and apply it on the include.
 */

const SUPER_ADMIN_ROLE = 'ADMIN';
const COMPLEX_ADMIN_ROLE = 'COMPLEX_ADMIN';

// Every role that is locked to a single complex: a complex admin AND the staff
// logins (Employee / Security / Coach), who must only ever see the data of the
// complex they were created in. ADMIN (super admin) and USER are NOT scoped.
const COMPLEX_SCOPED_ROLES = [COMPLEX_ADMIN_ROLE, 'EMPLOYEE', 'SECURITY', 'COACH'];

const roleOf = (req) => (req && req.user && req.user.role ? String(req.user.role).toUpperCase() : '');

const isSuperAdmin = (req) => roleOf(req) === SUPER_ADMIN_ROLE;
const isComplexAdmin = (req) => roleOf(req) === COMPLEX_ADMIN_ROLE;

/**
 * Whether the current user is bound to a single complex (complex admin or staff
 * login). These users are always force-scoped to their own `sportComplexId` and
 * can never opt into another complex via query params.
 */
const isComplexScoped = (req) => COMPLEX_SCOPED_ROLES.includes(roleOf(req));

/**
 * The complex id a query must be restricted to, or `null` when it must NOT be
 * restricted (super admin / other roles see everything).
 *
 *  - COMPLEX_ADMIN → their own sportComplexId (or -1 if somehow unassigned, so a
 *    misconfigured complex admin matches nothing rather than seeing all data).
 *  - ADMIN / others → null, but a super admin may opt-in to filter one complex
 *    via the `?sportComplexId=` query param.
 */
function resolveComplexId(req) {
  if (isComplexScoped(req)) {
    const id = req.user.sportComplexId;
    return id != null ? Number(id) : -1;
  }
  const q = req && req.query ? req.query.sportComplexId : undefined;
  if (q !== undefined && q !== null && q !== '') {
    const n = Number(q);
    return Number.isNaN(n) ? null : n;
  }
  return null;
}

/**
 * A Sequelize `where` fragment for a DIRECT-scoped model. Returns `{}` when the
 * caller should not be restricted (super admin without a filter).
 * @param {object} req
 * @param {string} [column='sportComplexId']
 */
function complexWhere(req, column = 'sportComplexId') {
  const id = resolveComplexId(req);
  return id != null ? { [column]: id } : {};
}

/**
 * Force the complex id on a create/update payload.
 *  - COMPLEX_ADMIN → always their own complex (cannot be spoofed).
 *  - super admin    → honors an explicit body value if provided.
 * Mutates and returns `data`.
 */
function stampComplexId(req, data = {}) {
  if (isComplexScoped(req) && req.user.sportComplexId != null) {
    data.sportComplexId = Number(req.user.sportComplexId);
  } else if (req && req.body && req.body.sportComplexId != null) {
    data.sportComplexId = Number(req.body.sportComplexId);
  }
  return data;
}

/**
 * Whether the current user may access a record with the given complex id.
 * Super admin / other roles: always true. Complex admin: only their own.
 */
function canAccessComplex(req, recordComplexId) {
  if (!isComplexScoped(req)) return true;
  return Number(recordComplexId) === Number(req.user.sportComplexId);
}

/**
 * Express guard for a single record fetched by the route handler. Pass the
 * record's complex id; sends 403 and returns false if a complex admin is
 * reaching outside their complex. Returns true when access is allowed.
 */
function assertComplexAccess(req, res, recordComplexId) {
  if (canAccessComplex(req, recordComplexId)) return true;
  res.status(403).json({
    success: false,
    message: 'Access denied: this record belongs to a different sports complex.',
  });
  return false;
}

module.exports = {
  SUPER_ADMIN_ROLE,
  COMPLEX_ADMIN_ROLE,
  COMPLEX_SCOPED_ROLES,
  isSuperAdmin,
  isComplexAdmin,
  isComplexScoped,
  resolveComplexId,
  complexWhere,
  stampComplexId,
  canAccessComplex,
  assertComplexAccess,
};
