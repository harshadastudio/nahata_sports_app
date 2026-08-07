import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The card body from `viewgame.dart`'s `_buildGameCard`, in the grid cell it
/// actually gets.
///
/// The real widget needs a `Sport`, a network image and a navigator, so what
/// is pinned here is the layout that broke: a fixed-height cell
/// (`childAspectRatio: 1.1`) containing padding + a 60px badge + a gap + a
/// title. A long name or a large system text scale used to push that past the
/// cell and paint the overflow stripes.
Widget gameCardBody(String title) {
  return Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(30),
          ),
          child: const Icon(Icons.sports, color: Colors.white, size: 30),
        ),
        const SizedBox(height: 8),
        Flexible(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    ),
  );
}

Future<void> pumpGrid(
  WidgetTester tester,
  List<String> titles, {
  double width = 360,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = Size(width, 720);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: GridView.builder(
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                childAspectRatio: 1.1,
              ),
              itemCount: titles.length,
              itemBuilder: (context, index) => DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A237E),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: gameCardBody(titles[index]),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a short sport name fits', (tester) async {
    await pumpGrid(tester, const ['Tennis', 'Squash']);
    expect(tester.takeException(), isNull);
    expect(find.text('Tennis'), findsOneWidget);
  });

  testWidgets('a long name that wraps to two lines does not overflow',
      (tester) async {
    // This is the case that produced "bottom overflowed by 4.7 pixels".
    await pumpGrid(tester, const [
      'Table Tennis Doubles',
      'Basketball Half Court',
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a very long name ellipsises rather than overflowing',
      (tester) async {
    await pumpGrid(tester, const [
      'Synchronised Underwater Basket Weaving Championship',
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('survives a large system text scale', (tester) async {
    // The accessibility setting that makes every fixed-height card overflow.
    await pumpGrid(
      tester,
      const ['Table Tennis Doubles', 'Badminton'],
      textScale: 1.6,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('survives a narrow phone', (tester) async {
    await pumpGrid(
      tester,
      const ['Table Tennis Doubles', 'Badminton'],
      width: 320,
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
  });
}