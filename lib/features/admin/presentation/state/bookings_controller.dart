import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../models/sports_complex_model.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/booking.dart';
import '../../domain/entities/court.dart';
import '../../domain/entities/paged.dart';
import '../../domain/entities/sport.dart';
import '../../domain/repositories/booking_repository.dart';
import 'view_state.dart';

/// The four ways the module presents its data.
enum BookingsView {
  list('All bookings', 'List'),
  today("Today's board", 'Today'),
  calendar('Calendar', 'Calendar'),
  stats('Statistics', 'Stats');

  const BookingsView(this.label, this.shortLabel);

  final String label;
  final String shortLabel;
}

/// The columns the bookings table can be ordered by.
enum BookingSort {
  reference('Booking ID'),
  customer('Customer'),
  sport('Sport'),
  court('Court'),
  complex('Sports complex'),
  date('Booking date'),
  amount('Amount'),
  payment('Payment status'),
  status('Booking status'),
  created('Created');

  const BookingSort(this.label);

  final String label;
}

/// Counters derived from the rows in hand, for when `/bookings/stats` has not
/// answered — or has answered without a figure the card needs.
class BookingsSummary {
  const BookingsSummary({
    this.total = 0,
    this.confirmed = 0,
    this.pending = 0,
    this.cancelled = 0,
    this.completed = 0,
    this.paid = 0,
    this.unpaid = 0,
    this.revenue,
  });

  final int total;
  final int confirmed;
  final int pending;
  final int cancelled;
  final int completed;
  final int paid;
  final int unpaid;

  /// Null when not one row carried an amount — a zero would claim the day took
  /// nothing when the API simply did not say.
  final num? revenue;

  static BookingsSummary from(List<Booking> bookings) {
    var confirmed = 0;
    var pending = 0;
    var cancelled = 0;
    var completed = 0;
    var paid = 0;
    var unpaid = 0;

    num revenue = 0;
    var revenueKnown = false;

    for (final booking in bookings) {
      switch (booking.status) {
        case BookingStatus.confirmed:
          confirmed++;
        case BookingStatus.pending:
          pending++;
        case BookingStatus.cancelled:
          cancelled++;
        case BookingStatus.completed:
          completed++;
        case null:
          break;
      }

      if (booking.payment == PaymentStatus.paid) {
        paid++;
      } else if (booking.payment != null) {
        unpaid++;
      }

      final amount = booking.amount;
      // Cancelled bookings are excluded: counting refunded money as revenue
      // would overstate the take.
      if (amount != null && !booking.isCancelled) {
        revenueKnown = true;
        revenue += amount;
      }
    }

    return BookingsSummary(
      total: bookings.length,
      confirmed: confirmed,
      pending: pending,
      cancelled: cancelled,
      completed: completed,
      paid: paid,
      unpaid: unpaid,
      revenue: revenueKnown ? revenue : null,
    );
  }
}

/// Everything the Bookings page needs.
///
/// `GET /bookings` documents no filter parameters, so this controller sends the
/// ones it has *and* re-applies every one of them locally — the table is then
/// right whether or not the backend honours them. Because the route is paged,
/// any filter, search or sort switches it into **catalogue mode** (all pages
/// loaded once, up to a cap) exactly like the Batches module: filtering one
/// page at a time would make "no matches on page one" indistinguishable from
/// "no matches".
class BookingsController extends ChangeNotifier {
  BookingsController(this._repository) {
    AdminLog.life('BookingsController created');
    final now = DateTime.now();
    _calendarMonth = DateTime(now.year, now.month);
  }

  final BookingRepository _repository;

  static const Duration searchDebounce = Duration(milliseconds: 300);
  static const List<int> pageSizes = [10, 20, 50, 100];
  static const int cataloguePageSize = 100;
  static const int catalogueMaxPages = 20;

  BookingsView _view = BookingsView.list;

  ViewState _state = ViewState.idle;
  String? _error;
  List<Booking> _rows = const [];

  int _serverPage = 1;
  int _serverTotalPages = 1;
  int _serverTotalItems = 0;

  bool _catalogueMode = false;
  int? _cappedAt;
  int? _cappedTotal;

  String _search = '';
  String _appliedSearch = '';

