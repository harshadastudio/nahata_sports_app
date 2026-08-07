'use strict';

/**
 * Zero-dependency tests for the slot engine. Run with:
 *   node src/services/__tests__/slotEngineService.test.js
 * (The API has no test framework; the engine is pure so plain asserts suffice.)
 */

const assert = require('assert');
const engine = require('../slotEngineService');
const { toMinutes } = require('../../utils/timeIntervals');

const NOW = new Date('2026-06-22T12:00:00Z');

let passed = 0;
let failed = 0;
function test(name, fn) {
  try {
    fn();
    passed++;
    console.log('  ok  -', name);
  } catch (err) {
    failed++;
    console.error('FAIL  -', name, '\n      ', err.message);
  }
}

// ── builders ──────────────────────────────────────────────────────────────
const hhmm = (h) => `${String(Math.floor(h)).padStart(2, '0')}:${h % 1 ? '30' : '00'}:00`;

function makeCourt(id, opts = {}) {
  const { capacity = null, hourlyRate = 500, external = null, open = 9, close = 23, peakFrom = null, peakPrice = null } = opts;
  const slots = [];
  for (let h = open; h < close; h++) {
    const peak = peakFrom != null && h >= peakFrom;
    slots.push({
      startTime: hhmm(h),
      endTime: hhmm(h + 1),
      slotType: peak ? 'Peak' : 'Regular',
      priceOverride: peak ? peakPrice : null,
    });
  }
  return { id, capacity, hourlyRate, externalResourceId: external, slots };
}

function makeBooking(id, courtId, startH, endH, opts = {}) {
  return {
    id,
    courtId,
    userId: opts.userId ?? 1000 + id,
    startTime: hhmm(startH),
    endTime: hhmm(endH),
    bookingStatus: opts.bookingStatus ?? 'Confirmed',
    bookingSource: opts.bookingSource ?? 'Website',
    holdExpiresAt: opts.holdExpiresAt ?? null,
    maxPersons: opts.maxPersons ?? 0,
    isDeleted: opts.isDeleted ?? false,
    isBlocked: opts.isBlocked ?? false,
  };
}

/**
 * Apply a solution to the occupancy and assert: (a) host court is free for the
 * block, (b) no court has overlapping bookings after the moves. Proves the
 * rearrangement is actually valid.
 */
function assertValidSolution(courts, bookings, res, startTime, durationMinutes) {
  const startMin = toMinutes(startTime);
  const endMin = startMin + durationMinutes;
  // current intervals per court (active only)
  const byCourt = new Map(courts.map((c) => [c.id, []]));
  const activeNow = bookings.filter((b) => !b.isDeleted && b.bookingStatus !== 'Cancelled' && (!b.holdExpiresAt || new Date(b.holdExpiresAt) > NOW));
  for (const b of activeNow) byCourt.get(b.courtId).push({ id: b.id, s: toMinutes(b.startTime), e: toMinutes(b.endTime) });
  // apply moves
  for (const m of res.moves) {
    const from = byCourt.get(m.fromCourtId);
    const i = from.findIndex((x) => x.id === m.bookingId);
    assert.ok(i >= 0, `moved booking ${m.bookingId} not found on origin court ${m.fromCourtId}`);
    const [moved] = from.splice(i, 1);
    byCourt.get(m.toCourtId).push(moved);
  }
  // add the new booking on host
  byCourt.get(res.hostCourtId).push({ id: 'NEW', s: startMin, e: endMin });
  // no overlaps anywhere
  for (const [courtId, ivs] of byCourt) {
    const sorted = ivs.slice().sort((a, b) => a.s - b.s);
    for (let i = 1; i < sorted.length; i++) {
      assert.ok(sorted[i].s >= sorted[i - 1].e, `overlap on court ${courtId} after solution`);
    }
  }
}

// ── tests ───────────────────────────────────────────────────────────────────

test('direct hit: a single free court is used, no moves', () => {
  const courts = [makeCourt(1), makeCourt(2)];
  const bookings = [makeBooking(11, 1, 9, 10)]; // C1 busy 9-10; C2 fully free
  const res = engine.computeAvailability({ courts, bookings, now: NOW, startTime: '09:00:00', durationMinutes: 120 });
  assert.strictEqual(res.available, true);
  assert.strictEqual(res.requiresRearrangement, false);
  assert.strictEqual(res.moves.length, 0);
  assert.strictEqual(res.hostCourtId, 2);
  assert.strictEqual(res.price, 1000); // 2h * 500
});

test("client's 2x4 example: 9-11 freed by one move", () => {
  const courts = [makeCourt(1), makeCourt(2), makeCourt(3), makeCourt(4)];
  const bookings = [
    makeBooking(11, 1, 9, 10), makeBooking(12, 1, 10, 11),
    makeBooking(21, 2, 9, 10),                              // C2 free 10-11
    makeBooking(31, 3, 10, 11),                             // C3 free 9-10
    makeBooking(41, 4, 9, 10), makeBooking(42, 4, 10, 11),
  ];
  const res = engine.computeAvailability({ courts, bookings, now: NOW, startTime: '09:00:00', durationMinutes: 120 });
  assert.strictEqual(res.available, true);
  assert.strictEqual(res.requiresRearrangement, true);
  assert.ok(res.moves.length >= 1 && res.moves.length <= 2, 'expected 1-2 moves');
  assertValidSolution(courts, bookings, res, '09:00:00', 120);
  assert.strictEqual(res.price, 1000);
});

