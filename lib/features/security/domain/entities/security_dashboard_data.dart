import '../../../admin/domain/entities/dashboard_stats.dart';
import '../../../admin/domain/entities/report.dart';
import '../../../admin/domain/entities/visitor_pass.dart';

/// The windows the dashboard can be looked at through.
///
/// The window decides which passes the cards, charts and table describe.
/// [today] is the default because that is what a gate desk is looking at.
enum SecurityRange {
  today('Today'),
  yesterday('Yesterday'),
  thisWeek('This Week'),
  thisMonth('This Month'),
  custom('Custom');

  const SecurityRange(this.label);

  final String label;

  /// How many days back this window reaches, used to size the sweep of pages
  /// the controller has to fetch. Null for [custom], which carries its own
  /// dates.
  int? get daysBack => switch (this) {
        SecurityRange.today => 1,
        SecurityRange.yesterday => 2,
        SecurityRange.thisWeek => 7,
        SecurityRange.thisMonth => 31,
        SecurityRange.custom => null,
      };
}

/// A concrete `[start, end)` window, resolved from a [SecurityRange].
class SecurityWindow {
  const SecurityWindow({
    required this.range,
    required this.start,
    required this.end,
  });

  final SecurityRange range;

  /// Inclusive.
  final DateTime start;

  /// Exclusive — always the midnight *after* the last day in the window, so a
  /// pass created at 23:59 still counts.
  final DateTime end;

  bool contains(DateTime? moment) {
    if (moment == null) return false;
    return !moment.isBefore(start) && moment.isBefore(end);
  }

  /// The window of the same length immediately before this one, for the
  /// increase/decrease figure on the cards.
  SecurityWindow get previous {
    final span = end.difference(start);
    return SecurityWindow(
      range: range,
      start: start.subtract(span),
      end: start,
    );
  }

  /// True when the window covers exactly one day — the hourly chart is only
  /// meaningful then, and the daily chart only outside it.
  bool get isSingleDay => end.difference(start).inHours <= 25;

  int get days {
    final span = end.difference(start).inDays;
    return span <= 0 ? 1 : span;
  }

  String get label => range == SecurityRange.custom
      ? '${_date(start)} – ${_date(end.subtract(const Duration(days: 1)))}'
      : range.label;

  static String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}';

  /// Resolves [range] against [now]. [customStart] / [customEnd] are only read
  /// for [SecurityRange.custom], and are normalised to whole days.
  factory SecurityWindow.of(
    SecurityRange range,
    DateTime now, {
    DateTime? customStart,
    DateTime? customEnd,
  }) {
    final today = DateTime(now.year, now.month, now.day);

    switch (range) {
      case SecurityRange.today:
        return SecurityWindow(
          range: range,
          start: today,
          end: today.add(const Duration(days: 1)),
        );
      case SecurityRange.yesterday:
        return SecurityWindow(
          range: range,
          start: today.subtract(const Duration(days: 1)),
          end: today,
        );
      case SecurityRange.thisWeek:
        // Monday-based, matching how the rest of the console reads a week.
        final monday = today.subtract(Duration(days: today.weekday - 1));
        return SecurityWindow(
          range: range,
          start: monday,
          end: today.add(const Duration(days: 1)),
        );
      case SecurityRange.thisMonth:
        return SecurityWindow(
          range: range,
          start: DateTime(now.year, now.month),
          end: today.add(const Duration(days: 1)),
        );
      case SecurityRange.custom:
        final rawStart = customStart ?? today;
        final rawEnd = customEnd ?? rawStart;
        var start = DateTime(rawStart.year, rawStart.month, rawStart.day);
        var end = DateTime(
          rawEnd.year,
          rawEnd.month,
          rawEnd.day,
        ).add(const Duration(days: 1));
        // A backwards range is a slip, not an empty dashboard.
        if (end.isBefore(start)) {
          final swap = start;
          start = end.subtract(const Duration(days: 1));
          end = swap.add(const Duration(days: 1));
        }
        return SecurityWindow(range: range, start: start, end: end);
    }
  }
}

/// One movement through the gate, for the timeline.
class SecurityTimelineEvent {
  const SecurityTimelineEvent({
    required this.at,
    required this.scanType,
    required this.pass,
  });

  final DateTime at;
  final VisitorScanType scanType;
  final VisitorPass pass;

  bool get isEntry => scanType == VisitorScanType.checkIn;

  String get title => isEntry
      ? '${pass.displayName} entered'
      : '${pass.displayName} exited';

  /// "08:35".
  String get timeLabel =>
      '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
}

