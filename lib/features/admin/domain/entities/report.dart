/// The window every report is read for.
///
/// `from` and `to` go out as `yyyy-MM-dd`, the format every other admin route
/// in this console uses for a date.
class DateRange {
  const DateRange({required this.from, required this.to});

  final DateTime from;
  final DateTime to;

  static String wire(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  String get wireFrom => wire(from);
  String get wireTo => wire(to);

  int get days => to.difference(from).inDays + 1;

  /// The same length of time immediately before this one, for a comparison the
  /// UI can offer without inventing a growth figure of its own.
  DateRange get previous {
    final length = Duration(days: days);
    final end = from.subtract(const Duration(days: 1));
    return DateRange(from: end.subtract(length - const Duration(days: 1)), to: end);
  }

  bool get isSingleDay => days == 1;

  static DateRange lastDays(int count, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final end = DateTime(today.year, today.month, today.day);
    return DateRange(from: end.subtract(Duration(days: count - 1)), to: end);
  }

  static DateRange thisMonth({DateTime? now}) {
    final today = now ?? DateTime.now();
    return DateRange(
      from: DateTime(today.year, today.month),
      to: DateTime(today.year, today.month, today.day),
    );
  }

  static DateRange lastMonth({DateTime? now}) {
    final today = now ?? DateTime.now();
    final firstOfThis = DateTime(today.year, today.month);
    final end = firstOfThis.subtract(const Duration(days: 1));
    return DateRange(from: DateTime(end.year, end.month), to: end);
  }

  static DateRange thisYear({DateTime? now}) {
    final today = now ?? DateTime.now();
    return DateRange(
      from: DateTime(today.year),
      to: DateTime(today.year, today.month, today.day),
    );
  }

  /// Cache key: two reports for the same window are the same report.
  String get key => '$wireFrom→$wireTo';

  @override
  bool operator ==(Object other) =>
      other is DateRange && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => key;
}

/// The named windows the picker offers.
enum DateRangePreset {
  today('Today'),
  last7('Last 7 days'),
  last30('Last 30 days'),
  last90('Last 90 days'),
  thisMonth('This month'),
  lastMonth('Last month'),
  thisYear('This year');

  const DateRangePreset(this.label);

  final String label;

  DateRange range({DateTime? now}) {
    switch (this) {
      case DateRangePreset.today:
        return DateRange.lastDays(1, now: now);
      case DateRangePreset.last7:
        return DateRange.lastDays(7, now: now);
      case DateRangePreset.last30:
        return DateRange.lastDays(30, now: now);
      case DateRangePreset.last90:
        return DateRange.lastDays(90, now: now);
      case DateRangePreset.thisMonth:
        return DateRange.thisMonth(now: now);
      case DateRangePreset.lastMonth:
        return DateRange.lastMonth(now: now);
      case DateRangePreset.thisYear:
        return DateRange.thisYear(now: now);
    }
  }
}

/// How a figure should read.
enum ReportFormat { count, currency, percent, minutes, text }

/// One number on a report.
///
/// [value] is nullable throughout: a figure the endpoint did not send shows as
/// an em dash, never as a 0, which would be a claim of its own.
class ReportFigure {
  const ReportFigure({
    required this.key,
    required this.label,
    this.value,
    this.text,
    this.format = ReportFormat.count,
  });

  /// The wire key this was read from, so a caller can find it again.
  final String key;

  final String label;
  final num? value;

  /// Set instead of [value] when the endpoint answered with a word.
  final String? text;

  final ReportFormat format;

  bool get isEmpty => value == null && (text ?? '').trim().isEmpty;

  @override
  String toString() => '$label=${value ?? text ?? '—'}';
}

/// One point on a chart.
class ChartPoint {
  const ChartPoint({required this.label, required this.value, this.secondary});

  final String label;
  final num value;

  /// A second figure some series carry (bookings *and* revenue for a court).
  final num? secondary;

  @override
  String toString() => '$label: $value';
}

/// A named series of points.
class ChartSeries {
  const ChartSeries({
    required this.key,
    required this.label,
    this.points = const [],
    this.valueLabel,
    this.format = ReportFormat.count,
    this.secondaryLabel,
    this.secondaryFormat = ReportFormat.count,
  });

  final String key;
  final String label;
  final List<ChartPoint> points;

