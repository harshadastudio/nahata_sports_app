import '../../../../core/api/complex_scope.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../models/sports_complex_model.dart';
import '../../../../repositories/sports_complex_repository.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/admin_role.dart';
import '../../domain/entities/sport.dart';
import '../../domain/repositories/sport_repository.dart';
import '../catalogue_fetch.dart';
import '../datasources/sport_remote_data_source.dart';
import '../models/sport_model.dart';

/// [SportRepository] over the JWT backend.
///
/// The venue list is delegated to the app's shared [SportsComplexRepository],
/// the same one the Employee, Security Guard and Complex Admin forms use, so
/// none of them can disagree about what venues exist.
class SportRepositoryImpl implements SportRepository {
  SportRepositoryImpl({
    SportRemoteDataSource? remote,
    SportsComplexRepository? complexes,
  }) : _remote = remote ?? SportRemoteDataSource(),
       _complexes = complexes ?? SportsComplexRepository.instance;

  final SportRemoteDataSource _remote;
  final SportsComplexRepository _complexes;

  @override
  Future<List<Sport>> fetchSports({
    AdminUserStatus? status,
    int? complexId,
  }) async {
    // A venue-scoped session cannot browse another complex's sports, so the
    // filter is pinned to its own; an ADMIN keeps whatever it picked, including
    // "All". `sportComplexId` is a filter this route documents — it is not
    // being bolted onto a URL that never had one.
    final effectiveComplex = ComplexScope.pin(complexId);

    final sports = await fetchCatalogue<Sport>(
      request: (page) => _remote.list(
        status: status,
        complexId: effectiveComplex,
        page: page,
      ),
      parse: (response) => SportMapper.listFrom(response.data),
      identity: (sport) => sport.id,
      label: 'sports',
    );

    AdminLog.data('Sports → ${sports.length}');
    return sports;
  }

  @override
  Future<Sport> fetchSport(int id) async {
    final response = await _remote.detail(id);
    if (!response.isOk) throw response.toException();

    final sport = SportMapper.fromJson(response.payload);
    AdminLog.data('Sport detail → $sport');
    return sport;
  }

  @override
  Future<SportStats> fetchStats(int id) async {
    final response = await _remote.stats(id);
    if (!response.isOk) throw response.toException();

    final stats = SportStatsMapper.fromJson(response.payload);
    AdminLog.data('Sport $id stats → $stats');
    return stats;
  }

  @override
  Future<Sport> createSport(SportDraft draft) async {
    final body = draft.toCreateJson();

    // Fail before the round trip rather than let the server reject a body it
    // could never accept.
    if ((body['name'] as String).isEmpty) {
      throw const ValidationException('Give the sport a name.');
    }
    if (body['sportComplexId'] == null) {
      throw const ValidationException('Pick a sports complex.');
    }

    final response = await _remote.create(body);
    if (!response.isOk) throw response.toException();

    final created = SportMapper.maybeFromBody(response.data);
    AdminLog.success('Created sport ${created?.id ?? '(id not echoed)'}');

    return created ??
        Sport(
          id: 0,
          name: draft.name,
          sportComplexId: draft.sportComplexId,
          categoryRaw: draft.category?.slug,
        );
  }

  @override
  Future<Sport> updateSport(int id, SportDraft draft) async {
    final body = draft.toUpdateJson();
    if (body.isEmpty) {
      throw const BadRequestException('Nothing to update.');
    }

    final response = await _remote.update(id, body);
    if (!response.isOk) throw response.toException();

    AdminLog.success('Updated sport $id');
    return SportMapper.maybeFromBody(response.data) ?? Sport(id: id);
  }

  @override
  Future<void> deleteSport(int id) async {
    final response = await _remote.remove(id);
    if (!response.isOk) throw response.toException();
    AdminLog.success('Deleted sport $id');
  }

  @override
  Future<void> setStatus(int id, AdminUserStatus status) async {
    final response = await _remote.setStatus(id, status);
    if (!response.isOk) throw response.toException();
    AdminLog.success('Sport $id status → ${status.slug}');
  }

  @override
  Future<void> setVisibility(int id, bool showOnFrontend) async {
    final response = await _remote.setVisibility(id, showOnFrontend);
    if (!response.isOk) throw response.toException();
    AdminLog.success('Sport $id showOnFrontend → $showOnFrontend');
  }

  @override
  Future<void> assignComplex(int id, int sportComplexId) async {
    final response = await _remote.assignGround(id, sportComplexId);
    if (!response.isOk) throw response.toException();
    AdminLog.success('Sport $id assigned to complex $sportComplexId');
  }

  @override
  Future<String> uploadImage(String filePath, {String? filename}) async {
    final response = await _remote.uploadImage(filePath, filename: filename);
    if (!response.isOk) throw response.toException();

    final url = SportMapper.uploadedUrlFrom(response.data);
    if (url == null || url.isEmpty) {
      // Without a URL there is nothing to put in the sport payload, so this is
      // a failure even though the HTTP call succeeded.
      throw const ServerException(
        'The image uploaded but the server did not return its URL.',
      );
    }

    AdminLog.success('Uploaded sport image');
    return url;
  }

  @override
  Future<List<SportsComplex>> fetchSportComplexes({
    bool refresh = false,
  }) async {
    final complexes = await _complexes.fetchComplexes(
      refresh: refresh,
      includeHidden: true,
    );
    AdminLog.data('Sport complexes for sports module → ${complexes.length}');
    return complexes;
  }
}