/// Everything the Security Dashboard renders, derived from visitor passes.
///
/// The visitor-pass API is the seven documented routes and nothing else — there
/// is no statistics endpoint, and `GET /visitor-passes` filters by nothing but
/// `search`. So every figure here is computed from the rows the controller
/// fetched, in one pass, rather than read off a response. Should a
/// `/visitor-passes/stats` route appear later, only [SecurityDashboardData.from]
/// has to change.
class SecurityDashboardData {
  const SecurityDashboardData({
    required this.window,
    this.passes = const [],
    this.visitorsInWindow = 0,
    this.visitorsInPreviousWindow = 0,
    this.inside = 0,
    this.checkedOut = 0,
    this.pending = 0,
    this.totalPasses = 0,
    this.active = 0,
    this.expired = 0,
    this.timeline = const [],
    this.insidePasses = const [],
    this.purposes = const [],
    this.staff = const [],
    this.statusBreakdown = const ChartSeries(key: 'status', label: 'Status'),
    this.hourlyTrend = const ChartSeries(key: 'hourly', label: 'Per hour'),
    this.dailyTrend = const ChartSeries(key: 'daily', label: 'Per day'),
  });

  static const SecurityDashboardData none = SecurityDashboardData(
    window: null,
  );

  /// The window these figures describe. Null only on [none].
  final SecurityWindow? window;

  /// The passes inside the window, newest first — the activity table's source.
  final List<VisitorPass> passes;

  /// Passes issued in the window, and in the window before it, for the trend.
  final int visitorsInWindow;
  final int visitorsInPreviousWindow;

  /// Currently inside: checked in, not yet out. Deliberately **not** limited to
  /// the window — a visitor who entered before midnight is still in the
  /// building, and a gate desk needs to know that.
  final int inside;

  /// Visits completed inside the window.
  final int checkedOut;

  /// Issued in the window but never scanned in.
  final int pending;

  final int totalPasses;

  /// Still usable: pending or inside.
  final int active;

  /// Spent — checked out, expired or invalidated.
  final int expired;

  /// Entries and exits in the window, newest first.
  final List<SecurityTimelineEvent> timeline;

  /// Who is inside right now, most recent entry first.
  final List<VisitorPass> insidePasses;

  /// Distinct values in the window, for the filter dropdowns.
  final List<String> purposes;
  final List<String> staff;

  final ChartSeries statusBreakdown;
  final ChartSeries hourlyTrend;
  final ChartSeries dailyTrend;

  bool get isEmpty => window == null || totalPasses == 0;
  bool get isNotEmpty => !isEmpty;

  /// The card figure with its increase/decrease against the previous window.
  StatMetric get visitorsMetric => StatMetric(
        total: visitorsInWindow,
        thisMonth: visitorsInWindow,
        lastMonth: visitorsInPreviousWindow,
        growth: _growth(visitorsInWindow, visitorsInPreviousWindow),
        isPositive: visitorsInWindow >= visitorsInPreviousWindow,
      );

  /// Percentage change, or null when there is no baseline to compare against —
  /// "+100%" off a zero yesterday would be a claim the data cannot support.
  static double? _growth(int current, int previous) {
    if (previous <= 0) return null;
    return ((current - previous) / previous) * 100;
  }

