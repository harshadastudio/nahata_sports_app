import 'package:flutter/material.dart';

import '../../bottombar/Custombottombar.dart';
import '../../dashboard/admin_screen.dart';
import '../../dashboard/coach_screen.dart';
import '../../features/complex_admin/presentation/pages/complex_admin_dashboard_page.dart';
import '../../features/security/presentation/pages/security_console_screen.dart';
import '../services/app_session.dart';
import 'security_routes.dart';
import '../../features/employee/presentation/pages/employee_home_page.dart';

/// Turns `data.user.role` into the screen that role starts on.
///
/// One implementation for every entry point — the login screen, the Google and
/// Apple sign-in buttons, and the splash screen's session restore — so a role
/// can never be routed correctly from one place and incorrectly from another.
///
/// Routing is decided **solely** by the role string:
///
/// | role           | screen                        |
/// |----------------|-------------------------------|
/// | `ADMIN`        | `AdminDashboardScreen`        |
/// | `COMPLEX_ADMIN`| `ComplexAdminDashboardScreen` |
/// | `COACH`        | `CoachHomeScreen`             |
/// | `SECURITY`     | `SecurityConsoleScreen`       |
/// | `EMPLOYEE`     | `EmployeeHomeScreen`          |
/// | `SECURITY`     | `SecurityGateScannerScreen`   |
/// | anything else  | `CustomBottomNav` (student)   |
class RoleRouter {
  const RoleRouter._();

  /// Case- and spelling-insensitive: `COMPLEX_ADMIN`, `complex-admin` and
  /// `Complex Admin` all normalise to `complex_admin`.
  static String normalise(String? role) =>
      (role ?? '').trim().toLowerCase().replaceAll(RegExp(r'[-\s]+'), '_');

  static bool isComplexAdmin(String? role) =>
      normalise(role) == 'complex_admin';

  /// The roles allowed inside the security console.
  ///
  /// A guard sees only the gate; an admin and a complex admin reach the same
  /// screens through their own console. Anyone else — a student, a coach — is
  /// refused, which is what [canOpenSecurity] is checked for before a
  /// `/security/*` route is opened.
  static const Set<String> securityRoles = {
    'security',
    'admin',
    'super_admin',
    'superadmin',
    'complex_admin',
  };

  /// Whether [role] may open a security route. Defaults to the signed-in
  /// account when no role is passed.
  static bool canOpenSecurity([String? role]) {
    final key = normalise(role ?? AppSession.instance.role);
    return securityRoles.contains(key);
  }

  /// Guards a `/security/*` path: the screen when the account is allowed in,
  /// null when it is not, so the caller can refuse rather than render.
  static Widget? securityScreenFor(String route, {String? role}) {
    if (!SecurityRoutes.owns(route) || !canOpenSecurity(role)) return null;
    return SecurityConsoleScreen(
      initialSection: SecuritySection.fromRoute(route),
    );
  }

  /// The landing screen for [role]. Null, empty or unknown roles fall back to
  /// the student app, which is what an ordinary user account gets.
  static Widget screenFor(String? role) {
    switch (normalise(role)) {
      case 'admin':
      case 'super_admin':
      case 'superadmin':
        return const AdminDashboardScreen();
      case 'complex_admin':
        return const ComplexAdminDashboardScreen();
      case 'coach':
        return const CoachHomeScreen();
      case 'employee':
        return const EmployeeHomeScreen();
      case 'security':
        // `/security/dashboard`: the guard console — eight live counters, the
        // four gate scanners and the scan log, with the camera one tap away.
        return const SecurityConsoleScreen();
      case 'student':
      case 'user':
      default:
        return const CustomBottomNav();
    }
  }
}
