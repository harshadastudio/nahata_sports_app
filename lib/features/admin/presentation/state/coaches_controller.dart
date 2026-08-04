import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../models/sports_complex_model.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/admin_role.dart';
import '../../domain/entities/coach.dart';
import '../../domain/entities/paged.dart';
import '../../domain/entities/sport.dart';
import '../../domain/repositories/coach_repository.dart';
import 'view_state.dart';

/// The columns the coaches table can be ordered by.
///
/// These carry no wire value: `/coaches` is unpaginated and has no `sortBy`, so
/// ordering happens here over the rows the server returned.
enum CoachSort {
  name('Coach name'),
  email('Email'),
  sport('Sport'),
  complex('Sports complex'),
  ground('Ground'),
  experience('Experience'),
  price('Price'),
  availability('Availability'),
  status('Status');

  const CoachSort(this.label);

  final String label;
}

/// The six summary figures above the table.
///
/// There is no catalogue-wide statistics endpoint, so these are counted from
/// the rows `/coaches` returned for the current sport and status — never a
/// second request, and never a fabricated number. They deliberately ignore the
/// local filters (search, complex, category): those narrow what is *shown*,
/// while these describe what the server sent.
class CoachesSummary {
  const CoachesSummary({
    this.total = 0,
    this.active = 0,
    this.inactive = 0,
    this.sportsCovered = 0,
    this.complexesCovered = 0,
    this.availableToday,
  });

  final int total;
  final int active;
  final int inactive;

  /// Distinct sports named across the rows, matched case-insensitively so
  /// "Badminton" and "badminton" are not counted twice.
  final int sportsCovered;

  final int complexesCovered;

  /// Coaches whose schedule names today. Null when not one row carries a
  /// schedule this app can read — an unset or free-text availability is not
  /// evidence of absence, and a zero there would be a claim the data does not
  /// support.
  final int? availableToday;

  static CoachesSummary from(List<Coach> coaches, {DateTime? now}) {
    final today = now ?? DateTime.now();

    var active = 0;
    var inactive = 0;
    var available = 0;
    var readable = 0;

    final sports = <String>{};
    final complexes = <String>{};

    for (final coach in coaches) {
      if (coach.status == AdminUserStatus.active) active++;
      if (coach.status == AdminUserStatus.inactive) inactive++;

      for (final sport in coach.allSportNames) {
        sports.add(sport.toLowerCase());
      }

      // Prefer the id, which cannot drift, and fall back to the name for a
      // payload that sent only that.
      final complexId = coach.sportComplexId;
      final complexName = (coach.sportComplexName ?? '').trim();
      if (complexId != null) {
        complexes.add('#$complexId');
      } else if (complexName.isNotEmpty) {
        complexes.add(complexName.toLowerCase());
      }

      final availableTodayForCoach = coach.availability.availableOn(today);
      if (availableTodayForCoach != null) {
        readable++;
        if (availableTodayForCoach) available++;
      }
    }

    return CoachesSummary(
      total: coaches.length,
      active: active,
      inactive: inactive,
      sportsCovered: sports.length,
      complexesCovered: complexes.length,
      availableToday: readable == 0 ? null : available,
    );
  }
}

/// Everything the Coaches page needs.
///
/// Status and the sport are asked of the server — status is `/coaches?status=`
/// and the sport is its own route, `/coaches/sport/{sportId}`. Because they are
/// two different routes rather than two query parameters, they cannot be
/// combined server-side: when a sport is picked the sport route is called and
/// the status is re-applied here. Search, complex, category, sorting and paging
/// are always local.
class CoachesController extends ChangeNotifier {
  CoachesController(this._repository) {
    AdminLog.life('CoachesController created');
  }

  final CoachRepository _repository;

  static const Duration searchDebounce = Duration(milliseconds: 300);
  static const List<int> pageSizes = [10, 20, 50, 100];

  ViewState _state = ViewState.idle;
  String? _error;

  List<Coach> _rows = const [];

  String _search = '';
  String _appliedSearch = '';

