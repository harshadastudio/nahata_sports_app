import 'dart:ui' show Color;

import '../../domain/entities/enrollment_trend.dart';
import '../../domain/entities/live_enquiry.dart';
import '../../domain/entities/sport_distribution.dart';
import 'json_reader.dart';

/// Maps `GET /dashboard/enrollment-trends`.
class EnrollmentTrendMapper {
  const EnrollmentTrendMapper._();

  static EnrollmentTrend fromBody(Object? body) {
    final records = JsonReader.records(
      body,
      keys: const ['trends', 'items', 'data', 'months', 'enrollmentTrends'],
    );

    final points = records
        .map(_point)
        .whereType<EnrollmentPoint>()
        .toList(growable: false);

    return EnrollmentTrend(points: points);
  }

  static EnrollmentPoint? _point(Map<String, dynamic> json) {
    final label = JsonReader.string(json, const [
      'month',
      'label',
      'name',
      'period',
      'monthName',
      'date',
    ]);
    // A point with no label cannot be placed on the x-axis.
    if (label == null) return null;

    return EnrollmentPoint(
      label: label,
      students: JsonReader.integer(json, const [
        'students',
        'studentCount',
        'student_count',
        'enrollments',
        'admissions',
      ]),
      enquiries: JsonReader.integer(json, const [
        'enquiries',
        'inquiries',
        'enquiryCount',
        'enquiry_count',
        'leads',
      ]),
    );
  }
}

/// Maps `GET /dashboard/sport-distribution`.
class SportDistributionMapper {
  const SportDistributionMapper._();

  static SportDistribution fromBody(Object? body) {
    final records = JsonReader.records(
      body,
      keys: const [
        'distribution',
        'sports',
        'items',
        'data',
        'sportDistribution',
      ],
    );

    final slices = records
        .map(_slice)
        .whereType<SportSlice>()
        .toList(growable: false);

    return SportDistribution(slices: slices);
  }

  static SportSlice? _slice(Map<String, dynamic> json) {
    final sport = JsonReader.string(json, const [
      'sport',
      'sportName',
      'sport_name',
      'name',
      'label',
      'title',
    ]);
    if (sport == null) return null;

    return SportSlice(
      sport: sport,
      count: JsonReader.integer(json, const [
        'count',
        'total',
        'value',
        'students',
        'enrollments',
      ]),
      percentage: _double(json, const [
        'percentage',
        'percent',
        'share',
        'ratio',
      ]),
      color: parseColor(
        JsonReader.string(json, const ['color', 'colour', 'hex', 'colorCode']),
      ),
    );
  }

  /// `#RRGGBB`, `#AARRGGBB`, `RRGGBB` and `rgb(r, g, b)` all parse; anything
  /// else returns null so the chart falls back to its own palette rather than
  /// drawing a black slice.
  static Color? parseColor(String? value) {
    var text = (value ?? '').trim();
    if (text.isEmpty) return null;

    final rgb = RegExp(
      r'^rgba?\(([^)]+)\)$',
      caseSensitive: false,
    ).firstMatch(text);
    if (rgb != null) {
      final parts = rgb
          .group(1)!
          .split(',')
          .map((part) => part.trim())
          .toList();
      if (parts.length < 3) return null;
      final r = int.tryParse(parts[0]);
      final g = int.tryParse(parts[1]);
      final b = int.tryParse(parts[2]);
      if (r == null || g == null || b == null) return null;
      if (r > 255 || g > 255 || b > 255) return null;
      return Color.fromARGB(255, r, g, b);
    }

    if (text.startsWith('#')) text = text.substring(1);
    if (text.length == 3) {
      // `#abc` → `#aabbcc`
      text = text.split('').map((c) => '$c$c').join();
    }
    if (text.length == 6) text = 'FF$text';
    if (text.length != 8) return null;

    final value32 = int.tryParse(text, radix: 16);
    return value32 == null ? null : Color(value32);
  }

  static double? _double(Map<String, dynamic> json, List<String> keys) {
    final value = JsonReader.pick(json, keys);
    if (value == null) return null;
    if (value is num) return value.toDouble();
    final text = value.toString().trim().replaceAll('%', '');
    return text.isEmpty ? null : double.tryParse(text);
  }
}

/// Maps `GET /dashboard/live-enquiries`.
class LiveEnquiryMapper {
  const LiveEnquiryMapper._();

  static List<LiveEnquiry> listFrom(Object? body) {
    final records = JsonReader.records(
      body,
      keys: const ['enquiries', 'inquiries', 'items', 'data', 'results'],
    );

    return records
        .map(fromJson)
        .where((enquiry) => enquiry.id.isNotEmpty)
        .toList(growable: false);
  }

  static LiveEnquiry fromJson(Map<String, dynamic> json) {
    return LiveEnquiry(
      id: JsonReader.string(json, const ['id', '_id', 'enquiryId']) ?? '',
      name: JsonReader.string(json, const [
        'name',
        'fullName',
        'full_name',
        'studentName',
        'customerName',
      ]),
      email: JsonReader.string(json, const ['email', 'emailAddress']),
      phone: JsonReader.string(json, const [
        'phoneNumber',
        'phone_number',
        'phone',
        'mobile',
      ]),
      sport: JsonReader.string(json, const [
        'sport',
        'sportName',
        'sport_name',
        'interestedSport',
        'interest',
      ]),
      statusRaw: JsonReader.string(json, const ['status', 'enquiryStatus']),
      createdAt: JsonReader.date(json, const [
        'createdAt',
        'created_at',
        'date',
        'enquiryDate',
        'submittedAt',
      ]),
      timeAgoRaw: JsonReader.string(json, const [
        'timeAgo',
        'time_ago',
        'relativeTime',
      ]),
      avatarUrl: JsonReader.string(json, const [
        'avatar',
        'avatarUrl',
        'profilePicture',
        'profile_picture',
        'image',
      ]),
      raw: json,
    );
  }
}
