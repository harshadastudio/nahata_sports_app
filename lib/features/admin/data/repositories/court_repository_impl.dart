import '../../../../core/network/api_exception.dart';
import '../../../../models/sports_complex_model.dart';
import '../../../../repositories/sports_complex_repository.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/admin_role.dart';
import '../../domain/entities/court.dart';
import '../../domain/entities/sport.dart';
import '../../domain/repositories/court_repository.dart';
import '../../domain/repositories/sport_repository.dart';
import '../datasources/court_remote_data_source.dart';
import '../models/court_model.dart';
import 'sport_repository_impl.dart';

/// [CourtRepository] over the JWT backend.
///
/// The two dropdown catalogues are delegated rather than re-fetched: sports
/// come from the Sports module's repository and venues from the app-wide
/// [SportsComplexRepository], so no two screens can disagree about what exists.
class CourtRepositoryImpl implements CourtRepository {
  CourtRepositoryImpl({
    CourtRemoteDataSource? remote,
    SportRepository? sports,
    SportsComplexRepository? complexes,
  }) : _remote = remote ?? CourtRemoteDataSource(),
       _sports = sports ?? SportRepositoryImpl(),
       _complexes = complexes ?? SportsComplexRepository.instance;

  final CourtRemoteDataSource _remote;
  final SportRepository _sports;
  final SportsComplexRepository _complexes;

  @override
  Future<List<Court>> fetchCourts({int? complexId, int? sportId}) async {
    final response = await _remote.list(
      complexId: complexId,
      sportId: sportId,
    );
    if (!response.isOk) throw response.toException();

    final courts = CourtMapper.listFrom(response.data);
    AdminLog.data('Courts → ${courts.length}');
    return courts;
  }

  @override
  Future<Court> fetchCourt(int id) async {
    final response = await _remote.detail(id);
    if (!response.isOk) throw response.toException();

    final court = CourtMapper.fromJson(response.payload);
    AdminLog.data('Court detail → $court');
    return court;
  }

  @override
  Future<Court> createCourt(CourtDraft draft) async {
    final body = draft.toCreateJson();

    // Fail before the round trip rather than let the server reject a body it
    // could never accept. These are exactly the fields the form marks required.
    if ((body['name'] as String).isEmpty) {
      throw const ValidationException('Give the court a name.');
    }
    if (body['sportComplexId'] == null) {
      throw const ValidationException('Pick a sports complex.');
    }
    if (body['sportId'] == null) {
      throw const ValidationException('Pick a sport.');
    }
    if (body['capacity'] == null) {
      throw const ValidationException('Set the court capacity.');
    }
    if (body['hourlyRate'] == null) {
      throw const ValidationException('Set the hourly rate.');
    }

    final response = await _remote.create(body);
    if (!response.isOk) throw response.toException();

    final created = CourtMapper.maybeFromBody(response.data);
    AdminLog.success('Created court ${created?.id ?? '(id not echoed)'}');

    return created ??
        Court(
          id: 0,
          name: draft.name,
          sportId: draft.sportId,
          sportComplexId: draft.sportComplexId,
        );
  }

  @override
  Future<Court> updateCourt(int id, CourtDraft draft) async {
    final body = draft.toUpdateJson();
    if (body.isEmpty) {
      throw const BadRequestException('Nothing to update.');
    }

    final response = await _remote.update(id, body);
    if (!response.isOk) throw response.toException();

    AdminLog.success('Updated court $id');
    return CourtMapper.maybeFromBody(response.data) ?? Court(id: id);
  }

  @override
  Future<void> setVisibility(int id, bool showOnFrontend) async {
    final response = await _remote.setVisibility(id, showOnFrontend);
    if (!response.isOk) throw response.toException();
    AdminLog.success('Court $id showOnFrontend → $showOnFrontend');
  }

  @override
  Future<void> setStatus(int id, AdminUserStatus status) async {
    final response = await _remote.setStatus(id, status);
    if (!response.isOk) throw response.toException();
    AdminLog.success('Court $id status → ${status.slug}');
  }

  @override
  Future<void> deleteCourt(int id) async {
    final response = await _remote.remove(id);
    if (!response.isOk) throw response.toException();
    AdminLog.success('Deleted court $id');
  }

  @override
  Future<String> uploadImage(String filePath, {String? filename}) async {
    final response = await _remote.uploadImage(filePath, filename: filename);
    if (!response.isOk) throw response.toException();

    final url = CourtMapper.uploadedUrlFrom(response.data);
    if (url == null || url.isEmpty) {
      // Without a URL there is nothing to put in the court payload, so this is
      // a failure even though the HTTP call succeeded.
      throw const ServerException(
        'The image uploaded but the server did not return its URL.',
      );
    }

    AdminLog.success('Uploaded court image');
    return url;
  }

  @override
  Future<List<Sport>> fetchSports({bool refresh = false}) async {
    final sports = await _sports.fetchSports();
    AdminLog.data('Sports for courts module → ${sports.length}');
    return sports;
  }

  @override
  Future<List<SportsComplex>> fetchSportComplexes({
    bool refresh = false,
  }) async {
    final complexes = await _complexes.fetchComplexes(
      refresh: refresh,
      includeHidden: true,
    );
    AdminLog.data('Complexes for courts module → ${complexes.length}');
    return complexes;
  }
}