test('no full block → partial fallback to the available 1hr', () => {
  const courts = [makeCourt(1), makeCourt(2)];
  const bookings = [
    makeBooking(11, 1, 9, 10), makeBooking(12, 1, 10, 11), // C1 full 9-11
    makeBooking(21, 2, 10, 11),                            // C2 free 9-10 only
  ];
  const res = engine.computeAvailability({ courts, bookings, now: NOW, startTime: '09:00:00', durationMinutes: 120 });
  assert.strictEqual(res.available, false);
  assert.ok(res.fallback, 'expected a fallback');
  assert.strictEqual(res.fallback.durationMinutes, 60);
  assert.strictEqual(res.fallback.startTime, '09:00:00');
  assert.strictEqual(res.fallback.endTime, '10:00:00');
});

test('abutting bookings (8-9, 11-12) do NOT block 9-11', () => {
  const courts = [makeCourt(1, { open: 8, close: 13 })];
  const bookings = [makeBooking(11, 1, 8, 9), makeBooking(12, 1, 11, 12)];
  const res = engine.computeAvailability({ courts, bookings, now: NOW, startTime: '09:00:00', durationMinutes: 120 });
  assert.strictEqual(res.available, true);
  assert.strictEqual(res.requiresRearrangement, false);
  assert.strictEqual(res.hostCourtId, 1);
});

test('move cap: 2-move solution works at maxMoves=2 but not maxMoves=1', () => {
  const courts = [makeCourt(1), makeCourt(2), makeCourt(3)];
  const bookings = [
    makeBooking(11, 1, 9, 10), makeBooking(12, 1, 10, 11),     // host C1, 2 movable conflicts
    makeBooking(21, 2, 10, 11, { bookingSource: 'Playo' }),   // C2 free 9-10, conflict non-movable
    makeBooking(31, 3, 9, 10, { bookingSource: 'Playo' }),    // C3 free 10-11, conflict non-movable
  ];
  const ok2 = engine.computeAvailability({ courts, bookings, now: NOW, startTime: '09:00:00', durationMinutes: 120, maxMoves: 2 });
  assert.strictEqual(ok2.available, true);
  assert.strictEqual(ok2.moves.length, 2);
  assert.strictEqual(ok2.hostCourtId, 1);
  assertValidSolution(courts, bookings, ok2, '09:00:00', 120);

  const ok1 = engine.computeAvailability({ courts, bookings, now: NOW, startTime: '09:00:00', durationMinutes: 120, maxMoves: 1 });
  assert.strictEqual(ok1.available, false);
});

test('expired Pending hold is treated as free; active hold blocks', () => {
  const courts = [makeCourt(1)];
  const expired = [makeBooking(11, 1, 9, 11, { bookingStatus: 'Pending', holdExpiresAt: '2026-06-22T11:00:00Z' })];
  const r1 = engine.computeAvailability({ courts, bookings: expired, now: NOW, startTime: '09:00:00', durationMinutes: 120 });
  assert.strictEqual(r1.available, true, 'expired hold should free the slot');

  const active = [makeBooking(11, 1, 9, 11, { bookingStatus: 'Pending', holdExpiresAt: '2026-06-22T13:00:00Z' })];
  const r2 = engine.computeAvailability({ courts, bookings: active, now: NOW, startTime: '09:00:00', durationMinutes: 120 });
  assert.strictEqual(r2.available, false, 'active hold should block');
});

test('a non-movable (Playo) conflict on the only court cannot be consolidated', () => {
  const courts = [makeCourt(1)];
  const bookings = [makeBooking(11, 1, 10, 11, { bookingSource: 'Playo' })];
  const res = engine.computeAvailability({ courts, bookings, now: NOW, startTime: '09:00:00', durationMinutes: 120 });
  assert.strictEqual(res.available, false);
  assert.ok(res.fallback && res.fallback.endTime === '10:00:00', 'should fall back to free 9-10');
});

test('buildOccupancy: same-user multi-court group is locked (non-movable)', () => {
  const courts = [makeCourt(1), makeCourt(2), makeCourt(3)];
  const bookings = [
    makeBooking(11, 1, 9, 10, { userId: 7 }),
    makeBooking(21, 2, 10, 11, { userId: 7 }), // user 7 holds 2 courts → locked
    makeBooking(31, 3, 9, 10, { userId: 8 }),  // user 8, single court → movable
  ];
  const occ = engine.buildOccupancy(courts, bookings, NOW, new Set());
  assert.strictEqual(occ.get(1)[0].movable, false);
  assert.strictEqual(occ.get(2)[0].movable, false);
  assert.strictEqual(occ.get(3)[0].movable, true);
});

