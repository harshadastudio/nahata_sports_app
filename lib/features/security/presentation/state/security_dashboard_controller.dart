import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../../admin/core/admin_log.dart';
import '../../../admin/domain/entities/visitor_pass.dart';
import '../../../admin/domain/repositories/visitor_pass_repository.dart';
import '../../../admin/presentation/state/view_state.dart';
import '../../domain/entities/security_dashboard_data.dart';

/// Drives the Security Dashboard.
///
/// ## Why it sweeps
///
/// The visitor-pass API is seven routes and no more: `GET /visitor-passes`
/// takes `page`, `limit` and `search`, and there is no statistics endpoint and
/// no date or status filter. Every card, chart and timeline on this screen is
/// therefore computed from rows this controller fetched — [_sweep] walks the
/// list newest-first until it has covered the window being shown, then
/// [SecurityDashboardData.from] turns the rows into figures in one pass.
///
/// The sweep is bounded three ways so a busy venue cannot turn a dashboard into
/// a hundred requests: [maxPages], [_pageSize], and an early exit as soon as a
/// page comes back entirely older than the window. When the cap is hit,
/// [truncated] is set and the UI says so rather than presenting a partial count
/// as the whole truth.
///
/// If a `/visitor-passes/stats` route is added later, only [_sweep] and
/// [SecurityDashboardData.from] need to change; nothing above them moves.
class SecurityDashboardController extends ChangeNotifier {
  SecurityDashboardController(
    this._repository, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    AdminLog.life('SecurityDashboardController created');
  }

  final VisitorPassRepository _repository;

  /// Injected so the windows and every derived figure are testable.
  final DateTime Function() _clock;

  /// Rows per request during the sweep. The list endpoint's own maximum.
  static const int _pageSize = 100;

  /// Hard ceiling on requests per refresh — 10 × 100 rows covers a month at a
  /// very busy venue.
  static const int maxPages = 10;

  /// How long computed figures stay good. A gate desk wants live numbers; it
  /// does not want a re-sweep on every rebuild.
  static const Duration cacheTtl = Duration(seconds: 45);

  /// How often the live gate panel re-reads while the screen is open.
  static const Duration livePollInterval = Duration(seconds: 30);

  static const Duration searchDebounce = Duration(milliseconds: 400);

  /// Rows per page in the activity table. Paged in memory: the rows are
  /// already here, and asking the server again would only re-fetch them.
  static const int activityPageSize = 20;

  // --- State -----------------------------------------------------------------

  ViewState _state = ViewState.idle;
  String? _error;
  List<VisitorPass> _all = const [];
  SecurityDashboardData _data = SecurityDashboardData.none;
  DateTime? _loadedAt;
  bool _truncated = false;

  SecurityRange _range = SecurityRange.today;
  DateTime? _customStart;
  DateTime? _customEnd;

  VisitorPassStatus? _statusFilter;
  String? _purposeFilter;
  String? _staffFilter;
  String _search = '';

  int _activityPage = 1;

  Timer? _debounce;
  Timer? _livePoll;
  int _requestId = 0;
  bool _disposed = false;

  // --- Reads -----------------------------------------------------------------

  ViewState get state => _state;
  String? get error => _error;

  /// Every figure on the screen, for the current window.
  SecurityDashboardData get data => _data;

  /// True while the very first sweep is in flight — the screen shows skeletons.
  bool get isFirstLoad => _state.isLoading && _all.isEmpty;

  /// True while a later sweep is in flight — the screen keeps its figures and
  /// shows a refresh line.
  bool get isRefreshing => _state.isLoading && _all.isNotEmpty;

  bool get hasData => _all.isNotEmpty;

  /// True when the sweep stopped at [maxPages] with older passes still
  /// unfetched, so the figures describe only the window's most recent rows.
  bool get truncated => _truncated;

  DateTime? get loadedAt => _loadedAt;

  SecurityRange get range => _range;
  DateTime? get customStart => _customStart;
  DateTime? get customEnd => _customEnd;
  SecurityWindow get window => SecurityWindow.of(
        _range,
        _clock(),
        customStart: _customStart,
        customEnd: _customEnd,
      );

  VisitorPassStatus? get statusFilter => _statusFilter;
  String? get purposeFilter => _purposeFilter;
  String? get staffFilter => _staffFilter;
  String get search => _search;

  bool get hasFilters =>
      _statusFilter != null ||
      _purposeFilter != null ||
      _staffFilter != null ||
      _search.trim().isNotEmpty;

  int get activeFilterCount => [
        _statusFilter != null,
        _purposeFilter != null,
        _staffFilter != null,
        _search.trim().isNotEmpty,
      ].where((on) => on).length;

