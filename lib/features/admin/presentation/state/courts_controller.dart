import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../models/sports_complex_model.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/admin_role.dart';
import '../../domain/entities/court.dart';
import '../../domain/entities/paged.dart';
import '../../domain/entities/sport.dart';
import '../../domain/repositories/court_repository.dart';
import 'view_state.dart';

/// The columns the courts table can be ordered by.
///
/// These carry no wire value: `/courts` is unpaginated and has no `sortBy`, so
/// ordering happens here over the rows the server returned.
enum CourtSort {
  name('Court name'),
  sport('Sport'),
  complex('Sports complex'),
  surface('Surface type'),
  capacity('Capacity'),
  rate('Hourly rate'),
  status('Status'),
  visibility('Show on frontend');

  const CourtSort(this.label);

  final String label;
}

/// The six summary figures above the table.
///
/// There is no catalogue-wide statistics endpoint, so these are counted from
/// the rows `/courts` returned for the current complex and sport — never a
/// second request, and never a fabricated number. They deliberately ignore the
/// local filters: those narrow what is *shown*, while these describe what the
/// server sent.
class CourtsSummary {
  const CourtsSummary({
    this.total = 0,
    this.active = 0,
    this.onFrontend = 0,
    this.hidden = 0,
    this.slots,
    this.availableSlots,
  });

  final int total;
  final int active;

  /// Explicitly `showOnFrontend == true`. A court whose payload omitted the key
  /// is counted in neither this nor [hidden] — that would be a guess.
  final int onFrontend;
  final int hidden;

  /// Null when not one row carried a slot counter: the list route does not
  /// promise them, and a zero would claim an empty schedule the API never
  /// described.
  final int? slots;
  final int? availableSlots;

  static CourtsSummary from(List<Court> courts) {
    var active = 0;
    var onFrontend = 0;
    var hidden = 0;

    var slots = 0;
    var slotsKnown = false;
    var free = 0;
    var freeKnown = false;

    for (final court in courts) {
      if (court.isActive) active++;
      if (court.showOnFrontend == true) onFrontend++;
      if (court.showOnFrontend == false) hidden++;

      final count = court.slotCount;
      if (count != null) {
        slotsKnown = true;
        slots += count;
      }

      final available = court.availableSlotCount;
      if (available != null) {
        freeKnown = true;
        free += available;
      }
    }

    return CourtsSummary(
      total: courts.length,
      active: active,
      onFrontend: onFrontend,
      hidden: hidden,
      slots: slotsKnown ? slots : null,
      availableSlots: freeKnown ? free : null,
    );
  }
}

/// Everything the Courts page needs.
///
/// The complex and the sport are asked of the server — they are the two
/// parameters `/courts` accepts. Search, status, surface type, frontend
/// visibility, sorting and paging are applied here over the returned rows.
class CourtsController extends ChangeNotifier {
  CourtsController(this._repository) {
    AdminLog.life('CourtsController created');
  }

  final CourtRepository _repository;

  static const Duration searchDebounce = Duration(milliseconds: 300);
  static const List<int> pageSizes = [10, 20, 50, 100];

  ViewState _state = ViewState.idle;
  String? _error;

  List<Court> _rows = const [];

  String _search = '';
  String _appliedSearch = '';

  // Server-side.
  int? _complexFilter;
  int? _sportFilter;

  // Local.
  AdminUserStatus? _statusFilter;
  String? _surfaceFilter;
  bool? _visibilityFilter;

  CourtSort? _sort;
  bool _descending = false;

  int _page = 1;
  int _limit = 20;

  Timer? _debounce;
  int _requestId = 0;
  bool _disposed = false;

  // Detail drawer.
  Court? _selected;
  ViewState _detailState = ViewState.idle;
  String? _detailError;

  // Dropdown catalogues.
  List<Sport> _sports = const [];
  ViewState _sportsState = ViewState.idle;

  List<SportsComplex> _complexes = const [];
  ViewState _complexesState = ViewState.idle;

  /// Ids with a status or visibility write in flight, so the row can disable
  /// just that control instead of the whole table.
  final Set<int> _busyRows = <int>{};

  // --- Reads -----------------------------------------------------------------

  ViewState get state => _state;
  String? get error => _error;

  List<Court> get rows => _rows;
  CourtsSummary get summary => CourtsSummary.from(_rows);

  String get search => _search;
  int? get complexFilter => _complexFilter;
  int? get sportFilter => _sportFilter;
  AdminUserStatus? get statusFilter => _statusFilter;
  String? get surfaceFilter => _surfaceFilter;
  bool? get visibilityFilter => _visibilityFilter;

  CourtSort? get sort => _sort;
  bool get descending => _descending;
  int get limit => _limit;

