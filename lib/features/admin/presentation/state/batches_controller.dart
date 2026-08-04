import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../models/sports_complex_model.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/admin_role.dart';
import '../../domain/entities/batch.dart';
import '../../domain/entities/coach.dart';
import '../../domain/entities/paged.dart';
import '../../domain/entities/sport.dart';
import '../../domain/repositories/batch_repository.dart';
import 'view_state.dart';

/// The three ways the module presents its data.
enum BatchesView {
  list('All batches', 'List'),
  bySport('Sport-wise', 'By sport'),
  byCoach('Coach-wise', 'By coach');

  const BatchesView(this.label, this.shortLabel);

  final String label;
  final String shortLabel;
}

/// The columns the batches table can be ordered by.
///
/// These carry no wire value: `/batches` has no `sortBy`, so ordering happens
/// here — which is also why sorting switches the controller into catalogue mode
/// (see [BatchesController]).
enum BatchSort {
  name('Batch name'),
  sport('Sport'),
  coach('Coach'),
  complex('Sports complex'),
  startDate('Start date'),
  endDate('End date'),
  fees('Fees'),
  maxStudents('Max students'),
  currentStudents('Current students'),
  availableSeats('Available seats'),
  occupancy('Occupancy'),
  status('Status');

  const BatchSort(this.label);

  final String label;
}

/// The five summary figures above the table.
///
/// There is no catalogue-wide statistics endpoint, so these are counted from
/// the rows in hand. [total] is the one figure that is always the server's own
/// `totalItems` when it sent one, because a page of twenty must not claim the
/// academy runs twenty batches.
class BatchesSummary {
  const BatchesSummary({
    this.total = 0,
    this.active = 0,
    this.inactive = 0,
    this.totalStudents,
    this.availableSeats,
  });

  final int total;
  final int active;
  final int inactive;

  /// Null when not one row reported a headcount — a zero there would claim an
  /// empty academy when the API simply did not say.
  final int? totalStudents;

  /// Null for the same reason: a batch with no capacity has unknown seats, not
  /// zero free ones.
  final int? availableSeats;

  static BatchesSummary from(List<AdminBatch> batches, {int? total}) {
    var active = 0;
    var inactive = 0;

    var students = 0;
    var studentsKnown = false;
    var seats = 0;
    var seatsKnown = false;

    for (final batch in batches) {
      if (batch.status == AdminUserStatus.active) active++;
      if (batch.status == AdminUserStatus.inactive) inactive++;

      final current = batch.currentStudents;
      if (current != null) {
        studentsKnown = true;
        students += current;
      }

      final free = batch.availableSeats;
      if (free != null) {
        seatsKnown = true;
        seats += free;
      }
    }

    return BatchesSummary(
      total: total ?? batches.length,
      active: active,
      inactive: inactive,
      totalStudents: studentsKnown ? students : null,
      availableSeats: seatsKnown ? seats : null,
    );
  }
}

/// Everything the Batches page needs.
///
/// This is the first admin module whose list route is genuinely paginated, so
/// the controller runs in one of two modes and says which:
///
/// * **Server paging** — the default. `GET /batches?status=&sportId=&page=&
///   limit=` is asked for one page at a time and the pagination bar is driven
///   by the server's own counters.
/// * **Catalogue** — entered as soon as something the route cannot express is
///   asked for: a search, a coach / complex / age-group filter, or a sort. All
///   pages are loaded once (up to a cap) and the work is done here. Without
///   this, "search" would mean "search page one", which looks identical to
///   "no matches".
///
/// [isCatalogueMode] and [catalogueCapped] are exposed so the page can explain
/// which of the two is in force rather than leaving the admin to guess.
class BatchesController extends ChangeNotifier {
  BatchesController(this._repository) {
    AdminLog.life('BatchesController created');
  }

  final BatchRepository _repository;

  static const Duration searchDebounce = Duration(milliseconds: 300);
  static const List<int> pageSizes = [10, 20, 50, 100];

  /// How much of the catalogue a filtered read will pull before giving up.
  static const int cataloguePageSize = 100;
  static const int catalogueMaxPages = 20;

  ViewState _state = ViewState.idle;
  String? _error;

