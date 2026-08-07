import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../core/employee_log.dart';
import '../../domain/entities/employee_formats.dart';
import '../../domain/entities/employee_master.dart';
import '../../domain/repositories/employee_dashboard_repository.dart';
import 'employee_view_state.dart';

/// Blocked Slots — a court's availability on **one date**.
///
/// Distinct from the Slot screen, which edits the recurring template. Three
/// kinds of unavailability show up here and they are not interchangeable:
///
/// * **Booked by a customer** — never touchable from here. Freeing it means
///   cancelling the booking, which is a different screen and a refund decision.
/// * **Blocked by a partner feed** (KheloMore, Huddle) — releasable. The venue
///   must never be locked out of its own courts by an aggregator.
/// * **Blocked recurring** — the legacy form, where the slot *template* was set
///   Inactive. There is no date row to release, so unblocking reactivates the
///   template and reopens **every** date. Confirmed before it happens.
class EmployeeBlockedSlotsController extends ChangeNotifier {
  EmployeeBlockedSlotsController(this._repository) {
    EmployeeLog.life('EmployeeBlockedSlotsController created');
  }

  final EmployeeDashboardRepository _repository;

  EmployeeViewState _state = EmployeeViewState.idle;
  List<EmployeeCourt> _courts = const [];
  List<EmployeeAvailableSlot> _slots = const [];
  String? _error;

  EmployeeCourt? _court;
  DateTime _date = DateTime.now();

  bool _courtsLoaded = false;
  bool _fetched = false;
  bool _busy = false;
  int? _busySlotId;
  bool _disposed = false;

  /// Which slots to show: all, only the free ones, only the closed ones.
  EmployeeSlotFilter _filter = EmployeeSlotFilter.all;

  EmployeeViewState get state => _state;
  List<EmployeeCourt> get courts => _courts;
  EmployeeCourt? get court => _court;
  DateTime get date => _date;
  String? get error => _error;
  EmployeeSlotFilter get filter => _filter;

  /// True once a court and date have actually been fetched — before that the
  /// screen shows a prompt rather than an empty grid.
  bool get fetched => _fetched;

  /// A bulk action is running.
  bool get busy => _busy;

  /// The slot with a single toggle in flight, if any.
  int? get busySlotId => _busySlotId;

  bool get canFetch => _court != null;

  List<EmployeeAvailableSlot> get slots => _slots;

  List<EmployeeAvailableSlot> get visibleSlots {
    switch (_filter) {
      case EmployeeSlotFilter.available:
        return _slots.where((s) => !s.isBooked).toList(growable: false);
      case EmployeeSlotFilter.blocked:
        return _slots.where((s) => s.isBooked).toList(growable: false);
      case EmployeeSlotFilter.all:
        return _slots;
    }
  }

  int get blockedCount => _slots.where((s) => s.isBooked).length;

  /// Loads the court list. The first court is selected so the picker starts on
  /// something rather than on "— Select —".
  Future<void> loadCourts() async {
    if (_courtsLoaded) return;

    _state = EmployeeViewState.loading;
    _notify();

    try {
      final courts = await _repository.getCourts();
      if (_disposed) return;

      _courts = courts;
      _court ??= courts.isEmpty ? null : courts.first;
      _courtsLoaded = true;
      _error = null;
      _state = EmployeeViewState.ready;
    } catch (e) {
      if (_disposed) return;
      _error = _describe(e);
      _state = EmployeeViewState.failed;
      EmployeeLog.failure('Blocked slots — court list failed', error: e);
    } finally {
      _notify();
    }
  }

  Future<void> fetchSlots() async {
    final court = _court;
    if (court == null) return;

    _state = EmployeeViewState.loading;
    _error = null;
    _notify();

    try {
      final slots = await _repository.getAvailableSlots(
        courtId: court.id,
        date: formatIsoDate(_date),
      );
      if (_disposed) return;

      _slots = slots;
      _fetched = true;
      _state = EmployeeViewState.ready;
    } catch (e) {
      if (_disposed) return;
      _slots = const [];
      _error = _describe(e);
      _state = EmployeeViewState.failed;
      EmployeeLog.failure('Availability fetch failed', error: e);
    } finally {
      _notify();
    }
  }

  void selectCourt(EmployeeCourt? court) {
    if (court?.id == _court?.id) return;
    _court = court;
    // The rows on screen describe the previous court; keeping them would be a
    // lie the moment the picker moves.
    _slots = const [];
    _fetched = false;
    EmployeeLog.ui('Blocked slots court → ${court?.displayName ?? 'none'}');
    _notify();
  }

