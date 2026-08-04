import '../entities/admin_role.dart';
import '../entities/court_slot.dart';

/// Slot CRUD for one court, plus the two availability reads.
///
/// Every route here is scoped to a court, except [fetchAvailability] — which is
/// deliberately court-agnostic: the spec asks it to answer "is anything free"
/// without naming the court.
abstract class CourtSlotRepository {
  /// `GET /courts/{courtId}/slots`
  Future<List<CourtSlot>> fetchSlots(int courtId);

  /// `POST /courts/{courtId}/slots`
  Future<CourtSlot> createSlot(int courtId, CourtSlotDraft draft);

  /// `PUT /courts/{courtId}/slots/{slotId}`
  Future<CourtSlot> updateSlot(int courtId, int slotId, CourtSlotDraft draft);

  /// `PATCH /courts/{courtId}/slots/{slotId}/toggle` — block / unblock.
  ///
  /// Returns the status the server settled on when it echoes one, so the row
  /// reflects the truth rather than what the caller assumed.
  Future<AdminUserStatus?> toggleSlot(int courtId, int slotId);

  /// `DELETE /courts/{courtId}/slots/{slotId}`
  Future<void> deleteSlot(int courtId, int slotId);

  /// `GET /courts/{courtId}/available-slots?date=`
  Future<List<AvailableSlot>> fetchAvailableSlots(int courtId, DateTime date);

  /// `GET /courts/availability?sportComplexId=&sportId=&date=`
  Future<List<AvailabilityWindow>> fetchAvailability({
    int? complexId,
    int? sportId,
    required DateTime date,
  });
}
