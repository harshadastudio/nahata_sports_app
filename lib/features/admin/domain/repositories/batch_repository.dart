import '../../../../models/sports_complex_model.dart';
import '../entities/admin_role.dart';
import '../entities/batch.dart';
import '../entities/coach.dart';
import '../entities/sport.dart';

/// Batch CRUD, per-batch statistics, the two grouped breakdowns, and the three
/// catalogues the batch form needs.
///
/// Unlike `/sports` and `/coaches`, `GET /batches` really is paginated — it
/// answers `{ batches, currentPage, totalPages, totalItems, itemsPerPage }` —
/// so [fetchBatches] returns a [BatchPageResult] rather than a bare list, and
/// the controller only falls back to loading the whole catalogue when a filter
/// the route does not support is in force. Reads and writes both throw so the
/// page or dialog can surface the server's own message.
abstract class BatchRepository {
  /// `GET /batches?status=&sportId=&page=&limit=`
  Future<BatchPageResult> fetchBatches({
    AdminUserStatus? status,
    int? sportId,
    int page,
    int limit,
  });

  /// Every page of `/batches` for the current server-side filters, up to
  /// [maxPages].
  ///
  /// Needed because the coach, complex, age-group and search filters have no
  /// query parameter: applying them to one page at a time would silently hide
  /// matches sitting on page two. The cap is reported through [onCapped] so the
  /// page can say so rather than quietly truncating.
  Future<List<AdminBatch>> fetchAllBatches({
    AdminUserStatus? status,
    int? sportId,
    int limit,
    int maxPages,
    void Function(int loaded, int total)? onCapped,
  });

  /// `GET /batches/{batchId}`
  Future<AdminBatch> fetchBatch(int id);

  /// `GET /batches/{batchId}/stats`
  Future<BatchStatistics> fetchStats(int id);

  /// `GET /batches/sport/{sportId}` — the sport-wise breakdown. Unpaginated.
  Future<List<AdminBatch>> fetchBatchesBySport(int sportId);

  /// `GET /batches/coach/{coachId}` — the coach-wise breakdown. Unpaginated.
  Future<CoachBatchLoad> fetchBatchesByCoach(int coachId, {String? coachName});

  /// `POST /batches`
  Future<AdminBatch> createBatch(BatchDraft draft);

  /// `PUT /batches/{batchId}`
  Future<AdminBatch> updateBatch(int id, BatchDraft draft);

  /// `PATCH /batches/{batchId}/status`
  Future<void> setStatus(int id, AdminUserStatus status);

  /// `DELETE /batches/{batchId}`
  Future<void> deleteBatch(int id);

  /// `POST /batches/upload-image` — multipart, field `image`.
  ///
  /// Not part of the documented batch routes; see `ApiEndpoints
  /// .batchUploadImage`. Throws like any other write, so the image field can
  /// explain itself without blocking the rest of the form.
  Future<String> uploadImage(String filePath, {String? filename});

  /// Sports for the form dropdown and the sport filter, from `GET /sports`.
  Future<List<Sport>> fetchSports({bool refresh});

  /// Coaches for the form dropdown and the coach filter, from `GET /coaches`.
  Future<List<Coach>> fetchCoaches({bool refresh});

  /// Venues for the form dropdown and the complex filter, from
  /// `GET /sports-complexes`.
  Future<List<SportsComplex>> fetchSportComplexes({bool refresh});
}
