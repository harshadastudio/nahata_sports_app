import '../../../../core/network/api_exception.dart';
import '../../../../models/sports_complex_model.dart';
import '../../../../repositories/sports_complex_repository.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/coach.dart';
import '../../domain/entities/coaching_enquiry.dart';
import '../../domain/entities/paged.dart';
import '../../domain/entities/sport.dart';
import '../../domain/repositories/coach_repository.dart';
import '../../domain/repositories/coaching_enquiry_repository.dart';
import '../../domain/repositories/sport_repository.dart';
import '../datasources/coaching_enquiry_remote_data_source.dart';
import '../models/coaching_enquiry_model.dart';
import 'coach_repository_impl.dart';
import 'sport_repository_impl.dart';

/// [CoachingEnquiryRepository] over the JWT backend.
///
/// The coach, sport and venue lists are delegated to the modules that already
/// own them rather than re-fetched here, so the enquiry desk and the rest of
/// the console cannot disagree about what exists.
class CoachingEnquiryRepositoryImpl implements CoachingEnquiryRepository {
  CoachingEnquiryRepositoryImpl({
    CoachingEnquiryRemoteDataSource? remote,
    CoachRepository? coaches,
    SportRepository? sports,
    SportsComplexRepository? complexes,
  }) : _remote = remote ?? CoachingEnquiryRemoteDataSource(),
       _coaches = coaches ?? CoachRepositoryImpl(),
       _sports = sports ?? SportRepositoryImpl(),
       _complexes = complexes ?? SportsComplexRepository.instance;

  final CoachingEnquiryRemoteDataSource _remote;
  final CoachRepository _coaches;
  final SportRepository _sports;
  final SportsComplexRepository _complexes;

  @override
  Future<Paged<CoachingEnquiry>> getEnquiries({
    int page = 1,
    int limit = 20,
    String? search,
    CoachingEnquiryStatus? status,
  }) async {
    final response = await _remote.list(
      page: page,
      limit: limit,
      search: search,
      status: status?.slug,
    );
    if (!response.isOk) throw response.toException();

    final result = CoachingEnquiryMapper.pageFrom(
      response.data,
      fallbackPage: page,
      fallbackLimit: limit,
    );

    _warnIfUnreadable(
      rows: CoachingEnquiryMapper.rowsIn(response.data),
      parsed: result.items.length,
      body: response.data,
    );

    AdminLog.data('Coaching enquiries → $result');
    return result;
  }

  @override
  Future<CoachingEnquiry> getEnquiry(int id) async {
    final response = await _remote.detail(id);
    if (!response.isOk) throw response.toException();

    final enquiry = CoachingEnquiryMapper.maybeFromBody(response.data);
    if (enquiry == null) {
      throw const ParseException('The server did not return this enquiry.');
    }

    AdminLog.data('Coaching enquiry detail → $enquiry');
    return enquiry;
  }

  @override
  Future<CoachingEnquiry> createEnquiry(CoachingEnquiryDraft draft) async {
    final body = draft.toJson();

    // Fail before the round trip rather than let the server reject a body it
    // could never accept.
    if ((body['name'] as String).isEmpty) {
      throw const ValidationException("Enter the enquirer's name.");
    }
    final phone = body['phone'] as String;
    if (phone.isEmpty) {
      throw const ValidationException('Enter a phone number.');
    }
    if (phone.length != 10) {
      throw const ValidationException(
        'The phone number must be exactly 10 digits.',
      );
    }
    final email = body['email'] as String;
    if (email.isEmpty) {
      throw const ValidationException('Enter an email address.');
    }
    if (!RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(email)) {
      throw const ValidationException('Enter a valid email address.');
    }
    if (body['sportId'] == null) {
      throw const ValidationException('Pick the sport they asked about.');
    }
    if (body['sportComplexId'] == null) {
      throw const ValidationException('Pick a sports complex.');
    }
    if ((body['message'] as String).isEmpty) {
      throw const ValidationException('Enter what the enquiry is about.');
    }

    final response = await _remote.create(body);
    if (!response.isOk) throw response.toException();

    final created = CoachingEnquiryMapper.maybeFromBody(response.data);
    AdminLog.success(
      'Logged coaching enquiry ${created?.id ?? '(id not echoed)'}',
    );

    // A create that does not echo the row is still a success — the reload that
    // follows picks it up.
    return created ??
        CoachingEnquiry(
          id: 0,
          name: draft.name,
          phone: draft.normalisedPhone,
          email: draft.email,
          message: draft.message,
          sportId: draft.sportId,
          sportComplexId: draft.sportComplexId,
          statusRaw: CoachingEnquiryStatus.isNew.slug,
        );
  }

