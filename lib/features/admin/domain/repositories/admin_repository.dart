import '../entities/admin_role.dart';
import '../entities/admin_stats.dart';
import '../entities/admin_user.dart';
import '../entities/paged.dart';
import '../entities/role_permissions.dart';

/// What the presentation layer is allowed to ask for.
///
/// Implementations live in `data/` and are the only place that knows about
/// HTTP, JSON or the endpoint strings. Reads may return an empty entity on
/// failure; writes must throw so the caller can surface the reason.
abstract class AdminRepository {
  /// `GET /admin/stats`
  Future<AdminStats> fetchStats();

  /// `GET /admin/users?page=&limit=&role=&search=&status=`
  ///
  /// [sortBy] / [descending] are forwarded as query parameters when set; a
  /// backend that ignores them simply returns its default order, which the
  /// controller then sorts client-side for the current page.
  Future<Paged<AdminUser>> fetchUsers({
    int page,
    int limit,
    AdminRole? role,
    AdminUserStatus? status,
    String? search,
    String? sortBy,
    bool descending,
  });

  /// `GET /admin/users/{userId}`
  Future<AdminUser> fetchUser(String userId);

  /// `POST /admin/create-user`
  Future<AdminUser> createUser(AdminUserDraft draft);

  /// `PUT /admin/users/{userId}`
  Future<AdminUser> updateUser(String userId, AdminUserDraft draft);

  /// `DELETE /admin/users/{userId}`
  Future<void> deleteUser(String userId);

  /// `GET /admin/roles/{ROLE}/permissions`
  Future<RolePermissions> fetchRolePermissions(AdminRole role);

  /// `PUT /admin/roles/{ROLE}/permissions`
  Future<RolePermissions> updateRolePermissions(
    AdminRole role,
    Set<String> granted,
  );
}
