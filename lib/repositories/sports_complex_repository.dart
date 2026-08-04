import '../core/config/api_config.dart';
import '../core/network/api_client.dart';
import '../core/utils/app_logger.dart';
import '../models/sports_complex_model.dart';

/// `GET /sports-complexes` — the venues shown across the app.
///
/// One place owns this list because several screens need it: the events venue
/// picker, the coaching screens and registration.
class SportsComplexRepository {
  SportsComplexRepository._();

  static final SportsComplexRepository instance = SportsComplexRepository._();

  final ApiClient _api = ApiClient.instance;

  List<SportsComplex>? _cache;

  /// Cached separately: the admin list is a superset, so serving it to a
  /// customer-facing picker would leak venues that are hidden on purpose.
  List<SportsComplex>? _adminCache;

  void invalidateCache() {
    _cache = null;
    _adminCache = null;
  }

  /// Active, front-facing venues in the order the API returns them.
  ///
  /// Cached for the session; returns an empty list rather than throwing, so a
  /// venue picker degrades to "no choices" instead of breaking its screen.
  ///
  /// [includeHidden] widens the query for the admin console, which must be able
  /// to assign staff to a complex that is not shown on the storefront. Customer
  /// screens leave it false and get exactly the list they always got.
  Future<List<SportsComplex>> fetchComplexes({
    bool refresh = false,
    bool includeHidden = false,
  }) async {
    final cached = includeHidden ? _adminCache : _cache;
    if (cached != null && !refresh) return cached;

    try {
      final response = await _api.get(
        ApiEndpoints.sportsComplexes,
        requiresAuth: false,
        query: includeHidden
            ? {'limit': 200}
            : {'status': 'Active', 'showOnFrontend': 'true', 'limit': 50},
      );

      if (!response.isOk) return const <SportsComplex>[];

      final complexes =
          response.payload['sportsComplexes'] ??
          response.payload['sportComplexes'];

      final parsed = SportsComplex.listFrom(complexes);
      if (includeHidden) {
        _adminCache = parsed;
      } else {
        _cache = parsed;
      }
      return parsed;
    } catch (e) {
      AppLogger.error(
        'Could not load sports complexes',
        name: 'Venues',
        error: e,
      );
      return const <SportsComplex>[];
    }
  }

  /// Venue id for [name], matched case-insensitively.
  Future<int?> idFor(String name) async {
    final wanted = name.trim().toLowerCase();
    if (wanted.isEmpty) return null;

    for (final complex in await fetchComplexes()) {
      if (complex.name.toLowerCase() == wanted) return complex.id;
    }
    return null;
  }
}
