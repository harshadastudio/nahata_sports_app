import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/court.dart';
import '../../domain/entities/court_slot.dart';
import '../../domain/repositories/court_repository.dart';
import '../../domain/repositories/court_slot_repository.dart';
import 'view_state.dart';

/// Blocked Slots — a court's availability on **one date**.
///
/// Distinct from Manage Slots, which edits the recurring template. Three kinds
/// of unavailability show up here and they are not interchangeable:
///
/// * **Booked by a customer** — never touchable from here. Freeing it means
///   cancelling the booking.
/// * **Blocked by a partner feed** (KheloMore, Huddle) — releasable. The venue
///   must never be locked out of its own courts by an aggregator.
/// * **Blocked recurring** — the slot *template* was set Inactive. There is no
///   date row to release, so unblocking reactivates the template and reopens
///   **every** date. Confirmed before it happens.
class AdminBlockedSlotsController extends ChangeNotifier {
  AdminBlockedSlotsController(this._courtRepository, this._slotRepository) {
    AdminLog.life('AdminBlockedSlotsController created');
  }

  final CourtRepository _courtRepository;
  final CourtSlotRepository _slotRepository;

  ViewState _courtsState = ViewState.idle;
  List<Court> _courts = const [];
  String? _courtsError;

  Court? _court;
  DateTime _date = _today();

  ViewState _state = ViewState.idle;
  List<AvailableSlot> _slots = const [];
  String? _error;
  bool _fetched = false;

  bool _busy = false;
  int? _busySlotId;
  bool _disposed = false;

  AdminSlotFilter _filter = AdminSlotFilter.all;

  ViewState get courtsState => _courtsState;
  List<Court> get courts => _courts;
  String? get courtsError => _courtsError;

  Court? get court => _court;
  DateTime get date => _date;

  ViewState get state => _state;
  String? get error => _error;
  List<AvailableSlot> get slots => _slots;
  AdminSlotFilter get filter => _filter;

  /// True once a court and date have actually been fetched — before that the
  /// screen shows a prompt rather than an empty grid.
  bool get fetched => _fetched;

  /// A bulk action is running.
  bool get busy => _busy;

  /// The slot with a single action in flight, if any.
  int? get busySlotId => _busySlotId;

  bool get canFetch => _court != null;

  List<AvailableSlot> get visibleSlots {
    switch (_filter) {
      case AdminSlotFilter.available:
        return _slots.where((s) => !s.isBooked).toList(growable: false);
      case AdminSlotFilter.blocked:
        return _slots.where((s) => s.isBlocked ?? false).toList(growable: false);
      case AdminSlotFilter.all:
        return _slots;
    }
  }

  int get blockedCount => _slots.where((s) => s.isBlocked ?? false).length;

  /// Loads the court list. The first court is selected so the picker starts on
  /// something rather than on "— Select —". [refresh] forces a reload even
  /// when courts already loaded (or failed) once — used by the retry link.
  Future<void> loadCourts({bool refresh = false}) async {
    if (_courtsState != ViewState.idle && !refresh) return;

    _courtsState = ViewState.loading;
    _notify();

    try {
      final courts = await _courtRepository.fetchCourts();
      if (_disposed) return;

      _courts = courts;
      _court ??= courts.isEmpty ? null : courts.first;
      _courtsState = ViewState.ready;
      _courtsError = null;
    } catch (e) {
      if (_disposed) return;
      _courtsError = _describe(e);
      _courtsState = ViewState.failed;
      AdminLog.failure('Blocked slots — court list failed', error: e);
    } finally {
      _notify();
    }
  }

  Future<void> fetchSlots() async {
    final court = _court;
    if (court == null) return;

    _state = ViewState.loading;
    _error = null;
    _notify();

    try {
      final slots = await _slotRepository.fetchAvailableSlots(court.id, _date);
      if (_disposed) return;

      _slots = slots;
      _fetched = true;
      _state = ViewState.ready;
    } catch (e) {
      if (_disposed) return;
      _slots = const [];
      _error = _describe(e);
      _state = ViewState.failed;
      AdminLog.failure('Availability fetch failed', error: e);
    } finally {
      _notify();
    }
  }

  void selectCourt(Court? court) {
    if (court?.id == _court?.id) return;
    _court = court;
    // The rows on screen describe the previous court; keeping them would be a
    // lie the moment the picker moves.
    _slots = const [];
    _fetched = false;
    AdminLog.ui('Blocked slots court → ${court?.displayName ?? 'none'}');
    _notify();
  }

  void selectDate(DateTime date) {
    final normalised = DateTime(date.year, date.month, date.day);
    if (normalised == _date) return;
    _date = normalised;
    _slots = const [];
    _fetched = false;
    AdminLog.ui('Blocked slots date → ${_isoDate(normalised)}');
    _notify();
  }

  void setFilter(AdminSlotFilter value) {
    if (value == _filter) return;
    _filter = value;
    _notify();
  }

  /// Blocks a slot for the selected date. [billed] records it as a paid
  /// booking (BOOK) rather than plain maintenance (BLOCK).
  ///
  /// Returns null on success, else a message. A customer booking is refused
  /// here rather than sent to the API — the server would refuse it too, but
  /// saying why locally is faster and clearer.
  Future<String?> block(
    AvailableSlot slot, {
    required bool billed,
    num? amount,
    String? notes,
  }) async {
    final court = _court;
    final slotId = slot.slotId;
    if (court == null) return 'Pick a court first.';
    if (slotId == null) return 'This slot has no id.';
    if (slot.isUserBooked) {
      return 'Booked by a customer — cancel the booking to free this slot.';
    }

    _busySlotId = slotId;
    _notify();

    try {
      await _slotRepository.blockSlotForDate(
        courtId: court.id,
        slotId: slotId,
        date: _isoDate(_date),
        countAsRevenue: billed,
        amount: amount,
        notes: notes,
      );
      await fetchSlots();
      return null;
    } catch (e) {
      AdminLog.failure('Slot block failed', error: e);
      return _describe(e);
    } finally {
      if (!_disposed) {
        _busySlotId = null;
        _notify();
      }
    }
  }

