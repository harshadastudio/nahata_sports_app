import '../../../../core/api/complex_scope.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../repositories/sports_complex_repository.dart';
import '../../core/admin_log.dart';
import '../catalogue_fetch.dart';
import '../../domain/entities/admin_role.dart';
import '../../domain/entities/admin_sports_complex.dart';
import '../../domain/repositories/sports_complex_admin_repository.dart';
import '../datasources/sports_complex_remote_data_source.dart';
import '../models/admin_sports_complex_model.dart';

/// [SportsComplexAdminRepository] over the JWT backend.
///
/// Every write invalidates the app-wide [SportsComplexRepository] cache. That
/// repository is what the Employee, Security Guard and Complex Admin venue
/// pickers read, and it caches for the session — without this, renaming or
/// deleting a venue here would leave those forms offering a venue that no
/// longer exists until the app restarted.
class SportsComplexAdminRepositoryImpl implements SportsComplexAdminRepository {
  SportsComplexAdminRepositoryImpl({
    SportsComplexRemoteDataSource? remote,
    SportsComplexRepository? sharedCache,
  }) : _remote = remote ?? SportsComplexRemoteDataSource(),
       _sharedCache = sharedCache ?? SportsComplexRepository.instance;

  final SportsComplexRemoteDataSource _remote;
  final SportsComplexRepository _sharedCache;

  @override
  Future<List<AdminSportsComplex>> fetchComplexes() async {
    // The confirmed URL is `?page=1&limit=100`, but the module consumes the
    // whole catalogue, so the pages are walked. See `fetchCatalogue`.
    final complexes = await fetchCatalogue<AdminSportsComplex>(
      request: (page) => _remote.list(page: page),
      parse: (response) => AdminSportsComplexMapper.listFrom(response.data),
      identity: (complex) => complex.id,
      label: 'sports complexes',
    );

    // A COMPLEX_ADMIN administers one venue. The route is the global catalogue
    // for both roles — there is no confirmed venue-scoped endpoint — so the
    // narrowing happens here, and it uses the session's own id, never a value
    // chosen in the UI and never a constant.
    final scoped = ComplexScope.restrict(complexes, (c) => c.id);

    AdminLog.data(
      'Sports complexes → ${scoped.length}'
      '${scoped.length == complexes.length ? '' : ' (of ${complexes.length}, venue-scoped)'}',
    );
    return scoped;
  }

  @override
  Future<List<AdminSportsComplex>> fetchComplexesByCity(String city) async {
    final response = await _remote.listByCity(city);
    if (!response.isOk) throw response.toException();

    final complexes = AdminSportsComplexMapper.listFrom(response.data);
    AdminLog.data('Sports complexes in "$city" → ${complexes.length}');
    return complexes;
  }

  @override
  Future<List<AdminSportsComplex>> fetchComplexesByState(String state) async {
    final response = await _remote.listByState(state);
    if (!response.isOk) throw response.toException();

    final complexes = AdminSportsComplexMapper.listFrom(response.data);
    AdminLog.data('Sports complexes in "$state" → ${complexes.length}');
    return complexes;
  }

  @override
  Future<AdminSportsComplex> fetchComplex(int id) async {
    final response = await _remote.detail(id);
    if (!response.isOk) throw response.toException();

    final complex = AdminSportsComplexMapper.fromJson(response.payload);
    AdminLog.data('Sports complex detail → $complex');
    return complex;
  }

  @override
  Future<SportsComplexStats> fetchStats(int id) async {
    final response = await _remote.stats(id);
    if (!response.isOk) throw response.toException();

    final stats = SportsComplexStatsMapper.fromJson(response.payload);
    AdminLog.data('Sports complex $id stats → $stats');
    return stats;
  }

  @override
  Future<AdminSportsComplex> createComplex(SportsComplexDraft draft) async {
    final body = draft.toCreateJson();

    // Fail before the round trip rather than let the server reject a body it
    // could never accept.
    if ((body['name'] as String).isEmpty) {
      throw const ValidationException('Give the complex a name.');
    }

    final response = await _remote.create(body);
    if (!response.isOk) throw response.toException();

    _sharedCache.invalidateCache();

    final created = AdminSportsComplexMapper.maybeFromBody(response.data);
    AdminLog.success(
      'Created sports complex ${created?.id ?? '(id not echoed)'}',
    );

    return created ??
        AdminSportsComplex(
          id: 0,
          name: draft.name,
          city: draft.city,
          state: draft.state,
        );
  }

  @override
  Future<AdminSportsComplex> updateComplex(
    int id,
    SportsComplexDraft draft,
  ) async {
    final body = draft.toUpdateJson();
    if (body.isEmpty) {
      throw const BadRequestException('Nothing to update.');
    }

    final response = await _remote.update(id, body);
    if (!response.isOk) throw response.toException();

    _sharedCache.invalidateCache();
    AdminLog.success('Updated sports complex $id');

    return AdminSportsComplexMapper.maybeFromBody(response.data) ??
        AdminSportsComplex(id: id);
  }

  @override
  Future<void> deleteComplex(int id) async {
    final response = await _remote.remove(id);
    if (!response.isOk) throw response.toException();

    _sharedCache.invalidateCache();
    AdminLog.success('Deleted sports complex $id');
  }

  @override
  Future<void> setStatus(int id, AdminUserStatus status) async {
    final response = await _remote.setStatus(id, status);
    if (!response.isOk) throw response.toException();

    _sharedCache.invalidateCache();
    AdminLog.success('Sports complex $id status → ${status.slug}');
  }

  @override
  Future<void> setVisibility(int id, bool showOnFrontend) async {
    final response = await _remote.setVisibility(id, showOnFrontend);
    if (!response.isOk) throw response.toException();

    // The storefront cache is keyed on visibility, so this one especially
    // must not be served stale.
    _sharedCache.invalidateCache();
    AdminLog.success('Sports complex $id showOnFrontend → $showOnFrontend');
  }

  @override
  Future<String> uploadImage(String filePath, {String? filename}) async {
    final response = await _remote.uploadImage(filePath, filename: filename);
    if (!response.isOk) throw response.toException();

    final url = AdminSportsComplexMapper.uploadedUrlFrom(response.data);
    if (url == null || url.isEmpty) {
      // Without a URL there is nothing to put in the complex payload, so this
      // is a failure even though the HTTP call succeeded.
      throw const ServerException(
        'The image uploaded but the server did not return its URL.',
      );
    }

    AdminLog.success('Uploaded complex image');
    return url;
  }

  @override
  Future<void> deleteImage(String imageUrl) async {
    final response = await _remote.deleteImage(imageUrl);
    if (!response.isOk) throw response.toException();
    AdminLog.success('Deleted complex image');
  }
}
