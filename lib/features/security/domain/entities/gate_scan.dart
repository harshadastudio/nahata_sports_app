import 'package:flutter/foundation.dart';

/// Which gate a scan belongs to.
///
/// The four modules hit four different routes with four different response
/// shapes, but a guard at a gate does the same thing with all of them: present
/// a code, read a verdict, let somebody through or not. Everything below is
/// built around that, so one scanner, one result sheet and one activity feed
/// serve all four.
enum GateScanKind {
  visitor('Visitor Pass', 'Visitor'),
  event('Event Pass', 'Event'),
  courtBooking('Court Booking', 'Booking'),
  coaching('Coaching Pass', 'Coaching');

  const GateScanKind(this.label, this.shortLabel);

  final String label;
  final String shortLabel;
}

/// Which leg of a visit a scan records.
enum GateDirection {
  inbound('In', 'Check in'),
  outbound('Out', 'Check out');

  const GateDirection(this.slug, this.label);

  /// The value sent as `scanType`. The backend matches it case-sensitively.
  final String slug;

  final String label;

  static GateDirection? tryParse(Object? value) {
    final text = value?.toString().trim().toLowerCase();
    if (text == null || text.isEmpty) return null;
    if (text.startsWith('in')) return GateDirection.inbound;
    if (text.startsWith('out')) return GateDirection.outbound;
    return null;
  }
}

/// What the gate should do about a scan.
///
/// Four of these are refusals and three of those are *soft* — the pass is real,
/// it simply cannot be used for this leg right now. A guard needs to tell that
/// apart from a forged or unknown code, which is why "already checked in" is
/// not lumped in with "invalid".
enum GateScanOutcome {
  /// The visitor may enter.
  granted('Entry Granted', GateScanSeverity.success),

  /// The visitor has left; for most passes this spends the pass for good.
  exitRecorded('Exit Recorded', GateScanSeverity.success),

  alreadyCheckedIn('Already Checked In', GateScanSeverity.warning),
  alreadyCheckedOut('Already Checked Out', GateScanSeverity.warning),
  duplicate('Duplicate Scan', GateScanSeverity.warning),
  expired('Expired Pass', GateScanSeverity.warning),
  cancelled('Booking Cancelled', GateScanSeverity.danger),

  /// The code is not a pass this system knows.
  invalid('Invalid QR', GateScanSeverity.danger),

  /// The call itself failed — network, timeout, 500. Distinct from a refusal:
  /// nothing is known about the pass, so nobody should be let through on it.
  error('Scan Failed', GateScanSeverity.danger);

  const GateScanOutcome(this.label, this.severity);

  final String label;
  final GateScanSeverity severity;

  bool get isSuccess => severity == GateScanSeverity.success;

  /// True when the pass exists but this scan changed nothing.
  bool get isSoftRefusal => severity == GateScanSeverity.warning;

  bool get isFailure => severity == GateScanSeverity.danger;

  /// Reads the backend's own words when it sends no machine-readable status.
  ///
  /// Every module phrases refusals in prose ("Pass already used", "This
  /// booking was cancelled"), so the message is matched against the phrases
  /// they actually use. Anything unrecognised stays [invalid] rather than
  /// being guessed into a friendlier bucket — at a gate, an unclear answer is a
  /// refusal.
  static GateScanOutcome fromMessage(
    String? message, {
    GateDirection? direction,
    GateScanOutcome fallback = GateScanOutcome.invalid,
  }) {
    final text = (message ?? '').toLowerCase();
    if (text.isEmpty) return fallback;

    if (text.contains('cancel')) return GateScanOutcome.cancelled;
    if (text.contains('expire')) return GateScanOutcome.expired;

    final saysAlready = text.contains('already') || text.contains('duplicate');
    if (saysAlready) {
      if (text.contains('out') || text.contains('exit')) {
        return GateScanOutcome.alreadyCheckedOut;
      }
      if (text.contains('in') || text.contains('enter')) {
        return GateScanOutcome.alreadyCheckedIn;
      }
      return GateScanOutcome.duplicate;
    }

    if (text.contains('not found') ||
        text.contains('invalid') ||
        text.contains('no pass')) {
      return GateScanOutcome.invalid;
    }

    return fallback;
  }
}

