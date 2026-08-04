import '../core/config/api_config.dart';
import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../core/utils/app_logger.dart';
import '../models/batch_model.dart';

/// Outcome of `POST /coaching-enquiries`.
class EnquiryResult {
  const EnquiryResult({
    required this.success,
    required this.message,
    this.referenceNumber,
    this.id,
  });

  final bool success;
  final String message;

  /// Server-issued reference, e.g. `NSC-20260729-F0DAK`.
  final String? referenceNumber;
  final int? id;
}

/// Coaching module: sports, batches, batch stats and enquiries.
class CoachingRepository {
  CoachingRepository._();

  static final CoachingRepository instance = CoachingRepository._();

  final ApiClient _api = ApiClient.instance;

  /// Cache of sport(+ground)→batches, keyed by `"<sportId>|<ground>"` so a
  /// filtered and an unfiltered lookup never collide.
  ///
  /// The *future* is stored, not the resolved list, so two callers asking at
  /// the same moment (BatchScreen wants the batches and their coaches) share
  /// one HTTP request instead of racing two.
  final Map<String, Future<List<BatchModel>>> _batchesBySport =
      <String, Future<List<BatchModel>>>{};

  static String _sportCacheKey(int sportId, String? ground) =>
      '$sportId|${(ground ?? '').trim().toLowerCase()}';

  /// Sports per ground, keyed by the (lower-cased) ground name; `''` is the
  /// unfiltered "all grounds" list.
  final Map<String, Future<List<SportRef>>> _sportsByGround =
      <String, Future<List<SportRef>>>{};

  void invalidateCache() {
    _batchesBySport.clear();
    _sportsByGround.clear();
  }

  // ---------------------------------------------------------------------------
  // Batches
  // ---------------------------------------------------------------------------

  /// `GET /batches?status=&page=&limit=`
  Future<BatchPage> fetchBatchPage({
    String? status = 'Active',
    int page = 1,
    int limit = 10,
  }) async {
    final response = await _api.get(
      ApiEndpoints.batches,
      query: {
        if (status != null && status.isNotEmpty) 'status': status,
        'page': page,
        'limit': limit,
      },
    );

    if (!response.isOk) return const BatchPage();
    return BatchPage.fromJson(response.payload);
  }

  /// Walks every page of `/batches` and returns the full list.
  ///
  /// [maxPages] is a safety stop so a bad `totalPages` can never spin forever.
  Future<List<BatchModel>> fetchAllBatches({
    String? status = 'Active',
    int limit = 50,
    int maxPages = 20,
  }) async {
    final all = <BatchModel>[];

    var page = 1;
    while (page <= maxPages) {
      final result = await fetchBatchPage(status: status, page: page, limit: limit);
      all.addAll(result.batches);

      if (!result.hasMore || result.batches.isEmpty) break;
      page++;
    }

    if (page > maxPages) {
      AppLogger.debug(
        'fetchAllBatches stopped at the $maxPages page cap — '
        'some batches may not be listed',
        name: 'Coaching',
      );
    }

    return all;
  }

  /// `GET /batches/sport/{sportId}[?ground=]` — batches for one sport,
  /// optionally narrowed to a single ground/venue.
  Future<List<BatchModel>> fetchBatchesBySport(
    int sportId, {
    String? ground,
    bool forceRefresh = false,
  }) {
    final key = _sportCacheKey(sportId, ground);

    if (!forceRefresh) {
      final cached = _batchesBySport[key];
      if (cached != null) return cached;
    }

    final future = _requestBatchesBySport(sportId, ground);
    _batchesBySport[key] = future;

    // A failed request must not stay cached, or Retry could never recover.
    // This listener only evicts; the error itself still travels to whoever
    // awaits the future we return.
    future.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {
        if (identical(_batchesBySport[key], future)) _batchesBySport.remove(key);
      },
    );

