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

  /// `POST /courts/{courtId}/slots/{slotId}/block` — that date only.
  ///
  /// `countAsRevenue: true` (BOOK) records the block as a paid booking;
  /// re-posting with the opposite value on an already-blocked slot is the
  /// un-bill/re-bill correction and only changes the billed flag. Throws a
  /// `ConflictException` (409, `SLOT_BOOKED`) when a customer already holds
  /// the slot.
  Future<void> blockSlotForDate({
    required int courtId,
    required int slotId,
    required String date,
    String? notes,
    bool countAsRevenue = false,
    num? amount,
  });

  /// `POST /courts/{courtId}/slots/{slotId}/unblock` — that date only.
  ///
  /// Releases whoever placed the block, partner holds included.
  Future<void> unblockSlotForDate({
    required int courtId,
    required int slotId,
    required String date,
  });

  /// `PATCH /courts/{courtId}/slots/{slotId}/toggle` with an explicit status.
  ///
  /// ⚠️ Flips the **template**, so it applies to every date. Used to
  /// reactivate a recurring (`Template`) block, which has no date row for
  /// [unblockSlotForDate] to release.
  Future<void> setSlotStatus(int courtId, int slotId, String status);

  /// `GET /courts/availability?sportComplexId=&sportId=&date=`
  Future<List<AvailabilityWindow>> fetchAvailability({
    int? complexId,
    int? sportId,
    required DateTime date,
  });
}