  /// What the values mean, for the tooltip ("Bookings", "Revenue").
  final String? valueLabel;

  final ReportFormat format;

  /// What [ChartPoint.secondary] means, when the payload carries two figures
  /// per point — the captured booking-trends rows send bookings *and* revenue.
  /// Null means the second figure has no known meaning and is not shown.
  final String? secondaryLabel;
  final ReportFormat secondaryFormat;

  bool get isEmpty => points.isEmpty;
  bool get isNotEmpty => points.isNotEmpty;

  num get total => points.fold<num>(0, (sum, point) => sum + point.value);

  num get maxValue => points.isEmpty
      ? 0
      : points.map((p) => p.value).reduce((a, b) => a > b ? a : b);

  @override
  String toString() => 'ChartSeries($key, ${points.length} points)';
}

/// One report's worth of figures and series.
///
/// The module documents *what to display* for each endpoint but ships no sample
/// response, so a mapper reads the documented figures through candidate keys and
/// keeps whatever else came back in [extras] — section 1 asks for "any
/// additional values returned by API" in as many words, and the same courtesy
/// costs nothing on the other twelve.
class ReportSection {
  const ReportSection({
    this.figures = const [],
    this.extras = const [],
    this.charts = const [],
    this.raw = const {},
  });

  /// The documented figures, in the order the module lists them.
  final List<ReportFigure> figures;

  /// Numbers the endpoint sent that the module never mentioned.
  final List<ReportFigure> extras;

  final List<ChartSeries> charts;

  final Map<String, dynamic> raw;

  bool get isEmpty =>
      figures.every((f) => f.isEmpty) &&
      extras.isEmpty &&
      charts.every((c) => c.isEmpty);

  /// The figures worth drawing a card for: documented ones that arrived, plus
  /// anything extra.
  List<ReportFigure> get shownFigures => [
    ...figures.where((figure) => !figure.isEmpty),
    ...extras,
  ];

  ReportFigure? figure(String key) {
    for (final figure in [...figures, ...extras]) {
      if (figure.key == key) return figure;
    }
    return null;
  }

  num? valueOf(String key) => figure(key)?.value;

  ChartSeries? chart(String key) {
    for (final series in charts) {
      if (series.key == key) return series;
    }
    return null;
  }

  List<ChartSeries> get shownCharts =>
      charts.where((series) => series.isNotEmpty).toList(growable: false);

  @override
  String toString() =>
      'ReportSection(${figures.length} figures, ${extras.length} extra, '
      '${charts.length} charts)';
}

/// One option in a filter dropdown, from a `/filter-options` route.
class FilterOption {
  const FilterOption({required this.id, required this.label});

  final String id;
  final String label;

  @override
  bool operator ==(Object other) =>
      other is FilterOption && other.id == id && other.label == label;

  @override
  int get hashCode => Object.hash(id, label);

  @override
  String toString() => '$label ($id)';
}

/// A `/filter-options` payload: named groups of options.
///
/// The routes are documented by the dropdowns they fill (sport, batch, coach,
/// status …) but not by their shape, so every group the payload carries is
/// kept and the UI asks for the ones it knows by name.
class ReportFilterOptions {
  const ReportFilterOptions({this.groups = const {}});

  final Map<String, List<FilterOption>> groups;

  bool get isEmpty => groups.isEmpty;

  List<FilterOption> operator [](String group) => groups[group] ?? const [];

  /// The first group matching any of [names], for callers that know a field by
  /// several possible keys (`sports`, `sport`, `sportOptions`).
  List<FilterOption> find(List<String> names) {
    for (final name in names) {
      final group = groups[name];
      if (group != null && group.isNotEmpty) return group;
    }
    return const [];
  }

  @override
  String toString() => 'ReportFilterOptions(${groups.keys.toList()})';
}

/// The filters a report table can carry.
///
/// Every value is the option *id* as the filter-options route gave it, sent
/// verbatim — this console never rewrites a value the server chose.
class ReportFilters {
  const ReportFilters({this.values = const {}, this.search = ''});

  final Map<String, String> values;
  final String search;

  bool get isEmpty => values.isEmpty && search.trim().isEmpty;
  int get count => values.length;

  String? operator [](String key) => values[key];

