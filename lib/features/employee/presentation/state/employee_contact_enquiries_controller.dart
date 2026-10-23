import '../../core/employee_log.dart';
import '../../domain/entities/employee_contact_enquiry.dart';
import '../../domain/entities/employee_paged.dart';
import '../../domain/repositories/employee_dashboard_repository.dart';
import 'employee_list_controller.dart';

/// Contact Enquiries — the "Contact Us" queue from the public site.
///
/// This route sends a `statusCounts` block alongside its rows, which no other
/// list in the console does, so the counts are kept here and shown as a strip
/// above the list. They come from the **unfiltered** totals the server
/// computes, so they still read correctly while a status filter is applied —
/// which is the whole point of showing them.
class EmployeeContactEnquiriesController
    extends EmployeeListController<EmployeeContactEnquiry> {
  EmployeeContactEnquiriesController(this._repository);

  final EmployeeDashboardRepository _repository;

  static const List<String> statuses = EmployeeContactEnquiry.statuses;

  String? _status;
  EmployeeContactEnquiryCounts _counts = EmployeeContactEnquiryCounts.none;

  String? get status => _status;
  EmployeeContactEnquiryCounts get counts => _counts;

  bool get isFiltered => _status != null;

  @override
  Future<EmployeePaged<EmployeeContactEnquiry>> fetchPage(int page) async {
    final result = await _repository.getContactEnquiries(
      page: page,
      limit: pageSize,
      status: _status,
    );

    // The counters ride along with every page; keeping the latest is enough,
    // and they are cheap to carry.
    _counts = result.counts;
    return result.page;
  }

  void setStatus(String? value) {
    if (value == _status) return;
    _status = value;
    EmployeeLog.ui('Contact enquiry status filter → ${value ?? 'all'}');
    reload();
  }

  void clearFilters() {
    if (!isFiltered) return;
    _status = null;
    reload();
  }

  /// Re-reads one enquiry in full and patches it onto the queue.
  ///
  /// The list row is what the queue shows; this is what the detail sheet reads,
  /// because a list payload can carry a shortened message. Returns null when
  /// the read fails — the sheet keeps showing the row it opened with rather
  /// than an error over content the user can already see.
  Future<EmployeeContactEnquiry?> loadEnquiry(String id) async {
    try {
      final enquiry = await _repository.getContactEnquiry(id);
      replaceItem((e) => e.id == id, (_) => enquiry);
      return enquiry;
    } catch (e) {
      EmployeeLog.failure('Contact enquiry $id read failed', error: e);
      return null;
    }
  }

  /// Marks where the desk has got to. The row is patched in place so the queue
  /// does not jump under someone working down it.
  Future<String?> setEnquiryStatus(
    EmployeeContactEnquiry enquiry,
    String status,
  ) async {
    try {
      await _repository.setContactEnquiryStatus(enquiry.id, status);
      replaceItem(
        (e) => e.id == enquiry.id,
        (e) => e.copyWith(status: status, updatedAt: DateTime.now()),
      );
      return null;
    } catch (e) {
      return reportFailure('Contact enquiry status failed', e);
    }
  }

  Future<String?> delete(EmployeeContactEnquiry enquiry) async {
    try {
      await _repository.deleteContactEnquiry(enquiry.id);
      removeItem((e) => e.id == enquiry.id);
      return null;
    } catch (e) {
      return reportFailure('Contact enquiry delete failed', e);
    }
  }
}