  // Server-side.
  AdminUserStatus? _statusFilter;
  int? _sportFilter;

  // Local.
  int? _complexFilter;
  SportCategory? _categoryFilter;

  CoachSort? _sort;
  bool _descending = false;

  int _page = 1;
  int _limit = 20;

  Timer? _debounce;
  int _requestId = 0;
  bool _disposed = false;

  // Detail drawer.
  Coach? _selected;
  ViewState _detailState = ViewState.idle;
  String? _detailError;

  // Stats are loaded beside the detail but tracked separately: a stats failure
  // must not blank a drawer whose detail arrived fine.
  CoachStats? _stats;
  ViewState _statsState = ViewState.idle;

  // Dropdown catalogues for the form and the filters.
  List<Sport> _sports = const [];
  ViewState _sportsState = ViewState.idle;

  List<SportsComplex> _complexes = const [];
  ViewState _complexesState = ViewState.idle;

  /// Ids with a status write in flight, so the row can disable just that
  /// control instead of the whole table.
  final Set<int> _busyRows = <int>{};

  // --- Reads -----------------------------------------------------------------

  ViewState get state => _state;
  String? get error => _error;

  List<Coach> get rows => _rows;
  CoachesSummary get summary => CoachesSummary.from(_rows);

  String get search => _search;
  AdminUserStatus? get statusFilter => _statusFilter;
  int? get sportFilter => _sportFilter;
  int? get complexFilter => _complexFilter;
  SportCategory? get categoryFilter => _categoryFilter;

  CoachSort? get sort => _sort;
  bool get descending => _descending;
  int get limit => _limit;

  Coach? get selected => _selected;
  ViewState get detailState => _detailState;

  /// Set when `GET /coaches/{id}` failed. The drawer keeps showing the list
  /// row and notes that the extra detail is missing — that route is not part
  /// of the documented module, so its absence must not break the panel.
  String? get detailError => _detailError;

  CoachStats? get stats => _stats;
  ViewState get statsState => _statsState;

  List<Sport> get sports => _sports;
  ViewState get sportsState => _sportsState;

  List<SportsComplex> get complexes => _complexes;
  ViewState get complexesState => _complexesState;

  bool isRowBusy(int id) => _busyRows.contains(id);

  /// The sport behind [sportFilter], for the filter chip's label.
  Sport? get filteredSport => sportById(_sportFilter);

  Sport? sportById(int? id) {
    if (id == null) return null;
    for (final sport in _sports) {
      if (sport.id == id) return sport;
    }
    return null;
  }

  SportsComplex? get filteredComplex => complexById(_complexFilter);

  SportsComplex? complexById(int? id) {
    if (id == null) return null;
    for (final complex in _complexes) {
      if (complex.id == id) return complex;
    }
    return null;
  }

  /// Grounds seen on the rows so far. There is no `/grounds` endpoint, so the
  /// form's suggestions are *learned* from what the API has returned rather
  /// than hardcoded — the same approach the guard module takes for postings.
  List<String> get knownGrounds {
    final seen = <String, String>{};
    for (final coach in _rows) {
      final ground = (coach.ground ?? '').trim();
      if (ground.isEmpty) continue;
      seen.putIfAbsent(ground.toLowerCase(), () => ground);
    }
    final grounds = seen.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return grounds;
  }

  bool get hasFilters =>
      _appliedSearch.trim().isNotEmpty ||
      _statusFilter != null ||
      _sportFilter != null ||
      _complexFilter != null ||
      _categoryFilter != null;

  /// How many dropdown filters are set — drives the badge on the Filter button.
  /// Search is excluded; it has its own visible box.
  int get activeFilterCount => [
    _statusFilter,
    _sportFilter,
    _complexFilter,
    _categoryFilter,
  ].where((filter) => filter != null).length;

  bool get isFirstLoad => _state.isLoading && _rows.isEmpty;
  bool get isRefreshing => _state.isLoading && _rows.isNotEmpty;

