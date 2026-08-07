import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../core/coach_log.dart';
import '../../domain/entities/coach_paged.dart';
import '../../domain/entities/coach_student.dart';
import '../../domain/repositories/coach_dashboard_repository.dart';
import 'coach_view_state.dart';

/// The My Students roster.
///
/// The list scrolls infinitely rather than paging: each load **appends**, so
/// [students] accumulates across pages and is not read off [page] directly.
///
/// Search is debounced and every request is stamped with a sequence number —
/// a slow response for "ri" must not land after a fast one for "riya" and
/// repopulate the list with stale rows.
class CoachStudentsController extends ChangeNotifier {
  CoachStudentsController(this._repository) {
    CoachLog.life('CoachStudentsController created');
  }

  final CoachDashboardRepository _repository;

  static const Duration searchDebounce = Duration(milliseconds: 400);
  static const int pageSize = 20;

  /// The enrollment statuses the roster can be filtered by. `null` is "all".
  static const List<String> statusFilters = [
    'Active',
    'Completed',
    'Dropped',
    'Transferred',
  ];

  CoachViewState _state = CoachViewState.idle;
  CoachPaged<CoachStudent> _page = const CoachPaged<CoachStudent>();
  List<CoachStudent> _students = const [];
  String? _error;

  String _search = '';
  String? _status;
  bool _loadingMore = false;
  bool _refreshing = false;
  bool _disposed = false;

  Timer? _debounce;

  /// Guards against an out-of-order response overwriting a newer one.
  int _requestId = 0;

  CoachViewState get state => _state;
  List<CoachStudent> get students => _students;
  String? get error => _error;
  String get search => _search;
  String? get status => _status;

  bool get loadingMore => _loadingMore;
  bool get refreshing => _refreshing;
  bool get hasMore => _page.hasNext;

  /// Enrollment rows, not distinct people — a student in two of this coach's
  /// batches is counted twice, which is what the backend reports.
  int get total => _page.total;

  bool get isFiltered => _search.trim().isNotEmpty || _status != null;

  bool get isEmpty => _state.isReady && _students.isEmpty;

  // ---------------------------------------------------------------------------
  // Loading
  // ---------------------------------------------------------------------------

  /// Loads the first page, replacing whatever is on screen.
  Future<void> load({bool silent = false}) async {
    if (_disposed) return;

    final request = ++_requestId;

    _refreshing = silent && _students.isNotEmpty;
    if (!_refreshing) _state = CoachViewState.loading;
    _notify();

    try {
      final result = await _repository.getStudents(
        page: 1,
        limit: pageSize,
        search: _search.trim().isEmpty ? null : _search.trim(),
        status: _status,
      );

      // A newer request has already been fired — drop this answer.
      if (request != _requestId || _disposed) return;

      _page = result;
      _students = result.items;
      _error = null;
      _state = CoachViewState.ready;
    } catch (e) {
      if (request != _requestId || _disposed) return;

      _error = _describe(e);
      _state = CoachViewState.failed;
      CoachLog.failure('My students failed', error: e);
    } finally {
      if (request == _requestId && !_disposed) {
        _refreshing = false;
        _notify();
      }
    }
  }

  Future<void> refresh() => load(silent: true);

  /// Appends the next page. Safe to call from a scroll listener — it is a
  /// no-op while one is already in flight or when the list is exhausted.
  Future<void> loadMore() async {
    if (_disposed || _loadingMore || !_page.hasNext) return;
    if (_state.isLoading) return;

    final request = _requestId;
    _loadingMore = true;
    _notify();

    try {
      final result = await _repository.getStudents(
        page: _page.page + 1,
        limit: pageSize,
        search: _search.trim().isEmpty ? null : _search.trim(),
        status: _status,
      );

      // The filter changed underneath us — this page belongs to a query the
      // user has already moved on from.
      if (request != _requestId || _disposed) return;

      _page = result;
      _students = [..._students, ...result.items];
      CoachLog.state('My students → page ${result.page}, '
          '${_students.length}/${result.total} loaded');
    } catch (e) {
      if (request != _requestId || _disposed) return;
      // A failed *append* keeps the rows already on screen and only reports
      // itself; it must not tear the list down.
      _error = _describe(e);
      CoachLog.failure('My students page failed', error: e);
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
    _debounce = Timer(searchDebounce, () {
      CoachLog.ui('Student search → "${_search.trim()}"');
      load();
    });
  }

  void clearSearch() {
    _debounce?.cancel();
    if (_search.isEmpty) return;
    _search = '';
    load();
  }

  /// Passing the currently selected status clears the filter, so the chip
  /// row toggles.
  void setStatus(String? value) {
    final next = value == _status ? null : value;
    if (next == _status) return;

    _status = next;
    _debounce?.cancel();
    CoachLog.ui('Student status filter → ${next ?? 'all'}');
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
    CoachLog.life('CoachStudentsController disposed');
    super.dispose();
  }
}
