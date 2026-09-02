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

/// Resolves an image reference from the API to something `Image.network` can
/// actually load.
///
/// The API is inconsistent here: some routes return a full URL, others a bare
/// filename. Handing a bare filename straight to `Image.network` is why coach
/// and sport pictures rendered as placeholders. An already-absolute URL is
/// returned untouched.
String? resolveMediaUrl(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;
  if (value.startsWith('http://') || value.startsWith('https://')) {
    return value;
  }
  // Some coach records store the picture inline as a base64 `data:` URI rather
  // than as an uploaded file. That is already the whole image — prefixing the
  // media host would turn it into a nonsense URL that can never load. It is
  // passed through for [MediaImage] to decode.
  if (value.startsWith('data:')) return value;

  final path = value.startsWith('/') ? value.substring(1) : value;
  return '${ApiConfig.mediaBaseUrl}/$path';
}

/// A coach's own record from `GET /coaches/sport/{sportId}`.
///
/// The batch payload carries only a coach's id and name, so the coaching
/// screens had no photo and no biography to show. This is where both come
/// from; it is merged onto the batch-derived coach by sport.
class CoachProfile {
  const CoachProfile({
    this.id,
    this.name,
    this.image,
    this.bio,
    this.experience,
    this.qualifications,
    this.specialization,
    this.certification,
    this.availability,
    this.ground,
  });

  final int? id;
  final String? name;

  /// Absolute URL as sent by the API. Relative paths are resolved against the
  /// media host before they reach here — see [_resolveImage].
  final String? image;

  final String? bio;
  final String? experience;
  final String? qualifications;
  final String? specialization;

  /// Free text from the coach record, e.g. "ALL India Basketball Cert".
  final String? certification;

  /// The coach's own weekly availability, e.g. "Monday,Tuesday,Sunday".
  /// Distinct from a batch's schedule, which belongs to the batch.
  final String? availability;

  final String? ground;

  bool get hasImage => (image ?? '').isNotEmpty;

  /// The credential line shown under the coach's name, e.g.
  /// `"8 years experience · NIS Certified"`. Empty when the API sent nothing.
  String get credentials => [
        if ((experience ?? '').trim().isNotEmpty)
          '${experience!.trim()} experience',
        if ((qualifications ?? '').trim().isNotEmpty) qualifications!.trim(),
        if ((specialization ?? '').trim().isNotEmpty) specialization!.trim(),
      ].join(' \u00b7 ');

  factory CoachProfile.fromJson(Map<String, dynamic> json) {
    final sport = json['Sport'] ?? json['sport'];
    final complex =
        json['SportsComplex'] ?? json['sportsComplex'] ?? json['complex'];

    return CoachProfile(
      id: _int(json['id'] ?? json['_id'] ?? json['coachId']),
      name: _str(json['name'] ?? json['coachName'] ?? json['fullName']),
      image: resolveMediaUrl(
        _str(
          json['image'] ??
              json['imageUrl'] ??
              json['image_url'] ??
              json['photo'] ??
              json['profileImage'] ??
              json['profile_picture'] ??
              json['avatar'],
        ),
      ),
      bio: _str(json['bio'] ?? json['about'] ?? json['description'] ??
          json['coachbio']),
      experience: _str(json['experience'] ??
          json['experienceYears'] ??
          json['yearsOfExperience']),
      qualifications:
          _str(json['qualifications'] ?? json['qualification']),
      specialization: _str(json['specialization'] ??
          json['specialisation'] ??
          json['speciality']),
      certification:
          _str(json['certification'] ?? json['certifications']),
      availability: _str(json['availability']),
      ground: _str(
        json['ground'] ??
            (complex is Map ? complex['name'] : null) ??
            (sport is Map ? sport['ground'] : null),
      ),
    );
  }

  static String? _str(Object? v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static int? _int(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '');
  }
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

  /// Coach profiles per sport, keyed by sport id. Shared by the coach list and
  /// the coach detail screen, which both need the photo and biography.
  final Map<int, Future<List<CoachProfile>>> _coachesBySport =
      <int, Future<List<CoachProfile>>>{};

  void invalidateCache() {
    _batchesBySport.clear();
    _sportsByGround.clear();
    _coachesBySport.clear();
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
      final result = await fetchBatchPage(
        status: status,
        page: page,
        limit: limit,
      );
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
        if (identical(_batchesBySport[key], future))
          _batchesBySport.remove(key);
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
      AppLogger.debug(
        'Batch stats unavailable: ${e.message}',
        name: 'Coaching',
      );
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
        if (identical(_sportsByGround[key], future))
          _sportsByGround.remove(key);
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

    final sports =
        raw
            .whereType<Map>()
            .map(
              (s) => SportRef.fromJson(
                Map<String, dynamic>.from(s),
              ).copyWith(ground: trimmedGround),
            )
            .where((s) => s.id != null)
            .toList()
          ..sort(
            (a, b) => a.displayName.toLowerCase().compareTo(
              b.displayName.toLowerCase(),
            ),
          );

    return sports;
  }

