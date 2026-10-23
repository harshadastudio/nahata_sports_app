import 'employee_formats.dart';

/// A gate pass issued to a visitor, from `GET /visitor-passes`.
///
/// The lifecycle the gate drives is `Active → In → Out`; the desk only ever
/// creates a pass, emails it and deletes it. Scanning belongs to the security
/// console, so nothing here advances the status.
class EmployeeVisitorPass {
  const EmployeeVisitorPass({
    required this.id,
    this.passNumber = '',
    this.visitorName = '',
    this.phoneNumber = '',
    this.email,
    this.visitPurpose = 'Visit',
    this.status = 'Active',
    this.qrCode,
    this.validFrom,
    this.validUntil,
    this.checkInAt,
    this.checkOutAt,
    this.createdAt,
  });

  final int id;

  /// `VP-20260812-F1D246`. The lookup route accepts this in place of the
  /// numeric id, which is why it is worth keeping on the entity.
  final String passNumber;

  final String visitorName;
  final String phoneNumber;

  /// Where the pass was last emailed, when the row reported it. The generate
  /// call does not take an email — [EmployeeVisitorPassEmailDraft] does.
  final String? email;

  /// `Meeting` | `Delivery` | `Service` | `Visit` | `Other`.
  final String visitPurpose;

  /// Lower-case snake on the wire: `active` | `checked_in` | `checked_out` |
  /// `expired`. Compare through [isCheckedIn] / [isCheckedOut] rather than
  /// against a literal — the older `In` / `Out` spellings are still accepted.
  final String status;

  final String? qrCode;

  final DateTime? validFrom;
  final DateTime? validUntil;
  final DateTime? checkInAt;
  final DateTime? checkOutAt;
  final DateTime? createdAt;

  String get displayName =>
      visitorName.trim().isEmpty ? 'Visitor #$id' : visitorName.trim();

  String get initial =>
      displayName.trim().isEmpty ? '?' : displayName.trim()[0].toUpperCase();

  /// The pass number if there is one, else something stable to show in its
  /// place — a blank code column reads as a loading bug.
  String get displayCode =>
      passNumber.trim().isEmpty ? 'Pass #$id' : passNumber.trim();

  /// Both spellings are matched: the live route sends `checked_in`, while the
  /// scanner's own payloads use the bare `In`.
  bool get isCheckedIn => _is(const ['in', 'checkedin', 'checked_in']);
  bool get isCheckedOut => _is(const ['out', 'checkedout', 'checked_out']);

  bool _is(List<String> names) => names.contains(status.trim().toLowerCase());

  /// `checked_out` → `Checked out`. The raw wire value in a status chip reads
  /// as a bug rather than a state.
  String get displayStatus {
    final text = status.trim();
    if (text.isEmpty) return 'Unknown';
    final words = text.replaceAll('_', ' ').toLowerCase();
    return words[0].toUpperCase() + words.substring(1);
  }

  /// True when the server says so, or when the pass has an end date that has
  /// passed. An absent end date is not an expiry.
  bool get isExpired {
    if (status.trim().toLowerCase() == 'expired') return true;
    final end = validUntil;
    if (end == null) return false;
    return end.isBefore(DateTime.now());
  }

  String get issuedLabel => formatDateTime(createdAt);

  /// `In 2:30 PM · Out 4:10 PM`, or null when the gate has not scanned it.
  String? get movementLabel {
    final parts = <String>[
      if (checkInAt != null) 'In ${formatDateTime(checkInAt)}',
      if (checkOutAt != null) 'Out ${formatDateTime(checkOutAt)}',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  String toString() => 'EmployeeVisitorPass($id, $displayCode, $status)';
}

/// The body of `POST /visitor-passes`.
class EmployeeVisitorPassDraft {
  const EmployeeVisitorPassDraft({
    this.visitorName = '',
    this.phoneNumber = '',
    this.visitPurpose = 'Visit',
  });

  final String visitorName;
  final String phoneNumber;
  final String visitPurpose;

  static const List<String> purposes = [
    'Meeting',
    'Delivery',
    'Service',
    'Visit',
    'Other',
  ];

  String? get validationError {
    if (visitorName.trim().isEmpty) return "Enter the visitor's name.";

    final digits = phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) return 'Enter a 10-digit phone number.';

    return null;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'visitorName': visitorName.trim(),
        'phoneNumber': phoneNumber.trim(),
        'visitPurpose': visitPurpose,
      };
}

/// The body of `POST /visitor-passes/{id}/send-email`.
///
/// The address is free-form on purpose: the route emails the pass and its QR
/// code to whoever is named, which is not necessarily the visitor — a host
/// forwarding it to their guest is the common case.
class EmployeeVisitorPassEmailDraft {
  const EmployeeVisitorPassEmailDraft({required this.email});

  final String email;

  /// Deliberately loose. The server is the authority on deliverability; this
  /// only catches the empty box and the obvious typo before a round trip.
  bool get isValid {
    final text = email.trim();
    if (text.isEmpty) return false;
    return RegExp(r'^[^@\s]+@[^@\s.]+\.[^@\s]+$').hasMatch(text);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{'email': email.trim()};
}
