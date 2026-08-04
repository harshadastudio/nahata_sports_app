import '../../../../core/network/api_exception.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/admin_role.dart';
import '../../domain/entities/admin_stats.dart';
import '../../domain/entities/admin_user.dart';
import '../../domain/entities/paged.dart';
import '../../domain/entities/role_permissions.dart';
import '../../domain/repositories/admin_repository.dart';
import '../datasources/admin_remote_data_source.dart';
import '../models/admin_stats_model.dart';
import '../models/admin_user_model.dart';
import '../models/json_reader.dart';
import '../models/role_permissions_model.dart';

/// [AdminRepository] over the JWT backend.
///
/// Reads degrade: a dead `/admin/stats` leaves the cards empty instead of
/// taking the page down, and the failure is logged. Writes rethrow the typed
/// [ApiException] so the dialog can show the server's own message (a duplicate
/// email, a validation error) rather than a generic "something went wrong".
class AdminRepositoryImpl implements AdminRepository {
  AdminRepositoryImpl({AdminRemoteDataSource? remote})
    : _remote = remote ?? AdminRemoteDataSource();

  final AdminRemoteDataSource _remote;

  @override
  Future<AdminStats> fetchStats() async {
    try {
      final response = await _remote.stats();
      if (!response.isOk) {
        AdminLog.failure('Stats rejected (${response.statusCode})');
        return AdminStats.empty;
      }
      final stats = AdminStatsMapper.fromJson(response.payload);
      AdminLog.data('Stats → $stats');
      return stats;
    } catch (error, stackTrace) {
      AdminLog.failure('Stats failed', error: error, stackTrace: stackTrace);
      return AdminStats.empty;
    }
  }

  @override
  Future<Paged<AdminUser>> fetchUsers({
    int page = 1,
    int limit = 20,
    AdminRole? role,
    AdminUserStatus? status,
    String? search,
    String? sortBy,
    bool descending = false,
  }) async {
    final response = await _remote.users(
      page: page,
      limit: limit,
      role: role,
      status: status,
      search: search,
      sortBy: sortBy,
      descending: descending,
    );

    if (!response.isOk) {
      // A 2xx that says `success:false` still carries a reason worth showing.
      throw response.toException();
    }

    final result = AdminUserMapper.pageFrom(
      response.data,
      fallbackPage: page,
      fallbackLimit: limit,
    );
    AdminLog.data('Users → $result');
    return result;
  }

  @override
  Future<AdminUser> fetchUser(String userId) async {
    final response = await _remote.user(userId);
    if (!response.isOk) throw response.toException();

    final user = AdminUserMapper.fromJson(response.payload);
    AdminLog.data(
      'User detail → $user '
      '(${user.permissions.length} permissions, '
      '${user.assignedSports.length} sports)',
    );
    return user;
  }

  @override
  Future<AdminUser> createUser(AdminUserDraft draft) async {
    final body = draft.toJson();
    final response = await _remote.createUser(body);
    if (!response.isOk) throw response.toException();

    final created = AdminUserMapper.maybeFromBody(response.data);
    AdminLog.success('Created user ${created?.id ?? '(id not echoed)'}');

    // A create that does not echo the row is still a success — the list reload
    // that follows will pick it up.
    return created ??
        AdminUser(
          id: JsonReader.string(response.payload, const ['id', '_id']) ?? '',
          name: draft.name,
          email: draft.email,
          phone: draft.phone,
          roleRaw: draft.role?.slug,
          statusRaw: draft.status?.slug,
          membership: draft.membership,
        );
  }

  @override
  Future<AdminUser> updateUser(String userId, AdminUserDraft draft) async {
    final body = draft.toJson();
    if (body.isEmpty) {
      throw const BadRequestException('Nothing to update.');
    }

    final response = await _remote.updateUser(userId, body);
    if (!response.isOk) throw response.toException();

    final updated = AdminUserMapper.maybeFromBody(response.data);
    AdminLog.success('Updated user $userId');
    return updated ?? AdminUser(id: userId);
  }

  @override
  Future<void> deleteUser(String userId) async {
    final response = await _remote.deleteUser(userId);
    if (!response.isOk) throw response.toException();
    AdminLog.success('Deleted user $userId');
  }

  /// The permissions route accepts four roles and 400s on anything else.
  ///
  /// Refused here rather than round-tripped: `Invalid role. Must be one of:
  /// EMPLOYEE, COACH, SECURITY, USER` (captured 2026-08-04) is a failure the
  /// caller can neither fix nor retry, and it reads to an admin as if the
  /// server were broken.
  static void _assertPermissionManaged(AdminRole role) {
    if (role.supportsPermissions) return;
    throw ValidationException(
      '${role.label} permissions are not managed through this endpoint. '
      'The API accepts '
      '${AdminRole.permissionManaged.map((r) => r.label).join(', ')}.',
    );
  }

  @override
  Future<RolePermissions> fetchRolePermissions(AdminRole role) async {
    _assertPermissionManaged(role);

    final response = await _remote.rolePermissions(role);
    if (!response.isOk) throw response.toException();

    // Permission routes often answer at the top level rather than inside a
    // `data` envelope, so the mapper is handed the whole body.
    final body = response.data;
    final permissions = RolePermissionsMapper.fromJson(
      role,
      body is Map<String, dynamic>
          ? body
          : Map<String, dynamic>.from(body is Map ? body : const {}),
    );
    AdminLog.data('Permissions → $permissions');
    return permissions;
  }

  @override
  Future<RolePermissions> updateRolePermissions(
    AdminRole role,
    Set<String> granted,
  ) async {
    _assertPermissionManaged(role);

    final body = RolePermissionsMapper.toUpdateBody(granted);
    final response = await _remote.updateRolePermissions(role, body);
    if (!response.isOk) throw response.toException();

    AdminLog.success('Saved ${granted.length} permissions for ${role.slug}');

    // Prefer the server's echo; fall back to what was just sent.
    final echoed = response.data;
    if (echoed is Map) {
      final parsed = RolePermissionsMapper.fromJson(
        role,
        Map<String, dynamic>.from(echoed),
      );
      if (parsed.granted.isNotEmpty || parsed.available.isNotEmpty) {
        return parsed;
      }
    }
    return RolePermissions(
      role: role,
      granted: granted,
      available: granted.toList()..sort(),
    );
  }
}
