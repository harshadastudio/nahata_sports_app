import 'dart:convert';

/// Strongly typed representation of `GET /auth/profile`.
///
/// Every field the API documents is mapped, all of them null-safe. Legacy
/// snake/camel spellings are both accepted so a profile restored from an older
/// cache (or from the legacy `student` endpoints) still parses.
class ProfileModel {
  const ProfileModel({
    this.id,
    this.name,
    this.phoneNumber,
    this.email,
    this.googleId,
    this.isGoogleUser = false,
    this.role,
    this.sportComplexId,
    this.totalBookings,
    this.membershipType,
    this.status,
    this.joinDate,
    this.lastActive,
    this.avatar,
    this.employeeId,
    this.department,
    this.assignedSports = const <String>[],
    this.assignedLocation,
    this.permissions = const <String>[],
    this.profilePicture,
    this.extras = const <String, dynamic>{},
  });

  final int? id;
  final String? name;
  final String? phoneNumber;
  final String? email;
  final String? googleId;
  final bool isGoogleUser;
  final String? role;
  final int? sportComplexId;
  final int? totalBookings;
  final String? membershipType;
  final String? status;
  final String? joinDate;
  final String? lastActive;
  final String? avatar;
  final String? employeeId;
  final String? department;
  final List<String> assignedSports;
  final String? assignedLocation;
  final List<String> permissions;
  final String? profilePicture;

  /// Fields the API returned that this model does not type explicitly
  /// (`student_id`, `passcode`, …). Kept verbatim so screens still reading the
  /// raw user map keep working, and so nothing is silently dropped when the
  /// backend adds a field.
  final Map<String, dynamic> extras;

  static const ProfileModel empty = ProfileModel();

  bool get isEmpty => id == null && (name == null || name!.isEmpty);
  bool get isNotEmpty => !isEmpty;

  // ---------------------------------------------------------------------------
  // Derived values used by the UI
  // ---------------------------------------------------------------------------

  /// Display name, never null.
  String get displayName => (name ?? '').trim();

  /// First letter of the name, uppercased. Falls back to `?` like the existing
  /// screens did.
  String get initial {
    final trimmed = displayName;
    if (trimmed.isEmpty) return '?';
    return trimmed.substring(0, 1).toUpperCase();
  }

