import 'admin_role.dart';
import 'employee_vocabulary.dart';

/// A security guard (`/admin/security-guards`).
///
/// Shaped like [Employee] deliberately — the two modules share their table,
/// form and password widgets' vocabulary — but a guard carries a licence number
/// and a patrol area instead of a department and a designation.
///
/// Every field is nullable so a thinner list payload is never padded with
/// invented values; the UI renders "—" for anything the server did not send.
class SecurityGuard {
  const SecurityGuard({
    required this.id,
    this.guardCode,
    this.fullName,
    this.email,
    this.phone,
    this.licenseNumber,
    this.assignedArea,
    this.sportComplexId,
    this.sportComplexName,
    this.sportComplexCity,
    this.shiftRaw,
    this.salary,
    this.statusRaw,
    this.joiningDate,
    this.raw = const {},
  });

  /// The database id, used in every `/admin/security-guards/{id}` call.
  final String id;

  /// The guard-facing badge number (`SG-204`) — a different thing from [id],
  /// and the two must never be swapped at a call site.
  final String? guardCode;

  final String? fullName;
  final String? email;
  final String? phone;

  /// The security licence the guard holds. Optional on the form and often
  /// absent from a list payload.
  final String? licenseNumber;

  /// The area of the complex this guard patrols — free text, because the API
  /// offers no enumeration of areas.
  final String? assignedArea;

  /// The posting as a known enum member, or null when the row holds something
  /// outside the vocabulary — a legacy value written before the column was
  /// constrained, for instance.
  AssignedArea? get area => AssignedArea.tryParse(assignedArea);

  /// Always renders: a known member by its own casing, an unknown value
  /// title-cased, and an em dash when there is nothing at all.
  String get assignedAreaLabel => AssignedArea.labelFor(assignedArea);

  final int? sportComplexId;
  final String? sportComplexName;
  final String? sportComplexCity;

  final String? shiftRaw;

  /// Kept as a number so the table can sort on it; formatted for display.
  final num? salary;

  final String? statusRaw;
  final DateTime? joiningDate;

  final Map<String, dynamic> raw;

  Shift? get shift => Shift.tryParse(shiftRaw);
  AdminUserStatus? get status => AdminUserStatus.tryParse(statusRaw);

  String get shiftLabel => Shift.labelFor(shiftRaw);
  String get statusLabel => status?.label ?? ((statusRaw ?? '').trim());

  String get displayName {
    final trimmed = (fullName ?? '').trim();
    if (trimmed.isNotEmpty) return trimmed;
    final mail = (email ?? '').trim();
    return mail.isEmpty ? 'Unnamed guard' : mail;
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

  /// Merges a detail read over the list row, keeping anything detail omitted.
  SecurityGuard mergedWith(SecurityGuard other) {
    return SecurityGuard(
      id: other.id.isEmpty ? id : other.id,
      guardCode: other.guardCode ?? guardCode,
      fullName: other.fullName ?? fullName,
      email: other.email ?? email,
      phone: other.phone ?? phone,
      licenseNumber: other.licenseNumber ?? licenseNumber,
      assignedArea: other.assignedArea ?? assignedArea,
      sportComplexId: other.sportComplexId ?? sportComplexId,
      sportComplexName: other.sportComplexName ?? sportComplexName,
      sportComplexCity: other.sportComplexCity ?? sportComplexCity,
      shiftRaw: other.shiftRaw ?? shiftRaw,
      salary: other.salary ?? salary,
      statusRaw: other.statusRaw ?? statusRaw,
      joiningDate: other.joiningDate ?? joiningDate,
      raw: {...raw, ...other.raw},
    );
  }

  @override
  String toString() =>
      'SecurityGuard($id, code: $guardCode, $fullName, $assignedArea/'
      '$shiftRaw, $statusRaw)';
}

/// The write payload for create and update.
class SecurityGuardDraft {
  const SecurityGuardDraft({
    this.fullName,
    this.email,
    this.phone,
    this.password,
    this.guardCode,
    this.licenseNumber,
    this.shift,
    this.assignedArea,
    this.joiningDate,
    this.salary,
    this.status,
    this.sportComplexId,
  });

  final String? fullName;
  final String? email;
  final String? phone;
  final String? password;
  final String? guardCode;
  final String? licenseNumber;
  final Shift? shift;
  final String? assignedArea;
  final DateTime? joiningDate;

  /// Kept as text: the payload documents `"salary": ""`, and the field is a
  /// free-text numeric input.
  final String? salary;

  final AdminUserStatus? status;
  final int? sportComplexId;

  /// `POST /admin/security-guards` — every documented key, in the documented
  /// shape.
  ///
  /// `status` is not in the documented payload but the Add form offers it, so
  /// it is sent alongside: a status the admin chose has to reach the server,
  /// and the sibling `/admin/employees` create accepts the same key.
  Map<String, dynamic> toCreateJson() {
    return <String, dynamic>{
      'fullName': (fullName ?? '').trim(),
      'email': (email ?? '').trim(),
      'phone': (phone ?? '').trim(),
      'password': password ?? '',
      'guardId': (guardCode ?? '').trim(),
      'licenseNumber': (licenseNumber ?? '').trim(),
      'shift': shift?.slug ?? '',
      'assignedArea': (assignedArea ?? '').trim(),
      'joiningDate': formatDate(joiningDate),
      'salary': (salary ?? '').trim(),
      'sportComplexId': sportComplexId,
      // New guards default to Active when the form left the dropdown alone.
      'status': (status ?? AdminUserStatus.active).slug,
    };
  }

  /// `PUT /admin/security-guards/{guardId}`.
  ///
  /// Only the five fields the API documents as editable, and only the ones that
  /// actually carry a value — so an edit never blanks a column the admin did
  /// not touch.
  Map<String, dynamic> toUpdateJson() {
    final body = <String, dynamic>{};

    void put(String key, Object? value) {
      if (value == null) return;
      if (value is String && value.trim().isEmpty) return;
      body[key] = value is String ? value.trim() : value;
    }

    put('fullName', fullName);
    put('phone', phone);
    put('shift', shift?.slug);
    put('assignedArea', assignedArea);
    put('status', status?.slug);

    return body;
  }

  /// `yyyy-MM-dd`, the shape a date-only API field expects.
  static String formatDate(DateTime? date) {
    if (date == null) return '';
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

/// What `GET /admin/security-guards/{guardId}/password` returns.
///
/// Deliberately not stored, cached or logged anywhere — it is read, shown in
/// a dialog, and dropped when that dialog closes.
class SecurityGuardCredentials {
  const SecurityGuardCredentials({this.email, this.password});

  final String? email;
  final String? password;

  bool get hasPassword => (password ?? '').trim().isNotEmpty;

  /// Never interpolates the password — this is what shows up in a log line if
  /// one of these is ever printed by accident.
  @override
  String toString() =>
      'SecurityGuardCredentials(email: $email, '
      'password: ${hasPassword ? '***' : 'none'})';
}