test('buildOccupancy: a slot BLOCK is never movable, whatever its source', () => {
  const courts = [makeCourt(1), makeCourt(2)];
  const bookings = [
    // An Admin block looks like an ordinary Confirmed website booking apart from
    // isBlocked — that flag is the only thing keeping it pinned to its court.
    makeBooking(11, 1, 9, 10, { isBlocked: true, bookingSource: 'Admin' }),
    makeBooking(21, 2, 9, 10),
  ];
  const occ = engine.buildOccupancy(courts, bookings, NOW, new Set());
  assert.strictEqual(occ.get(1)[0].movable, false, 'a block must stay on its own court');
  assert.strictEqual(occ.get(2)[0].movable, true);
});

test('a blocked court is not freed by consolidation', () => {
  // Both courts busy 9-10; court 2's occupant is movable, court 1's is a block.
  // The only 2-hour solution would be to move the block off court 1 — it must not.
  const courts = [makeCourt(1), makeCourt(2)];
  const bookings = [
    makeBooking(11, 1, 9, 10, { isBlocked: true, bookingSource: 'Admin' }),
    makeBooking(21, 2, 9, 10),
  ];
  const res = engine.computeAvailability({ courts, bookings, now: NOW, startTime: '09:00:00', durationMinutes: 120, maxMoves: 2 });
  assert.ok(
    !res.available || res.moves.every((m) => m.bookingId !== 11),
    'consolidation must never relocate a block'
  );
});

test('priceForBlock: peak/regular proration incl. half hours', () => {
  const court = makeCourt(1, { open: 9, close: 23, peakFrom: 18, peakPrice: 800 });
  assert.strictEqual(engine.priceForBlock(court, toMinutes('17:00:00'), toMinutes('19:00:00')), 1300); // 500 + 800
  assert.strictEqual(engine.priceForBlock(court, toMinutes('17:00:00'), toMinutes('17:30:00')), 250); // half hr regular
});

test('listBookableStartTimes: grid marks blocked start as unavailable', () => {
  const courts = [makeCourt(1, { open: 9, close: 12 })];
  const bookings = [makeBooking(11, 1, 10, 11)];
  const grid = engine.listBookableStartTimes({ courts, bookings, now: NOW, durationMinutes: 60, gridStepMinutes: 60 });
  assert.strictEqual(grid.length, 3); // 9,10,11
  const ten = grid.find((g) => g.startTime === '10:00:00');
  assert.strictEqual(ten.available, false);
  assert.strictEqual(grid.find((g) => g.startTime === '09:00:00').available, true);
  assert.strictEqual(grid.find((g) => g.startTime === '11:00:00').available, true);
});

test('listBookableStartTimes: midnight close ("00:00:00") extends to the last hour', () => {
  // Court open 22:00 → 24:00, with the closing slot stored as 23:00 → 00:00.
  const court = {
    id: 1,
    capacity: null,
    hourlyRate: 500,
    externalResourceId: null,
    slots: [
      { startTime: '22:00:00', endTime: '23:00:00', slotType: 'Regular', priceOverride: null },
      { startTime: '23:00:00', endTime: '00:00:00', slotType: 'Regular', priceOverride: null }, // midnight close
    ],
  };
  const grid = engine.listBookableStartTimes({ courts: [court], bookings: [], now: NOW, durationMinutes: 60, gridStepMinutes: 60 });
  const starts = grid.map((g) => g.startTime);
  // Before the fix the 00:00 close collapsed to 0, capping the last start at 22:00.
  assert.deepStrictEqual(starts, ['22:00:00', '23:00:00']);
  assert.strictEqual(grid.find((g) => g.startTime === '23:00:00').endTime, '00:00:00');
  assert.strictEqual(grid.find((g) => g.startTime === '23:00:00').available, true);
});

test('buildOccupancy: a booking ending at midnight occupies the last hour', () => {
  const court = {
    id: 1, capacity: null, hourlyRate: 500, externalResourceId: null,
    slots: [{ startTime: '23:00:00', endTime: '00:00:00', slotType: 'Regular', priceOverride: null }],
  };
  const booking = {
    id: 1, courtId: 1, userId: 7, startTime: '23:00:00', endTime: '00:00:00',
    bookingStatus: 'Confirmed', bookingSource: 'Website', holdExpiresAt: null, maxPersons: 0, isDeleted: false,
  };
  const occ = engine.buildOccupancy([court], [booking], NOW, new Set());
  assert.strictEqual(occ.get(1)[0].endMin, 1440); // not 0
  // 23:00–00:00 must read as unavailable, not free.
  const grid = engine.listBookableStartTimes({ courts: [court], bookings: [booking], now: NOW, durationMinutes: 60, gridStepMinutes: 60 });
  assert.strictEqual(grid.find((g) => g.startTime === '23:00:00').available, false);
});

console.log(`\nslotEngine: ${passed} passed, ${failed} failed`);
process.exit(failed ? 1 : 0);