  BatchesView _view = BatchesView.list;

  /// The rows currently on screen: one server page, or the whole catalogue.
  List<AdminBatch> _rows = const [];

  /// The server's own counters, kept only while server paging.
  int _serverPage = 1;
  int _serverTotalPages = 1;
  int _serverTotalItems = 0;

  bool _catalogueMode = false;
  int? _cappedAt;
  int? _cappedTotal;

  String _search = '';
  String _appliedSearch = '';

  // Server-side.
  AdminUserStatus? _statusFilter;
  int? _sportFilter;

  // Local — none of these has a query parameter, so each forces catalogue mode.
  int? _coachFilter;
  int? _complexFilter;
  String? _ageGroupFilter;

  BatchSort? _sort;
  bool _descending = false;

  int _page = 1;
  int _limit = 20;

  Timer? _debounce;
  int _requestId = 0;
  bool _disposed = false;

  // Detail drawer.
  AdminBatch? _selected;
  ViewState _detailState = ViewState.idle;
  String? _detailError;

  BatchStatistics? _stats;
  ViewState _statsState = ViewState.idle;

  // Grouped views.
  int? _groupSportId;
  List<AdminBatch> _sportGroup = const [];
  ViewState _sportGroupState = ViewState.idle;
  String? _sportGroupError;

  int? _groupCoachId;
  CoachBatchLoad? _coachGroup;
  ViewState _coachGroupState = ViewState.idle;
  String? _coachGroupError;

  // Dropdown catalogues.
  List<Sport> _sports = const [];
  ViewState _sportsState = ViewState.idle;

  List<Coach> _coaches = const [];
  ViewState _coachesState = ViewState.idle;

  List<SportsComplex> _complexes = const [];
  ViewState _complexesState = ViewState.idle;

  /// Ids with a status write in flight, so the row can disable just that
  /// control instead of the whole table.
  final Set<int> _busyRows = <int>{};

  // --- Reads -----------------------------------------------------------------

  ViewState get state => _state;
  String? get error => _error;

  BatchesView get view => _view;

  List<AdminBatch> get rows => _rows;

  /// True while every page has been pulled so a local filter or sort can be
  /// applied honestly.
  bool get isCatalogueMode => _catalogueMode;

  /// Set when the catalogue read hit its page cap: `(loaded, total)`.
  (int, int)? get catalogueCapped {
    final loaded = _cappedAt;
    final total = _cappedTotal;
    if (loaded == null || total == null) return null;
    return (loaded, total);
  }

  /// The summary figures. [BatchesSummary.total] is the server's own count
  /// while paging, so it describes the academy rather than the page.
  BatchesSummary get summary => BatchesSummary.from(
    _catalogueMode ? visibleRows : _rows,
    total: _catalogueMode ? visibleRows.length : _serverTotalItems,
  );

  /// True when the four counted figures describe one page rather than
  /// everything — the cards caption themselves with this.
  bool get summaryIsPageScoped => !_catalogueMode && _serverTotalPages > 1;

  String get search => _search;
  AdminUserStatus? get statusFilter => _statusFilter;
  int? get sportFilter => _sportFilter;
  int? get coachFilter => _coachFilter;
  int? get complexFilter => _complexFilter;
  String? get ageGroupFilter => _ageGroupFilter;

  BatchSort? get sort => _sort;
  bool get descending => _descending;
  int get limit => _limit;

  AdminBatch? get selected => _selected;
  ViewState get detailState => _detailState;
  String? get detailError => _detailError;
  BatchStatistics? get stats => _stats;
  ViewState get statsState => _statsState;

  int? get groupSportId => _groupSportId;
  List<AdminBatch> get sportGroup => _sportGroup;
  ViewState get sportGroupState => _sportGroupState;
  String? get sportGroupError => _sportGroupError;

  int? get groupCoachId => _groupCoachId;
  CoachBatchLoad? get coachGroup => _coachGroup;
  ViewState get coachGroupState => _coachGroupState;
  String? get coachGroupError => _coachGroupError;

