import '../../core/employee_log.dart';
import '../../domain/entities/employee_fee.dart';
import '../../domain/entities/employee_master.dart';
import '../../domain/entities/employee_paged.dart';
import '../../domain/repositories/employee_dashboard_repository.dart';
import 'employee_list_controller.dart';

/// Fees Approval — the queue of coach-recorded collections.
///
/// Approving is the point of the screen: it is what unlocks the student's gate
/// pass, and it is an ADMIN/COMPLEX_ADMIN/EMPLOYEE route precisely so the
/// person who took the money is not the person who signs it off.
///
/// Opens on `Pending` rather than "all", the way the website does — a queue
/// with the settled records mixed in is not a queue.
class EmployeeFeesApprovalController extends EmployeeListController<EmployeeFee> {
  EmployeeFeesApprovalController(this._repository);

  final EmployeeDashboardRepository _repository;

  static const List<String> approvalStatuses = [
    'Pending',
    'Approved',
    'Rejected',
  ];

  String? _approvalStatus = 'Pending';
  String _search = '';
  EmployeeFeeStats _stats = EmployeeFeeStats.empty;

  String? get approvalStatus => _approvalStatus;
  String get search => _search;
  EmployeeFeeStats get stats => _stats;

  bool get isFiltered => _approvalStatus != null || _search.trim().isNotEmpty;

  @override
  Future<EmployeePaged<EmployeeFee>> fetchPage(int page) {
    return _repository.getFees(
      page: page,
      limit: pageSize,
      approvalStatus: _approvalStatus,
      search: _search.trim().isEmpty ? null : _search.trim(),
    );
  }

  /// The counters come from `/fees/stats`, which is unfiltered — it describes
  /// the whole complex, not the current filter, so it is fetched separately and
  /// after the rows rather than blocking them.
  @override
  Future<void> onFirstPageLoaded() => _loadStats();

  Future<void> _loadStats() async {
    try {
      final stats = await _repository.getFeeStats();
      if (isDisposed) return;
      _stats = stats;
      notify();
    } catch (e) {
      // Non-fatal: the queue is still workable without the counters above it.
      EmployeeLog.failure('Fee stats failed', error: e);
    }
  }

  void setApprovalStatus(String? value) {
    if (value == _approvalStatus) return;
    _approvalStatus = value;
    EmployeeLog.ui('Fee approval filter → ${value ?? 'all'}');
    reload();
  }

  void onSearchChanged(String value) {
    if (value == _search) return;
    _search = value;
    notify();

    debounce(() {
      EmployeeLog.ui('Fee search → "${_search.trim()}"');
      load();
    });
  }

  void clearFilters() {
    cancelDebounce();
    _approvalStatus = null;
    _search = '';
    reload();
  }

  /// Approves the collection and unlocks the student's gate pass.
  ///
  /// The row is patched in place and the counters re-pulled, so the "awaiting
  /// approval" number above the queue drops as the queue is worked down.
  Future<String?> approve(EmployeeFee fee) async {
    try {
      await _repository.approveFee(fee.id);
      _settle(fee, 'Approved');
      return null;
    } catch (e) {
      return reportFailure('Fee approve failed', e);
    }
  }

  Future<String?> reject(EmployeeFee fee) async {
    try {
      await _repository.rejectFee(fee.id);
      _settle(fee, 'Rejected');
      return null;
    } catch (e) {
      return reportFailure('Fee reject failed', e);
    }
  }

  void _settle(EmployeeFee fee, String status) {
    // While the queue is filtered to Pending, a settled row no longer belongs
    // in it — dropping it is what makes working down the queue feel like
    // progress. With no filter, the row stays and just changes colour.
    if (_approvalStatus == 'Pending') {
      removeItem((f) => f.id == fee.id);
    } else {
      replaceItem((f) => f.id == fee.id, (f) => f.copyWith(approvalStatus: status));
    }
    _loadStats();
  }
}

/// Fees Management — the records themselves.
///
/// A different permission from approval (`employee_fees_management`), enforced
/// on the API as well, so an admin can grant one without the other. Approving
/// is deliberately **not** offered here.
class EmployeeFeesManagementController
    extends EmployeeListController<EmployeeFee> {
  EmployeeFeesManagementController(this._repository);

  final EmployeeDashboardRepository _repository;

  static const List<String> paymentStatuses = [
    'Pending',
    'Paid',
    'Partial',
    'Overdue',
  ];

  String? _paymentStatus;
  String _search = '';

  List<EmployeeOption> _students = const [];
  List<EmployeeBatch> _batches = const [];
  bool _pickersLoaded = false;

  String? get paymentStatus => _paymentStatus;
  String get search => _search;
  List<EmployeeOption> get students => _students;
  List<EmployeeBatch> get batches => _batches;

  /// Whether the create form can be opened at all — it needs both pickers, and
  /// an employee whose complex has no students yet cannot create a fee record.
  bool get canCreate => _students.isNotEmpty && _batches.isNotEmpty;

  bool get isFiltered => _paymentStatus != null || _search.trim().isNotEmpty;

  @override
  Future<EmployeePaged<EmployeeFee>> fetchPage(int page) {
    return _repository.getFees(
      page: page,
      limit: pageSize,
      paymentStatus: _paymentStatus,
      search: _search.trim().isEmpty ? null : _search.trim(),
    );
  }

  @override
  Future<void> onFirstPageLoaded() async {
    if (_pickersLoaded) return;
    _pickersLoaded = true;

    try {
      final results = await Future.wait([
        _repository.getStudentOptions(),
        _repository.getBatches(),
      ]);
      if (isDisposed) return;

      _students = results[0] as List<EmployeeOption>;
      _batches = results[1] as List<EmployeeBatch>;
      notify();
    } catch (e) {
      // Non-fatal: the list reads fine, only the create form is unavailable.
      _pickersLoaded = false;
      EmployeeLog.failure('Fee pickers failed', error: e);
    }
  }

  void setPaymentStatus(String? value) {
    if (value == _paymentStatus) return;
    _paymentStatus = value;
    EmployeeLog.ui('Fee payment filter → ${value ?? 'all'}');
    reload();
  }

  void onSearchChanged(String value) {
    if (value == _search) return;
    _search = value;
    notify();

    debounce(() {
      EmployeeLog.ui('Fee search → "${_search.trim()}"');
      load();
    });
  }

  void clearFilters() {
    cancelDebounce();
    if (!isFiltered) return;
    _paymentStatus = null;
    _search = '';
    reload();
  }

  /// Creates a record. Re-loads afterwards: the new row carries the student and
  /// batch names from joins this side cannot fill in.
  Future<String?> create(EmployeeFeeDraft draft) async {
    try {
      await _repository.createFee(draft);
      await refresh();
      return null;
    } catch (e) {
      return reportFailure('Fee create failed', e);
    }
  }

  Future<String?> update(int id, EmployeeFeeDraft draft) async {
    try {
      await _repository.updateFee(id, draft);
      await refresh();
      return null;
    } catch (e) {
      return reportFailure('Fee update failed', e);
    }
  }

  Future<String?> delete(EmployeeFee fee) async {
    try {
      await _repository.deleteFee(fee.id);
      removeItem((f) => f.id == fee.id);
      return null;
    } catch (e) {
      return reportFailure('Fee delete failed', e);
    }
  }
}
