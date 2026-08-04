import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/admin_role.dart';
import '../../domain/entities/court.dart';
import '../../domain/entities/court_slot.dart';
import '../../domain/repositories/court_slot_repository.dart';
import 'view_state.dart';

/// The three ways one court's schedule is presented.
enum SlotsView {
  schedule('Slot schedule', 'Slots'),
  day('Day availability', 'Day'),
  week('Week calendar', 'Week');

  const SlotsView(this.label, this.shortLabel);

  final String label;
  final String shortLabel;
}

/// The five summary figures above the slot table.
class SlotsSummary {
  const SlotsSummary({
    this.total = 0,
    this.active = 0,
    this.blocked = 0,
    this.regular = 0,
    this.customPrice = 0,
  });

  final int total;

  /// Bookable. The spec's own wording: Active = bookable, Inactive = blocked.
  final int active;
  final int blocked;

  final int regular;

  /// Slots charging something other than the court's hourly rate.
  final int customPrice;

  static SlotsSummary from(List<CourtSlot> slots) {
    var active = 0;
    var blocked = 0;
    var regular = 0;
    var custom = 0;

    for (final slot in slots) {
      if (slot.isBookable) active++;
      if (slot.isBlocked) blocked++;
      if (slot.slotType == SlotType.regular) regular++;
      if (slot.hasPriceOverride) custom++;
    }

    return SlotsSummary(
      total: slots.length,
      active: active,
      blocked: blocked,
      regular: regular,
      customPrice: custom,
    );
  }
}

/// One court's schedule: the recurring slots, one day's live availability, and
/// the week grid built from seven of those days.
class CourtSlotsController extends ChangeNotifier {
  CourtSlotsController(this._repository, this.court) {
    AdminLog.life('CourtSlotsController created for court ${court.id}');
    _selectedDate = _today();
    _weekStart = startOfWeek(_selectedDate);
  }

  final CourtSlotRepository _repository;

  /// The court being managed. Held rather than looked up so this screen works
  /// when opened directly from a row.
  final Court court;

  SlotsView _view = SlotsView.schedule;

  ViewState _state = ViewState.idle;
  String? _error;
  List<CourtSlot> _slots = const [];

  // Day availability.
  late DateTime _selectedDate;
  List<AvailableSlot> _dayAvailability = const [];
  ViewState _dayState = ViewState.idle;
  String? _dayError;

  // Week grid — seven day-reads, keyed by DateTime.weekday (1–7).
  late DateTime _weekStart;
  Map<int, List<AvailableSlot>> _week = const {};
  ViewState _weekState = ViewState.idle;
  String? _weekError;

  /// Ids with a toggle in flight, so the row can disable just that switch.
  final Set<int> _busyRows = <int>{};

  bool _disposed = false;

  // --- Reads -----------------------------------------------------------------

  SlotsView get view => _view;

  ViewState get state => _state;
  String? get error => _error;
  List<CourtSlot> get slots => _slots;

  SlotsSummary get summary => SlotsSummary.from(_slots);

  bool get isFirstLoad => _state.isLoading && _slots.isEmpty;
  bool get isRefreshing => _state.isLoading && _slots.isNotEmpty;

  DateTime get selectedDate => _selectedDate;
  List<AvailableSlot> get dayAvailability => _dayAvailability;
  ViewState get dayState => _dayState;
  String? get dayError => _dayError;

  DateTime get weekStart => _weekStart;
  Map<int, List<AvailableSlot>> get week => _week;
  ViewState get weekState => _weekState;
  String? get weekError => _weekError;

  bool isRowBusy(int id) => _busyRows.contains(id);

  /// Slots in clock order, with unreadable times last so they are never
  /// silently dropped from the schedule.
  List<CourtSlot> get orderedSlots {
    final ordered = [..._slots];
    ordered.sort((a, b) {
      final first = a.startTime;
      final second = b.startTime;
      if (first == null && second == null) return 0;
      if (first == null) return 1;
      if (second == null) return -1;
      return first.compareTo(second);
    });
    return ordered;
  }

  /// The hours the week grid needs rows for: every hour any slot touches, or a
  /// sensible working day when nothing is scheduled yet.
  List<int> get gridHours {
    final hours = <int>{};

    for (final slot in _slots) {
      final start = slot.startTime;
      if (start != null) hours.add(start.hour);
    }
    for (final entry in _week.values) {
      for (final slot in entry) {
        final start = slot.startTime;
        if (start != null) hours.add(start.hour);
      }
    }

    if (hours.isEmpty) {
      // 6am–10pm: a placeholder grid is more useful than an empty one, and it
      // is visibly a default rather than data.
      return [for (var hour = 6; hour <= 22; hour++) hour];
    }

    final sorted = hours.toList()..sort();
    return sorted;
  }

