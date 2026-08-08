import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nahata_app/features/employee/domain/entities/employee_master.dart';
import 'package:nahata_app/features/employee/presentation/theme/employee_theme.dart';
import 'package:nahata_app/features/employee/presentation/widgets/employee_forms.dart';
import 'package:nahata_app/features/employee/presentation/widgets/employee_stat_tile.dart';
import 'package:nahata_app/features/employee/presentation/widgets/employee_states.dart';

/// Overflow regression tests for the employee dashboard's tiled layouts.
///
/// The stat grids and the Blocked Slots grid were originally `GridView`s with a
/// fixed `childAspectRatio`, which ties a tile's height to the screen's width.
/// The two are unrelated: the content is text, so its height follows the user's
/// font scale. On a 320dp phone a tile came out ~138px wide and ~99px tall for
/// content that needed ~111px, and it overflowed before the font scale was
/// touched at all.
///
/// Each case below is pumped at the **worst realistic combination** — the
/// narrowest phone still shipped (320×568, e.g. an SE-class device) and a 1.5×
/// system font — because that is where the old layout broke and where a
/// regression would land first.
void main() {
  /// The smallest screen the app is expected to render on.
  const smallPhone = Size(320, 568);

  /// Renders [child] at [size] with [textScale] applied.
  ///
  /// `tester.takeException()` is what actually catches an overflow: a
  /// `RenderFlex` that runs out of room throws a `FlutterError` during paint,
  /// which the test binding records rather than rethrowing.
  Future<void> pumpAt(
    WidgetTester tester,
    Widget child, {
    Size size = smallPhone,
    double textScale = 1.5,
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: MaterialApp(
          home: Scaffold(
            backgroundColor: EmployeeTokens.canvas,
            // A ListView reproduces the real parent: an unbounded height, which
            // is what turns a too-tall child into an overflow rather than a
            // silently clipped one.
            body: ListView(
              padding: const EdgeInsets.all(EmployeeTokens.space4),
              children: [child],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('EmployeeTileGrid sizes to its content', () {
    testWidgets('six stat tiles do not overflow on a small phone', (
      tester,
    ) async {
      await pumpAt(
        tester,
        const EmployeeTileGrid(
          children: [
            EmployeeStatTile(
              label: "Today's bookings",
              value: '12',
              icon: Icons.today_rounded,
              color: EmployeeTokens.info,
              trend: 12.4,
            ),
            EmployeeStatTile(
              label: 'Total revenue',
              // A long value is the realistic worst case for the number line.
              value: '₹12,45,600',
              icon: Icons.currency_rupee_rounded,
              color: EmployeeTokens.accent,
              trend: -3.2,
            ),
            EmployeeStatTile(
              label: 'Upcoming (7 days)',
              value: '48',
              icon: Icons.event_available_rounded,
              color: EmployeeTokens.purple,
            ),
            EmployeeStatTile(
              label: 'Total bookings',
              value: '1204',
              icon: Icons.receipt_long_rounded,
              color: EmployeeTokens.brand,
            ),
            EmployeeStatTile(
              label: 'Active enrollments',
              value: '86',
              icon: Icons.school_outlined,
              color: EmployeeTokens.success,
            ),
            EmployeeStatTile(
              label: 'Courts',
              value: '9',
              icon: Icons.stadium_outlined,
              color: EmployeeTokens.warning,
            ),
          ],
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('₹12,45,600'), findsOneWidget);
    });

    testWidgets('an odd tile count leaves the last row half-filled', (
      tester,
    ) async {
      await pumpAt(
        tester,
        const EmployeeTileGrid(
          children: [
            EmployeeStatTile(
              label: 'One',
              value: '1',
              icon: Icons.today_rounded,
              color: EmployeeTokens.info,
            ),
            EmployeeStatTile(
              label: 'Two',
              value: '2',
              icon: Icons.today_rounded,
              color: EmployeeTokens.info,
            ),
            EmployeeStatTile(
              label: 'Three',
              value: '3',
              icon: Icons.today_rounded,
              color: EmployeeTokens.info,
            ),
          ],
        ),
      );

      expect(tester.takeException(), isNull);

      // The lone tile on the last row keeps a column's width rather than
      // stretching across the row.
      final first = tester.getSize(find.byType(EmployeeStatTile).first);
      final last = tester.getSize(find.byType(EmployeeStatTile).last);
      expect(last.width, first.width);
    });

    testWidgets('three summary tiles do not overflow', (tester) async {
      await pumpAt(
        tester,
        const EmployeeTileGrid(
          columns: 3,
          children: [
            EmployeeSummaryTile(
              // The longest label the fee queue actually renders.
              label: 'Awaiting approval',
              value: '14',
              icon: Icons.pending_actions_rounded,
              color: EmployeeTokens.danger,
            ),
            EmployeeSummaryTile(
              label: 'Paid',
              value: '203',
              icon: Icons.check_circle_outline_rounded,
              color: EmployeeTokens.success,
            ),
            EmployeeSummaryTile(
              label: 'Fee records',
              value: '217',
              icon: Icons.folder_outlined,
              color: EmployeeTokens.info,
            ),
          ],
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('tiles in a row share the tallest tile\'s height', (
      tester,
    ) async {
      await pumpAt(
        tester,
        const EmployeeTileGrid(
          children: [
            EmployeeStatTile(
              label: 'Short',
              value: '1',
              icon: Icons.today_rounded,
              color: EmployeeTokens.info,
            ),
            EmployeeStatTile(
              // Long enough to wrap onto a second line at 1.5× scale.
              label: 'A considerably longer label that wraps',
              value: '2',
              icon: Icons.today_rounded,
              color: EmployeeTokens.info,
            ),
          ],
        ),
      );

      expect(tester.takeException(), isNull);

      final tiles = tester
          .widgetList<EmployeeStatTile>(find.byType(EmployeeStatTile))
          .toList();
      expect(tiles, hasLength(2));

      final heights = find
          .byType(EmployeeStatTile)
          .evaluate()
          .map((e) => tester.getSize(find.byWidget(e.widget)).height)
          .toSet();
      expect(heights, hasLength(1), reason: 'both tiles should be equal height');
    });
  });

  group('EmployeeStatsShimmer', () {
    testWidgets('matches the tile grid without overflowing', (tester) async {
      await pumpAt(tester, const EmployeeStatsShimmer(tiles: 6));
      expect(tester.takeException(), isNull);
    });
  });

  group('EmployeeFilterChips', () {
    testWidgets('scrolls rather than clipping at a large text scale', (
      tester,
    ) async {
      await pumpAt(
        tester,
        EmployeeFilterChips<String>(
          values: const [
            'Pending',
            'Confirmed',
            'Completed',
            'Cancelled',
          ],
          selected: 'Confirmed',
          labelOf: (s) => s,
          allLabel: 'All statuses',
          onChanged: (_) {},
        ),
        // Deliberately past what the old fixed 36px box could hold.
        textScale: 2.0,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('All statuses'), findsOneWidget);
    });
  });

  group('EmployeeDropdown with a two-line option', () {
    // The court, batch and student pickers all pass `subtitleOf`, which puts a
    // second line of text inside each option.
    //
    // `InputDecorator` sizes its content to a single line of the field's
    // `style` and hands the child a tight height, so a two-line Column drawn
    // straight into the closed button is clipped — 1px at 1.0×, ~6px at 1.6×.
    // That is the "overflowed by 5.0 pixels on the bottom" reported from a
    // handset on the Slots screen's court picker.
    Widget courtPicker() => EmployeeDropdown<int>(
          value: 15,
          items: const [15, 16],
          labelOf: (id) => id == 15 ? 'Cricket Nets Court 2' : 'Court 3',
          subtitleOf: (id) => id == 15 ? 'Cricket Nets' : 'Badminton',
          onChanged: (_) {},
        );

    // Pinned at 1.0 as well: this never depended on the font scale being
    // raised, it was only more visible there.
    for (final scale in <double>[1.0, 1.3, 1.6]) {
      testWidgets('does not clip the closed button at ${scale}x text', (
        tester,
      ) async {
        await pumpAt(tester, courtPicker(), textScale: scale);

        expect(tester.takeException(), isNull);
        expect(find.text('Cricket Nets Court 2'), findsOneWidget);
      });
    }

    testWidgets('the open menu still shows the subtitle', (tester) async {
      // The one-line rendering applies to the closed button only. The subtitle
      // is what makes an option pickable, so it has to survive in the menu.
      await pumpAt(tester, courtPicker(), textScale: 1.0);

      await tester.tap(find.text('Cricket Nets Court 2'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Cricket Nets'), findsWidgets);
      expect(find.text('Badminton'), findsWidgets);
    });

    testWidgets('a single-line option keeps its usual height', (tester) async {
      // The pickers without a subtitle must not change as a side effect.
      await pumpAt(
        tester,
        EmployeeDropdown<String>(
          value: 'Active',
          items: const ['Active', 'Inactive'],
          labelOf: (s) => s,
          onChanged: (_) {},
        ),
        textScale: 1.0,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Active'), findsOneWidget);
    });
  });

  group('Blocked slot state labels', () {
    // The three kinds of unavailability are not interchangeable, and the tile
    // colours and copy hang off these. Worth pinning even though the layout
    // fix did not change them.
    test('a recurring block is told apart from an ordinary one', () {
      const recurring = EmployeeAvailableSlot(
        id: 1,
        startTime: '09:00:00',
        endTime: '10:00:00',
        isBooked: true,
        isBlocked: true,
        blockedBy: 'Template',
      );
      const ordinary = EmployeeAvailableSlot(
        id: 2,
        startTime: '10:00:00',
        endTime: '11:00:00',
        isBooked: true,
        isBlocked: true,
        blockedBy: 'Admin',
      );

      expect(recurring.isRecurringBlock, isTrue);
      expect(ordinary.isRecurringBlock, isFalse);
      expect(ordinary.stateLabel, 'Blocked');
    });

    test('a partner hold names the partner', () {
      const slot = EmployeeAvailableSlot(
        id: 3,
        startTime: '10:00:00',
        endTime: '11:00:00',
        isBooked: true,
        isBlocked: true,
        blockedBy: 'KheloMore',
      );

      expect(slot.isPartnerBlock, isTrue);
      expect(slot.stateLabel, 'Blocked by KheloMore');
    });

    test('a customer booking is not a block', () {
      const slot = EmployeeAvailableSlot(
        id: 4,
        startTime: '11:00:00',
        endTime: '12:00:00',
        isBooked: true,
        isUserBooked: true,
      );

      expect(slot.isPartnerBlock, isFalse);
      expect(slot.stateLabel, 'Booked by user');
    });

    test('a free slot reads as available', () {
      const slot = EmployeeAvailableSlot(
        id: 5,
        startTime: '12:00:00',
        endTime: '13:00:00',
      );

      expect(slot.stateLabel, 'Available');
    });
  });
}
