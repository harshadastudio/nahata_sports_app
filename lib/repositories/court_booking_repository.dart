import '../core/config/api_config.dart';
import '../core/network/api_client.dart';
import '../core/utils/app_logger.dart';
import '../models/court_booking_model.dart';

/// `GET /courts/bookings/my` — the signed-in user's court (facility) bookings,
/// each carrying its own pass code and QR.
class CourtBookingRepository {
  CourtBookingRepository._();

  static final CourtBookingRepository instance = CourtBookingRepository._();

  final ApiClient _api = ApiClient.instance;

  /// One page of bookings, in the order the API returns them.
  Future<CourtBookingPage> fetchMyBookingPage({
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _api.get(
      ApiEndpoints.myCourtBookings,
      query: {'page': page, 'limit': limit},
    );

    if (!response.isOk) return const CourtBookingPage();

    final body = response.data;
    return CourtBookingPage.fromJson(
      data: body is Map ? body['data'] : null,
      pagination: body is Map && body['pagination'] is Map
          ? Map<String, dynamic>.from(body['pagination'] as Map)
          : null,
    );
  }

  /// Every booking, following pagination. Returns an empty list on failure —
  /// the pass screen shows its empty state rather than an error.
  Future<List<CourtBooking>> fetchMyBookings({
    int limit = 20,
    int maxPages = 20,
  }) async {
    try {
      final all = <CourtBooking>[];

      var page = 1;
      while (page <= maxPages) {
        final result = await fetchMyBookingPage(page: page, limit: limit);
        all.addAll(result.bookings);
        if (!result.hasMore || result.bookings.isEmpty) break;
        page++;
      }

      if (page > maxPages) {
        AppLogger.debug('Stopped at the $maxPages page cap',
            name: 'CourtBooking');
      }

      return all;
    } catch (e) {
      AppLogger.error('Could not load court bookings',
          name: 'CourtBooking', error: e);
      return const <CourtBooking>[];
    }
  }
}
