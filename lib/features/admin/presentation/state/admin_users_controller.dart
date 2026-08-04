import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/admin_role.dart';
import '../../domain/entities/admin_user.dart';
import '../../domain/entities/paged.dart';
import '../../domain/repositories/admin_repository.dart';
import 'view_state.dart';

/// The columns the table can be ordered by.
///
/// [wire] is what goes out as `?sortBy=`; a backend that ignores it still gets
/// a sorted view because the controller re-orders the page it received.
enum UserSort {
  name('name', 'Name'),
  email('email', 'Email'),
  role('role', 'Role'),
  membership('membershipType', 'Membership'),
  bookings('totalBookings', 'Bookings'),
  status('status', 'Status'),
  joined('joinDate', 'Joined'),
  lastActive('lastActive', 'Last active');

  const UserSort(this.wire, this.label);

  final String wire;
  final String label;
}

/// Everything the Users page needs: server-side pagination, debounced search,
/// role/status filters, sorting and the four write operations.
class AdminUsersController extends ChangeNotifier {
  AdminUsersController(this._repository) {
    AdminLog.life('AdminUsersController created');
  }

  final AdminRepository _repository;

  /// How long typing settles before a request goes out.
  static const Duration searchDebounce = Duration(milliseconds: 400);

  static const List<int> pageSizes = [10, 20, 50, 100];

  ViewState _state = ViewState.idle;
  Paged<AdminUser> _page = const Paged<AdminUser>();
  String? _error;

  int _requestedPage = 1;
  int _limit = 20;
  AdminRole? _roleFilter;
  AdminUserStatus? _statusFilter;
  String _search = '';
  UserSort? _sort;
  bool _descending = false;

  Timer? _debounce;

  /// Guards against a slow early response overwriting a newer one.
  int _requestId = 0;

  bool _disposed = false;

  // Detail drawer.
  AdminUser? _selected;
  ViewState _detailState = ViewState.idle;
  String? _detailError;

  /// Membership values are not enumerable from any endpoint, so the vocabulary
  /// is learned from the rows the server actually returns — that keeps the
  /// dropdown honest instead of hardcoding a guessed tier list.
  final Set<String> _knownMemberships = <String>{};
  final Set<String> _knownDepartments = <String>{};
  final Set<String> _knownSports = <String>{};
  final Set<String> _knownLocations = <String>{};

  // --- Reads -----------------------------------------------------------------

  ViewState get state => _state;
  Paged<AdminUser> get page => _page;
  List<AdminUser> get users => _sortedRows;
  String? get error => _error;

  int get limit => _limit;
  AdminRole? get roleFilter => _roleFilter;
  AdminUserStatus? get statusFilter => _statusFilter;
  String get search => _search;
  UserSort? get sort => _sort;
  bool get descending => _descending;

  AdminUser? get selected => _selected;
  ViewState get detailState => _detailState;
  String? get detailError => _detailError;

  bool get hasFilters =>
      _roleFilter != null || _statusFilter != null || _search.trim().isNotEmpty;

  bool get isFirstLoad => _state.isLoading && _page.items.isEmpty;

  bool get isRefreshing => _state.isLoading && _page.items.isNotEmpty;

  List<String> get knownMemberships => _sortedCopy(_knownMemberships);
  List<String> get knownDepartments => _sortedCopy(_knownDepartments);
  List<String> get knownSports => _sortedCopy(_knownSports);
  List<String> get knownLocations => _sortedCopy(_knownLocations);

  static List<String> _sortedCopy(Set<String> values) {
    final list = values.toList()..sort();
    return List<String>.unmodifiable(list);
  }

  /// The page as ordered for display. The server is asked to sort, but a
  /// backend that ignores `sortBy` would otherwise leave the header arrow
  /// lying — so the received page is ordered locally too.
  List<AdminUser> get _sortedRows {
    final rows = List<AdminUser>.from(_page.items);
    final by = _sort;
    if (by == null) return rows;

    int compare(AdminUser a, AdminUser b) {
      switch (by) {
        case UserSort.name:
          return a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          );
        case UserSort.email:
          return (a.email ?? '').toLowerCase().compareTo(
            (b.email ?? '').toLowerCase(),
          );
        case UserSort.role:
          return a.roleLabel.compareTo(b.roleLabel);
        case UserSort.membership:
          return (a.membership ?? '').compareTo(b.membership ?? '');
        case UserSort.bookings:
          return (a.totalBookings ?? -1).compareTo(b.totalBookings ?? -1);
        case UserSort.status:
          return a.statusLabel.compareTo(b.statusLabel);
        case UserSort.joined:
          return _compareDates(a.joinedAt, b.joinedAt);
        case UserSort.lastActive:
          return _compareDates(a.lastActiveAt, b.lastActiveAt);
      }
    }

