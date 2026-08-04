/// The roles the backend recognises, and the vocabulary the whole admin module
/// filters and posts with.
///
/// [slug] is the wire value and is sent verbatim — `/admin/users?role=USER`,
/// `/admin/roles/SECURITY_GUARD/permissions`. Never case-fold it at a call site.
enum AdminRole {
  admin('ADMIN', 'Admin'),
  complexAdmin('COMPLEX_ADMIN', 'Complex Admin'),
  employee('EMPLOYEE', 'Employee'),
  coach('COACH', 'Coach'),
  securityGuard('SECURITY_GUARD', 'Security Guard'),
  user('USER', 'User');

  const AdminRole(this.slug, this.label);

  /// The exact string the API expects.
  final String slug;

  /// How the role reads in the UI.
  final String label;

  /// The role segment `/admin/roles/{ROLE}/permissions` expects.
  ///
  /// **Not the same as [slug].** A live 400 on 2026-08-04 answered
  /// `Invalid role. Must be one of: EMPLOYEE, COACH, SECURITY, USER` — so that
  /// route calls the guard role `SECURITY`, while `/admin/users?role=` and the
  /// create-user payload still use `SECURITY_GUARD`. Only this one route is
  /// rewritten; do not "unify" them without a capture of the others.
  String get permissionsSlug =>
      this == AdminRole.securityGuard ? 'SECURITY' : slug;

  /// Whether the permissions route accepts this role at all.
  ///
  /// The same 400 enumerated the whole list, and Admin and Complex Admin are
  /// not in it — their permissions are not managed through this endpoint, so
  /// asking for them is a guaranteed error rather than an empty result.
  bool get supportsPermissions => permissionManaged.contains(this);

  /// The four roles the permissions route named, in the order it named them.
  static const List<AdminRole> permissionManaged = [
    AdminRole.employee,
    AdminRole.coach,
    AdminRole.securityGuard,
    AdminRole.user,
  ];

  /// An employee-shaped role carries an employee id + department.
  bool get isEmployeeLike =>
      this == AdminRole.employee ||
      this == AdminRole.securityGuard ||
      this == AdminRole.admin ||
      this == AdminRole.complexAdmin;

  /// A coach carries assigned sports + an assigned location.
  bool get isCoach => this == AdminRole.coach;

  /// Resolves a wire value onto a role, tolerating casing and separator drift
  /// (`security_guard`, `Security Guard`, `securityGuard` all land on one role).
  static AdminRole? tryParse(Object? value) {
    if (value == null) return null;
    final normalised = value.toString().trim().toUpperCase().replaceAll(
      RegExp(r'[\s\-]+'),
      '_',
    );
    if (normalised.isEmpty) return null;

    for (final role in AdminRole.values) {
      if (role.slug == normalised) return role;
      // `securityGuard` → `SECURITYGUARD` — match with separators dropped too.
      if (role.slug.replaceAll('_', '') == normalised.replaceAll('_', '')) {
        return role;
      }
    }

    // The permissions route calls the guard role `SECURITY`, so a response
    // echoing that must still land on a role rather than reading as unknown.
    for (final role in AdminRole.values) {
      if (role.permissionsSlug == normalised) return role;
    }
    return null;
  }

  /// The label to show for a value the enum does not cover, so an unexpected
  /// role from the server still renders as something readable.
  static String labelFor(String? raw) {
    final parsed = tryParse(raw);
    if (parsed != null) return parsed.label;
    final text = (raw ?? '').trim();
    if (text.isEmpty) return '—';
    return text
        .split(RegExp(r'[_\s]+'))
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }
}

/// Account status. The prompt's own example (`?status=Active`) fixes the
/// casing, so the slug is title-case rather than upper-case.
enum AdminUserStatus {
  active('Active', 'Active'),
  inactive('Inactive', 'Inactive'),
  suspended('Suspended', 'Suspended');

  const AdminUserStatus(this.slug, this.label);

  final String slug;
  final String label;

  static AdminUserStatus? tryParse(Object? value) {
    if (value == null) return null;
    final normalised = value.toString().trim().toLowerCase();
    if (normalised.isEmpty) return null;
    for (final status in AdminUserStatus.values) {
      if (status.slug.toLowerCase() == normalised) return status;
    }
    return null;
  }
}
