import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../admin/core/admin_log.dart';
import '../../../admin/domain/entities/visitor_pass.dart';
import '../../../admin/domain/repositories/visitor_pass_repository.dart';
import '../../../admin/presentation/state/view_state.dart';
import '../../domain/entities/gate_scan.dart';
import '../../domain/repositories/gate_scan_repository.dart';
import 'scan_journal.dart';

/// The eight counters across the top of the guard dashboard.
@immutable
class GuardCounters {
  const GuardCounters({
    this.visitorPassesToday = 0,
    this.visitorsInside = 0,
    this.visitorsCheckedOut = 0,
    this.eventEntries = 0,
    this.courtEntries = 0,
    this.coachingScans = 0,
    this.totalScans = 0,
    this.invalidAttempts = 0,
  });

  static const GuardCounters empty = GuardCounters();

  /// From the visitor-pass list — the only gate with a queryable history.
  final int visitorPassesToday;
  final int visitorsInside;
  final int visitorsCheckedOut;

  /// From this device's own journal: the event, court and coaching backends
  /// expose no "scans today" endpoint, so what this gate did is what can be
  /// counted. See [SecurityGuardController] for why that is stated on screen.
  final int eventEntries;
  final int courtEntries;
  final int coachingScans;

  final int totalScans;
  final int invalidAttempts;
}

/// Drives `/security/dashboard`.
///
/// ## Where the numbers come from
///
/// Three of the four gates have no history endpoint. `/event-passes/…/scan-stats`
/// and `/courts/bookings/scan-stats` are both **per-event** and **per-court**:
/// they answer "how is this event going", not "what has this guard scanned
/// today". `/fees/scan-logs` is the one exception and is queried directly.
///
/// So the dashboard is built from two honest sources and says which is which:
///
///  * **visitor counters** — computed from `/visitor-passes`, the whole gate's
///    activity, same as the security dashboard's own figures;
///  * **event / court / coaching counters and the activity feed** — this
///    device's [ScanJournal], which records every scan made here including the
///    refusals no backend stores.
///
/// Nothing is extrapolated between them, and the UI labels the journal-backed
/// figures as "this device" rather than presenting them as venue totals.
class SecurityGuardController extends ChangeNotifier {
  SecurityGuardController({
    required VisitorPassRepository visitorPasses,
    required GateScanRepository gates,
    required ScanJournal journal,
    DateTime Function()? clock,
  })  : _visitorPasses = visitorPasses,
        _gates = gates,
        _journal = journal,
        _clock = clock ?? DateTime.now {
    _journal.addListener(_onJournalChanged);
    AdminLog.life('SecurityGuardController created');
  }

  final VisitorPassRepository _visitorPasses;
  final GateScanRepository _gates;
  final ScanJournal _journal;
  final DateTime Function() _clock;

  /// Rows per request while sweeping the visitor list.
  static const int _pageSize = 100;

  /// Hard ceiling on requests per refresh.
  static const int maxPages = 4;

  /// The spec asks for 30–60s; 45 sits in the middle and keeps a gate current
  /// without hammering the API from every guard's phone.
  static const Duration refreshInterval = Duration(seconds: 45);

  ViewState _state = ViewState.idle;
  String? _error;
  GuardCounters _counters = GuardCounters.empty;
  List<VisitorPass> _visitorsToday = const [];
  DateTime? _loadedAt;

  Timer? _poll;
  int _requestId = 0;
  bool _disposed = false;

  ViewState get state => _state;
  String? get error => _error;
  GuardCounters get counters => _counters;
  DateTime? get loadedAt => _loadedAt;

  ScanJournal get journal => _journal;
  GateScanRepository get gates => _gates;

  bool get isFirstLoad => _state.isLoading && _loadedAt == null;
  bool get isRefreshing => _state.isLoading && _loadedAt != null;

  /// Today's visitor passes, newest first — the Recent Scan Activity fallback
  /// when the journal is empty (a guard who just signed in on a new device).
  List<VisitorPass> get visitorsToday => _visitorsToday;

  /// The activity feed: every scan this device made, newest first.
  List<ScanJournalEntry> recentActivity([int limit = 12]) =>
      _journal.recent(limit);

  // --- Loading ---------------------------------------------------------------

