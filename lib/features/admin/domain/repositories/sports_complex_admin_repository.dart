import '../entities/admin_role.dart';
import '../entities/admin_sports_complex.dart';

/// Sports complex CRUD, image management and per-venue statistics.
///
/// The list route is unpaginated, so [fetchComplexes] returns the whole
/// catalogue and the controller pages it locally. Reads and writes both throw
/// so the page or dialog can surface the server's own message.
abstract class SportsComplexAdminRepository {
  /// `GET /sports-complexes` — the full catalogue, including venues hidden
  /// from the storefront.
  Future<List<AdminSportsComplex>> fetchComplexes();

  /// `GET /sports-complexes/city/{city}`
  Future<List<AdminSportsComplex>> fetchComplexesByCity(String city);

  /// `GET /sports-complexes/state/{state}`
  Future<List<AdminSportsComplex>> fetchComplexesByState(String state);

  /// `GET /sports-complexes/{sportComplexId}`
  Future<AdminSportsComplex> fetchComplex(int id);

  /// `GET /sports-complexes/{sportComplexId}/stats`
  Future<SportsComplexStats> fetchStats(int id);

  /// `POST /sports-complexes`
  Future<AdminSportsComplex> createComplex(SportsComplexDraft draft);

  /// `PUT /sports-complexes/{sportComplexId}`
  Future<AdminSportsComplex> updateComplex(int id, SportsComplexDraft draft);

  /// `DELETE /sports-complexes/{sportComplexId}`
  Future<void> deleteComplex(int id);

  /// `PUT /sports-complexes/{sportComplexId}/status`
  Future<void> setStatus(int id, AdminUserStatus status);

  /// `PUT /sports-complexes/{sportComplexId}/show-on-frontend`
  Future<void> setVisibility(int id, bool showOnFrontend);

  /// `POST /sports-complexes/upload-image` — multipart, field `image`.
  ///
  /// Returns the URL the API stored, which is what the create/update payload
  /// carries in its `image` field.
  Future<String> uploadImage(String filePath, {String? filename});

  /// `DELETE /sports-complexes/delete-image?imageUrl=`
  Future<void> deleteImage(String imageUrl);
}
