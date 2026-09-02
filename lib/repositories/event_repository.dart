import '../core/config/api_config.dart';
import '../core/network/api_client.dart';
import '../core/services/selected_ground.dart';
import '../core/utils/app_logger.dart';
import '../models/event_pass_model.dart';
import '../models/sports_complex_model.dart';
import 'sports_complex_repository.dart';

/// `GET /event-passes` — events, their bookable slots and their venue.
class EventRepository {
  EventRepository._();

  static final EventRepository instance = EventRepository._();

  final ApiClient _api = ApiClient.instance;

  final SportsComplexRepository _complexes = SportsComplexRepository.instance;

  void invalidateCache() => _complexes.invalidateCache();

  /// Venues the events screen can filter by, on top of "All complexes".
  Future<List<SportsComplex>> fetchVenues() => _complexes.fetchComplexes();

  /// One page of event passes.
  ///
  /// [sportComplexId] limits results to a single venue.
  ///
  /// [timeframe] is the server-side split the events screen's two tabs run on:
  /// `'upcoming'` for events that still have a date to come, `'past'` for ones
  /// that are over. The backend decides which is which — passing null asks for
  /// both, which is what the details page wants when it re-reads one event's
  /// slots and does not know whether that event has already happened.
  Future<EventPassPage> fetchEventPassPage({
    String? status = 'Active',
    String? timeframe,
    int page = 1,
    int limit = 50,
    int? sportComplexId,
  }) async {
    final response = await _api.get(
      ApiEndpoints.eventPasses,
      query: {
        if (status != null && status.isNotEmpty) 'status': status,
        if (timeframe != null && timeframe.isNotEmpty) 'timeframe': timeframe,
        'page': page,
        'limit': limit,
        if (sportComplexId != null) 'sportComplexId': sportComplexId,
      },
    );

    if (!response.isOk) return const EventPassPage();

    final body = response.data;
    return EventPassPage.fromJson(
      data: body is Map ? body['data'] : null,
      pagination: body is Map && body['pagination'] is Map
          ? Map<String, dynamic>.from(body['pagination'] as Map)
          : null,
    );
  }

  /// Every event pass, following pagination.
  Future<List<EventPassModel>> fetchEventPasses({
    String? status = 'Active',
    String? timeframe,
    int? sportComplexId,
    int limit = 50,
    int maxPages = 20,
  }) async {
    final all = <EventPassModel>[];

    var page = 1;
    while (page <= maxPages) {
      final result = await fetchEventPassPage(
        status: status,
        timeframe: timeframe,
        page: page,
        limit: limit,
        sportComplexId: sportComplexId,
      );

      all.addAll(result.events);
      if (!result.hasMore || result.events.isEmpty) break;
      page++;
    }

    if (page > maxPages) {
      AppLogger.debug(
        'fetchEventPasses stopped at the $maxPages page cap',
        name: 'Events',
      );
    }

    return all;
  }

  /// Resolves the sports-complex id for the currently selected venue.
  ///
  /// The venue is stored by name (it is also used as the `ground` filter for
  /// the coaching endpoints), but `/event-passes` filters by id — so the id is
  /// looked up from `/sports-complexes` and then cached back onto the
  /// selection.
  Future<int?> resolveSelectedComplexId() async {
    final selected = SelectedGround.instance;

    final knownId = await selected.readId();
    if (knownId != null) return knownId;

    final name = await selected.read();
    if (name == null) return null;

    final id = await _complexes.idFor(name);
    if (id != null) await selected.attachId(id);
    return id;
  }
}