  /// How a given weekday and hour reads in the week grid.
  SlotAvailability availabilityAt(int weekday, int hour) {
    final slots = _week[weekday];
    if (slots == null || slots.isEmpty) return SlotAvailability.unknown;

    for (final slot in slots) {
      if (slot.startTime?.hour == hour) return slot.availability;
    }
    return SlotAvailability.unknown;
  }

  /// The date the grid's [weekday] column stands for.
  DateTime dateForWeekday(int weekday) =>
      _weekStart.add(Duration(days: weekday - 1));

  // --- Loading ---------------------------------------------------------------

  Future<void> load() async {
    AdminLog.state('Slots loading for court ${court.id}');
    _state = ViewState.loading;
    _error = null;
    _safeNotify();

    try {
      final result = await _repository.fetchSlots(court.id);
      if (_disposed) return;
      _slots = result;
      _state = ViewState.ready;
      AdminLog.state('Slots ready → ${result.length}');
    } on ApiException catch (error) {
      if (_disposed) return;
      _state = ViewState.failed;
      _error = error.message;
      AdminLog.failure('Slots load failed: ${error.message}', error: error);
    } catch (error, stackTrace) {
      if (_disposed) return;
      _state = ViewState.failed;
      _error = 'Could not load the slots for this court.';
      AdminLog.failure(
        'Slots load crashed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _safeNotify();
    }
  }

  Future<void> refresh() {
    AdminLog.ui('Slots refresh requested');
    return switch (_view) {
      SlotsView.schedule => load(),
      SlotsView.day => loadDay(),
      SlotsView.week => loadWeek(),
    };
  }

  void setView(SlotsView view) {
    if (_view == view) return;
    AdminLog.ui('Slots view → ${view.name}');
    _view = view;
    _safeNotify();

    switch (view) {
      case SlotsView.schedule:
        if (_state.isIdle) load();
      case SlotsView.day:
        if (_dayState.isIdle) loadDay();
      case SlotsView.week:
        if (_weekState.isIdle) loadWeek();
    }
  }

  // --- Day availability ------------------------------------------------------

  void setDate(DateTime date) {
    final normalised = DateTime(date.year, date.month, date.day);
    if (normalised == _selectedDate) return;
    AdminLog.ui('Slot availability date → $normalised');
    _selectedDate = normalised;
    loadDay();
  }

  Future<void> loadDay() async {
    AdminLog.state('Day availability loading for ${court.id} on $_selectedDate');
    _dayState = ViewState.loading;
    _dayError = null;
    _safeNotify();

    final requested = _selectedDate;

    try {
      final result = await _repository.fetchAvailableSlots(
        court.id,
        requested,
      );
      // Dropped if the admin moved the date while this was in flight.
      if (_disposed || requested != _selectedDate) return;
      _dayAvailability = result;
      _dayState = ViewState.ready;
      AdminLog.state('Day availability ready → ${result.length}');
    } on ApiException catch (error) {
      if (_disposed || requested != _selectedDate) return;
      _dayState = ViewState.failed;
      _dayError = error.message;
    } catch (error, stackTrace) {
      if (_disposed || requested != _selectedDate) return;
      _dayState = ViewState.failed;
      _dayError = 'Could not load availability for this date.';
      AdminLog.failure(
        'Day availability crashed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _safeNotify();
    }
  }

  // --- Week grid -------------------------------------------------------------

  /// Monday of the week [date] falls in.
  static DateTime startOfWeek(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  void goToWeek(DateTime anchor) {
    final start = startOfWeek(anchor);
    if (start == _weekStart) return;
    AdminLog.ui('Slot week → $start');
    _weekStart = start;
    loadWeek();
  }

  void previousWeek() => goToWeek(_weekStart.subtract(const Duration(days: 7)));
  void nextWeek() => goToWeek(_weekStart.add(const Duration(days: 7)));
  void thisWeek() => goToWeek(_today());

  /// Seven reads, one per day.
  ///
  /// `/available-slots` answers for a single date, so a week genuinely costs
  /// seven requests. They go out together rather than in series, and a day that
  /// fails leaves its column empty instead of failing the whole grid — a
  /// partial week is more use than none.
  Future<void> loadWeek() async {
    final start = _weekStart;
    AdminLog.state('Week availability loading from $start');

    _weekState = ViewState.loading;
    _weekError = null;
    _safeNotify();

    try {
      final days = List<DateTime>.generate(
        7,
        (index) => start.add(Duration(days: index)),
      );

      final results = await Future.wait(
        days.map((day) async {
          try {
            return await _repository.fetchAvailableSlots(court.id, day);
          } catch (error) {
            AdminLog.failure('Week day $day unavailable', error: error);
            return const <AvailableSlot>[];
          }
        }),
      );

      if (_disposed || start != _weekStart) return;

      _week = <int, List<AvailableSlot>>{
        for (var index = 0; index < results.length; index++)
          index + 1: results[index],
      };

      final loaded = results.where((day) => day.isNotEmpty).length;
      _weekState = ViewState.ready;
      // Said plainly rather than left as a silently sparse grid.
      _weekError = loaded == 0
          ? 'No availability was returned for this week.'
          : null;
      AdminLog.state('Week availability ready → $loaded of 7 days');
    } catch (error, stackTrace) {
      if (_disposed || start != _weekStart) return;
      _weekState = ViewState.failed;
      _weekError = 'Could not load the week.';
      AdminLog.failure(
        'Week availability crashed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _safeNotify();
    }
  }

  // --- Writes ----------------------------------------------------------------

  /// Existing slots a new or edited window would clash with.
  ///
  /// [ignoreId] is the slot being edited, which must not be compared with
  /// itself. Returned rather than thrown so the form can name the offender.
  List<CourtSlot> clashesWith(CourtSlotDraft draft, {int? ignoreId}) {
    final candidate = CourtSlot(
      id: -1,
      courtId: court.id,
      startTimeRaw: draft.startTime?.wire,
      endTimeRaw: draft.endTime?.wire,
      availableDaysRaw: draft.availableDays,
    );

    return _slots
        .where((slot) => slot.id != ignoreId && candidate.overlaps(slot))
        .toList(growable: false);
  }

  Future<CourtSlot> create(CourtSlotDraft draft) async {
    AdminLog.ui('Create slot submitted on court ${court.id}');
    final created = await _repository.createSlot(court.id, draft);
    await load();
    await _refreshAvailabilityViews();
    return created;
  }

  Future<CourtSlot> update(int slotId, CourtSlotDraft draft) async {
    AdminLog.ui('Update slot $slotId submitted');
    final updated = await _repository.updateSlot(court.id, slotId, draft);
    await load();
    await _refreshAvailabilityViews();
    return updated;
  }

  Future<void> delete(int slotId) async {
    AdminLog.ui('Delete slot $slotId confirmed');

    // Optimistic: the row disappears immediately, and is put back if the call
    // fails, so a failed delete never silently loses a row from the table.
    final previous = _slots;
    _slots = _slots.where((slot) => slot.id != slotId).toList();
    _safeNotify();

    try {
      await _repository.deleteSlot(court.id, slotId);
    } catch (error) {
      if (!_disposed) {
        AdminLog.failure('Delete failed — restoring the row', error: error);
        _slots = previous;
        _safeNotify();
      }
      rethrow;
    }

    await load();
    await _refreshAvailabilityViews();
  }

  /// `PATCH /{slotId}/toggle` — block or unblock.
  ///
  /// The row flips first so the switch responds instantly. The route flips
  /// whatever the slot currently is, so the optimistic value is the opposite of
  /// what is on screen; if the response names a status, that wins over the
  /// guess.
  Future<void> toggle(int slotId) async {
    final current = _slotFor(slotId);
    if (current == null) return;

    final assumed = current.isBookable
        ? AdminUserStatus.inactive
        : AdminUserStatus.active;

    AdminLog.ui('Toggle slot $slotId → ${assumed.slug} (assumed)');
    _busyRows.add(slotId);
    _replaceSlot(slotId, current.copyWith(statusRaw: assumed.slug));
    _safeNotify();

    try {
      final settled = await _repository.toggleSlot(court.id, slotId);
      if (_disposed) return;
      if (settled != null && settled != assumed) {
        // The server disagreed with the guess; it is the authority.
        AdminLog.state('Toggle settled on ${settled.slug}, not ${assumed.slug}');
        _replaceSlot(slotId, current.copyWith(statusRaw: settled.slug));
      }
    } catch (error) {
      if (!_disposed) {
        AdminLog.failure('Toggle rejected — reverting', error: error);
        _replaceSlot(slotId, current);
      }
      rethrow;
    } finally {
      _busyRows.remove(slotId);
      _safeNotify();
    }

    await _refreshAvailabilityViews();
  }

  /// A schedule change makes any loaded availability stale, so whichever of the
  /// two has been opened is re-read. Neither is fetched speculatively.
  Future<void> _refreshAvailabilityViews() async {
    final tasks = <Future<void>>[
      if (!_dayState.isIdle) loadDay(),
      if (!_weekState.isIdle) loadWeek(),
    ];
    if (tasks.isNotEmpty) await Future.wait(tasks);
  }

  CourtSlot? _slotFor(int id) {
    for (final slot in _slots) {
      if (slot.id == id) return slot;
    }
    return null;
  }

  void _replaceSlot(int id, CourtSlot next) {
    _slots = _slots
        .map((slot) => slot.id == id ? next : slot)
        .toList(growable: false);
  }

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    AdminLog.life('CourtSlotsController disposed');
    super.dispose();
  }
}