  /// The window's passes with the status / purpose / staff / search filters
  /// applied. The cards and charts deliberately describe the whole window —
  /// filtering the activity table must not silently redefine "visitors today".
  List<VisitorPass> get filteredPasses {
    final query = _search.trim().toLowerCase();

    return _data.passes.where((pass) {
      if (_statusFilter != null && pass.status != _statusFilter) return false;

      if (_purposeFilter != null &&
          (pass.visitPurpose ?? '').trim() != _purposeFilter) {
        return false;
      }

      if (_staffFilter != null &&
          (pass.createdByName ?? '').trim() != _staffFilter) {
        return false;
      }

      if (query.isEmpty) return true;

      // Name, phone, pass code and purpose — the four the desk searches by.
      return [
        pass.visitorName,
        pass.phoneNumber,
        pass.passCode,
        pass.visitPurpose,
      ].any((field) => (field ?? '').toLowerCase().contains(query));
    }).toList(growable: false);
  }

  int get activityPage => _activityPage;

  int get activityPageCount {
    final rows = filteredPasses.length;
    if (rows == 0) return 1;
    return (rows / activityPageSize).ceil();
  }

  /// The current page of the activity table.
  List<VisitorPass> get activityRows {
    final rows = filteredPasses;
    final start = (_activityPage - 1) * activityPageSize;
    if (start >= rows.length) return const [];
    final end = (start + activityPageSize).clamp(0, rows.length);
    return rows.sublist(start, end);
  }

  bool get canPagePrevious => _activityPage > 1;
  bool get canPageNext => _activityPage < activityPageCount;

  /// The most recently issued passes, for the "Recent Generated Passes" strip.
  List<VisitorPass> recentPasses({int limit = 6}) {
    final rows = _data.passes;
    return rows.length <= limit ? rows : rows.sublist(0, limit);
  }

  // --- Loading ---------------------------------------------------------------

