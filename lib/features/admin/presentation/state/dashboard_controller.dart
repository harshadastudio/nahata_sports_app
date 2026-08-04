import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/dashboard_stats.dart';
import '../../domain/entities/enrollment_trend.dart';
import '../../domain/entities/live_enquiry.dart';
import '../../domain/entities/sport_distribution.dart';
import '../../domain/repositories/dashboard_repository.dart';
import 'view_state.dart';

/// One section of the dashboard: its data, its state and its own error.
///
/// Modelling each section separately is what lets a dead
/// `/dashboard/sport-distribution` show one retry card instead of blanking the
/// whole page.
class Section<T> {
  const Section({required this.data, this.state = ViewState.idle, this.error});

  final T data;
  final ViewState state;
  final String? error;

  bool get isLoading => state.isLoading;
  bool get isFailed => state.isFailed;
  bool get isReady => state.isReady;

  /// Loading, or not started yet.
  ///
  /// The distinction matters on the very first frame: `load()` runs in a
  /// post-frame callback, so a section is still `idle` when it first paints.
  /// Treating that as "empty" would flash an empty state before the request
  /// has even gone out.
  bool get isBusy => state.isIdle || state.isLoading;

  Section<T> loading() => Section<T>(data: data, state: ViewState.loading);

  Section<T> ready(T value) => Section<T>(data: value, state: ViewState.ready);

  Section<T> failed(String message) =>
      Section<T>(data: data, state: ViewState.failed, error: message);
}

/// Drives the dashboard home.
///
/// [load] fans the four reads out concurrently — they are independent, so
/// running them in series would make the page four round trips slow for no
/// reason.
class DashboardController extends ChangeNotifier {
  DashboardController(this._repository) {
    AdminLog.life('DashboardController created');
  }

  final DashboardRepository _repository;

  /// How many enquiries the card asks for. The "View all" button is what takes
  /// an admin to the full list.
  static const int enquiryPreviewLimit = 6;

  Section<DashboardStats> _stats = const Section<DashboardStats>(
    data: DashboardStats.empty,
  );
  Section<EnrollmentTrend> _trends = const Section<EnrollmentTrend>(
    data: EnrollmentTrend.empty,
  );
  Section<SportDistribution> _distribution = const Section<SportDistribution>(
    data: SportDistribution.empty,
  );
  Section<List<LiveEnquiry>> _enquiries = const Section<List<LiveEnquiry>>(
    data: <LiveEnquiry>[],
  );

  DateTime? _loadedAt;
  bool _disposed = false;

  Section<DashboardStats> get stats => _stats;
  Section<EnrollmentTrend> get trends => _trends;
  Section<SportDistribution> get distribution => _distribution;
  Section<List<LiveEnquiry>> get enquiries => _enquiries;

  DateTime? get loadedAt => _loadedAt;

  bool get isLoading =>
      _stats.isLoading ||
      _trends.isLoading ||
      _distribution.isLoading ||
      _enquiries.isLoading;

  /// True while the very first load is in flight — after that a reload keeps
  /// the previous numbers on screen behind a progress line.
  bool get isFirstLoad => _loadedAt == null && isLoading;

  /// Loads all four sections at once.
  Future<void> load() async {
    AdminLog.state('Dashboard loading (4 sections, concurrent)');

    await Future.wait<void>([
      loadStats(),
      loadTrends(),
      loadDistribution(),
      loadEnquiries(),
    ]);

    if (_disposed) return;
    _loadedAt = DateTime.now();
    AdminLog.state('Dashboard load finished');
    _safeNotify();
  }

  Future<void> refresh() {
    AdminLog.ui('Dashboard refresh requested');
    return load();
  }

  Future<void> loadStats() => _run<DashboardStats>(
    name: 'stats',
    current: () => _stats,
    assign: (section) => _stats = section,
    fetch: _repository.fetchStats,
    fallback: 'Could not load the summary figures.',
  );

  Future<void> loadTrends() => _run<EnrollmentTrend>(
    name: 'enrollment trends',
    current: () => _trends,
    assign: (section) => _trends = section,
    fetch: _repository.fetchEnrollmentTrends,
    fallback: 'Could not load enrollment trends.',
  );

  Future<void> loadDistribution() => _run<SportDistribution>(
    name: 'sport distribution',
    current: () => _distribution,
    assign: (section) => _distribution = section,
    fetch: _repository.fetchSportDistribution,
    fallback: 'Could not load the sport distribution.',
  );

  Future<void> loadEnquiries() => _run<List<LiveEnquiry>>(
    name: 'live enquiries',
    current: () => _enquiries,
    assign: (section) => _enquiries = section,
    fetch: () => _repository.fetchLiveEnquiries(limit: enquiryPreviewLimit),
    fallback: 'Could not load recent enquiries.',
  );

  /// The load/ready/failed cycle every section shares.
  Future<void> _run<T>({
    required String name,
    required Section<T> Function() current,
    required void Function(Section<T>) assign,
    required Future<T> Function() fetch,
    required String fallback,
  }) async {
    AdminLog.state('Dashboard section "$name" loading');
    assign(current().loading());
    _safeNotify();

    try {
      final data = await fetch();
      if (_disposed) return;
      assign(current().ready(data));
      AdminLog.state('Dashboard section "$name" ready');
    } on ApiException catch (error) {
      if (_disposed) return;
      assign(current().failed(error.message));
      AdminLog.failure(
        'Dashboard section "$name" failed: ${error.message}',
        error: error,
      );
    } catch (error, stackTrace) {
      if (_disposed) return;
      assign(current().failed(fallback));
      AdminLog.failure(
        'Dashboard section "$name" crashed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _safeNotify();
    }
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    AdminLog.life('DashboardController disposed');
    super.dispose();
  }
}
