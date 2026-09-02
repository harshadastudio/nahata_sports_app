import '../core/config/api_config.dart';
import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../core/utils/app_logger.dart';
import '../models/event_booking_model.dart';

/// Outcome of creating an event-pass booking.
class EventBookingResult {
  const EventBookingResult({this.bookingId, this.message, this.data});

  /// Id the payment endpoints refer to (`bookingId` in create-order/verify).
  final int? bookingId;

  /// Server message, shown as-is when the booking could not be created.
  final String? message;

  /// Whole `data` object, so the pass screen can read a QR code or reference
  /// number when the backend returns one.
  final Map<String, dynamic>? data;

  bool get isOk => bookingId != null;

  factory EventBookingResult.failed(String? message) =>
      EventBookingResult(message: message);
}

/// Creates the pending booking that a payment is raised against.
///
/// Mirrors what `/courts/bookings/create` does for facility bookings: reserve
/// first, pay second — so no money can be taken without a booking to attach it
/// to.
class EventBookingRepository {
  EventBookingRepository._();

  static final EventBookingRepository instance = EventBookingRepository._();

  final ApiClient _api = ApiClient.instance;

  Future<EventBookingResult> createBooking({
    required int eventPassId,
    required int slotId,
    required int passes,
    required num amount,
    String? name,
    String? email,
    String? couponCode,
    int? sportComplexId,
    Map<String, String>? customFieldValues,
  }) async {
    try {
      final response = await _api.post(
        ApiEndpoints.eventBookingCreate,
        body: {
          // Field names taken from the booking record returned by
          // `/event-passes/bookings/my`.
          'eventPassId': eventPassId,
          'slotId': slotId,
          'numberOfPasses': passes,
          'totalAmount': amount is int ? amount : amount.round(),
          if (name != null && name.isNotEmpty) 'name': name,
          if (email != null && email.isNotEmpty) 'email': email,
          if (couponCode != null && couponCode.isNotEmpty)
            'couponCode': couponCode,
          if (sportComplexId != null) 'sportComplexId': sportComplexId,
          // The event's own questions, as `[{key, value}]`. Sent only when the
          // event defines some — an empty list would be noise on the many
          // events that ask nothing. The server echoes each answer back with
          // its label attached.
          if (customFieldValues != null && customFieldValues.isNotEmpty)
            'customFieldValues': [
              for (final entry in customFieldValues.entries)
                {'key': entry.key, 'value': entry.value},
            ],
        },
      );

      if (!response.isOk) {
        return EventBookingResult.failed(
            response.message ?? 'Could not create the booking');
      }

      final body = response.data;
      final data = body is Map ? body['data'] : null;
      final map = data is Map ? Map<String, dynamic>.from(data) : null;

      final id = _bookingIdFrom(map);
      if (id == null) {
        AppLogger.error(
          'Booking created but no id found in the response',
          name: 'EventBooking',
        );
        return EventBookingResult.failed('Could not create the booking');
      }

      return EventBookingResult(
        bookingId: id,
        message: body is Map ? body['message']?.toString() : null,
        data: map,
      );
    } on ApiException catch (e) {
      AppLogger.error('Create event booking failed',
          name: 'EventBooking', error: e);
      return EventBookingResult.failed(e.message);
    } catch (e) {
      AppLogger.error('Create event booking error',
          name: 'EventBooking', error: e);
      return EventBookingResult.failed('Could not create the booking');
    }
  }

  /// `GET /event-passes/bookings/my` — the signed-in user's bookings, newest
  /// first.
  Future<List<EventPassBooking>> fetchMyBookings() async {
    try {
      final response = await _api.get(ApiEndpoints.myEventBookings);
      if (!response.isOk) return const <EventPassBooking>[];

      final body = response.data;
      final data = body is Map ? body['data'] : null;

      // `data` is a bare list today; tolerate a wrapper as well.
      final raw = data is Map ? (data['bookings'] ?? data['data']) : data;

      final bookings = EventPassBooking.listFrom(raw).toList()
        ..sort((a, b) {
          final left = a.createdAt;
          final right = b.createdAt;
          if (left == null && right == null) return (b.id ?? 0) - (a.id ?? 0);
          if (left == null) return 1;
          if (right == null) return -1;
          return right.compareTo(left);
        });

      return bookings;
    } catch (e) {
      AppLogger.error('Could not load bookings',
          name: 'EventBooking', error: e);
      return const <EventPassBooking>[];
    }
  }

  /// A single booking of the user's, by id.
  Future<EventPassBooking?> fetchMyBooking(int bookingId) async {
    final bookings = await fetchMyBookings();
    for (final booking in bookings) {
      if (booking.id == bookingId) return booking;
    }
    return null;
  }

  /// Reads the new booking's id, accepting the shapes the other booking
  /// endpoints use (`data.id`, `data.booking.id`, `data.bookings[0].id`).
  static int? _bookingIdFrom(Map<String, dynamic>? data) {
    if (data == null) return null;

    int? asInt(Object? value) =>
        value is int ? value : int.tryParse(value?.toString() ?? '');

    final direct = asInt(data['id'] ?? data['bookingId'] ?? data['booking_id']);
    if (direct != null) return direct;

    final booking = data['booking'];
    if (booking is Map) {
      final nested = asInt(booking['id'] ?? booking['bookingId']);
      if (nested != null) return nested;
    }

    final bookings = data['bookings'];
    if (bookings is List) {
      for (final entry in bookings.whereType<Map>()) {
        final id = asInt(entry['id'] ?? entry['bookingId']);
        if (id != null) return id;
      }
    }

    return null;
  }
}
