import '../../../../core/network/api_exception.dart';
import '../../../../models/sports_complex_model.dart';
import '../../../../repositories/sports_complex_repository.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/admin_role.dart';
import '../../domain/entities/employee_vocabulary.dart';
import '../../domain/entities/paged.dart';
import '../../domain/entities/security_guard.dart';
import '../../domain/repositories/security_guard_repository.dart';
import '../datasources/security_guard_remote_data_source.dart';
import '../models/security_guard_model.dart';

/// [SecurityGuardRepository] over the JWT backend.
///
/// The venue list is delegated to the app's shared [SportsComplexRepository],
/// the same one the Employee and Complex Admin forms use, so the three cannot
/// disagree about what venues exist.
class SecurityGuardRepositoryImpl implements SecurityGuardRepository {
  SecurityGuardRepositoryImpl({
    SecurityGuardRemoteDataSource? remote,
    SportsComplexRepository? complexes,
  }) : _remote = remote ?? SecurityGuardRemoteDataSource(),
       _complexes = complexes ?? SportsComplexRepository.instance;

  final SecurityGuardRemoteDataSource _remote;
  final SportsComplexRepository _complexes;

  @override
  Future<Paged<SecurityGuard>> fetchGuards({
    int page = 1,
    int limit = 20,
    String? search,
    AdminUserStatus? status,
    Shift? shift,
    int? sportComplexId,
    String? assignedArea,
    String? sortBy,
    bool descending = false,
  }) async {
    final response = await _remote.list(
      page: page,
      limit: limit,
      search: search,
      status: status,
      shift: shift,
      sportComplexId: sportComplexId,
      assignedArea: assignedArea,
      sortBy: sortBy,
      descending: descending,
    );
    if (!response.isOk) throw response.toException();

    final result = SecurityGuardMapper.pageFrom(
      response.data,
      fallbackPage: page,
      fallbackLimit: limit,
    );
    AdminLog.data('Security guards → $result');
    return result;
  }

  @override
  Future<SecurityGuard> fetchGuard(String id) async {
    final response = await _remote.detail(id);
    if (!response.isOk) throw response.toException();

    final guard = SecurityGuardMapper.fromJson(response.payload);
    AdminLog.data('Security guard detail → $guard');
    return guard;
  }

  @override
  Future<SecurityGuard> createGuard(SecurityGuardDraft draft) async {
    final body = draft.toCreateJson();

    // Fail before the round trip rather than let the server reject a body it
    // could never accept.
    if (body['sportComplexId'] == null) {
      throw const ValidationException('Pick a sports complex.');
    }

    final response = await _remote.create(body);
    if (!response.isOk) throw response.toException();

    final created = SecurityGuardMapper.maybeFromBody(response.data);
    AdminLog.success(
      'Created security guard ${created?.id ?? '(id not echoed)'}',
    );

    return created ??
        SecurityGuard(
          id: '',
          guardCode: draft.guardCode,
          fullName: draft.fullName,
          email: draft.email,
          phone: draft.phone,
        );
  }

  @override
  Future<SecurityGuard> updateGuard(
    String id,
    SecurityGuardDraft draft,
  ) async {
    final body = draft.toUpdateJson();
    if (body.isEmpty) {
      throw const BadRequestException('Nothing to update.');
    }

    final response = await _remote.update(id, body);
    if (!response.isOk) throw response.toException();

    AdminLog.success('Updated security guard $id');
    return SecurityGuardMapper.maybeFromBody(response.data) ??
        SecurityGuard(id: id);
  }

  @override
  Future<void> deleteGuard(String id) async {
    final response = await _remote.remove(id);
    if (!response.isOk) throw response.toException();
    AdminLog.success('Deleted security guard $id');
  }

  @override
  Future<SecurityGuardCredentials> fetchCredentials(String id) async {
    final response = await _remote.credentials(id);
    if (!response.isOk) throw response.toException();

    final credentials = SecurityGuardCredentialsMapper.fromJson(
      response.payload,
    );

    // Logs whether a password came back, never the password itself.
    AdminLog.data(
      'Credentials for guard $id → '
      'password ${credentials.hasPassword ? 'present' : 'absent'}',
    );
    return credentials;
  }

  @override
  Future<void> resetPassword(String id, String password) async {
    final response = await _remote.resetPassword(id, password);
    if (!response.isOk) throw response.toException();
    AdminLog.success('Password reset for security guard $id');
  }

  @override
  Future<List<SportsComplex>> fetchSportComplexes({
    bool refresh = false,
  }) async {
    final complexes = await _complexes.fetchComplexes(
      refresh: refresh,
      includeHidden: true,
    );
    AdminLog.data('Sport complexes for guard form → ${complexes.length}');
    return complexes;
  }
}