  Court? get selected => _selected;
  ViewState get detailState => _detailState;
  String? get detailError => _detailError;

  List<Sport> get sports => _sports;
  ViewState get sportsState => _sportsState;
  List<SportsComplex> get complexes => _complexes;
  ViewState get complexesState => _complexesState;

  bool isRowBusy(int id) => _busyRows.contains(id);

  Sport? get filteredSport => sportById(_sportFilter);
  SportsComplex? get filteredComplex => complexById(_complexFilter);

  Sport? sportById(int? id) {
    if (id == null) return null;
    for (final sport in _sports) {
      if (sport.id == id) return sport;
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

  /// Surface types seen on the rows so far.
  ///
  /// There is no `/surface-types` endpoint, and this backend has enum-backed
  /// columns elsewhere, so the options are *learned* from what the API has
  /// returned rather than hardcoded — those are the only values that can be
  /// proved acceptable.
  List<String> get knownSurfaces {
    final seen = <String, String>{};
    for (final court in _rows) {
      final surface = (court.surfaceType ?? '').trim();
      if (surface.isEmpty) continue;
      seen.putIfAbsent(surface.toLowerCase(), () => surface);
    }
    final surfaces = seen.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return surfaces;
  }

  bool get hasFilters =>
      _appliedSearch.trim().isNotEmpty ||
      _complexFilter != null ||
      _sportFilter != null ||
      _statusFilter != null ||
      _surfaceFilter != null ||
      _visibilityFilter != null;

  /// How many dropdown filters are set — drives the badge on the Filter button.
  /// Search is excluded; it has its own visible box.
  int get activeFilterCount => [
    _complexFilter,
    _sportFilter,
    _statusFilter,
    _surfaceFilter,
    _visibilityFilter,
  ].where((filter) => filter != null).length;

  bool get isFirstLoad => _state.isLoading && _rows.isEmpty;
  bool get isRefreshing => _state.isLoading && _rows.isNotEmpty;

  /// Every row that survives the local filters, in the requested order.
  List<Court> get visibleRows {
    final query = _appliedSearch.trim();

    final filtered = _rows.where((court) {
      if (!court.matches(query)) return false;

      if (_statusFilter != null && court.status != _statusFilter) return false;

      if (_surfaceFilter != null) {
        final surface = (court.surfaceType ?? '').trim().toLowerCase();
        if (surface != _surfaceFilter!.trim().toLowerCase()) return false;
      }

      if (_visibilityFilter != null &&
          court.showOnFrontend != _visibilityFilter) {
        return false;
      }

      // The list route has already applied these two; re-checking keeps the
      // table honest if a backend ignores one of its own query parameters.
      if (_complexFilter != null && court.sportComplexId != _complexFilter) {
        return false;
      }
      if (_sportFilter != null && court.sportId != _sportFilter) return false;

      return true;
    }).toList();

    _sortRows(filtered);
    return filtered;
  }

  void _sortRows(List<Court> rows) {
    final by = _sort;
    if (by == null) return;

    int compare(Court a, Court b) {
      switch (by) {
        case CourtSort.name:
          return a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          );
        case CourtSort.sport:
          return (a.sportName ?? '').toLowerCase().compareTo(
            (b.sportName ?? '').toLowerCase(),
          );
        case CourtSort.complex:
          return (a.sportComplexName ?? '').toLowerCase().compareTo(
            (b.sportComplexName ?? '').toLowerCase(),
          );
        case CourtSort.surface:
          return (a.surfaceType ?? '').toLowerCase().compareTo(
            (b.surfaceType ?? '').toLowerCase(),
          );
        case CourtSort.capacity:
          return (a.capacity ?? 0).compareTo(b.capacity ?? 0);
        case CourtSort.rate:
          return (a.hourlyRate ?? 0).compareTo(b.hourlyRate ?? 0);
        case CourtSort.status:
          return a.statusLabel.compareTo(b.statusLabel);
        case CourtSort.visibility:
          // Shown before hidden, so the storefront-visible courts lead.
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

  static bool _isMissing(CourtSort by, Court court) {
    switch (by) {
      case CourtSort.sport:
        return (court.sportName ?? '').trim().isEmpty;
      case CourtSort.complex:
        return (court.sportComplexName ?? '').trim().isEmpty;
      case CourtSort.surface:
        return (court.surfaceType ?? '').trim().isEmpty;
      case CourtSort.capacity:
        return court.capacity == null;
      case CourtSort.rate:
        return court.hourlyRate == null;
      case CourtSort.visibility:
        return court.showOnFrontend == null;
      case CourtSort.name:
      case CourtSort.status:
        return false;
    }
  }

  /// The current page of [visibleRows].
  List<Court> get pageRows {
    final rows = visibleRows;
    if (rows.isEmpty) return const [];

    final start = (_page - 1) * _limit;
    if (start >= rows.length) return const [];
    final end = (start + _limit).clamp(0, rows.length);
    return rows.sublist(start, end);
  }

  /// Shaped for [PaginationBar], which is shared with the server-paged modules.
  Paged<Court> get page {
    final total = visibleRows.length;
    return Paged<Court>(
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
      'Courts loading → complex=${_complexFilter ?? '-'} '
      'sport=${_sportFilter ?? '-'} search="${_appliedSearch.trim()}" '
      'status=${_statusFilter?.slug ?? '-'} surface=${_surfaceFilter ?? '-'} '
      'frontend=${_visibilityFilter ?? '-'} sort=${_sort?.name ?? '-'}',
    );

    _state = ViewState.loading;
    _error = null;
    _safeNotify();

    try {
      final result = await _repository.fetchCourts(
        complexId: _complexFilter,
        sportId: _sportFilter,
      );

      if (_disposed || id != _requestId) {
        AdminLog.state('Courts response superseded — dropped');
        return;
      }

      _rows = result;
      _state = ViewState.ready;
      _clampPage();
      AdminLog.state('Courts ready → ${result.length} rows');
    } on ApiException catch (error) {
      if (_disposed || id != _requestId) return;
      _state = ViewState.failed;
      _error = error.message;
      AdminLog.failure('Courts load failed: ${error.message}', error: error);
    } catch (error, stackTrace) {
      if (_disposed || id != _requestId) return;
      _state = ViewState.failed;
      _error = 'Could not load courts. Please try again.';
      AdminLog.failure(
        'Courts load crashed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _safeNotify();
    }
  }

  Future<void> refresh() {
    AdminLog.ui('Courts refresh requested');
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
      AdminLog.state('Court sport list ready → ${result.length}');
    } catch (error, stackTrace) {
      if (_disposed) return;
      _sportsState = ViewState.failed;
      AdminLog.failure(
        'Court sport list failed',
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
      AdminLog.state('Court venue list ready → ${result.length}');
    } catch (error, stackTrace) {
      if (_disposed) return;
      _complexesState = ViewState.failed;
      AdminLog.failure(
        'Court venue list failed',
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
    AdminLog.ui('Court search typed: "$value"');
    notifyListeners();

    _debounce?.cancel();
    _debounce = Timer(searchDebounce, () {
      if (_disposed) return;
      AdminLog.ui('Court search settled: "${_search.trim()}"');
      _appliedSearch = _search;
      _page = 1;
      _safeNotify();
    });
  }

  void clearSearch() {
    if (_search.isEmpty && _appliedSearch.isEmpty) return;
    AdminLog.ui('Court search cleared');
    _debounce?.cancel();
    _search = '';
    _appliedSearch = '';
    _page = 1;
    _safeNotify();
  }

  /// Server-side — `/courts` takes `sportComplexId`.
  void setComplexFilter(int? complexId) {
    if (_complexFilter == complexId) return;
    AdminLog.ui('Court complex filter → ${complexId ?? 'All'}');
    _complexFilter = complexId;
    _page = 1;
    load();
  }

  /// Server-side — `/courts` takes `sportId`.
  void setSportFilter(int? sportId) {
    if (_sportFilter == sportId) return;
    AdminLog.ui('Court sport filter → ${sportId ?? 'All'}');
    _sportFilter = sportId;
    _page = 1;
    load();
  }

  /// Local — the route takes no status parameter.
  void setStatusFilter(AdminUserStatus? status) {
    if (_statusFilter == status) return;
    AdminLog.ui('Court status filter → ${status?.slug ?? 'All'}');
    _statusFilter = status;
    _page = 1;
    _safeNotify();
  }

  void setSurfaceFilter(String? surface) {
    final next = (surface ?? '').trim().isEmpty ? null : surface;
    if (_surfaceFilter == next) return;
    AdminLog.ui('Court surface filter → ${next ?? 'All'}');
    _surfaceFilter = next;
    _page = 1;
    _safeNotify();
  }

  void setVisibilityFilter(bool? showOnFrontend) {
    if (_visibilityFilter == showOnFrontend) return;
    AdminLog.ui('Court frontend filter → ${showOnFrontend ?? 'All'}');
    _visibilityFilter = showOnFrontend;
    _page = 1;
    _safeNotify();
  }

  void clearFilters() {
    if (!hasFilters) return;
    AdminLog.ui('All court filters cleared');
    _debounce?.cancel();

    // Only the two server-side filters need a refetch; the rest were local.
    final needsReload = _complexFilter != null || _sportFilter != null;

    _search = '';
    _appliedSearch = '';
    _complexFilter = null;
    _sportFilter = null;
    _statusFilter = null;
    _surfaceFilter = null;
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
    AdminLog.ui('Court page size → $limit');
    _limit = limit;
    _page = 1;
    _safeNotify();
  }

  /// Same column twice flips direction; a third tap restores the API's order.
  void toggleSort(CourtSort column) {
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
      'Court sort → ${_sort?.name ?? 'default'}'
      '${_sort == null ? '' : (_descending ? ' desc' : ' asc')}',
    );
    _page = 1;
    _safeNotify();
  }

  void goToPage(int target) {
    final total = page.effectiveTotalPages;
    final next = total > 0 ? target.clamp(1, total) : 1;
    if (next == _page) return;
    AdminLog.ui('Courts go to page $next');
    _page = next;
    _safeNotify();
  }

  void _clampPage() {
    final total = page.effectiveTotalPages;
    if (total > 0 && _page > total) _page = total;
    if (_page < 1) _page = 1;
  }

  // --- Detail ----------------------------------------------------------------

  /// Shows the row already in hand, then fills in from `GET /courts/{id}`.
  Future<void> openCourt(Court court) async {
    AdminLog.ui('Court detail opened for ${court.id}');
    _selected = court;
    _detailState = ViewState.loading;
    _detailError = null;
    _safeNotify();

    try {
      final detail = await _repository.fetchCourt(court.id);
      if (_disposed || _selected?.id != court.id) return;

      _selected = court.mergedWith(detail);
      _detailState = ViewState.ready;
      AdminLog.state('Court detail ready for ${court.id}');
    } on ApiException catch (error) {
      if (_disposed || _selected?.id != court.id) return;
      _detailState = ViewState.failed;
      _detailError = error.message;
      AdminLog.failure('Court detail failed: ${error.message}', error: error);
    } catch (error, stackTrace) {
      if (_disposed || _selected?.id != court.id) return;
      _detailState = ViewState.failed;
      _detailError = 'Could not load this court.';
      AdminLog.failure(
        'Court detail crashed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _safeNotify();
    }
  }

  void closeCourt() {
    if (_selected == null) return;
    AdminLog.ui('Court detail closed');
    _selected = null;
    _detailState = ViewState.idle;
    _detailError = null;
    _safeNotify();
  }

  // --- Writes ----------------------------------------------------------------

  Future<Court> create(CourtDraft draft) async {
    AdminLog.ui('Create court submitted');
    final created = await _repository.createCourt(draft);
    _page = 1;
    await load();
    return created;
  }

  Future<Court> update(int id, CourtDraft draft) async {
    AdminLog.ui('Update court $id submitted');
    final updated = await _repository.updateCourt(id, draft);

    if (_selected?.id == id) {
      _selected = _selected!.mergedWith(updated);
      _safeNotify();
    }

    await load();
    return updated;
  }

  Future<void> delete(int id) async {
    AdminLog.ui('Delete court $id confirmed');

    // Optimistic: the row disappears immediately, and is put back if the call
    // fails, so a failed delete never silently loses a row from the table.
    final previous = _rows;

    _rows = _rows.where((court) => court.id != id).toList();
    if (_selected?.id == id) closeCourt();
    _clampPage();
    _safeNotify();

    try {
      await _repository.deleteCourt(id);
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

  /// `PATCH /{id}/show-on-frontend`, applied to the row before the call so the
  /// switch flips instantly; reverted if the server refuses.
  Future<void> setVisibility(int id, bool showOnFrontend) async {
    final current = _rowFor(id);
    if (current == null) return;

    AdminLog.ui('Court $id showOnFrontend → $showOnFrontend');
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

  /// There is no `/courts/{id}/status` route, so this is a `PUT` of that one
  /// field — still optimistic, still reverted if the server refuses.
  Future<void> setStatus(int id, AdminUserStatus status) async {
    final current = _rowFor(id);
    if (current == null || current.status == status) return;

    AdminLog.ui('Court $id status → ${status.slug}');
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

  Court? _rowFor(int id) {
    for (final court in _rows) {
      if (court.id == id) return court;
    }
    return _selected?.id == id ? _selected : null;
  }

  /// Applies a row change everywhere it is held, so the table, the summary
  /// cards and an open drawer can never disagree.
  void _replaceRow(int id, Court next) {
    _rows = _rows
        .map((court) => court.id == id ? next : court)
        .toList(growable: false);
    if (_selected?.id == id) _selected = next;
  }

  // --- Images ----------------------------------------------------------------

  Future<String> uploadImage(String filePath, {String? filename}) {
    AdminLog.ui('Court image upload started');
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
    AdminLog.life('CourtsController disposed');
    super.dispose();
  }
}
