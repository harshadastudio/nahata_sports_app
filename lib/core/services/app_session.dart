import '../../models/profile_model.dart';

/// Who is signed in, available anywhere without a [BuildContext].
///
/// Filled from the one place every sign-in path already passes through —
/// [PermissionService.sync] — so login, Google login, a cached-profile restore
/// and a `/auth/profile` refresh all populate it without extra wiring.
///
/// It exists mainly for `COMPLEX_ADMIN`: every API that role calls is scoped to
/// its assigned venue, and screens deep in the tree need [sportComplexId]
/// without threading it through constructors.
///
/// ```dart
/// final complexId = AppSession.instance.sportComplexId; // 1
/// final name = AppSession.instance.sportComplexName;    // "Sinhagad Road"
/// ```
class AppSession {
  AppSession._();

  static final AppSession instance = AppSession._();

  ProfileModel? _profile;

  /// The signed-in user, or null before the first sign-in / after sign-out.
  ProfileModel? get profile => _profile;

  /// Normalised role (`admin`, `complex_admin`, `coach`, …). Empty when signed
  /// out, never null.
  String get role => _profile?.roleKey ?? '';

  bool get isSignedIn => _profile != null;

  bool get isAdmin => _profile?.isAdmin ?? false;
  bool get isComplexAdmin => _profile?.isComplexAdmin ?? false;
  bool get isCoach => role == 'coach';
  bool get isSecurity => role == 'security';

  // ---------------------------------------------------------------------------
  // Complex scope
  // ---------------------------------------------------------------------------

  /// The venue this session is limited to, or null for roles that see them all.
  SportComplexRef? get sportComplex => _profile?.sportComplex;

  /// Assigned complex id. Prefers the nested object and falls back to the flat
  /// `sportComplexId` field, since only one of the two is guaranteed.
  int? get sportComplexId =>
      _profile?.sportComplex?.id ?? _profile?.sportComplexId;

  /// True when the session is bound to a single venue — the flag to branch on
  /// rather than testing the role string at call sites.
  bool get hasComplexScope => sportComplexId != null;

  /// "Sinhagad Road", or an empty string when unscoped.
  String get sportComplexName => sportComplex?.name ?? '';

  String? get sportComplexCity => sportComplex?.city;

  /// "Sinhagad Road, Pune" when the city is known.
  String get sportComplexLabel => sportComplex?.label ?? '';

  // ---------------------------------------------------------------------------
  // Permissions
  // ---------------------------------------------------------------------------

  /// `can('students', 'view')` — reads `data.user.permissions`, nothing is
  /// hard-coded per role. Unknown modules answer false.
  bool can(String module, String action) =>
      _profile?.can(module, action) ?? false;

  bool canView(String module) => can(module, 'view');
  bool canCreate(String module) => can(module, 'create');
  bool canEdit(String module) => can(module, 'edit');
  bool canDelete(String module) => can(module, 'delete');

  /// True when the backend sent the object-form permissions at all. Screens use
  /// it to tell "explicitly denied" from "this build has no matrix", so a role
  /// on the legacy slug list is never locked out of its own console.
  bool get hasPermissionMatrix =>
      (_profile?.permissionMatrix.isNotEmpty) ?? false;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  void adopt(ProfileModel? profile) => _profile = profile;

  void clear() => _profile = null;
}