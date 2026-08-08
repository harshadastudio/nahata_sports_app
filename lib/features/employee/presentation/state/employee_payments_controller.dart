import '../../core/employee_log.dart';
import '../../domain/entities/employee_paged.dart';
import '../../domain/entities/employee_payment.dart';
import '../../domain/repositories/employee_dashboard_repository.dart';
import 'employee_list_controller.dart';

/// Payments Management — the unified ledger.
///
/// The stats strip is **not** a separate call: `/payments/all` returns it
/// alongside every page, and it describes the whole filtered set. Fetching it
/// separately would let the header disagree with the rows under it.
///
/// Read-only. There is no employee-facing endpoint that edits a payment; a
/// correction is made on the booking or the fee record it came from.
class EmployeePaymentsController
    extends EmployeeListController<EmployeePayment> {
  EmployeePaymentsController(this._repository);

  final EmployeeDashboardRepository _repository;

  /// The normalised statuses the ledger reports, across all three sources.
  static const List<String> statuses = [
    'Paid',
    'Pending',
    'Failed',
    'Refunded',
  ];

  /// The three books being merged. The wire values are lower-case; the labels
  /// are what the backend already calls them in `typeLabel`.
  static const Map<String, String> types = {
    'facility': 'Court',
    'event': 'Event',
    'coaching': 'Coaching',
  };

  String? _status;
  String? _type;
  EmployeePaymentStats _stats = EmployeePaymentStats.empty;

  String? get status => _status;
  String? get type => _type;
  EmployeePaymentStats get stats => _stats;

  bool get isFiltered => _status != null || _type != null;

  @override
  Future<EmployeePaged<EmployeePayment>> fetchPage(int page) async {
    final result = await _repository.getPayments(
      page: page,
      limit: pageSize,
      status: _status,
      type: _type,
    );

    // The stats ride along with every page, so they refresh for free — and
    // stay in step with whatever filter produced these rows.
    _stats = result.stats;

    return EmployeePaged<EmployeePayment>(
      items: result.payments,
      page: result.page,
      limit: result.limit,
      total: result.total,
      totalPages: result.totalPages,
    );
  }

  void setStatus(String? value) {
    if (value == _status) return;
    _status = value;
    EmployeeLog.ui('Payment status filter → ${value ?? 'all'}');
    reload();
  }

  void setType(String? value) {
    if (value == _type) return;
    _type = value;
    EmployeeLog.ui('Payment type filter → ${value ?? 'all'}');
    reload();
  }

  void clearFilters() {
    if (!isFiltered) return;
    _status = null;
    _type = null;
    reload();
  }
}