    rows.sort((a, b) {
      // Rows the server sent no value for sink to the bottom in BOTH
      // directions. Folding this into `compare` would not work: reversing the
      // arguments would float every blank to the top on the descending pass.
      final missingA = _isMissing(by, a);
      final missingB = _isMissing(by, b);
      if (missingA && missingB) return 0;
      if (missingA != missingB) return missingA ? 1 : -1;

      return _descending ? compare(b, a) : compare(a, b);
    });
    return rows;
  }

  /// True when [user] has nothing to sort by in column [by].
  static bool _isMissing(UserSort by, AdminUser user) {
    switch (by) {
      case UserSort.joined:
        return user.joinedAt == null;
      case UserSort.lastActive:
        return user.lastActiveAt == null;
      case UserSort.membership:
        return (user.membership ?? '').trim().isEmpty;
      case UserSort.bookings:
        return user.totalBookings == null;
      case UserSort.name:
      case UserSort.email:
      case UserSort.role:
      case UserSort.status:
        return false;
    }
  }

  static int _compareDates(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return a.compareTo(b);
  }

  // --- Loading ---------------------------------------------------------------

  Future<void> load({int? page, bool resetError = true}) async {
    final target = page ?? _requestedPage;
    final id = ++_requestId;

    AdminLog.state(
      'Users loading → page=$target limit=$_limit '
      'role=${_roleFilter?.slug ?? '-'} status=${_statusFilter?.slug ?? '-'} '
      'search="${_search.trim()}" sort=${_sort?.wire ?? '-'}'
      '${_sort == null ? '' : (_descending ? ' desc' : ' asc')}',
    );

    _requestedPage = target;
    _state = ViewState.loading;
    if (resetError) _error = null;
    _safeNotify();

    try {
      final result = await _repository.fetchUsers(
        page: target,
        limit: _limit,
        role: _roleFilter,
        status: _statusFilter,
        search: _search.trim().isEmpty ? null : _search.trim(),
        sortBy: _sort?.wire,
        descending: _descending,
      );

      if (_disposed || id != _requestId) {
        AdminLog.state('Users response for a superseded request — dropped');
        return;
      }

      _page = result;
      _requestedPage = result.page;
      _state = ViewState.ready;
      _error = null;
      _learnVocabulary(result.items);

      AdminLog.state(
        'Users ready → ${result.items.length} rows, '
        'page ${result.page}/${result.effectiveTotalPages}, '
        'total ${result.total}',
      );
    } on ApiException catch (error) {
      if (_disposed || id != _requestId) return;
      _state = ViewState.failed;
      _error = error.message;
      AdminLog.failure('Users load failed: ${error.message}', error: error);
    } catch (error, stackTrace) {
      if (_disposed || id != _requestId) return;
      _state = ViewState.failed;
      _error = 'Could not load users. Please try again.';
      AdminLog.failure(
        'Users load crashed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _safeNotify();
    }
  }

  Future<void> refresh() {
    AdminLog.ui('Users refresh requested');
    return load();
  }

  /// Reloads from page 1 — used whenever a filter changes.
  Future<void> _reloadFromStart() => load(page: 1);

  // --- Filters ---------------------------------------------------------------

  void onSearchChanged(String value) {
    if (_search == value) return;
    _search = value;
    AdminLog.ui(
      'Search typed: "$value" (debouncing ${searchDebounce.inMilliseconds}ms)',
    );
    notifyListeners(); // Keep the field's clear button in sync immediately.

    _debounce?.cancel();
    _debounce = Timer(searchDebounce, () {
      AdminLog.ui('Search settled: "${_search.trim()}"');
      _reloadFromStart();
    });
  }

  void clearSearch() {
    if (_search.isEmpty) return;
    AdminLog.ui('Search cleared');
    _debounce?.cancel();
    _search = '';
    _reloadFromStart();
  }

  void setRoleFilter(AdminRole? role) {
    if (_roleFilter == role) return;
    AdminLog.ui('Role filter → ${role?.slug ?? 'All roles'}');
    _roleFilter = role;
    _reloadFromStart();
  }

  void setStatusFilter(AdminUserStatus? status) {
    if (_statusFilter == status) return;
    AdminLog.ui('Status filter → ${status?.slug ?? 'All statuses'}');
    _statusFilter = status;
    _reloadFromStart();
  }

  void clearFilters() {
    if (!hasFilters) return;
    AdminLog.ui('All filters cleared');
    _debounce?.cancel();
    _roleFilter = null;
    _statusFilter = null;
    _search = '';
    _reloadFromStart();
  }

  void setLimit(int limit) {
    if (_limit == limit) return;
    AdminLog.ui('Page size → $limit');
    _limit = limit;
    _reloadFromStart();
  }

  /// Tapping the same column flips direction; a third tap clears the sort and
  /// hands ordering back to the server's default.
  void toggleSort(UserSort column) {
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
      'Sort → ${_sort?.wire ?? 'default'}'
      '${_sort == null ? '' : (_descending ? ' desc' : ' asc')}',
    );
    _reloadFromStart();
  }

  // --- Paging ----------------------------------------------------------------

  void goToPage(int page) {
    final total = _page.effectiveTotalPages;
    final target = total > 0 ? page.clamp(1, total) : page;
    if (target == _page.page && _state.isReady) return;
    AdminLog.ui('Go to page $target');
    load(page: target);
  }

  void nextPage() {
    if (!_page.hasNext) return;
    goToPage(_page.page + 1);
  }

  void previousPage() {
    if (!_page.hasPrevious) return;
    goToPage(_page.page - 1);
  }

  // --- Detail ----------------------------------------------------------------

  /// Shows the row we already have, then replaces it with the full record.
  Future<void> openUser(AdminUser user) async {
    AdminLog.ui('Open detail for ${user.id} (${user.displayName})');
    _selected = user;
    _detailState = ViewState.loading;
    _detailError = null;
    _safeNotify();

    try {
      final detail = await _repository.fetchUser(user.id);
      if (_disposed || _selected?.id != user.id) return;

      // Merge rather than replace: the list row sometimes carries a field the
      // detail route omits.
      _selected = user.mergedWith(detail);
      _detailState = ViewState.ready;
      _learnVocabulary([_selected!]);
      AdminLog.state('Detail ready for ${user.id}');
    } on ApiException catch (error) {
      if (_disposed || _selected?.id != user.id) return;
      _detailState = ViewState.failed;
      _detailError = error.message;
      AdminLog.failure('Detail failed: ${error.message}', error: error);
    } catch (error, stackTrace) {
      if (_disposed || _selected?.id != user.id) return;
      _detailState = ViewState.failed;
      _detailError = 'Could not load this user.';
      AdminLog.failure('Detail crashed', error: error, stackTrace: stackTrace);
    } finally {
      _safeNotify();
    }
  }

  void closeUser() {
    if (_selected == null) return;
    AdminLog.ui('Detail closed');
    _selected = null;
    _detailState = ViewState.idle;
    _detailError = null;
    _safeNotify();
  }

  // --- Writes ----------------------------------------------------------------
  //
  // These rethrow so the dialog can keep itself open and show the server's own
  // message; the list reload only happens on success.

  Future<AdminUser> createUser(AdminUserDraft draft) async {
    AdminLog.ui('Create user submitted (${draft.role?.slug ?? 'no role'})');
    final created = await _repository.createUser(draft);
    await _reloadFromStart();
    return created;
  }

  Future<AdminUser> updateUser(String userId, AdminUserDraft draft) async {
    AdminLog.ui('Update user $userId submitted');
    final updated = await _repository.updateUser(userId, draft);

    // Keep the open drawer in step with what was just saved.
    if (_selected?.id == userId) {
      _selected = _selected!.mergedWith(updated);
      _safeNotify();
    }

    await load();
    return updated;
  }

  Future<void> deleteUser(String userId) async {
    AdminLog.ui('Delete user $userId confirmed');
    await _repository.deleteUser(userId);

    if (_selected?.id == userId) closeUser();

    // Deleting the last row of the last page would otherwise leave an empty
    // page selected.
    final wasLastRowOnPage = _page.items.length == 1 && _page.page > 1;
    await load(page: wasLastRowOnPage ? _page.page - 1 : _page.page);
  }

  void _learnVocabulary(List<AdminUser> users) {
    for (final user in users) {
      final membership = (user.membership ?? '').trim();
      if (membership.isNotEmpty) _knownMemberships.add(membership);

      final department = (user.department ?? '').trim();
      if (department.isNotEmpty) _knownDepartments.add(department);

      final location = (user.assignedLocation ?? '').trim();
      if (location.isNotEmpty) _knownLocations.add(location);

      for (final sport in user.assignedSports) {
        final trimmed = sport.trim();
        if (trimmed.isNotEmpty) _knownSports.add(trimmed);
      }
    }
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    AdminLog.life('AdminUsersController disposed');
    super.dispose();
  }
}
