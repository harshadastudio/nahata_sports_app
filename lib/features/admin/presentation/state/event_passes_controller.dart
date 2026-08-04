import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../models/sports_complex_model.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/admin_role.dart';
import '../../domain/entities/event_pass.dart';
import '../../domain/entities/paged.dart';
import '../../domain/repositories/event_pass_repository.dart';
import 'view_state.dart';

/// The two things this module lists.
enum EventsView {
  events('Events', 'Events'),
  bookings('Event bookings', 'Bookings');

  const EventsView(this.label, this.shortLabel);

  final String label;
  final String shortLabel;
}

/// The columns the events table can be ordered by.
enum EventSort {
  title('Event'),
  complex('Sports complex'),
  starts('Starts'),
  slots('Slots'),
  capacity('Capacity'),
  status('Status');

  const EventSort(this.label);

  final String label;
}

/// The five summary figures above the events table.
class EventsSummary {
  const EventsSummary({
    this.total = 0,
    this.active = 0,
    this.upcoming = 0,
    this.slots = 0,
    this.capacity,
  });

  final int total;
  final int active;

  /// Events with at least one slot still to run.
  final int upcoming;

  final int slots;

  /// Null when not one slot declared a capacity.
  final int? capacity;

  static EventsSummary from(
    List<AdminEventPass> events, {
    DateTime? now,
    int? total,
  }) {
    final moment = now ?? DateTime.now();

    var active = 0;
    var upcoming = 0;
    var slots = 0;
    var capacity = 0;
    var capacityKnown = false;

    for (final event in events) {
      if (event.isActive) active++;
      if (event.upcomingSlotCount(moment) > 0) upcoming++;
      slots += event.slotCount;

      final seats = event.totalCapacity;
      if (seats != null) {
        capacityKnown = true;
        capacity += seats;
      }
    }

    return EventsSummary(
      total: total ?? events.length,
      active: active,
      upcoming: upcoming,
      slots: slots,
      capacity: capacityKnown ? capacity : null,
    );
  }
}

/// Everything the Event Passes page needs.
///
/// `GET /event-passes` is paginated, and the route documents no filters at all
/// — so search, status and venue are applied over the rows and, like the
/// Batches and Bookings modules, using any of them loads the whole catalogue
/// first. Filtering one page at a time would make "no matches on page one"
/// indistinguishable from "no matches".
class EventPassesController extends ChangeNotifier {
  EventPassesController(this._repository) {
    AdminLog.life('EventPassesController created');
  }

  final EventPassRepository _repository;

  static const Duration searchDebounce = Duration(milliseconds: 300);
  static const List<int> pageSizes = [10, 20, 50, 100];
  static const int cataloguePageSize = 100;
  static const int catalogueMaxPages = 20;

  EventsView _view = EventsView.events;

  ViewState _state = ViewState.idle;
  String? _error;
  List<AdminEventPass> _rows = const [];

  int _serverPage = 1;
  int _serverTotalPages = 1;
  int _serverTotalItems = 0;
  bool _catalogueMode = false;

  String _search = '';
  String _appliedSearch = '';
  AdminUserStatus? _statusFilter;
  int? _complexFilter;
  bool _upcomingOnly = false;

  EventSort? _sort;
  bool _descending = false;

  int _page = 1;
  int _limit = 20;

  Timer? _debounce;
  int _requestId = 0;
  bool _disposed = false;

  // Detail drawer.
  AdminEventPass? _selected;
  ViewState _detailState = ViewState.idle;
  String? _detailError;

  // Bookings.
  List<EventPassBookingRow> _bookings = const [];
  ViewState _bookingsState = ViewState.idle;
  String? _bookingsError;
  int _bookingsPage = 1;
  int _bookingsTotalPages = 1;
  int _bookingsTotalItems = 0;
  String _bookingSearch = '';

  // Venue catalogue.
  List<SportsComplex> _complexes = const [];
  ViewState _complexesState = ViewState.idle;

  final Set<int> _busyRows = <int>{};

  // --- Reads -----------------------------------------------------------------

  EventsView get view => _view;
  ViewState get state => _state;
  String? get error => _error;
  List<AdminEventPass> get rows => _rows;

  bool get isCatalogueMode => _catalogueMode;

  EventsSummary get summary => EventsSummary.from(
    _catalogueMode ? visibleRows : _rows,
    total: _catalogueMode ? visibleRows.length : _serverTotalItems,
  );

