import 'dart:convert';

/// The sports complex a `COMPLEX_ADMIN` is scoped to.
///
/// `POST /auth/login` returns it beside `sportComplexId` for that role only;
/// every other role gets `null` for both. Kept deliberately small — it is
/// identity, not the full venue record served by `/sports-complexes`.
class SportComplexRef {
  const SportComplexRef({required this.id, required this.name, this.city});

  final int id;
  final String name;
  final String? city;

  /// "Sinhagad Road, Pune" when the city is known, otherwise just the name.
  String get label =>
      (city == null || city!.trim().isEmpty) ? name : '$name, ${city!.trim()}';

  /// Null when the payload is absent or has no usable id/name, so callers can
  /// treat "not a complex admin" and "malformed" the same way.
  static SportComplexRef? fromJson(Object? value) {
    if (value is! Map) return null;
    final json = Map<String, dynamic>.from(value);

    final rawId = json['id'];
    final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    final name = json['name']?.toString().trim();
    if (id == null || name == null || name.isEmpty || name == 'null') {
      return null;
    }

    final city = json['city']?.toString().trim();
    return SportComplexRef(
      id: id,
      name: name,
      city: (city == null || city.isEmpty || city == 'null') ? null : city,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'city': city,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SportComplexRef &&
          other.id == id &&
          other.name == name &&
          other.city == city);

  @override
  int get hashCode => Object.hash(id, name, city);

  @override
  String toString() => 'SportComplexRef(id: $id, name: $name)';
}

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
    this.sportComplex,
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
    this.gender,
    this.bloodGroup,
    this.dob,
    this.permissions = const <String>[],
    this.permissionMatrix = const <String, Map<String, bool>>{},
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

  /// Set for `COMPLEX_ADMIN` only — the venue every one of their APIs is
  /// scoped to. Null for every other role.
  final SportComplexRef? sportComplex;

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

  /// The three fields `PUT /auth/profile` accepts alongside name and phone.
  ///
  /// [dob] reads `dob` or `date_of_birth` — the profile payload carries both
  /// keys and only one of them is ever filled.
  final String? gender;
  final String? bloodGroup;
  final String? dob;
  /// Flat permission slugs. Two shapes reach this list:
  ///
  ///  * the legacy `/auth/profile` form — `["user_dashboard", …]`, used
  ///    verbatim;
  ///  * the object form returned by `/auth/login` — `{"students": {"view":
  ///    true}}`, flattened here to `students.view` so a single
  ///    `hasPermission(...)` call works for both.
  final List<String> permissions;

  /// The object form, kept structured: `{"students": {"view": true, …}}`.
  ///
  /// Empty when the backend sent the legacy slug list. Read it through
  /// [can] rather than indexing it directly.
  final Map<String, Map<String, bool>> permissionMatrix;

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

  /// Role comparison that ignores case and the `_`/`-`/space spellings the
  /// backend has used for `COMPLEX_ADMIN` over time.
  String get roleKey => roleLabel.toLowerCase().replaceAll(RegExp(r'[-\s]'), '_');

  bool get isAdmin => roleKey == 'admin' || roleKey == 'super_admin';

  bool get isComplexAdmin => roleKey == 'complex_admin';

  /// True when `/auth/google-login` signed the user in but the account still
  /// has no phone number — the backend flags this as `needsPhone`. Only that
  /// endpoint sends it, so it is read out of [extras].
  bool get needsPhone => _asBool(extras['needsPhone']);

  bool hasPermission(String permission) =>
      permissions.contains(permission);

  /// `can('students', 'view')` — the object-form check.
  ///
  /// Falls back to the flat slug list so a profile restored from a legacy
  /// cache answers the same question the same way. Unknown module or action
  /// means "no", never a crash.
  bool can(String module, String action) {
    final actions = permissionMatrix[module];
    if (actions != null) return actions[action] ?? false;
    return permissions.contains('$module.$action');
  }

  // ---------------------------------------------------------------------------
  // Serialisation
  // ---------------------------------------------------------------------------

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    final matrix = _asPermissionMatrix(json['permissions']);
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
      sportComplex: SportComplexRef.fromJson(
        json['sportComplex'] ?? json['sport_complex'],
      ),
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
      gender: _asString(json['gender']),
      bloodGroup: _asString(json['blood_group'] ?? json['bloodGroup']),
      dob: _asString(
        json['dob'] ?? json['date_of_birth'] ?? json['dateOfBirth'],
      ),
      permissions: matrix.isEmpty
          ? _asStringList(json['permissions'])
          : _flattenPermissions(matrix),
      permissionMatrix: matrix,
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
    'sportComplex', 'sport_complex',
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
    'gender',
    'blood_group', 'bloodGroup',
    'dob', 'date_of_birth', 'dateOfBirth',
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
        'sportComplex': sportComplex?.toJson(),
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
        'gender': gender,
        'blood_group': bloodGroup,
        'dob': dob,
        // Written back in whichever shape it arrived, so a cached profile
        // re-parses into exactly the same object.
        'permissions': permissionMatrix.isEmpty ? permissions : permissionMatrix,
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
    SportComplexRef? sportComplex,
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
    String? gender,
    String? bloodGroup,
    String? dob,
    List<String>? permissions,
    Map<String, Map<String, bool>>? permissionMatrix,
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
      sportComplex: sportComplex ?? this.sportComplex,
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
      gender: gender ?? this.gender,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      dob: dob ?? this.dob,
      permissions: permissions ?? this.permissions,
      permissionMatrix: permissionMatrix ?? this.permissionMatrix,
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
          other.sportComplexId == sportComplexId &&
          other.sportComplex == sportComplex &&
          other.status == status &&
          other.membershipType == membershipType &&
          other.gender == gender &&
          other.bloodGroup == bloodGroup &&
          other.dob == dob &&
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
        sportComplexId,
        sportComplex,
        status,
        membershipType,
        gender,
        bloodGroup,
        dob,
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

  /// Reads the object form of `permissions`.
  ///
  /// `{"students": {"view": true, "create": false}}` becomes
  /// `{students: {view: true, create: false}}`. Anything that is not a map of
  /// maps (the legacy slug list, a null, a malformed entry) yields an empty
  /// matrix, which callers read as "fall back to the flat list".
  static Map<String, Map<String, bool>> _asPermissionMatrix(Object? value) {
    if (value is! Map) return const <String, Map<String, bool>>{};

    final matrix = <String, Map<String, bool>>{};
    value.forEach((module, actions) {
      if (actions is! Map) return;
      final key = module?.toString().trim();
      if (key == null || key.isEmpty) return;

      final entries = <String, bool>{};
      actions.forEach((action, allowed) {
        final name = action?.toString().trim();
        if (name == null || name.isEmpty) return;
        entries[name] = _asBool(allowed);
      });

      if (entries.isNotEmpty) matrix[key] = entries;
    });

    return matrix;
  }

  /// `{students: {view: true, create: false}}` → `["students.view"]`.
  /// Only granted actions are listed, so `contains` is a positive check.
  static List<String> _flattenPermissions(
    Map<String, Map<String, bool>> matrix,
  ) {
    final slugs = <String>[];
    matrix.forEach((module, actions) {
      actions.forEach((action, allowed) {
        if (allowed) slugs.add('$module.$action');
      });
    });
    return List<String>.unmodifiable(slugs);
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
