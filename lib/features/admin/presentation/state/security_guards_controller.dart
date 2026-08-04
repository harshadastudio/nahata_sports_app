import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../models/sports_complex_model.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/admin_role.dart';
import '../../domain/entities/employee_vocabulary.dart';
import '../../domain/entities/paged.dart';
import '../../domain/entities/security_guard.dart';
import '../../domain/repositories/security_guard_repository.dart';
import 'view_state.dart';

/// The columns the security guard table can be ordered by.
enum SecurityGuardSort {
  code('guardId', 'Guard ID'),
  name('fullName', 'Name'),
  email('email', 'Email'),
  area('assignedArea', 'Assigned area'),
  shift('shift', 'Shift'),
  salary('salary', 'Salary'),
  status('status', 'Status'),
  joining('joiningDate', 'Joining date');

  const SecurityGuardSort(this.wire, this.label);

  final String wire;
  final String label;
}

/// Everything the Security Guards page needs: server-side pagination, debounced
/// search, four filters, sorting, CRUD and password management.
class SecurityGuardsController extends ChangeNotifier {
  SecurityGuardsController(this._repository) {
    AdminLog.life('SecurityGuardsController created');
  }

  final SecurityGuardRepository _repository;

  static const Duration searchDebounce = Duration(milliseconds: 400);
  static const List<int> pageSizes = [10, 20, 50, 100];

  ViewState _state = ViewState.idle;
  Paged<SecurityGuard> _page = const Paged<SecurityGuard>();
  String? _error;

  int _requestedPage = 1;
  int _limit = 20;
  String _search = '';

  AdminUserStatus? _statusFilter;
  Shift? _shiftFilter;
  int? _complexFilter;
  String? _areaFilter;

  SecurityGuardSort? _sort;
  bool _descending = false;

  Timer? _debounce;
  int _requestId = 0;
  bool _disposed = false;

  // Detail drawer.
  SecurityGuard? _selected;
  ViewState _detailState = ViewState.idle;
  String? _detailError;

  // Venue list for the form and the complex filter.
  List<SportsComplex> _complexes = const [];
  ViewState _complexesState = ViewState.idle;

  /// Every assigned area seen so far, so the area filter can offer choices.
  /// There is no `/areas` route, so the options are learned from the rows the
  /// server actually returns rather than hardcoded.
  final Set<String> _knownAreas = <String>{};

  // --- Reads -----------------------------------------------------------------

  ViewState get state => _state;
  Paged<SecurityGuard> get page => _page;
  List<SecurityGuard> get guards => _sortedRows;
  String? get error => _error;

  int get limit => _limit;
  String get search => _search;

  AdminUserStatus? get statusFilter => _statusFilter;
  Shift? get shiftFilter => _shiftFilter;
  int? get complexFilter => _complexFilter;
  String? get areaFilter => _areaFilter;

  SecurityGuardSort? get sort => _sort;
  bool get descending => _descending;

  SecurityGuard? get selected => _selected;
  ViewState get detailState => _detailState;
  String? get detailError => _detailError;

  List<SportsComplex> get complexes => _complexes;
  ViewState get complexesState => _complexesState;

  /// The areas learned so far, alphabetically, for the searchable area filter.
  List<String> get knownAreas {
    final areas = _knownAreas.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return List<String>.unmodifiable(areas);
  }

  /// The venue behind [complexFilter], for the filter chip's label.
  SportsComplex? get filteredComplex {
    final id = _complexFilter;
    if (id == null) return null;
    for (final complex in _complexes) {
      if (complex.id == id) return complex;
    }
    return null;
  }

  bool get hasFilters =>
      _search.trim().isNotEmpty ||
      _statusFilter != null ||
      _shiftFilter != null ||
      _complexFilter != null ||
      (_areaFilter ?? '').trim().isNotEmpty;