  BookingStatus? _statusFilter;
  PaymentStatus? _paymentFilter;
  BookingSource? _sourceFilter;
  int? _sportFilter;
  int? _courtFilter;
  int? _complexFilter;
  DateTime? _dateFilter;

  BookingSort? _sort;
  bool _descending = false;

  int _page = 1;
  int _limit = 20;

  Timer? _debounce;
  int _requestId = 0;
  bool _disposed = false;

  // Detail drawer.
  Booking? _selected;
  ViewState _detailState = ViewState.idle;
  String? _detailError;

  // Stats.
  BookingStats? _stats;
  ViewState _statsState = ViewState.idle;
  String? _statsError;

  // Today's board.
  List<Booking> _current = const [];
  ViewState _currentState = ViewState.idle;
  String? _currentError;

  // Calendar.
  late DateTime _calendarMonth;
  DateTime? _calendarSelectedDay;

  // Dropdown catalogues.
  List<Court> _courts = const [];
  ViewState _courtsState = ViewState.idle;
  List<Sport> _sports = const [];
  ViewState _sportsState = ViewState.idle;
  List<SportsComplex> _complexes = const [];
  ViewState _complexesState = ViewState.idle;

  final Set<int> _busyRows = <int>{};

  // --- Reads -----------------------------------------------------------------

  BookingsView get view => _view;
  ViewState get state => _state;
  String? get error => _error;
  List<Booking> get rows => _rows;

  bool get isCatalogueMode => _catalogueMode;

  (int, int)? get catalogueCapped {
    final loaded = _cappedAt;
    final total = _cappedTotal;
    if (loaded == null || total == null) return null;
    return (loaded, total);
  }

  /// Counted from the rows in hand. The dashboard cards prefer
  /// `/bookings/stats` and fall back to this when a figure is missing.
  BookingsSummary get summary =>
      BookingsSummary.from(_catalogueMode ? visibleRows : _rows);

  bool get summaryIsPageScoped => !_catalogueMode && _serverTotalPages > 1;

  String get search => _search;
  BookingStatus? get statusFilter => _statusFilter;
  PaymentStatus? get paymentFilter => _paymentFilter;
  BookingSource? get sourceFilter => _sourceFilter;
  int? get sportFilter => _sportFilter;
  int? get courtFilter => _courtFilter;
  int? get complexFilter => _complexFilter;
  DateTime? get dateFilter => _dateFilter;

  BookingSort? get sort => _sort;
  bool get descending => _descending;
  int get limit => _limit;

  Booking? get selected => _selected;
  ViewState get detailState => _detailState;
  String? get detailError => _detailError;

  BookingStats? get stats => _stats;
  ViewState get statsState => _statsState;
  String? get statsError => _statsError;

  List<Booking> get current => _current;
  ViewState get currentState => _currentState;
  String? get currentError => _currentError;

  DateTime get calendarMonth => _calendarMonth;
  DateTime? get calendarSelectedDay => _calendarSelectedDay;

  List<Court> get courts => _courts;
  ViewState get courtsState => _courtsState;
  List<Sport> get sports => _sports;
  ViewState get sportsState => _sportsState;
  List<SportsComplex> get complexes => _complexes;
  ViewState get complexesState => _complexesState;

  bool isRowBusy(int id) => _busyRows.contains(id);

  Sport? sportById(int? id) {
    if (id == null) return null;
    for (final sport in _sports) {
      if (sport.id == id) return sport;
    }
    return null;
  }

  Court? courtById(int? id) {
    if (id == null) return null;
    for (final court in _courts) {
      if (court.id == id) return court;
    }
    return null;
  }

  SportsComplex? complexById(int? id) {
    if (id == null) return null;
    for (final complex in _complexes) {
      if (complex.id == id) return complex;
    }
    return null;
  }

  Sport? get filteredSport => sportById(_sportFilter);
  Court? get filteredCourt => courtById(_courtFilter);
  SportsComplex? get filteredComplex => complexById(_complexFilter);

  bool get hasFilters =>
      _appliedSearch.trim().isNotEmpty ||
      _statusFilter != null ||
      _paymentFilter != null ||
      _sourceFilter != null ||
      _sportFilter != null ||
      _courtFilter != null ||
      _complexFilter != null ||
      _dateFilter != null;

