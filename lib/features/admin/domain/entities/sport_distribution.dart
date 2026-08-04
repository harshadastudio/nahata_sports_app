import 'dart:ui' show Color;

/// One slice of the sport doughnut (`GET /dashboard/sport-distribution`).
class SportSlice {
  const SportSlice({
    required this.sport,
    this.count,
    this.percentage,
    this.color,
  });

  final String sport;
  final int? count;

  /// The share as the server computed it. [effectivePercentage] falls back to
  /// deriving it from the counts when this is absent.
  final double? percentage;

  /// Parsed from the API's own hex string. Null means "the API did not pick a
  /// colour" and the chart assigns one from the theme palette — it never
  /// overrides a colour the backend did send.
  final Color? color;

  int get value => count ?? 0;

  @override
  String toString() => 'SportSlice($sport: $count, $percentage%)';
}

/// The full distribution.
class SportDistribution {
  const SportDistribution({this.slices = const []});

  final List<SportSlice> slices;

  static const SportDistribution empty = SportDistribution();

  bool get isEmpty => slices.isEmpty;
  bool get isNotEmpty => slices.isNotEmpty;

  /// Shown in the middle of the doughnut.
  int get totalSports => slices.length;

  int get totalCount => slices.fold(0, (sum, slice) => sum + slice.value);

  /// Every slice is zero — a doughnut cannot be drawn from that, so the page
  /// shows its empty state.
  bool get isAllZero => totalCount == 0;

  /// The share of [slice], using the server's percentage when it sent one and
  /// deriving it from the counts otherwise.
  double percentageOf(SportSlice slice) {
    final sent = slice.percentage;
    if (sent != null) return sent;

    final total = totalCount;
    if (total <= 0) return 0;
    return (slice.value / total) * 100;
  }

  @override
  String toString() =>
      'SportDistribution($totalSports sports, $totalCount total)';
}
