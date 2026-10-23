import '../../core/employee_log.dart';
import '../../domain/entities/employee_coach.dart';
import '../../domain/entities/employee_enquiry.dart';
import '../../domain/entities/employee_master.dart';
import '../../domain/entities/employee_paged.dart';
import '../../domain/repositories/employee_dashboard_repository.dart';
import 'employee_list_controller.dart';
import 'employee_view_state.dart';

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
  DateTime? _from;
  DateTime? _to;

  List<EmployeeSport> _sports = const [];
  List<EmployeeBatch> _batches = const [];
  List<EmployeeCoach> _coaches = const [];
  bool _pickersLoaded = false;

  List<EmployeeSport> get sports => _sports;
  List<EmployeeBatch> get batches => _batches;
  List<EmployeeCoach> get coaches => _coaches;

  /// Whether the Add form can be opened.
  ///
  /// A walk-in enquiry needs a batch — unless it is marked All Sports, which
  /// needs nothing — so the form is offered as soon as the list has loaded.
  /// The batch dropdown simply comes up empty on a complex that has none, and
  /// the All Sports switch is still usable.
  bool get canCreate => state.isReady;

  String? get status => _status;
  String get search => _search;
  DateTime? get from => _from;
  DateTime? get to => _to;

  bool get isFiltered =>
      _status != null ||
      _search.trim().isNotEmpty ||
      _from != null ||
      _to != null;

  @override
  Future<EmployeePaged<EmployeeEnquiry>> fetchPage(int page) {
    return _repository.getEnquiries(
      page: page,
      limit: pageSize,
      status: _status,
      search: _search.trim().isEmpty ? null : _search.trim(),
      from: _from,
      to: _to,
    );
  }

  @override
  Future<void> onFirstPageLoaded() async {
    if (_pickersLoaded) return;
    _pickersLoaded = true;

    // Secondary to the queue itself: an employee without the Sports, Batches
    // or Coaches permission gets a 403 here and must still be able to read
    // their enquiries, so a failure is swallowed and only logged.
    try {
      final sports = _repository.getSports();
      final batches = _repository.getBatches();
      final coaches = _repository.getCoaches(limit: 200);

      _sports = await sports;
      _batches = await batches;
      _coaches = (await coaches).items;

      if (isDisposed) return;
      notify();
    } catch (e) {
      _pickersLoaded = false;
      EmployeeLog.failure('Enquiry pickers failed', error: e);
    }
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

  /// Sets the received-between window. Either end may be null for an open one.
  ///
  /// The ends are swapped when they arrive the wrong way round rather than
  /// sending a range the API would answer empty for — a picker makes that easy
  /// to do by accident.
  void setDateRange(DateTime? from, DateTime? to) {
    var start = from;
    var end = to;
    if (start != null && end != null && end.isBefore(start)) {
      final swapped = start;
      start = end;
      end = swapped;
    }

    if (start == _from && end == _to) return;
    _from = start;
    _to = end;
    EmployeeLog.ui('Enquiry date range → ${start ?? 'any'} .. ${end ?? 'any'}');
    reload();
  }

  void clearFilters() {
    cancelDebounce();
    if (!isFiltered) return;
    _status = null;
    _search = '';
    _from = null;
    _to = null;
    reload();
  }

  /// Adds a walk-in enquiry typed at the desk, then reloads so the new row
  /// arrives with the batch, sport and coach the server derived for it.
  ///
  /// Returns an [EmployeeEnquiryCreateResult] on success and a message on
  /// failure. The result matters because creating an enquiry also registers the
  /// student when their email is new: the desk has to know whether login
  /// details were just emailed before it tells the walk-in to look for them.
  Future<({EmployeeEnquiryCreateResult? result, String? error})> create(
    EmployeeEnquiryDraft draft,
  ) async {
    final invalid = draft.validationError;
    if (invalid != null) return (result: null, error: invalid);

    try {
      final result = await _repository.createEnquiry(draft);
      await refresh();
      return (result: result, error: null);
    } catch (e) {
      return (result: null, error: reportFailure('Enquiry create failed', e));
    }
  }

  /// Edits a staff-entered enquiry. Reloads for the same reason as [create]:
  /// moving it to another batch re-derives the sport and coach server-side.
  Future<String?> update(EmployeeEnquiry enquiry, EmployeeEnquiryDraft draft) async {
    final invalid = draft.validationError;
    if (invalid != null) return invalid;

    try {
      await _repository.updateEnquiry(enquiry.id, draft);
      await refresh();
      return null;
    } catch (e) {
      return reportFailure('Enquiry update failed', e);
    }
  }

  /// Moves the enquiry along the queue without enrolling anyone.
  ///
  /// `Approved` is not offered here — that is [approve]'s job, and setting the
  /// status alone would mark the enquiry done with no student and no fee.
  Future<String?> setEnquiryStatus(EmployeeEnquiry enquiry, String status) async {
    try {
      await _repository.setEnquiryStatus(enquiry.id, status);
      replaceItem(
        (e) => e.id == enquiry.id,
        (e) => e.copyWith(status: status, updatedAt: DateTime.now()),
      );
      return null;
    } catch (e) {
      return reportFailure('Enquiry status failed', e);
    }
  }

  Future<String?> delete(EmployeeEnquiry enquiry) async {
    try {
      await _repository.deleteEnquiry(enquiry.id);
      removeItem((e) => e.id == enquiry.id);
      return null;
    } catch (e) {
      return reportFailure('Enquiry delete failed', e);
    }
  }

  /// Approves and enrols. Returns null on success, else the server's message —
  /// which is the useful one here: it names the batch that was full or says the
  /// enquiry was already settled.
  Future<String?> approve(
    EmployeeEnquiry enquiry, {
    EmployeeEnquiryApprovalDraft draft = EmployeeEnquiryApprovalDraft.pending,
  }) async {
    try {
      await _repository.approveEnquiry(enquiry.id, draft: draft);
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
