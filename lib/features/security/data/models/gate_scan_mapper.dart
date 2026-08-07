import '../../../../core/network/api_response.dart';
import '../../../admin/domain/entities/paged.dart';
import '../../domain/entities/gate_scan.dart';

/// Reads the four gates' responses into one [GateScanResult].
///
/// No sample response was captured for the event or court scan routes, so every
/// field is read through an ordered list of candidate keys rather than one
/// hard-coded name — the same approach the rest of the console takes. A field
/// that cannot be read is simply absent from the card; nothing is invented, and
/// nothing crashes.
class GateScanMapper {
  const GateScanMapper._();

  /// The documented success shape is `{success, valid, direction}` with the
  /// pass details beside or below it. The verdict is decided in this order:
  ///
  ///  1. an explicit `valid: false` — a refusal however the HTTP call went;
  ///  2. `success: false` — likewise;
  ///  3. otherwise the direction decides the wording: In → Entry Granted,
  ///     Out → Exit Recorded.
  ///
  /// A 2xx whose body says nothing at all is treated as success, because that
  /// is what the scan endpoints do when a pass is accepted and they have
  /// nothing to add.
  static GateScanResult fromResponse(
    ApiResponse response, {
    required GateScanKind kind,
    required String passCode,
    GateDirection? direction,
  }) {
    final body = _body(response);
    final message = response.message ?? _text(body, const ['message', 'error']);

    final valid = _bool(body, const ['valid', 'isValid']);
    final success = response.isOk && _bool(body, const ['success']) != false;

    final resolvedDirection = GateDirection.tryParse(
          _text(body, const ['direction', 'scanType', 'scan_type']),
        ) ??
        direction;

    final refused = valid == false || !success;

    final outcome = refused
        ? GateScanOutcome.fromMessage(message, direction: resolvedDirection)
        : (resolvedDirection == GateDirection.outbound
              ? GateScanOutcome.exitRecorded
              : GateScanOutcome.granted);

    // The pass details can sit at the top level or under any of these.
    final details = _firstObject(body, const [
      'pass',
      'visitorPass',
      'eventPass',
      'booking',
      'member',
      'student',
      'data',
      'details',
    ]) ??
        body;

    return GateScanResult(
      kind: kind,
      outcome: outcome,
      passCode: _text(details, const ['passCode', 'pass_code', 'code']) ??
          _text(body, const ['passCode', 'pass_code', 'code']) ??
          passCode,
      at: DateTime.now(),
      direction: resolvedDirection,
      message: message,
      personName: _personName(details, kind),
      avatarUrl: _text(details, const [
        'avatar',
        'photo',
        'image',
        'profilePicture',
        'profile_picture',
      ]),
      facts: _facts(details, kind, resolvedDirection),
      raw: body,
    );
  }

  // ---------------------------------------------------------------------------
  // The details card
  // ---------------------------------------------------------------------------

  static String? _personName(Map<String, dynamic> json, GateScanKind kind) {
    return _text(json, switch (kind) {
      GateScanKind.visitor => const [
          'visitorName',
          'visitor_name',
          'name',
          'guestName',
        ],
      GateScanKind.event => const [
          'attendeeName',
          'memberName',
          'userName',
          'name',
          'bookedBy',
        ],
      GateScanKind.courtBooking => const [
          'memberName',
          'userName',
          'customerName',
          'name',
          'bookedBy',
        ],
      GateScanKind.coaching => const [
          'studentName',
          'student_name',
          'name',
        ],
    });
  }