  /// Best available image URL, or `null` when the UI should render the initial.
  String? get imageUrl {
    for (final candidate in [profilePicture, avatar]) {
      if (candidate != null && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }
    return null;
  }

  bool get hasImage => imageUrl != null;

  String get membershipLabel =>
      (membershipType == null || membershipType!.trim().isEmpty)
          ? 'N/A'
          : membershipType!.trim();

  String get roleLabel => (role ?? '').trim();

  /// Lower-cased role, matching how the legacy screens routed by role.
  String get normalisedRole => roleLabel.toLowerCase();

  bool get isActive => (status ?? '').toLowerCase() == 'active';

  /// True when `/auth/google-login` signed the user in but the account still
  /// has no phone number — the backend flags this as `needsPhone`. Only that
  /// endpoint sends it, so it is read out of [extras].
  bool get needsPhone => _asBool(extras['needsPhone']);

  bool hasPermission(String permission) =>
      permissions.contains(permission);

  // ---------------------------------------------------------------------------
  // Serialisation
  // ---------------------------------------------------------------------------

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: _asInt(json['id']),
      name: _asString(json['name']),
      phoneNumber: _asString(
          json['phone_number'] ?? json['phoneNumber'] ?? json['phone']),
      email: _asString(json['email']),
      googleId: _asString(json['googleId'] ?? json['google_id']),
      isGoogleUser: _asBool(json['isGoogleUser'] ?? json['is_google_user']),
      role: _asString(json['role']),
      sportComplexId:
          _asInt(json['sportComplexId'] ?? json['sport_complex_id']),
      totalBookings: _asInt(json['total_bookings'] ?? json['totalBookings']),
      membershipType:
          _asString(json['membership_type'] ?? json['membershipType']),
      status: _asString(json['status']),
      joinDate: _asString(json['join_date'] ?? json['joinDate']),
      lastActive: _asString(json['last_active'] ?? json['lastActive']),
      avatar: _asString(json['avatar']),
      employeeId: _asString(json['employee_id'] ?? json['employeeId']),
      department: _asString(json['department']),
      assignedSports:
          _asStringList(json['assigned_sports'] ?? json['assignedSports']),
      assignedLocation:
          _asString(json['assigned_location'] ?? json['assignedLocation']),
      permissions: _asStringList(json['permissions']),
      profilePicture:
          _asString(json['profile_picture'] ?? json['profilePicture']),
      extras: Map<String, dynamic>.fromEntries(
        json.entries.where((e) => !_mappedKeys.contains(e.key)),
      ),
    );
  }

  /// Keys consumed by the typed fields above; everything else lands in
  /// [extras].
  static const Set<String> _mappedKeys = <String>{
    'id',
    'name',
    'phone_number', 'phoneNumber', 'phone',
    'email',
    'googleId', 'google_id',
    'isGoogleUser', 'is_google_user',
    'role',
    'sportComplexId', 'sport_complex_id',
    'total_bookings', 'totalBookings',
    'membership_type', 'membershipType',
    'status',
    'join_date', 'joinDate',
    'last_active', 'lastActive',
    'avatar',
    'employee_id', 'employeeId',
    'department',
    'assigned_sports', 'assignedSports',
    'assigned_location', 'assignedLocation',
    'permissions',
    'profile_picture', 'profilePicture',
    'photo',
  };

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'phone_number': phoneNumber,
        'email': email,
        'googleId': googleId,
        'isGoogleUser': isGoogleUser,
        'role': role,
        'sportComplexId': sportComplexId,
        'total_bookings': totalBookings,
        'membership_type': membershipType,
        'status': status,
        'join_date': joinDate,
        'last_active': lastActive,
        'avatar': avatar,
        'employee_id': employeeId,
        'department': department,
        'assigned_sports': assignedSports,
        'assigned_location': assignedLocation,
        'permissions': permissions,
        'profile_picture': profilePicture,
        ...extras,
      };

  /// Map shape kept for the screens that still read `prefs.getString('user')`
  /// as a raw map. Includes the legacy `phone` / `photo` aliases they expect
  /// and every unmapped field (`student_id`, `passcode`, …).
  Map<String, dynamic> toLegacyUserMap() => <String, dynamic>{
        ...toJson(),
        'phone': phoneNumber,
        'photo': imageUrl,
        // Older screens fall back to the user id when there is no student id.
        'student_id': extras['student_id'] ?? id,
      };

  String encode() => jsonEncode(toJson());

  static ProfileModel? decode(String? source) {
    if (source == null || source.isEmpty) return null;
    try {
      final decoded = jsonDecode(source);
      if (decoded is Map<String, dynamic>) return ProfileModel.fromJson(decoded);
      if (decoded is Map) {
        return ProfileModel.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      // Corrupt cache — treat as absent.
    }
    return null;
  }

  ProfileModel copyWith({
    int? id,
    String? name,
    String? phoneNumber,
    String? email,
    String? googleId,
    bool? isGoogleUser,
    String? role,
    int? sportComplexId,
    int? totalBookings,
    String? membershipType,
    String? status,
    String? joinDate,
    String? lastActive,
    String? avatar,
    String? employeeId,
    String? department,
    List<String>? assignedSports,
    String? assignedLocation,
    List<String>? permissions,
    String? profilePicture,
    Map<String, dynamic>? extras,
  }) {
    return ProfileModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      googleId: googleId ?? this.googleId,
      isGoogleUser: isGoogleUser ?? this.isGoogleUser,
      role: role ?? this.role,
      sportComplexId: sportComplexId ?? this.sportComplexId,
      totalBookings: totalBookings ?? this.totalBookings,
      membershipType: membershipType ?? this.membershipType,
      status: status ?? this.status,
      joinDate: joinDate ?? this.joinDate,
      lastActive: lastActive ?? this.lastActive,
      avatar: avatar ?? this.avatar,
      employeeId: employeeId ?? this.employeeId,
      department: department ?? this.department,
      assignedSports: assignedSports ?? this.assignedSports,
      assignedLocation: assignedLocation ?? this.assignedLocation,
      permissions: permissions ?? this.permissions,
      profilePicture: profilePicture ?? this.profilePicture,
      extras: extras ?? this.extras,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProfileModel &&
          other.id == id &&
          other.name == name &&
          other.email == email &&
          other.phoneNumber == phoneNumber &&
          other.role == role &&
          other.status == status &&
          other.membershipType == membershipType &&
          other.profilePicture == profilePicture &&
          other.avatar == avatar &&
          other.totalBookings == totalBookings &&
          other.permissions.join(',') == permissions.join(','));

  @override
  int get hashCode => Object.hash(
        id,
        name,
        email,
        phoneNumber,
        role,
        status,
        membershipType,
        profilePicture,
        avatar,
        totalBookings,
        permissions.join(','),
      );

  @override
  String toString() => 'ProfileModel(id: $id, name: $name, role: $role)';

  // ---------------------------------------------------------------------------
  // Parsing helpers — every one of them tolerates nulls and wrong types.
  // ---------------------------------------------------------------------------

  static String? _asString(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return null;
    return text;
  }

  static int? _asInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static bool _asBool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().toLowerCase();
    return text == 'true' || text == '1';
  }

  static List<String> _asStringList(Object? value) {
    if (value == null) return const <String>[];
    if (value is List) {
      return value
          .where((e) => e != null)
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
    }
    // Some endpoints send a comma separated string or a JSON-encoded array.
    final text = value.toString().trim();
    if (text.isEmpty) return const <String>[];
    if (text.startsWith('[')) {
      try {
        final decoded = jsonDecode(text);
        if (decoded is List) return _asStringList(decoded);
      } catch (_) {
        // fall through to comma splitting
      }
    }
    return text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }
}
