import '../../../../core/network/api_exception.dart';
import '../../../../models/sports_complex_model.dart';
import '../../../../repositories/sports_complex_repository.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/complex_admin.dart';
import '../../domain/entities/paged.dart';
import '../../domain/repositories/complex_admin_repository.dart';
import '../datasources/complex_admin_remote_data_source.dart';
import '../models/complex_admin_model.dart';

/// [ComplexAdminRepository] over the JWT backend.
///
/// The venue list is delegated to the app's existing
/// [SportsComplexRepository] rather than re-fetched here, so the console and
/// the customer screens cannot disagree about what venues exist.
class ComplexAdminRepositoryImpl implements ComplexAdminRepository {
  ComplexAdminRepositoryImpl({
    ComplexAdminRemoteDataSource? remote,
    SportsComplexRepository? complexes,
  }) : _remote = remote ?? ComplexAdminRemoteDataSource(),
       _complexes = complexes ?? SportsComplexRepository.instance;

  final ComplexAdminRemoteDataSource _remote;
  final SportsComplexRepository _complexes;

  @override
  Future<Paged<ComplexAdmin>> fetchComplexAdmins({
    int page = 1,
    int limit = 20,
    String? search,
  }) async {
    final response = await _remote.list(
      page: page,
      limit: limit,
      search: search,
    );
    if (!response.isOk) throw response.toException();

    final result = ComplexAdminMapper.pageFrom(
      response.data,
      fallbackPage: page,
      fallbackLimit: limit,
    );
    AdminLog.data('Complex admins → $result');
    return result;
  }

  @override
  Future<ComplexAdmin> createComplexAdmin(ComplexAdminDraft draft) async {
    final body = draft.toCreateJson();

    // Fail before the round trip rather than letting the server reject a body
    // it could never accept.
    if ((body['sportComplexId']) == null) {
      throw const ValidationException('Pick a sports complex.');
    }

    final response = await _remote.create(body);
    if (!response.isOk) throw response.toException();

    final created = ComplexAdminMapper.maybeFromBody(response.data);
    AdminLog.success(
      'Created complex admin ${created?.id ?? '(id not echoed)'}',
    );

    // A create that does not echo the row is still a success — the reload that
    // follows picks it up.
    return created ??
        ComplexAdmin(
          id: '',
          name: draft.name,
          email: draft.email,
          phone: draft.phone,
          sportComplexId: draft.sportComplexId,
        );
  }

  @override
  Future<ComplexAdmin> updateComplexAdmin(
    String id,
    ComplexAdminDraft draft,
  ) async {
    final body = draft.toUpdateJson();
    if (body.isEmpty) {
      throw const BadRequestException('Nothing to update.');
    }

    final response = await _remote.update(id, body);
    if (!response.isOk) throw response.toException();

    AdminLog.success('Updated complex admin $id');
    return ComplexAdminMapper.maybeFromBody(response.data) ??
        ComplexAdmin(id: id);
  }

  @override
  Future<void> deleteComplexAdmin(String id) async {
    final response = await _remote.remove(id);
    if (!response.isOk) throw response.toException();
    AdminLog.success('Deleted complex admin $id');
  }

  @override
  Future<List<SportsComplex>> fetchSportComplexes({
    bool refresh = false,
  }) async {
    // `includeHidden` so an admin can be assigned to a complex that is not
    // currently shown on the storefront.
    final complexes = await _complexes.fetchComplexes(
      refresh: refresh,
      includeHidden: true,
    );
    AdminLog.data('Sport complexes for picker → ${complexes.length}');
    return complexes;
  }
}