  List<Sport> get sports => _sports;
  ViewState get sportsState => _sportsState;
  List<Coach> get coaches => _coaches;
  ViewState get coachesState => _coachesState;
  List<SportsComplex> get complexes => _complexes;
  ViewState get complexesState => _complexesState;

  bool isRowBusy(int id) => _busyRows.contains(id);

  Sport? get filteredSport => sportById(_sportFilter);
  Coach? get filteredCoach => coachById(_coachFilter);
  SportsComplex? get filteredComplex => complexById(_complexFilter);

  Sport? sportById(int? id) {
    if (id == null) return null;
    for (final sport in _sports) {
      if (sport.id == id) return sport;
    }
    return null;
  }

  Coach? coachById(int? id) {
    if (id == null) return null;
    for (final coach in _coaches) {
      if (coach.id == id) return coach;
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

  /// Age groups seen on the rows so far. There is no `/age-groups` endpoint, so
  /// the filter's options are *learned* from what the API returned rather than
  /// hardcoded — the same approach the guard and coach modules take.
  List<String> get knownAgeGroups {
    final seen = <String, String>{};
    for (final batch in _rows) {
      final group = (batch.ageGroup ?? '').trim();
      if (group.isEmpty) continue;
      seen.putIfAbsent(group.toLowerCase(), () => group);
    }
    final groups = seen.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return groups;
  }

  bool get hasFilters =>
      _appliedSearch.trim().isNotEmpty ||
      _statusFilter != null ||
      _sportFilter != null ||
      _coachFilter != null ||
      _complexFilter != null ||
      _ageGroupFilter != null;

  /// How many dropdown filters are set — drives the badge on the Filter button.
  /// Search is excluded; it has its own visible box.
  int get activeFilterCount => [
    _statusFilter,
    _sportFilter,
    _coachFilter,
    _complexFilter,
    _ageGroupFilter,
  ].where((filter) => filter != null).length;

  bool get isFirstLoad => _state.isLoading && _rows.isEmpty;
  bool get isRefreshing => _state.isLoading && _rows.isNotEmpty;

  /// True when what is being asked for cannot be expressed as a query on
  /// `/batches`, so the whole catalogue has to be in hand to answer honestly.
  bool get _needsCatalogue =>
      _appliedSearch.trim().isNotEmpty ||
      _coachFilter != null ||
      _complexFilter != null ||
      _ageGroupFilter != null ||
      _sort != null;

  /// Every row that survives the local filters, in the requested order.
  ///
  /// In server-paging mode this is just the page the server sent: nothing local
  /// is in force, by definition of [_needsCatalogue].
  List<AdminBatch> get visibleRows {
    if (!_catalogueMode) return _rows;

    final query = _appliedSearch.trim();

    final filtered = _rows.where((batch) {
      if (!batch.matches(query)) return false;

      if (_coachFilter != null && batch.coachId != _coachFilter) return false;
      if (_complexFilter != null &&
          batch.sportComplexId != _complexFilter) {
        return false;
      }

      if (_ageGroupFilter != null) {
        final group = (batch.ageGroup ?? '').trim().toLowerCase();
        if (group != _ageGroupFilter!.trim().toLowerCase()) return false;
      }

      // Re-checked so the table stays honest if a backend ignores one of its
      // own query parameters.
      if (_statusFilter != null && batch.status != _statusFilter) return false;
      if (_sportFilter != null && batch.sportId != _sportFilter) return false;

      return true;
    }).toList();

    _sortRows(filtered);
    return filtered;
  }

  void _sortRows(List<AdminBatch> rows) {
    final by = _sort;
    if (by == null) return;

    int compare(AdminBatch a, AdminBatch b) {
      switch (by) {
        case BatchSort.name:
          return a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          );
        case BatchSort.sport:
          return (a.sportName ?? '').toLowerCase().compareTo(
            (b.sportName ?? '').toLowerCase(),
          );
        case BatchSort.coach:
          return (a.coachName ?? '').toLowerCase().compareTo(
            (b.coachName ?? '').toLowerCase(),
          );
        case BatchSort.complex:
          return (a.sportComplexName ?? '').toLowerCase().compareTo(
            (b.sportComplexName ?? '').toLowerCase(),
          );
        case BatchSort.startDate:
          return a.startDate!.compareTo(b.startDate!);
        case BatchSort.endDate:
          return a.endDate!.compareTo(b.endDate!);
        case BatchSort.fees:
          return (a.fees ?? 0).compareTo(b.fees ?? 0);
        case BatchSort.maxStudents:
          return (a.maxStudents ?? 0).compareTo(b.maxStudents ?? 0);
        case BatchSort.currentStudents:
          return (a.currentStudents ?? 0).compareTo(b.currentStudents ?? 0);
        case BatchSort.availableSeats:
          return (a.availableSeats ?? 0).compareTo(b.availableSeats ?? 0);
        case BatchSort.occupancy:
          return (a.occupancy ?? 0).compareTo(b.occupancy ?? 0);
        case BatchSort.status:
          return a.statusLabel.compareTo(b.statusLabel);
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

  static bool _isMissing(BatchSort by, AdminBatch batch) {
    switch (by) {
      case BatchSort.sport:
        return (batch.sportName ?? '').trim().isEmpty;
      case BatchSort.coach:
        return (batch.coachName ?? '').trim().isEmpty;
      case BatchSort.complex:
        return (batch.sportComplexName ?? '').trim().isEmpty;
      case BatchSort.startDate:
        return batch.startDate == null;
      case BatchSort.endDate:
        return batch.endDate == null;
      case BatchSort.fees:
        return batch.fees == null;
      case BatchSort.maxStudents:
        return batch.maxStudents == null;
      case BatchSort.currentStudents:
        return batch.currentStudents == null;
      case BatchSort.availableSeats:
        return batch.availableSeats == null;
      case BatchSort.occupancy:
        return batch.occupancy == null;
      case BatchSort.name:
      case BatchSort.status:
        return false;
    }
  }

  /// The rows on screen right now — one server page, or the current slice of
  /// the filtered catalogue.
  List<AdminBatch> get pageRows {
    if (!_catalogueMode) return _rows;

    final rows = visibleRows;
    if (rows.isEmpty) return const [];

    final start = (_page - 1) * _limit;
    if (start >= rows.length) return const [];
    final end = (start + _limit).clamp(0, rows.length);
    return rows.sublist(start, end);
  }

  /// Everything an export should write: the filtered set in catalogue mode, and
  /// the page in hand while paging. The export dialog says which.
  List<AdminBatch> get exportRows => _catalogueMode ? visibleRows : _rows;

  /// Shaped for [PaginationBar], from whichever of the two sources is in force.
  Paged<AdminBatch> get page {
    if (!_catalogueMode) {
      return Paged<AdminBatch>(
        items: _rows,
        page: _serverPage,
        limit: _limit,
        total: _serverTotalItems,
        totalPages: _serverTotalPages,
      );
    }

    final total = visibleRows.length;
    return Paged<AdminBatch>(
      items: pageRows,
      page: _page,
      limit: _limit,
      total: total,
      totalPages: total == 0 ? 0 : (total / _limit).ceil(),
    );
  }

  // --- Loading ---------------------------------------------------------------

  Future<void> load() async {
    final id = ++_requestId;
    final catalogue = _needsCatalogue;

    AdminLog.state(
      'Batches loading (${catalogue ? 'catalogue' : 'page $_page'}) → '
      'status=${_statusFilter?.slug ?? '-'} sport=${_sportFilter ?? '-'} '
      'coach=${_coachFilter ?? '-'} complex=${_complexFilter ?? '-'} '
      'age=${_ageGroupFilter ?? '-'} search="${_appliedSearch.trim()}" '
      'sort=${_sort?.name ?? '-'}',
    );

    _state = ViewState.loading;
    _error = null;
    _safeNotify();

    try {
      if (catalogue) {
        _cappedAt = null;
        _cappedTotal = null;

        final all = await _repository.fetchAllBatches(
          status: _statusFilter,
          sportId: _sportFilter,
          limit: cataloguePageSize,
          maxPages: catalogueMaxPages,
          onCapped: (loaded, total) {
            _cappedAt = loaded;
            _cappedTotal = total;
          },
        );

        if (_disposed || id != _requestId) {
          AdminLog.state('Batch catalogue superseded — dropped');
          return;
        }

        _catalogueMode = true;
        _rows = all;
        _serverTotalItems = all.length;
        _serverTotalPages = 1;
        _state = ViewState.ready;
        _clampPage();
        AdminLog.state('Batch catalogue ready → ${all.length} rows');
      } else {
        final result = await _repository.fetchBatches(
          status: _statusFilter,
          sportId: _sportFilter,
          page: _page,
          limit: _limit,
        );

        if (_disposed || id != _requestId) {
          AdminLog.state('Batches response superseded — dropped');
          return;
        }

        _catalogueMode = false;
        _cappedAt = null;
        _cappedTotal = null;
        _rows = result.batches;
        _serverPage = result.page;
        _serverTotalPages = result.totalPages;
        _serverTotalItems = result.totalItems;
        // Keeps the local cursor in step with what the server actually served,
        // so a clamped page does not fight the next Next-page tap.
        _page = result.page;
        _state = ViewState.ready;
        AdminLog.state(
          'Batches ready → ${result.batches.length} rows '
          '(page ${result.page}/${result.totalPages})',
        );
      }
    } on ApiException catch (error) {
      if (_disposed || id != _requestId) return;
      _state = ViewState.failed;
      _error = error.message;
      AdminLog.failure('Batches load failed: ${error.message}', error: error);
    } catch (error, stackTrace) {
      if (_disposed || id != _requestId) return;
      _state = ViewState.failed;
      _error = 'Could not load batches. Please try again.';
      AdminLog.failure(
        'Batches load crashed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _safeNotify();
    }
  }

  Future<void> refresh() {
    AdminLog.ui('Batches refresh requested');
    return load();
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
      AdminLog.state('Batch sport list ready → ${result.length}');
    } catch (error, stackTrace) {
      if (_disposed) return;
      _sportsState = ViewState.failed;
      AdminLog.failure(
        'Batch sport list failed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _safeNotify();
    }
  }

  Future<void> loadCoaches({bool refresh = false}) async {
    if (_coachesState.isLoading) return;
    if (_coaches.isNotEmpty && !refresh) return;

    _coachesState = ViewState.loading;
    _safeNotify();

    try {
      final result = await _repository.fetchCoaches(refresh: refresh);
      if (_disposed) return;
      _coaches = result;
      _coachesState = ViewState.ready;
      AdminLog.state('Batch coach list ready → ${result.length}');
    } catch (error, stackTrace) {
      if (_disposed) return;
      _coachesState = ViewState.failed;
      AdminLog.failure(
        'Batch coach list failed',
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
      AdminLog.state('Batch venue list ready → ${result.length}');
    } catch (error, stackTrace) {
      if (_disposed) return;
      _complexesState = ViewState.failed;
      AdminLog.failure(
        'Batch venue list failed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _safeNotify();
    }
  }

  // --- Grouped views ---------------------------------------------------------

  void setView(BatchesView view) {
    if (_view == view) return;
    AdminLog.ui('Batches view → ${view.name}');
    _view = view;
    _safeNotify();

    // The grouped views need a subject before they can ask for anything, and
    // they pick it from the catalogues the filters already loaded.
    switch (view) {
      case BatchesView.list:
        break;
      case BatchesView.bySport:
        loadSports();
        if (_groupSportId == null && _sportFilter != null) {
          selectGroupSport(_sportFilter);
        } else if (_groupSportId != null && _sportGroupState.isIdle) {
          loadSportGroup();
        }
      case BatchesView.byCoach:
        loadCoaches();
        if (_groupCoachId == null && _coachFilter != null) {
          selectGroupCoach(_coachFilter);
        } else if (_groupCoachId != null && _coachGroupState.isIdle) {
          loadCoachGroup();
        }
    }
  }

  void selectGroupSport(int? sportId) {
    if (_groupSportId == sportId) return;
    AdminLog.ui('Batch sport group → ${sportId ?? 'none'}');
    _groupSportId = sportId;
    _sportGroup = const [];
    _sportGroupError = null;
    _sportGroupState = sportId == null ? ViewState.idle : ViewState.loading;
    _safeNotify();
    if (sportId != null) loadSportGroup();
  }

  Future<void> loadSportGroup() async {
    final sportId = _groupSportId;
    if (sportId == null) return;

    _sportGroupState = ViewState.loading;
    _sportGroupError = null;
    _safeNotify();

    try {
      final batches = await _repository.fetchBatchesBySport(sportId);
      if (_disposed || _groupSportId != sportId) return;
      _sportGroup = batches;
      _sportGroupState = ViewState.ready;
      AdminLog.state('Sport $sportId group ready → ${batches.length}');
    } on ApiException catch (error) {
      if (_disposed || _groupSportId != sportId) return;
      _sportGroupState = ViewState.failed;
      _sportGroupError = error.message;
    } catch (error, stackTrace) {
      if (_disposed || _groupSportId != sportId) return;
      _sportGroupState = ViewState.failed;
      _sportGroupError = 'Could not load the batches for this sport.';
      AdminLog.failure(
        'Sport group crashed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _safeNotify();
    }
  }

  void selectGroupCoach(int? coachId) {
    if (_groupCoachId == coachId) return;
    AdminLog.ui('Batch coach group → ${coachId ?? 'none'}');
    _groupCoachId = coachId;
    _coachGroup = null;
    _coachGroupError = null;
    _coachGroupState = coachId == null ? ViewState.idle : ViewState.loading;
    _safeNotify();
    if (coachId != null) loadCoachGroup();
  }

  Future<void> loadCoachGroup() async {
    final coachId = _groupCoachId;
    if (coachId == null) return;

    _coachGroupState = ViewState.loading;
    _coachGroupError = null;
    _safeNotify();

    try {
      final load = await _repository.fetchBatchesByCoach(
        coachId,
        coachName: coachById(coachId)?.displayName,
      );
      if (_disposed || _groupCoachId != coachId) return;
      _coachGroup = load;
      _coachGroupState = ViewState.ready;
      AdminLog.state('Coach $coachId group ready → ${load.totalBatches}');
    } on ApiException catch (error) {
      if (_disposed || _groupCoachId != coachId) return;
      _coachGroupState = ViewState.failed;
      _coachGroupError = error.message;
    } catch (error, stackTrace) {
      if (_disposed || _groupCoachId != coachId) return;
      _coachGroupState = ViewState.failed;
      _coachGroupError = 'Could not load the batches for this coach.';
      AdminLog.failure(
        'Coach group crashed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _safeNotify();
    }
  }

  // --- Search, filters, paging ----------------------------------------------

  /// Debounced. The first search also switches the module into catalogue mode,
  /// which is a real round trip, so the delay is doing more here than it does
  /// in the unpaginated modules.
  void onSearchChanged(String value) {
    if (_search == value) return;
    _search = value;
    AdminLog.ui('Batch search typed: "$value"');
    notifyListeners();

    _debounce?.cancel();
    _debounce = Timer(searchDebounce, () {
      if (_disposed) return;
      final previous = _appliedSearch;
      _appliedSearch = _search;
      _page = 1;
      AdminLog.ui('Batch search settled: "${_search.trim()}"');
      _reloadIfModeChanged(previouslyCatalogue: previous.trim().isNotEmpty);
    });
  }

  void clearSearch() {
    if (_search.isEmpty && _appliedSearch.isEmpty) return;
    AdminLog.ui('Batch search cleared');
    _debounce?.cancel();
    _search = '';
    _appliedSearch = '';
    _page = 1;
    _reloadIfModeChanged(previouslyCatalogue: true);
  }

  /// Server-side — `/batches` takes `status`, so this always refetches.
  void setStatusFilter(AdminUserStatus? status) {
    if (_statusFilter == status) return;
    AdminLog.ui('Batch status filter → ${status?.slug ?? 'All'}');
    _statusFilter = status;
    _page = 1;
    load();
  }

  /// Server-side — `/batches` takes `sportId`.
  void setSportFilter(int? sportId) {
    if (_sportFilter == sportId) return;
    AdminLog.ui('Batch sport filter → ${sportId ?? 'All'}');
    _sportFilter = sportId;
    _page = 1;
    load();
  }

  /// Local — no query parameter exists, so this needs the catalogue.
  void setCoachFilter(int? coachId) {
    if (_coachFilter == coachId) return;
    AdminLog.ui('Batch coach filter → ${coachId ?? 'All'}');
    final wasCatalogue = _needsCatalogue;
    _coachFilter = coachId;
    _page = 1;
    _reloadIfModeChanged(previouslyCatalogue: wasCatalogue);
  }

  void setComplexFilter(int? complexId) {
    if (_complexFilter == complexId) return;
    AdminLog.ui('Batch complex filter → ${complexId ?? 'All'}');
    final wasCatalogue = _needsCatalogue;
    _complexFilter = complexId;
    _page = 1;
    _reloadIfModeChanged(previouslyCatalogue: wasCatalogue);
  }

  void setAgeGroupFilter(String? ageGroup) {
    final next = (ageGroup ?? '').trim().isEmpty ? null : ageGroup;
    if (_ageGroupFilter == next) return;
    AdminLog.ui('Batch age group filter → ${next ?? 'All'}');
    final wasCatalogue = _needsCatalogue;
    _ageGroupFilter = next;
    _page = 1;
    _reloadIfModeChanged(previouslyCatalogue: wasCatalogue);
  }

  void clearFilters() {
    if (!hasFilters) return;
    AdminLog.ui('All batch filters cleared');
    _debounce?.cancel();

    final wasCatalogue = _needsCatalogue;
    final hadServerFilter = _statusFilter != null || _sportFilter != null;

    _search = '';
    _appliedSearch = '';
    _statusFilter = null;
    _sportFilter = null;
    _coachFilter = null;
    _complexFilter = null;
    _ageGroupFilter = null;
    _page = 1;

    if (hadServerFilter) {
      load();
    } else {
      _reloadIfModeChanged(previouslyCatalogue: wasCatalogue);
    }
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
    AdminLog.ui('Batch page size → $limit');
    _limit = limit;
    _page = 1;
    // Only the server needs telling; a catalogue re-slices in place.
    if (_catalogueMode) {
      _safeNotify();
    } else {
      load();
    }
  }

  /// Same column twice flips direction; a third tap restores the API's order.
  ///
  /// Sorting needs every row, so the first tap also pulls the catalogue.
  void toggleSort(BatchSort column) {
    final wasCatalogue = _needsCatalogue;

    if (_sort != column) {
      _sort = column;
      _descending = false;
    } else if (!_descending) {
      _descending = true;
    } else {
      _sort = null;
      _descending = false;
    }

    AdminLog.ui(
      'Batch sort → ${_sort?.name ?? 'default'}'
      '${_sort == null ? '' : (_descending ? ' desc' : ' asc')}',
    );
    _page = 1;
    _reloadIfModeChanged(previouslyCatalogue: wasCatalogue);
  }

  void goToPage(int target) {
    final total = page.effectiveTotalPages;
    final next = total > 0 ? target.clamp(1, total) : 1;
    if (next == _page) return;
    AdminLog.ui('Batches go to page $next');
    _page = next;

    // A server page is a request; a catalogue page is a slice.
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

  /// Shows the row already in hand, then fills in from the detail and stats
  /// routes. The two are awaited together so the drawer settles in one step.
  Future<void> openBatch(AdminBatch batch) async {
    AdminLog.ui('Batch detail opened for ${batch.id}');
    _selected = batch;
    _detailState = ViewState.loading;
    _detailError = null;
    _stats = null;
    _statsState = ViewState.loading;
    _safeNotify();

    await Future.wait([_loadDetail(batch), _loadStats(batch.id)]);
  }

  Future<void> _loadDetail(AdminBatch batch) async {
    try {
      final detail = await _repository.fetchBatch(batch.id);
      if (_disposed || _selected?.id != batch.id) return;

      _selected = batch.mergedWith(detail);
      _detailState = ViewState.ready;
      AdminLog.state('Batch detail ready for ${batch.id}');
    } on ApiException catch (error) {
      if (_disposed || _selected?.id != batch.id) return;
      _detailState = ViewState.failed;
      _detailError = error.message;
      AdminLog.failure('Batch detail failed: ${error.message}', error: error);
    } catch (error, stackTrace) {
      if (_disposed || _selected?.id != batch.id) return;
      _detailState = ViewState.failed;
      _detailError = 'Could not load this batch.';
      AdminLog.failure(
        'Batch detail crashed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _safeNotify();
    }
  }

  Future<void> _loadStats(int id) async {
    try {
      final stats = await _repository.fetchStats(id);
      if (_disposed || _selected?.id != id) return;
      _stats = stats;
      _statsState = ViewState.ready;
      AdminLog.state('Batch stats ready for $id');
    } catch (error) {
      if (_disposed || _selected?.id != id) return;
      _statsState = ViewState.failed;
      // Not surfaced as a drawer error: the rest of the detail is still good.
      AdminLog.failure('Batch stats unavailable for $id', error: error);
    } finally {
      _safeNotify();
    }
  }

  Future<void> retryStats() {
    final id = _selected?.id;
    if (id == null) return Future<void>.value();
    _statsState = ViewState.loading;
    _safeNotify();
    return _loadStats(id);
  }

  void closeBatch() {
    if (_selected == null) return;
    AdminLog.ui('Batch detail closed');
    _selected = null;
    _detailState = ViewState.idle;
    _detailError = null;
    _stats = null;
    _statsState = ViewState.idle;
    _safeNotify();
  }

  // --- Writes ----------------------------------------------------------------

  Future<AdminBatch> create(BatchDraft draft) async {
    AdminLog.ui('Create batch submitted');
    final created = await _repository.createBatch(draft);
    _page = 1;
    await load();
    return created;
  }

  Future<AdminBatch> update(int id, BatchDraft draft) async {
    AdminLog.ui('Update batch $id submitted');
    final updated = await _repository.updateBatch(id, draft);

    if (_selected?.id == id) {
      _selected = _selected!.mergedWith(updated);
      _safeNotify();
    }

    await load();
    return updated;
  }

  Future<void> delete(int id) async {
    AdminLog.ui('Delete batch $id confirmed');

    // Optimistic: the row disappears immediately, and is put back if the call
    // fails, so a failed delete never silently loses a row from the table.
    final previous = _rows;

    _rows = _rows.where((batch) => batch.id != id).toList();
    if (_selected?.id == id) closeBatch();
    _clampPage();
    _safeNotify();

    try {
      await _repository.deleteBatch(id);
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

  /// `PATCH /{id}/status`, applied to the row before the call so the badge
  /// flips instantly; reverted if the server refuses.
  Future<void> setStatus(int id, AdminUserStatus status) async {
    final current = _rowFor(id);
    if (current == null || current.status == status) return;

    AdminLog.ui('Batch $id status → ${status.slug}');
    _busyRows.add(id);
    _replaceRow(id, current.copyWith(statusRaw: status.slug));
    _safeNotify();

    try {
      await _repository.setStatus(id, status);
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

  AdminBatch? _rowFor(int id) {
    for (final batch in _rows) {
      if (batch.id == id) return batch;
    }
    return _selected?.id == id ? _selected : null;
  }

  /// Applies a row change everywhere it is held, so the table, the summary
  /// cards, the grouped views and an open drawer can never disagree.
  void _replaceRow(int id, AdminBatch next) {
    _rows = _rows
        .map((batch) => batch.id == id ? next : batch)
        .toList(growable: false);

    _sportGroup = _sportGroup
        .map((batch) => batch.id == id ? next : batch)
        .toList(growable: false);

    final group = _coachGroup;
    if (group != null) {
      _coachGroup = CoachBatchLoad(
        coachId: group.coachId,
        coachName: group.coachName,
        batches: group.batches
            .map((batch) => batch.id == id ? next : batch)
            .toList(growable: false),
      );
    }

    if (_selected?.id == id) _selected = next;
  }

  // --- Images ----------------------------------------------------------------
  //
  // Owned by the controller rather than the dialog so an upload survives the
  // dialog rebuilding, and so the route goes through one logged path.

  Future<String> uploadImage(String filePath, {String? filename}) {
    AdminLog.ui('Batch image upload started');
    return _repository.uploadImage(filePath, filename: filename);
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    AdminLog.life('BatchesController disposed');
    super.dispose();
  }
}