  /// Every row that survives the local filters, in the requested order.
  List<Coach> get visibleRows {
    final query = _appliedSearch.trim();

    final filtered = _rows.where((coach) {
      if (!coach.matches(query)) return false;

      if (_complexFilter != null && coach.sportComplexId != _complexFilter) {
        return false;
      }

      if (_categoryFilter != null && coach.category != _categoryFilter) {
        return false;
      }

      // The sport route does not accept a status, so this is the only place
      // the two filters can be true at once. Re-checking also keeps the table
      // honest if a backend ignores its own `status` parameter.
      if (_statusFilter != null && coach.status != _statusFilter) return false;

      return true;
    }).toList();

    _sortRows(filtered);
    return filtered;
  }

  void _sortRows(List<Coach> rows) {
    final by = _sort;
    if (by == null) return;

    int compare(Coach a, Coach b) {
      switch (by) {
        case CoachSort.name:
          return a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          );
        case CoachSort.email:
          return (a.email ?? '').toLowerCase().compareTo(
            (b.email ?? '').toLowerCase(),
          );
        case CoachSort.sport:
          return (a.sportName ?? '').toLowerCase().compareTo(
            (b.sportName ?? '').toLowerCase(),
          );
        case CoachSort.complex:
          return (a.sportComplexName ?? '').toLowerCase().compareTo(
            (b.sportComplexName ?? '').toLowerCase(),
          );
        case CoachSort.ground:
          return (a.ground ?? '').toLowerCase().compareTo(
            (b.ground ?? '').toLowerCase(),
          );
        case CoachSort.experience:
          // Free text on the wire ("5 years"), so the leading number is what
          // actually orders it; identical numbers fall back to the text.
          final first = _leadingNumber(a.experience);
          final second = _leadingNumber(b.experience);
          if (first != second) return first.compareTo(second);
          return (a.experience ?? '').toLowerCase().compareTo(
            (b.experience ?? '').toLowerCase(),
          );
        case CoachSort.price:
          return (a.price ?? 0).compareTo(b.price ?? 0);
        case CoachSort.availability:
          // Most days first once reversed; a custom schedule sorts as one day
          // rather than as nothing, since it does say something.
          return _availabilityWeight(a).compareTo(_availabilityWeight(b));
        case CoachSort.status:
          return a.statusLabel.compareTo(b.statusLabel);
      }
    }

