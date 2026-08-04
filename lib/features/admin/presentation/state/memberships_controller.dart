import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/membership.dart';
import '../../domain/entities/paged.dart';
import '../../domain/repositories/membership_repository.dart';
import 'view_state.dart';

/// The columns the memberships table can be ordered by.
enum MembershipSort {
  plan('Plan'),
  member('Member'),
  price('Price'),
  starts('Starts'),
  ends('Ends'),
  status('Status'),
  payment('Payment');

  const MembershipSort(this.label);

  final String label;
}

/// The five summary figures above the table.
///
/// Every field is nullable: these come from `/memberships/stats` when it
/// answers, and are otherwise counted from the rows in hand — which is a
/// different claim, so [countedLocally] says which.
class MembershipsSummary {
  const MembershipsSummary({
    this.total,
    this.active,
    this.expired,
    this.cancelled,
    this.revenue,
    this.countedLocally = false,
  });

  final int? total;
  final int? active;
  final int? expired;
  final int? cancelled;
  final num? revenue;
  final bool countedLocally;

  /// Counted from the rows on screen. Revenue counts what has actually been
  /// paid — billing a cancelled plan as revenue would overstate the take.
  static MembershipsSummary from(List<Membership> rows, {int? total}) {
    var active = 0;
    var expired = 0;
    var cancelled = 0;
    num revenue = 0;
    var revenueKnown = false;

    for (final row in rows) {
      switch (row.status) {
        case MembershipStatus.active:
          active++;
        case MembershipStatus.expired:
          expired++;
        case MembershipStatus.cancelled:
          cancelled++;
        case MembershipStatus.inactive:
        case null:
          break;
      }

      final amount = row.totalAmount ?? row.price;
      if (amount != null && row.isPaid) {
        revenueKnown = true;
        revenue += amount;
      }
    }

    return MembershipsSummary(
      total: total ?? rows.length,
      active: active,
      expired: expired,
      cancelled: cancelled,
      revenue: revenueKnown ? revenue : null,
      countedLocally: true,
    );
  }

  /// The endpoint's own figures, with anything it omitted filled in from the
  /// rows — and the caption then tells the truth about which is which.
  MembershipsSummary mergedWith(MembershipsSummary counted) {
    return MembershipsSummary(
      total: total ?? counted.total,
      active: active ?? counted.active,
      expired: expired ?? counted.expired,
      cancelled: cancelled ?? counted.cancelled,
      revenue: revenue ?? counted.revenue,
      countedLocally:
          total == null ||
          active == null ||
          expired == null ||
          cancelled == null,
    );
  }

  static MembershipsSummary fromStats(MembershipStats stats) {
    return MembershipsSummary(
      total: stats.total,
      active: stats.active,
      expired: stats.expired,
      cancelled: stats.cancelled,
      revenue: stats.revenue,
    );
  }
}

/// Everything the Memberships page needs.
///
/// `GET /memberships` paginates and filters by status server-side, so status
/// paging stays on the server. Search and sorting are not documented as
/// parameters, so — like the Batches, Bookings and Events modules — asking for
/// either switches the controller into **catalogue mode**, walking every page
/// once so that "no matches" means no matches, not "none on page one".
class MembershipsController extends ChangeNotifier {
  MembershipsController(this._repository) {
    AdminLog.life('MembershipsController created');
  }

  final MembershipRepository _repository;

  static const Duration searchDebounce = Duration(milliseconds: 300);
  static const List<int> pageSizes = [10, 20, 50, 100];
  static const int cataloguePageSize = 100;
  static const int catalogueMaxPages = 20;

  ViewState _state = ViewState.idle;
  String? _error;
  List<Membership> _rows = const [];

  int _serverPage = 1;
  int _serverTotalPages = 0;
  int _serverTotalItems = 0;
  bool _catalogueMode = false;

  /// True while an infinite-scroll append is in flight, so the mobile list can
  /// show a footer without the whole page flipping to its shimmer.
  bool _loadingMore = false;

  String _search = '';
  String _appliedSearch = '';
  MembershipStatus? _statusFilter;
  MembershipPaymentStatus? _paymentFilter;
  bool _expiringSoonOnly = false;

  MembershipSort? _sort;
  bool _descending = false;

  int _page = 1;
  int _limit = 20;

  Timer? _debounce;
  int _requestId = 0;
  bool _disposed = false;

  // Statistics.
  MembershipStats _stats = const MembershipStats();
  ViewState _statsState = ViewState.idle;

  // Detail drawer.
  Membership? _selected;
  ViewState _detailState = ViewState.idle;
  String? _detailError;

