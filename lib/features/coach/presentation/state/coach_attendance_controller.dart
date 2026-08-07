import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../core/coach_log.dart';
import '../../domain/entities/coach_attendance.dart';
import '../../domain/entities/coach_option.dart';
import '../../domain/entities/coach_paged.dart';
import '../../domain/entities/coach_student.dart';
import '../../domain/repositories/coach_dashboard_repository.dart';
import 'coach_view_state.dart';

/// Formats a date the way every attendance route expects it: `yyyy-MM-dd`.
///
/// Built by hand rather than with `intl` so it is always the **local** civil
/// date. `toIso8601String()` on a local `DateTime` would be right by accident
/// and wrong the moment anything upstream hands over a UTC value — the day a
/// coach in IST marks attendance at 2am would come out as the previous day.
String coachDateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

/// The already-marked attendance log.
///
/// Reads `/coach/dashboard/attendance/records`, which is scoped to the coach's
/// own batches. `GET /attendance` is deliberately not used — it applies no
/// scoping for the `COACH` role.
class CoachAttendanceRecordsController extends ChangeNotifier {
  CoachAttendanceRecordsController(this._repository) {
    CoachLog.life('CoachAttendanceRecordsController created');
  }

  final CoachDashboardRepository _repository;

  static const int pageSize = 20;

  CoachViewState _state = CoachViewState.idle;
  CoachPaged<CoachAttendanceRecord> _page =
      const CoachPaged<CoachAttendanceRecord>();
  List<CoachAttendanceRecord> _records = const [];
  String? _error;

  DateTime? _date;
  CoachAttendanceStatus? _status;
  CoachOption? _batch;

  bool _loadingMore = false;
  bool _refreshing = false;
  bool _disposed = false;
  int _requestId = 0;

  CoachViewState get state => _state;
  List<CoachAttendanceRecord> get records => _records;
  String? get error => _error;

  DateTime? get date => _date;
  CoachAttendanceStatus? get status => _status;
  CoachOption? get batch => _batch;

  bool get loadingMore => _loadingMore;
  bool get refreshing => _refreshing;
  bool get hasMore => _page.hasNext;
  int get total => _page.total;

  bool get isFiltered => _date != null || _status != null || _batch != null;
  bool get isEmpty => _state.isReady && _records.isEmpty;

  /// Records grouped by day, newest day first — the log reads as a diary
  /// rather than as one flat list.
  ///
  /// Relies on the API's own `date DESC, createdAt DESC` ordering, so the keys
  /// come out in order without a second sort.
  Map<String, List<CoachAttendanceRecord>> get byDate {
    final grouped = <String, List<CoachAttendanceRecord>>{};
    for (final record in _records) {
      grouped.putIfAbsent(record.dateKey, () => []).add(record);
    }
    return grouped;
  }

