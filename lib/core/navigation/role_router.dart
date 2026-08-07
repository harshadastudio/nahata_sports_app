import 'package:flutter/material.dart';

import '../../bottombar/Custombottombar.dart';
import '../../dashboard/admin_screen.dart';
import '../../dashboard/coach_screen.dart';
import '../../dashboard/security_screen.dart';
import '../../features/complex_admin/presentation/pages/complex_admin_dashboard_page.dart';

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
      case 'security':
        return const SecurityGateScannerScreen();
      case 'student':
      case 'user':
      default:
        return const CustomBottomNav();
    }
  }
}