  /// Everything worth showing about the pass, in the order a guard reads it.
  ///
  /// Each gate has its own list because they describe different things — a
  /// visitor has a purpose, a student has a batch and a blood group, a booking
  /// has a court and a slot.
  static List<GateScanFact> _facts(
    Map<String, dynamic> json,
    GateScanKind kind,
    GateDirection? direction,
  ) {
    final facts = <GateScanFact>[];

    void add(String label, List<String> keys, {bool emphasised = false}) {
      final value = _text(json, keys);
      if (value == null || value.isEmpty) return;
      facts.add(GateScanFact(label, value, emphasised: emphasised));
    }

    switch (kind) {
      case GateScanKind.visitor:
        add('Phone', const ['phoneNumber', 'phone_number', 'phone']);
        add('Purpose', const ['visitPurpose', 'visit_purpose', 'purpose']);
        add('Generated', const ['createdAt', 'created_at', 'generatedAt']);
        add('Check in', const ['entryTime', 'entry_time', 'checkInTime']);
        add('Check out', const ['exitTime', 'exit_time', 'checkOutTime']);
        add('Status', const ['status', 'passStatus'], emphasised: true);
        add('Issued by', const [
          'createdByName',
          'created_by_name',
          'issuedBy',
          'generatedBy',
        ]);
        add('Complex', const [
          'sportComplexName',
          'sport_complex_name',
          'complexName',
        ]);
      case GateScanKind.event:
        add('Event', const ['eventTitle', 'event_title', 'title', 'eventName']);
        add('Phone', const ['phoneNumber', 'phone_number', 'phone']);
        add('Persons', const ['totalPersons', 'persons', 'quantity', 'seats']);
        add('Venue', const ['venue', 'location', 'sportComplexName']);
        add('Event date', const ['eventDate', 'event_date', 'date']);
        add('Check in', const ['checkInTime', 'entryTime', 'scannedInAt']);
        add('Check out', const ['checkOutTime', 'exitTime', 'scannedOutAt']);
        add('Status', const ['status', 'scanStatus'], emphasised: true);
      case GateScanKind.courtBooking:
        add('Court', const ['courtName', 'court_name', 'court']);
        add('Sport', const ['sportName', 'sport_name', 'sport']);
        add('Phone', const ['phoneNumber', 'phone_number', 'phone']);
        add('Date', const ['bookingDate', 'booking_date', 'date']);
        add('Slot', const ['slot', 'timeSlot', 'startTime', 'time']);
        add('Persons', const ['totalPersons', 'persons', 'members']);
        add('Check in', const ['checkInTime', 'entryTime']);
        add('Check out', const ['checkOutTime', 'exitTime']);
        add('Status', const ['status', 'bookingStatus'], emphasised: true);
      case GateScanKind.coaching:
        add('Phone', const ['phone', 'phoneNumber', 'studentPhone']);
        add('Batch', const ['batchName', 'batch_name', 'batch']);
        add('Sport', const ['sportName', 'sport_name', 'sport']);
        add('Coach', const ['coachName', 'coach_name', 'coach']);
        add('Blood group', const ['bloodGroup', 'blood_group']);
        add('Date of birth', const ['dob', 'dateOfBirth', 'date_of_birth']);
        add('Marked at', const ['checkInTime', 'check_in_time', 'time']);
        add('Attendance', const [
          'attendance',
          'attendanceStatus',
          'status',
        ], emphasised: true);
    }

    if (direction != null) {
      facts.add(GateScanFact('Direction', direction.label));
    }

    return List<GateScanFact>.unmodifiable(facts);
  }

  // ---------------------------------------------------------------------------
  // Scan logs
  // ---------------------------------------------------------------------------

  static Paged<ScanLogEntry> logPageFrom(
    Object? data,
    {
    required int fallbackPage,
    required int fallbackLimit,
  }) {
    final body = data is Map ? Map<String, dynamic>.from(data) : null;
    final rows = _rowsIn(data);

    final items = rows
        .map(ScanLogEntry.fromJson)
        .toList(growable: false);

    final pagination = body == null
        ? null
        : _firstObject(body, const ['pagination', 'meta', 'paging']);

    int intFrom(List<String> keys, int fallback) {
      for (final source in [pagination, body]) {
        if (source == null) continue;
        for (final key in keys) {
          final value = source[key];
          if (value == null) continue;
          if (value is int) return value;
          final parsed = int.tryParse(value.toString());
          if (parsed != null) return parsed;
        }
      }
      return fallback;
    }

    return Paged<ScanLogEntry>(
      items: items,
      page: intFrom(const ['page', 'currentPage', 'current_page'], fallbackPage),
      limit: intFrom(const ['limit', 'perPage', 'per_page'], fallbackLimit),
      total: intFrom(const ['total', 'totalRecords', 'count'], items.length),
      totalPages: intFrom(const ['totalPages', 'total_pages', 'pages'], 0),
    );
  }

  /// The list of rows, wherever the envelope put it.
  static List<Map<String, dynamic>> _rowsIn(Object? data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
    }

    if (data is! Map) return const [];
    final body = Map<String, dynamic>.from(data);

    for (final key in const [
      'logs',
      'scanLogs',
      'scan_logs',
      'data',
      'items',
      'results',
      'records',
    ]) {
      final value = body[key];
      if (value is List) {
        return value
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList(growable: false);
      }
      // One more level: `{data: {logs: [...]}}`.
      if (value is Map) {
        final nested = _rowsIn(value);
        if (nested.isNotEmpty) return nested;
      }
    }

    return const [];
  }

  // ---------------------------------------------------------------------------
  // Readers — every one of them tolerates nulls and wrong types
  // ---------------------------------------------------------------------------

  static Map<String, dynamic> _body(ApiResponse response) {
    final payload = response.payload;
    if (payload.isNotEmpty) return payload;
    final data = response.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return const <String, dynamic>{};
  }

  static Map<String, dynamic>? _firstObject(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = json[key];
      if (value is Map && value.isNotEmpty) {
        return Map<String, dynamic>.from(value);
      }
    }
    return null;
  }

  static String? _text(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isEmpty || text.toLowerCase() == 'null') continue;
      return text;
    }
    return null;
  }

  /// Null when the key is absent — which is different from `false` and drives
  /// whether a scan counts as refused.
  static bool? _bool(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value == null) continue;
      if (value is bool) return value;
      if (value is num) return value != 0;
      final text = value.toString().toLowerCase();
      if (text == 'true' || text == '1') return true;
      if (text == 'false' || text == '0') return false;
    }
    return null;
  }
}