  int get activeFilterCount => [
    _statusFilter,
    _paymentFilter,
    _sourceFilter,
    _sportFilter,
    _courtFilter,
    _complexFilter,
    _dateFilter,
  ].where((filter) => filter != null).length;

  bool get isFirstLoad => _state.isLoading && _rows.isEmpty;
  bool get isRefreshing => _state.isLoading && _rows.isNotEmpty;

  /// True when what is being asked for cannot be trusted to one page.
  bool get _needsCatalogue => hasFilters || _sort != null;

  /// Every row that survives the filters, in the requested order.
  ///
  /// Every filter is re-applied here even though the request also carried it:
  /// the route documents none of them, so the local pass is what makes the
  /// table correct.
  List<Booking> get visibleRows {
    if (!_catalogueMode) return _rows;

    final query = _appliedSearch.trim();

    final filtered = _rows.where((booking) {
      if (!booking.matches(query)) return false;
      if (_statusFilter != null && booking.status != _statusFilter) return false;
      if (_paymentFilter != null && booking.payment != _paymentFilter) {
        return false;
      }
      if (_sourceFilter != null && booking.source != _sourceFilter) return false;
      if (_sportFilter != null && booking.sportId != _sportFilter) return false;
      if (_courtFilter != null && booking.courtId != _courtFilter) return false;
      if (_complexFilter != null &&
          booking.sportComplexId != _complexFilter) {
        return false;
      }
      if (_dateFilter != null && !booking.isOn(_dateFilter!)) return false;
      return true;
    }).toList();

    _sortRows(filtered);
    return filtered;
  }

  void _sortRows(List<Booking> rows) {
    final by = _sort;
    if (by == null) return;

    int compare(Booking a, Booking b) {
      switch (by) {
        case BookingSort.reference:
          return a.displayReference.toLowerCase().compareTo(
            b.displayReference.toLowerCase(),
          );
        case BookingSort.customer:
          return a.displayCustomer.toLowerCase().compareTo(
            b.displayCustomer.toLowerCase(),
          );
        case BookingSort.sport:
          return (a.sportName ?? '').toLowerCase().compareTo(
            (b.sportName ?? '').toLowerCase(),
          );
        case BookingSort.court:
          return (a.courtName ?? '').toLowerCase().compareTo(
            (b.courtName ?? '').toLowerCase(),
          );
        case BookingSort.complex:
          return (a.sportComplexName ?? '').toLowerCase().compareTo(
            (b.sportComplexName ?? '').toLowerCase(),
          );
        case BookingSort.date:
          final byDate = a.date!.compareTo(b.date!);
          if (byDate != 0) return byDate;
          // Same day: the earlier slot leads, which is how a schedule reads.
          final first = a.startTime?.minutesFromMidnight ?? 0;
          final second = b.startTime?.minutesFromMidnight ?? 0;
          return first.compareTo(second);
        case BookingSort.amount:
          return (a.amount ?? 0).compareTo(b.amount ?? 0);
        case BookingSort.payment:
          return a.paymentLabel.compareTo(b.paymentLabel);
        case BookingSort.status:
          return a.statusLabel.compareTo(b.statusLabel);
        case BookingSort.created:
          return a.createdAt!.compareTo(b.createdAt!);
      }
    }

    rows.sort((a, b) {
      // Rows with nothing to sort by sink in BOTH directions — reversing the
      // comparison would otherwise float every blank to the top. This also
      // keeps the date branches above from dereferencing a null.
      final missingA = _isMissing(by, a);
      final missingB = _isMissing(by, b);
      if (missingA && missingB) return 0;
      if (missingA != missingB) return missingA ? 1 : -1;

      return _descending ? compare(b, a) : compare(a, b);
    });
  }

  static bool _isMissing(BookingSort by, Booking booking) {
    switch (by) {
      case BookingSort.sport:
        return (booking.sportName ?? '').trim().isEmpty;
      case BookingSort.court:
        return (booking.courtName ?? '').trim().isEmpty;
      case BookingSort.complex:
        return (booking.sportComplexName ?? '').trim().isEmpty;
      case BookingSort.date:
        return booking.date == null;
      case BookingSort.amount:
        return booking.amount == null;
      case BookingSort.created:
        return booking.createdAt == null;
      case BookingSort.reference:
      case BookingSort.customer:
      case BookingSort.payment:
      case BookingSort.status:
        return false;
    }
  }