  void selectDate(DateTime date) {
    if (formatIsoDate(date) == formatIsoDate(_date)) return;
    _date = date;
    _slots = const [];
    _fetched = false;
    EmployeeLog.ui('Blocked slots date → ${formatIsoDate(date)}');
    _notify();
  }

  void setFilter(EmployeeSlotFilter value) {
    if (value == _filter) return;
    _filter = value;
    _notify();
  }

  /// Blocks or unblocks one slot for the selected date.
  ///
  /// Returns null on success, else a message. A customer booking is refused
  /// here rather than sent to the API — the server would refuse it too, but
  /// saying why locally is faster and clearer.
  Future<String?> toggle(EmployeeAvailableSlot slot) async {
    final court = _court;
    if (court == null) return 'Pick a court first.';

    if (slot.isUserBooked) {
      return 'Booked by a customer — cancel the booking to free this slot.';
    }

    _busySlotId = slot.id;
    _notify();

    try {
      await _apply(court.id, slot, block: !slot.isBlocked);
      // Re-read rather than guess: the server decides who owns a block, and a
      // partner feed can have claimed the slot since the page loaded.
      await fetchSlots();
      return null;
    } catch (e) {
      EmployeeLog.failure('Slot toggle failed', error: e);
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
  /// Customer bookings are skipped entirely — a bulk action must never touch a
  /// slot somebody paid for. Returns a summary, since a partial failure is a
  /// real outcome here: the requests go one at a time and any of them can be
  /// refused on its own.
  Future<EmployeeBulkResult> bulkSet({required bool block}) async {
    final court = _court;
    if (court == null) {
      return const EmployeeBulkResult(attempted: 0, succeeded: 0);
    }

    final targets = _slots
        .where((s) => !s.isUserBooked && s.isBlocked != block)
        .toList(growable: false);

    if (targets.isEmpty) {
      return const EmployeeBulkResult(attempted: 0, succeeded: 0);
    }

    _busy = true;
    _notify();

    var succeeded = 0;
    for (final slot in targets) {
      try {
        await _apply(court.id, slot, block: block);
        succeeded += 1;
      } catch (e) {
        EmployeeLog.failure('Bulk ${block ? 'block' : 'unblock'} failed', error: e);
      }
    }

    _busy = false;
    await fetchSlots();

    return EmployeeBulkResult(
      attempted: targets.length,
      succeeded: succeeded,
    );
  }

  /// How many of [slots] would reopen every date if unblocked — the recurring
  /// ones. Used to warn before a bulk unblock does more than the user meant.
  int recurringAmong(Iterable<EmployeeAvailableSlot> slots) =>
      slots.where((s) => s.isRecurringBlock).length;

  /// The slots a bulk action would actually touch.
  List<EmployeeAvailableSlot> bulkTargets({required bool block}) => _slots
      .where((s) => !s.isUserBooked && s.isBlocked != block)
      .toList(growable: false);

  /// The one place that knows which of the two mechanisms applies.
  ///
  /// A recurring block has no date row to release, so unblocking it has to go
  /// through the slot template's toggle instead — and that reopens every date.
  Future<void> _apply(
    int courtId,
    EmployeeAvailableSlot slot, {
    required bool block,
  }) {
    if (!block && slot.isRecurringBlock) {
      return _repository.setSlotStatus(courtId, slot.id, 'Active');
    }

    final date = formatIsoDate(_date);
    return block
        ? _repository.blockSlotForDate(
            courtId: courtId,
            slotId: slot.id,
            date: date,
          )
        : _repository.unblockSlotForDate(
            courtId: courtId,
            slotId: slot.id,
            date: date,
          );
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
    EmployeeLog.life('EmployeeBlockedSlotsController disposed');
    super.dispose();
  }
}

/// Which slots the grid shows.
enum EmployeeSlotFilter {
  all('All'),
  available('Available'),
  blocked('Blocked');

  const EmployeeSlotFilter(this.label);

  final String label;
}

/// The outcome of a bulk block / unblock.
///
/// [succeeded] can be lower than [attempted]: the requests go one at a time and
/// any of them can be refused on its own, so the UI has to be able to say "4 of
/// 7" rather than claiming a clean sweep.
class EmployeeBulkResult {
  const EmployeeBulkResult({required this.attempted, required this.succeeded});

  final int attempted;
  final int succeeded;

  bool get nothingToDo => attempted == 0;
  bool get isComplete => attempted > 0 && succeeded == attempted;
}
