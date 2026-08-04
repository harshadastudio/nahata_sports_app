import '../../../../models/sports_complex_model.dart';
import '../entities/admin_role.dart';
import '../entities/employee_vocabulary.dart';
import '../entities/paged.dart';
import '../entities/security_guard.dart';

/// Security guard CRUD, password management, and the venue list its form needs.
///
/// Reads and writes both throw so the page or dialog can surface the server's
/// own message rather than a generic failure.
abstract class SecurityGuardRepository {
  /// `GET /admin/security-guards?page=&limit=&search=` plus the filters.
  Future<Paged<SecurityGuard>> fetchGuards({
    int page,
    int limit,
    String? search,
    AdminUserStatus? status,
    Shift? shift,
    int? sportComplexId,
    String? assignedArea,
    String? sortBy,
    bool descending,
  });

  /// `GET /admin/security-guards/{guardId}`
  Future<SecurityGuard> fetchGuard(String id);

  /// `POST /admin/security-guards`
  Future<SecurityGuard> createGuard(SecurityGuardDraft draft);

  /// `PUT /admin/security-guards/{guardId}`
  Future<SecurityGuard> updateGuard(String id, SecurityGuardDraft draft);

  /// `DELETE /admin/security-guards/{guardId}`
  Future<void> deleteGuard(String id);

  /// `GET /admin/security-guards/{guardId}/password`
  ///
  /// The result is shown once and never persisted.
  Future<SecurityGuardCredentials> fetchCredentials(String id);

  /// `POST /admin/security-guards/{guardId}/reset-password`
  Future<void> resetPassword(String id, String password);

  /// Venues for the form's searchable dropdown, from `GET /sports-complexes`.
  Future<List<SportsComplex>> fetchSportComplexes({bool refresh});
}
