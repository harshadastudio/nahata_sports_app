import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../models/sports_complex_model.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/admin_role.dart';
import '../../domain/entities/paged.dart';
import '../../domain/entities/sport.dart';
import '../../domain/repositories/sport_repository.dart';
import 'view_state.dart';

/// The columns the sports table can be ordered by.
///
/// These carry no wire value: `/sports` is unpaginated and has no `sortBy`, so
/// ordering happens here over the rows the server returned.
enum SportSort {
  name('Sport name'),
  complex('Sports complex'),
  category('Category'),
  members('Allowed members'),
  programs('Programs'),
  courts('Courts'),
  status('Status'),
  visibility('Show on frontend');

  const SportSort(this.label);

  final String label;
}

/// The seven summary figures above the table.
///
/// There is no catalogue-wide statistics endpoint, so these are counted from
/// the rows `/sports` returned for the current complex and status — never a
/// second request, and never a fabricated number. They deliberately ignore the
/// local filters (search, category, visibility): those narrow what is *shown*,
/// while these describe what the server sent.
class SportsSummary {
  const SportsSummary({
    this.total = 0,
    this.active = 0,
    this.indoor = 0,
    this.outdoor = 0,
    this.onFrontend = 0,
    this.programs = 0,
    this.courts = 0,
  });

  final int total;
  final int active;
  final int indoor;
  final int outdoor;

  /// Explicitly `showOnFrontend == true`. A sport whose payload omitted the key
  /// is not counted — that would be a guess.
  final int onFrontend;

  final int programs;
  final int courts;

  static SportsSummary from(List<Sport> sports) {
    var active = 0;
    var indoor = 0;
    var outdoor = 0;
    var onFrontend = 0;
    var programs = 0;
    var courts = 0;

    for (final sport in sports) {
      if (sport.isActive) active++;
      if (sport.isIndoor) indoor++;
      if (sport.isOutdoor) outdoor++;
      if (sport.showOnFrontend == true) onFrontend++;
      programs += sport.programCount ?? 0;
      courts += sport.courtCount ?? 0;
    }

    return SportsSummary(
      total: sports.length,
      active: active,
      indoor: indoor,
      outdoor: outdoor,
      onFrontend: onFrontend,
      programs: programs,
      courts: courts,
    );
  }
}

/// Everything the Sports page needs.
///
/// Status and the sports complex are asked of the server — they are the two
/// parameters `/sports` accepts. Search, category, frontend visibility, sorting
/// and paging are applied here over the returned rows.
class SportsController extends ChangeNotifier {
  SportsController(this._repository) {
    AdminLog.life('SportsController created');
  }

  final SportRepository _repository;

  static const Duration searchDebounce = Duration(milliseconds: 300);
  static const List<int> pageSizes = [10, 20, 50, 100];

  ViewState _state = ViewState.idle;
  String? _error;

  List<Sport> _rows = const [];

  String _search = '';
  String _appliedSearch = '';

  // Server-side.
  AdminUserStatus? _statusFilter;
  int? _complexFilter;

  // Local.
  SportCategory? _categoryFilter;
  bool? _visibilityFilter;

  SportSort? _sort;
  bool _descending = false;

  int _page = 1;
  int _limit = 20;

  Timer? _debounce;
  int _requestId = 0;
  bool _disposed = false;

  // Detail drawer.
  Sport? _selected;
  ViewState _detailState = ViewState.idle;
  String? _detailError;

  // Stats are loaded beside the detail but tracked separately: a stats failure
  // must not blank a drawer whose detail arrived fine.
  SportStats? _stats;
  ViewState _statsState = ViewState.idle;

  // Venue list for the form, the complex filter and the assign dialog.
  List<SportsComplex> _complexes = const [];
  ViewState _complexesState = ViewState.idle;

  /// Ids with a status, visibility or assignment write in flight, so the row
  /// can disable just that control instead of the whole table.
  final Set<int> _busyRows = <int>{};

