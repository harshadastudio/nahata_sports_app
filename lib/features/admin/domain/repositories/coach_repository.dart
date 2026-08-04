import '../../../../models/sports_complex_model.dart';
import '../entities/admin_role.dart';
import '../entities/coach.dart';
import '../entities/sport.dart';

/// Coach CRUD, password management, per-coach statistics and image upload.
///
/// The list route is unpaginated but does filter server-side on status, and
/// filtering by sport is a route of its own — so [fetchCoaches] takes both and
/// the controller applies search, complex, category, sorting and paging over
/// what comes back. Reads and writes throw so the page or dialog can surface
/// the server's own message.
abstract class CoachRepository {
  /// `GET /coaches?status=`, or `GET /coaches/sport/{sportId}` when [sportId]
  /// is set — the sport filter has its own route rather than a query
  /// parameter, so the two cannot be combined server-side. When both are
  /// given, the sport route is called and the status is applied locally by the
  /// controller.
  Future<List<Coach>> fetchCoaches({AdminUserStatus? status, int? sportId});

  /// `GET /coaches/{coachId}`
  ///
  /// Undocumented in the module spec, which describes the drawer as the coach
  /// record plus `/stats`. Callers must treat a failure here as "no extra
  /// detail", not as a broken drawer.
  Future<Coach> fetchCoach(int id);

  /// `GET /coaches/{coachId}/stats`
  Future<CoachStats> fetchStats(int id);

  /// `POST /coaches`
  Future<Coach> createCoach(CoachDraft draft);

  /// `PUT /coaches/{coachId}`
  Future<Coach> updateCoach(int id, CoachDraft draft);

  /// `DELETE /coaches/{coachId}`
  Future<void> deleteCoach(int id);

  /// `GET /coaches/{coachId}/password`
  ///
  /// Returned to the caller and never cached: the dialog owns the credentials
  /// for as long as it is open.
  Future<CoachCredentials> fetchCredentials(int id);

  /// `POST /coaches/{coachId}/reset-password`
  Future<void> resetPassword(int id, String password);

  /// `POST /coaches/upload-image` — multipart, field `image`.
  ///
  /// Returns the URL the API stored, which is what the create/update payload
  /// carries in its `image` field.
  Future<String> uploadImage(String filePath, {String? filename});

  /// Sports for the form dropdown and the sport filter, from `GET /sports`.
  Future<List<Sport>> fetchSports({bool refresh});

  /// Venues for the form dropdown and the complex filter, from
  /// `GET /sports-complexes`.
  Future<List<SportsComplex>> fetchSportComplexes({bool refresh});
}