  Future<void> load({bool force = false}) async {
    if (_state.isLoading) return;

    final id = ++_requestId;
    _state = ViewState.loading;
    _error = null;
    _safeNotify();

    try {
      await _journal.restore();
      final visitors = await _sweepVisitorPasses();

      if (_disposed || id != _requestId) {
        AdminLog.state('Guard dashboard response superseded — dropped');
        return;
      }

      _visitorsToday = visitors;
      _counters = _countersFrom(visitors);
      _loadedAt = _clock();
      _state = ViewState.ready;

      AdminLog.state(
        'Guard dashboard ready → ${_counters.visitorPassesToday} passes, '
        '${_counters.totalScans} scans, ${_counters.invalidAttempts} refused',
      );
    } catch (error, stackTrace) {
      if (_disposed || id != _requestId) return;
      _state = ViewState.failed;
      _error = error is Exception
          ? error.toString().replaceFirst('Exception: ', '')
          : 'The dashboard could not be loaded. Please try again.';
      AdminLog.failure(
        'Guard dashboard failed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _safeNotify();
    }
  }

  Future<void> refresh() {
    AdminLog.ui('Guard dashboard refresh requested');
    return load(force: true);
  }

  /// Auto-refresh while the dashboard is open.
  void startAutoRefresh() {
    if (_poll != null) return;
    AdminLog.state(
      'Guard dashboard auto-refresh every ${refreshInterval.inSeconds}s',
    );
    _poll = Timer.periodic(refreshInterval, (_) {
      if (_disposed || _state.isLoading) return;
      unawaited(load(force: true));
    });
  }

  void stopAutoRefresh() {
    if (_poll == null) return;
    AdminLog.state('Guard dashboard auto-refresh stopped');
    _poll?.cancel();
    _poll = null;
  }

  /// Records a scan and re-derives the counters straight away, so a guard sees
  /// the number move as they work rather than at the next poll.
  Future<void> recordScan(GateScanResult result) async {
    await _journal.record(result);
    _counters = _countersFrom(_visitorsToday);
    _safeNotify();

    // A visitor scan changes figures that come from the server, not the
    // journal, so those are re-read.
    if (result.kind == GateScanKind.visitor && result.isSuccess) {
      unawaited(load(force: true));
    }
  }

  // --- Derivation ------------------------------------------------------------

  /// Sweeps the visitor list far enough to cover today.
  ///
  /// Same bounded approach as the security dashboard: the list is served
  /// newest-first, so the sweep stops on the first page that is entirely older
  /// than midnight.
  Future<List<VisitorPass>> _sweepVisitorPasses() async {
    final now = _clock();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final collected = <String, VisitorPass>{};

    for (var page = 1; page <= maxPages; page++) {
      final result = await _visitorPasses.fetchVisitorPasses(
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

      if (dated.isNotEmpty &&
          dated.every((at) => at.isBefore(startOfDay))) {
        break;
      }
    }

    return List<VisitorPass>.unmodifiable(collected.values);
  }

  GuardCounters _countersFrom(List<VisitorPass> passes) {
    final now = _clock();
    final startOfDay = DateTime(now.year, now.month, now.day);

    var issuedToday = 0;
    var checkedOutToday = 0;
    var inside = 0;

    for (final pass in passes) {
      final created = pass.createdAt;
      if (created != null && !created.isBefore(startOfDay)) {
        issuedToday++;
        if (pass.status == VisitorPassStatus.checkedOut) checkedOutToday++;
      }

      // Live, not windowed: somebody who entered yesterday and has not left is
      // still in the building.
      if (pass.status == VisitorPassStatus.checkedIn) inside++;
    }

    return GuardCounters(
      visitorPassesToday: issuedToday,
      visitorsInside: inside,
      visitorsCheckedOut: checkedOutToday,
      eventEntries: _journal.countToday(GateScanKind.event, now),
      courtEntries: _journal.countToday(GateScanKind.courtBooking, now),
      coachingScans: _journal.countToday(GateScanKind.coaching, now),
      totalScans: _journal.totalToday,
      invalidAttempts: _journal.failuresToday,
    );
  }

  void _onJournalChanged() {
    _counters = _countersFrom(_visitorsToday);
    _safeNotify();
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    _journal.removeListener(_onJournalChanged);
    AdminLog.life('SecurityGuardController disposed');
    super.dispose();
  }
}