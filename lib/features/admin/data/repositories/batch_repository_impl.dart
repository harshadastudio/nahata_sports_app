import '../../../../core/network/api_exception.dart';
import '../../../../models/sports_complex_model.dart';
import '../../../../repositories/sports_complex_repository.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/admin_role.dart';
import '../../domain/entities/batch.dart';
import '../../domain/entities/coach.dart';
import '../../domain/entities/sport.dart';
import '../../domain/repositories/batch_repository.dart';
import '../../domain/repositories/coach_repository.dart';
import '../../domain/repositories/sport_repository.dart';
import '../datasources/batch_remote_data_source.dart';
import '../models/batch_admin_model.dart';
import 'coach_repository_impl.dart';
import 'sport_repository_impl.dart';

/// [BatchRepository] over the JWT backend.
///
/// The three dropdown catalogues are delegated rather than re-fetched: sports
/// and coaches come from their own modules' repositories and venues from the
/// app-wide [SportsComplexRepository], so no two screens can disagree about
/// what exists.
class BatchRepositoryImpl implements BatchRepository {
  BatchRepositoryImpl({
    BatchRemoteDataSource? remote,
    SportRepository? sports,
    CoachRepository? coaches,
    SportsComplexRepository? complexes,
  }) : _remote = remote ?? BatchRemoteDataSource(),
       _sports = sports ?? SportRepositoryImpl(),
       _coaches = coaches ?? CoachRepositoryImpl(),
       _complexes = complexes ?? SportsComplexRepository.instance;

  final BatchRemoteDataSource _remote;
  final SportRepository _sports;
  final CoachRepository _coaches;
  final SportsComplexRepository _complexes;

