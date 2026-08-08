import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shimmer/shimmer.dart';

import 'package:nahata_app/core/widgets/app_shimmer.dart';

/// Each placeholder is pumped under the *same* constraints the real screen
/// gives it, because that is where this kind of widget breaks: an `Expanded` in
/// an unbounded Column, or a grid that owns its viewport dropped into a scroll
/// view. Both compile fine and blow up only at layout.
void main() {
  /// Pumps without settling — Shimmer animates forever, so pumpAndSettle would
  /// never return.
  Future<void> pumpClean(WidgetTester t, Widget child) async {
    await t.pumpWidget(MaterialApp(home: child));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(t.takeException(), isNull);
  }

  /// The two shapes every placeholder lands in.
  Widget inBody(Widget child) => Scaffold(body: child);

  Widget inExpanded(Widget child) =>
      Scaffold(body: Column(children: [Expanded(child: child)]));

  Widget inScrollView(Widget child) => Scaffold(
        body: SingleChildScrollView(
          child: Column(children: [const SizedBox(height: 40), child]),
        ),
      );

  group('Play', () {
    testWidgets('the venue list fills a Scaffold body', (t) async {
      // BookPlay: `body: AppShimmer.venueList()`.
      await pumpClean(t, inBody(AppShimmer.venueList()));
      expect(find.byType(Shimmer), findsWidgets);
    });

    testWidgets('the sports grid sits inside the page scroll view', (t) async {
      // viewgame: the grid is a Column child inside a SingleChildScrollView.
      await pumpClean(t, inScrollView(AppShimmer.sportsGrid()));
      expect(find.byType(Shimmer), findsWidgets);
    });

    testWidgets('the slot screen lays out inside an Expanded', (t) async {
      // slotbook: `body: Column(children: [Expanded(child: _buildBody())])`.
      await pumpClean(t, inExpanded(AppShimmer.slotBooking()));
      expect(find.byType(Shimmer), findsWidgets);
    });
  });

  group('Coaching', () {
    testWidgets('the sports grid owns its viewport', (t) async {
      // profile.dart SportsScreen: `Expanded(child: FutureBuilder(...))`.
      await pumpClean(t, inExpanded(AppShimmer.coachingSports()));
      expect(find.byType(Shimmer), findsWidgets);
    });

    testWidgets('the batch list fills a Scaffold body', (t) async {
      // profile.dart BatchScreen: `body: FutureBuilder(...)`.
      await pumpClean(t, inBody(AppShimmer.batchList()));
      expect(find.byType(Shimmer), findsWidgets);
    });
  });

  group('Events', () {
    testWidgets('the poster grid lays out inside an Expanded', (t) async {
      // event.dart: `Expanded(child: _buildEventGrid())`.
      await pumpClean(t, inExpanded(AppShimmer.eventGrid()));
      expect(find.byType(Shimmer), findsWidgets);
    });
  });

  testWidgets('no spinner is left behind anywhere', (t) async {
    // The point of the change: content-shaped placeholders replaced the
    // centred CircularProgressIndicator, they did not join it.
    final placeholders = <Widget>[
      inBody(AppShimmer.venueList()),
      inScrollView(AppShimmer.sportsGrid()),
      inExpanded(AppShimmer.slotBooking()),
      inExpanded(AppShimmer.coachingSports()),
      inBody(AppShimmer.batchList()),
      inExpanded(AppShimmer.eventGrid()),
    ];

    for (final placeholder in placeholders) {
      await pumpClean(t, placeholder);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(Shimmer), findsWidgets);
    }
  });
}
