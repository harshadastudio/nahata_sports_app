import 'package:flutter/foundation.dart';

import '../../core/admin_log.dart';
import '../../domain/entities/admin_stats.dart';
import '../../domain/repositories/admin_repository.dart';
import 'view_state.dart';

/// Drives the dashboard-home summary cards.
class AdminStatsController extends ChangeNotifier {
  AdminStatsController(this._repository) {
    AdminLog.life('AdminStatsController created');
  }

  final AdminRepository _repository;

  ViewState _state = ViewState.idle;
  AdminStats _stats = AdminStats.empty;
  String? _error;
  DateTime? _loadedAt;
  bool _disposed = false;

  ViewState get state => _state;
  AdminStats get stats => _stats;
  String? get error => _error;
  DateTime? get loadedAt => _loadedAt;

  /// True on the very first load only — a refresh keeps the old numbers on
  /// screen and shows a subtle progress line instead of a full shimmer.
  bool get isFirstLoad => _state.isLoading && _stats.isEmpty;

  Future<void> load({bool silent = false}) async {
    if (_state.isLoading) {
      AdminLog.state('Stats load skipped — one is already in flight');
      return;
    }

    AdminLog.state('Stats loading (silent: $silent)');
    _state = ViewState.loading;
    if (!silent) _error = null;
    _safeNotify();

    // `fetchStats` degrades to an empty entity instead of throwing, so a dead
    // stats route leaves the cards blank rather than blocking the page.
    final result = await _repository.fetchStats();

    if (_disposed) return;

    _stats = result;
    _loadedAt = DateTime.now();
    _state = ViewState.ready;
    _error = result.isEmpty ? 'No statistics were returned.' : null;

    AdminLog.state('Stats ready → $result');
    _safeNotify();
  }

  Future<void> refresh() {
    AdminLog.ui('Stats refresh requested');
    return load(silent: true);
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    AdminLog.life('AdminStatsController disposed');
    super.dispose();
  }
}
