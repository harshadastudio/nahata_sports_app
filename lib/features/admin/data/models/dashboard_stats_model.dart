import '../../domain/entities/dashboard_stats.dart';
import 'json_reader.dart';

/// Maps `GET /dashboard/stats` onto [DashboardStats].
///
/// Two shapes are handled, because this endpoint was never captured live:
///
/// * nested — `{ students: { total, thisMonth, lastMonth, growth, isPositive } }`
/// * flat   — `{ totalStudents, studentsThisMonth, studentsLastMonth, … }`
class DashboardStatsMapper {
  const DashboardStatsMapper._();

  static DashboardStats fromJson(Map<String, dynamic> json) {
    final source = _unwrap(json);

    return DashboardStats(
      students: _metric(source, 'students', const ['student']),
      coaches: _metric(source, 'coaches', const ['coach']),
      bookings: _metric(source, 'bookings', const ['booking']),
      enquiries: _metric(source, 'enquiries', const ['enquiry', 'inquiries']),
      contactRequests: _metric(source, 'contactRequests', const [
        'contact_requests',
        'contacts',
        'contactUs',
        'contact',
      ]),
      raw: source,
    );
  }

  /// Reads one metric under [key], accepting either shape.
  static StatMetric _metric(
    Map<String, dynamic> source,
    String key,
    List<String> aliases,
  ) {
    final keys = <String>[key, ...aliases];

    // Nested: the value under the key is itself an object.
    for (final candidate in keys) {
      final value = JsonReader.pick(source, [candidate]);
      if (value is Map) {
        return _metricFrom(Map<String, dynamic>.from(value));
      }
    }

    // Flat: `totalStudents` / `studentsThisMonth` / `students_growth` …
    final capitalised = keys
        .map((k) => k.isEmpty ? k : k[0].toUpperCase() + k.substring(1))
        .toList();

    int? readInt(List<String> patterns) => JsonReader.integer(source, patterns);

    final total = readInt([
      for (final k in keys) ...[
        'total${_cap(k)}',
        // Snake-case totals: `total_coaches`, `total_contact_requests`.
        'total_$k',
        k,
        '${k}Count',
        '${k}_count',
      ],
      for (final k in capitalised) 'total$k',
    ]);
    final thisMonth = readInt([
      for (final k in keys) ...[
        '${k}ThisMonth',
        '${k}_this_month',
        'thisMonth${_cap(k)}',
      ],
    ]);
    final lastMonth = readInt([
      for (final k in keys) ...[
        '${k}LastMonth',
        '${k}_last_month',
        'lastMonth${_cap(k)}',
      ],
    ]);
    final growth = _double(source, [
      for (final k in keys) ...[
        '${k}Growth',
        '${k}_growth',
        '${k}GrowthPercentage',
      ],
    ]);
    final isPositive = JsonReader.boolean(source, [
      for (final k in keys) ...['${k}IsPositive', '${k}_is_positive'],
    ]);

    return StatMetric(
      total: total,
      thisMonth: thisMonth,
      lastMonth: lastMonth,
      growth: growth,
      isPositive: isPositive,
    );
  }

  static StatMetric _metricFrom(Map<String, dynamic> json) {
    return StatMetric(
      total: JsonReader.integer(json, const [
        'total',
        'count',
        'totalCount',
        'value',
      ]),
      thisMonth: JsonReader.integer(json, const [
        'thisMonth',
        'this_month',
        'currentMonth',
        'current',
      ]),
      lastMonth: JsonReader.integer(json, const [
        'lastMonth',
        'last_month',
        'previousMonth',
        'previous',
      ]),
      growth: _double(json, const [
        'growth',
        'growthPercentage',
        'growth_percentage',
        'percentage',
        'change',
      ]),
      isPositive: JsonReader.boolean(json, const [
        'isPositive',
        'is_positive',
        'positive',
        'trendUp',
      ]),
    );
  }

  /// Percentages arrive as `12`, `12.5` or `"12.5%"`.
  static double? _double(Map<String, dynamic> json, List<String> keys) {
    final value = JsonReader.pick(json, keys);
    if (value == null) return null;
    if (value is num) return value.toDouble();

    final text = value
        .toString()
        .trim()
        .replaceAll('%', '')
        .replaceAll('+', '');
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  static String _cap(String value) =>
      value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

  static Map<String, dynamic> _unwrap(Map<String, dynamic> json) {
    for (final key in const ['data', 'stats', 'result', 'summary']) {
      final inner = json[key];
      if (inner is Map) {
        final unwrapped = Map<String, dynamic>.from(inner);
        final nested = unwrapped['stats'];
        if (nested is Map) return Map<String, dynamic>.from(nested);
        return unwrapped;
      }
    }
    return json;
  }
}
