import '../../../../models/sports_complex_model.dart';
import '../entities/event_pass.dart';

/// Event pass CRUD, image upload, and the event booking reads.
///
/// **No response for any of these routes was captured** — the Postman
/// collection ships them with empty `response` arrays — so every mapper reads
/// through ordered candidate keys and the shapes are inferred from the
/// storefront models, which *were* written against live payloads.
abstract class EventPassRepository {
  /// `GET /event-passes?page=&limit=`
  ///
  /// The list route answers `{ data: [...], pagination: {...} }` — the
  /// counters sit beside the rows rather than inside them, unlike every other
  /// paginated route in this console.
  Future<EventPassPageResult<AdminEventPass>> fetchEventPasses({
    int page,
    int limit,
  });

  /// `GET /event-passes/{eventPassId}`
  Future<AdminEventPass> fetchEventPass(int id);

  /// `POST /event-passes` — creates the event together with its slots and FAQs.
  Future<AdminEventPass> createEventPass(EventPassDraft draft);

  /// `PUT /event-passes/{eventPassId}`
  Future<AdminEventPass> updateEventPass(int id, EventPassDraft draft);

  /// `DELETE /event-passes/{eventPassId}`
  Future<void> deleteEventPass(int id);

  /// `POST /event-passes/upload-image` — multipart, field `image`.
  Future<String> uploadImage(String filePath, {String? filename});

  /// `GET /event-passes/bookings/all?page=&limit=`
  Future<EventPassPageResult<EventPassBookingRow>> fetchBookings({
    int page,
    int limit,
  });

  /// `GET /event-passes/bookings/my`
  ///
  /// Scoped to the signed-in account, so it answers for the *admin's own*
  /// bookings — not something the console lists. Implemented because the
  /// module documents it; the UI uses [fetchBookings] instead.
  Future<List<EventPassBookingRow>> fetchMyBookings();

  /// `POST /event-passes/bookings/create` — books passes on behalf of a
  /// customer, which is what makes this route useful from the desk.
  Future<EventPassBookingRow> createBooking(EventBookingDraft draft);

  /// Venues for the form dropdown, from `GET /sports-complexes`.
  Future<List<SportsComplex>> fetchSportComplexes({bool refresh});
}