  List<Booking> get pageRows {
    if (!_catalogueMode) return _rows;

    final rows = visibleRows;
    if (rows.isEmpty) return const [];

    final start = (_page - 1) * _limit;
    if (start >= rows.length) return const [];
    final end = (start + _limit).clamp(0, rows.length);
    return rows.sublist(start, end);
  }

  /// Everything an export should write: the filtered set in catalogue mode, and
  /// the page in hand while paging. The export says which.
  List<Booking> get exportRows => _catalogueMode ? visibleRows : _rows;

  Paged<Booking> get page {
    if (!_catalogueMode) {
      return Paged<Booking>(
        items: _rows,
        page: _serverPage,
        limit: _limit,
        total: _serverTotalItems,
        totalPages: _serverTotalPages,
      );
    }

    final total = visibleRows.length;
    return Paged<Booking>(
      items: pageRows,
      page: _page,
      limit: _limit,
      total: total,
      totalPages: total == 0 ? 0 : (total / _limit).ceil(),
    );
  }

  // --- Today's board ---------------------------------------------------------

  /// Today's bookings split into the three groups the spec asks for.
  List<Booking> currentIn(BookingPhase phase, {DateTime? now}) {
    final moment = now ?? DateTime.now();
    final rows = _current.where((booking) => booking.phaseAt(moment) == phase)
        .toList();

    rows.sort((a, b) {
      final first = a.startTime?.minutesFromMidnight ?? 0;
      final second = b.startTime?.minutesFromMidnight ?? 0;
      return first.compareTo(second);
    });
    return rows;
  }

  /// Today's board in clock order — the timeline's own source.
  List<Booking> orderedCurrent() {
    final rows = [..._current];
    rows.sort((a, b) {
      final first = a.startTime;
      final second = b.startTime;
      if (first == null && second == null) return 0;
      if (first == null) return 1;
      if (second == null) return -1;
      return first.compareTo(second);
    });
    return rows;
  }

  // --- Calendar --------------------------------------------------------------

  /// Bookings on a given day, from whichever set is loaded.
  ///
  /// The calendar draws from the rows in hand rather than firing a request per
  /// day; the month header says how many that is, so a partial month is never
  /// mistaken for an empty one.
  List<Booking> bookingsOn(DateTime day) {
    final rows = _catalogueMode ? visibleRows : _rows;
    return rows.where((booking) => booking.isOn(day)).toList();
  }

  void goToMonth(DateTime month) {
    final normalised = DateTime(month.year, month.month);
    if (normalised == _calendarMonth) return;
    AdminLog.ui('Booking calendar → $normalised');
    _calendarMonth = normalised;
    _calendarSelectedDay = null;
    _safeNotify();
  }

  void previousMonth() =>
      goToMonth(DateTime(_calendarMonth.year, _calendarMonth.month - 1));

  void nextMonth() =>
      goToMonth(DateTime(_calendarMonth.year, _calendarMonth.month + 1));

  void selectDay(DateTime? day) {
    final normalised = day == null
        ? null
        : DateTime(day.year, day.month, day.day);
    if (normalised == _calendarSelectedDay) return;
    _calendarSelectedDay = normalised;
    _safeNotify();
  }

  // --- Loading ---------------------------------------------------------------

