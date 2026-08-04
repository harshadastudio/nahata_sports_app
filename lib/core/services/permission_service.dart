import '../../models/profile_model.dart';
import '../storage/profile_cache.dart';

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
class CoachPermissions {
  const CoachPermissions._();

  static const String dashboard = 'coach_dashboard';
  static const String students = 'coach_students';
  static const String schedule = 'coach_schedule';
  static const String attendance = 'coach_attendance';
  static const String performance = 'coach_performance';
  static const String feesApproval = 'coach_fees_approval';
  static const String coachingEnquiries = 'coach_coaching_enquiries';
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

  Set<String> get permissions => Set.unmodifiable(_permissions);

  String get role => _role;

  bool get isLoaded => _permissions.isNotEmpty || _role.isNotEmpty;

  /// Refreshes the cached permission set from a profile.
  void sync(ProfileModel? profile) {
    _permissions = (profile?.permissions ?? const <String>[]).toSet();
    _role = profile?.normalisedRole ?? '';
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

  bool hasAny(Iterable<String> required) => required.any(_permissions.contains);

  bool hasAll(Iterable<String> required) =>
      required.every(_permissions.contains);

  bool hasRole(String role) => _role == role.toLowerCase();

  bool get isAdmin => _role == 'admin';
  bool get isCoach => _role == 'coach';
  bool get isSecurity => _role == 'security';
  bool get isUser => _role == 'user' || _role.isEmpty;

  void clear() {
    _permissions = <String>{};
    _role = '';
  }
}
