import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/admin_role.dart';
import '../../domain/entities/admin_sports_complex.dart';
import '../../domain/entities/paged.dart';
import '../../domain/repositories/sports_complex_admin_repository.dart';
import 'view_state.dart';

/// The columns the sports complex table can be ordered by.
///
/// Unlike the staff modules these carry no wire value: `/sports-complexes` is
/// unpaginated and has no `sortBy`, so ordering is done here over the whole
/// catalogue rather than asked of the server.
enum SportsComplexSort {
  name('Complex name'),
  city('City'),
  state('State'),
  status('Status'),
  visibility('Show on frontend'),
  created('Created date');

  const SportsComplexSort(this.label);

  final String label;
}

/// The four summary figures above the table.
///
/// There is no venue-stats endpoint, so these are counted from the catalogue
/// the list route already returned — never a second request, and never a
/// fabricated number.
class SportsComplexSummary {
  const SportsComplexSummary({
    this.total = 0,
    this.active = 0,
    this.hidden = 0,
    this.cities = 0,
  });

  final int total;
  final int active;

  /// Explicitly `showOnFrontend == false`. A venue whose payload omitted the
  /// key is not counted as hidden — that would be a guess.
  final int hidden;

  final int cities;

  static SportsComplexSummary from(List<AdminSportsComplex> complexes) {
    final cities = <String>{};
    var active = 0;
    var hidden = 0;

    for (final complex in complexes) {
      final city = (complex.city ?? '').trim();
      if (city.isNotEmpty) cities.add(city.toLowerCase());
      if (complex.isActive) active++;
      if (complex.showOnFrontend == false) hidden++;
    }

    return SportsComplexSummary(
      total: complexes.length,
      active: active,
      hidden: hidden,
      cities: cities.length,
    );
  }
}

/// Everything the Sports Complexes page needs.
///
/// The list route returns the whole catalogue in one response, so paging,
/// searching and sorting all happen here. The city and state filters are the
/// exception: those have dedicated endpoints and are asked of the server, as
/// the spec requires.
class SportsComplexesController extends ChangeNotifier {
  SportsComplexesController(this._repository) {
    AdminLog.life('SportsComplexesController created');
  }

  final SportsComplexAdminRepository _repository;

  static const Duration searchDebounce = Duration(milliseconds: 300);
  static const List<int> pageSizes = [10, 20, 50, 100];

  ViewState _state = ViewState.idle;
  String? _error;

  /// The last unscoped read. Drives the summary cards and the city/state filter
  /// options, and deliberately survives a city/state scoped read — otherwise
  /// filtering to one city would leave every other city unpickable.
  List<AdminSportsComplex> _catalogue = const [];

  /// The rows currently in play: the catalogue, or a city/state scoped read.
  List<AdminSportsComplex> _rows = const [];

  String _search = '';
  String _appliedSearch = '';

  String? _cityFilter;
  String? _stateFilter;
  AdminUserStatus? _statusFilter;
  bool? _visibilityFilter;

  SportsComplexSort? _sort;
  bool _descending = false;

  int _page = 1;
  int _limit = 20;

  Timer? _debounce;
  int _requestId = 0;
  bool _disposed = false;

  // Detail drawer.
  AdminSportsComplex? _selected;
  ViewState _detailState = ViewState.idle;
  String? _detailError;

  // Stats are loaded beside the detail but tracked separately: a stats failure
  // must not blank a drawer whose detail arrived fine.
  SportsComplexStats? _stats;
  ViewState _statsState = ViewState.idle;

  /// Ids with a status or visibility write in flight, so the row can disable
  /// just that control instead of the whole table.
  final Set<int> _busyRows = <int>{};

  // --- Reads -----------------------------------------------------------------

  ViewState get state => _state;
  String? get error => _error;

  List<AdminSportsComplex> get catalogue => _catalogue;
  SportsComplexSummary get summary => SportsComplexSummary.from(_catalogue);

  String get search => _search;
  String? get cityFilter => _cityFilter;
  String? get stateFilter => _stateFilter;
  AdminUserStatus? get statusFilter => _statusFilter;
  bool? get visibilityFilter => _visibilityFilter;

