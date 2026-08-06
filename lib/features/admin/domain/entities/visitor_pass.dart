/// The lifecycle a visitor pass moves through.
///
/// A pass is issued [pending], the first successful scan puts it [checkedIn],
/// and the second puts it [checkedOut] — at which point it is spent and can
/// never be used again. [expired] and [invalid] are terminal states the server
/// reports; the app never invents them.
enum VisitorPassStatus {
  pending('Pending'),
  checkedIn('Checked In'),
  checkedOut('Checked Out'),
  expired('Expired'),
  invalid('Invalid');

  const VisitorPassStatus(this.label);

  /// How the status reads in a badge.
  final String label;

  /// Resolves whatever spelling the backend used onto a state.
  ///
  /// The module documents the five labels above, but a status field of this
  /// kind is written a dozen ways across a codebase (`CHECKED_IN`, `checked-in`,
  /// `IN`, `USED`, `COMPLETED`), so every form that unambiguously means one of
  /// these lands on it. Anything unrecognised returns null and is shown
  /// verbatim rather than being forced into the wrong bucket.
  static VisitorPassStatus? tryParse(Object? value) {
    if (value == null) return null;
    final normalised = value.toString().trim().toLowerCase().replaceAll(
      RegExp(r'[\s\-]+'),
      '_',
    );
    if (normalised.isEmpty) return null;

    switch (normalised) {
      case 'pending':
      case 'issued':
      case 'active':
      case 'new':
      case 'generated':
      case 'not_used':
        return VisitorPassStatus.pending;
      case 'checked_in':
      case 'checkedin':
      case 'check_in':
      case 'in':
      case 'entered':
      case 'inside':
        return VisitorPassStatus.checkedIn;
      case 'checked_out':
      case 'checkedout':
      case 'check_out':
      case 'out':
      case 'exited':
      case 'used':
      case 'completed':
      case 'closed':
        return VisitorPassStatus.checkedOut;
      case 'expired':
        return VisitorPassStatus.expired;
      case 'invalid':
      case 'cancelled':
      case 'canceled':
      case 'revoked':
      case 'rejected':
        return VisitorPassStatus.invalid;
    }
    return null;
  }
}

/// Which leg of the visit a scan records. The wire values are exactly `In` and
/// `Out` — the backend matches them case-sensitively.
enum VisitorScanType {
  checkIn('In', 'Check in'),
  checkOut('Out', 'Check out');

  const VisitorScanType(this.slug, this.label);

  /// The value sent as `scanType`.
  final String slug;

  final String label;

  static VisitorScanType? tryParse(Object? value) {
    if (value == null) return null;
    switch (value.toString().trim().toLowerCase()) {
      case 'in':
      case 'checkin':
      case 'check_in':
      case 'check-in':
        return VisitorScanType.checkIn;
      case 'out':
      case 'checkout':
      case 'check_out':
      case 'check-out':
        return VisitorScanType.checkOut;
    }
    return null;
  }
}

/// A visitor pass as the console shows it (`/visitor-passes`).
class VisitorPass {
  const VisitorPass({
    required this.id,
    this.passCode,
    this.visitorName,
    this.phoneNumber,
    this.visitPurpose,
    this.statusRaw,
    this.qrCode,
    this.entryTime,
    this.exitTime,
    this.sportComplexId,
    this.sportComplexName,
    this.createdByName,
    this.createdAt,
    this.raw = const {},
  });

  /// The numeric id. Zero when the row only carried a pass code — every route
  /// that takes an id also accepts the code, so [reference] is what to address
  /// the record with.
  final int id;

  final String? passCode;
  final String? visitorName;
  final String? phoneNumber;
  final String? visitPurpose;

  final String? statusRaw;

  /// Whatever the server sent for the QR: an absolute URL, a `data:` URI, a
  /// stored path, or the encoded payload itself. [VisitorPassQrView] decides
  /// how to render it, and falls back to generating one from [passCode].
  final String? qrCode;

  final DateTime? entryTime;
  final DateTime? exitTime;

  final int? sportComplexId;
  final String? sportComplexName;

  final String? createdByName;
  final DateTime? createdAt;

  /// The untouched row, so the detail panel can show a field the mapper has no
  /// name for yet rather than dropping it.
  final Map<String, dynamic> raw;

  /// What `/visitor-passes/{id}` and `/{id}/send-email` should address.
  String get reference {
    if (id > 0) return id.toString();
    return (passCode ?? '').trim();
  }

  bool get hasReference => reference.isNotEmpty;

  /// A stable key for list widgets, even for a row with neither id nor code.
  String get key => hasReference
      ? reference
      : '${visitorName ?? ''}|${phoneNumber ?? ''}|${createdAt ?? ''}';

  /// The status the server reported, falling back to what the timestamps imply.
  ///
  /// A row that carries an exit time is out whatever its status column says —
  /// and some list payloads omit the column entirely.
  VisitorPassStatus? get status {
    final parsed = VisitorPassStatus.tryParse(statusRaw);
    if (parsed != null) return parsed;
    if (exitTime != null) return VisitorPassStatus.checkedOut;
    if (entryTime != null) return VisitorPassStatus.checkedIn;
    if ((statusRaw ?? '').trim().isEmpty) return VisitorPassStatus.pending;
    return null;
  }

  String get statusLabel => status?.label ?? (statusRaw ?? '').trim();

