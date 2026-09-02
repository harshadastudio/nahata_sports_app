import 'package:flutter_test/flutter_test.dart';
import 'package:nahata_app/bottombar/slotbook.dart';

/// The Book a Court screen turns a start time plus a duration back into the
/// run of slot maps the payment screen has always been handed. These pin the
/// merging that sits under that, which is what decides which times are
/// offered and at what price.
Map<String, dynamic> slot({
  required String start,
  required String end,
  int price = 300,
  bool soldOut = false,
  String hourType = 'Regular',
  String court = 'Court 1',
}) =>
    <String, dynamic>{
      'court': court,
      'hourType': hourType,
      'time': '$start - $end',
      'price': price,
      'date': '2026-08-27',
      'isSoldOut': soldOut,
      'courtId': 7,
      'slotId': 1,
      'sportId': 4,
      'sportComplexId': 1,
      'startTime': start,
      'endTime': end,
    };

void main() {
  group('mergeSlotsByTime', () {
    test('one row per start time, cheapest free court wins', () {
      final merged = mergeSlotsByTime([
        slot(start: '07:00:00', end: '08:00:00', price: 500, court: 'A'),
        slot(start: '07:00:00', end: '08:00:00', price: 300, court: 'B'),
      ], 'Regular');

      expect(merged, hasLength(1));
      expect(merged.single.slot['price'], 300);
      expect(merged.single.slot['court'], 'B');
      expect(merged.single.freeCourts, 2);
      expect(merged.single.totalCourts, 2);
    });

    test('a time is offered while any court still has it', () {
      final merged = mergeSlotsByTime([
        slot(start: '07:00:00', end: '08:00:00', court: 'A', soldOut: true),
        slot(start: '07:00:00', end: '08:00:00', court: 'B'),
      ], 'Regular');

      expect(merged.single.isSoldOut, isFalse);
      expect(merged.single.freeCourts, 1);
      expect(merged.single.totalCourts, 2);
    });

    test('a time is sold out only once every court is taken', () {
      final merged = mergeSlotsByTime([
        slot(start: '07:00:00', end: '08:00:00', court: 'A', soldOut: true),
        slot(start: '07:00:00', end: '08:00:00', court: 'B', soldOut: true),
      ], 'Regular');

      expect(merged.single.isSoldOut, isTrue);
      expect(merged.single.freeCourts, 0);
    });

    test('rows come back in clock order, not payload order', () {
      final merged = mergeSlotsByTime([
        slot(start: '19:00:00', end: '20:00:00'),
        slot(start: '07:00:00', end: '08:00:00'),
        slot(start: '13:00:00', end: '14:00:00'),
      ], 'Regular');

      expect(
        merged.map((t) => t.slot['startTime']),
        ['07:00:00', '13:00:00', '19:00:00'],
      );
    });

    test('another hour type is left out of this list', () {
      final merged = mergeSlotsByTime([
        slot(start: '07:00:00', end: '08:00:00'),
        slot(start: '19:00:00', end: '20:00:00', hourType: 'Peak'),
      ], 'Regular');

      expect(merged, hasLength(1));
      expect(merged.single.slot['startTime'], '07:00:00');
    });

    test('the booking metadata survives the merge', () {
      // The payment screen reads these straight off the slot map, so the
      // merge must not drop them.
      final merged = mergeSlotsByTime(
        [slot(start: '07:00:00', end: '08:00:00')],
        'Regular',
      );

      final s = merged.single.slot;
      expect(s['courtId'], 7);
      expect(s['slotId'], 1);
      expect(s['sportId'], 4);
      expect(s['sportComplexId'], 1);
      expect(s['startTime'], '07:00:00');
      expect(s['endTime'], '08:00:00');
      expect(s['date'], '2026-08-27');
    });

    test('no slots for the type is an empty list, not an error', () {
      expect(mergeSlotsByTime(const [], 'Regular'), isEmpty);
    });
  });

  group('a run of consecutive hours', () {
    /// Mirrors the screen's own walk: step forward while the next slot starts
    /// exactly where the last one ended and is still free.
    List<TimeSlot> runFrom(List<TimeSlot> all, int index, int wanted) {
      final run = <TimeSlot>[all[index]];
      for (var i = index + 1; i < all.length && run.length < wanted; i++) {
        final previousEnd = run.last.slot['endTime'].toString();
        final nextStart = all[i].slot['startTime'].toString();
        if (all[i].isSoldOut || nextStart != previousEnd) break;
        run.add(all[i]);
      }
      return run;
    }

    final timetable = mergeSlotsByTime([
      slot(start: '07:00:00', end: '08:00:00', price: 300),
      slot(start: '08:00:00', end: '09:00:00', price: 300),
      slot(start: '09:00:00', end: '10:00:00', price: 400, soldOut: true),
      slot(start: '10:00:00', end: '11:00:00', price: 400),
    ], 'Regular');

    test('two free hours in a row make a two hour booking', () {
      final run = runFrom(timetable, 0, 2);

      expect(run, hasLength(2));
      expect(run.fold<int>(0, (n, t) => n + (t.slot['price'] as int)), 600);
      expect(run.first.slot['startTime'], '07:00:00');
      expect(run.last.slot['endTime'], '09:00:00');
    });

    test('the run stops at an hour someone else already has', () {
      // Asking for three hours from 7am cannot swallow the sold-out 9am.
      final run = runFrom(timetable, 0, 3);

      expect(run, hasLength(2));
      expect(run.last.slot['endTime'], '09:00:00');
    });

    test('the run stops at a gap in the timetable', () {
      final split = mergeSlotsByTime([
        slot(start: '07:00:00', end: '08:00:00'),
        slot(start: '10:00:00', end: '11:00:00'),
      ], 'Regular');

      expect(runFrom(split, 0, 2), hasLength(1));
    });

    test('a peak hour in the run is charged at its own price', () {
      final mixed = mergeSlotsByTime([
        slot(start: '07:00:00', end: '08:00:00', price: 300),
        slot(start: '08:00:00', end: '09:00:00', price: 750),
      ], 'Regular');

      final run = runFrom(mixed, 0, 2);
      expect(run.fold<int>(0, (n, t) => n + (t.slot['price'] as int)), 1050);
    });

    test('a free court totals zero, which is a bookable state', () {
      final free = mergeSlotsByTime([
        slot(start: '07:00:00', end: '08:00:00', price: 0),
      ], 'Regular');

      final run = runFrom(free, 0, 1);
      final total = run.fold<int>(0, (n, t) => n + (t.slot['price'] as int));

      expect(total, 0);
      expect(run, isNotEmpty);
    });
  });
}