  Future<void> load() async {
    final id = ++_requestId;
    final catalogue = _needsCatalogue;

    AdminLog.state(
      'Bookings loading (${catalogue ? 'catalogue' : 'page $_page'}) → '
      'status=${_statusFilter?.slug ?? '-'} '
      'payment=${_paymentFilter?.slug ?? '-'} '
      'source=${_sourceFilter?.slug ?? '-'} sport=${_sportFilter ?? '-'} '
      'court=${_courtFilter ?? '-'} complex=${_complexFilter ?? '-'} '
      'date=${_dateFilter ?? '-'} search="${_appliedSearch.trim()}"',
    );

    _state = ViewState.loading;
    _error = null;
    _safeNotify();

    try {
      if (catalogue) {
        _cappedAt = null;
        _cappedTotal = null;

        final all = await _repository.fetchAllBookings(
          status: _statusFilter,
          payment: _paymentFilter,
          source: _sourceFilter,
          sportId: _sportFilter,
          courtId: _courtFilter,
          complexId: _complexFilter,
          date: _dateFilter,
          limit: cataloguePageSize,
          maxPages: catalogueMaxPages,
          onCapped: (loaded, total) {
            _cappedAt = loaded;
            _cappedTotal = total;
          },
        );

        if (_disposed || id != _requestId) return;

        _catalogueMode = true;
        _rows = all;
        _serverTotalItems = all.length;
        _serverTotalPages = 1;
        _state = ViewState.ready;
        _clampPage();
        AdminLog.state('Booking catalogue ready → ${all.length}');
      } else {
        final result = await _repository.fetchBookings(
          page: _page,
          limit: _limit,
        );

        if (_disposed || id != _requestId) return;

        _catalogueMode = false;
        _cappedAt = null;
        _cappedTotal = null;
        _rows = result.bookings;
        _serverPage = result.page;
        _serverTotalPages = result.totalPages;
        _serverTotalItems = result.totalItems;
        _page = result.page;
        _state = ViewState.ready;
        AdminLog.state(
          'Bookings ready → ${result.bookings.length} '
          '(page ${result.page}/${result.totalPages})',
        );
      }
    } on ApiException catch (error) {
      if (_disposed || id != _requestId) return;
      _state = ViewState.failed;
      _error = error.message;
      AdminLog.failure('Bookings load failed: ${error.message}', error: error);
    } catch (error, stackTrace) {
      if (_disposed || id != _requestId) return;
      _state = ViewState.failed;
      _error = 'Could not load bookings. Please try again.';
      AdminLog.failure(
        'Bookings load crashed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _safeNotify();
    }
  }

  Future<void> refresh() {
    AdminLog.ui('Bookings refresh requested');
    return switch (_view) {
      BookingsView.list || BookingsView.calendar => load(),
      BookingsView.today => loadCurrent(),
      BookingsView.stats => loadStats(),
    };
  }

  void setView(BookingsView view) {
    if (_view == view) return;
    AdminLog.ui('Bookings view → ${view.name}');
    _view = view;
    _safeNotify();

    switch (view) {
      case BookingsView.list:
      case BookingsView.calendar:
        if (_state.isIdle) load();
      case BookingsView.today:
        if (_currentState.isIdle) loadCurrent();
      case BookingsView.stats:
        if (_statsState.isIdle) loadStats();
    }
  }

  Future<void> loadStats() async {
    _statsState = ViewState.loading;
    _statsError = null;
    _safeNotify();

    try {
      final result = await _repository.fetchStats();
      if (_disposed) return;
      _stats = result;
      _statsState = ViewState.ready;
      AdminLog.state('Booking stats ready');
    } on ApiException catch (error) {
      if (_disposed) return;
      _statsState = ViewState.failed;
      _statsError = error.message;
    } catch (error, stackTrace) {
      if (_disposed) return;
      _statsState = ViewState.failed;
      _statsError = 'Could not load the booking statistics.';
      AdminLog.failure(
        'Booking stats crashed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _safeNotify();
    }
  }

  Future<void> loadCurrent() async {
    _currentState = ViewState.loading;
    _currentError = null;
    _safeNotify();

    try {
      final result = await _repository.fetchCurrent();
      if (_disposed) return;
      _current = result;
      _currentState = ViewState.ready;
      AdminLog.state("Today's bookings ready → ${result.length}");
    } on ApiException catch (error) {
      if (_disposed) return;
      _currentState = ViewState.failed;
      _currentError = error.message;
    } catch (error, stackTrace) {
      if (_disposed) return;
      _currentState = ViewState.failed;
      _currentError = "Could not load today's bookings.";
      AdminLog.failure(
        'Current bookings crashed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _safeNotify();
    }
  }

  Future<void> loadCourts({bool refresh = false, int? complexId}) async {
    if (_courtsState.isLoading) return;
    if (_courts.isNotEmpty && !refresh) return;

    _courtsState = ViewState.loading;
    _safeNotify();

    try {
      final result = await _repository.fetchCourts(complexId: complexId);
      if (_disposed) return;
      _courts = result;
      _courtsState = ViewState.ready;
    } catch (error, stackTrace) {
      if (_disposed) return;
      _courtsState = ViewState.failed;
      AdminLog.failure(
        'Booking court list failed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _safeNotify();
    }
  }

  Future<void> loadSports({bool refresh = false}) async {
    if (_sportsState.isLoading) return;
    if (_sports.isNotEmpty && !refresh) return;

    _sportsState = ViewState.loading;
    _safeNotify();

    try {
      final result = await _repository.fetchSports(refresh: refresh);
      if (_disposed) return;
      _sports = result;
      _sportsState = ViewState.ready;
    } catch (error, stackTrace) {
      if (_disposed) return;
      _sportsState = ViewState.failed;
      AdminLog.failure(
        'Booking sport list failed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _safeNotify();
    }
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
        'Booking venue list failed',
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
      AdminLog.ui('Booking search settled: "${_search.trim()}"');
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

  void setStatusFilter(BookingStatus? status) =>
      _setFilter(() => _statusFilter = status, _statusFilter == status);

  void setPaymentFilter(PaymentStatus? payment) =>
      _setFilter(() => _paymentFilter = payment, _paymentFilter == payment);

  void setSourceFilter(BookingSource? source) =>
      _setFilter(() => _sourceFilter = source, _sourceFilter == source);

  void setSportFilter(int? sportId) =>
      _setFilter(() => _sportFilter = sportId, _sportFilter == sportId);

  void setCourtFilter(int? courtId) =>
      _setFilter(() => _courtFilter = courtId, _courtFilter == courtId);

  void setComplexFilter(int? complexId) =>
      _setFilter(() => _complexFilter = complexId, _complexFilter == complexId);

  void setDateFilter(DateTime? date) {
    final normalised = date == null
        ? null
        : DateTime(date.year, date.month, date.day);
    _setFilter(() => _dateFilter = normalised, _dateFilter == normalised);
  }

  void _setFilter(VoidCallback apply, bool unchanged) {
    if (unchanged) return;
    final previous = _needsCatalogue;
    apply();
    _page = 1;
    AdminLog.ui('Booking filters → $activeFilterCount active');
    _reloadIfModeChanged(previouslyCatalogue: previous);
  }

  void clearFilters() {
    if (!hasFilters) return;
    AdminLog.ui('All booking filters cleared');
    _debounce?.cancel();

    final previous = _needsCatalogue;
    _search = '';
    _appliedSearch = '';
    _statusFilter = null;
    _paymentFilter = null;
    _sourceFilter = null;
    _sportFilter = null;
    _courtFilter = null;
    _complexFilter = null;
    _dateFilter = null;
    _page = 1;

    _reloadIfModeChanged(previouslyCatalogue: previous);
  }

  /// Reloads only when the mode actually changed — filtering inside a catalogue
  /// already in memory costs nothing, and re-pulling it would be a round trip
  /// for the same rows.
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

  void toggleSort(BookingSort column) {
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

  Future<void> openBooking(Booking booking) async {
    AdminLog.ui('Booking detail opened for ${booking.id}');
    _selected = booking;
    _detailState = ViewState.loading;
    _detailError = null;
    _safeNotify();

    try {
      final detail = await _repository.fetchBooking(booking.id);
      if (_disposed || _selected?.id != booking.id) return;
      _selected = booking.mergedWith(detail);
      _detailState = ViewState.ready;
    } on ApiException catch (error) {
      if (_disposed || _selected?.id != booking.id) return;
      _detailState = ViewState.failed;
      _detailError = error.message;
    } catch (error, stackTrace) {
      if (_disposed || _selected?.id != booking.id) return;
      _detailState = ViewState.failed;
      _detailError = 'Could not load this booking.';
      AdminLog.failure(
        'Booking detail crashed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _safeNotify();
    }
  }

  void closeBooking() {
    if (_selected == null) return;
    _selected = null;
    _detailState = ViewState.idle;
    _detailError = null;
    _safeNotify();
  }

  // --- Writes ----------------------------------------------------------------

  /// Bookings that would collide with [draft] — same court, same day,
  /// overlapping time. Returned rather than thrown so the form can name them.
  ///
  /// Only as complete as the rows in hand: while paging, that is one page. The
  /// form says so, and the backend remains the authority.
  List<Booking> clashesWith(BookingDraft draft, {int? ignoreId}) {
    final candidate = Booking(
      id: -1,
      courtId: draft.courtId,
      date: draft.date,
      startTimeRaw: BookingDraft.formatTime(draft.startTime),
      endTimeRaw: BookingDraft.formatTime(draft.endTime),
      bookingStatusRaw: (draft.status ?? BookingStatus.confirmed).slug,
    );

    final pool = _catalogueMode ? _rows : [..._rows, ..._current];
    return pool
        .where(
          (booking) =>
              booking.id != ignoreId && candidate.clashesWith(booking),
        )
        .toList(growable: false);
  }

  Future<Booking> create(BookingDraft draft) async {
    AdminLog.ui('Create booking submitted');
    final created = await _repository.createBooking(draft);
    _page = 1;
    await load();
    await _refreshSideViews();
    return created;
  }

  Future<Booking> update(int id, BookingDraft draft) async {
    AdminLog.ui('Update booking $id submitted');
    final updated = await _repository.updateBooking(id, draft);

    if (_selected?.id == id) {
      _selected = _selected!.mergedWith(updated);
      _safeNotify();
    }

    await load();
    await _refreshSideViews();
    return updated;
  }

  Future<void> delete(int id) async {
    AdminLog.ui('Delete booking $id confirmed');

    // Optimistic: the row disappears immediately, and is put back if the call
    // fails, so a failed delete never silently loses a row from the table.
    final previous = _rows;
    _rows = _rows.where((booking) => booking.id != id).toList();
    if (_selected?.id == id) closeBooking();
    _clampPage();
    _safeNotify();

    try {
      await _repository.deleteBooking(id);
    } catch (error) {
      if (!_disposed) {
        AdminLog.failure('Delete failed — restoring the row', error: error);
        _rows = previous;
        _safeNotify();
      }
      rethrow;
    }

    await load();
    await _refreshSideViews();
  }

  /// A booking status change is a `PUT` of that one field — there is no route
  /// of its own. Optimistic, reverted if the server refuses.
  Future<void> setStatus(int id, BookingStatus status) async {
    final current = _rowFor(id);
    if (current == null || current.status == status) return;

    _busyRows.add(id);
    _replaceRow(id, current.copyWith(bookingStatusRaw: status.slug));
    _safeNotify();

    try {
      await _repository.updateBooking(id, BookingDraft(status: status));
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

  Future<void> setPaymentStatus(int id, PaymentStatus payment) async {
    final current = _rowFor(id);
    if (current == null || current.payment == payment) return;

    _busyRows.add(id);
    _replaceRow(id, current.copyWith(paymentStatusRaw: payment.slug));
    _safeNotify();

    try {
      await _repository.updateBooking(id, BookingDraft(payment: payment));
    } catch (error) {
      if (!_disposed) {
        AdminLog.failure('Payment change rejected — reverting', error: error);
        _replaceRow(id, current);
      }
      rethrow;
    } finally {
      _busyRows.remove(id);
      _safeNotify();
    }
  }

  /// A write makes the loaded stats and today's board stale, so whichever has
  /// been opened is re-read. Neither is fetched speculatively.
  Future<void> _refreshSideViews() async {
    final tasks = <Future<void>>[
      if (!_statsState.isIdle) loadStats(),
      if (!_currentState.isIdle) loadCurrent(),
    ];
    if (tasks.isNotEmpty) await Future.wait(tasks);
  }

  Booking? _rowFor(int id) {
    for (final booking in _rows) {
      if (booking.id == id) return booking;
    }
    return _selected?.id == id ? _selected : null;
  }

  /// Applies a row change everywhere it is held, so the table, the cards,
  /// today's board and an open drawer can never disagree.
  void _replaceRow(int id, Booking next) {
    _rows = _rows
        .map((booking) => booking.id == id ? next : booking)
        .toList(growable: false);
    _current = _current
        .map((booking) => booking.id == id ? next : booking)
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
    AdminLog.life('BookingsController disposed');
    super.dispose();
  }
}
