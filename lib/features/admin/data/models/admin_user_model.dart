import '../../domain/entities/admin_user.dart';
import '../../domain/entities/paged.dart';
import 'json_reader.dart';

/// Maps `/admin/users` JSON onto [AdminUser].
///
/// Kept out of the entity so the domain layer stays free of wire concerns.
class AdminUserMapper {
  const AdminUserMapper._();

  static AdminUser fromJson(Map<String, dynamic> json) {
    // Unwrap `{ "user": {...} }` / `{ "data": {...} }` before reading fields.
    final source = _unwrap(json);

    return AdminUser(
      id:
          JsonReader.string(source, const ['id', '_id', 'userId', 'user_id']) ??
          '',
      name: JsonReader.string(source, const [
        'name',
        'fullName',
        'full_name',
        'userName',
      ]),
      email: JsonReader.string(source, const ['email', 'emailAddress']),
      phone: JsonReader.string(source, const [
        'phoneNumber',
        'phone_number',
        'phone',
        'mobile',
        'mobileNumber',
      ]),
      roleRaw: JsonReader.string(source, const [
        'role',
        'userRole',
        'roleName',
      ]),
      statusRaw: JsonReader.string(source, const ['status', 'accountStatus']),
      membership: JsonReader.string(source, const [
        'membershipType',
        'membership_type',
        'membership',
        'plan',
      ]),
      totalBookings: JsonReader.integer(source, const [
        'totalBookings',
        'total_bookings',
        'bookingsCount',
        'bookings_count',
      ]),
      joinedAt: JsonReader.date(source, const [
        'joinDate',
        'join_date',
        'joinedAt',
        'joined_at',
        'createdAt',
        'created_at',
      ]),
      lastActiveAt: JsonReader.date(source, const [
        'lastActive',
        'last_active',
        'lastActiveAt',
        'lastLogin',
        'last_login',
        'lastSeen',
      ]),
      avatarUrl: JsonReader.string(source, const [
        'profilePicture',
        'profile_picture',
        'avatar',
        'avatarUrl',
        'image',
        'photo',
      ]),
      dateOfBirth: JsonReader.date(source, const [
        'dob',
        'dateOfBirth',
        'date_of_birth',
        'birthDate',
      ]),
      gender: JsonReader.string(source, const ['gender', 'sex']),
      bloodGroup: JsonReader.string(source, const [
        'bloodGroup',
        'blood_group',
        'bloodType',
      ]),
      emailVerified: JsonReader.boolean(source, const [
        'emailVerified',
        'email_verified',
        'isEmailVerified',
        'emailVerification',
      ]),
      phoneVerified: JsonReader.boolean(source, const [
        'phoneVerified',
        'phone_verified',
        'isPhoneVerified',
        'mobileVerified',
        'phoneVerification',
      ]),
      employeeId: JsonReader.string(source, const [
        'employeeId',
        'employee_id',
        'empId',
        'staffId',
      ]),
      department: JsonReader.string(source, const [
        'department',
        'dept',
        'departmentName',
      ]),
      assignedSports: JsonReader.stringList(source, const [
        'assignedSports',
        'assigned_sports',
        'sports',
        'sportNames',
      ]),
      assignedLocation: JsonReader.string(source, const [
        'assignedLocation',
        'assigned_location',
        'location',
        'sportComplexName',
        'complexName',
      ]),
      permissions: JsonReader.stringList(source, const [
        'permissions',
        'permissionSlugs',
        'abilities',
      ]),
      raw: source,
    );
  }

  static List<AdminUser> listFrom(Object? body) {
    return JsonReader.records(
      body,
    ).map(fromJson).where((user) => user.id.isNotEmpty).toList(growable: false);
  }

  /// Builds the page + its meta from a `/admin/users` body.
  static Paged<AdminUser> pageFrom(
    Object? body, {
    required int fallbackPage,
    required int fallbackLimit,
  }) {
    final items = listFrom(body);
    final meta = JsonReader.meta(body);

    final page =
        JsonReader.integer(meta, const [
          'page',
          'currentPage',
          'current_page',
          'pageNumber',
        ]) ??
        fallbackPage;

    final limit =
        JsonReader.integer(meta, const [
          'limit',
          'perPage',
          'per_page',
          'pageSize',
        ]) ??
        fallbackLimit;

    final total =
        JsonReader.integer(meta, const [
          'total',
          'totalItems',
          'total_items',
          'totalRecords',
          'totalUsers',
          'count',
        ]) ??
        items.length;

    final totalPages =
        JsonReader.integer(meta, const [
          'totalPages',
          'total_pages',
          'pageCount',
          'lastPage',
          'last_page',
        ]) ??
        0;

    return Paged<AdminUser>(
      items: items,
      page: page,
      limit: limit,
      total: total,
      totalPages: totalPages,
    );
  }

  /// A write response may echo the saved row, wrap it, or return nothing at
  /// all; the caller reconciles a blank id by refetching the list.
  static AdminUser? maybeFromBody(Object? body) {
    if (body is! Map) return null;
    final user = fromJson(Map<String, dynamic>.from(body));
    return user.id.isEmpty ? null : user;
  }

  static Map<String, dynamic> _unwrap(Map<String, dynamic> json) {
    for (final key in const ['user', 'data', 'result']) {
      final inner = json[key];
      if (inner is Map) {
        final unwrapped = Map<String, dynamic>.from(inner);
        // `{ data: { user: {...} } }`
        for (final nested in const ['user', 'data']) {
          final deeper = unwrapped[nested];
          if (deeper is Map) return Map<String, dynamic>.from(deeper);
        }
        return unwrapped;
      }
    }
    return json;
  }
}
