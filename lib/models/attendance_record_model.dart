import 'package:intl/intl.dart';

/// One row of `GET /attendance/my` — a session the signed-in student was
/// marked for.
///
/// Every field is nullable because the endpoint sends `null` for anything not
/// recorded: `checkOutTime` and `notes` are routinely absent, and a row is
/// still worth showing without them.
class AttendanceRecord {
  const AttendanceRecord({
    this.id,
    this.date,
    this.sport,
    this.batch,
    this.status,
    this.checkInTime,
    this.checkOutTime,
    this.notes,
  });

  final int? id;

  /// ISO day, `"2026-08-06"`.
  final String? date;
  final String? sport;
  final String? batch;

  /// `"Present"`, `"Absent"`, `"Late"` — whatever the coach marked.
  final String? status;

  /// Wall-clock times, `"12:30:24"`.
  final String? checkInTime;
  final String? checkOutTime;

  final String? notes;

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? ''),
      date: _text(json['date']),
      sport: _text(json['sport']),
      batch: _text(json['batch']),
      status: _text(json['status']),
      checkInTime: _text(json['checkInTime'] ?? json['check_in_time']),
      checkOutTime: _text(json['checkOutTime'] ?? json['check_out_time']),
      notes: _text(json['notes']),
    );
  }

  DateTime? get day => DateTime.tryParse(date ?? '');

  /// `"6 Aug 2026"`, or the raw value when it will not parse — an unexpected
  /// format is still more use on screen than a blank.
  String get dateLabel {
    final parsed = day;
    if (parsed == null) return date ?? '';
    return DateFormat('d MMM yyyy').format(parsed);
  }

  /// `"Basketball · Regular (Evening)"`, dropping whichever half is missing.
  String get sessionLabel =>
      [sport, batch].where((v) => v != null && v.isNotEmpty).join(' · ');

  /// `"12:30 PM"` from `"12:30:24"`. Null when there is no check-in.
  String? get checkInLabel => _timeLabel(checkInTime);

  String? get checkOutLabel => _timeLabel(checkOutTime);

  bool get isPresent {
    final value = (status ?? '').toLowerCase();
    return value == 'present' || value == 'late';
  }

  bool get isAbsent => (status ?? '').toLowerCase() == 'absent';

  static String? _timeLabel(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;

    final parts = value.split(':');
    if (parts.length < 2) return value;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return value;

    // A fixed date: only the clock face matters, and DateFormat needs one.
    return DateFormat('h:mm a').format(DateTime(2000, 1, 1, hour, minute));
  }

  static String? _text(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text == 'null') return null;
    return text;
  }
}