  /// Releases a slot for the selected date. A recurring (`Template`) block has
  /// no date row to release, so this reactivates the template instead —
  /// reopening the time on **every** date.
  Future<String?> unblock(AvailableSlot slot) async {
    final court = _court;
    final slotId = slot.slotId;
    if (court == null) return 'Pick a court first.';
    if (slotId == null) return 'This slot has no id.';

    _busySlotId = slotId;
    _notify();

    try {
      if (slot.isRecurringBlock) {
        await _slotRepository.setSlotStatus(court.id, slotId, 'Active');
      } else {
        await _slotRepository.unblockSlotForDate(
          courtId: court.id,
          slotId: slotId,
          date: _isoDate(_date),
        );
      }
      await fetchSlots();
      return null;
    } catch (e) {
      AdminLog.failure('Slot unblock failed', error: e);
      return _describe(e);
    } finally {
      if (!_disposed) {
        _busySlotId = null;
        _notify();
      }
    }
  }

  /// The billed/unbilled correction on an already-blocked slot of our own —
  /// re-posts the block with the opposite `countAsRevenue`. Only meaningful on
  /// a slot that is blocked, not a partner hold, and not a recurring block —
  /// neither of those has a billable row of ours to correct.
  Future<String?> setBilled(AvailableSlot slot, bool billed) async {
    final court = _court;
    final slotId = slot.slotId;
    if (court == null) return 'Pick a court first.';
    if (slotId == null) return 'This slot has no id.';
    if (!(slot.isBlocked ?? false) || slot.isPartnerBlock || slot.isRecurringBlock) {
      return 'This block cannot be re-billed.';
    }

    _busySlotId = slotId;
    _notify();

    try {
      await _slotRepository.blockSlotForDate(
        courtId: court.id,
        slotId: slotId,
        date: _isoDate(_date),
        countAsRevenue: billed,
      );
      await fetchSlots();
      return null;
    } catch (e) {
      AdminLog.failure('Slot re-bill failed', error: e);
      return _describe(e);
    } finally {
      if (!_disposed) {
        _busySlotId = null;
        _notify();
      }
    }
  }

  /// Blocks or unblocks every slot that is not already in that state.
  ///
  /// [billed] only matters for a bulk BLOCK — `true` is Book All. Customer
  /// bookings are skipped entirely. Returns a summary, since a partial failure
  /// is a real outcome: the requests go one at a time and any can be refused
  /// on its own.
  Future<AdminBulkResult> bulkSet({
    required bool block,
    bool billed = false,
  }) async {
    final court = _court;
    if (court == null) {
      return const AdminBulkResult(attempted: 0, succeeded: 0);
    }

    final targets = bulkTargets(block: block);
    if (targets.isEmpty) {
      return const AdminBulkResult(attempted: 0, succeeded: 0);
    }

    _busy = true;
    _notify();

    var succeeded = 0;
    for (final slot in targets) {
      final slotId = slot.slotId;
      if (slotId == null) continue;

      try {
        if (!block && slot.isRecurringBlock) {
          await _slotRepository.setSlotStatus(court.id, slotId, 'Active');
        } else if (block) {
          await _slotRepository.blockSlotForDate(
            courtId: court.id,
            slotId: slotId,
            date: _isoDate(_date),
            countAsRevenue: billed,
          );
        } else {
          await _slotRepository.unblockSlotForDate(
            courtId: court.id,
            slotId: slotId,
            date: _isoDate(_date),
          );
        }
        succeeded += 1;
      } catch (e) {
        AdminLog.failure('Bulk ${block ? 'block' : 'unblock'} failed', error: e);
      }
    }

    _busy = false;
    await fetchSlots();

    return AdminBulkResult(attempted: targets.length, succeeded: succeeded);
  }

  /// How many of [slots] would reopen every date if unblocked — the recurring
  /// ones. Used to warn before a bulk unblock does more than the user meant.
  int recurringAmong(Iterable<AvailableSlot> slots) =>
      slots.where((s) => s.isRecurringBlock).length;

  /// The slots a bulk action would actually touch.
  List<AvailableSlot> bulkTargets({required bool block}) => _slots
      .where((s) => !s.isUserBooked && (s.isBlocked ?? false) != block)
      .toList(growable: false);

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static String _isoDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  static String _describe(Object error) => error is ApiException
      ? error.message
      : 'Something went wrong. Please try again.';

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    AdminLog.life('AdminBlockedSlotsController disposed');
    super.dispose();
  }
}

/// Which slots the grid shows.
enum AdminSlotFilter {
  all('All'),
  available('Available'),
  blocked('Blocked');

  const AdminSlotFilter(this.label);

  final String label;
}

/// The outcome of a bulk block / unblock / book.
///
/// [succeeded] can be lower than [attempted]: the requests go one at a time
/// and any of them can be refused on its own, so the UI has to be able to say
/// "4 of 7" rather than claiming a clean sweep.
class AdminBulkResult {
  const AdminBulkResult({required this.attempted, required this.succeeded});

  final int attempted;
  final int succeeded;

  bool get nothingToDo => attempted == 0;
  bool get isComplete => attempted > 0 && succeeded == attempted;
}
