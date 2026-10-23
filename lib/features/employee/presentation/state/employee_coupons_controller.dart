import '../../core/employee_log.dart';
import '../../domain/entities/employee_coupon.dart';
import '../../domain/entities/employee_paged.dart';
import '../../domain/repositories/employee_dashboard_repository.dart';
import 'employee_list_controller.dart';

/// Coupons — create, edit and retire the discount codes for this complex.
///
/// Writes re-read the first page rather than patching in place: the server
/// uppercases a new code, stamps `createdAt`, and computes `usedCount`, so the
/// row that comes back is not the row the form sent.
class EmployeeCouponsController extends EmployeeListController<EmployeeCoupon> {
  EmployeeCouponsController(this._repository);

  final EmployeeDashboardRepository _repository;

  static const List<String> statuses = EmployeeCouponDraft.statuses;

  String _search = '';
  String? _status;

  String get search => _search;
  String? get status => _status;

  bool get isFiltered => _search.trim().isNotEmpty || _status != null;

  @override
  Future<EmployeePaged<EmployeeCoupon>> fetchPage(int page) {
    return _repository.getCoupons(
      page: page,
      limit: pageSize,
      search: _search.trim().isEmpty ? null : _search.trim(),
      status: _status,
    );
  }

  void onSearchChanged(String value) {
    if (value == _search) return;
    _search = value;
    notify();

    debounce(() {
      EmployeeLog.ui('Coupon search → "${_search.trim()}"');
      load();
    });
  }

  void setStatus(String? value) {
    if (value == _status) return;
    _status = value;
    EmployeeLog.ui('Coupon status filter → ${value ?? 'all'}');
    reload();
  }

  void clearFilters() {
    cancelDebounce();
    if (!isFiltered) return;
    _search = '';
    _status = null;
    reload();
  }

  /// Re-reads one coupon so the edit form opens over the server's copy rather
  /// than a list row that may have been sitting on screen for a while.
  ///
  /// Returns null when the read fails — the caller falls back to the row it
  /// already has, because a network blip should not block an edit.
  Future<EmployeeCoupon?> loadCoupon(int id) async {
    try {
      final coupon = await _repository.getCoupon(id);
      replaceItem((c) => c.id == id, (_) => coupon);
      return coupon;
    } catch (e) {
      EmployeeLog.failure('Coupon $id read failed', error: e);
      return null;
    }
  }

  Future<String?> create(EmployeeCouponDraft draft) =>
      _write('Coupon create', () => _repository.createCoupon(draft));

  Future<String?> update(int id, EmployeeCouponDraft draft) =>
      _write('Coupon update', () => _repository.updateCoupon(id, draft));

  Future<String?> delete(EmployeeCoupon coupon) async {
    try {
      await _repository.deleteCoupon(coupon.id);
      // A delete is the one write that does not need the row re-read — it is
      // gone, and dropping it keeps the user's place in a long list.
      removeItem((c) => c.id == coupon.id);
      return null;
    } catch (e) {
      return reportFailure('Coupon delete failed', e);
    }
  }

  /// Runs a write, then reloads page 1 silently so the rows already on screen
  /// stay put while the fresh ones arrive.
  Future<String?> _write(String what, Future<void> Function() action) async {
    try {
      await action();
      await refresh();
      return null;
    } catch (e) {
      return reportFailure('$what failed', e);
    }
  }
}