  @override
  Future<CoachingEnquiry> updateEnquiry(
    int id,
    CoachingEnquiryUpdate update,
  ) async {
    final body = update.toJson();
    if (body.isEmpty) {
      throw const BadRequestException('Nothing to update.');
    }

    final response = await _remote.update(id, body);
    if (!response.isOk) throw response.toException();

    AdminLog.success('Updated coaching enquiry $id');
    return _resolve(response.data, id: id);
  }

  @override
  Future<CoachingEnquiry> assignCoach({
    required int id,
    required int coachId,
  }) async {
    if (coachId <= 0) {
      throw const ValidationException('Pick a coach to assign.');
    }

    final response = await _remote.assignCoach(id, coachId);
    if (!response.isOk) throw response.toException();

    AdminLog.success('Assigned coach $coachId to enquiry $id');
    return _resolve(response.data, id: id);
  }

  @override
  Future<CoachingEnquiry> updateStatus({
    required int id,
    required CoachingEnquiryStatus status,
  }) async {
    final response = await _remote.updateStatus(id, status.slug);
    if (!response.isOk) throw response.toException();

    AdminLog.success('Enquiry $id → ${status.slug}');
    return _resolve(response.data, id: id);
  }

  @override
  Future<void> deleteEnquiry(int id) async {
    final response = await _remote.remove(id);
    if (!response.isOk) throw response.toException();
    AdminLog.success('Deleted coaching enquiry $id');
  }

  @override
  Future<CoachingEnquiryStats> getStats() async {
    final response = await _remote.stats();
    if (!response.isOk) throw response.toException();

    final stats = CoachingEnquiryMapper.statsFrom(response.data);
    if (stats.isEmpty) {
      // Says which kind of empty this was, and names the keys it did see, so a
      // mapper fix is one edit away.
      final keys = response.data is Map
          ? (response.data as Map).keys.toList()
          : const [];
      AdminLog.data(
        'The stats response carried no counters. Top-level keys: $keys',
      );
    }

    AdminLog.data('Coaching enquiry stats → $stats');
    return stats;
  }

  @override
  Future<List<Coach>> fetchCoaches({bool refresh = false, int? sportId}) async {
    final coaches = await _coaches.fetchCoaches(sportId: sportId);
    AdminLog.data('Coaches for enquiries module → ${coaches.length}');
    return coaches;
  }

  @override
  Future<List<Sport>> fetchSports({bool refresh = false}) async {
    final sports = await _sports.fetchSports();
    AdminLog.data('Sports for enquiries module → ${sports.length}');
    return sports;
  }

  @override
  Future<List<SportsComplex>> fetchSportComplexes({
    bool refresh = false,
  }) async {
    // `includeHidden` so an enquiry can name a venue that is not currently
    // shown on the storefront.
    final complexes = await _complexes.fetchComplexes(
      refresh: refresh,
      includeHidden: true,
    );
    AdminLog.data('Complexes for enquiries module → ${complexes.length}');
    return complexes;
  }

  /// The updated record from a write response.
  ///
  /// The three write routes are documented without a response body, so when
  /// one answers with only `{success, message}` the caller still needs
  /// *something* to re-point the open panel at — the id it just wrote to.
  /// The controller re-reads the record either way; this only decides whether
  /// that read starts from a real row or a stub.
  static CoachingEnquiry _resolve(Object? body, {required int id}) {
    return CoachingEnquiryMapper.maybeFromBody(body) ?? CoachingEnquiry(id: id);
  }

  /// Says in the log which kind of empty an empty list was.
  static void _warnIfUnreadable({
    required List<Map<String, dynamic>> rows,
    required int parsed,
    required Object? body,
  }) {
    if (parsed > 0) return;

    if (rows.isEmpty) {
      final keys = body is Map ? body.keys.toList() : const <String>[];
      AdminLog.data(
        'No coaching enquiries in the response. Top-level keys: $keys — if '
        'the list is under one of these, add it to '
        'CoachingEnquiryMapper.listKeys.',
      );
      return;
    }

    AdminLog.failure(
      '${rows.length} enquiry rows were returned but none carried a readable '
      'id, so all were dropped. Row keys: ${rows.first.keys.toList()}',
    );
  }
}
