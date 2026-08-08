import '../../../../core/api/complex_scope.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../models/sports_complex_model.dart';
import '../../../../repositories/sports_complex_repository.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/admin_role.dart';
import '../../domain/entities/coach.dart';
import '../../domain/entities/sport.dart';
import '../../domain/repositories/coach_repository.dart';
import '../../domain/repositories/sport_repository.dart';
import '../catalogue_fetch.dart';
import '../datasources/coach_remote_data_source.dart';
import '../models/coach_model.dart';
import 'sport_repository_impl.dart';

/// [CoachRepository] over the JWT backend.
///
/// The two dropdown catalogues are delegated rather than re-fetched: sports
/// come from the Sports module's own repository and venues from the app-wide
/// [SportsComplexRepository] — the same one the Employee, Security Guard,
/// Complex Admin and Sport forms use, so none of them can disagree about what
/// exists.
class CoachRepositoryImpl implements CoachRepository {
  CoachRepositoryImpl({
    CoachRemoteDataSource? remote,
    SportRepository? sports,
    SportsComplexRepository? complexes,
  }) : _remote = remote ?? CoachRemoteDataSource(),
       _sports = sports ?? SportRepositoryImpl(),
       _complexes = complexes ?? SportsComplexRepository.instance;

  final CoachRemoteDataSource _remote;
  final SportRepository _sports;
  final SportsComplexRepository _complexes;

  @override
  Future<List<Coach>> fetchCoaches({
    AdminUserStatus? status,
    int? sportId,
  }) async {
    // Filtering by sport is a separate route, so it wins when both are set and
    // the controller narrows by status over the rows that come back. That route
    // documents no paging, so only the main list walks pages.
    final List<Coach> coaches;
    if (sportId != null) {
      final response = await _remote.listBySport(sportId);
      if (!response.isOk) throw response.toException();
      coaches = CoachMapper.listFrom(response.data);
    } else {
      coaches = await fetchCatalogue<Coach>(
        request: (page) => _remote.list(status: status, page: page),
        parse: (response) => CoachMapper.listFrom(response.data),
        identity: (coach) => coach.id,
        label: 'coaches',
      );
    }

    // `GET /coaches` is scoped by the backend from the JWT, so nothing is
    // appended to the URL. This is a second line of defence only, for a payload
    // that turns out to be estate-wide: a row belonging to another venue is
    // dropped, a row that reports no venue is kept.
    final scoped = ComplexScope.restrict(coaches, (c) => c.sportComplexId);

    AdminLog.data(
      'Coaches → ${scoped.length}'
      '${scoped.length == coaches.length ? '' : ' (of ${coaches.length}, venue-scoped)'}',
    );
    return scoped;
  }

  @override
  Future<Coach> fetchCoach(int id) async {
    final response = await _remote.detail(id);
    if (!response.isOk) throw response.toException();

    final coach = CoachMapper.fromJson(response.payload);
    AdminLog.data('Coach detail → $coach');
    return coach;
  }

  @override
  Future<CoachStats> fetchStats(int id) async {
    final response = await _remote.stats(id);
    if (!response.isOk) throw response.toException();

    final stats = CoachStatsMapper.fromJson(response.payload);
    AdminLog.data('Coach $id stats → $stats');
    return stats;
  }

  @override
  Future<Coach> createCoach(CoachDraft draft) async {
    final body = draft.toCreateJson();

    // Fail before the round trip rather than let the server reject a body it
    // could never accept.
    if ((body['name'] as String).isEmpty) {
      throw const ValidationException('Give the coach a name.');
    }
    if ((body['email'] as String).isEmpty) {
      throw const ValidationException('An email address is required.');
    }
    if ((body['password'] as String).isEmpty) {
      throw const ValidationException('Set an initial password.');
    }
    if (body['sportId'] == null) {
      throw const ValidationException('Pick a sport.');
    }
    if (body['sportComplexId'] == null) {
      throw const ValidationException('Pick a sports complex.');
    }

    final response = await _remote.create(body);
    if (!response.isOk) throw response.toException();

    final created = CoachMapper.maybeFromBody(response.data);
    AdminLog.success('Created coach ${created?.id ?? '(id not echoed)'}');

    return created ??
        Coach(
          id: 0,
          name: draft.name,
          email: draft.email,
          sportId: draft.sportId,
          sportComplexId: draft.sportComplexId,
        );
  }

  @override
  Future<Coach> updateCoach(int id, CoachDraft draft) async {
    final body = draft.toUpdateJson();
    if (body.isEmpty) {
      throw const BadRequestException('Nothing to update.');
    }

    final response = await _remote.update(id, body);
    if (!response.isOk) throw response.toException();

    AdminLog.success('Updated coach $id');
    return CoachMapper.maybeFromBody(response.data) ?? Coach(id: id);
  }

  @override
  Future<void> deleteCoach(int id) async {
    final response = await _remote.remove(id);
    if (!response.isOk) throw response.toException();
    AdminLog.success('Deleted coach $id');
  }

  @override
  Future<CoachCredentials> fetchCredentials(int id) async {
    final response = await _remote.credentials(id);
    if (!response.isOk) throw response.toException();

    final credentials = CoachCredentialsMapper.fromJson(response.payload);

    // Logs whether a password came back, never the password itself.
    AdminLog.data(
      'Credentials for coach $id → '
      'password ${credentials.hasPassword ? 'present' : 'absent'}',
    );
    return credentials;
  }

  @override
  Future<void> resetPassword(int id, String password) async {
    final response = await _remote.resetPassword(id, password);
    if (!response.isOk) throw response.toException();
    AdminLog.success('Password reset for coach $id');
  }

  @override
  Future<String> uploadImage(String filePath, {String? filename}) async {
    final response = await _remote.uploadImage(filePath, filename: filename);
    if (!response.isOk) throw response.toException();

    final url = CoachMapper.uploadedUrlFrom(response.data);
    if (url == null || url.isEmpty) {
      // Without a URL there is nothing to put in the coach payload, so this is
      // a failure even though the HTTP call succeeded.
      throw const ServerException(
        'The image uploaded but the server did not return its URL.',
      );
    }

    AdminLog.success('Uploaded coach image');
    return url;
  }

  @override
  Future<List<Sport>> fetchSports({bool refresh = false}) async {
    // `/sports` has no cache of its own, so `refresh` only distinguishes an
    // explicit retry in the log.
    final sports = await _sports.fetchSports();
    AdminLog.data('Sports for coaches module → ${sports.length}');
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
    AdminLog.data('Complexes for coaches module → ${complexes.length}');
    return complexes;
  }
}