  ReportFilters withValue(String key, String? value) {
    final next = Map<String, String>.from(values);
    if (value == null || value.isEmpty) {
      next.remove(key);
    } else {
      next[key] = value;
    }
    return ReportFilters(values: next, search: search);
  }

  ReportFilters withSearch(String value) =>
      ReportFilters(values: values, search: value);

  ReportFilters get cleared => const ReportFilters();

  Map<String, dynamic> get query => <String, dynamic>{
    ...values,
    if (search.trim().isNotEmpty) 'search': search.trim(),
  };

  @override
  String toString() => 'ReportFilters($values, search: "$search")';
}

/// One row of `GET /reports/bookings/all`.
class BookingReportRow {
  const BookingReportRow({
    required this.id,
    this.reference,
    this.userName,
    this.userContact,
    this.sportName,
    this.courtName,
    this.date,
    this.slotLabel,
    this.amount,
    this.statusRaw,
    this.paymentStatusRaw,
    this.raw = const {},
  });

  final String id;
  final String? reference;
  final String? userName;
  final String? userContact;
  final String? sportName;
  final String? courtName;
  final DateTime? date;
  final String? slotLabel;
  final num? amount;
  final String? statusRaw;
  final String? paymentStatusRaw;

  final Map<String, dynamic> raw;

  String get displayReference {
    final trimmed = (reference ?? '').trim();
    return trimmed.isEmpty ? '#$id' : trimmed;
  }

  String get displayUser {
    final trimmed = (userName ?? '').trim();
    return trimmed.isEmpty ? 'Unknown' : trimmed;
  }

  bool matches(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    return displayReference.toLowerCase().contains(needle) ||
        displayUser.toLowerCase().contains(needle) ||
        (sportName ?? '').toLowerCase().contains(needle) ||
        (courtName ?? '').toLowerCase().contains(needle) ||
        (userContact ?? '').toLowerCase().contains(needle) ||
        id.toLowerCase().contains(needle);
  }

  @override
  String toString() => 'BookingReportRow($id, $userName, $amount)';
}

/// One row of `GET /reports/students/all`.
class StudentReportRow {
  const StudentReportRow({
    required this.id,
    this.name,
    this.contact,
    this.sportName,
    this.coachName,
    this.batchName,
    this.membership,
    this.joinedAt,
    this.statusRaw,
    this.raw = const {},
  });

  final String id;
  final String? name;
  final String? contact;
  final String? sportName;
  final String? coachName;
  final String? batchName;
  final String? membership;
  final DateTime? joinedAt;
  final String? statusRaw;

  final Map<String, dynamic> raw;

  String get displayName {
    final trimmed = (name ?? '').trim();
    return trimmed.isEmpty ? 'Unnamed student' : trimmed;
  }

  String get initials {
    final parts = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  bool matches(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    return displayName.toLowerCase().contains(needle) ||
        (sportName ?? '').toLowerCase().contains(needle) ||
        (coachName ?? '').toLowerCase().contains(needle) ||
        (batchName ?? '').toLowerCase().contains(needle) ||
        (contact ?? '').toLowerCase().contains(needle) ||
        id.toLowerCase().contains(needle);
  }

  @override
  String toString() => 'StudentReportRow($id, $name, $batchName)';
}

/// One row of `GET /reports/coaches/all`.
class CoachReportRow {
  const CoachReportRow({
    required this.id,
    this.name,
    this.sportName,
    this.complexName,
    this.studentCount,
    this.revenue,
    this.programCount,
    this.statusRaw,
    this.raw = const {},
  });

  final String id;
  final String? name;
  final String? sportName;
  final String? complexName;
  final int? studentCount;
  final num? revenue;
  final int? programCount;
  final String? statusRaw;

  final Map<String, dynamic> raw;

  String get displayName {
    final trimmed = (name ?? '').trim();
    return trimmed.isEmpty ? 'Unnamed coach' : trimmed;
  }

  String get initials {
    final parts = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  bool matches(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    return displayName.toLowerCase().contains(needle) ||
        (sportName ?? '').toLowerCase().contains(needle) ||
        (complexName ?? '').toLowerCase().contains(needle) ||
        id.toLowerCase().contains(needle);
  }

  @override
  String toString() => 'CoachReportRow($id, $name, $studentCount students)';
}