  SportsComplexSort? get sort => _sort;
  bool get descending => _descending;
  int get limit => _limit;

  AdminSportsComplex? get selected => _selected;
  ViewState get detailState => _detailState;
  String? get detailError => _detailError;
  SportsComplexStats? get stats => _stats;
  ViewState get statsState => _statsState;

  bool isRowBusy(int id) => _busyRows.contains(id);

  /// True when the current read came from a city/state endpoint rather than the
  /// full catalogue.
  bool get isScoped => _cityFilter != null || _stateFilter != null;

  /// Cities present in the catalogue, alphabetically. Learned from the data —
  /// there is no endpoint that enumerates them.
  List<String> get cities => _distinct((complex) => complex.city);

  List<String> get states => _distinct((complex) => complex.state);

  List<String> _distinct(String? Function(AdminSportsComplex) read) {
    final seen = <String, String>{};
    for (final complex in _catalogue) {
      final value = (read(complex) ?? '').trim();
      if (value.isEmpty) continue;
      // Keyed case-insensitively so "Pune" and "pune" are one option, but the
      // first spelling the API used is what gets shown.
      seen.putIfAbsent(value.toLowerCase(), () => value);
    }
    final values = seen.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return List<String>.unmodifiable(values);
  }

  bool get hasFilters =>
      _appliedSearch.trim().isNotEmpty ||
      _cityFilter != null ||
      _stateFilter != null ||
      _statusFilter != null ||
      _visibilityFilter != null;

  /// How many dropdown filters are set — drives the badge on the Filter button.
  /// Search is excluded; it has its own visible box.
  int get activeFilterCount => [
    _cityFilter,
    _stateFilter,
    _statusFilter,
    _visibilityFilter,
  ].where((filter) => filter != null).length;

  bool get isFirstLoad => _state.isLoading && _rows.isEmpty;
  bool get isRefreshing => _state.isLoading && _rows.isNotEmpty;

  /// Every row that survives the filters, in the requested order.
  List<AdminSportsComplex> get visibleRows {
    final query = _appliedSearch.trim().toLowerCase();

    final filtered = _rows.where((complex) {
      if (query.isNotEmpty) {
        // Name, city and state — the three fields the spec makes searchable.
        final haystack = [
          complex.name ?? '',
          complex.city ?? '',
          complex.state ?? '',
        ].join(' ').toLowerCase();
        if (!haystack.contains(query)) return false;
      }

      // The scoping endpoint has already applied whichever of these it covers;
      // re-checking is harmless and keeps a combined city+state filter honest.
      final city = _cityFilter;
      if (city != null &&
          (complex.city ?? '').trim().toLowerCase() != city.toLowerCase()) {
        return false;
      }

      final state = _stateFilter;
      if (state != null &&
          (complex.state ?? '').trim().toLowerCase() != state.toLowerCase()) {
        return false;
      }

      if (_statusFilter != null && complex.status != _statusFilter) return false;

      if (_visibilityFilter != null &&
          complex.showOnFrontend != _visibilityFilter) {
        return false;
      }

      return true;
    }).toList();

    _sortRows(filtered);
    return filtered;
  }

