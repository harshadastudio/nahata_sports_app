import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../core/employee_log.dart';
import '../../domain/entities/employee_paged.dart';
import 'employee_view_state.dart';

/// The paging every employee list screen shares.
///
/// Eight of these screens — bookings, payments, attendance, coaches, enquiries,
/// fees, users, notifications — are the same machine over a different row type:
/// fetch page 1, append on scroll, re-fetch from page 1 when a filter moves.
/// Writing that eight times would mean eight places for the same off-by-one to
/// hide, so a subclass supplies only [fetchPage] and its own filter fields.
///
/// Two invariants the subclasses depend on:
///
/// * **Lists append, they do not page.** [items] accumulates across pages;
///   nothing reads the last page's rows directly.
/// * **Every request is sequence-stamped.** A slow answer for "ri" must never
///   land after a fast one for "riya" and repopulate the list with stale rows,
///   so a response whose stamp is not the current one is dropped on the floor.
abstract class EmployeeListController<T> extends ChangeNotifier {
  EmployeeListController({this.pageSize = 20});

  final int pageSize;

  static const Duration searchDebounce = Duration(milliseconds: 400);

  /// Fetches one page with the subclass's current filters applied.
  Future<EmployeePaged<T>> fetchPage(int page);

  /// Called after a successful first-page load, for a subclass that has a
  /// second thing to pull alongside the list (fee stats, an audience list).
  /// Runs after the rows are already on screen, so it can never delay them.
  Future<void> onFirstPageLoaded() async {}

  EmployeeViewState _state = EmployeeViewState.idle;
  EmployeePaged<T> _page = const EmployeePaged();
  List<T> _items = const [];
  String? _error;

  bool _loadingMore = false;
  bool _refreshing = false;
  bool _disposed = false;

  Timer? _debounce;

  /// Guards against an out-of-order response overwriting a newer one.
  int _requestId = 0;

  EmployeeViewState get state => _state;
  List<T> get items => _items;
  String? get error => _error;

  bool get loadingMore => _loadingMore;
  bool get refreshing => _refreshing;
  bool get hasMore => _page.hasNext;
  bool get isDisposed => _disposed;

  /// Rows matching the current filters, as the server counts them — which is
  /// not `items.length` until the whole list has been scrolled in.
  int get total => _page.total;

  /// True only for a genuinely empty result, not for a list still loading.
  bool get isEmpty => _state.isReady && _items.isEmpty;

  /// Whether to show the full-page shimmer, as opposed to the hairline bar.
  bool get isInitialLoad => _state.isLoading && _items.isEmpty;

  // ───────────────────────────────────────────────────────────────────────────
  // Loading
  // ───────────────────────────────────────────────────────────────────────────

  /// Loads the first page, replacing whatever is on screen.
  ///
  /// [silent] keeps the current rows visible and shows the refresh line instead
  /// — used by pull-to-refresh and by a re-load after a successful write, where
  /// blanking the list would lose the user's place.
  Future<void> load({bool silent = false}) async {
    if (_disposed) return;

    final request = ++_requestId;

    _refreshing = silent && _items.isNotEmpty;
    if (!_refreshing) _state = EmployeeViewState.loading;
    notify();

    try {
      final result = await fetchPage(1);

      // A newer request has already been fired — drop this answer.
      if (request != _requestId || _disposed) return;

      _page = result;
      _items = result.items;
      _error = null;
      _state = EmployeeViewState.ready;
    } catch (e) {
      if (request != _requestId || _disposed) return;

      _error = describeError(e);
      _state = EmployeeViewState.failed;
      EmployeeLog.failure('$runtimeType first page failed', error: e);
    } finally {
      if (request == _requestId && !_disposed) {
        _refreshing = false;
        notify();
      }
    }

    if (request == _requestId && !_disposed && _state.isReady) {
      await onFirstPageLoaded();
    }
  }

  Future<void> refresh() => load(silent: true);

  /// Re-runs the query from page 1 after a filter changed. Never silent — the
  /// rows on screen answer a question the user has just stopped asking.
  Future<void> reload() {
    _debounce?.cancel();
    return load();
  }

  /// Appends the next page. Safe to call from a scroll listener — a no-op while
  /// one is already in flight or when the list is exhausted.
  Future<void> loadMore() async {
    if (_disposed || _loadingMore || !_page.hasNext) return;
    if (_state.isLoading) return;

    final request = _requestId;
    _loadingMore = true;
    notify();

    try {
      final result = await fetchPage(_page.page + 1);

      // The filters changed underneath us — this page answers a query the user
      // has already moved on from.
      if (request != _requestId || _disposed) return;

      _page = result;
      _items = [..._items, ...result.items];
      EmployeeLog.state(
        '$runtimeType → page ${result.page}, '
        '${_items.length}/${result.total} loaded',
      );
    } catch (e) {
      if (request != _requestId || _disposed) return;
      // A failed *append* keeps the rows already on screen and only reports
      // itself; it must not tear the list down.
      _error = describeError(e);
      EmployeeLog.failure('$runtimeType page failed', error: e);
    } finally {
      if (!_disposed) {
        _loadingMore = false;
        notify();
      }
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Local edits
  // ───────────────────────────────────────────────────────────────────────────

  /// Swaps one row in place after a write, so an approval or a status change
  /// shows immediately without re-fetching the whole list and losing scroll.
  ///
  /// [matches] identifies the row; [update] returns its replacement.
  @protected
  void replaceItem(bool Function(T) matches, T Function(T) update) {
    var changed = false;
    final next = _items.map((item) {
      if (!matches(item)) return item;
      changed = true;
      return update(item);
    }).toList(growable: false);

    if (!changed) return;
    _items = next;
    notify();
  }

  /// Drops a row after a delete, and decrements the total so the header count
  /// does not claim a record that is gone.
  @protected
  void removeItem(bool Function(T) matches) {
    final next = _items.where((item) => !matches(item)).toList(growable: false);
    if (next.length == _items.length) return;

    _items = next;
    _page = _page.copyWith(
      total: _page.total > 0 ? _page.total - 1 : 0,
    );
    notify();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Search
  // ───────────────────────────────────────────────────────────────────────────

  /// Runs [action] once the user stops typing.
  ///
  /// The subclass owns the search string — it has to go into the query — but
  /// the timer lives here so every screen waits the same beat.
  @protected
  void debounce(VoidCallback action) {
    _debounce?.cancel();
    _debounce = Timer(searchDebounce, action);
  }

  @protected
  void cancelDebounce() => _debounce?.cancel();

  // ───────────────────────────────────────────────────────────────────────────
  // Plumbing
  // ───────────────────────────────────────────────────────────────────────────

  /// The user-facing text for a thrown error. An [ApiException] already carries
  /// the server's own wording, which is more useful than anything invented
  /// here — it names the batch that was full, or the permission that was
  /// missing.
  @protected
  static String describeError(Object error) => error is ApiException
      ? error.message
      : 'Something went wrong. Please try again.';

  /// Reports [error] to the caller as a message, after logging it.
  ///
  /// Used by write actions, which return a message rather than setting the
  /// list's error state — a failed approval must not blank the queue.
  @protected
  String reportFailure(String what, Object error) {
    EmployeeLog.failure(what, error: error);
    return describeError(error);
  }

  @protected
  void notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    EmployeeLog.life('$runtimeType disposed');
    super.dispose();
  }
}
