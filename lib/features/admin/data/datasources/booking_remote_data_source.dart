import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_response.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/booking.dart';

/// Booking requests. Auth, refresh and error mapping come from [ApiClient].
class BookingRemoteDataSource {
  BookingRemoteDataSource({ApiClient? client})
    : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  /// `GET /bookings` with whatever filters are set.
  ///
  /// The route documents no filter parameters, so these are sent hopefully —
  /// if the backend ignores one, the controller's own local pass still gets the
  /// right rows. Null values are dropped by `ApiClient._buildUri`.
  Future<ApiResponse> list({
    BookingStatus? status,
    PaymentStatus? payment,
    BookingSource? source,
    int? sportId,
    int? courtId,
    int? complexId,
    DateTime? date,
    int page = 1,
    int limit = 20,
  }) {
    final query = <String, dynamic>{
      if (status != null) 'bookingStatus': status.slug,
      if (payment != null) 'paymentStatus': payment.slug,
      if (source != null) 'bookingSource': source.slug,
      if (sportId != null) 'sportId': sportId,
      if (courtId != null) 'courtId': courtId,
      if (complexId != null) 'sportComplexId': complexId,
      if (date != null) 'date': BookingDraft.formatDate(date),
      'page': page,
      'limit': limit,
    };

    AdminLog.call('GET ${ApiEndpoints.bookings} $query');
    return _api.get(ApiEndpoints.bookings, query: query);
  }

  Future<ApiResponse> stats() {
    AdminLog.call('GET ${ApiEndpoints.bookingsStats}');
    return _api.get(ApiEndpoints.bookingsStats);
  }

  Future<ApiResponse> current() {
    AdminLog.call('GET ${ApiEndpoints.bookingsCurrent}');
    return _api.get(ApiEndpoints.bookingsCurrent);
  }

  Future<ApiResponse> detail(int id) {
    AdminLog.call('GET ${ApiEndpoints.booking(id)}');
    return _api.get(ApiEndpoints.booking(id));
  }

  Future<ApiResponse> create(Map<String, dynamic> body) {
    AdminLog.call('POST ${ApiEndpoints.bookings} fields=${body.keys}');
    return _api.post(ApiEndpoints.bookings, body: body);
  }

  Future<ApiResponse> update(int id, Map<String, dynamic> body) {
    AdminLog.call('PUT ${ApiEndpoints.booking(id)} fields=${body.keys}');
    return _api.put(ApiEndpoints.booking(id), body: body);
  }

  Future<ApiResponse> remove(int id) {
    AdminLog.call('DELETE ${ApiEndpoints.booking(id)}');
    return _api.delete(ApiEndpoints.booking(id));
  }
}
