import 'admin_role.dart';
import 'employee_vocabulary.dart';

/// A staff member (`/admin/employees`).
///
/// Every field is nullable so a thinner list payload is never padded with
/// invented values; the UI renders "—" for anything the server did not send.
class Employee {
  const Employee({
    required this.id,
    this.employeeCode,
    this.fullName,
    this.email,
    this.phone,
    this.sportComplexId,
    this.sportComplexName,
    this.departmentRaw,
    this.designationRaw,
    this.shiftRaw,
    this.salary,
    this.statusRaw,
    this.joiningDate,
    this.address,
    this.raw = const {},
  });

  /// The database id, used in every `/admin/employees/{id}` call.
  final String id;

  /// The human-facing staff number (`NS-1042`) — a different thing from [id],
  /// and the two must never be swapped at a call site.
  final String? employeeCode;

  final String? fullName;
  final String? email;
  final String? phone;

  final int? sportComplexId;
  final String? sportComplexName;

  final String? departmentRaw;
  final String? designationRaw;
  final String? shiftRaw;

  /// Kept as a number so the table can sort on it; formatted for display.
  final num? salary;

  final String? statusRaw;
  final DateTime? joiningDate;
  final String? address;

  final Map<String, dynamic> raw;

  Department? get department => Department.tryParse(departmentRaw);
  Designation? get designation => Designation.tryParse(designationRaw);
  Shift? get shift => Shift.tryParse(shiftRaw);
  AdminUserStatus? get status => AdminUserStatus.tryParse(statusRaw);

  String get departmentLabel => Department.labelFor(departmentRaw);
  String get designationLabel => Designation.labelFor(designationRaw);
  String get shiftLabel => Shift.labelFor(shiftRaw);
  String get statusLabel => status?.label ?? ((statusRaw ?? '').trim());

  String get displayName {
    final trimmed = (fullName ?? '').trim();
    if (trimmed.isNotEmpty) return trimmed;
    final mail = (email ?? '').trim();
    return mail.isEmpty ? 'Unnamed employee' : mail;
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
  Employee mergedWith(Employee other) {
    return Employee(
      id: other.id.isEmpty ? id : other.id,
      employeeCode: other.employeeCode ?? employeeCode,
      fullName: other.fullName ?? fullName,
      email: other.email ?? email,
      phone: other.phone ?? phone,
      sportComplexId: other.sportComplexId ?? sportComplexId,
      sportComplexName: other.sportComplexName ?? sportComplexName,
      departmentRaw: other.departmentRaw ?? departmentRaw,
      designationRaw: other.designationRaw ?? designationRaw,
      shiftRaw: other.shiftRaw ?? shiftRaw,
      salary: other.salary ?? salary,
      statusRaw: other.statusRaw ?? statusRaw,
      joiningDate: other.joiningDate ?? joiningDate,
      address: other.address ?? address,
      raw: {...raw, ...other.raw},
    );
  }

  @override
  String toString() =>
      'Employee($id, code: $employeeCode, $fullName, $departmentRaw/'
      '$designationRaw, $statusRaw)';
}

/// The write payload for create and update.
class EmployeeDraft {
  const EmployeeDraft({
    this.fullName,
    this.email,
    this.phone,
    this.password,
    this.employeeCode,
    this.department,
    this.designation,
    this.joiningDate,
    this.salary,
    this.shift,
    this.status,
    this.sportComplexId,
    this.address,
  });

  final String? fullName;
  final String? email;
  final String? phone;
  final String? password;
  final String? employeeCode;
  final Department? department;
  final Designation? designation;
  final DateTime? joiningDate;

  /// Kept as text: the payload documents `"salary": ""`, and the field is a
  /// free-text numeric input.
  final String? salary;

  final Shift? shift;
  final AdminUserStatus? status;
  final int? sportComplexId;
  final String? address;

  /// `POST /admin/employees` — every documented key, in the documented shape.
  Map<String, dynamic> toCreateJson() {
    return <String, dynamic>{
      'fullName': (fullName ?? '').trim(),
      'email': (email ?? '').trim(),
      'phone': (phone ?? '').trim(),
      'password': password ?? '',
      'employeeId': (employeeCode ?? '').trim(),
      'department': department?.slug ?? '',
      'designation': designation?.slug ?? '',
      'joiningDate': formatDate(joiningDate),
      'salary': (salary ?? '').trim(),
      'shift': shift?.slug ?? '',
      // The payload pins new employees to Active.
      'status': (status ?? AdminUserStatus.active).slug,
      'sportComplexId': sportComplexId,
      'address': (address ?? '').trim(),
    };
  }

  /// `PUT /admin/employees/{id}` — only what changed, so an edit never blanks
  /// a column the admin did not touch. Address is the exception: it is
  /// legitimately clearable, so an explicitly empty string is sent.
  Map<String, dynamic> toUpdateJson({bool clearAddress = false}) {
    final body = <String, dynamic>{};

    void put(String key, Object? value) {
      if (value == null) return;
      if (value is String && value.trim().isEmpty) return;
      body[key] = value is String ? value.trim() : value;
    }

    put('fullName', fullName);
    put('phone', phone);
    put('department', department?.slug);
    put('designation', designation?.slug);
    put('shift', shift?.slug);
    put('salary', salary);
    put('status', status?.slug);
    put('sportComplexId', sportComplexId);

    if (clearAddress) {
      body['address'] = '';
    } else {
      put('address', address);
    }

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

/// What `GET /admin/employees/{id}/password` returns.
///
/// Deliberately not stored, cached or logged anywhere — it is read, shown in
/// a dialog, and dropped when that dialog closes.
class EmployeeCredentials {
  const EmployeeCredentials({this.email, this.password});

  final String? email;
  final String? password;

  bool get hasPassword => (password ?? '').trim().isNotEmpty;

  /// Never interpolates the password — this is what shows up in a log line if
  /// one of these is ever printed by accident.
  @override
  String toString() =>
      'EmployeeCredentials(email: $email, password: ${hasPassword ? '***' : 'none'})';
}
