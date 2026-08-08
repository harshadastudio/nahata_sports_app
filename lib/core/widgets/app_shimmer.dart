import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Loading placeholders for the student-facing browse screens — Play,
/// Coaching and Events.
///
/// These replace the centred spinner each of those screens used to show. A
/// spinner says "something is happening somewhere"; a shimmer laid out like the
/// real content says *what* is coming and roughly how much of it, so the screen
/// fills in place instead of snapping from an empty page to a full one.
///
/// Every placeholder copies the geometry of the widget it stands in for — the
/// same grid columns, spacing and aspect ratio, the same card heights. That is
/// the whole point of using one instead of a spinner, and it is why the grids
/// below do not share a single set of numbers: each screen's grid is shaped
/// differently.
class AppShimmer {
  const AppShimmer._();

  static const Color _base = Color(0xFFE9ECF3);
  static const Color _highlight = Color(0xFFF7F8FC);

  /// One shimmering block. [width] `null` fills the available width.
  static Widget box({
    double? width,
    double height = 14,
    double radius = 8,
  }) {
    return Shimmer.fromColors(
      baseColor: _base,
      highlightColor: _highlight,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }

  /// A grid of plain tiles, shaped by the caller.
  ///
  /// [shrinkWrap] for the grids that sit inside another scroll view; the ones
  /// that own their viewport leave it false so they fill the space the real
  /// grid will.
  static Widget tileGrid({
    int tiles = 4,
    double crossAxisSpacing = 16,
    double mainAxisSpacing = 16,
    double childAspectRatio = 1.1,
    EdgeInsets padding = EdgeInsets.zero,
    double radius = 16,
    bool shrinkWrap = false,
  }) {
    return GridView.builder(
      shrinkWrap: shrinkWrap,
      physics: const NeverScrollableScrollPhysics(),
      padding: padding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: mainAxisSpacing,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: tiles,
      itemBuilder: (context, index) => box(radius: radius),
    );
  }

  // ---------------------------------------------------------------------------
  // Play
  // ---------------------------------------------------------------------------

  /// The Play tab while its venues load: carousel, filter chips, venue cards.
  static Widget venueList({int cards = 2}) {
    return SingleChildScrollView(
      // Not scrollable in practice, but it keeps the placeholder in the same
      // scroll position the real screen builds in.
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Carousel band.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: box(height: 200, radius: 16),
          ),
          const SizedBox(height: 21),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // "Available Venues"
                box(width: 130, height: 14),
                const SizedBox(height: 12),
                // Date chip + sport chips.
                Row(
                  children: [
                    box(width: 64, height: 32, radius: 20),
                    const SizedBox(width: 8),
                    box(width: 86, height: 32, radius: 20),
                    const SizedBox(width: 8),
                    box(width: 74, height: 32, radius: 20),
                    const SizedBox(width: 8),
                    Expanded(child: box(height: 32, radius: 20)),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          for (var i = 0; i < cards; i++) _venueCard(),
        ],
      ),
    );
  }

  static Widget _venueCard() {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            child: box(height: 200, radius: 0),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                box(width: 16, height: 16, radius: 4),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: box(height: 16)),
                    const SizedBox(width: 12),
                    box(width: 58, height: 14),
                  ],
                ),
                const SizedBox(height: 10),
                box(width: 180, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// A venue's sports grid (Play → venue), inside that screen's scroll view.
  static Widget sportsGrid({int tiles = 4}) => tileGrid(
        tiles: tiles,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childAspectRatio: 1.1,
        radius: 20,
        shrinkWrap: true,
      );

  /// The slot-booking screen while courts and prices load: the month label,
  /// the date strip, the court chips and the slot rows.
  static Widget slotBooking({int slots = 6}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        // Month label.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: box(width: 120, height: 16),
        ),
        const SizedBox(height: 12),
        // Date strip — 60×80 tiles, 4px either side.
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 7,
            itemBuilder: (context, index) => Container(
              width: 60,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: box(radius: 12),
            ),
          ),
        ),
        const SizedBox(height: 20),
        // "Available Slots(n)"
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: box(width: 140, height: 14),
        ),
        const SizedBox(height: 12),
        // Court chips.
        SizedBox(
          height: 42,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 4,
            itemBuilder: (context, index) => Container(
              width: 104,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: box(radius: 10),
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Hour-type tabs.
        Container(
          height: 45,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(child: box(radius: 8)),
              const SizedBox(width: 8),
              Expanded(child: box(radius: 8)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Slot rows.
        Expanded(
          child: ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            itemCount: slots,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: box(height: 60, radius: 12),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Coaching
  // ---------------------------------------------------------------------------

  /// The Coaching tab's sports grid. Owns its viewport (it is the `Expanded`
  /// child of the screen's Column), so it does not shrink-wrap.
  static Widget coachingSports({int tiles = 6}) => tileGrid(
        tiles: tiles,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.2,
        padding: const EdgeInsets.all(20),
        radius: 16,
      );

  /// A sport's batch list (Coaching → sport): stacked cards, each carrying a
  /// title, a few detail lines, a button and a price row.
  static Widget batchList({int cards = 3}) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      itemCount: cards,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      box(width: 150, height: 18),
                      const SizedBox(height: 10),
                      box(width: 110, height: 13),
                      const SizedBox(height: 6),
                      box(width: 170, height: 13),
                      const SizedBox(height: 6),
                      box(width: 140, height: 13),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                box(width: 92, height: 28, radius: 6),
              ],
            ),
            const SizedBox(height: 16),
            box(width: 96, height: 14),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Events
  // ---------------------------------------------------------------------------

  /// The Events tab's poster grid: artwork on top, title / venue / price
  /// underneath — the same card the real grid builds, and the same 0.60 aspect
  /// ratio, so the posters land exactly where the placeholders were.
  static Widget eventGrid({int tiles = 4}) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
        childAspectRatio: 0.60,
      ),
      itemCount: tiles,
      itemBuilder: (context, index) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: box(radius: 0)),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  box(height: 12),
                  const SizedBox(height: 6),
                  box(width: 70, height: 10),
                  const SizedBox(height: 8),
                  box(width: 88, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