  @override
  Future<BatchPageResult> fetchBatches({
    AdminUserStatus? status,
    int? sportId,
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _remote.list(
      status: status,
      sportId: sportId,
      page: page,
      limit: limit,
    );
    if (!response.isOk) throw response.toException();

    final result = BatchMapper.pageFrom(
      response.data,
      requestedPage: page,
      requestedLimit: limit,
    );
    AdminLog.data('Batches → $result');
    return result;
  }

  @override
  Future<List<AdminBatch>> fetchAllBatches({
    AdminUserStatus? status,
    int? sportId,
    int limit = 100,
    int maxPages = 20,
    void Function(int loaded, int total)? onCapped,
  }) async {
    final all = <AdminBatch>[];
    var page = 1;
    var totalItems = 0;

    while (page <= maxPages) {
      final result = await fetchBatches(
        status: status,
        sportId: sportId,
        page: page,
        limit: limit,
      );

      all.addAll(result.batches);
      totalItems = result.totalItems;

      if (!result.hasMore || result.batches.isEmpty) break;
      page++;
    }

    // Reported rather than swallowed: a filter applied over a truncated
    // catalogue would look like "no matches" instead of "not all loaded".
    if (page > maxPages && totalItems > all.length) {
      AdminLog.failure(
        'Batch catalogue stopped at the $maxPages page cap — '
        '${all.length} of $totalItems loaded',
      );
      onCapped?.call(all.length, totalItems);
    }

    AdminLog.data('Batch catalogue → ${all.length}');
    return all;
  }

  @override
  Future<AdminBatch> fetchBatch(int id) async {
    final response = await _remote.detail(id);
    if (!response.isOk) throw response.toException();

    final batch = BatchMapper.fromJson(response.payload);
    AdminLog.data('Batch detail → $batch');
    return batch;
  }

  @override
  Future<BatchStatistics> fetchStats(int id) async {
    final response = await _remote.stats(id);
    if (!response.isOk) throw response.toException();

    final stats = BatchStatsMapper.fromJson(response.payload);
    AdminLog.data('Batch $id stats → $stats');
    return stats;
  }

  @override
  Future<List<AdminBatch>> fetchBatchesBySport(int sportId) async {
    final response = await _remote.bySport(sportId);
    if (!response.isOk) throw response.toException();

    final batches = BatchMapper.listFrom(response.data);
    AdminLog.data('Batches for sport $sportId → ${batches.length}');
    return batches;
  }

  @override
  Future<CoachBatchLoad> fetchBatchesByCoach(
    int coachId, {
    String? coachName,
  }) async {
    final response = await _remote.byCoach(coachId);
    if (!response.isOk) throw response.toException();

    final batches = BatchMapper.listFrom(response.data);

    // The route may echo the coach's own name; the caller's is the fallback so
    // the header never reads "Coach #12" when the list already knew better.
    final echoed = batches
        .map((batch) => (batch.coachName ?? '').trim())
        .firstWhere((name) => name.isNotEmpty, orElse: () => '');

    AdminLog.data('Batches for coach $coachId → ${batches.length}');
    return CoachBatchLoad(
      coachId: coachId,
      coachName: (coachName ?? '').trim().isNotEmpty
          ? coachName
          : (echoed.isEmpty ? null : echoed),
      batches: batches,
    );
  }

  @override
  Future<AdminBatch> createBatch(BatchDraft draft) async {
    final body = draft.toCreateJson();

    // Fail before the round trip rather than let the server reject a body it
    // could never accept. These are exactly the fields the form marks required.
    if ((body['name'] as String).isEmpty) {
      throw const ValidationException('Give the batch a name.');
    }
    if (body['sportId'] == null) {
      throw const ValidationException('Pick a sport.');
    }
    if (body['coachId'] == null) {
      throw const ValidationException('Pick a coach.');
    }
    if (body['sportComplexId'] == null) {
      throw const ValidationException('Pick a sports complex.');
    }
    if (body['startDate'] == null) {
      throw const ValidationException('Pick a start date.');
    }
    if (body['endDate'] == null) {
      throw const ValidationException('Pick an end date.');
    }
    if (body['fees'] == null) {
      throw const ValidationException('Set the batch fees.');
    }
    if (body['maxStudents'] == null) {
      throw const ValidationException('Set the maximum number of students.');
    }

    final response = await _remote.create(body);
    if (!response.isOk) throw response.toException();

    final created = BatchMapper.maybeFromBody(response.data);
    AdminLog.success('Created batch ${created?.id ?? '(id not echoed)'}');

    return created ??
        AdminBatch(
          id: 0,
          name: draft.name,
          sportId: draft.sportId,
          coachId: draft.coachId,
          sportComplexId: draft.sportComplexId,
        );
  }

  @override
  Future<AdminBatch> updateBatch(int id, BatchDraft draft) async {
    final body = draft.toUpdateJson();
    if (body.isEmpty) {
      throw const BadRequestException('Nothing to update.');
    }

    final response = await _remote.update(id, body);
    if (!response.isOk) throw response.toException();

    AdminLog.success('Updated batch $id');
    return BatchMapper.maybeFromBody(response.data) ?? AdminBatch(id: id);
  }

  @override
  Future<void> setStatus(int id, AdminUserStatus status) async {
    final response = await _remote.setStatus(id, status);
    if (!response.isOk) throw response.toException();
    AdminLog.success('Batch $id status → ${status.slug}');
  }

  @override
  Future<void> deleteBatch(int id) async {
    final response = await _remote.remove(id);
    if (!response.isOk) throw response.toException();
    AdminLog.success('Deleted batch $id');
  }

  @override
  Future<String> uploadImage(String filePath, {String? filename}) async {
    final response = await _remote.uploadImage(filePath, filename: filename);
    if (!response.isOk) throw response.toException();

    final url = BatchMapper.uploadedUrlFrom(response.data);
    if (url == null || url.isEmpty) {
      // Without a URL there is nothing to put in the batch payload, so this is
      // a failure even though the HTTP call succeeded.
      throw const ServerException(
        'The image uploaded but the server did not return its URL.',
      );
    }

    AdminLog.success('Uploaded batch image');
    return url;
  }

  @override
  Future<List<Sport>> fetchSports({bool refresh = false}) async {
    final sports = await _sports.fetchSports();
    AdminLog.data('Sports for batches module → ${sports.length}');
    return sports;
  }

  @override
  Future<List<Coach>> fetchCoaches({bool refresh = false}) async {
    final coaches = await _coaches.fetchCoaches();
    AdminLog.data('Coaches for batches module → ${coaches.length}');
    return coaches;
  }

  @override
  Future<List<SportsComplex>> fetchSportComplexes({
    bool refresh = false,
  }) async {
    final complexes = await _complexes.fetchComplexes(
      refresh: refresh,
      includeHidden: true,
    );
    AdminLog.data('Complexes for batches module → ${complexes.length}');
    return complexes;
  }
}