/// Drives the colour of every scan surface: green, orange, red.
enum GateScanSeverity { success, warning, danger }

/// One labelled fact about a pass, for the details card.
///
/// Deliberately a list of pairs rather than a fixed schema: the four modules
/// return different fields, and a guard wants to see whatever the backend
/// actually sent about the person in front of them, not a fixed form with
/// blanks in it.
@immutable
class GateScanFact {
  const GateScanFact(this.label, this.value, {this.emphasised = false});

  final String label;
  final String value;

  /// Rendered larger — the name, the status.
  final bool emphasised;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GateScanFact &&
          other.label == label &&
          other.value == value &&
          other.emphasised == emphasised);

  @override
  int get hashCode => Object.hash(label, value, emphasised);
}

/// The verdict on one scan, whatever gate it came from.
@immutable
class GateScanResult {
  const GateScanResult({
    required this.kind,
    required this.outcome,
    required this.passCode,
    required this.at,
    this.direction,
    this.message,
    this.title,
    this.personName,
    this.avatarUrl,
    this.facts = const [],
    this.raw = const {},
  });

  final GateScanKind kind;
  final GateScanOutcome outcome;

  /// The code as the backend echoed it back, or as it was scanned.
  final String passCode;

  /// When the scan happened, on this device — used to order the activity feed.
  final DateTime at;

  final GateDirection? direction;

  /// The server's own sentence. Shown verbatim: it carries the reason a guard
  /// has to be able to repeat to the person at the gate.
  final String? message;

  /// Overrides the outcome's own headline when the backend phrased it better.
  final String? title;

  final String? personName;
  final String? avatarUrl;

  /// Everything worth showing about the pass, in display order.
  final List<GateScanFact> facts;

  /// The untouched payload, so a field the mapper has no name for yet is
  /// available rather than lost.
  final Map<String, dynamic> raw;

  bool get isSuccess => outcome.isSuccess;
  GateScanSeverity get severity => outcome.severity;

  /// The headline on the result sheet.
  String get headline {
    final custom = (title ?? '').trim();
    if (custom.isNotEmpty) return custom;
    if (outcome == GateScanOutcome.invalid) return 'Invalid ${kind.label}';
    return outcome.label;
  }

  String get displayName {
    final name = (personName ?? '').trim();
    return name.isEmpty ? kind.label : name;
  }

  /// A failure built from an exception, so a thrown call still produces
  /// something the gate can show and the activity feed can record.
  factory GateScanResult.failure({
    required GateScanKind kind,
    required String passCode,
    required String message,
    GateDirection? direction,
    GateScanOutcome outcome = GateScanOutcome.error,
    DateTime? at,
  }) {
    return GateScanResult(
      kind: kind,
      outcome: outcome,
      passCode: passCode,
      at: at ?? DateTime.now(),
      direction: direction,
      message: message,
    );
  }
}

/// The six counters `/…/scan-stats` returns, for the event and court gates.
@immutable
class ScanStats {
  const ScanStats({
    this.totalPasses = 0,
    this.totalPersons = 0,
    this.inCount = 0,
    this.outCount = 0,
    this.notScanned = 0,
    this.currentlyInside = 0,
  });

  static const ScanStats empty = ScanStats();

  final int totalPasses;
  final int totalPersons;

  /// Scanned in — the API's `in`, which is a Dart keyword.
  final int inCount;

  /// Scanned out — the API's `out`.
  final int outCount;

  final int notScanned;
  final int currentlyInside;

  bool get isEmpty =>
      totalPasses == 0 &&
      totalPersons == 0 &&
      inCount == 0 &&
      outCount == 0 &&
      notScanned == 0 &&
      currentlyInside == 0;