  void _sortRows(List<AdminSportsComplex> rows) {
    final by = _sort;
    if (by == null) return;

    int compare(AdminSportsComplex a, AdminSportsComplex b) {
      switch (by) {
        case SportsComplexSort.name:
          return a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          );
        case SportsComplexSort.city:
          return (a.city ?? '').toLowerCase().compareTo(
            (b.city ?? '').toLowerCase(),
          );
        case SportsComplexSort.state:
          return (a.state ?? '').toLowerCase().compareTo(
            (b.state ?? '').toLowerCase(),
          );
        case SportsComplexSort.status:
          return a.statusLabel.compareTo(b.statusLabel);
        case SportsComplexSort.visibility:
          // Shown before hidden, so the storefront-visible venues lead.
          final first = a.showOnFrontend == true ? 0 : 1;
          final second = b.showOnFrontend == true ? 0 : 1;
          return first.compareTo(second);
        case SportsComplexSort.created:
          final first = a.createdAt;
          final second = b.createdAt;
          if (first == null || second == null) return 0;
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

  static bool _isMissing(SportsComplexSort by, AdminSportsComplex complex) {
    switch (by) {
      case SportsComplexSort.city:
        return (complex.city ?? '').trim().isEmpty;
      case SportsComplexSort.state:
        return (complex.state ?? '').trim().isEmpty;
      case SportsComplexSort.created:
        return complex.createdAt == null;
      case SportsComplexSort.visibility:
        return complex.showOnFrontend == null;
      case SportsComplexSort.name:
      case SportsComplexSort.status:
        return false;
    }
  }

  /// The current page of [visibleRows].
  List<AdminSportsComplex> get pageRows {
    final rows = visibleRows;
    if (rows.isEmpty) return const [];

    final start = (_page - 1) * _limit;
    if (start >= rows.length) return const [];
    final end = (start + _limit).clamp(0, rows.length);
    return rows.sublist(start, end);
  }

  /// Shaped for [PaginationBar], which is shared with the server-paged modules.
  Paged<AdminSportsComplex> get page {
    final total = visibleRows.length;
    return Paged<AdminSportsComplex>(
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
    final city = _cityFilter;
    final state = _stateFilter;

    AdminLog.state(
      'Sports complexes loading → '
      'scope=${city != null ? 'city:$city' : (state != null ? 'state:$state' : 'all')} '
      'search="${_appliedSearch.trim()}" status=${_statusFilter?.slug ?? '-'} '
      'frontend=${_visibilityFilter ?? '-'} sort=${_sort?.name ?? '-'}',
    );

    _state = ViewState.loading;
    _error = null;
    _safeNotify();

    try {
      final List<AdminSportsComplex> rows;
      if (city != null) {
        rows = await _repository.fetchComplexesByCity(city);
      } else if (state != null) {
        rows = await _repository.fetchComplexesByState(state);
      } else {
        rows = await _repository.fetchComplexes();
      }

      if (_disposed || id != _requestId) {
        AdminLog.state('Sports complex response superseded — dropped');
        return;
      }

      _rows = rows;
      // An unscoped read IS the catalogue; a scoped one must not shrink it.
      if (city == null && state == null) _catalogue = rows;

      _state = ViewState.ready;
      _clampPage();
      AdminLog.state('Sports complexes ready → ${rows.length} rows');
    } on ApiException catch (error) {
      if (_disposed || id != _requestId) return;
      _state = ViewState.failed;
      _error = error.message;
      AdminLog.failure(
        'Sports complexes load failed: ${error.message}',
        error: error,
      );
    } catch (error, stackTrace) {
      if (_disposed || id != _requestId) return;
      _state = ViewState.failed;
      _error = 'Could not load sports complexes. Please try again.';
      AdminLog.failure(
        'Sports complexes load crashed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _safeNotify();
    }
  }

  Future<void> refresh() {
    AdminLog.ui('Sports complexes refresh requested');
    return load();
  }

  /// Re-reads the unscoped catalogue without touching the visible rows.
  ///
  /// Needed after a write while a city/state filter is on: the scoped reload
  /// cannot see that the summary cards or the city list have changed.
  Future<void> _syncCatalogue() async {
    if (!isScoped) return;
    try {
      final rows = await _repository.fetchComplexes();
      if (_disposed) return;
      _catalogue = rows;
      _safeNotify();
    } catch (error) {
      // Cosmetic: the cards and filter options go one write stale rather than
      // the whole page reporting an error it already survived.
      AdminLog.failure('Catalogue re-sync failed', error: error);
    }
  }

  Future<void> _reloadAfterWrite() async {
    await load();
    await _syncCatalogue();
  }

  // --- Search, filters, paging ----------------------------------------------

  /// Debounced, though the filtering is local: re-deriving and re-sorting the
  /// whole catalogue on every keystroke is the cost being avoided here, not a
  /// round trip.
  void onSearchChanged(String value) {
    if (_search == value) return;
    _search = value;
    AdminLog.ui('Complex search typed: "$value"');
    notifyListeners();

    _debounce?.cancel();
    _debounce = Timer(searchDebounce, () {
      if (_disposed) return;
      AdminLog.ui('Complex search settled: "${_search.trim()}"');
      _appliedSearch = _search;
      _page = 1;
      _safeNotify();
    });
  }

  void clearSearch() {
    if (_search.isEmpty && _appliedSearch.isEmpty) return;
    AdminLog.ui('Complex search cleared');
    _debounce?.cancel();
    _search = '';
    _appliedSearch = '';
    _page = 1;
    _safeNotify();
  }

  /// Selecting a city switches the read to `/sports-complexes/city/{city}`.
  void setCityFilter(String? city) {
    final next = (city ?? '').trim().isEmpty ? null : city!.trim();
    if (_cityFilter == next) return;
    AdminLog.ui('Complex city filter → ${next ?? 'All'}');
    _cityFilter = next;
    _page = 1;
    load();
  }

  void setStateFilter(String? state) {
    final next = (state ?? '').trim().isEmpty ? null : state!.trim();
    if (_stateFilter == next) return;
    AdminLog.ui('Complex state filter → ${next ?? 'All'}');
    _stateFilter = next;
    _page = 1;
    load();
  }

  /// Local — there is no status-scoped endpoint, so this needs no refetch.
  void setStatusFilter(AdminUserStatus? status) {
    if (_statusFilter == status) return;
    AdminLog.ui('Complex status filter → ${status?.slug ?? 'All'}');
    _statusFilter = status;
    _page = 1;
    _safeNotify();
  }

  void setVisibilityFilter(bool? showOnFrontend) {
    if (_visibilityFilter == showOnFrontend) return;
    AdminLog.ui('Complex frontend filter → ${showOnFrontend ?? 'All'}');
    _visibilityFilter = showOnFrontend;
    _page = 1;
    _safeNotify();
  }

  void clearFilters() {
    if (!hasFilters) return;
    AdminLog.ui('All complex filters cleared');
    _debounce?.cancel();

    final wasScoped = isScoped;
    _search = '';
    _appliedSearch = '';
    _cityFilter = null;
    _stateFilter = null;
    _statusFilter = null;
    _visibilityFilter = null;
    _page = 1;

    // Only a scoped read has to go back to the server; the rest were local.
    if (wasScoped) {
      load();
    } else {
      _safeNotify();
    }
  }

  void setLimit(int limit) {
    if (_limit == limit) return;
    AdminLog.ui('Complex page size → $limit');
    _limit = limit;
    _page = 1;
    _safeNotify();
  }

  /// Same column twice flips direction; a third tap restores the API's order.
  void toggleSort(SportsComplexSort column) {
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
      'Complex sort → ${_sort?.name ?? 'default'}'
      '${_sort == null ? '' : (_descending ? ' desc' : ' asc')}',
    );
    _page = 1;
    _safeNotify();
  }

  void goToPage(int target) {
    final total = page.effectiveTotalPages;
    final next = total > 0 ? target.clamp(1, total) : 1;
    if (next == _page) return;
    AdminLog.ui('Sports complexes go to page $next');
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
  Future<void> openComplex(AdminSportsComplex complex) async {
    AdminLog.ui('Complex detail opened for ${complex.id}');
    _selected = complex;
    _detailState = ViewState.loading;
    _detailError = null;
    _stats = null;
    _statsState = ViewState.loading;
    _safeNotify();

    await Future.wait([_loadDetail(complex), _loadStats(complex.id)]);
  }

  Future<void> _loadDetail(AdminSportsComplex complex) async {
    try {
      final detail = await _repository.fetchComplex(complex.id);
      if (_disposed || _selected?.id != complex.id) return;

      _selected = complex.mergedWith(detail);
      _detailState = ViewState.ready;
      AdminLog.state('Complex detail ready for ${complex.id}');
    } on ApiException catch (error) {
      if (_disposed || _selected?.id != complex.id) return;
      _detailState = ViewState.failed;
      _detailError = error.message;
      AdminLog.failure('Complex detail failed: ${error.message}', error: error);
    } catch (error, stackTrace) {
      if (_disposed || _selected?.id != complex.id) return;
      _detailState = ViewState.failed;
      _detailError = 'Could not load this sports complex.';
      AdminLog.failure(
        'Complex detail crashed',
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
      AdminLog.state('Complex stats ready for $id');
    } catch (error) {
      if (_disposed || _selected?.id != id) return;
      _statsState = ViewState.failed;
      // Not surfaced as a drawer error: the rest of the detail is still good.
      AdminLog.failure('Complex stats unavailable for $id', error: error);
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

  void closeComplex() {
    if (_selected == null) return;
    AdminLog.ui('Complex detail closed');
    _selected = null;
    _detailState = ViewState.idle;
    _detailError = null;
    _stats = null;
    _statsState = ViewState.idle;
    _safeNotify();
  }

  // --- Writes ----------------------------------------------------------------

  Future<AdminSportsComplex> create(SportsComplexDraft draft) async {
    AdminLog.ui('Create sports complex submitted');
    final created = await _repository.createComplex(draft);
    _page = 1;
    await _reloadAfterWrite();
    return created;
  }

  Future<AdminSportsComplex> update(int id, SportsComplexDraft draft) async {
    AdminLog.ui('Update sports complex $id submitted');
    final updated = await _repository.updateComplex(id, draft);

    if (_selected?.id == id) {
      _selected = _selected!.mergedWith(updated);
      _safeNotify();
    }

    await _reloadAfterWrite();
    return updated;
  }

  Future<void> delete(int id) async {
    AdminLog.ui('Delete sports complex $id confirmed');

    // Optimistic: the row disappears immediately, and is put back if the call
    // fails, so a failed delete never silently loses a row from the table.
    final previousRows = _rows;
    final previousCatalogue = _catalogue;

    _rows = _rows.where((complex) => complex.id != id).toList();
    _catalogue = _catalogue.where((complex) => complex.id != id).toList();
    if (_selected?.id == id) closeComplex();
    _clampPage();
    _safeNotify();

    try {
      await _repository.deleteComplex(id);
    } catch (error) {
      if (!_disposed) {
        AdminLog.failure('Delete failed — restoring the row', error: error);
        _rows = previousRows;
        _catalogue = previousCatalogue;
        _safeNotify();
      }
      rethrow;
    }

    await _reloadAfterWrite();
  }

  /// `PUT /{id}/status`, applied to the row before the call so the badge flips
  /// instantly; reverted if the server refuses.
  Future<void> setStatus(int id, AdminUserStatus status) async {
    final current = _rowFor(id);
    if (current == null) return;
    if (current.status == status) return;

    AdminLog.ui('Complex $id status → ${status.slug}');
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

  /// `PUT /{id}/show-on-frontend`, same optimistic treatment as the status.
  Future<void> setVisibility(int id, bool showOnFrontend) async {
    final current = _rowFor(id);
    if (current == null) return;

    AdminLog.ui('Complex $id showOnFrontend → $showOnFrontend');
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

  AdminSportsComplex? _rowFor(int id) {
    for (final complex in _rows) {
      if (complex.id == id) return complex;
    }
    for (final complex in _catalogue) {
      if (complex.id == id) return complex;
    }
    return null;
  }

  /// Applies a row change everywhere it is held, so the table, the summary
  /// cards and an open drawer can never disagree.
  void _replaceRow(int id, AdminSportsComplex next) {
    List<AdminSportsComplex> swap(List<AdminSportsComplex> source) => source
        .map((complex) => complex.id == id ? next : complex)
        .toList(growable: false);

    _rows = swap(_rows);
    _catalogue = swap(_catalogue);
    if (_selected?.id == id) _selected = next;
  }

  // --- Images ----------------------------------------------------------------
  //
  // Owned by the controller rather than the dialog so an upload survives the
  // dialog rebuilding, and so both routes go through one logged path.

  Future<String> uploadImage(String filePath, {String? filename}) {
    AdminLog.ui('Complex image upload started');
    return _repository.uploadImage(filePath, filename: filename);
  }

  Future<void> deleteImage(String imageUrl) {
    AdminLog.ui('Complex image delete requested');
    return _repository.deleteImage(imageUrl);
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    AdminLog.life('SportsComplexesController disposed');
    super.dispose();
  }
}
