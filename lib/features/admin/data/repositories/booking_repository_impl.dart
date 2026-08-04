import '../../../../core/network/api_exception.dart';
import '../../../../models/sports_complex_model.dart';
import '../../../../repositories/sports_complex_repository.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/booking.dart';
import '../../domain/entities/court.dart';
import '../../domain/entities/sport.dart';
import '../../domain/repositories/booking_repository.dart';
import '../../domain/repositories/court_repository.dart';
import '../../domain/repositories/sport_repository.dart';
import '../datasources/booking_remote_data_source.dart';
import '../models/booking_model.dart';
import 'court_repository_impl.dart';
import 'sport_repository_impl.dart';

/// [BookingRepository] over the JWT backend.
///
/// The three dropdown catalogues are delegated to the modules that own them,
/// so no two screens can disagree about what courts, sports or venues exist.
class BookingRepositoryImpl implements BookingRepository {
  BookingRepositoryImpl({
    BookingRemoteDataSource? remote,
    CourtRepository? courts,
    SportRepository? sports,
    SportsComplexRepository? complexes,
  }) : _remote = remote ?? BookingRemoteDataSource(),
       _courts = courts ?? CourtRepositoryImpl(),
       _sports = sports ?? SportRepositoryImpl(),
       _complexes = complexes ?? SportsComplexRepository.instance;

  final BookingRemoteDataSource _remote;
  final CourtRepository _courts;
  final SportRepository _sports;
  final SportsComplexRepository _complexes;

  @override
  Future<BookingPageResult> fetchBookings({
    BookingStatus? status,
    PaymentStatus? payment,
    BookingSource? source,
    int? sportId,
    int? courtId,
    int? complexId,
    DateTime? date,
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _remote.list(
      status: status,
      payment: payment,
      source: source,
      sportId: sportId,
      courtId: courtId,
      complexId: complexId,
      date: date,
      page: page,
      limit: limit,
    );
    if (!response.isOk) throw response.toException();

    final result = BookingMapper.pageFrom(
      response.data,
      requestedPage: page,
      requestedLimit: limit,
    );
    AdminLog.data('Bookings → $result');
    return result;
  }

  @override
  Future<List<Booking>> fetchAllBookings({
    BookingStatus? status,
    PaymentStatus? payment,
    BookingSource? source,
    int? sportId,
    int? courtId,
    int? complexId,
    DateTime? date,
    int limit = 100,
    int maxPages = 20,
    void Function(int loaded, int total)? onCapped,
  }) async {
    final all = <Booking>[];
    var page = 1;
    var totalItems = 0;

    while (page <= maxPages) {
      final result = await fetchBookings(
        status: status,
        payment: payment,
        source: source,
        sportId: sportId,
        courtId: courtId,
        complexId: complexId,
        date: date,
        page: page,
        limit: limit,
      );

      all.addAll(result.bookings);
      totalItems = result.totalItems;

      if (!result.hasMore || result.bookings.isEmpty) break;
      page++;
    }

    // Reported rather than swallowed: a filter applied over a truncated
    // catalogue would look like "no matches" instead of "not all loaded".
    if (page > maxPages && totalItems > all.length) {
      AdminLog.failure(
        'Booking catalogue stopped at the $maxPages page cap — '
        '${all.length} of $totalItems loaded',
      );
      onCapped?.call(all.length, totalItems);
    }

    AdminLog.data('Booking catalogue → ${all.length}');
    return all;
  }

  @override
  Future<BookingStats> fetchStats() async {
    final response = await _remote.stats();
    if (!response.isOk) throw response.toException();

    final stats = BookingStatsMapper.fromJson(response.payload);
    AdminLog.data('Booking stats → $stats');
    return stats;
  }

  @override
  Future<List<Booking>> fetchCurrent() async {
    final response = await _remote.current();
    if (!response.isOk) throw response.toException();

    final bookings = BookingMapper.listFrom(response.data);
    AdminLog.data('Current bookings → ${bookings.length}');
    return bookings;
  }

  @override
  Future<Booking> fetchBooking(int id) async {
    final response = await _remote.detail(id);
    if (!response.isOk) throw response.toException();

    final booking = BookingMapper.fromJson(response.payload);
    AdminLog.data('Booking detail → $booking');
    return booking;
  }

  @override
  Future<Booking> createBooking(BookingDraft draft) async {
    final body = draft.toCreateJson();

    // Fail before the round trip rather than let the server reject a body it
    // could never accept. These are exactly the fields the form marks required.
    if (body['userId'] == null) {
      throw const ValidationException('Pick a customer.');
    }
    if (body['sportId'] == null) {
      throw const ValidationException('Pick a sport.');
    }
    if (body['courtId'] == null) {
      throw const ValidationException('Pick a court.');
    }
    if (body['date'] == null) {
      throw const ValidationException('Pick a date.');
    }
    if (body['startTime'] == null || body['endTime'] == null) {
      throw const ValidationException('Set the start and end times.');
    }

    final start = draft.startTime;
    final end = draft.endTime;
    if (start != null && end != null && start.minutesUntil(end) == 0) {
      throw const ValidationException(
        'The end time cannot equal the start time.',
      );
    }

    final response = await _remote.create(body);
    if (!response.isOk) throw response.toException();

    final created = BookingMapper.maybeFromBody(response.data);
    AdminLog.success('Created booking ${created?.id ?? '(id not echoed)'}');

    return created ??
        Booking(
          id: 0,
          userId: draft.userId,
          courtId: draft.courtId,
          sportId: draft.sportId,
          date: draft.date,
        );
  }

  @override
  Future<Booking> updateBooking(int id, BookingDraft draft) async {
    final body = draft.toUpdateJson();
    if (body.isEmpty) {
      throw const BadRequestException('Nothing to update.');
    }

    final response = await _remote.update(id, body);
    if (!response.isOk) throw response.toException();

    AdminLog.success('Updated booking $id');
    return BookingMapper.maybeFromBody(response.data) ?? Booking(id: id);
  }

  @override
  Future<void> deleteBooking(int id) async {
    final response = await _remote.remove(id);
    if (!response.isOk) throw response.toException();
    AdminLog.success('Deleted booking $id');
  }

  @override
  Future<List<Court>> fetchCourts({int? complexId, int? sportId}) async {
    final courts = await _courts.fetchCourts(
      complexId: complexId,
      sportId: sportId,
    );
    AdminLog.data('Courts for bookings module → ${courts.length}');
    return courts;
  }

  @override
  Future<List<Sport>> fetchSports({bool refresh = false}) async {
    final sports = await _sports.fetchSports();
    AdminLog.data('Sports for bookings module → ${sports.length}');
    return sports;
  }

  @override
  Future<List<SportsComplex>> fetchSportComplexes({
    bool refresh = false,
  }) async {
    final complexes = await _complexes.fetchComplexes(
      refresh: refresh,
      includeHidden: true,
    );
    AdminLog.data('Complexes for bookings module → ${complexes.length}');
    return complexes;
  }
}