  // The selected member's other plans, from `/memberships/user/{userId}`.
  List<Membership> _userHistory = const [];
  Membership? _userActive;
  ViewState _historyState = ViewState.idle;

  final Set<String> _busyRows = <String>{};

  /// Days ahead that count as "expiring soon" for the filter and the badge.
  static const int expiringSoonDays = 30;

  // --- Reads -----------------------------------------------------------------

  ViewState get state => _state;
  String? get error => _error;
  List<Membership> get rows => _rows;

  bool get isCatalogueMode => _catalogueMode;
  bool get isLoadingMore => _loadingMore;

  MembershipStats get stats => _stats;
  ViewState get statsState => _statsState;

  MembershipsSummary get summary {
    final counted = MembershipsSummary.from(
      _catalogueMode ? visibleRows : _rows,
      total: _catalogueMode ? visibleRows.length : _serverTotalItems,
    );
    if (_stats.isEmpty) return counted;
    return MembershipsSummary.fromStats(_stats).mergedWith(counted);
  }

  /// True when the counted figures describe one page rather than everything.
  bool get summaryIsPageScoped =>
      !_catalogueMode && page.effectiveTotalPages > 1;

  String get search => _search;
  MembershipStatus? get statusFilter => _statusFilter;
  MembershipPaymentStatus? get paymentFilter => _paymentFilter;
  bool get expiringSoonOnly => _expiringSoonOnly;

  MembershipSort? get sort => _sort;
  bool get descending => _descending;
  int get limit => _limit;

  Membership? get selected => _selected;
  ViewState get detailState => _detailState;
  String? get detailError => _detailError;

  List<Membership> get userHistory => _userHistory;
  Membership? get userActive => _userActive;
  ViewState get historyState => _historyState;

  bool isRowBusy(String id) => _busyRows.contains(id);

  bool get hasFilters =>
      _appliedSearch.trim().isNotEmpty ||
      _statusFilter != null ||
      _paymentFilter != null ||
      _expiringSoonOnly;

  int get activeFilterCount =>
      [_statusFilter, _paymentFilter].where((f) => f != null).length +
      (_expiringSoonOnly ? 1 : 0);

  bool get isFirstLoad => _state.isLoading && _rows.isEmpty && !_loadingMore;
  bool get isRefreshing => _state.isLoading && _rows.isNotEmpty;

  /// Status alone is a server parameter, so it does not force the catalogue.
  bool get _needsCatalogue =>
      _appliedSearch.trim().isNotEmpty ||
      _paymentFilter != null ||
      _expiringSoonOnly ||
      _sort != null;

  /// Every membership that survives the filters, in the requested order.
  List<Membership> get visibleRows {
    if (!_catalogueMode) return _rows;

    final query = _appliedSearch.trim();
    final now = DateTime.now();

    final filtered = _rows.where((row) {
      if (!row.matches(query)) return false;
      if (_statusFilter != null && row.status != _statusFilter) return false;
      if (_paymentFilter != null && row.paymentStatus != _paymentFilter) {
        return false;
      }
      if (_expiringSoonOnly) {
        final days = row.daysRemaining(now: now);
        // A plan with no end date is unknown, not expiring — it must not be
        // swept into a list an admin will act on.
        if (days == null || days < 0 || days > expiringSoonDays) return false;
      }
      return true;
    }).toList();

    _sortRows(filtered);
    return filtered;
  }

