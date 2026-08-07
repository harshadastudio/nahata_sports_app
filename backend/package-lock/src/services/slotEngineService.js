'use strict';

/**
 * Slot engine — court-hidden availability + auto-consolidation.
 *
 * PURE module: no Sequelize / DB access. Callers (courtService, controllers)
 * load the equivalent courts (+ their active CourtSlot templates for the
 * weekday) and that date's bookings, then pass plain objects in here.
 *
 * Core idea: courts of the same sport+venue+rate are interchangeable, and the
 * end user never sees a court. So when no single court is free for a continuous
 * block, we may MOVE existing (movable) bookings onto other equivalent courts
 * to free one court for the whole block.
 *
 * Expected shapes:
 *   court   = { id, capacity, externalResourceId, hourlyRate,
 *               slots: [{ startTime, endTime, slotType, priceOverride }] }   // weekday-active templates
 *   booking = { id, courtId, userId, startTime, endTime, bookingStatus,
 *               holdExpiresAt, bookingSource, maxPersons, isDeleted,
 *               isBlocked }                                                  // for ONE date, across the courts
 */

const { toMinutes, toEndMinutes, toTimeString } = require('../utils/timeIntervals');
const { getPartnerSources } = require('../config/partnerSources');

/**
 * Bookings from these sources are never moved (external aggregator owns them).
 * Every registered partner qualifies, so onboarding a platform protects it without
 * touching this list. 'Playo' predates the registry and is kept explicitly.
 */
const NON_MOVABLE_SOURCES = [...new Set(['Playo', ...getPartnerSources()])];

// ── small helpers ─────────────────────────────────────────────────────────────

function courtById(courts, id) {
  return courts.find((c) => c.id === id) || null;
}

/** Does any busy interval overlap [startMin, endMin)? (half-open) */
function hasOverlap(intervals, startMin, endMin) {
  return intervals.some((iv) => iv.startMin < endMin && iv.endMin > startMin);
}

/** A hold occupies the slot unless it is an EXPIRED pending hold. */
function isHoldActive(booking, nowDate) {
  if (!booking.holdExpiresAt) return true; // confirmed / permanent
  return new Date(booking.holdExpiresAt) > nowDate;
}

/** Sorted template segments [{ s, e, p }] (minutes + per-cell price or null). */
function courtSegments(court) {
  return (court.slots || [])
    .map((s) => {
      const start = toMinutes(s.startTime);
      return {
        s: start,
        e: toEndMinutes(s.endTime, start), // 00:00 close -> 1440 (end of day)
        p: s.priceOverride !== null && s.priceOverride !== undefined ? parseFloat(s.priceOverride) : null,
      };
    })
    .sort((a, b) => a.s - b.s);
}

/**
 * Is [startMin, endMin) fully inside the court's operating hours (i.e. covered
 * by its weekday templates with no gaps)? Courts with no templates are treated
 * as having no operating hours (matches today's getAvailableSlots behaviour).
 */
function isWithinOperatingHours(court, startMin, endMin) {
  const segs = courtSegments(court);
  let cursor = startMin;
  for (const seg of segs) {
    if (seg.s > cursor) break; // gap before coverage continues
    if (seg.e > cursor) cursor = seg.e;
    if (cursor >= endMin) return true;
  }
  return cursor >= endMin;
}

/**
 * Price for [startMin, endMin) on a court: sum each overlapping template cell's
 * (priceOverride ?? hourlyRate) prorated by hours; any remainder not covered by
 * a template is priced at the court's base hourlyRate.
 */
function priceForBlock(court, startMin, endMin) {
  const rate = parseFloat(court.hourlyRate) || 0;
  const segs = courtSegments(court);
  let total = 0;
  let covered = 0;
  for (const seg of segs) {
    const os = Math.max(startMin, seg.s);
    const oe = Math.min(endMin, seg.e);
    if (oe > os) {
      total += ((oe - os) / 60) * (seg.p !== null ? seg.p : rate);
      covered += oe - os;
    }
  }
  const remaining = endMin - startMin - covered;
  if (remaining > 0) total += (remaining / 60) * rate;
  return Math.round(total * 100) / 100;
}

// ── occupancy ───────────────────────────────────────────────────────────────

/**
 * Map<courtId, Array<{ bookingId, courtId, userId, startMin, endMin, movable,
 * maxPersons }>> of currently-occupying bookings.
 *
 * movable = Confirmed AND not a slot BLOCK AND not aggregator-SOURCED AND not
 * part of a same-user multi-court group on this date (those are a locked unit —
 * a team that booked 2 courts together must not be split).
 *
 * NOTE: a court merely being mapped to the aggregator (externalResourceId) does
 * NOT block consolidating LOCAL bookings on it — per client decision. A swap
 * keeps the same number of courts busy per time slot, so net venue availability
 * (what the aggregator sees) is unchanged. Only reservations the aggregator
 * itself made (see NON_MOVABLE_SOURCES) are protected. Pushing a court
 * change back to the aggregator remains a separate follow-up.
 */
