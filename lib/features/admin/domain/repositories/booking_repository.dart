import '../../../../models/sports_complex_model.dart';
import '../entities/booking.dart';
import '../entities/court.dart';
import '../entities/sport.dart';

/// Booking CRUD, the dashboard counters, today's board, and the catalogues the
/// booking form needs.
///
/// `GET /bookings` documents no filter parameters, so [fetchBookings] sends the
/// ones it has and the controller re-applies **every** filter locally. That way
/// the table is right whether or not the backend honours them.
abstract class BookingRepository {
  /// `GET /bookings?page=&limit=` plus whatever filters are set.
  Future<BookingPageResult> fetchBookings({
    BookingStatus? status,
    PaymentStatus? payment,
    BookingSource? source,
    int? sportId,
    int? courtId,
    int? complexId,
    DateTime? date,
    int page,
    int limit,
  });

  /// Every page of `/bookings` for the current filters, up to [maxPages].
  ///
  /// Needed because a filter applied to one page at a time would silently hide
  /// matches sitting on page two. The cap is reported through [onCapped] so the
  /// page can say so rather than quietly truncating.
  Future<List<Booking>> fetchAllBookings({
    BookingStatus? status,
    PaymentStatus? payment,
    BookingSource? source,
    int? sportId,
    int? courtId,
    int? complexId,
    DateTime? date,
    int limit,
    int maxPages,
    void Function(int loaded, int total)? onCapped,
  });

  /// `GET /bookings/stats`
  Future<BookingStats> fetchStats();

  /// `GET /bookings/current` — today's board.
  Future<List<Booking>> fetchCurrent();

  /// `GET /bookings/{bookingId}`
  Future<Booking> fetchBooking(int id);

  /// `POST /bookings`
  Future<Booking> createBooking(BookingDraft draft);

  /// `PUT /bookings/{bookingId}`
  Future<Booking> updateBooking(int id, BookingDraft draft);

  /// `DELETE /bookings/{bookingId}`
  Future<void> deleteBooking(int id);

  /// Courts for the form dropdown and the court filter, from `GET /courts`.
  Future<List<Court>> fetchCourts({int? complexId, int? sportId});

  /// Sports for the form dropdown and the sport filter, from `GET /sports`.
  Future<List<Sport>> fetchSports({bool refresh});

  /// Venues for the form dropdown and the complex filter.
  Future<List<SportsComplex>> fetchSportComplexes({bool refresh});
}