  bool get summaryIsPageScoped => !_catalogueMode && _serverTotalPages > 1;

  String get search => _search;
  AdminUserStatus? get statusFilter => _statusFilter;
  int? get complexFilter => _complexFilter;
  bool get upcomingOnly => _upcomingOnly;

  EventSort? get sort => _sort;
  bool get descending => _descending;
  int get limit => _limit;

  AdminEventPass? get selected => _selected;
  ViewState get detailState => _detailState;
  String? get detailError => _detailError;

  List<EventPassBookingRow> get bookings => _bookings;
  ViewState get bookingsState => _bookingsState;
  String? get bookingsError => _bookingsError;
  String get bookingSearch => _bookingSearch;

  List<SportsComplex> get complexes => _complexes;
  ViewState get complexesState => _complexesState;

  bool isRowBusy(int id) => _busyRows.contains(id);

  SportsComplex? get filteredComplex => complexById(_complexFilter);

  SportsComplex? complexById(int? id) {
    if (id == null) return null;
    for (final complex in _complexes) {
      if (complex.id == id) return complex;
    }
    return null;
  }

  bool get hasFilters =>
      _appliedSearch.trim().isNotEmpty ||
      _statusFilter != null ||
      _complexFilter != null ||
      _upcomingOnly;

  int get activeFilterCount =>
      [_statusFilter, _complexFilter].where((f) => f != null).length +
      (_upcomingOnly ? 1 : 0);

  bool get isFirstLoad => _state.isLoading && _rows.isEmpty;
  bool get isRefreshing => _state.isLoading && _rows.isNotEmpty;

  bool get _needsCatalogue => hasFilters || _sort != null;

  /// Every event that survives the filters, in the requested order.
  List<AdminEventPass> get visibleRows {
    if (!_catalogueMode) return _rows;

    final query = _appliedSearch.trim();
    final now = DateTime.now();

    final filtered = _rows.where((event) {
      if (!event.matches(query)) return false;
      if (_statusFilter != null && event.status != _statusFilter) return false;
      if (_complexFilter != null && event.sportComplexId != _complexFilter) {
        return false;
      }
      if (_upcomingOnly && event.upcomingSlotCount(now) == 0) return false;
      return true;
    }).toList();

    _sortRows(filtered);
    return filtered;
  }

  void _sortRows(List<AdminEventPass> rows) {
    final by = _sort;
    if (by == null) return;

    int compare(AdminEventPass a, AdminEventPass b) {
      switch (by) {
        case EventSort.title:
          return a.displayTitle.toLowerCase().compareTo(
            b.displayTitle.toLowerCase(),
          );
        case EventSort.complex:
          return (a.sportComplexName ?? '').toLowerCase().compareTo(
            (b.sportComplexName ?? '').toLowerCase(),
          );
        case EventSort.starts:
          return a.firstDate!.compareTo(b.firstDate!);
        case EventSort.slots:
          return a.slotCount.compareTo(b.slotCount);
        case EventSort.capacity:
          return (a.totalCapacity ?? 0).compareTo(b.totalCapacity ?? 0);
        case EventSort.status:
          return a.statusLabel.compareTo(b.statusLabel);
      }
    }

    rows.sort((a, b) {
      // Rows with nothing to sort by sink in BOTH directions — reversing the
      // comparison would otherwise float every blank to the top. This also
      // keeps the date branch above from dereferencing a null.
      final missingA = _isMissing(by, a);
      final missingB = _isMissing(by, b);
      if (missingA && missingB) return 0;
      if (missingA != missingB) return missingA ? 1 : -1;

      return _descending ? compare(b, a) : compare(a, b);
    });
  }

  static bool _isMissing(EventSort by, AdminEventPass event) {
    switch (by) {
      case EventSort.complex:
        return (event.sportComplexName ?? '').trim().isEmpty;
      case EventSort.starts:
        return event.firstDate == null;
      case EventSort.capacity:
        return event.totalCapacity == null;
      case EventSort.title:
      case EventSort.slots:
      case EventSort.status:
        return false;
    }
  }

  List<AdminEventPass> get pageRows {
    if (!_catalogueMode) return _rows;

    final rows = visibleRows;
    if (rows.isEmpty) return const [];

    final start = (_page - 1) * _limit;
    if (start >= rows.length) return const [];
    final end = (start + _limit).clamp(0, rows.length);
    return rows.sublist(start, end);
  }