    return future;
  }

  Future<List<BatchModel>> _requestBatchesBySport(
    int sportId,
    String? ground,
  ) async {
    final trimmedGround = ground?.trim();

    final response = await _api.get(
      ApiEndpoints.batchesBySport(sportId),
      query: {
        if (trimmedGround != null && trimmedGround.isNotEmpty)
          'ground': trimmedGround,
      },
    );

    // This endpoint returns a bare list under `data`.
    final raw = response.data is Map ? (response.data as Map)['data'] : null;
    return raw is List
        ? raw
            .whereType<Map>()
            .map((b) => BatchModel.fromJson(Map<String, dynamic>.from(b)))
            .toList(growable: false)
        : const <BatchModel>[];
  }

  /// Distinct grounds/venues teaching a sport, taken from the coaches attached
  /// to its batches. Useful for building a ground filter.
  Future<List<String>> fetchGroundsForSport(int sportId) async {
    final batches = await fetchBatchesBySport(sportId);

    final grounds = <String>{};
    for (final batch in batches) {
      final ground = batch.coach?.ground?.trim();
      if (ground != null && ground.isNotEmpty) grounds.add(ground);
    }

    return grounds.toList()..sort();
  }

  /// `GET /batches/coach/{coachId}`
  Future<List<BatchModel>> fetchBatchesByCoach(int coachId) async {
    final response = await _api.get(ApiEndpoints.batchesByCoach(coachId));

    final raw = response.data is Map ? (response.data as Map)['data'] : null;
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((b) => BatchModel.fromJson(Map<String, dynamic>.from(b)))
          .toList(growable: false);
    }
    // Tolerate a paginated shape here too, in case this endpoint mirrors
    // `/batches` rather than `/batches/sport/{id}`.
    if (raw is Map && raw['batches'] is List) {
      return BatchPage.fromJson(Map<String, dynamic>.from(raw)).batches;
    }
    return const <BatchModel>[];
  }

  /// `GET /batches/{id}?includeStudents=`
  Future<BatchModel?> fetchBatch(
    int batchId, {
    bool includeStudents = false,
  }) async {
    final response = await _api.get(
      ApiEndpoints.batchById(batchId),
      query: {'includeStudents': includeStudents},
    );

    if (!response.isOk) return null;
    final payload = response.payload;
    if (payload.isEmpty) return null;
    return BatchModel.fromJson(payload);
  }

  /// `GET /batches/{id}/stats`
  Future<BatchStats?> fetchBatchStats(int batchId) async {
    try {
      final response = await _api.get(ApiEndpoints.batchStats(batchId));
      if (!response.isOk) return null;
      return BatchStats.fromJson(response.payload);
    } on ApiException catch (e) {
      // Stats are supplementary — never break the screen over them.
      AppLogger.debug('Batch stats unavailable: ${e.message}', name: 'Coaching');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Sports
  // ---------------------------------------------------------------------------

  /// `GET /sports?status=Active&showOnFrontend=true&limit=100[&ground=]`
  ///
  /// Pass [ground] to list only the sports offered at that venue. Because
  /// sport ids are scoped to a ground, the returned records are stamped with
  /// the ground they came from so downstream screens keep that context.
  Future<List<SportRef>> fetchSports({
    String? ground,
    bool forceRefresh = false,
  }) {
    final key = (ground ?? '').trim().toLowerCase();

    if (!forceRefresh) {
      final cached = _sportsByGround[key];
      if (cached != null) return cached;
    }

    final future = _requestSports(ground);
    _sportsByGround[key] = future;

    future.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {
        if (identical(_sportsByGround[key], future)) _sportsByGround.remove(key);
      },
    );

    return future;
  }

  Future<List<SportRef>> _requestSports(String? ground) async {
    final trimmedGround = ground?.trim();

    final response = await _api.get(
      ApiEndpoints.sports,
      query: {
        'status': 'Active',
        'showOnFrontend': 'true',
        'limit': 100,
        if (trimmedGround != null && trimmedGround.isNotEmpty)
          'ground': trimmedGround,
      },
    );

    // This endpoint returns a bare list under `data`.
    final raw = response.data is Map ? (response.data as Map)['data'] : null;
    if (raw is! List) return const <SportRef>[];

    final sports = raw
        .whereType<Map>()
        .map((s) => SportRef.fromJson(Map<String, dynamic>.from(s))
            .copyWith(ground: trimmedGround))
        .where((s) => s.id != null)
        .toList()
      ..sort((a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));

    return sports;
  }

  /// Venue names that can be used as a `ground` filter, from
  /// `/sports-complexes`.
  Future<List<String>> fetchGrounds() async {
    final response = await _api.get(
      ApiEndpoints.sportsComplexes,
      query: {'status': 'Active', 'showOnFrontend': 'true', 'limit': 50},
    );

    final complexes = response.payload['sportsComplexes'];
    if (complexes is! List) return const <String>[];

    final names = complexes
        .whereType<Map>()
        .map((c) => c['name']?.toString().trim() ?? '')
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return names;
  }

  // ---------------------------------------------------------------------------
  // Enquiries
  // ---------------------------------------------------------------------------

  /// `POST /coaching-enquiries`
  ///
  /// The user is identified by the bearer token; the contact fields are what
  /// the enquiry is followed up on.
  Future<EnquiryResult> submitEnquiry({
    required String name,
    required String email,
    required String phone,
    int? batchId,
    int? sportId,
    int? coachId,
    String? message,
  }) async {
    try {
      final response = await _api.post(
        ApiEndpoints.coachingEnquiries,
        body: {
          if (batchId != null) 'batchId': batchId,
          if (sportId != null) 'sportId': sportId,
          if (coachId != null) 'coachId': coachId,
          'name': name,
          'email': email,
          'phone': phone,
          if (message != null && message.isNotEmpty) 'message': message,
        },
      );

      if (!response.isOk) {
        return EnquiryResult(
          success: false,
          message: response.message ?? 'Failed to send enquiry',
        );
      }

      final payload = response.payload;
      return EnquiryResult(
        success: true,
        message: response.message ?? 'Your enquiry has been sent!',
        referenceNumber: payload['referenceNumber']?.toString(),
        id: payload['id'] is int
            ? payload['id'] as int
            : int.tryParse(payload['id']?.toString() ?? ''),
      );
    } on ApiException catch (e) {
      AppLogger.error('Enquiry failed', name: 'Coaching', error: e.message);
      return EnquiryResult(success: false, message: e.message);
    }
  }
}
