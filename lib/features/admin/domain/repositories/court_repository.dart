import '../../../../models/sports_complex_model.dart';
import '../entities/admin_role.dart';
import '../entities/court.dart';
import '../entities/sport.dart';

/// Court CRUD, storefront visibility, and the two catalogues the court form
/// needs.
///
/// The list route filters server-side on the complex and the sport — the two
/// parameters it documents — so [fetchCourts] takes those and the controller
/// applies search, status, surface and visibility over what comes back. Reads
/// and writes both throw so the page or dialog can surface the server's own
/// message.
abstract class CourtRepository {
  /// `GET /courts?sportComplexId=&sportId=`
  Future<List<Court>> fetchCourts({int? complexId, int? sportId});

  /// `GET /courts/{courtId}`
  Future<Court> fetchCourt(int id);

  /// `POST /courts`
  Future<Court> createCourt(CourtDraft draft);

  /// `PUT /courts/{courtId}`
  Future<Court> updateCourt(int id, CourtDraft draft);

  /// `PATCH /courts/{courtId}/show-on-frontend`
  Future<void> setVisibility(int id, bool showOnFrontend);

  /// `DELETE /courts/{courtId}`
  Future<void> deleteCourt(int id);

  /// `POST /courts/upload-image` — multipart, field `image`.
  ///
  /// Not part of the documented court routes; named after the four upload
  /// routes that are. A failure is surfaced in the image field and never
  /// blocks saving the court itself.
  Future<String> uploadImage(String filePath, {String? filename});

  /// Sports for the form dropdown and the sport filter, from `GET /sports`.
  Future<List<Sport>> fetchSports({bool refresh});

  /// Venues for the form dropdown and the complex filter, from
  /// `GET /sports-complexes`.
  Future<List<SportsComplex>> fetchSportComplexes({bool refresh});

  /// Convenience for the status write, which the court routes express as a
  /// `PUT` of that one field rather than a route of its own.
  Future<void> setStatus(int id, AdminUserStatus status);
}
