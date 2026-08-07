import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nahata_app/features/coach/presentation/theme/coach_theme.dart';

/// Regression tests for [CoachCard]'s layout.
///
/// The card is used almost exclusively as a list item, where the incoming
/// height constraint is unbounded. An earlier version laid the accent stripe
/// out with `Row(crossAxisAlignment: stretch)`, which forces an infinite
/// height on its children in exactly that position — every coach screen threw
/// "BoxConstraints forces an infinite height" and rendered blank.
void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('CoachCard in an unbounded-height list', () {
    testWidgets('lays out with an accent stripe', (tester) async {
      await tester.pumpWidget(
        host(
          ListView(
            children: const [
              CoachCard(
                accentColor: Colors.red,
                child: Text('with stripe'),
              ),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('with stripe'), findsOneWidget);
    });

    testWidgets('lays out without an accent stripe', (tester) async {
      await tester.pumpWidget(
        host(
          ListView(
            children: const [
              CoachCard(child: Text('no stripe')),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('no stripe'), findsOneWidget);
    });

    testWidgets('lays out when tappable', (tester) async {
      var taps = 0;

      await tester.pumpWidget(
        host(
          ListView(
            children: [
              CoachCard(
                accentColor: Colors.blue,
                onTap: () => taps++,
                child: const Text('tappable'),
              ),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isNull);

      await tester.tap(find.text('tappable'));
      expect(taps, 1);
    });

    testWidgets('a tall child grows the card rather than overflowing',
        (tester) async {
      await tester.pumpWidget(
        host(
          ListView(
            children: const [
              CoachCard(
                accentColor: Colors.green,
                child: SizedBox(height: 400, child: Text('tall')),
              ),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isNull);

      // 400 for the child plus the card's default 16pt padding top and bottom.
      final card = tester.getSize(find.byType(CoachCard));
      expect(card.height, 400 + 32);
    });

    testWidgets('the stripe spans the full height of the card',
        (tester) async {
      await tester.pumpWidget(
        host(
          ListView(
            children: const [
              CoachCard(
                accentColor: Colors.orange,
                child: SizedBox(height: 200),
              ),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isNull);

      // Scoped to the stripe's own colour — Material and Scaffold put their
      // own ColoredBoxes in the tree, so `byType` alone finds the wrong one.
      final stripe = tester.getSize(
        find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == Colors.orange,
        ),
      );
      expect(stripe.width, 4);
      // Fills the card: the 200pt child plus its padding.
      expect(stripe.height, 200 + 32);
    });
  });

  group('CoachCard in a bounded box', () {
    testWidgets('still lays out when the height is constrained',
        (tester) async {
      await tester.pumpWidget(
        host(
          SizedBox(
            height: 120,
            child: CoachCard(
              accentColor: Colors.purple,
              child: const Text('bounded'),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('bounded'), findsOneWidget);
    });
  });
}
