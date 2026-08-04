import '../../../../core/network/api_exception.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/admin_role.dart';
import '../../domain/entities/court_slot.dart';
import '../../domain/repositories/court_slot_repository.dart';
import '../datasources/court_remote_data_source.dart';
import '../models/court_slot_model.dart';

/// [CourtSlotRepository] over the JWT backend.
///
/// Shares [CourtRemoteDataSource] with the court repository: every slot route
/// is a child of a court route, and splitting the two would mean two objects
/// building the same paths.
class CourtSlotRepositoryImpl implements CourtSlotRepository {
  CourtSlotRepositoryImpl({CourtRemoteDataSource? remote})
    : _remote = remote ?? CourtRemoteDataSource();

  final CourtRemoteDataSource _remote;

  @override
  Future<List<CourtSlot>> fetchSlots(int courtId) async {
    final response = await _remote.slots(courtId);
    if (!response.isOk) throw response.toException();

    final slots = CourtSlotMapper.listFrom(response.data);
    AdminLog.data('Slots for court $courtId → ${slots.length}');
    return slots;
  }

  @override
  Future<CourtSlot> createSlot(int courtId, CourtSlotDraft draft) async {
    final body = draft.toCreateJson();

    // The one-hour rule is the API's, not this form's — checking it here means
    // a bad window never costs a round trip, whichever screen submitted it.
    final invalid = CourtSlotDraft.validateWindow(
      draft.startTime,
      draft.endTime,
    );
    if (invalid != null) throw ValidationException(invalid);

    final response = await _remote.createSlot(courtId, body);
    if (!response.isOk) throw response.toException();

    final created = CourtSlotMapper.maybeFromBody(response.data);
    AdminLog.success(
      'Created slot ${created?.id ?? '(id not echoed)'} on court $courtId',
    );

    return created ??
        CourtSlot(
          id: 0,
          courtId: courtId,
          startTimeRaw: draft.startTime?.wire,
          endTimeRaw: draft.endTime?.wire,
        );
  }

  @override
  Future<CourtSlot> updateSlot(
    int courtId,
    int slotId,
    CourtSlotDraft draft,
  ) async {
    final body = draft.toUpdateJson();
    if (body.isEmpty) {
      throw const BadRequestException('Nothing to update.');
    }

    // Only when both ends are being changed: a partial edit leaves the other
    // end as the server has it, and this app cannot judge the pair.
    if (draft.startTime != null && draft.endTime != null) {
      final invalid = CourtSlotDraft.validateWindow(
        draft.startTime,
        draft.endTime,
      );
      if (invalid != null) throw ValidationException(invalid);
    }

    final response = await _remote.updateSlot(courtId, slotId, body);
    if (!response.isOk) throw response.toException();

    AdminLog.success('Updated slot $slotId on court $courtId');
    return CourtSlotMapper.maybeFromBody(response.data) ??
        CourtSlot(id: slotId, courtId: courtId);
  }

  @override
  Future<AdminUserStatus?> toggleSlot(int courtId, int slotId) async {
    final response = await _remote.toggleSlot(courtId, slotId);
    if (!response.isOk) throw response.toException();

    final status = CourtSlotMapper.statusFrom(response.data);
    AdminLog.success(
      'Toggled slot $slotId on court $courtId → ${status?.slug ?? 'unstated'}',
    );
    return status;
  }

  @override
  Future<void> deleteSlot(int courtId, int slotId) async {
    final response = await _remote.removeSlot(courtId, slotId);
    if (!response.isOk) throw response.toException();
    AdminLog.success('Deleted slot $slotId on court $courtId');
  }

  @override
  Future<List<AvailableSlot>> fetchAvailableSlots(
    int courtId,
    DateTime date,
  ) async {
    final response = await _remote.availableSlots(courtId, formatDate(date));
    if (!response.isOk) throw response.toException();

    final slots = AvailableSlotMapper.listFrom(response.data);
    AdminLog.data(
      'Available slots for court $courtId on ${formatDate(date)} → '
      '${slots.length}',
    );
    return slots;
  }

  @override
  Future<List<AvailabilityWindow>> fetchAvailability({
    int? complexId,
    int? sportId,
    required DateTime date,
  }) async {
    final response = await _remote.availability(
      complexId: complexId,
      sportId: sportId,
      date: formatDate(date),
    );
    if (!response.isOk) throw response.toException();

    final windows = AvailabilityMapper.listFrom(response.data);
    AdminLog.data(
      'Availability on ${formatDate(date)} → ${windows.length} windows',
    );
    return windows;
  }

  /// `yyyy-MM-dd`, the shape every date this API returns is in.
  static String formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