  Paged<AdminEventPass> get page {
    if (!_catalogueMode) {
      return Paged<AdminEventPass>(
        items: _rows,
        page: _serverPage,
        limit: _limit,
        total: _serverTotalItems,
        totalPages: _serverTotalPages,
      );
    }

    final total = visibleRows.length;
    return Paged<AdminEventPass>(
      items: pageRows,
      page: _page,
      limit: _limit,
      total: total,
      totalPages: total == 0 ? 0 : (total / _limit).ceil(),
    );
  }

  /// The bookings that survive the booking search, in newest-first order.
  List<EventPassBookingRow> get visibleBookings {
    final query = _bookingSearch.trim();
    final rows = _bookings
        .where((booking) => booking.matches(query))
        .toList();

    rows.sort((a, b) {
      final first = a.createdAt;
      final second = b.createdAt;
      if (first == null && second == null) return b.id.compareTo(a.id);
      if (first == null) return 1;
      if (second == null) return -1;
      return second.compareTo(first);
    });
    return rows;
  }

  Paged<EventPassBookingRow> get bookingsPage => Paged<EventPassBookingRow>(
    items: visibleBookings,
    page: _bookingsPage,
    limit: _limit,
    total: _bookingsTotalItems,
    totalPages: _bookingsTotalPages,
  );

  // --- Loading ---------------------------------------------------------------