  /// How many of the four dropdown filters are set — drives the badge on the
  /// Filter button. Search is excluded; it has its own visible box.
  int get activeFilterCount => [
    _statusFilter,
    _shiftFilter,
    _complexFilter,
    (_areaFilter ?? '').trim().isEmpty ? null : _areaFilter,
  ].where((filter) => filter != null).length;

  bool get isFirstLoad => _state.isLoading && _page.items.isEmpty;
  bool get isRefreshing => _state.isLoading && _page.items.isNotEmpty;

  /// The page as displayed. The server is asked to sort, but a backend that
  /// ignores `sortBy` would leave the header arrow lying, so the received page
  /// is ordered locally too.
  List<SecurityGuard> get _sortedRows {
    final rows = List<SecurityGuard>.from(_page.items);
    final by = _sort;
    if (by == null) return rows;

    int compare(SecurityGuard a, SecurityGuard b) {
      switch (by) {
        case SecurityGuardSort.code:
          return (a.guardCode ?? '').toLowerCase().compareTo(
            (b.guardCode ?? '').toLowerCase(),
          );
        case SecurityGuardSort.name:
          return a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          );
        case SecurityGuardSort.email:
          return (a.email ?? '').toLowerCase().compareTo(
            (b.email ?? '').toLowerCase(),
          );
        case SecurityGuardSort.area:
          return (a.assignedArea ?? '').toLowerCase().compareTo(
            (b.assignedArea ?? '').toLowerCase(),
          );
        case SecurityGuardSort.shift:
          return a.shiftLabel.compareTo(b.shiftLabel);
        case SecurityGuardSort.salary:
          return (a.salary ?? 0).compareTo(b.salary ?? 0);
        case SecurityGuardSort.status:
          return a.statusLabel.compareTo(b.statusLabel);
        case SecurityGuardSort.joining:
          final first = a.joiningDate;
          final second = b.joiningDate;
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
    return rows;
  }

  static bool _isMissing(SecurityGuardSort by, SecurityGuard guard) {
    switch (by) {
      case SecurityGuardSort.code:
        return (guard.guardCode ?? '').trim().isEmpty;
      case SecurityGuardSort.area:
        return (guard.assignedArea ?? '').trim().isEmpty;
      case SecurityGuardSort.salary:
        return guard.salary == null;
      case SecurityGuardSort.joining:
        return guard.joiningDate == null;
      case SecurityGuardSort.shift:
        return (guard.shiftRaw ?? '').trim().isEmpty;
      case SecurityGuardSort.name:
      case SecurityGuardSort.email:
      case SecurityGuardSort.status:
        return false;
    }
  }

  // --- Loading ---------------------------------------------------------------

  Future<void> load({int? page}) async {
    final target = page ?? _requestedPage;
    final id = ++_requestId;

    AdminLog.state(
      'Security guards loading → page=$target limit=$_limit '
      'search="${_search.trim()}" status=${_statusFilter?.slug ?? '-'} '
      'shift=${_shiftFilter?.slug ?? '-'} complex=${_complexFilter ?? '-'} '
      'area=${_areaFilter ?? '-'} sort=${_sort?.wire ?? '-'}'
      '${_sort == null ? '' : (_descending ? ' desc' : ' asc')}',
    );

    _requestedPage = target;
    _state = ViewState.loading;
    _error = null;
    _safeNotify();

    try {
      final result = await _repository.fetchGuards(
        page: target,
        limit: _limit,
        search: _search.trim().isEmpty ? null : _search.trim(),
        status: _statusFilter,
        shift: _shiftFilter,
        sportComplexId: _complexFilter,
        assignedArea: _areaFilter,
        sortBy: _sort?.wire,
        descending: _descending,
      );

      if (_disposed || id != _requestId) {
        AdminLog.state('Security guard response superseded — dropped');
        return;
      }

      _page = result;
      _requestedPage = result.page;
      _state = ViewState.ready;
      _rememberAreas(result.items);

      AdminLog.state(
        'Security guards ready → ${result.items.length} rows, '
        'page ${result.page}/${result.effectiveTotalPages}, '
        'total ${result.total}',
      );
    } on ApiException catch (error) {
      if (_disposed || id != _requestId) return;
      _state = ViewState.failed;
      _error = error.message;
      AdminLog.failure(
        'Security guards load failed: ${error.message}',
        error: error,
      );
    } catch (error, stackTrace) {
      if (_disposed || id != _requestId) return;
      _state = ViewState.failed;
      _error = 'Could not load security guards. Please try again.';
      AdminLog.failure(
        'Security guards load crashed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _safeNotify();
    }
  }

  void _rememberAreas(List<SecurityGuard> rows) {
    for (final guard in rows) {
      final area = (guard.assignedArea ?? '').trim();
      if (area.isNotEmpty) _knownAreas.add(area);
    }
  }

  Future<void> refresh() {
    AdminLog.ui('Security guards refresh requested');
    return load();
  }

  /// Loads the venue list used by both the form and the complex filter.
  Future<void> loadComplexes({bool refresh = false}) async {
    if (_complexesState.isLoading) return;
    if (_complexes.isNotEmpty && !refresh) return;

    AdminLog.state('Guard venue list loading (refresh: $refresh)');
    _complexesState = ViewState.loading;
    _safeNotify();

    try {
      final result = await _repository.fetchSportComplexes(refresh: refresh);
      if (_disposed) return;
      _complexes = result;
      _complexesState = ViewState.ready;
      AdminLog.state('Guard venue list ready → ${result.length}');
    } catch (error, stackTrace) {
      if (_disposed) return;
      _complexesState = ViewState.failed;
      AdminLog.failure(
        'Guard venue list failed',
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
    AdminLog.ui(
      'Guard search typed: "$value" '
      '(debouncing ${searchDebounce.inMilliseconds}ms)',
    );
    notifyListeners();

    _debounce?.cancel();
    _debounce = Timer(searchDebounce, () {
      AdminLog.ui('Guard search settled: "${_search.trim()}"');
      load(page: 1);
    });
  }

  void clearSearch() {
    if (_search.isEmpty) return;
    AdminLog.ui('Guard search cleared');
    _debounce?.cancel();
    _search = '';
    load(page: 1);
  }

  void setStatusFilter(AdminUserStatus? status) {
    if (_statusFilter == status) return;
    AdminLog.ui('Guard status filter → ${status?.slug ?? 'All'}');
    _statusFilter = status;
    load(page: 1);
  }

  void setShiftFilter(Shift? shift) {
    if (_shiftFilter == shift) return;
    AdminLog.ui('Guard shift filter → ${shift?.slug ?? 'All'}');
    _shiftFilter = shift;
    load(page: 1);
  }

  void setComplexFilter(int? sportComplexId) {
    if (_complexFilter == sportComplexId) return;
    AdminLog.ui('Guard complex filter → ${sportComplexId ?? 'All'}');
    _complexFilter = sportComplexId;
    load(page: 1);
  }

  void setAreaFilter(String? area) {
    final next = (area ?? '').trim().isEmpty ? null : area!.trim();
    if (_areaFilter == next) return;
    AdminLog.ui('Guard area filter → ${next ?? 'All'}');
    _areaFilter = next;
    load(page: 1);
  }

  void clearFilters() {
    if (!hasFilters) return;
    AdminLog.ui('All guard filters cleared');
    _debounce?.cancel();
    _search = '';
    _statusFilter = null;
    _shiftFilter = null;
    _complexFilter = null;
    _areaFilter = null;
    load(page: 1);
  }

  void setLimit(int limit) {
    if (_limit == limit) return;
    AdminLog.ui('Guard page size → $limit');
    _limit = limit;
    load(page: 1);
  }

  /// Same column twice flips direction; a third tap hands ordering back to the
  /// server's default.
  void toggleSort(SecurityGuardSort column) {
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
      'Guard sort → ${_sort?.wire ?? 'default'}'
      '${_sort == null ? '' : (_descending ? ' desc' : ' asc')}',
    );
    load(page: 1);
  }

  void goToPage(int page) {
    final total = _page.effectiveTotalPages;
    final target = total > 0 ? page.clamp(1, total) : page;
    if (target == _page.page && _state.isReady) return;
    AdminLog.ui('Security guards go to page $target');
    load(page: target);
  }

  // --- Detail ----------------------------------------------------------------

  /// Shows the row already in hand, then replaces it with the full record.
  Future<void> openGuard(SecurityGuard guard) async {
    AdminLog.ui('Guard detail opened for ${guard.id}');
    _selected = guard;
    _detailState = ViewState.loading;
    _detailError = null;
    _safeNotify();

    try {
      final detail = await _repository.fetchGuard(guard.id);
      if (_disposed || _selected?.id != guard.id) return;

      _selected = guard.mergedWith(detail);
      _detailState = ViewState.ready;
      AdminLog.state('Guard detail ready for ${guard.id}');
    } on ApiException catch (error) {
      if (_disposed || _selected?.id != guard.id) return;
      _detailState = ViewState.failed;
      _detailError = error.message;
      AdminLog.failure('Guard detail failed: ${error.message}', error: error);
    } catch (error, stackTrace) {
      if (_disposed || _selected?.id != guard.id) return;
      _detailState = ViewState.failed;
      _detailError = 'Could not load this security guard.';
      AdminLog.failure(
        'Guard detail crashed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _safeNotify();
    }
  }

  void closeGuard() {
    if (_selected == null) return;
    AdminLog.ui('Guard detail closed');
    _selected = null;
    _detailState = ViewState.idle;
    _detailError = null;
    _safeNotify();
  }

  // --- Writes ----------------------------------------------------------------

  Future<SecurityGuard> create(SecurityGuardDraft draft) async {
    AdminLog.ui('Create security guard submitted');
    final created = await _repository.createGuard(draft);
    await load(page: 1);
    return created;
  }

  Future<SecurityGuard> update(String id, SecurityGuardDraft draft) async {
    AdminLog.ui('Update security guard $id submitted');
    final updated = await _repository.updateGuard(id, draft);

    if (_selected?.id == id) {
      _selected = _selected!.mergedWith(updated);
      _safeNotify();
    }

    await load();
    return updated;
  }

  Future<void> delete(String id) async {
    AdminLog.ui('Delete security guard $id confirmed');

    // Optimistic: the row disappears immediately, and is put back if the call
    // fails, so a failed delete never silently loses a row from the table.
    final previous = _page;
    _page = _page.copyWith(
      items: _page.items.where((guard) => guard.id != id).toList(),
      total: _page.total > 0 ? _page.total - 1 : 0,
    );
    if (_selected?.id == id) closeGuard();
    _safeNotify();

    try {
      await _repository.deleteGuard(id);
    } catch (error) {
      if (!_disposed) {
        AdminLog.failure('Delete failed — restoring the row', error: error);
        _page = previous;
        _safeNotify();
      }
      rethrow;
    }

    // Reconcile with the server; step back if that was the page's last row.
    final wasLastRowOnPage = previous.items.length == 1 && previous.page > 1;
    await load(page: wasLastRowOnPage ? previous.page - 1 : previous.page);
  }

  // --- Passwords -------------------------------------------------------------
  //
  // Credentials are returned to the caller and never held on this controller:
  // the dialog owns them for as long as it is open, and they go with it.

  Future<SecurityGuardCredentials> fetchCredentials(String id) {
    AdminLog.ui('View password requested for guard $id');
    return _repository.fetchCredentials(id);
  }

  Future<void> resetPassword(String id, String password) {
    AdminLog.ui('Password reset submitted for guard $id');
    return _repository.resetPassword(id, password);
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    AdminLog.life('SecurityGuardsController disposed');
    super.dispose();
  }
}