  // --- Reads -----------------------------------------------------------------

  ViewState get state => _state;
  String? get error => _error;

  List<Sport> get rows => _rows;
  SportsSummary get summary => SportsSummary.from(_rows);

  String get search => _search;
  AdminUserStatus? get statusFilter => _statusFilter;
  int? get complexFilter => _complexFilter;
  SportCategory? get categoryFilter => _categoryFilter;
  bool? get visibilityFilter => _visibilityFilter;

  SportSort? get sort => _sort;
  bool get descending => _descending;
  int get limit => _limit;

  Sport? get selected => _selected;
  ViewState get detailState => _detailState;
  String? get detailError => _detailError;
  SportStats? get stats => _stats;
  ViewState get statsState => _statsState;

  List<SportsComplex> get complexes => _complexes;
  ViewState get complexesState => _complexesState;

  bool isRowBusy(int id) => _busyRows.contains(id);

  /// The venue behind [complexFilter], for the filter chip's label.
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
      _categoryFilter != null ||
      _visibilityFilter != null;

  /// How many dropdown filters are set — drives the badge on the Filter button.
  /// Search is excluded; it has its own visible box.
  int get activeFilterCount => [
    _statusFilter,
    _complexFilter,
    _categoryFilter,
    _visibilityFilter,
  ].where((filter) => filter != null).length;

  bool get isFirstLoad => _state.isLoading && _rows.isEmpty;
  bool get isRefreshing => _state.isLoading && _rows.isNotEmpty;

  /// Every row that survives the local filters, in the requested order.
  List<Sport> get visibleRows {
    final query = _appliedSearch.trim().toLowerCase();

    final filtered = _rows.where((sport) {
      // The spec makes only the name searchable.
      if (query.isNotEmpty &&
          !sport.displayName.toLowerCase().contains(query)) {
        return false;
      }

      if (_categoryFilter != null && sport.category != _categoryFilter) {
        return false;
      }

      if (_visibilityFilter != null &&
          sport.showOnFrontend != _visibilityFilter) {
        return false;
      }

      // The list route has already applied these two; re-checking keeps the
      // table honest if a backend ignores one of its own query parameters.
      if (_statusFilter != null && sport.status != _statusFilter) return false;
      if (_complexFilter != null && sport.sportComplexId != _complexFilter) {
        return false;
      }

      return true;
    }).toList();

    _sortRows(filtered);
    return filtered;
  }