  Future<void> load() async {
    final id = ++_requestId;
    final catalogue = _needsCatalogue;

    AdminLog.state(
      'Events loading (${catalogue ? 'catalogue' : 'page $_page'}) → '
      'status=${_statusFilter?.slug ?? '-'} complex=${_complexFilter ?? '-'} '
      'upcoming=$_upcomingOnly search="${_appliedSearch.trim()}"',
    );

    _state = ViewState.loading;
    _error = null;
    _safeNotify();

    try {
      if (catalogue) {
        final all = <AdminEventPass>[];
        var page = 1;

        while (page <= catalogueMaxPages) {
          final result = await _repository.fetchEventPasses(
            page: page,
            limit: cataloguePageSize,
          );
          all.addAll(result.items);
          if (!result.hasMore || result.items.isEmpty) break;
          page++;
        }

        if (_disposed || id != _requestId) return;

        _catalogueMode = true;
        _rows = all;
        _serverTotalItems = all.length;
        _serverTotalPages = 1;
        _state = ViewState.ready;
        _clampPage();
        AdminLog.state('Event catalogue ready → ${all.length}');
      } else {
        final result = await _repository.fetchEventPasses(
          page: _page,
          limit: _limit,
        );

        if (_disposed || id != _requestId) return;

        _catalogueMode = false;
        _rows = result.items;
        _serverPage = result.page;
        _serverTotalPages = result.totalPages;
        _serverTotalItems = result.totalItems;
        _page = result.page;
        _state = ViewState.ready;
        AdminLog.state(
          'Events ready → ${result.items.length} '
          '(page ${result.page}/${result.totalPages})',
        );
      }
    } on ApiException catch (error) {
      if (_disposed || id != _requestId) return;
      _state = ViewState.failed;
      _error = error.message;
      AdminLog.failure('Events load failed: ${error.message}', error: error);
    } catch (error, stackTrace) {
      if (_disposed || id != _requestId) return;
      _state = ViewState.failed;
      _error = 'Could not load the events. Please try again.';
      AdminLog.failure(
        'Events load crashed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _safeNotify();
    }
  }

  Future<void> refresh() {
    AdminLog.ui('Events refresh requested');
    return switch (_view) {
      EventsView.events => load(),
      EventsView.bookings => loadBookings(),
    };
  }

  void setView(EventsView view) {
    if (_view == view) return;
    AdminLog.ui('Events view → ${view.name}');
    _view = view;
    _safeNotify();

    switch (view) {
      case EventsView.events:
        if (_state.isIdle) load();
      case EventsView.bookings:
        if (_bookingsState.isIdle) loadBookings();
    }
  }

  Future<void> loadBookings({int? page}) async {
    final requested = page ?? _bookingsPage;

    _bookingsState = ViewState.loading;
    _bookingsError = null;
    _safeNotify();

    try {
      final result = await _repository.fetchBookings(
        page: requested,
        limit: _limit,
      );
      if (_disposed) return;
      _bookings = result.items;
      _bookingsPage = result.page;
      _bookingsTotalPages = result.totalPages;
      _bookingsTotalItems = result.totalItems;
      _bookingsState = ViewState.ready;
      AdminLog.state('Event bookings ready → ${result.items.length}');
    } on ApiException catch (error) {
      if (_disposed) return;
      _bookingsState = ViewState.failed;
      _bookingsError = error.message;
    } catch (error, stackTrace) {
      if (_disposed) return;
      _bookingsState = ViewState.failed;
      _bookingsError = 'Could not load the event bookings.';
      AdminLog.failure(
        'Event bookings crashed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _safeNotify();
    }
  }

  void goToBookingsPage(int target) {
    final total = _bookingsTotalPages;
    final next = total > 0 ? target.clamp(1, total) : 1;
    if (next == _bookingsPage) return;
    _bookingsPage = next;
    loadBookings(page: next);
  }

  void onBookingSearchChanged(String value) {
    if (_bookingSearch == value) return;
    _bookingSearch = value;
    _safeNotify();
  }

  Future<void> loadComplexes({bool refresh = false}) async {
    if (_complexesState.isLoading) return;
    if (_complexes.isNotEmpty && !refresh) return;

    _complexesState = ViewState.loading;
    _safeNotify();

    try {
      final result = await _repository.fetchSportComplexes(refresh: refresh);
      if (_disposed) return;
      _complexes = result;
      _complexesState = ViewState.ready;
    } catch (error, stackTrace) {
      if (_disposed) return;
      _complexesState = ViewState.failed;
      AdminLog.failure(
        'Event venue list failed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _safeNotify();
    }
  }

  // --- Search, filters, paging ----------------------------------------------

  void onSearchChanged(String value) {
    if (_search == value) return;
    _search = value;
    notifyListeners();

    _debounce?.cancel();
    _debounce = Timer(searchDebounce, () {
      if (_disposed) return;
      final previous = _needsCatalogue;
      _appliedSearch = _search;
      _page = 1;
      _reloadIfModeChanged(previouslyCatalogue: previous);
    });
  }

  void clearSearch() {
    if (_search.isEmpty && _appliedSearch.isEmpty) return;
    _debounce?.cancel();
    final previous = _needsCatalogue;
    _search = '';
    _appliedSearch = '';
    _page = 1;
    _reloadIfModeChanged(previouslyCatalogue: previous);
  }

  void setStatusFilter(AdminUserStatus? status) =>
      _setFilter(() => _statusFilter = status, _statusFilter == status);

  void setComplexFilter(int? complexId) =>
      _setFilter(() => _complexFilter = complexId, _complexFilter == complexId);

  void setUpcomingOnly(bool value) =>
      _setFilter(() => _upcomingOnly = value, _upcomingOnly == value);

  void _setFilter(VoidCallback apply, bool unchanged) {
    if (unchanged) return;
    final previous = _needsCatalogue;
    apply();
    _page = 1;
    _reloadIfModeChanged(previouslyCatalogue: previous);
  }

  void clearFilters() {
    if (!hasFilters) return;
    AdminLog.ui('All event filters cleared');
    _debounce?.cancel();

    final previous = _needsCatalogue;
    _search = '';
    _appliedSearch = '';
    _statusFilter = null;
    _complexFilter = null;
    _upcomingOnly = false;
    _page = 1;

    _reloadIfModeChanged(previouslyCatalogue: previous);
  }

  /// Reloads only when the mode actually changed — filtering inside a catalogue
  /// already in memory costs nothing.
  void _reloadIfModeChanged({required bool previouslyCatalogue}) {
    final needs = _needsCatalogue;
    if (needs == previouslyCatalogue && needs == _catalogueMode) {
      _clampPage();
      _safeNotify();
      return;
    }
    load();
  }

  void setLimit(int limit) {
    if (_limit == limit) return;
    _limit = limit;
    _page = 1;
    if (_catalogueMode) {
      _safeNotify();
    } else {
      load();
    }
  }

  void toggleSort(EventSort column) {
    final previous = _needsCatalogue;

    if (_sort != column) {
      _sort = column;
      _descending = false;
    } else if (!_descending) {
      _descending = true;
    } else {
      _sort = null;
      _descending = false;
    }

    _page = 1;
    _reloadIfModeChanged(previouslyCatalogue: previous);
  }

  void goToPage(int target) {
    final total = page.effectiveTotalPages;
    final next = total > 0 ? target.clamp(1, total) : 1;
    if (next == _page) return;
    _page = next;
    if (_catalogueMode) {
      _safeNotify();
    } else {
      load();
    }
  }

  void _clampPage() {
    final total = page.effectiveTotalPages;
    if (total > 0 && _page > total) _page = total;
    if (_page < 1) _page = 1;
  }

  // --- Detail ----------------------------------------------------------------

  /// Shows the row already in hand, then fills in from `GET /event-passes/{id}`
  /// — which is where the slots and FAQs usually arrive in full.
  Future<void> openEvent(AdminEventPass event) async {
    AdminLog.ui('Event detail opened for ${event.id}');
    _selected = event;
    _detailState = ViewState.loading;
    _detailError = null;
    _safeNotify();

    try {
      final detail = await _repository.fetchEventPass(event.id);
      if (_disposed || _selected?.id != event.id) return;
      _selected = event.mergedWith(detail);
      _detailState = ViewState.ready;
    } on ApiException catch (error) {
      if (_disposed || _selected?.id != event.id) return;
      _detailState = ViewState.failed;
      _detailError = error.message;
    } catch (error, stackTrace) {
      if (_disposed || _selected?.id != event.id) return;
      _detailState = ViewState.failed;
      _detailError = 'Could not load this event.';
      AdminLog.failure(
        'Event detail crashed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _safeNotify();
    }
  }

  void closeEvent() {
    if (_selected == null) return;
    _selected = null;
    _detailState = ViewState.idle;
    _detailError = null;
    _safeNotify();
  }

  // --- Writes ----------------------------------------------------------------

  Future<AdminEventPass> create(EventPassDraft draft) async {
    AdminLog.ui('Create event submitted');
    final created = await _repository.createEventPass(draft);
    _page = 1;
    await load();
    return created;
  }

  Future<AdminEventPass> update(int id, EventPassDraft draft) async {
    AdminLog.ui('Update event $id submitted');
    final updated = await _repository.updateEventPass(id, draft);

    if (_selected?.id == id) {
      _selected = _selected!.mergedWith(updated);
      _safeNotify();
    }

    await load();
    return updated;
  }

  Future<void> delete(int id) async {
    AdminLog.ui('Delete event $id confirmed');

    // Optimistic: the row disappears immediately, and is put back if the call
    // fails, so a failed delete never silently loses a row from the table.
    final previous = _rows;
    _rows = _rows.where((event) => event.id != id).toList();
    if (_selected?.id == id) closeEvent();
    _clampPage();
    _safeNotify();

    try {
      await _repository.deleteEventPass(id);
    } catch (error) {
      if (!_disposed) {
        AdminLog.failure('Delete failed — restoring the row', error: error);
        _rows = previous;
        _safeNotify();
      }
      rethrow;
    }

    await load();
  }

  /// There is no status route, so this is a `PUT` of that one field —
  /// optimistic, reverted if the server refuses.
  Future<void> setStatus(int id, AdminUserStatus status) async {
    final current = _rowFor(id);
    if (current == null || current.status == status) return;

    _busyRows.add(id);
    _replaceRow(id, current.copyWith(statusRaw: status.slug));
    _safeNotify();

    try {
      await _repository.updateEventPass(id, EventPassDraft(status: status));
    } catch (error) {
      if (!_disposed) {
        AdminLog.failure('Status change rejected — reverting', error: error);
        _replaceRow(id, current);
      }
      rethrow;
    } finally {
      _busyRows.remove(id);
      _safeNotify();
    }
  }

  /// `POST /event-passes/bookings/create` — books on a customer's behalf.
  Future<EventPassBookingRow> createBooking(EventBookingDraft draft) async {
    AdminLog.ui('Create event booking submitted');
    final created = await _repository.createBooking(draft);
    if (!_bookingsState.isIdle) await loadBookings();
    return created;
  }

  Future<String> uploadImage(String filePath, {String? filename}) {
    AdminLog.ui('Event image upload started');
    return _repository.uploadImage(filePath, filename: filename);
  }

  AdminEventPass? _rowFor(int id) {
    for (final event in _rows) {
      if (event.id == id) return event;
    }
    return _selected?.id == id ? _selected : null;
  }

  void _replaceRow(int id, AdminEventPass next) {
    _rows = _rows
        .map((event) => event.id == id ? next : event)
        .toList(growable: false);
    if (_selected?.id == id) _selected = next;
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    AdminLog.life('EventPassesController disposed');
    super.dispose();
  }
}
