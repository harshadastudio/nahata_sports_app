import '../../../../core/network/api_exception.dart';
import '../../../../models/sports_complex_model.dart';
import '../../../../repositories/sports_complex_repository.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/event_pass.dart';
import '../../domain/repositories/event_pass_repository.dart';
import '../datasources/event_pass_remote_data_source.dart';
import '../models/event_pass_admin_model.dart';

/// [EventPassRepository] over the JWT backend.
class EventPassRepositoryImpl implements EventPassRepository {
  EventPassRepositoryImpl({
    EventPassRemoteDataSource? remote,
    SportsComplexRepository? complexes,
  }) : _remote = remote ?? EventPassRemoteDataSource(),
       _complexes = complexes ?? SportsComplexRepository.instance;

  final EventPassRemoteDataSource _remote;
  final SportsComplexRepository _complexes;

  @override
  Future<EventPassPageResult<AdminEventPass>> fetchEventPasses({
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _remote.list(page: page, limit: limit);
    if (!response.isOk) throw response.toException();

    final result = EventPassMapper.pageFrom(
      response.data,
      requestedPage: page,
      requestedLimit: limit,
    );
    _warnIfUnreadable(
      'event passes',
      rows: EventPassMapper.rowsIn(response.data),
      parsed: result.items.length,
      body: response.data,
    );
    AdminLog.data('Event passes → $result');
    return result;
  }

  @override
  Future<AdminEventPass> fetchEventPass(int id) async {
    final response = await _remote.detail(id);
    if (!response.isOk) throw response.toException();

    final event = EventPassMapper.fromJson(response.payload);
    AdminLog.data('Event pass detail → $event');
    return event;
  }

  @override
  Future<AdminEventPass> createEventPass(EventPassDraft draft) async {
    final body = draft.toCreateJson();

    // Fail before the round trip rather than let the server reject a body it
    // could never accept.
    if ((body['title'] as String).isEmpty) {
      throw const ValidationException('Give the event a title.');
    }
    if (body['sportComplexId'] == null) {
      throw const ValidationException('Pick a sports complex.');
    }

    final slots = body['slots'] as List;
    if (slots.isEmpty) {
      // An event with no slot has nothing to sell, and the storefront would
      // render it as permanently unavailable.
      throw const ValidationException('Add at least one slot.');
    }
    for (final entry in slots) {
      final slot = entry as Map<String, dynamic>;
      if (slot['date'] == null) {
        throw const ValidationException('Every slot needs a date.');
      }
      if (slot['startTime'] == null || slot['endTime'] == null) {
        throw const ValidationException('Every slot needs a start and end.');
      }
      if (slot['price'] == null) {
        throw const ValidationException('Every slot needs a price.');
      }
      if (slot['capacity'] == null) {
        throw const ValidationException('Every slot needs a capacity.');
      }
    }

    final response = await _remote.create(body);
    if (!response.isOk) throw response.toException();

    final created = EventPassMapper.maybeFromBody(response.data);
    AdminLog.success('Created event ${created?.id ?? '(id not echoed)'}');

    return created ??
        AdminEventPass(
          id: 0,
          title: draft.title,
          sportComplexId: draft.sportComplexId,
        );
  }

  @override
  Future<AdminEventPass> updateEventPass(int id, EventPassDraft draft) async {
    final body = draft.toUpdateJson();
    if (body.isEmpty) {
      throw const BadRequestException('Nothing to update.');
    }

    final response = await _remote.update(id, body);
    if (!response.isOk) throw response.toException();

    AdminLog.success('Updated event $id');
    return EventPassMapper.maybeFromBody(response.data) ??
        AdminEventPass(id: id);
  }

  @override
  Future<void> deleteEventPass(int id) async {
    final response = await _remote.remove(id);
    if (!response.isOk) throw response.toException();
    AdminLog.success('Deleted event $id');
  }

  @override
  Future<String> uploadImage(String filePath, {String? filename}) async {
    final response = await _remote.uploadImage(filePath, filename: filename);
    if (!response.isOk) throw response.toException();

    final url = EventPassMapper.uploadedUrlFrom(response.data);
    if (url == null || url.isEmpty) {
      // Without a URL there is nothing to put in the event payload, so this is
      // a failure even though the HTTP call succeeded.
      throw const ServerException(
        'The image uploaded but the server did not return its URL.',
      );
    }

    AdminLog.success('Uploaded event image');
    return url;
  }

  @override
  Future<EventPassPageResult<EventPassBookingRow>> fetchBookings({
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _remote.allBookings(page: page, limit: limit);
    if (!response.isOk) throw response.toException();

    final result = EventBookingMapper.pageFrom(
      response.data,
      requestedPage: page,
      requestedLimit: limit,
    );
    _warnIfUnreadable(
      'event bookings',
      rows: EventBookingMapper.rowsIn(response.data),
      parsed: result.items.length,
      body: response.data,
    );
    AdminLog.data('Event bookings → $result');
    return result;
  }

  @override
  Future<List<EventPassBookingRow>> fetchMyBookings() async {
    final response = await _remote.myBookings();
    if (!response.isOk) throw response.toException();

    final bookings = EventBookingMapper.listFrom(response.data);
    AdminLog.data('My event bookings → ${bookings.length}');
    return bookings;
  }

  @override
  Future<EventPassBookingRow> createBooking(EventBookingDraft draft) async {
    final body = draft.toJson();

    if (body['eventPassId'] == null) {
      throw const ValidationException('Pick an event.');
    }
    if (body['slotId'] == null) {
      throw const ValidationException('Pick a slot.');
    }
    if ((body['name'] as String).isEmpty) {
      throw const ValidationException("Enter the customer's name.");
    }
    if ((body['phone'] as String).isEmpty) {
      throw const ValidationException("Enter the customer's phone number.");
    }
    final passes = body['numberOfPasses'] as int;
    if (passes < 1) {
      throw const ValidationException('Book at least one pass.');
    }

    final response = await _remote.createBooking(body);
    if (!response.isOk) throw response.toException();

    final created = EventBookingMapper.maybeFromBody(response.data);
    AdminLog.success(
      'Created event booking ${created?.id ?? '(id not echoed)'}',
    );

    return created ??
        EventPassBookingRow(
          id: 0,
          eventPassId: draft.eventPassId,
          slotId: draft.slotId,
          customerName: draft.name,
          numberOfPasses: draft.numberOfPasses,
        );
  }

  /// Says in the log which kind of empty this was.
  ///
  /// No response for these routes was ever captured, so "the list is empty" and
  /// "this mapper could not read the list" look identical on screen. This tells
  /// them apart, and names the keys it did see so the fix is one edit away.
  static void _warnIfUnreadable(
    String what, {
    required List<Map<String, dynamic>> rows,
    required int parsed,
    required Object? body,
  }) {
    if (parsed > 0) return;

    if (rows.isEmpty) {
      final keys = body is Map ? body.keys.toList() : const <String>[];
      AdminLog.data(
        'No $what in the response. Top-level keys: $keys — if the list is in '
        'one of these, add it to the mapper\'s listKeys.',
      );
      return;
    }

    AdminLog.failure(
      '${rows.length} $what rows were returned but none carried a readable '
      'id, so all were dropped. Row keys: ${rows.first.keys.toList()}',
    );
  }

  @override
  Future<List<SportsComplex>> fetchSportComplexes({
    bool refresh = false,
  }) async {
    final complexes = await _complexes.fetchComplexes(
      refresh: refresh,
      includeHidden: true,
    );
    AdminLog.data('Complexes for events module → ${complexes.length}');
    return complexes;
  }
}