  // ---------------------------------------------------------------------------
  // Coaches
  // ---------------------------------------------------------------------------

  /// `GET /coaches/sport/{sportId}` — the coaches teaching one sport, with
  /// their photo and biography.
  ///
  /// Deliberately never throws: a coach's picture is decoration on a screen
  /// that is really about batches. If this call fails the screen still lists
  /// the coaches it derived from the batches, just without the extra detail.
  Future<List<CoachProfile>> fetchCoachProfiles(
    int sportId, {
    bool forceRefresh = false,
  }) {
    if (!forceRefresh) {
      final cached = _coachesBySport[sportId];
      if (cached != null) return cached;
    }

    final future = _requestCoachProfiles(sportId);
    _coachesBySport[sportId] = future;

    future.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {
        if (identical(_coachesBySport[sportId], future)) {
          _coachesBySport.remove(sportId);
        }
      },
    );

    return future;
  }

  Future<List<CoachProfile>> _requestCoachProfiles(int sportId) async {
    try {
      final response = await _api.get(
        ApiEndpoints.coachesBySport(sportId),
        query: {'status': 'Active', 'limit': 100},
      );

      // Tolerates both `data: [...]` and `data: {coaches: [...]}`.
      final data = response.data is Map ? (response.data as Map)['data'] : null;
      final raw = data is List
          ? data
          : (data is Map ? (data['coaches'] ?? data['rows']) : null);
      if (raw is! List) return const <CoachProfile>[];

      return raw
          .whereType<Map>()
          .map((c) => CoachProfile.fromJson(Map<String, dynamic>.from(c)))
          .where((c) => c.id != null)
          .toList(growable: false);
    } on ApiException catch (e) {
      AppLogger.debug(
        'Coach profiles unavailable for sport $sportId: ${e.message}',
        name: 'Coaching',
      );
      return const <CoachProfile>[];
    }
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

    final names =
        complexes
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

  /// `GET /coaching-enquiries/my-enquiries?page=&limit=`
  ///
  /// The signed-in user's own enquiries. This route wraps its rows in an
  /// object (`data.enquiries`) rather than answering a bare list like the rest
  /// of the module, so the reader looks in both places and treats a shape it
  /// does not recognise as empty rather than throwing.
  Future<List<MyEnquiry>> fetchMyEnquiries({
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _api.get(
      ApiEndpoints.myCoachingEnquiries,
      query: {'page': page, 'limit': limit},
    );

    if (!response.isOk) throw response.toException();

    final data = response.data;
    final envelope = data is Map ? data['data'] : null;
    final raw = envelope is Map ? envelope['enquiries'] : envelope;
    if (raw is! List) return const [];

    return raw
        .whereType<Map>()
        .map((row) => MyEnquiry.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

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

/// One row of `GET /coaching-enquiries/my-enquiries`.
class MyEnquiry {
  const MyEnquiry({
    this.id,
    this.referenceNumber,
    this.status,
    this.message,
    this.createdAt,
    this.batchName,
    this.sportName,
    this.coachName,
  });

  final int? id;

  /// Server-issued, e.g. `NSC-20260822-K7QX2` — what the user quotes when
  /// they follow up.
  final String? referenceNumber;

  /// `Pending`, `Assigned`, `Closed` — whatever the console last set.
  final String? status;

  final String? message;
  final String? createdAt;

  /// Flattened from the `batch` / `sport` / `coach` objects the route nests,
  /// since a list row only ever shows their names.
  final String? batchName;
  final String? sportName;
  final String? coachName;

  factory MyEnquiry.fromJson(Map<String, dynamic> json) {
    String? nameOf(Object? nested) {
      if (nested is! Map) return null;
      return _clean(nested['name']);
    }

    return MyEnquiry(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? ''),
      referenceNumber: _clean(json['referenceNumber']),
      status: _clean(json['status']),
      message: _clean(json['message']),
      createdAt: _clean(json['createdAt']),
      batchName: nameOf(json['batch']),
      sportName: nameOf(json['sport']),
      coachName: nameOf(json['coach']),
    );
  }

  bool get isPending => (status ?? '').toLowerCase() == 'pending';

  static String? _clean(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text == 'null') return null;
    return text;
  }
}
