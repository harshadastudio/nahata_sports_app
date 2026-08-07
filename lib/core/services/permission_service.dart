import '../../models/profile_model.dart';
import '../storage/profile_cache.dart';
import 'app_session.dart';

/// Well-known permission slugs returned by `/auth/profile`.
///
/// Use these constants instead of bare strings so typos fail at compile time.
class AppPermissions {
  const AppPermissions._();

  static const String dashboard = 'user_dashboard';
  static const String logout = 'user_logout';
  static const String account = 'user_account';
  static const String viewSports = 'user_view_sports';
  static const String feedback = 'user_feedback';
  static const String myBookings = 'user_my_bookings';
  static const String myEventPass = 'user_my_event_pass';
  static const String studentsParents = 'user_students_parents';
  static const String entryPass = 'user_entry_pass';
  static const String attendanceSheet = 'user_attendance_sheet';
  static const String coachingEnquiries = 'user_coaching_enquiries';
}

/// Permission slugs granted to the `COACH` role, as returned by
/// `/auth/profile` and `/permissions/coach`.
///
/// These mirror the `COACH` block of the website's `roleMenuConfig.ts`
/// one-for-one, so the app and the web dashboard hide and show the same
/// sections for the same coach.
class CoachPermissions {
  const CoachPermissions._();

  static const String dashboard = 'coach_dashboard';

  /// Covers both My Students and Student Enrollments — the website gates both
  /// on this single slug.
  static const String students = 'coach_students';

  static const String schedule = 'coach_schedule';

  /// Covers the attendance sheet and the student pass scanner.
  static const String attendance = 'coach_attendance';

  static const String performance = 'coach_performance';
  static const String feesManagement = 'coach_fees_management';
  static const String feesApproval = 'coach_fees_approval';
  static const String coachingEnquiries = 'coach_coaching_enquiries';
  static const String notifications = 'coach_notifications';
  static const String logout = 'coach_logout';

  /// Not coach-specific — the website marks the profile entry `alwaysShow`, so
  /// it is never filtered out even when the slug is absent.
  static const String profile = 'profile';
}

/// Single source of truth for "may the current user do X?".
///
/// Permissions arrive with the profile; [sync] is called whenever the profile
/// changes so checks stay synchronous and allocation-free at call sites:
///
/// ```dart
/// if (PermissionService.instance.hasPermission(AppPermissions.dashboard)) { … }
/// ```
class PermissionService {
  PermissionService._();

  static final PermissionService instance = PermissionService._();

  Set<String> _permissions = <String>{};
  String _role = '';
  Map<String, Map<String, bool>> _matrix = const <String, Map<String, bool>>{};

  Set<String> get permissions => Set.unmodifiable(_permissions);

  /// The object-form permissions (`{"students": {"view": true}}`) when the
  /// backend sent them; empty for the legacy slug list.
  Map<String, Map<String, bool>> get matrix => Map.unmodifiable(_matrix);

  String get role => _role;

  bool get isLoaded => _permissions.isNotEmpty || _role.isNotEmpty;

  /// Refreshes the cached permission set from a profile.
  ///
  /// Also hands the profile to [AppSession] — this is the one call every
  /// sign-in path makes, so the session scope (role, assigned complex) stays
  /// in step with the permissions without a second wiring point.
  void sync(ProfileModel? profile) {
    AppSession.instance.adopt(profile);

    // Read back rather than using [profile] directly: the session carries
    // forward the permission matrix and assigned complex that a slimmer
    // `/auth/profile` payload leaves out.
    final effective = AppSession.instance.profile;
    _permissions = (effective?.permissions ?? const <String>[]).toSet();
    _role = effective?.roleKey ?? '';
    _matrix = effective?.permissionMatrix ?? const <String, Map<String, bool>>{};
  }

  /// Loads permissions from disk — used before the first profile fetch lands.
  Future<void> loadFromCache() async {
    final profile = await ProfileCache.instance.read();
    if (profile != null) {
      sync(profile);
      return;
    }
    _permissions = (await ProfileCache.instance.readPermissions()).toSet();
  }

  bool hasPermission(String permission) => _permissions.contains(permission);

  /// `can('students', 'view')` — the module/action form returned by
  /// `/auth/login`. Falls back to the flat `module.action` slug so a profile
  /// restored from an older cache answers identically. Never hard-codes a role.
  bool can(String module, String action) {
    final actions = _matrix[module];
    if (actions != null) return actions[action] ?? false;
    return _permissions.contains('$module.$action');
  }

  bool canView(String module) => can(module, 'view');
  bool canCreate(String module) => can(module, 'create');
  bool canEdit(String module) => can(module, 'edit');
  bool canDelete(String module) => can(module, 'delete');

  bool hasAny(Iterable<String> required) => required.any(_permissions.contains);

  bool hasAll(Iterable<String> required) =>
      required.every(_permissions.contains);

  bool hasRole(String role) => _role == role.toLowerCase();

  bool get isAdmin => _role == 'admin';
  bool get isComplexAdmin => _role == 'complex_admin';
  bool get isCoach => _role == 'coach';
  bool get isSecurity => _role == 'security';
  bool get isUser => _role == 'user' || _role.isEmpty;

  void clear() {
    _permissions = <String>{};
    _role = '';
    _matrix = const <String, Map<String, bool>>{};
    AppSession.instance.clear();
  }
}
