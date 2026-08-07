import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../core/coach_log.dart';
import '../../domain/entities/coach_fee.dart';
import '../../domain/entities/coach_paged.dart';
import '../../domain/repositories/coach_dashboard_repository.dart';
import 'coach_view_state.dart';

/// Fee records for the coach's own students.
///
/// One controller serves both fee screens, because they are the same list
/// under different filters:
///
/// * **Fees Management** — everything, filterable by payment status.
/// * **Fees Approval** — pinned to `approvalStatus == Pending`, and read-only:
///   a coach cannot approve or reject (403), only see what is waiting.
///
/// [approvalLocked] is what tells the two apart, so the approval queue's
/// filter cannot be cleared out from under it.
class CoachFeesController extends ChangeNotifier {
  CoachFeesController(
    this._repository, {
    CoachApprovalStatus? lockedApproval,
  }) : _approvalStatus = lockedApproval,
       _approvalLocked = lockedApproval != null {
    CoachLog.life('CoachFeesController created (locked: $_approvalLocked)');
  }

  final CoachDashboardRepository _repository;

  static const Duration searchDebounce = Duration(milliseconds: 400);
  static const int pageSize = 20;

  CoachViewState _state = CoachViewState.idle;
  CoachPaged<CoachFee> _page = const CoachPaged<CoachFee>();
  List<CoachFee> _fees = const [];
  String? _error;

  CoachFeeStats _stats = CoachFeeStats.empty;

  String _search = '';
  CoachPaymentStatus? _paymentStatus;
  CoachApprovalStatus? _approvalStatus;
  final bool _approvalLocked;

  bool _loadingMore = false;
  bool _refreshing = false;
  bool _disposed = false;
  Timer? _debounce;
  int _requestId = 0;

  CoachViewState get state => _state;
  List<CoachFee> get fees => _fees;
  String? get error => _error;
  CoachFeeStats get stats => _stats;

  String get search => _search;
  CoachPaymentStatus? get paymentStatus => _paymentStatus;
  CoachApprovalStatus? get approvalStatus => _approvalStatus;

  /// True on the Fees Approval screen, where the approval filter is fixed.
  bool get approvalLocked => _approvalLocked;

  bool get loadingMore => _loadingMore;
  bool get refreshing => _refreshing;
  bool get hasMore => _page.hasNext;
  int get total => _page.total;

  bool get isFiltered =>
      _search.trim().isNotEmpty ||
      _paymentStatus != null ||
      (!_approvalLocked && _approvalStatus != null);

  bool get isEmpty => _state.isReady && _fees.isEmpty;

  /// Collected in full but still not signed off — the rows whose students
  /// cannot yet get through the gate.
  int get paidButUnapprovedCount =>
      _fees.where((f) => f.paidButUnapproved).length;

  // ---------------------------------------------------------------------------
  // Loading
  // ---------------------------------------------------------------------------

  Future<void> load({bool silent = false}) async {
    if (_disposed) return;

    final request = ++_requestId;

    _refreshing = silent && _fees.isNotEmpty;
    if (!_refreshing) _state = CoachViewState.loading;
    _notify();

    // The stats block is a separate endpoint; it failing must not take the
    // list down, so it is awaited alongside and swallowed on its own.
    final statsFuture = _loadStats();

    try {
      final result = await _repository.getFees(
        page: 1,
        limit: pageSize,
        paymentStatus: _paymentStatus,
        approvalStatus: _approvalStatus,
        search: _search.trim().isEmpty ? null : _search.trim(),
      );

      if (request != _requestId || _disposed) return;

      _page = result;
      _fees = result.items;
      _error = null;
      _state = CoachViewState.ready;
    } catch (e) {
      if (request != _requestId || _disposed) return;

      _error = _describe(e);
      _state = CoachViewState.failed;
      CoachLog.failure('Fees failed', error: e);
    } finally {
      await statsFuture;
      if (request == _requestId && !_disposed) {
        _refreshing = false;
        _notify();
      }
    }
  }

  Future<void> refresh() => load(silent: true);

  Future<void> _loadStats() async {
    try {
      final stats = await _repository.getFeeStats();
      if (!_disposed) _stats = stats;
    } catch (e) {
      // Left at whatever was last known rather than zeroed — stale counters
      // beat counters that suddenly claim there are none.
      CoachLog.failure('Fee stats failed', error: e);
    }
  }

  Future<void> loadMore() async {
    if (_disposed || _loadingMore || !_page.hasNext) return;
    if (_state.isLoading) return;

    final request = _requestId;
    _loadingMore = true;
    _notify();

    try {
      final result = await _repository.getFees(
        page: _page.page + 1,
        limit: pageSize,
        paymentStatus: _paymentStatus,
        approvalStatus: _approvalStatus,
        search: _search.trim().isEmpty ? null : _search.trim(),
      );

      if (request != _requestId || _disposed) return;

      _page = result;
      _fees = [..._fees, ...result.items];
    } catch (e) {
      if (request != _requestId || _disposed) return;
      _error = _describe(e);
      CoachLog.failure('Fees page failed', error: e);
    } finally {
      if (!_disposed) {
        _loadingMore = false;
        _notify();
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Filters
  // ---------------------------------------------------------------------------

  void onSearchChanged(String value) {
    if (value == _search) return;
    _search = value;
    _notify();

    _debounce?.cancel();
    _debounce = Timer(searchDebounce, load);
  }

  void clearSearch() {
    _debounce?.cancel();
    if (_search.isEmpty) return;
    _search = '';
    load();
  }

  /// Passing the currently selected status clears the filter, so chips toggle.
  void setPaymentStatus(CoachPaymentStatus? value) {
    final next = value == _paymentStatus ? null : value;
    if (next == _paymentStatus) return;
    _paymentStatus = next;
    _debounce?.cancel();
    CoachLog.ui('Fee payment filter → ${next?.slug ?? 'all'}');
    load();
  }

  void setApprovalStatus(CoachApprovalStatus? value) {
    // The approval queue's own filter is not the user's to change.
    if (_approvalLocked) return;

    final next = value == _approvalStatus ? null : value;
    if (next == _approvalStatus) return;
    _approvalStatus = next;
    _debounce?.cancel();
    load();
  }

  void clearFilters() {
    _debounce?.cancel();
    if (!isFiltered) return;
    _search = '';
    _paymentStatus = null;
    if (!_approvalLocked) _approvalStatus = null;
    load();
  }

  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------

  /// Records a payment.
  ///
  /// Reloads rather than patching the row in place: the server also resets the
  /// record's approval to `Pending`, so a locally-patched row would show the
  /// old approval state and mislead the coach about whether the student's gate
  /// pass works.
  Future<void> recordPayment({
    required int id,
    required CoachPaymentDraft draft,
  }) async {
    await _repository.recordPayment(id: id, draft: draft);
    await load(silent: true);
  }

  /// Edits the record itself — validity and notes, not the payment.
  Future<void> updateRecord({
    required int id,
    String? validTill,
    String? notes,
  }) async {
    await _repository.updateFeeRecord(
      id: id,
      validTill: validTill,
      notes: notes,
    );
    await load(silent: true);
  }

  static String _describe(Object error) => error is ApiException
      ? error.message
      : 'Something went wrong. Please try again.';

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    CoachLog.life('CoachFeesController disposed');
    super.dispose();
  }
}
