import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../core/coach_log.dart';
import '../../domain/entities/coach_batch.dart';
import '../../domain/entities/coach_paged.dart';
import '../../domain/repositories/coach_dashboard_repository.dart';
import 'coach_view_state.dart';

/// My Schedule — the coach's batches.
///
/// There is no per-session table behind this: the backend has batches with a
/// free-text day and time, so the screen presents batches rather than a
/// timetable, and the entity keeps that distinction explicit.
class CoachScheduleController extends ChangeNotifier {
  CoachScheduleController(this._repository) {
    CoachLog.life('CoachScheduleController created');
  }

  final CoachDashboardRepository _repository;

  static const int pageSize = 20;

  /// The batch statuses the list can be filtered by. `null` is "all".
  static const List<String> statusFilters = ['Active', 'Inactive', 'Completed'];

  CoachViewState _state = CoachViewState.idle;
  CoachPaged<CoachBatch> _page = const CoachPaged<CoachBatch>();
  List<CoachBatch> _batches = const [];
  String? _error;

  String? _status;
  bool _loadingMore = false;
  bool _refreshing = false;
  bool _disposed = false;
  int _requestId = 0;

  CoachViewState get state => _state;
  List<CoachBatch> get batches => _batches;
  String? get error => _error;
  String? get status => _status;

  bool get loadingMore => _loadingMore;
  bool get refreshing => _refreshing;
  bool get hasMore => _page.hasNext;
  int get total => _page.total;

  bool get isFiltered => _status != null;
  bool get isEmpty => _state.isReady && _batches.isEmpty;

  /// Total students across every loaded batch. Enrollment rows, so a student
  /// in two batches counts twice — the same basis the rest of the dashboard
  /// counts on.
  int get totalStudents =>
      _batches.fold(0, (sum, batch) => sum + batch.studentCount);

  int get activeCount => _batches.where((b) => b.isActive).length;

  Future<void> load({bool silent = false}) async {
    if (_disposed) return;

    final request = ++_requestId;

    _refreshing = silent && _batches.isNotEmpty;
    if (!_refreshing) _state = CoachViewState.loading;
    _notify();

    try {
      final result = await _repository.getBatches(
        page: 1,
        limit: pageSize,
        status: _status,
      );

      if (request != _requestId || _disposed) return;

      _page = result;
      _batches = result.items;
      _error = null;
      _state = CoachViewState.ready;
    } catch (e) {
      if (request != _requestId || _disposed) return;

      _error = _describe(e);
      _state = CoachViewState.failed;
      CoachLog.failure('My schedule failed', error: e);
    } finally {
      if (request == _requestId && !_disposed) {
        _refreshing = false;
        _notify();
      }
    }
  }

  Future<void> refresh() => load(silent: true);

  Future<void> loadMore() async {
    if (_disposed || _loadingMore || !_page.hasNext) return;
    if (_state.isLoading) return;

    final request = _requestId;
    _loadingMore = true;
    _notify();

    try {
      final result = await _repository.getBatches(
        page: _page.page + 1,
        limit: pageSize,
        status: _status,
      );

      if (request != _requestId || _disposed) return;

      _page = result;
      _batches = [..._batches, ...result.items];
    } catch (e) {
      if (request != _requestId || _disposed) return;
      // A failed append keeps what is already on screen.
      _error = _describe(e);
      CoachLog.failure('My schedule page failed', error: e);
    } finally {
      if (!_disposed) {
        _loadingMore = false;
        _notify();
      }
    }
  }

  /// Passing the currently selected status clears the filter, so chips toggle.
  void setStatus(String? value) {
    final next = value == _status ? null : value;
    if (next == _status) return;

    _status = next;
    CoachLog.ui('Batch status filter → ${next ?? 'all'}');
    load();
  }

  void clearFilters() {
    if (!isFiltered) return;
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
    CoachLog.life('CoachScheduleController disposed');
    super.dispose();
  }
}
