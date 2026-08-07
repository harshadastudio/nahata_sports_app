'use strict';

/**
 * Time-interval helpers for court bookings.
 *
 * Bookings store SQL TIME values ("HH:MM:SS"). We compare them as
 * minutes-since-midnight using HALF-OPEN intervals [start, end):
 * a booking ending at 10:00 does NOT conflict with one starting at 10:00.
 * (The legacy inclusive Op.between check falsely flagged such abutting
 * bookings — see createCourtBooking.)
 */

/** "09:00:00" | "9:00" | 540 -> minutes since midnight (e.g. 540). */
function toMinutes(time) {
  if (time === null || time === undefined) throw new Error('toMinutes: time is required');
  if (typeof time === 'number') return time;
  const parts = String(time).trim().split(':');
  const h = parseInt(parts[0], 10);
  const m = parseInt(parts[1] || '0', 10);
  const s = parseInt(parts[2] || '0', 10);
  if (Number.isNaN(h) || Number.isNaN(m)) throw new Error(`toMinutes: invalid time "${time}"`);
  return h * 60 + m + Math.floor(s / 60);
}

/**
 * End time as minutes since midnight, treating a value at/at-or-before the
 * start as an end-of-day close that wraps past midnight. A slot/booking that
 * ends at "00:00:00" (12 AM) parses to 0 via toMinutes; relative to its start
 * that means 1440 (end of day), not 0. Without this, midnight-ending segments
 * collapse and the last operating hour becomes unbookable.
 */
function toEndMinutes(endTime, startMin) {
  const end = toMinutes(endTime);
  return end <= startMin ? end + 1440 : end;
}

/** minutes since midnight -> "HH:MM:SS" */
function toTimeString(minutes) {
  const m = ((Math.round(minutes) % 1440) + 1440) % 1440;
  const hh = String(Math.floor(m / 60)).padStart(2, '0');
  const mm = String(m % 60).padStart(2, '0');
  return `${hh}:${mm}:00`;
}

/**
 * Half-open overlap test. True if [aStart,aEnd) and [bStart,bEnd) share any
 * positive-length sub-interval. Abutting intervals do NOT overlap.
 */
function intervalsOverlap(aStart, aEnd, bStart, bEnd) {
  const as = toMinutes(aStart);
  const ae = toMinutes(aEnd);
  const bs = toMinutes(bStart);
  const be = toMinutes(bEnd);
  return as < be && ae > bs;
}

/** True if [innerStart,innerEnd) fits entirely within [outerStart,outerEnd). */
function intervalContains(outerStart, outerEnd, innerStart, innerEnd) {
  return toMinutes(outerStart) <= toMinutes(innerStart) && toMinutes(outerEnd) >= toMinutes(innerEnd);
}

module.exports = { toMinutes, toEndMinutes, toTimeString, intervalsOverlap, intervalContains };