  factory ScanStats.fromJson(Map<String, dynamic> json) {
    int read(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value == null) continue;
        if (value is int) return value;
        if (value is num) return value.toInt();
        final parsed = int.tryParse(value.toString());
        if (parsed != null) return parsed;
      }
      return 0;
    }

    return ScanStats(
      totalPasses: read(const ['totalPasses', 'total_passes', 'total']),
      totalPersons: read(const ['totalPersons', 'total_persons', 'persons']),
      inCount: read(const ['in', 'inCount', 'checkedIn', 'checked_in']),
      outCount: read(const ['out', 'outCount', 'checkedOut', 'checked_out']),
      notScanned: read(const ['notScanned', 'not_scanned', 'pending']),
      currentlyInside: read(const [
        'currentlyInside',
        'currently_inside',
        'inside',
      ]),
    );
  }
}

/// One row of `GET /fees/scan-logs`.
@immutable
class ScanLogEntry {
  const ScanLogEntry({
    this.id,
    this.studentName = '',
    this.phone = '',
    this.batchName = '',
    this.passCode = '',
    this.scannerName = '',
    this.scannerRole = '',
    this.attendance = '',
    this.scannedAt,
    this.raw = const {},
  });

  final int? id;
  final String studentName;
  final String phone;
  final String batchName;
  final String passCode;
  final String scannerName;
  final String scannerRole;

  /// "Present", "Absent" — shown verbatim.
  final String attendance;

  final DateTime? scannedAt;
  final Map<String, dynamic> raw;

  String get displayName =>
      studentName.trim().isEmpty ? 'Student' : studentName.trim();

  /// "14:05" — the time is what a log is read for; the date is the filter.
  String get timeLabel {
    final at = scannedAt;
    if (at == null) return '—';
    return '${at.hour.toString().padLeft(2, '0')}:'
        '${at.minute.toString().padLeft(2, '0')}';
  }

  factory ScanLogEntry.fromJson(Map<String, dynamic> json) {
    String text(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        final trimmed = value?.toString().trim() ?? '';
        if (trimmed.isNotEmpty && trimmed.toLowerCase() != 'null') {
          return trimmed;
        }
      }
      return '';
    }

    final rawId = json['id'];

    return ScanLogEntry(
      id: rawId is int ? rawId : int.tryParse(rawId?.toString() ?? ''),
      studentName: text(const [
        'studentName',
        'student_name',
        'name',
        'student',
      ]),
      phone: text(const ['phone', 'phoneNumber', 'phone_number', 'mobile']),
      batchName: text(const ['batchName', 'batch_name', 'batch']),
      passCode: text(const ['passCode', 'pass_code', 'gatePass', 'code']),
      scannerName: text(const [
        'scannerName',
        'scanner_name',
        'scannedBy',
        'scanned_by',
        'scanner',
      ]),
      scannerRole: text(const ['scannerRole', 'scanner_role', 'role']),
      attendance: text(const ['attendance', 'status', 'attendanceStatus']),
      scannedAt: _parseDate(
        text(const [
          'scannedAt',
          'scanned_at',
          'createdAt',
          'created_at',
          'time',
          'checkInTime',
          'check_in_time',
        ]),
        fallbackDate: text(const ['date']),
      ),
      raw: json,
    );
  }

  /// Accepts a full timestamp, or a bare `HH:mm:ss` paired with the row's
  /// `date` — the logs endpoint has been seen sending both.
  static DateTime? _parseDate(String value, {String fallbackDate = ''}) {
    if (value.isEmpty) return null;

    final direct = DateTime.tryParse(value);
    if (direct != null) return direct.toLocal();

    if (fallbackDate.isNotEmpty) {
      final combined = DateTime.tryParse('${fallbackDate}T$value');
      if (combined != null) return combined.toLocal();
    }

    // A bare clock time with no date at all: assume today, which is what the
    // log is filtered to anyway.
    final parts = value.split(':');
    if (parts.length >= 2) {
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour != null && minute != null) {
        final now = DateTime.now();
        return DateTime(now.year, now.month, now.day, hour, minute);
      }
    }

    return null;
  }
}