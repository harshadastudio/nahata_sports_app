import 'admin_role.dart';

/// An admin scoped to one sports complex (`/admin/complex-admins`).
class ComplexAdmin {
  const ComplexAdmin({
    required this.id,
    this.name,
    this.email,
    this.phone,
    this.sportComplexId,
    this.sportComplexName,
    this.city,
    this.statusRaw,
    this.createdAt,
    this.raw = const {},
  });

  final String id;
  final String? name;
  final String? email;
  final String? phone;

  /// Kept alongside the name so the edit dialog can preselect the dropdown
  /// without having to match on a display string.
  final int? sportComplexId;
  final String? sportComplexName;

  final String? city;
  final String? statusRaw;
  final DateTime? createdAt;

  final Map<String, dynamic> raw;

  AdminUserStatus? get status => AdminUserStatus.tryParse(statusRaw);

  String get statusLabel => status?.label ?? ((statusRaw ?? '').trim());

  String get displayName {
    final trimmed = (name ?? '').trim();
    if (trimmed.isNotEmpty) return trimmed;
    final mail = (email ?? '').trim();
    return mail.isEmpty ? 'Unnamed admin' : mail;
  }

  String get initials {
    final parts = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  /// "Nahata Sports Complex, Pune" when both are known.
  String get venueLabel {
    final venue = (sportComplexName ?? '').trim();
    final town = (city ?? '').trim();
    if (venue.isEmpty) return town;
    if (town.isEmpty) return venue;
    return '$venue, $town';
  }

  @override
  String toString() =>
      'ComplexAdmin($id, $name, complex: $sportComplexName, $statusRaw)';
}

/// The write payload for create and update.
///
/// Only touched fields are serialised, so an edit never blanks a column the
/// admin did not change — and an empty password field means "leave it alone"
/// rather than "set the password to empty".
class ComplexAdminDraft {
  const ComplexAdminDraft({
    this.name,
    this.email,
    this.password,
    this.phone,
    this.sportComplexId,
    this.status,
  });

  final String? name;
  final String? email;
  final String? password;
  final String? phone;
  final int? sportComplexId;
  final AdminUserStatus? status;

  /// The create body, exactly as the endpoint documents it — note the
  /// `phone_number` snake_case key sitting next to camelCase `sportComplexId`.
  Map<String, dynamic> toCreateJson() {
    return <String, dynamic>{
      'name': (name ?? '').trim(),
      'email': (email ?? '').trim(),
      'password': password ?? '',
      'phone_number': (phone ?? '').trim(),
      'sportComplexId': sportComplexId,
    };
  }

  Map<String, dynamic> toUpdateJson() {
    final body = <String, dynamic>{};

    void put(String key, Object? value) {
      if (value == null) return;
      if (value is String && value.trim().isEmpty) return;
      body[key] = value is String ? value.trim() : value;
    }

    put('name', name);
    put('phone_number', phone);
    put('sportComplexId', sportComplexId);
    put('status', status?.slug);
    // Absent unless the admin actually typed a new one.
    put('password', password);

    return body;
  }

  bool get isEmptyUpdate => toUpdateJson().isEmpty;
}