function buildOccupancy(courts, bookings, nowDate, externalCourtIds) {
  const courtIds = new Set(courts.map((c) => c.id));
  const active = bookings.filter(
    (b) =>
      !b.isDeleted &&
      b.bookingStatus !== 'Cancelled' &&
      courtIds.has(b.courtId) &&
      isHoldActive(b, nowDate)
  );

  // locked multi-court groups: a user holding >1 distinct court on this date
  const userCourts = new Map();
  for (const b of active) {
    if (!userCourts.has(b.userId)) userCourts.set(b.userId, new Set());
    userCourts.get(b.userId).add(b.courtId);
  }

  const map = new Map();
  for (const c of courts) map.set(c.id, []);
  for (const b of active) {
    const lockedGroup = (userCourts.get(b.userId)?.size || 0) > 1;
    const movable =
      b.bookingStatus === 'Confirmed' &&
      // A block names a specific COURT (maintenance on court 3, a partner holding
      // court 3). Relocating it would silently un-block the court that was meant
      // to be shut and block a different one instead.
      !b.isBlocked &&
      !NON_MOVABLE_SOURCES.includes(b.bookingSource) &&
      !lockedGroup;
    map.get(b.courtId).push({
      bookingId: b.id,
      courtId: b.courtId,
      userId: b.userId,
      startMin: toMinutes(b.startTime),
      endMin: toEndMinutes(b.endTime, toMinutes(b.startTime)), // 00:00 end -> 1440

      movable,
      maxPersons: b.maxPersons || 0,
    });
  }
  return map;
}

// ── direct availability + rearrangement search ───────────────────────────────

/** First equivalent court free for the whole block (fast path). */
function findDirectCourt(courts, occupancy, startMin, endMin) {
  for (const c of courts) {
    if (!isWithinOperatingHours(c, startMin, endMin)) continue;
    if (!hasOverlap(occupancy.get(c.id) || [], startMin, endMin)) return c.id;
  }
  return null;
}

/** Can `target` court receive a booking for [startMin,endMin) given staged moves? */
function targetCanReceive(target, interval, occupancy, staged) {
  if (!isWithinOperatingHours(target, interval.startMin, interval.endMin)) return false;
  if (target.capacity != null && interval.maxPersons && target.capacity < interval.maxPersons) return false;
  const existing = occupancy.get(target.id) || [];
  if (hasOverlap(existing, interval.startMin, interval.endMin)) return false;
  const stagedHere = staged.filter((m) => m.toCourtId === target.id);
  if (hasOverlap(stagedHere, interval.startMin, interval.endMin)) return false;
  return true;
}

/** Backtracking assignment of each conflict to a distinct, free, equivalent court. */
function assignMoves(conflicts, idx, hostId, courts, occupancy, staged, externalCourtIds) {
  if (idx >= conflicts.length) return true;
  const iv = conflicts[idx];
  for (const target of courts) {
    if (target.id === hostId) continue; // can't stay on the court we're freeing
    if (!targetCanReceive(target, iv, occupancy, staged)) continue;
    staged.push({
      bookingId: iv.bookingId,
      fromCourtId: hostId,
      toCourtId: target.id,
      startMin: iv.startMin,
      endMin: iv.endMin,
      maxPersons: iv.maxPersons,
    });
    if (assignMoves(conflicts, idx + 1, hostId, courts, occupancy, staged, externalCourtIds)) return true;
    staged.pop();
  }
  return false;
}

/**
 * Try to free one host court for [startMin,endMin) by relocating its in-block
 * bookings (at most maxMoves, all must be movable) onto other equivalent courts.
 * Returns { hostCourtId, moves } or null.
 */
function findRearrangement(courts, occupancy, startMin, endMin, maxMoves, externalCourtIds) {
  const candidates = [];
  for (const c of courts) {
    if (!isWithinOperatingHours(c, startMin, endMin)) continue;
    const conflicts = (occupancy.get(c.id) || []).filter((iv) => iv.startMin < endMin && iv.endMin > startMin);
    candidates.push({ court: c, conflicts });
  }
  // fewest conflicts first → least disruption
  candidates.sort((a, b) => a.conflicts.length - b.conflicts.length);

  for (const { court, conflicts } of candidates) {
    if (conflicts.length === 0) return { hostCourtId: court.id, moves: [] };
    if (conflicts.length > maxMoves) continue;
    if (!conflicts.every((iv) => iv.movable)) continue;
    const staged = [];
    if (assignMoves(conflicts, 0, court.id, courts, occupancy, staged, externalCourtIds)) {
      return { hostCourtId: court.id, moves: staged };
    }
  }
  return null;
}

