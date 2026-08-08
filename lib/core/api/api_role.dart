import '../services/app_session.dart';

/// The roles the API distinguishes between.
///
/// One login (`POST /auth/login`), one token store, one `Authorization: Bearer`
/// header — the role only decides *which* route a module calls, what the
/// sidebar shows, and how far the data reaches. It is never a second auth
/// system.
///
/// `data.user.role` is matched case- and separator-insensitively, so
/// `COMPLEX_ADMIN`, `complex-admin` and `Complex Admin` all resolve to
/// [ApiRole.complexAdmin].
enum ApiRole {
  admin('ADMIN'),
  complexAdmin('COMPLEX_ADMIN'),
  coach('COACH'),
  employee('EMPLOYEE'),
  security('SECURITY'),

  /// A customer account, and the fallback for an unknown role string.
  user('USER');

  const ApiRole(this.wire);

  /// The spelling the backend uses — also what the API trace prints.
  final String wire;

  /// Normalises the way [RoleRouter] does: lower case, separators collapsed to
  /// `_`. Kept in step deliberately, so routing and API mapping can never
  /// disagree about what role is signed in.
  static String normalise(String? role) =>
      (role ?? '').trim().toLowerCase().replaceAll(RegExp(r'[-\s]+'), '_');

  /// [ApiRole] for a raw role string. Unknown, empty and null all answer
  /// [ApiRole.user] — the least-privileged option, never an admin.
  static ApiRole fromRole(String? role) {
    switch (normalise(role)) {
      case 'admin':
      case 'super_admin':
      case 'superadmin':
        return ApiRole.admin;
      case 'complex_admin':
        return ApiRole.complexAdmin;
      case 'coach':
        return ApiRole.coach;
      case 'employee':
        return ApiRole.employee;
      case 'security':
      case 'security_guard':
        return ApiRole.security;
      default:
        return ApiRole.user;
    }
  }

  /// The signed-in account's role, read from the live session.
  static ApiRole get current => fromRole(AppSession.instance.role);

  bool get isAdmin => this == ApiRole.admin;
  bool get isComplexAdmin => this == ApiRole.complexAdmin;

  /// True for the two roles the admin console serves.
  bool get isAdministrative => isAdmin || isComplexAdmin;
}