  void _sortRows(List<Membership> rows) {
    final by = _sort;
    if (by == null) return;

    int compare(Membership a, Membership b) {
      switch (by) {
        case MembershipSort.plan:
          return a.displayPlan.toLowerCase().compareTo(
            b.displayPlan.toLowerCase(),
          );
        case MembershipSort.member:
          return a.displayUser.toLowerCase().compareTo(
            b.displayUser.toLowerCase(),
          );
        case MembershipSort.price:
          return (a.totalAmount ?? a.price ?? 0).compareTo(
            b.totalAmount ?? b.price ?? 0,
          );
        case MembershipSort.starts:
          return a.startDate!.compareTo(b.startDate!);
        case MembershipSort.ends:
          return a.endDate!.compareTo(b.endDate!);
        case MembershipSort.status:
          return a.statusLabel.compareTo(b.statusLabel);
        case MembershipSort.payment:
          return a.paymentLabel.compareTo(b.paymentLabel);
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

  static bool _isMissing(MembershipSort by, Membership row) {
    switch (by) {
      case MembershipSort.price:
        return row.totalAmount == null && row.price == null;
      case MembershipSort.starts:
        return row.startDate == null;
      case MembershipSort.ends:
        return row.endDate == null;
      case MembershipSort.plan:
      case MembershipSort.member:
      case MembershipSort.status:
      case MembershipSort.payment:
        return false;
    }
  }

  List<Membership> get pageRows {
    if (!_catalogueMode) return _rows;

    final rows = visibleRows;
    if (rows.isEmpty) return const [];

    final start = (_page - 1) * _limit;
    if (start >= rows.length) return const [];
    final end = (start + _limit).clamp(0, rows.length);
    return rows.sublist(start, end);
  }

  Paged<Membership> get page {
    if (!_catalogueMode) {
      return Paged<Membership>(
        items: _rows,
        page: _serverPage,
        limit: _limit,
        total: _serverTotalItems,
        totalPages: _serverTotalPages,
      );
    }

    final total = visibleRows.length;
    return Paged<Membership>(
      items: pageRows,
      page: _page,
      limit: _limit,
      total: total,
      totalPages: total == 0 ? 0 : (total / _limit).ceil(),
    );
  }

  /// Whether another server page exists to append to the infinite list.
  bool get hasMore {
    if (_catalogueMode) return false;
    final total = page.effectiveTotalPages;
    return total > 0 && _serverPage < total;
  }

  // --- Loading ---------------------------------------------------------------

  Future<void> load() async {
    final id = ++_requestId;
    final catalogue = _needsCatalogue;

    AdminLog.state(
      'Memberships loading (${catalogue ? 'catalogue' : 'page $_page'}) → '
      'status=${_statusFilter?.slug ?? '-'} '
      'payment=${_paymentFilter?.slug ?? '-'} '
      'expiring=$_expiringSoonOnly search="${_appliedSearch.trim()}"',
    );

    _state = ViewState.loading;
    _error = null;
    _safeNotify();

    try {
      if (catalogue) {
        final all = <Membership>[];
        var page = 1;

        while (page <= catalogueMaxPages) {
          final result = await _repository.fetchMemberships(
            page: page,
            limit: cataloguePageSize,
            // Status is a real server parameter, so it still narrows the walk.
            status: _statusFilter,
          );
          all.addAll(result.items);
          if (!result.hasNext || result.items.isEmpty) break;
          page++;
        }

        if (_disposed || id != _requestId) return;

        _catalogueMode = true;
        _rows = all;
        _serverTotalItems = all.length;
        _serverTotalPages = 1;
        _state = ViewState.ready;
        _clampPage();
        AdminLog.state('Membership catalogue ready → ${all.length}');
      } else {
        final result = await _repository.fetchMemberships(
          page: _page,
          limit: _limit,
          status: _statusFilter,
        );

        if (_disposed || id != _requestId) return;

        _catalogueMode = false;
        _rows = result.items;
        _serverPage = result.page;
        _serverTotalPages = result.totalPages;
        _serverTotalItems = result.total;
        _page = result.page;
        _state = ViewState.ready;
        AdminLog.state(
          'Memberships ready → ${result.items.length} '
          '(page ${result.page}/${result.effectiveTotalPages})',
        );
      }
    } on ApiException catch (error) {
      if (_disposed || id != _requestId) return;
      _state = ViewState.failed;
      _error = error.message;
      AdminLog.failure(
        'Memberships load failed: ${error.message}',
        error: error,
      );
    } catch (error, stackTrace) {
      if (_disposed || id != _requestId) return;
      _state = ViewState.failed;
      _error = 'Could not load the memberships. Please try again.';
      AdminLog.failure(
        'Memberships load crashed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _safeNotify();
    }
  }

  /// Appends the next server page — the infinite scroll on narrow layouts.
  ///
  /// A no-op while another read is running, so a fast scroll cannot fire the
  /// same page twice.
  Future<void> loadMore() async {
    if (_catalogueMode || _loadingMore || _state.isLoading || !hasMore) return;

    final next = _serverPage + 1;
    _loadingMore = true;
    _safeNotify();

    AdminLog.state('Memberships appending page $next');

    try {
      final result = await _repository.fetchMemberships(
        page: next,
        limit: _limit,
        status: _statusFilter,
      );
      if (_disposed) return;

      // Guarded against a backend that echoes page one for an out-of-range
      // page: appending it would duplicate every row already on screen.
      final seen = _rows.map((row) => row.id).toSet();
      final fresh = result.items
          .where((row) => !seen.contains(row.id))
          .toList(growable: false);

      _rows = [..._rows, ...fresh];
      _serverPage = result.page > _serverPage ? result.page : next;
      _serverTotalPages = result.totalPages;
      _serverTotalItems = result.total;
      _state = ViewState.ready;
    } on ApiException catch (error) {
      if (_disposed) return;
      // The rows already on screen stay; only the append failed.
      AdminLog.failure('Could not append page $next', error: error);
    } catch (error, stackTrace) {
      if (_disposed) return;
      AdminLog.failure(
        'Membership append crashed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _loadingMore = false;
      _safeNotify();
    }
  }

  Future<void> loadStats({bool force = false}) async {
    if (_statsState.isLoading) return;
    if (_statsState.isReady && !force) return;

    _statsState = ViewState.loading;
    _safeNotify();

    try {
      _stats = await _repository.fetchStats();
      if (_disposed) return;
      _statsState = ViewState.ready;
    } catch (error, stackTrace) {
      if (_disposed) return;
      // The cards fall back to counting the rows, so this is not a page error.
      _statsState = ViewState.failed;
      AdminLog.failure(
        'Membership stats failed — the cards will count the rows instead',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _safeNotify();
    }
  }

  Future<void> refresh() async {
    AdminLog.ui('Memberships refresh requested');
    await Future.wait([load(), loadStats(force: true)]);
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

  /// Status is a server parameter, so this always refetches.
  void setStatusFilter(MembershipStatus? status) {
    if (_statusFilter == status) return;
    _statusFilter = status;
    _page = 1;
    load();
  }

  void setPaymentFilter(MembershipPaymentStatus? payment) =>
      _setLocalFilter(() => _paymentFilter = payment, _paymentFilter == payment);

  void setExpiringSoonOnly(bool value) =>
      _setLocalFilter(() => _expiringSoonOnly = value, _expiringSoonOnly == value);

  void _setLocalFilter(VoidCallback apply, bool unchanged) {
    if (unchanged) return;
    final previous = _needsCatalogue;
    apply();
    _page = 1;
    _reloadIfModeChanged(previouslyCatalogue: previous);
  }

  void clearFilters() {
    if (!hasFilters) return;
    AdminLog.ui('All membership filters cleared');
    _debounce?.cancel();

    final hadStatus = _statusFilter != null;
    final previous = _needsCatalogue;

    _search = '';
    _appliedSearch = '';
    _statusFilter = null;
    _paymentFilter = null;
    _expiringSoonOnly = false;
    _page = 1;

    // Dropping the status filter changes the server query, so that always
    // refetches whatever the mode was.
    if (hadStatus) {
      load();
      return;
    }
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

  void toggleSort(MembershipSort column) {
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

  /// Shows the row already in hand, then fills it in from
  /// `GET /memberships/{id}` and loads the member's other plans.
  Future<void> openMembership(Membership membership) async {
    AdminLog.ui('Membership detail opened for ${membership.id}');
    _selected = membership;
    _detailState = ViewState.loading;
    _detailError = null;
    _userHistory = const [];
    _userActive = null;
    _historyState = ViewState.idle;
    _safeNotify();

    try {
      final detail = await _repository.fetchMembership(membership.id);
      if (_disposed || _selected?.id != membership.id) return;
      _selected = membership.mergedWith(detail);
      _detailState = ViewState.ready;
    } on ApiException catch (error) {
      if (_disposed || _selected?.id != membership.id) return;
      _detailState = ViewState.failed;
      _detailError = error.message;
    } catch (error, stackTrace) {
      if (_disposed || _selected?.id != membership.id) return;
      _detailState = ViewState.failed;
      _detailError = 'Could not load this membership.';
      AdminLog.failure(
        'Membership detail crashed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _safeNotify();
    }

    final userId = _selected?.userId;
    if (userId != null && userId.isNotEmpty) {
      await loadUserPlans(userId);
    }
  }

  /// `/memberships/user/{userId}` + `/memberships/user/{userId}/active`.
  Future<void> loadUserPlans(String userId) async {
    _historyState = ViewState.loading;
    _safeNotify();

    try {
      final results = await Future.wait([
        _repository.fetchForUser(userId),
        _repository.fetchActiveForUser(userId),
      ]);
      if (_disposed || _selected?.userId != userId) return;

      _userHistory = results[0] as List<Membership>;
      _userActive = results[1] as Membership?;
      _historyState = ViewState.ready;
    } catch (error, stackTrace) {
      if (_disposed || _selected?.userId != userId) return;
      _historyState = ViewState.failed;
      AdminLog.failure(
        'Membership history failed for user $userId',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _safeNotify();
    }
  }

  void closeMembership() {
    if (_selected == null) return;
    _selected = null;
    _detailState = ViewState.idle;
    _detailError = null;
    _userHistory = const [];
    _userActive = null;
    _historyState = ViewState.idle;
    _safeNotify();
  }

  // --- Writes ----------------------------------------------------------------

  Future<Membership> create(MembershipDraft draft) async {
    AdminLog.ui('Create membership submitted');
    final created = await _repository.createMembership(draft);
    _page = 1;
    await refresh();
    return created;
  }

  Future<Membership> update(String id, MembershipDraft draft) async {
    AdminLog.ui('Update membership $id submitted');
    final updated = await _repository.updateMembership(id, draft);

    if (_selected?.id == id) {
      _selected = _selected!.mergedWith(updated);
      _safeNotify();
    }

    await load();
    return updated;
  }

  /// `PATCH /{id}/status` — optimistic, reverted if the server refuses.
  Future<void> setStatus(String id, MembershipStatus status) async {
    final current = _rowFor(id);
    if (current == null || current.status == status) return;

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

    // The counters move with the status, so they are re-read rather than
    // adjusted by hand.
    unawaited(loadStats(force: true));
  }

  /// `PATCH /{id}/payment-status` — optimistic, same revert rule.
  Future<void> setPaymentStatus(
    String id,
    MembershipPaymentStatus payment,
  ) async {
    final current = _rowFor(id);
    if (current == null || current.paymentStatus == payment) return;

    _busyRows.add(id);
    _replaceRow(id, current.copyWith(paymentStatusRaw: payment.slug));
    _safeNotify();

    try {
      await _repository.setPaymentStatus(id, payment);
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

    unawaited(loadStats(force: true));
  }

  /// `PATCH /{id}/cancel` — the reason is required by the route.
  Future<void> cancel(String id, String reason) async {
    AdminLog.ui('Cancel membership $id confirmed');
    _busyRows.add(id);
    _safeNotify();

    try {
      await _repository.cancelMembership(id, reason);
    } finally {
      _busyRows.remove(id);
      _safeNotify();
    }

    await refresh();
    if (_selected?.id == id) await _refreshSelected(id);
  }

  /// `POST /{id}/renew` — refreshes the detail and the list, in that order.
  Future<void> renew(
    String id, {
    required int validityDays,
    required num totalAmount,
  }) async {
    AdminLog.ui('Renew membership $id submitted');
    _busyRows.add(id);
    _safeNotify();

    try {
      await _repository.renewMembership(
        id,
        validityDays: validityDays,
        totalAmount: totalAmount,
      );
    } finally {
      _busyRows.remove(id);
      _safeNotify();
    }

    if (_selected?.id == id) await _refreshSelected(id);
    await refresh();
  }

  Future<void> delete(String id) async {
    AdminLog.ui('Delete membership $id confirmed');

    // Optimistic: the row disappears immediately and is put back if the call
    // fails, so a failed delete never silently loses a row from the table.
    final previous = _rows;
    _rows = _rows.where((row) => row.id != id).toList();
    if (_selected?.id == id) closeMembership();
    _clampPage();
    _safeNotify();

    try {
      await _repository.deleteMembership(id);
    } catch (error) {
      if (!_disposed) {
        AdminLog.failure('Delete failed — restoring the row', error: error);
        _rows = previous;
        _safeNotify();
      }
      rethrow;
    }

    await refresh();
  }

  /// `POST /memberships/check-expired`. Returns how many rows the sweep
  /// changed, or null when the response did not say.
  Future<int?> runExpirySweep() async {
    AdminLog.ui('Expiry sweep requested');
    final changed = await _repository.checkExpired();
    await refresh();
    return changed;
  }

  Future<void> _refreshSelected(String id) async {
    try {
      final detail = await _repository.fetchMembership(id);
      if (_disposed || _selected?.id != id) return;
      _selected = _selected!.mergedWith(detail);
      _detailState = ViewState.ready;
      _safeNotify();
    } catch (error) {
      AdminLog.failure('Could not refresh membership $id', error: error);
    }
  }

  Membership? _rowFor(String id) {
    for (final row in _rows) {
      if (row.id == id) return row;
    }
    return _selected?.id == id ? _selected : null;
  }

  void _replaceRow(String id, Membership next) {
    _rows = _rows
        .map((row) => row.id == id ? next : row)
        .toList(growable: false);
    if (_selected?.id == id) _selected = _selected!.mergedWith(next);
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    AdminLog.life('MembershipsController disposed');
    super.dispose();
  }
}
