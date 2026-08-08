import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nahata_app/bottombar/event.dart';

/// The redesigned Events card.
///
/// The old card put the title *on* the poster over a gradient and showed
/// nothing else; the new one carries the two facts that decide a tap — when the
/// event is and what it costs — on a white block under the artwork. These pin
/// down that those facts are read off the slots correctly, and that the card
/// still fits the grid it is built into.
void main() {
  EventModel event({
    String title = 'Summer Slam',
    String location = 'Nahata Sports Complex',
    String image = '',
    List<Map<String, dynamic>> slots = const [],
  }) {
    return EventModel(
      id: '1',
      title: title,
      image: image,
      location: location,
      description: 'A tournament.',
      slots: slots,
    );
  }

  Widget host(Widget child) => MaterialApp(
        home: Scaffold(body: Center(child: SizedBox(width: 170, child: child))),
      );

  /// The real grid the cards are laid out in — same delegate as the screen.
  Widget grid(List<EventModel> events) => MaterialApp(
        home: Scaffold(
          body: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 16,
              childAspectRatio: 0.60,
            ),
            itemCount: events.length,
            itemBuilder: (context, i) =>
                EventCard(event: events[i], onTap: () {}),
          ),
        ),
      );

  testWidgets('shows the title, the venue and the cheapest slot price',
      (t) async {
    await t.pumpWidget(host(
      EventCard(
        onTap: () {},
        event: event(slots: const [
          {'date': '2026-09-12', 'price': '750'},
          {'date': '2026-09-10', 'price': '400'},
        ]),
      ),
    ));

    expect(find.text('Summer Slam'), findsOneWidget);
    expect(find.text('Nahata Sports Complex'), findsOneWidget);
    // Cheapest of the two, not the first.
    expect(find.text('₹400 onwards'), findsOneWidget);
    // Earliest of the two, not the first.
    expect(find.text('10 Sep'), findsOneWidget);
  });

  testWidgets('a zero-priced event reads as free, not as ₹0', (t) async {
    await t.pumpWidget(host(
      EventCard(
        onTap: () {},
        event: event(slots: const [
          {'date': '2026-09-10', 'price': '0'},
        ]),
      ),
    ));

    expect(find.text('Free entry'), findsOneWidget);
    expect(find.textContaining('₹'), findsNothing);
  });

  testWidgets('an event with no readable slots says nothing about money',
      (t) async {
    await t.pumpWidget(host(
      EventCard(
        onTap: () {},
        // No slots at all, and a slot whose price is unparseable.
        event: event(slots: const [
          {'date': 'not-a-date', 'price': 'TBA'},
        ]),
      ),
    ));

    // Guessing ₹0 here would advertise a free event that is not free.
    expect(find.text('View details'), findsOneWidget);
    expect(find.text('Free entry'), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('a missing poster falls back instead of showing a broken box',
      (t) async {
    await t.pumpWidget(host(EventCard(onTap: () {}, event: event(image: ''))));

    expect(find.byIcon(Icons.confirmation_number_outlined), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('a relative image path never reaches the network', (t) async {
    // The API has shipped bare paths before; `Image.network` on one throws.
    await t.pumpWidget(
      host(EventCard(onTap: () {}, event: event(image: 'uploads/x.png'))),
    );

    expect(find.byType(Image), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('tapping the card calls back', (t) async {
    var taps = 0;
    await t.pumpWidget(host(
      EventCard(onTap: () => taps++, event: event()),
    ));

    await t.tap(find.byType(EventCard));
    expect(taps, 1);
  });

  testWidgets('fits the grid on a small phone', (t) async {
    // 320×568 — the narrowest screen the app still ships to. An overflow here
    // throws, which is exactly what this is watching for.
    await t.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => t.binding.setSurfaceSize(null));

    await t.pumpWidget(grid([
      event(
        title: 'A tournament with a deliberately long name that wraps twice',
        slots: const [
          {'date': '2026-09-10', 'price': '1200'}
        ],
      ),
      event(title: 'Short'),
    ]));

    expect(t.takeException(), isNull);
  });
}
