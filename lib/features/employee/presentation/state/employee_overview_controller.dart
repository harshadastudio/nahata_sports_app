import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../core/employee_log.dart';
import '../../domain/entities/employee_overview.dart';
import '../../domain/repositories/employee_dashboard_repository.dart';
import 'employee_view_state.dart';

/// The dashboard home: the headline numbers and the newest bookings.
///
/// The two sections load **independently on purpose**. `/reports/overview` runs
/// a dozen aggregate counts and is the slowest call in the module; making the
/// recent-bookings strip wait on it would leave the page blank for a second
/// longer than it needs to be. Each section keeps its own error, so a failed
/// stats call still leaves the bookings readable.
class EmployeeOverviewController extends ChangeNotifier {
  EmployeeOverviewController(this._repository) {
    EmployeeLog.life('EmployeeOverviewController created');
  }

  final EmployeeDashboardRepository _repository;

  static const int recentBookingLimit = 5;

  EmployeeViewState _statsState = EmployeeViewState.idle;
  EmployeeViewState _bookingsState = EmployeeViewState.idle;

  EmployeeStats _stats = EmployeeStats.empty;
  List<EmployeeRecentBooking> _recent = const [];

  String? _statsError;
  String? _bookingsError;

  bool _refreshing = false;
  bool _disposed = false;

  EmployeeViewState get statsState => _statsState;
  EmployeeViewState get bookingsState => _bookingsState;

  EmployeeStats get stats => _stats;
  List<EmployeeRecentBooking> get recentBookings => _recent;

  String? get statsError => _statsError;
  String? get bookingsError => _bookingsError;

  bool get refreshing => _refreshing;

  /// True only while nothing at all is on screen — a pull-to-refresh over
  /// existing content is not "loading" for the shimmer's purposes.
  bool get isInitialLoad =>
      _statsState.isLoading && _stats == EmployeeStats.empty;

  /// Loads both sections.
  ///
  /// [silent] keeps whatever is on screen and shows the hairline refresh bar
  /// instead of tearing the page down — used by pull-to-refresh.
  Future<void> load({bool silent = false}) async {
    if (_disposed) return;

    _refreshing = silent;
    if (!silent) {
      _statsState = EmployeeViewState.loading;
      _bookingsState = EmployeeViewState.loading;
    }
    _notify();

    // Fired together, awaited together — but each swallows its own failure into
    // its own state, so one dead section cannot blank the other.
    await Future.wait([_loadStats(), _loadRecent()]);

    if (_disposed) return;
    _refreshing = false;
    _notify();

    EmployeeLog.state(
      'Overview → ${_stats.todayBookings} today, ${_recent.length} recent',
    );
  }

  Future<void> refresh() => load(silent: true);

  Future<void> _loadStats() async {
    try {
      final stats = await _repository.getStats();
      if (_disposed) return;
      _stats = stats;
      _statsError = null;
      _statsState = EmployeeViewState.ready;
    } catch (e) {
      if (_disposed) return;
      _statsError = _describe(e);
      _statsState = EmployeeViewState.failed;
      EmployeeLog.failure('Overview stats failed', error: e);
    }
  }

  Future<void> _loadRecent() async {
    try {
      final bookings =
          await _repository.getRecentBookings(limit: recentBookingLimit);
      if (_disposed) return;
      _recent = bookings;
      _bookingsError = null;
      _bookingsState = EmployeeViewState.ready;
    } catch (e) {
      if (_disposed) return;
      _bookingsError = _describe(e);
      _bookingsState = EmployeeViewState.failed;
      EmployeeLog.failure('Recent bookings failed', error: e);
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
    EmployeeLog.life('EmployeeOverviewController disposed');
    super.dispose();
  }
}
