import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_response.dart';
import '../../core/admin_log.dart';

/// The ten `/revenue-splits` routes this console uses.
///
/// Auth, refresh, timeouts and error mapping all come from [ApiClient]; this
/// layer only shapes requests and traces them. `GET /revenue-splits/unsplit`
/// and `POST /revenue-splits/unsplit/repair` are deliberately not here — the
/// collection itself says they are "not wired into the current admin screen",
/// matching the real website.
class RevenueSplitRemoteDataSource {
  RevenueSplitRemoteDataSource({ApiClient? client})
    : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  /// `GET /revenue-splits?includeInactive=&scope=&sportId=&coachId=&batchId=`
  ///
  /// `includeInactive` is sent as the literal string `'true'` only when
  /// asked — the API reads exactly that string, anything else (including
  /// omitting the key) means active-only.
  Future<ApiResponse> list({
    bool includeInactive = false,
    String? scope,
    int? sportId,
    int? coachId,
    int? batchId,
  }) {
    final query = <String, dynamic>{
      if (includeInactive) 'includeInactive': 'true',
      if (scope != null && scope.trim().isNotEmpty) 'scope': scope.trim(),
      if (sportId != null && sportId > 0) 'sportId': sportId,
      if (coachId != null && coachId > 0) 'coachId': coachId,
      if (batchId != null && batchId > 0) 'batchId': batchId,
    };

    AdminLog.call('GET ${ApiEndpoints.revenueSplits} $query');
    return _api.get(ApiEndpoints.revenueSplits, query: query);
  }

  /// `GET /revenue-splits/options`
  Future<ApiResponse> options() {
    AdminLog.call('GET ${ApiEndpoints.revenueSplitOptions}');
    return _api.get(ApiEndpoints.revenueSplitOptions);
  }

  /// `GET /revenue-splits/coverage`
  Future<ApiResponse> coverage() {
    AdminLog.call('GET ${ApiEndpoints.revenueSplitCoverage}');
    return _api.get(ApiEndpoints.revenueSplitCoverage);
  }

  /// `GET /revenue-splits/resolve?batchId=&sportId=&coachId=&paidOn=`
  Future<ApiResponse> resolve({
    int? batchId,
    int? sportId,
    int? coachId,
    String? paidOn,
  }) {
    final query = <String, dynamic>{
      if (batchId != null && batchId > 0) 'batchId': batchId,
      if (sportId != null && sportId > 0) 'sportId': sportId,
      if (coachId != null && coachId > 0) 'coachId': coachId,
      if (paidOn != null && paidOn.trim().isNotEmpty) 'paidOn': paidOn.trim(),
    };

    AdminLog.call('GET ${ApiEndpoints.revenueSplitResolve} $query');
    return _api.get(ApiEndpoints.revenueSplitResolve, query: query);
  }

  /// `POST /revenue-splits`
  Future<ApiResponse> create(Map<String, dynamic> body) {
    AdminLog.call('POST ${ApiEndpoints.revenueSplits} fields=${body.keys}');
    return _api.post(ApiEndpoints.revenueSplits, body: body);
  }

  /// `PUT /revenue-splits/{ruleId}`
  Future<ApiResponse> update(int id, Map<String, dynamic> body) {
    AdminLog.call('PUT ${ApiEndpoints.revenueSplit(id)} fields=${body.keys}');
    return _api.put(ApiEndpoints.revenueSplit(id), body: body);
  }

  /// `PATCH /revenue-splits/{ruleId}/deactivate` — `{isActive: false}`
  /// deactivates, `{isActive: true}` reactivates.
  Future<ApiResponse> setActive(int id, bool isActive) {
    AdminLog.call(
      'PATCH ${ApiEndpoints.revenueSplitDeactivate(id)} isActive=$isActive',
    );
    return _api.patch(
      ApiEndpoints.revenueSplitDeactivate(id),
      body: {'isActive': isActive},
    );
  }

  /// `POST /revenue-splits/backfill/dry-run` — an empty body is fine, no
  /// confirmation needed for a dry run.
  Future<ApiResponse> backfillDryRun() {
    AdminLog.call('POST ${ApiEndpoints.revenueSplitBackfillDryRun}');
    return _api.post(ApiEndpoints.revenueSplitBackfillDryRun, body: const {});
  }

  /// `POST /revenue-splits/backfill/apply` — `{confirm: true}` is mandatory.
  Future<ApiResponse> backfillApply() {
    AdminLog.call('POST ${ApiEndpoints.revenueSplitBackfillApply} confirm=true');
    return _api.post(
      ApiEndpoints.revenueSplitBackfillApply,
      body: {'confirm': true},
    );
  }

  /// `POST /revenue-splits/backfill/rollback` — `{confirm: true}` is
  /// mandatory.
  Future<ApiResponse> backfillRollback() {
    AdminLog.call(
      'POST ${ApiEndpoints.revenueSplitBackfillRollback} confirm=true',
    );
    return _api.post(
      ApiEndpoints.revenueSplitBackfillRollback,
      body: {'confirm': true},
    );
  }
}