    rows.sort((a, b) {
      // Rows with nothing to sort by sink in BOTH directions — reversing the
      // comparison would otherwise float every blank to the top.
      final missingA = _isMissing(by, a);
      final missingB = _isMissing(by, b);
      if (missingA && missingB) return 0;
      if (missingA != missingB) return missingA ? 1 : -1;

      return _descending ? compare(b, a) : compare(a, b);
    });
  }

  static double _leadingNumber(String? value) {
    final match = RegExp(r'\d+(\.\d+)?').firstMatch(value ?? '');
    if (match == null) return -1;
    return double.tryParse(match.group(0)!) ?? -1;
  }

  static int _availabilityWeight(Coach coach) {
    final availability = coach.availability;
    if (availability.isEmpty) return 0;
    if (availability.isCustom) return 1;
    return availability.days.length;
  }

  static bool _isMissing(CoachSort by, Coach coach) {
    switch (by) {
      case CoachSort.email:
        return (coach.email ?? '').trim().isEmpty;
      case CoachSort.sport:
        return (coach.sportName ?? '').trim().isEmpty;
      case CoachSort.complex:
        return (coach.sportComplexName ?? '').trim().isEmpty;
      case CoachSort.ground:
        return (coach.ground ?? '').trim().isEmpty;
      case CoachSort.experience:
        return (coach.experience ?? '').trim().isEmpty;
      case CoachSort.price:
        return coach.price == null;
      case CoachSort.availability:
        return coach.availability.isEmpty;
      case CoachSort.name:
      case CoachSort.status:
        return false;
    }
  }

  /// The current page of [visibleRows].
  List<Coach> get pageRows {
    final rows = visibleRows;
    if (rows.isEmpty) return const [];

    final start = (_page - 1) * _limit;
    if (start >= rows.length) return const [];
    final end = (start + _limit).clamp(0, rows.length);
    return rows.sublist(start, end);
  }

  /// Shaped for [PaginationBar], which is shared with the server-paged modules.
  Paged<Coach> get page {
    final total = visibleRows.length;
    return Paged<Coach>(
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

    AdminLog.state(
      'Coaches loading → status=${_statusFilter?.slug ?? '-'} '
      'sport=${_sportFilter ?? '-'} search="${_appliedSearch.trim()}" '
      'complex=${_complexFilter ?? '-'} '
      'category=${_categoryFilter?.slug ?? '-'} sort=${_sort?.name ?? '-'}',
    );

    _state = ViewState.loading;
    _error = null;
    _safeNotify();

    try {
      final result = await _repository.fetchCoaches(
        status: _statusFilter,
        sportId: _sportFilter,
      );

      if (_disposed || id != _requestId) {
        AdminLog.state('Coaches response superseded — dropped');
        return;
      }

      _rows = result;
      _state = ViewState.ready;
      _clampPage();
      AdminLog.state('Coaches ready → ${result.length} rows');
    } on ApiException catch (error) {
      if (_disposed || id != _requestId) return;
      _state = ViewState.failed;
      _error = error.message;
      AdminLog.failure('Coaches load failed: ${error.message}', error: error);
    } catch (error, stackTrace) {
      if (_disposed || id != _requestId) return;
      _state = ViewState.failed;
      _error = 'Could not load coaches. Please try again.';
      AdminLog.failure(
        'Coaches load crashed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _safeNotify();
    }
  }

  Future<void> refresh() {
    AdminLog.ui('Coaches refresh requested');
    return load();
  }

  /// Loads the sport list used by the form and the sport filter.
  Future<void> loadSports({bool refresh = false}) async {
    if (_sportsState.isLoading) return;
    if (_sports.isNotEmpty && !refresh) return;

    AdminLog.state('Coach sport list loading (refresh: $refresh)');
    _sportsState = ViewState.loading;
    _safeNotify();

    try {
      final result = await _repository.fetchSports(refresh: refresh);
      if (_disposed) return;
      _sports = result;
      _sportsState = ViewState.ready;
      AdminLog.state('Coach sport list ready → ${result.length}');
    } catch (error, stackTrace) {
      if (_disposed) return;
      _sportsState = ViewState.failed;
      AdminLog.failure(
        'Coach sport list failed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _safeNotify();
    }
  }

  /// Loads the venue list used by the form and the complex filter.
  Future<void> loadComplexes({bool refresh = false}) async {
    if (_complexesState.isLoading) return;
    if (_complexes.isNotEmpty && !refresh) return;

    AdminLog.state('Coach venue list loading (refresh: $refresh)');
    _complexesState = ViewState.loading;
    _safeNotify();

    try {
      final result = await _repository.fetchSportComplexes(refresh: refresh);
      if (_disposed) return;
      _complexes = result;
      _complexesState = ViewState.ready;
      AdminLog.state('Coach venue list ready → ${result.length}');
    } catch (error, stackTrace) {
      if (_disposed) return;
      _complexesState = ViewState.failed;
      AdminLog.failure(
        'Coach venue list failed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _safeNotify();
    }
  }

  // --- Search, filters, paging ----------------------------------------------

  /// Debounced, though the filtering is local: re-deriving and re-sorting the
  /// whole list on every keystroke is the cost being avoided here, not a round
  /// trip.
  void onSearchChanged(String value) {
    if (_search == value) return;
    _search = value;
    AdminLog.ui('Coach search typed: "$value"');
    notifyListeners();

    _debounce?.cancel();
    _debounce = Timer(searchDebounce, () {
      if (_disposed) return;
      AdminLog.ui('Coach search settled: "${_search.trim()}"');
      _appliedSearch = _search;
      _page = 1;
      _safeNotify();
    });
  }

  void clearSearch() {
    if (_search.isEmpty && _appliedSearch.isEmpty) return;
    AdminLog.ui('Coach search cleared');
    _debounce?.cancel();
    _search = '';
    _appliedSearch = '';
    _page = 1;
    _safeNotify();
  }

  /// Server-side — `/coaches` takes `status`, so this refetches. It is also
  /// re-applied locally, because the sport route ignores it.
  void setStatusFilter(AdminUserStatus? status) {
    if (_statusFilter == status) return;
    AdminLog.ui('Coach status filter → ${status?.slug ?? 'All'}');
    _statusFilter = status;
    _page = 1;
    load();
  }

  /// Server-side — picking a sport switches the whole read to
  /// `/coaches/sport/{sportId}`.
  void setSportFilter(int? sportId) {
    if (_sportFilter == sportId) return;
    AdminLog.ui('Coach sport filter → ${sportId ?? 'All'}');
    _sportFilter = sportId;
    _page = 1;
    load();
  }

  /// Local — neither coach route takes a complex parameter.
  void setComplexFilter(int? complexId) {
    if (_complexFilter == complexId) return;
    AdminLog.ui('Coach complex filter → ${complexId ?? 'All'}');
    _complexFilter = complexId;
    _page = 1;
    _safeNotify();
  }

  void setCategoryFilter(SportCategory? category) {
    if (_categoryFilter == category) return;
    AdminLog.ui('Coach category filter → ${category?.slug ?? 'All'}');
    _categoryFilter = category;
    _page = 1;
    _safeNotify();
  }

  void clearFilters() {
    if (!hasFilters) return;
    AdminLog.ui('All coach filters cleared');
    _debounce?.cancel();

    // Only the two server-side filters need a refetch; the rest were local.
    final needsReload = _statusFilter != null || _sportFilter != null;

    _search = '';
    _appliedSearch = '';
    _statusFilter = null;
    _sportFilter = null;
    _complexFilter = null;
    _categoryFilter = null;
    _page = 1;

    if (needsReload) {
      load();
    } else {
      _safeNotify();
    }
  }

  void setLimit(int limit) {
    if (_limit == limit) return;
    AdminLog.ui('Coach page size → $limit');
    _limit = limit;
    _page = 1;
    _safeNotify();
  }

  /// Same column twice flips direction; a third tap restores the API's order.
  void toggleSort(CoachSort column) {
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
      'Coach sort → ${_sort?.name ?? 'default'}'
      '${_sort == null ? '' : (_descending ? ' desc' : ' asc')}',
    );
    _page = 1;
    _safeNotify();
  }

  void goToPage(int target) {
    final total = page.effectiveTotalPages;
    final next = total > 0 ? target.clamp(1, total) : 1;
    if (next == _page) return;
    AdminLog.ui('Coaches go to page $next');
    _page = next;
    _safeNotify();
  }

  void _clampPage() {
    final total = page.effectiveTotalPages;
    if (total > 0 && _page > total) _page = total;
    if (_page < 1) _page = 1;
  }

  // --- Detail ----------------------------------------------------------------

  /// Shows the row already in hand, then fills in from the detail and stats
  /// routes. The two are awaited together so the drawer settles in one step.
  Future<void> openCoach(Coach coach) async {
    AdminLog.ui('Coach detail opened for ${coach.id}');
    _selected = coach;
    _detailState = ViewState.loading;
    _detailError = null;
    _stats = null;
    _statsState = ViewState.loading;
    _safeNotify();

    await Future.wait([_loadDetail(coach), _loadStats(coach.id)]);
  }

  /// `GET /coaches/{id}`. A failure here is recorded but never blanks the
  /// drawer: that route is not part of the documented module, and the list row
  /// already carries every column the table showed.
  Future<void> _loadDetail(Coach coach) async {
    try {
      final detail = await _repository.fetchCoach(coach.id);
      if (_disposed || _selected?.id != coach.id) return;

      _selected = coach.mergedWith(detail);
      _detailState = ViewState.ready;
      _detailError = null;
      AdminLog.state('Coach detail ready for ${coach.id}');
    } on ApiException catch (error) {
      if (_disposed || _selected?.id != coach.id) return;
      _detailState = ViewState.ready;
      _detailError = error.message;
      AdminLog.failure('Coach detail failed: ${error.message}', error: error);
    } catch (error, stackTrace) {
      if (_disposed || _selected?.id != coach.id) return;
      _detailState = ViewState.ready;
      _detailError = 'Could not load the full record for this coach.';
      AdminLog.failure(
        'Coach detail crashed',
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
      AdminLog.state('Coach stats ready for $id');
    } catch (error) {
      if (_disposed || _selected?.id != id) return;
      _statsState = ViewState.failed;
      // Not surfaced as a drawer error: the rest of the detail is still good.
      AdminLog.failure('Coach stats unavailable for $id', error: error);
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

  void closeCoach() {
    if (_selected == null) return;
    AdminLog.ui('Coach detail closed');
    _selected = null;
    _detailState = ViewState.idle;
    _detailError = null;
    _stats = null;
    _statsState = ViewState.idle;
    _safeNotify();
  }

  // --- Writes ----------------------------------------------------------------

  Future<Coach> create(CoachDraft draft) async {
    AdminLog.ui('Create coach submitted');
    final created = await _repository.createCoach(draft);
    _page = 1;
    await load();
    return created;
  }

  Future<Coach> update(int id, CoachDraft draft) async {
    AdminLog.ui('Update coach $id submitted');
    final updated = await _repository.updateCoach(id, draft);

    if (_selected?.id == id) {
      _selected = _selected!.mergedWith(updated);
      _safeNotify();
    }

    await load();
    return updated;
  }

  Future<void> delete(int id) async {
    AdminLog.ui('Delete coach $id confirmed');

    // Optimistic: the row disappears immediately, and is put back if the call
    // fails, so a failed delete never silently loses a row from the table.
    final previous = _rows;

    _rows = _rows.where((coach) => coach.id != id).toList();
    if (_selected?.id == id) closeCoach();
    _clampPage();
    _safeNotify();

    try {
      await _repository.deleteCoach(id);
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

  /// There is no `/coaches/{id}/status` route, so a status change is a `PUT`
  /// of that one field. The row flips first so the badge repaints instantly,
  /// and is reverted if the server refuses.
  Future<void> setStatus(int id, AdminUserStatus status) async {
    final current = _rowFor(id);
    if (current == null || current.status == status) return;

    AdminLog.ui('Coach $id status → ${status.slug}');
    _busyRows.add(id);
    _replaceRow(id, current.copyWith(statusRaw: status.slug));
    _safeNotify();

    try {
      await _repository.updateCoach(id, CoachDraft(status: status));
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

  Coach? _rowFor(int id) {
    for (final coach in _rows) {
      if (coach.id == id) return coach;
    }
    return _selected?.id == id ? _selected : null;
  }

  /// Applies a row change everywhere it is held, so the table, the summary
  /// cards and an open drawer can never disagree.
  void _replaceRow(int id, Coach next) {
    _rows = _rows
        .map((coach) => coach.id == id ? next : coach)
        .toList(growable: false);
    if (_selected?.id == id) _selected = next;
  }

  // --- Passwords -------------------------------------------------------------
  //
  // Credentials are returned to the caller and never held on this controller:
  // the dialog owns them for as long as it is open, and they go with it.

  Future<CoachCredentials> fetchCredentials(int id) {
    AdminLog.ui('View password requested for coach $id');
    return _repository.fetchCredentials(id);
  }

  Future<void> resetPassword(int id, String password) {
    AdminLog.ui('Password reset submitted for coach $id');
    return _repository.resetPassword(id, password);
  }

  // --- Images ----------------------------------------------------------------
  //
  // Owned by the controller rather than the dialog so an upload survives the
  // dialog rebuilding, and so the route goes through one logged path.

  Future<String> uploadImage(String filePath, {String? filename}) {
    AdminLog.ui('Coach image upload started');
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
    AdminLog.life('CoachesController disposed');
    super.dispose();
  }
}
