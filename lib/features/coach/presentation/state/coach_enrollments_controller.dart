import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../core/coach_log.dart';
import '../../domain/entities/coach_enrollment.dart';
import '../../domain/repositories/coach_dashboard_repository.dart';
import 'coach_view_state.dart';

/// Student Enrollments — one month at a time, grouped batch-wise.
///
/// The endpoint is not paginated: it answers the whole month in one object,
/// along with the index of every month that has data. So there is no
/// `loadMore` here — changing the month is a fresh load.
///
/// The requested month is a **suggestion**. When it has no data the backend
/// falls back (to the current month, else the most recent month that does), so
/// the selection is always read back from the response rather than assumed.
class CoachEnrollmentsController extends ChangeNotifier {
  CoachEnrollmentsController(this._repository) {
    CoachLog.life('CoachEnrollmentsController created');
  }

  final CoachDashboardRepository _repository;

  static const Duration searchDebounce = Duration(milliseconds: 400);

  /// The enrollment statuses the month can be filtered by. `null` is "all".
  static const List<String> statusFilters = [
    'Active',
    'Completed',
    'Dropped',
    'Transferred',
  ];

  CoachViewState _state = CoachViewState.idle;
  CoachEnrollmentMonthView _view = CoachEnrollmentMonthView.empty;
  String? _error;

  /// What was last asked for. May differ from `view.month`, which is what the
  /// backend actually answered with.
  String? _requestedMonth;

  String _search = '';
  String? _status;

  bool _refreshing = false;
  bool _disposed = false;
  Timer? _debounce;
  int _requestId = 0;

  /// Batch ids the user has collapsed. Collapsed rather than expanded state is
  /// tracked so a newly arrived batch defaults to open.
  final Set<int> _collapsed = {};

  CoachViewState get state => _state;
  CoachEnrollmentMonthView get view => _view;
  String? get error => _error;

  String get search => _search;
  String? get status => _status;
  bool get refreshing => _refreshing;

  /// The month actually being shown.
  String get month => _view.month;
  String get monthLabel => _view.displayLabel;

  List<CoachEnrollmentMonth> get months => _view.months;
  CoachEnrollmentSummary get summary => _view.summary;
  List<CoachEnrollmentGroup> get batches => _view.batches;

  bool get isFiltered => _search.trim().isNotEmpty || _status != null;

  bool get isEmpty => _state.isReady && _view.isEmpty;

  /// No enrollments in any month, as opposed to none in the selected one —
  /// the two need very different wording.
  bool get hasNoHistory => _state.isReady && _view.hasNoHistory;

  bool isCollapsed(int batchId) => _collapsed.contains(batchId);

  void toggleGroup(int batchId) {
    if (!_collapsed.remove(batchId)) _collapsed.add(batchId);
    _notify();
  }

  void expandAll() {
    if (_collapsed.isEmpty) return;
    _collapsed.clear();
    _notify();
  }

  void collapseAll() {
    _collapsed
      ..clear()
      ..addAll(_view.batches.map((b) => b.batchId));
    _notify();
  }

  Future<void> load({bool silent = false}) async {
    if (_disposed) return;

    final request = ++_requestId;

    _refreshing = silent && !_view.isEmpty;
    if (!_refreshing) _state = CoachViewState.loading;
    _notify();

    try {
      final result = await _repository.getEnrollmentsByMonth(
        month: _requestedMonth,
        search: _search.trim().isEmpty ? null : _search.trim(),
        status: _status,
      );

      if (request != _requestId || _disposed) return;

      _view = result;
      // Adopt whatever the backend settled on, so the picker and the heading
      // cannot drift from the rows below them.
      _requestedMonth = result.month.isEmpty ? _requestedMonth : result.month;
      _error = null;
      _state = CoachViewState.ready;
      CoachLog.state('Enrollments → $result');
    } catch (e) {
      if (request != _requestId || _disposed) return;

      _error = _describe(e);
      _state = CoachViewState.failed;
      CoachLog.failure('Enrollments failed', error: e);
    } finally {
      if (request == _requestId && !_disposed) {
        _refreshing = false;
        _notify();
      }
    }
  }

  Future<void> refresh() => load(silent: true);

  /// [value] is `yyyy-MM`.
  void setMonth(String value) {
    if (value == _requestedMonth) return;
    _requestedMonth = value;
    // Collapse state belongs to the month that was on screen.
    _collapsed.clear();
    _debounce?.cancel();
    CoachLog.ui('Enrollment month → $value');
    load();
  }

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

  /// Passing the currently selected status clears the filter.
  void setStatus(String? value) {
    final next = value == _status ? null : value;
    if (next == _status) return;

    _status = next;
    _debounce?.cancel();
    load();
  }

  void clearFilters() {
    _debounce?.cancel();
    if (!isFiltered) return;
    _search = '';
    _status = null;
    load();
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
    CoachLog.life('CoachEnrollmentsController disposed');
    super.dispose();
  }
}
