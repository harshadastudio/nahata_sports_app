import 'package:flutter/material.dart';

import '../../../../core/services/app_session.dart';
import '../../../admin/presentation/navigation/admin_shell_config.dart';
import '../../../admin/presentation/pages/admin_dashboard_page.dart';

/// The console a `COMPLEX_ADMIN` lands on after login.
///
/// It is its own screen with its own navigation — never the student
/// [CustomBottomNav] — but it is not a second copy of the admin console. It
/// runs the same shell with a different [AdminShellConfig]:
///
///  * branded with the assigned venue (`sportComplex.name`) rather than
///    "Admin Console";
///  * a sidebar built from `data.user.permissions` — a module with
///    `view: false` (or missing) never appears;
///  * estate-wide modules (other complexes' admins, employees, security
///    guards) left out entirely;
///  * `enforcePermissions`, so reaching a module that is not granted shows an
///    access notice instead of the data.
///
/// The venue itself lives in [AppSession] (`sportComplexId`, `sportComplex`),
/// filled at login, so every screen and repository below can scope to it
/// without it being threaded through constructors.
class ComplexAdminDashboardScreen extends StatelessWidget {
  const ComplexAdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Built per-build rather than held as a constant: the brand line and the
    // permitted modules both come from the live session, which is replaced on
    // every sign-in.
    return AdminDashboardScreen(config: AdminShellConfig.complexAdmin());
  }

  /// The venue this console is scoped to, or null when the session carries no
  /// complex (an account mis-configured server-side).
  static int? get sportComplexId => AppSession.instance.sportComplexId;
}