  /// Loads the dashboard.
  ///
  /// [force] skips the TTL cache — pull-to-refresh, the Refresh button, and the
  /// return from any action that changed a pass.
  Future<void> load({bool force = false}) async {
    if (!force && _isFresh) {
      AdminLog.state('Security dashboard served from cache');
      return;
    }
    if (_state.isLoading) return;

    final id = ++_requestId;
    final target = window;

    AdminLog.state(
      'Security dashboard sweep → ${target.label} '
      '(${target.days}d, max $maxPages pages)',
    );

    _state = ViewState.loading;
    _error = null;
    _safeNotify();

    try {
      final swept = await _sweep(target);
      if (_disposed || id != _requestId) {
        AdminLog.state('Security dashboard response superseded — dropped');
        return;
      }

      _all = swept;
      _recompute();
      _loadedAt = _clock();
      _state = ViewState.ready;

      AdminLog.state(
        'Security dashboard ready → ${_data.totalPasses} passes in window, '
        '${_data.inside} inside, ${_data.timeline.length} movements',
      );
    } on ApiException catch (error) {
      if (_disposed || id != _requestId) return;
      _state = ViewState.failed;
      _error = error.message;
      AdminLog.failure('Security dashboard failed: ${error.message}',
          error: error);
    } catch (error, stackTrace) {
      if (_disposed || id != _requestId) return;
      _state = ViewState.failed;
      _error = 'Could not load the security dashboard. Please try again.';
      AdminLog.failure(
        'Security dashboard crashed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _safeNotify();
    }
  }

  /// Pull-to-refresh and the Refresh button.
  Future<void> refresh() {
    AdminLog.ui('Security dashboard refresh requested');
    return load(force: true);
  }

  bool get _isFresh {
    final at = _loadedAt;
    if (at == null || _all.isEmpty) return false;
    return _clock().difference(at) < cacheTtl;
  }

  /// Walks `/visitor-passes` newest-first until the window is covered.
  ///
  /// Stops early on the first page whose rows are all older than the window —
  /// the list is served newest-first, so nothing beyond it can be in range. A
  /// page with no `createdAt` at all is not treated as old: a payload that
  /// omits the field must not silently truncate the sweep.
  Future<List<VisitorPass>> _sweep(SecurityWindow target) async {
    final collected = <String, VisitorPass>{};
    var truncated = false;
    var page = 1;

    while (page <= maxPages) {
      final result = await _repository.fetchVisitorPasses(
        page: page,
        limit: _pageSize,
      );

      for (final pass in result.items) {
        collected[pass.key] = pass;
      }

      if (result.items.isEmpty || !result.hasNext) break;

      final dated = result.items
          .map((pass) => pass.createdAt)
          .whereType<DateTime>()
          .toList(growable: false);

      // Every dated row on this page is older than the window: the next page
      // can only be older still.
      if (dated.isNotEmpty && dated.every((at) => at.isBefore(target.start))) {
        break;
      }

      page++;
      if (page > maxPages) {
        truncated = true;
        AdminLog.state(
          'Security dashboard sweep hit the $maxPages page cap — '
          'figures cover the most recent ${maxPages * _pageSize} passes',
        );
      }
    }

    _truncated = truncated;
    return List<VisitorPass>.unmodifiable(collected.values);
  }

  /// Re-derives every figure from the rows already held — no network.
  void _recompute() {
    _data = SecurityDashboardData.from(
      all: _all,
      window: window,
      now: _clock(),
    );

    // A filter or a window change can leave the table on a page that no longer
    // exists.
    final pages = activityPageCount;
    if (_activityPage > pages) _activityPage = pages;
  }

  // --- Live gate -------------------------------------------------------------

  /// Starts polling while the dashboard is on screen, so "Currently Inside" and
  /// the gate panel stay live without the desk touching anything.
  void startLiveUpdates() {
    if (_livePoll != null) return;
    AdminLog.state(
      'Security dashboard live updates every ${livePollInterval.inSeconds}s',
    );
    _livePoll = Timer.periodic(livePollInterval, (_) {
      if (_disposed || _state.isLoading) return;
      unawaited(load(force: true));
    });
  }

  void stopLiveUpdates() {
    if (_livePoll == null) return;
    AdminLog.state('Security dashboard live updates stopped');
    _livePoll?.cancel();
    _livePoll = null;
  }

  // --- Filters ---------------------------------------------------------------

  /// Switching the window needs a new sweep when it reaches further back than
  /// the rows already held; otherwise the figures are re-derived in place.
  Future<void> setRange(
    SecurityRange range, {
    DateTime? start,
    DateTime? end,
  }) async {
    final unchanged = _range == range &&
        _customStart == start &&
        _customEnd == end &&
        range != SecurityRange.custom;
    if (unchanged) return;

    AdminLog.ui('Security dashboard range → ${range.label}');
    _range = range;
    _customStart = start;
    _customEnd = end;
    _activityPage = 1;

    // Widening past what was swept means the older rows were never fetched.
    if (_needsDeeperSweep) {
      await load(force: true);
      return;
    }

    _recompute();
    _safeNotify();
  }

  /// True when the requested window starts before the oldest row held.
  bool get _needsDeeperSweep {
    if (_all.isEmpty) return true;
    final oldest = _all
        .map((pass) => pass.createdAt)
        .whereType<DateTime>()
        .fold<DateTime?>(
          null,
          (min, at) => min == null || at.isBefore(min) ? at : min,
        );
    if (oldest == null) return true;
    // Not deeper if the sweep already reached past the window's start — unless
    // it was capped, in which case there may be more inside the window too.
    return _truncated || window.start.isBefore(oldest);
  }

  void setStatusFilter(VisitorPassStatus? status) {
    if (_statusFilter == status) return;
    AdminLog.ui('Security status filter → ${status?.label ?? 'All'}');
    _statusFilter = status;
    _activityPage = 1;
    _safeNotify();
  }

  void setPurposeFilter(String? purpose) {
    if (_purposeFilter == purpose) return;
    AdminLog.ui('Security purpose filter → ${purpose ?? 'All'}');
    _purposeFilter = purpose;
    _activityPage = 1;
    _safeNotify();
  }

  void setStaffFilter(String? staff) {
    if (_staffFilter == staff) return;
    AdminLog.ui('Security staff filter → ${staff ?? 'All'}');
    _staffFilter = staff;
    _activityPage = 1;
    _safeNotify();
  }

  /// Debounced: the rows are already in memory, but recomputing and rebuilding
  /// the table on every keystroke is work nobody sees.
  void onSearchChanged(String value) {
    if (_search == value) return;
    _search = value;
    notifyListeners();

    _debounce?.cancel();
    _debounce = Timer(searchDebounce, () {
      if (_disposed) return;
      AdminLog.ui('Security search settled: "${_search.trim()}"');
      _activityPage = 1;
      _safeNotify();
    });
  }

  void clearSearch() {
    if (_search.isEmpty) return;
    _debounce?.cancel();
    _search = '';
    _activityPage = 1;
    _safeNotify();
  }

  void clearFilters() {
    if (!hasFilters) return;
    AdminLog.ui('Security dashboard filters cleared');
    _debounce?.cancel();
    _statusFilter = null;
    _purposeFilter = null;
    _staffFilter = null;
    _search = '';
    _activityPage = 1;
    _safeNotify();
  }

  // --- Activity paging -------------------------------------------------------

  void goToActivityPage(int page) {
    final target = page.clamp(1, activityPageCount);
    if (target == _activityPage) return;
    _activityPage = target;
    _safeNotify();
  }

  void nextActivityPage() => goToActivityPage(_activityPage + 1);

  void previousActivityPage() => goToActivityPage(_activityPage - 1);

  // --- Helpers ---------------------------------------------------------------

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _livePoll?.cancel();
    AdminLog.life('SecurityDashboardController disposed');
    super.dispose();
  }
}