  Future<void> load({bool silent = false}) async {
    if (_disposed) return;

    final request = ++_requestId;

    _refreshing = silent && _records.isNotEmpty;
    if (!_refreshing) _state = CoachViewState.loading;
    _notify();

    try {
      final result = await _repository.getAttendanceRecords(
        page: 1,
        limit: pageSize,
        date: _date == null ? null : coachDateKey(_date!),
        status: _status?.slug,
        batchId: _batch?.id,
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
      CoachLog.failure('Attendance records failed', error: e);
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
      final result = await _repository.getAttendanceRecords(
        page: _page.page + 1,
        limit: pageSize,
        date: _date == null ? null : coachDateKey(_date!),
        status: _status?.slug,
        batchId: _batch?.id,
      );

      if (request != _requestId || _disposed) return;

      _page = result;
      _records = [..._records, ...result.items];
    } catch (e) {
      if (request != _requestId || _disposed) return;
      _error = _describe(e);
      CoachLog.failure('Attendance records page failed', error: e);
    } finally {
      if (!_disposed) {
        _loadingMore = false;
        _notify();
      }
    }
  }

  void setDate(DateTime? value) {
    if (value == _date) return;
    _date = value;
    CoachLog.ui('Attendance date filter → ${value == null ? 'all' : coachDateKey(value)}');
    load();
  }

  /// Passing the current value clears the filter, so chips toggle.
  void setStatus(CoachAttendanceStatus? value) {
    final next = value == _status ? null : value;
    if (next == _status) return;
    _status = next;
    load();
  }

  void setBatch(CoachOption? value) {
    if (value?.id == _batch?.id) return;
    _batch = value;
    load();
  }

  void clearFilters() {
    if (!isFiltered) return;
    _date = null;
    _status = null;
    _batch = null;
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
    CoachLog.life('CoachAttendanceRecordsController disposed');
    super.dispose();
  }
}

/// The mark-attendance sheet: pick a batch and a date, set each student's
/// status, save.
///
/// `POST /attendance` upserts on `(studentId, batchId, date)`, so saving twice
/// corrects rather than duplicates — which is what makes it safe to re-save a
/// sheet after a partial failure.
class CoachAttendanceSheetController extends ChangeNotifier {
  CoachAttendanceSheetController(this._repository) {
    CoachLog.life('CoachAttendanceSheetController created');
  }

  final CoachDashboardRepository _repository;

  /// How deep the roster fetch will page while collecting one batch's
  /// students. A safety stop, not an expected limit.
  static const int _maxRosterPages = 10;
  static const int _rosterPageSize = 100;

  CoachViewState _batchesState = CoachViewState.idle;
  List<CoachOption> _batches = const [];
  String? _batchesError;

  CoachViewState _rosterState = CoachViewState.idle;
  List<CoachStudent> _roster = const [];
  String? _rosterError;

  CoachOption? _batch;
  DateTime _date = DateTime.now();

  /// studentId → the status the coach has set for them.
  final Map<int, CoachAttendanceStatus> _marks = {};

  bool _saving = false;
  bool _disposed = false;

  CoachViewState get batchesState => _batchesState;
  List<CoachOption> get batches => _batches;
  String? get batchesError => _batchesError;

  CoachViewState get rosterState => _rosterState;
  List<CoachStudent> get roster => _roster;
  String? get rosterError => _rosterError;

  CoachOption? get batch => _batch;
  DateTime get date => _date;
  String get dateKey => coachDateKey(_date);
  bool get saving => _saving;

  /// A sheet can only be saved once a batch is chosen and someone is marked.
  bool get canSave => _batch != null && _marks.isNotEmpty && !_saving;

  int get markedCount => _marks.length;

  int get presentCount => _marks.values
      .where((s) => s == CoachAttendanceStatus.present)
      .length;

  int get absentCount =>
      _marks.values.where((s) => s == CoachAttendanceStatus.absent).length;

  CoachAttendanceStatus? statusFor(int studentId) => _marks[studentId];

  // ---------------------------------------------------------------------------
  // Setup
  // ---------------------------------------------------------------------------

  Future<void> loadBatches() async {
    if (_disposed) return;

    _batchesState = CoachViewState.loading;
    _notify();

    try {
      _batches = await _repository.searchBatches();
      _batchesError = null;
      _batchesState = CoachViewState.ready;

      // With exactly one batch there is nothing to choose — pick it and load
      // the roster straight away.
      if (_batches.length == 1 && _batch == null) {
        _batch = _batches.first;
        _notify();
        await loadRoster();
        return;
      }
    } catch (e) {
      _batchesError = _describe(e);
      _batchesState = CoachViewState.failed;
      CoachLog.failure('Attendance batches failed', error: e);
    }

    _notify();
  }

  Future<void> selectBatch(CoachOption? value) async {
    if (value?.id == _batch?.id) return;

    _batch = value;
    // Marks belong to a (batch, date) pair — carrying them across a batch
    // change would silently file one batch's register against another.
    _marks.clear();
    _roster = const [];
    _notify();

    if (value != null) await loadRoster();
  }

