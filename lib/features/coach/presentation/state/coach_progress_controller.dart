import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../core/coach_log.dart';
import '../../domain/entities/coach_option.dart';
import '../../domain/entities/coach_paged.dart';
import '../../domain/entities/coach_progress.dart';
import '../../domain/repositories/coach_dashboard_repository.dart';
import 'coach_view_state.dart';

/// Student Progress — the coach's assessment log, plus recording new ones.
///
/// Each record is a **dated assessment**, not a student's current state: the
/// same student appears once per assessment, and the improvement figure is the
/// delta against their previous one for the same sport. So the list is not
/// de-duplicated by student.
class CoachProgressController extends ChangeNotifier {
  CoachProgressController(this._repository) {
    CoachLog.life('CoachProgressController created');
  }

  final CoachDashboardRepository _repository;

  static const int pageSize = 20;

  CoachViewState _state = CoachViewState.idle;
  CoachPaged<CoachProgress> _page = const CoachPaged<CoachProgress>();
  List<CoachProgress> _records = const [];
  String? _error;

  CoachOption? _student;
  CoachOption? _sport;

  bool _loadingMore = false;
  bool _refreshing = false;
  bool _disposed = false;
  int _requestId = 0;

  // ── Pickers, loaded once and shared with the record form ──────────────────
  CoachViewState _optionsState = CoachViewState.idle;
  List<CoachOption> _students = const [];
  List<CoachOption> _sports = const [];

  CoachViewState get state => _state;
  List<CoachProgress> get records => _records;
  String? get error => _error;

  CoachOption? get student => _student;
  CoachOption? get sport => _sport;

  bool get loadingMore => _loadingMore;
  bool get refreshing => _refreshing;
  bool get hasMore => _page.hasNext;
  int get total => _page.total;

  bool get isFiltered => _student != null || _sport != null;
  bool get isEmpty => _state.isReady && _records.isEmpty;

  CoachViewState get optionsState => _optionsState;
  List<CoachOption> get students => _students;
  List<CoachOption> get sports => _sports;

  /// Whether an assessment can be recorded at all. Both a student and a sport
  /// are required by the backend, so with either list empty the form is
  /// pointless and the button is hidden rather than made to fail.
  bool get canRecord => _students.isNotEmpty && _sports.isNotEmpty;

  /// Mean score across the loaded records — a read of the coach's roster right
  /// now, not a historical average.
  num? get averageScore {
    if (_records.isEmpty) return null;
    final sum = _records.fold<num>(0, (a, r) => a + r.currentScore);
    return sum / _records.length;
  }

  int get improvedCount => _records.where((r) => r.improved).length;
  int get declinedCount => _records.where((r) => r.declined).length;

  // ---------------------------------------------------------------------------
  // Loading
  // ---------------------------------------------------------------------------

  Future<void> load({bool silent = false}) async {
    if (_disposed) return;

    final request = ++_requestId;

    _refreshing = silent && _records.isNotEmpty;
    if (!_refreshing) _state = CoachViewState.loading;
    _notify();

    try {
      final result = await _repository.getProgress(
        page: 1,
        limit: pageSize,
        studentId: _student?.id,
        sportId: _sport?.id,
      );

      if (request != _requestId || _disposed) return;

      _page = result;
      _records = result.items;
      _error = null;
      _state = CoachViewState.ready;
    } catch (e) {
      if (request != _requestId || _disposed) return;

      _error = _describe(e);
      _state = CoachViewState.failed;
      CoachLog.failure('Student progress failed', error: e);
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
      final result = await _repository.getProgress(
        page: _page.page + 1,
        limit: pageSize,
        studentId: _student?.id,
        sportId: _sport?.id,
      );

      if (request != _requestId || _disposed) return;

      _page = result;
      _records = [..._records, ...result.items];
    } catch (e) {
      if (request != _requestId || _disposed) return;
      _error = _describe(e);
      CoachLog.failure('Student progress page failed', error: e);
    } finally {
      if (!_disposed) {
        _loadingMore = false;
        _notify();
      }
    }
  }

  /// The student and sport pickers, used by both the filter row and the record
  /// form. Loaded once — the lists are short and already scoped to this coach.
  Future<void> loadOptions() async {
    if (_disposed || _optionsState.isLoading) return;

    _optionsState = CoachViewState.loading;
    _notify();

    try {
      final results = await Future.wait([
        _repository.searchStudents(),
        _repository.searchSports(),
      ]);
      if (_disposed) return;

      _students = results[0];
      _sports = results[1];
      _optionsState = CoachViewState.ready;
    } catch (e) {
      if (_disposed) return;
      // Not surfaced as a page error: the log still reads fine without the
      // pickers, only recording and filtering are unavailable.
      _optionsState = CoachViewState.failed;
      CoachLog.failure('Progress pickers failed', error: e);
    }

    _notify();
  }

  // ---------------------------------------------------------------------------
  // Filters
  // ---------------------------------------------------------------------------

  void setStudent(CoachOption? value) {
    if (value?.id == _student?.id) return;
    _student = value;
    CoachLog.ui('Progress student filter → ${value?.name ?? 'all'}');
    load();
  }

  void setSport(CoachOption? value) {
    if (value?.id == _sport?.id) return;
    _sport = value;
    load();
  }

  void clearFilters() {
    if (!isFiltered) return;
    _student = null;
    _sport = null;
    load();
  }

  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------

  /// Records a new assessment and reloads. Throws so the form can stay open
  /// and explain the failure.
  Future<void> create(CoachProgressDraft draft) async {
    await _repository.createProgress(draft);
    await load(silent: true);
  }

  /// Edits an existing assessment. [id] is the record's id, not the student's.
  Future<void> update(int id, CoachProgressDraft draft) async {
    await _repository.updateProgress(id, draft);
    await load(silent: true);
  }

  /// Deletes an assessment.
  ///
  /// The row is removed optimistically so the list does not sit still while
  /// the request is in flight, and put back if the server refuses — which it
  /// will with a 403 for a student outside this coach's roster.
  Future<void> delete(int id) async {
    final previous = _records;
    final previousTotal = _page.total;

    _records = _records.where((r) => r.id != id).toList(growable: false);
    _page = _page.copyWith(total: previousTotal > 0 ? previousTotal - 1 : 0);
    _notify();

    try {
      await _repository.deleteProgress(id);
      CoachLog.success('Deleted progress $id');
    } catch (e) {
      _records = previous;
      _page = _page.copyWith(total: previousTotal);
      _notify();
      CoachLog.failure('Delete progress $id failed', error: e);
      rethrow;
    }
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
    CoachLog.life('CoachProgressController disposed');
    super.dispose();
  }
}
