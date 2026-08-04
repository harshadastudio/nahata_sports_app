import '../../../../models/sports_complex_model.dart';
import '../entities/admin_role.dart';
import '../entities/sport.dart';

/// Sport CRUD, image upload, per-sport statistics and complex assignment.
///
/// The list route is unpaginated but does filter server-side on status and
/// complex, so [fetchSports] takes those two and the controller applies the
/// rest locally. Reads and writes both throw so the page or dialog can surface
/// the server's own message.
abstract class SportRepository {
  /// `GET /sports?status=&sportComplexId=`
  Future<List<Sport>> fetchSports({AdminUserStatus? status, int? complexId});

  /// `GET /sports/{sportId}`
  Future<Sport> fetchSport(int id);

  /// `GET /sports/{sportId}/stats`
  Future<SportStats> fetchStats(int id);

  /// `POST /sports`
  Future<Sport> createSport(SportDraft draft);

  /// `PUT /sports/{sportId}`
  Future<Sport> updateSport(int id, SportDraft draft);

  /// `DELETE /sports/{sportId}`
  Future<void> deleteSport(int id);

  /// `PATCH /sports/{sportId}/status`
  Future<void> setStatus(int id, AdminUserStatus status);

  /// `PATCH /sports/{sportId}/show-on-frontend`
  Future<void> setVisibility(int id, bool showOnFrontend);

  /// `POST /sports/{sportId}/assign-ground`
  Future<void> assignComplex(int id, int sportComplexId);

  /// `POST /sports/upload-image` — multipart, field `image`.
  ///
  /// Returns the URL the API stored, which is what the create/update payload
  /// carries in its `image` field.
  Future<String> uploadImage(String filePath, {String? filename});

  /// Venues for the form dropdown, the complex filter and the assign dialog,
  /// from `GET /sports-complexes`.
  Future<List<SportsComplex>> fetchSportComplexes({bool refresh});
}