  Future<void> setDate(DateTime value) async {
    if (coachDateKey(value) == coachDateKey(_date)) return;

    _date = value;
    // Same reasoning as [selectBatch]: a mark is for one specific day.
    _marks.clear();
    _notify();
  }

  /// Loads the students enrolled in the selected batch.
  ///
  /// There is no per-batch roster endpoint, so this pages through
  /// `my-students` (whose rows are enrollments, each already carrying its
  /// batch **name**) and keeps the ones for this batch. That is why the match
  /// is on name rather than id — the row does not carry a batch id.
  Future<void> loadRoster() async {
    if (_disposed || _batch == null) return;

    _rosterState = CoachViewState.loading;
    _notify();

    final batchName = _batch!.name.trim().toLowerCase();
    final collected = <CoachStudent>[];

    try {
      var page = 1;
      while (page <= _maxRosterPages) {
        final result = await _repository.getStudents(
          page: page,
          limit: _rosterPageSize,
          status: 'Active',
        );

        collected.addAll(
          result.items.where(
            (s) => s.batchName.trim().toLowerCase() == batchName,
          ),
        );

        if (!result.hasNext || result.isEmpty) break;
        page++;
      }

      if (_disposed) return;

      _roster = collected;
      _rosterError = null;
      _rosterState = CoachViewState.ready;
      CoachLog.state(
        'Roster for ${_batch!.name} → ${collected.length} students',
      );
    } catch (e) {
      if (_disposed) return;
      _rosterError = _describe(e);
      _rosterState = CoachViewState.failed;
      CoachLog.failure('Attendance roster failed', error: e);
    }

    _notify();
  }

  // ---------------------------------------------------------------------------
  // Marking
  // ---------------------------------------------------------------------------

  /// Sets one student's status. Tapping the status they already carry clears
  /// it, so a mis-tap can be undone without saving it first.
  void mark(int studentId, CoachAttendanceStatus status) {
    if (_marks[studentId] == status) {
      _marks.remove(studentId);
    } else {
      _marks[studentId] = status;
    }
    _notify();
  }

  /// Marks everyone on the roster — the common case, where a coach corrects
  /// the handful who are not present.
  void markAll(CoachAttendanceStatus status) {
    for (final student in _roster) {
      _marks[student.id] = status;
    }
    CoachLog.ui('Marked all ${_roster.length} students ${status.slug}');
    _notify();
  }

  void clearMarks() {
    if (_marks.isEmpty) return;
    _marks.clear();
    _notify();
  }

  /// Saves the sheet.
  ///
  /// Returns the students that could not be saved, so the page can say
  /// exactly who is still unmarked instead of claiming the whole sheet failed.
  /// Their marks are **kept** so a retry re-sends only them.
  Future<List<({CoachStudent student, String error})>> save() async {
    if (_batch == null || _marks.isEmpty) return const [];

    _saving = true;
    _notify();

    final batchId = _batch!.id;
    final day = dateKey;

    final drafts = _marks.entries
        .map((e) => CoachAttendanceDraft(
              studentId: e.key,
              batchId: batchId,
              date: day,
              status: e.value,
            ))
        .toList(growable: false);

    try {
      final failures = await _repository.markAttendanceSheet(drafts);

      if (_disposed) return const [];

      final failedIds = failures.map((f) => f.draft.studentId).toSet();

      // Everything that saved is dropped from the pending marks; what is left
      // is exactly what a retry should re-send.
      _marks.removeWhere((studentId, _) => !failedIds.contains(studentId));

      return failures
          .map((f) => (
                student: _roster.firstWhere(
                  (s) => s.id == f.draft.studentId,
                  orElse: () => CoachStudent(id: f.draft.studentId),
                ),
                error: f.error,
              ))
          .toList(growable: false);
    } finally {
      if (!_disposed) {
        _saving = false;
        _notify();
      }
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
    CoachLog.life('CoachAttendanceSheetController disposed');
    super.dispose();
  }
}
