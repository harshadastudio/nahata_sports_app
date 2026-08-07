import 'employee_formats.dart';

/// An app user, from `GET /admin/users`.
///
/// Despite the `/admin` prefix the list and the single update grant EMPLOYEE —
/// the desk needs to correct a phone number or block an account without
/// escalating. Creating and deleting users do **not**, so the app offers view
/// and edit only, matching the website.
///
/// ⚠️ `role` is sent back in the backend's own casing (`USER`, `COACH`,
/// `SECURITY`) and the update echoes whatever it is given, so an edit must
/// round-trip the value it received rather than a prettified label.
class EmployeeUser {
  const EmployeeUser({
    required this.id,
    this.name = '',
    this.email = '',
    this.phoneNumber = '',
    this.role = 'USER',
    this.status = 'Active',
    this.membershipType,
    this.totalBookings = 0,
    this.joinDate,
    this.lastActive,
    this.avatar,
  });

  /// String rather than int: the list sends numeric ids but the route accepts
  /// either, and nothing here does arithmetic on it.
  final Object id;

  final String name;
  final String email;
  final String phoneNumber;

  /// `USER` | `ADMIN` | `EMPLOYEE` | `COACH` | `SECURITY`, in backend casing.
  final String role;

  /// `Active` | `Blocked`.
  final String status;

  final String? membershipType;
  final int totalBookings;

  /// Already-formatted strings on this route, not timestamps.
  final String? joinDate;
  final String? lastActive;

  final String? avatar;

  String get displayName => name.trim().isEmpty ? 'User' : name.trim();

  String get initial =>
      displayName.trim().isEmpty ? '?' : displayName.trim()[0].toUpperCase();

  bool get isActive => status.toLowerCase() == 'active';

  /// `User`, `Coach`, `Security` — the backend's `SECURITY_GUARD` spelling is
  /// normalised here so the two never appear side by side in a list.
  String get roleLabel {
    final raw = role.trim().replaceAll('_', ' ').toLowerCase();
    if (raw.isEmpty) return 'User';
    return raw
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  EmployeeUser copyWith({
    String? name,
    String? email,
    String? phoneNumber,
    String? status,
    String? membershipType,
  }) {
    return EmployeeUser(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role,
      status: status ?? this.status,
      membershipType: membershipType ?? this.membershipType,
      totalBookings: totalBookings,
      joinDate: joinDate,
      lastActive: lastActive,
      avatar: avatar,
    );
  }

  @override
  String toString() => 'EmployeeUser($id, $displayName, $status)';
}

/// The membership tiers the edit form offers. Fixed on the website too — there
/// is no endpoint that lists them.
const List<String> employeeMembershipTypes = [
  'Basic',
  'Premium',
  'VIP',
  'Corporate',
];

/// The two account states an employee may set.
const List<String> employeeUserStatuses = ['Active', 'Blocked'];

/// The body `PUT /admin/users/{id}` expects — snake_case for the two fields
/// that map straight onto columns, camelCase for nothing. Getting this wrong
/// silently no-ops the field rather than erroring.
Map<String, dynamic> employeeUserUpdateBody({
  required String name,
  required String phoneNumber,
  required String email,
  required String role,
  required String membershipType,
  required String status,
}) {
  return {
    'name': name.trim(),
    'phone_number': phoneNumber.trim(),
    'email': email.trim(),
    'role': role.trim().toUpperCase(),
    'membership_type': membershipType,
    'status': status,
  };
}

/// Re-exported so pages can format a user's dates without a second import.
String formatUserDate(DateTime? value) => formatDay(value);
