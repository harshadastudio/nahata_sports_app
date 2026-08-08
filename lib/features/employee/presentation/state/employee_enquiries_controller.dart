import '../../core/employee_log.dart';
import '../../domain/entities/employee_enquiry.dart';
import '../../domain/entities/employee_paged.dart';
import '../../domain/repositories/employee_dashboard_repository.dart';
import 'employee_list_controller.dart';

/// Coaching Enquiries — the staff queue.
///
/// The one write here is Approve & Enroll, and it is not a status change:
/// the API creates the student, enrols them in the batch and opens a `Pending`
/// fee record inside one transaction. The row is patched to `Approved` in place
/// afterwards rather than re-fetching, so the queue does not jump under someone
/// who is working down it.
class EmployeeEnquiriesController
    extends EmployeeListController<EmployeeEnquiry> {
  EmployeeEnquiriesController(this._repository);

  final EmployeeDashboardRepository _repository;

  static const List<String> statuses = [
    'Pending',
    'Reviewed',
    'Contacted',
    'Approved',
    'Rejected',
  ];

  String? _status;
  String _search = '';

  String? get status => _status;
  String get search => _search;

  bool get isFiltered => _status != null || _search.trim().isNotEmpty;

  @override
  Future<EmployeePaged<EmployeeEnquiry>> fetchPage(int page) {
    return _repository.getEnquiries(
      page: page,
      limit: pageSize,
      status: _status,
      search: _search.trim().isEmpty ? null : _search.trim(),
    );
  }

  void setStatus(String? value) {
    if (value == _status) return;
    _status = value;
    EmployeeLog.ui('Enquiry status filter → ${value ?? 'all'}');
    reload();
  }

  void onSearchChanged(String value) {
    if (value == _search) return;
    _search = value;
    notify();

    debounce(() {
      EmployeeLog.ui('Enquiry search → "${_search.trim()}"');
      load();
    });
  }

  void clearFilters() {
    cancelDebounce();
    if (!isFiltered) return;
    _status = null;
    _search = '';
    reload();
  }

  /// Approves and enrols. Returns null on success, else the server's message —
  /// which is the useful one here: it names the batch that was full or says the
  /// enquiry was already settled.
  Future<String?> approve(EmployeeEnquiry enquiry) async {
    try {
      await _repository.approveEnquiry(enquiry.id);
      replaceItem(
        (e) => e.id == enquiry.id,
        (e) => e.copyWith(status: 'Approved', updatedAt: DateTime.now()),
      );
      return null;
    } catch (e) {
      return reportFailure('Enquiry approve failed', e);
    }
  }
}
