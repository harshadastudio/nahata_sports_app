import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../core/employee_log.dart';
import 'employee_view_state.dart';

/// The loading machinery the operations masters share.
///
/// Sports, courts, slots and batches are **not paginated** — the website pulls
/// them with `limit=200` and a single complex never has more than that. So they
/// cannot reuse [EmployeeListController], which is built around appending
/// pages, and would carry a scroll-to-load path that never fires.
///
/// What they do share is a CRUD cycle: load the whole list, write, re-load.
/// A subclass supplies [fetch] and its own write methods.
abstract class EmployeeCollectionController<T> extends ChangeNotifier {
  /// Pulls the whole collection.
  Future<List<T>> fetch();

  EmployeeViewState _state = EmployeeViewState.idle;
  List<T> _items = const [];
  String? _error;
  bool _refreshing = false;
  bool _disposed = false;

  EmployeeViewState get state => _state;
  List<T> get items => _items;
  String? get error => _error;
  bool get refreshing => _refreshing;
  bool get isDisposed => _disposed;

  bool get isEmpty => _state.isReady && _items.isEmpty;
  bool get isInitialLoad => _state.isLoading && _items.isEmpty;

  /// Loads the collection.
  ///
  /// [silent] keeps the current rows visible and shows the refresh hairline —
  /// used after a write, so the list does not flash empty between the save and
  /// the re-read.
  Future<void> load({bool silent = false}) async {
    if (_disposed) return;

    _refreshing = silent && _items.isNotEmpty;
    if (!_refreshing) _state = EmployeeViewState.loading;
    notify();

    try {
      final result = await fetch();
      if (_disposed) return;

      _items = result;
      _error = null;
      _state = EmployeeViewState.ready;
    } catch (e) {
      if (_disposed) return;
      _error = describeError(e);
      _state = EmployeeViewState.failed;
      EmployeeLog.failure('$runtimeType load failed', error: e);
    } finally {
      if (!_disposed) {
        _refreshing = false;
        notify();
      }
    }
  }

  Future<void> refresh() => load(silent: true);

  /// Runs a write, then re-reads.
  ///
  /// Re-reading rather than patching in place is deliberate here: these records
  /// carry joined names (a court's sport, a batch's coach) that this side
  /// cannot recompute, and the lists are small enough that a round trip is
  /// cheaper than getting a stale label on screen.
  ///
  /// Returns null on success, else the server's own message — which names the
  /// permission that was missing, or the record that is still referenced.
  @protected
  Future<String?> write(String what, Future<void> Function() action) async {
    try {
      await action();
      await refresh();
      return null;
    } catch (e) {
      EmployeeLog.failure('$what failed', error: e);
      return describeError(e);
    }
  }

  @protected
  static String describeError(Object error) => error is ApiException
      ? error.message
      : 'Something went wrong. Please try again.';

  @protected
  void notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    EmployeeLog.life('$runtimeType disposed');
    super.dispose();
  }
}