  void _sortRows(List<Sport> rows) {
    final by = _sort;
    if (by == null) return;

    int compare(Sport a, Sport b) {
      switch (by) {
        case SportSort.name:
          return a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          );
        case SportSort.complex:
          return (a.sportComplexName ?? '').toLowerCase().compareTo(
            (b.sportComplexName ?? '').toLowerCase(),
          );
        case SportSort.category:
          return a.categoryLabel.compareTo(b.categoryLabel);
        case SportSort.members:
          return (a.allowedMembers ?? 0).compareTo(b.allowedMembers ?? 0);
        case SportSort.programs:
          return (a.programCount ?? 0).compareTo(b.programCount ?? 0);
        case SportSort.courts:
          return (a.courtCount ?? 0).compareTo(b.courtCount ?? 0);
        case SportSort.status:
          return a.statusLabel.compareTo(b.statusLabel);
        case SportSort.visibility:
          // Shown before hidden, so the storefront-visible sports lead.
          final first = a.showOnFrontend == true ? 0 : 1;
          final second = b.showOnFrontend == true ? 0 : 1;
          return first.compareTo(second);
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

  static bool _isMissing(SportSort by, Sport sport) {
    switch (by) {
      case SportSort.complex:
        return (sport.sportComplexName ?? '').trim().isEmpty;
      case SportSort.category:
        return (sport.categoryRaw ?? '').trim().isEmpty;
      case SportSort.members:
        return sport.allowedMembers == null;
      case SportSort.programs:
        return sport.programCount == null;
      case SportSort.courts:
        return sport.courtCount == null;
      case SportSort.visibility:
        return sport.showOnFrontend == null;
      case SportSort.name:
      case SportSort.status:
        return false;
    }
  }

  /// The current page of [visibleRows].
  List<Sport> get pageRows {
    final rows = visibleRows;
    if (rows.isEmpty) return const [];

    final start = (_page - 1) * _limit;
    if (start >= rows.length) return const [];
    final end = (start + _limit).clamp(0, rows.length);
    return rows.sublist(start, end);
  }

  /// Shaped for [PaginationBar], which is shared with the server-paged modules.
  Paged<Sport> get page {
    final total = visibleRows.length;
    return Paged<Sport>(
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
      'Sports loading → status=${_statusFilter?.slug ?? '-'} '
      'complex=${_complexFilter ?? '-'} search="${_appliedSearch.trim()}" '
      'category=${_categoryFilter?.slug ?? '-'} '
      'frontend=${_visibilityFilter ?? '-'} sort=${_sort?.name ?? '-'}',
    );

    _state = ViewState.loading;
    _error = null;
    _safeNotify();

    try {
      final result = await _repository.fetchSports(
        status: _statusFilter,
        complexId: _complexFilter,
      );

      if (_disposed || id != _requestId) {
        AdminLog.state('Sports response superseded — dropped');
        return;
      }

      _rows = result;
      _state = ViewState.ready;
      _clampPage();
      AdminLog.state('Sports ready → ${result.length} rows');
    } on ApiException catch (error) {
      if (_disposed || id != _requestId) return;
      _state = ViewState.failed;
      _error = error.message;
      AdminLog.failure('Sports load failed: ${error.message}', error: error);
    } catch (error, stackTrace) {
      if (_disposed || id != _requestId) return;
      _state = ViewState.failed;
      _error = 'Could not load sports. Please try again.';
      AdminLog.failure(
        'Sports load crashed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _safeNotify();
    }
  }

  Future<void> refresh() {
    AdminLog.ui('Sports refresh requested');
    return load();
  }

  /// Loads the venue list used by the form, the complex filter and the assign
  /// dialog.
  Future<void> loadComplexes({bool refresh = false}) async {
    if (_complexesState.isLoading) return;
    if (_complexes.isNotEmpty && !refresh) return;

    AdminLog.state('Sports venue list loading (refresh: $refresh)');
    _complexesState = ViewState.loading;
    _safeNotify();

    try {
      final result = await _repository.fetchSportComplexes(refresh: refresh);
      if (_disposed) return;
      _complexes = result;
      _complexesState = ViewState.ready;
      AdminLog.state('Sports venue list ready → ${result.length}');
    } catch (error, stackTrace) {
      if (_disposed) return;
      _complexesState = ViewState.failed;
      AdminLog.failure(
        'Sports venue list failed',
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
    AdminLog.ui('Sport search typed: "$value"');
    notifyListeners();

    _debounce?.cancel();
    _debounce = Timer(searchDebounce, () {
      if (_disposed) return;
      AdminLog.ui('Sport search settled: "${_search.trim()}"');
      _appliedSearch = _search;
      _page = 1;
      _safeNotify();
    });
  }

  void clearSearch() {
    if (_search.isEmpty && _appliedSearch.isEmpty) return;
    AdminLog.ui('Sport search cleared');
    _debounce?.cancel();
    _search = '';
    _appliedSearch = '';
    _page = 1;
    _safeNotify();
  }

  /// Server-side — `/sports` takes `status`, so this refetches.
  void setStatusFilter(AdminUserStatus? status) {
    if (_statusFilter == status) return;
    AdminLog.ui('Sport status filter → ${status?.slug ?? 'All'}');
    _statusFilter = status;
    _page = 1;
    load();
  }

  /// Server-side — `/sports` takes `sportComplexId`, and the spec makes the
  /// complex the module's primary filter.
  void setComplexFilter(int? complexId) {
    if (_complexFilter == complexId) return;
    AdminLog.ui('Sport complex filter → ${complexId ?? 'All'}');
    _complexFilter = complexId;
    _page = 1;
    load();
  }

  /// Local — the route takes no category parameter.
  void setCategoryFilter(SportCategory? category) {
    if (_categoryFilter == category) return;
    AdminLog.ui('Sport category filter → ${category?.slug ?? 'All'}');
    _categoryFilter = category;
    _page = 1;
    _safeNotify();
  }

  void setVisibilityFilter(bool? showOnFrontend) {
    if (_visibilityFilter == showOnFrontend) return;
    AdminLog.ui('Sport frontend filter → ${showOnFrontend ?? 'All'}');
    _visibilityFilter = showOnFrontend;
    _page = 1;
    _safeNotify();
  }

  void clearFilters() {
    if (!hasFilters) return;
    AdminLog.ui('All sport filters cleared');
    _debounce?.cancel();

    // Only the two server-side filters need a refetch; the rest were local.
    final needsReload = _statusFilter != null || _complexFilter != null;

    _search = '';
    _appliedSearch = '';
    _statusFilter = null;
    _complexFilter = null;
    _categoryFilter = null;
    _visibilityFilter = null;
    _page = 1;

    if (needsReload) {
      load();
    } else {
      _safeNotify();
    }
  }

  void setLimit(int limit) {
    if (_limit == limit) return;
    AdminLog.ui('Sport page size → $limit');
    _limit = limit;
    _page = 1;
    _safeNotify();
  }

  /// Same column twice flips direction; a third tap restores the API's order.
  void toggleSort(SportSort column) {
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
      'Sport sort → ${_sort?.name ?? 'default'}'
      '${_sort == null ? '' : (_descending ? ' desc' : ' asc')}',
    );
    _page = 1;
    _safeNotify();
  }

  void goToPage(int target) {
    final total = page.effectiveTotalPages;
    final next = total > 0 ? target.clamp(1, total) : 1;
    if (next == _page) return;
    AdminLog.ui('Sports go to page $next');
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
  Future<void> openSport(Sport sport) async {
    AdminLog.ui('Sport detail opened for ${sport.id}');
    _selected = sport;
    _detailState = ViewState.loading;
    _detailError = null;
    _stats = null;
    _statsState = ViewState.loading;
    _safeNotify();

    await Future.wait([_loadDetail(sport), _loadStats(sport.id)]);
  }

  Future<void> _loadDetail(Sport sport) async {
    try {
      final detail = await _repository.fetchSport(sport.id);
      if (_disposed || _selected?.id != sport.id) return;

      _selected = sport.mergedWith(detail);
      _detailState = ViewState.ready;
      AdminLog.state('Sport detail ready for ${sport.id}');
    } on ApiException catch (error) {
      if (_disposed || _selected?.id != sport.id) return;
      _detailState = ViewState.failed;
      _detailError = error.message;
      AdminLog.failure('Sport detail failed: ${error.message}', error: error);
    } catch (error, stackTrace) {
      if (_disposed || _selected?.id != sport.id) return;
      _detailState = ViewState.failed;
      _detailError = 'Could not load this sport.';
      AdminLog.failure(
        'Sport detail crashed',
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
      AdminLog.state('Sport stats ready for $id');
    } catch (error) {
      if (_disposed || _selected?.id != id) return;
      _statsState = ViewState.failed;
      // Not surfaced as a drawer error: the rest of the detail is still good.
      AdminLog.failure('Sport stats unavailable for $id', error: error);
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

  void closeSport() {
    if (_selected == null) return;
    AdminLog.ui('Sport detail closed');
    _selected = null;
    _detailState = ViewState.idle;
    _detailError = null;
    _stats = null;
    _statsState = ViewState.idle;
    _safeNotify();
  }

  // --- Writes ----------------------------------------------------------------

  Future<Sport> create(SportDraft draft) async {
    AdminLog.ui('Create sport submitted');
    final created = await _repository.createSport(draft);
    _page = 1;
    await load();
    return created;
  }

  Future<Sport> update(int id, SportDraft draft) async {
    AdminLog.ui('Update sport $id submitted');
    final updated = await _repository.updateSport(id, draft);

    if (_selected?.id == id) {
      _selected = _selected!.mergedWith(updated);
      _safeNotify();
    }

    await load();
    return updated;
  }

  Future<void> delete(int id) async {
    AdminLog.ui('Delete sport $id confirmed');

    // Optimistic: the row disappears immediately, and is put back if the call
    // fails, so a failed delete never silently loses a row from the table.
    final previous = _rows;

    _rows = _rows.where((sport) => sport.id != id).toList();
    if (_selected?.id == id) closeSport();
    _clampPage();
    _safeNotify();

    try {
      await _repository.deleteSport(id);
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

    AdminLog.ui('Sport $id status → ${status.slug}');
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

  /// `PATCH /{id}/show-on-frontend`, same optimistic treatment as the status.
  Future<void> setVisibility(int id, bool showOnFrontend) async {
    final current = _rowFor(id);
    if (current == null) return;

    AdminLog.ui('Sport $id showOnFrontend → $showOnFrontend');
    _busyRows.add(id);
    _replaceRow(id, current.copyWith(showOnFrontend: showOnFrontend));
    _safeNotify();

    try {
      await _repository.setVisibility(id, showOnFrontend);
    } catch (error) {
      if (!_disposed) {
        AdminLog.failure('Visibility toggle rejected — reverting', error: error);
        _replaceRow(id, current);
      }
      rethrow;
    } finally {
      _busyRows.remove(id);
      _safeNotify();
    }
  }

  /// `POST /{id}/assign-ground`.
  ///
  /// The row moves complex immediately, carrying the picked venue's name so the
  /// table does not show a stale one while the reload is in flight.
  Future<void> assignComplex(int id, int complexId) async {
    final current = _rowFor(id);
    if (current == null) return;

    AdminLog.ui('Sport $id assign → complex $complexId');
    _busyRows.add(id);
    _replaceRow(
      id,
      current.copyWith(
        sportComplexId: complexId,
        sportComplexName: complexById(complexId)?.name,
      ),
    );
    _safeNotify();

    try {
      await _repository.assignComplex(id, complexId);
    } catch (error) {
      if (!_disposed) {
        AdminLog.failure('Assignment rejected — reverting', error: error);
        _replaceRow(id, current);
      }
      rethrow;
    } finally {
      _busyRows.remove(id);
      _safeNotify();
    }

    // A sport moved out of the complex being filtered on should leave the
    // table, so the list is reconciled with the server.
    await load();
  }

  Sport? _rowFor(int id) {
    for (final sport in _rows) {
      if (sport.id == id) return sport;
    }
    return _selected?.id == id ? _selected : null;
  }

  /// Applies a row change everywhere it is held, so the table, the summary
  /// cards and an open drawer can never disagree.
  void _replaceRow(int id, Sport next) {
    _rows = _rows
        .map((sport) => sport.id == id ? next : sport)
        .toList(growable: false);
    if (_selected?.id == id) _selected = next;
  }

  // --- Images ----------------------------------------------------------------
  //
  // Owned by the controller rather than the dialog so an upload survives the
  // dialog rebuilding, and so the route goes through one logged path.

  Future<String> uploadImage(String filePath, {String? filename}) {
    AdminLog.ui('Sport image upload started');
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
    AdminLog.life('SportsController disposed');
    super.dispose();
  }
}