  String get displayName {
    final name = (visitorName ?? '').trim();
    if (name.isNotEmpty) return name;
    final code = (passCode ?? '').trim();
    return code.isEmpty ? 'Visitor' : code;
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

  /// True once the visit is over. A checked-out pass is spent — the scanner
  /// refuses to send it again rather than letting the server reject it.
  bool get isSpent =>
      status == VisitorPassStatus.checkedOut ||
      status == VisitorPassStatus.expired ||
      status == VisitorPassStatus.invalid;

  bool get canCheckIn => status == VisitorPassStatus.pending;

  bool get canCheckOut => status == VisitorPassStatus.checkedIn;

  /// The scan this pass is waiting for, or null when it is waiting for none.
  VisitorScanType? get nextScan {
    if (canCheckIn) return VisitorScanType.checkIn;
    if (canCheckOut) return VisitorScanType.checkOut;
    return null;
  }

  /// True when the server sent something that can be rendered as a QR.
  bool get hasQrPayload =>
      (qrCode ?? '').trim().isNotEmpty || (passCode ?? '').trim().isNotEmpty;

  VisitorPass copyWith({
    int? id,
    String? passCode,
    String? visitorName,
    String? phoneNumber,
    String? visitPurpose,
    String? statusRaw,
    String? qrCode,
    DateTime? entryTime,
    DateTime? exitTime,
    int? sportComplexId,
    String? sportComplexName,
    String? createdByName,
    DateTime? createdAt,
    Map<String, dynamic>? raw,
  }) {
    return VisitorPass(
      id: id ?? this.id,
      passCode: passCode ?? this.passCode,
      visitorName: visitorName ?? this.visitorName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      visitPurpose: visitPurpose ?? this.visitPurpose,
      statusRaw: statusRaw ?? this.statusRaw,
      qrCode: qrCode ?? this.qrCode,
      entryTime: entryTime ?? this.entryTime,
      exitTime: exitTime ?? this.exitTime,
      sportComplexId: sportComplexId ?? this.sportComplexId,
      sportComplexName: sportComplexName ?? this.sportComplexName,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
      raw: raw ?? this.raw,
    );
  }

  /// The text shared over WhatsApp / the clipboard.
  String shareText({String? qrLink}) {
    final buffer = StringBuffer('Nahata Sports — Visitor Pass\n');
    buffer.writeln('Name: ${_orDash(visitorName)}');
    buffer.writeln('Phone: ${_orDash(phoneNumber)}');
    buffer.writeln('Purpose: ${_orDash(visitPurpose)}');
    buffer.writeln('Pass code: ${_orDash(passCode)}');
    if ((sportComplexName ?? '').trim().isNotEmpty) {
      buffer.writeln('Venue: ${sportComplexName!.trim()}');
    }
    buffer.writeln('Status: ${statusLabel.isEmpty ? '-' : statusLabel}');
    if (qrLink != null && qrLink.trim().isNotEmpty) {
      buffer.writeln('QR: ${qrLink.trim()}');
    }
    buffer.write('Show this pass at the gate for entry and exit.');
    return buffer.toString();
  }

  static String _orDash(String? value) {
    final trimmed = (value ?? '').trim();
    return trimmed.isEmpty ? '-' : trimmed;
  }

  @override
  String toString() =>
      'VisitorPass($id, ${passCode ?? '-'}, $visitorName, $statusRaw)';
}

/// The create payload for `POST /visitor-passes`.
class VisitorPassDraft {
  const VisitorPassDraft({
    required this.visitorName,
    required this.phoneNumber,
    required this.visitPurpose,
    required this.sportComplexId,
  });

  final String visitorName;
  final String phoneNumber;
  final String visitPurpose;
  final int? sportComplexId;

  /// Digits only — the field accepts formatting characters while typing, and
  /// the backend wants exactly ten digits.
  String get normalisedPhone => phoneNumber.replaceAll(RegExp(r'\D'), '');

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'visitorName': visitorName.trim(),
      'phoneNumber': normalisedPhone,
      'visitPurpose': visitPurpose.trim(),
      'sportComplexId': sportComplexId,
    };
  }
}

/// The outcome of a `/verify` or `/lookup` call.
///
/// A rejection is a result, not an absence of one: the desk still has to see
/// who the visitor is, what the pass's current state is and why the scan was
/// refused. Every failure path therefore produces one of these rather than
/// throwing past the UI.
class VisitorPassCheck {
  const VisitorPassCheck({
    required this.success,
    required this.readOnly,
    this.message,
    this.pass,
    this.scanType,
    this.valid,
  });

  /// True when the server accepted the call.
  final bool success;

  /// True for `/lookup`, which never changes the pass.
  final bool readOnly;

  /// The server's own message, shown verbatim — it carries the failure reason
  /// ("already checked out", "expired") the desk needs.
  final String? message;

  /// Whatever visitor details came back, on success or failure.
  final VisitorPass? pass;

  /// The leg that was attempted. Null for a lookup.
  final VisitorScanType? scanType;

  /// `/lookup`'s own valid flag, when it sends one. Falls back to the pass's
  /// status: a pass that can still be scanned is valid.
  final bool? valid;

  bool get isValid {
    final flag = valid;
    if (flag != null) return flag;
    final current = pass;
    if (current == null) return false;
    return !current.isSpent;
  }

  String get statusLabel => pass?.statusLabel ?? '';

  /// The headline for the result sheet.
  String get title {
    if (readOnly) {
      if (!success) return 'Pass not found';
      return isValid ? 'Valid pass' : 'Not usable';
    }
    if (success) {
      return scanType == VisitorScanType.checkOut
          ? 'Checked out'
          : 'Checked in';
    }
    return 'Scan refused';
  }

  @override
  String toString() =>
      'VisitorPassCheck(success: $success, readOnly: $readOnly, '
      'scan: ${scanType?.slug ?? '-'}, status: $statusLabel)';
}
