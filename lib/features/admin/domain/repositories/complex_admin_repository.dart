import '../../../../models/sports_complex_model.dart';
import '../entities/complex_admin.dart';
import '../entities/paged.dart';

/// Complex-admin CRUD, plus the venue list its form needs.
///
/// Reads throw so the page can show the server's reason; writes throw so the
/// dialog can stay open and explain itself.
abstract class ComplexAdminRepository {
  /// `GET /admin/complex-admins?page=&limit=&search=`
  ///
  /// Pagination parameters are sent optimistically. A backend that ignores
  /// them returns the whole list, which [Paged] then reports as a single page —
  /// so the footer stays truthful either way.
  Future<Paged<ComplexAdmin>> fetchComplexAdmins({
    int page,
    int limit,
    String? search,
  });

  /// `POST /admin/complex-admins`
  Future<ComplexAdmin> createComplexAdmin(ComplexAdminDraft draft);

  /// `PUT /admin/complex-admins/{complexAdminId}`
  Future<ComplexAdmin> updateComplexAdmin(String id, ComplexAdminDraft draft);

  /// `DELETE /admin/complex-admins/{complexAdminId}`
  Future<void> deleteComplexAdmin(String id);

  /// The venues offered by the form's searchable dropdown. Never hardcoded —
  /// this comes from `GET /sports-complexes`.
  Future<List<SportsComplex>> fetchSportComplexes({bool refresh});
}