/** Direct first, else rearrangement. Operates on a prebuilt occupancy map. */
function findOrRearrangeBlock({ courts, occupancy, startMin, endMin, maxMoves = 2, externalCourtIds }) {
  const direct = findDirectCourt(courts, occupancy, startMin, endMin);
  if (direct != null) return { available: true, requiresRearrangement: false, hostCourtId: direct, moves: [] };
  const rear = findRearrangement(courts, occupancy, startMin, endMin, maxMoves, externalCourtIds || new Set());
  if (rear) return { available: true, requiresRearrangement: true, hostCourtId: rear.hostCourtId, moves: rear.moves };
  return { available: false, requiresRearrangement: false, hostCourtId: null, moves: [] };
}

// ── public, court-hidden API ─────────────────────────────────────────────────

/**
 * Availability for one (startTime, duration). Returns a court-hidden answer plus
 * an internal hostCourtId/moves the booking path can act on, and a partial
 * `fallback` block when the full duration can't be formed.
 */
function computeAvailability({
  courts,
  bookings,
  now = new Date(),
  startTime,
  durationMinutes,
  maxMoves = 2,
  gridStepMinutes = 30,
}) {
  const externalCourtIds = new Set(courts.filter((c) => c.externalResourceId).map((c) => c.id));
  const occupancy = buildOccupancy(courts, bookings, now, externalCourtIds);
  const startMin = toMinutes(startTime);
  const endMin = startMin + durationMinutes;

  const res = findOrRearrangeBlock({ courts, occupancy, startMin, endMin, maxMoves, externalCourtIds });
  const price = res.available ? priceForBlock(courtById(courts, res.hostCourtId), startMin, endMin) : null;

  let fallback = null;
  if (!res.available && durationMinutes > gridStepMinutes) {
    for (let d = durationMinutes - gridStepMinutes; d >= gridStepMinutes; d -= gridStepMinutes) {
      const r = findOrRearrangeBlock({ courts, occupancy, startMin, endMin: startMin + d, maxMoves, externalCourtIds });
      if (r.available) {
        fallback = {
          startTime: toTimeString(startMin),
          endTime: toTimeString(startMin + d),
          durationMinutes: d,
          requiresRearrangement: r.requiresRearrangement,
          price: priceForBlock(courtById(courts, r.hostCourtId), startMin, startMin + d),
        };
        break;
      }
    }
  }

  return {
    available: res.available,
    requiresRearrangement: res.requiresRearrangement,
    hostCourtId: res.hostCourtId, // internal only — controllers must NOT expose this to the public
    moves: res.moves, // internal only
    price,
    fallback,
  };
}

/**
 * For a chosen duration, the grid of candidate start times across the venue's
 * operating window with bookable/blocked + price. Court-hidden.
 */
function listBookableStartTimes({
  courts,
  bookings,
  now = new Date(),
  durationMinutes,
  maxMoves = 2,
  gridStepMinutes = 30,
}) {
  const externalCourtIds = new Set(courts.filter((c) => c.externalResourceId).map((c) => c.id));
  const occupancy = buildOccupancy(courts, bookings, now, externalCourtIds);

  let minStart = Infinity;
  let maxEnd = -Infinity;
  for (const c of courts) {
    for (const seg of courtSegments(c)) {
      minStart = Math.min(minStart, seg.s);
      maxEnd = Math.max(maxEnd, seg.e);
    }
  }
  if (!isFinite(minStart)) return [];

  const out = [];
  for (let st = minStart; st + durationMinutes <= maxEnd; st += gridStepMinutes) {
    if (!courts.some((c) => isWithinOperatingHours(c, st, st + durationMinutes))) continue;
    const r = findOrRearrangeBlock({ courts, occupancy, startMin: st, endMin: st + durationMinutes, maxMoves, externalCourtIds });
    out.push({
      startTime: toTimeString(st),
      endTime: toTimeString(st + durationMinutes),
      available: r.available,
      requiresRearrangement: r.requiresRearrangement,
      price: r.available ? priceForBlock(courtById(courts, r.hostCourtId), st, st + durationMinutes) : null,
    });
  }
  return out;
}

module.exports = {
  NON_MOVABLE_SOURCES,
  // pure helpers (exported for tests / reuse)
  isWithinOperatingHours,
  priceForBlock,
  buildOccupancy,
  findDirectCourt,
  findRearrangement,
  findOrRearrangeBlock,
  // public API
  computeAvailability,
  listBookableStartTimes,
};
