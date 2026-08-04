import 'admin_role.dart';

/// A user as the admin module sees it.
///
/// The list route (`/admin/users`) and the detail route (`/admin/users/{id}`)
/// return the same entity — detail simply populates more of it. Every field is
/// nullable so a thinner list payload never has to be faked with placeholders;
/// the UI renders "—" for anything the server did not send.
class AdminUser {
  const AdminUser({
    required this.id,
    this.name,
    this.email,
    this.phone,
    this.roleRaw,
    this.statusRaw,
    this.membership,
    this.totalBookings,
    this.joinedAt,
    this.lastActiveAt,
    this.avatarUrl,
    this.dateOfBirth,
    this.gender,
    this.bloodGroup,
    this.emailVerified,
    this.phoneVerified,
    this.employeeId,
    this.department,
    this.assignedSports = const [],
    this.assignedLocation,
    this.permissions = const [],
    this.raw = const {},
  });

  final String id;

  final String? name;
  final String? email;
  final String? phone;

  /// Kept as sent so an unrecognised role still displays.
  final String? roleRaw;
  final String? statusRaw;

  final String? membership;
  final int? totalBookings;

  final DateTime? joinedAt;
  final DateTime? lastActiveAt;
  final String? avatarUrl;

  // Detail-only fields.
  final DateTime? dateOfBirth;
  final String? gender;
  final String? bloodGroup;
  final bool? emailVerified;
  final bool? phoneVerified;

  // Employee-shaped roles.
  final String? employeeId;
  final String? department;

  // Coach-shaped roles.
  final List<String> assignedSports;
  final String? assignedLocation;

  final List<String> permissions;

  /// Anything the API sent that this entity does not model, so nothing is lost
  /// and a future module can read it without a re-parse.
  final Map<String, dynamic> raw;

  AdminRole? get role => AdminRole.tryParse(roleRaw);

  AdminUserStatus? get status => AdminUserStatus.tryParse(statusRaw);

  String get roleLabel => AdminRole.labelFor(roleRaw);

  String get statusLabel => status?.label ?? ((statusRaw ?? '').trim());

  String get displayName {
    final trimmed = (name ?? '').trim();
    if (trimmed.isNotEmpty) return trimmed;
    final mail = (email ?? '').trim();
    return mail.isEmpty ? 'Unnamed user' : mail;
  }

  /// Up to two initials for the avatar fallback.
  String get initials {
    final parts = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  bool get hasAvatar {
    final url = (avatarUrl ?? '').trim();
    return url.startsWith('http://') || url.startsWith('https://');
  }

  bool get isEmployeeLike =>
      (role?.isEmployeeLike ?? false) ||
      (employeeId ?? '').trim().isNotEmpty ||
      (department ?? '').trim().isNotEmpty;

  bool get isCoach =>
      (role?.isCoach ?? false) ||
      assignedSports.isNotEmpty ||
      (assignedLocation ?? '').trim().isNotEmpty;

  AdminUser mergedWith(AdminUser other) {
    return AdminUser(
      id: other.id.isEmpty ? id : other.id,
      name: other.name ?? name,
      email: other.email ?? email,
      phone: other.phone ?? phone,
      roleRaw: other.roleRaw ?? roleRaw,
      statusRaw: other.statusRaw ?? statusRaw,
      membership: other.membership ?? membership,
      totalBookings: other.totalBookings ?? totalBookings,
      joinedAt: other.joinedAt ?? joinedAt,
      lastActiveAt: other.lastActiveAt ?? lastActiveAt,
      avatarUrl: other.avatarUrl ?? avatarUrl,
      dateOfBirth: other.dateOfBirth ?? dateOfBirth,
      gender: other.gender ?? gender,
      bloodGroup: other.bloodGroup ?? bloodGroup,
      emailVerified: other.emailVerified ?? emailVerified,
      phoneVerified: other.phoneVerified ?? phoneVerified,
      employeeId: other.employeeId ?? employeeId,
      department: other.department ?? department,
      assignedSports: other.assignedSports.isEmpty
          ? assignedSports
          : other.assignedSports,
      assignedLocation: other.assignedLocation ?? assignedLocation,
      permissions: other.permissions.isEmpty ? permissions : other.permissions,
      raw: {...raw, ...other.raw},
    );
  }

  @override
  String toString() =>
      'AdminUser(id: $id, name: $name, role: $roleRaw, status: $statusRaw)';
}

/// The write payload shared by create and update.
///
/// Only the fields the form actually touched are serialised, so an update never
/// blanks a column the admin did not edit.
class AdminUserDraft {
  const AdminUserDraft({
    this.name,
    this.email,
    this.phone,
    this.role,
    this.membership,
    this.status,
    this.employeeId,
    this.department,
    this.assignedSports,
    this.assignedLocation,
  });

  final String? name;
  final String? email;
  final String? phone;
  final AdminRole? role;
  final String? membership;
  final AdminUserStatus? status;
  final String? employeeId;
  final String? department;
  final List<String>? assignedSports;
  final String? assignedLocation;

  Map<String, dynamic> toJson() {
    final body = <String, dynamic>{};

    void put(String key, Object? value) {
      if (value == null) return;
      if (value is String && value.trim().isEmpty) return;
      if (value is List && value.isEmpty) return;
      body[key] = value is String ? value.trim() : value;
    }

    put('name', name);
    put('email', email);
    put('phoneNumber', phone);
    put('role', role?.slug);
    put('membershipType', membership);
    put('status', status?.slug);

    // Employee block — only for a role that has one.
    if (role == null || role!.isEmployeeLike) {
      put('employeeId', employeeId);
      put('department', department);
    }

    // Coach block — same rule.
    if (role == null || role!.isCoach) {
      put('assignedSports', assignedSports);
      put('assignedLocation', assignedLocation);
    }

    return body;
  }

  bool get isEmpty => toJson().isEmpty;
}