  /// Builds every figure in a single pass over [all].
  ///
  /// [all] is the raw sweep — passes from any date. [now] is injected so the
  /// result is deterministic under test.
  factory SecurityDashboardData.from({
    required List<VisitorPass> all,
    required SecurityWindow window,
    required DateTime now,
  }) {
    final inWindow = <VisitorPass>[];
    final events = <SecurityTimelineEvent>[];
    final insidePasses = <VisitorPass>[];
    final purposes = <String>{};
    final staff = <String>{};

    var pending = 0;
    var checkedOut = 0;
    var expired = 0;
    var previousCount = 0;

    final previous = window.previous;
    final hourly = List<int>.filled(24, 0);
    final daily = <DateTime, int>{};

    for (final pass in all) {
      final created = pass.createdAt;

      // "Currently inside" is a live figure, so it looks at every pass swept,
      // not just the ones issued in the window.
      if (pass.status == VisitorPassStatus.checkedIn) {
        insidePasses.add(pass);
      }

      // The daily chart is "the last seven days", not "the last seven days of
      // the selected window" — so it buckets every pass swept and lets
      // [_dailySeries] pick the seven days it draws.
      if (created != null) {
        final day = DateTime(created.year, created.month, created.day);
        daily[day] = (daily[day] ?? 0) + 1;
      }

      if (window.contains(created)) {
        inWindow.add(pass);

        final purpose = (pass.visitPurpose ?? '').trim();
        if (purpose.isNotEmpty) purposes.add(purpose);
        final by = (pass.createdByName ?? '').trim();
        if (by.isNotEmpty) staff.add(by);

        switch (pass.status) {
          case VisitorPassStatus.pending:
            pending++;
          case VisitorPassStatus.checkedOut:
            checkedOut++;
            expired++;
          case VisitorPassStatus.expired:
          case VisitorPassStatus.invalid:
            expired++;
          case VisitorPassStatus.checkedIn:
          case null:
            break;
        }
      } else if (previous.contains(created)) {
        previousCount++;
      }

      // Movements are timestamped independently of when the pass was issued,
      // so they are windowed on their own times.
      final entry = pass.entryTime;
      if (window.contains(entry)) {
        events.add(
          SecurityTimelineEvent(
            at: entry!,
            scanType: VisitorScanType.checkIn,
            pass: pass,
          ),
        );
        hourly[entry.hour]++;
      }

      final exit = pass.exitTime;
      if (window.contains(exit)) {
        events.add(
          SecurityTimelineEvent(
            at: exit!,
            scanType: VisitorScanType.checkOut,
            pass: pass,
          ),
        );
      }
    }

    inWindow.sort(_byCreatedDescending);
    events.sort((a, b) => b.at.compareTo(a.at));
    insidePasses.sort((a, b) {
      final left = a.entryTime;
      final right = b.entryTime;
      if (left == null || right == null) return 0;
      return right.compareTo(left);
    });

    final inside = insidePasses.length;
    final total = inWindow.length;
    // A pass issued in the window and still inside counts as active alongside
    // the ones never scanned.
    final activeInWindow =
        pending + inWindow.where((p) => p.status == VisitorPassStatus.checkedIn).length;

    final sortedPurposes = purposes.toList()..sort();
    final sortedStaff = staff.toList()..sort();

    return SecurityDashboardData(
      window: window,
      passes: List<VisitorPass>.unmodifiable(inWindow),
      visitorsInWindow: total,
      visitorsInPreviousWindow: previousCount,
      inside: inside,
      checkedOut: checkedOut,
      pending: pending,
      totalPasses: total,
      active: activeInWindow,
      expired: expired,
      timeline: List<SecurityTimelineEvent>.unmodifiable(events),
      insidePasses: List<VisitorPass>.unmodifiable(insidePasses),
      purposes: List<String>.unmodifiable(sortedPurposes),
      staff: List<String>.unmodifiable(sortedStaff),
      statusBreakdown: _statusSeries(
        pending: pending,
        inside: inWindow
            .where((p) => p.status == VisitorPassStatus.checkedIn)
            .length,
        completed: checkedOut,
        expired: expired - checkedOut,
      ),
      hourlyTrend: _hourlySeries(hourly),
      dailyTrend: _dailySeries(daily, window, now),
    );
  }

  static int _byCreatedDescending(VisitorPass a, VisitorPass b) {
    final left = a.createdAt;
    final right = b.createdAt;
    if (left == null && right == null) return 0;
    if (left == null) return 1;
    if (right == null) return -1;
    return right.compareTo(left);
  }

  /// Pie: Pending / Inside / Completed / Expired. Empty slices are dropped so
  /// the chart never renders a zero-width wedge with a legend entry.
  static ChartSeries _statusSeries({
    required int pending,
    required int inside,
    required int completed,
    required int expired,
  }) {
    final points = <ChartPoint>[
      if (pending > 0) ChartPoint(label: 'Pending', value: pending),
      if (inside > 0) ChartPoint(label: 'Inside', value: inside),
      if (completed > 0) ChartPoint(label: 'Completed', value: completed),
      if (expired > 0) ChartPoint(label: 'Expired', value: expired),
    ];

    return ChartSeries(
      key: 'visitor-status',
      label: 'Visitor status',
      valueLabel: 'Passes',
      points: points,
    );
  }

  /// Line: entries per hour. All 24 buckets are kept — a quiet hour is a fact
  /// about the day, and dropping it would distort the shape of the curve.
  static ChartSeries _hourlySeries(List<int> hourly) {
    final hasAny = hourly.any((count) => count > 0);
    return ChartSeries(
      key: 'visitors-hourly',
      label: 'Visitors per hour',
      valueLabel: 'Entries',
      points: hasAny
          ? [
              for (var hour = 0; hour < hourly.length; hour++)
                ChartPoint(
                  label: '${hour.toString().padLeft(2, '0')}:00',
                  value: hourly[hour],
                ),
            ]
          : const [],
    );
  }

  /// Bar: passes per day over the last seven days ending with the window's last
  /// day, with the days nobody visited shown as zero rather than skipped.
  static ChartSeries _dailySeries(
    Map<DateTime, int> daily,
    SecurityWindow window,
    DateTime now,
  ) {
    const span = 7;
    final lastDay = window.end.subtract(const Duration(days: 1));
    final points = <ChartPoint>[];

    for (var offset = span - 1; offset >= 0; offset--) {
      final day = DateTime(
        lastDay.year,
        lastDay.month,
        lastDay.day,
      ).subtract(Duration(days: offset));
      points.add(
        ChartPoint(
          label: '${day.day}/${day.month}',
          value: daily[day] ?? 0,
        ),
      );
    }

    final hasAny = points.any((point) => point.value > 0);

    return ChartSeries(
      key: 'visitors-daily',
      label: 'Daily visitors',
      valueLabel: 'Passes',
      points: hasAny ? points : const [],
    );
  }
}