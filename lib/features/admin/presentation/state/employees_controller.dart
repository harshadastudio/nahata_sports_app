import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../models/sports_complex_model.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/admin_role.dart';
import '../../domain/entities/employee.dart';
import '../../domain/entities/employee_vocabulary.dart';
import '../../domain/entities/paged.dart';
import '../../domain/repositories/employee_repository.dart';
import 'view_state.dart';

/// The columns the employee table can be ordered by.
enum EmployeeSort {
  code('employeeId', 'Employee ID'),
  name('fullName', 'Name'),
  email('email', 'Email'),
  department('department', 'Department'),
  designation('designation', 'Designation'),
  shift('shift', 'Shift'),
  salary('salary', 'Salary'),
  status('status', 'Status'),
  joining('joiningDate', 'Joining date');

  const EmployeeSort(this.wire, this.label);

  final String wire;
  final String label;
}

/// Everything the Employees page needs: server-side pagination, debounced
/// search, four filters, sorting, CRUD and password management.
class EmployeesController extends ChangeNotifier {
  EmployeesController(this._repository) {
    AdminLog.life('EmployeesController created');
  }

  final EmployeeRepository _repository;

  static const Duration searchDebounce = Duration(milliseconds: 400);
  static const List<int> pageSizes = [10, 20, 50, 100];

  ViewState _state = ViewState.idle;
  Paged<Employee> _page = const Paged<Employee>();
  String? _error;

  int _requestedPage = 1;
  int _limit = 20;
  String _search = '';

  AdminUserStatus? _statusFilter;
  Department? _departmentFilter;
  Shift? _shiftFilter;
  int? _complexFilter;

  EmployeeSort? _sort;
  bool _descending = false;

  Timer? _debounce;
  int _requestId = 0;
  bool _disposed = false;

  // Detail drawer.
  Employee? _selected;
  ViewState _detailState = ViewState.idle;
  String? _detailError;

  // Venue list for the form and the complex filter.
  List<SportsComplex> _complexes = const [];
  ViewState _complexesState = ViewState.idle;

  // --- Reads -----------------------------------------------------------------

  ViewState get state => _state;
  Paged<Employee> get page => _page;
  List<Employee> get employees => _sortedRows;
  String? get error => _error;

  int get limit => _limit;
  String get search => _search;

  AdminUserStatus? get statusFilter => _statusFilter;
  Department? get departmentFilter => _departmentFilter;
  Shift? get shiftFilter => _shiftFilter;
  int? get complexFilter => _complexFilter;

  EmployeeSort? get sort => _sort;
  bool get descending => _descending;

  Employee? get selected => _selected;
  ViewState get detailState => _detailState;
  String? get detailError => _detailError;

  List<SportsComplex> get complexes => _complexes;
  ViewState get complexesState => _complexesState;

  /// The venue behind [complexFilter], for the filter chip's label.
  SportsComplex? get filteredComplex {
    final id = _complexFilter;
    if (id == null) return null;
    for (final complex in _complexes) {
      if (complex.id == id) return complex;
    }
    return null;
  }

  bool get hasFilters =>
      _search.trim().isNotEmpty ||
      _statusFilter != null ||
      _departmentFilter != null ||
      _shiftFilter != null ||
      _complexFilter != null;

  /// How many of the four dropdown filters are set — drives the badge on the
  /// Filter button. Search is excluded; it has its own visible box.
  int get activeFilterCount => [
    _statusFilter,
    _departmentFilter,
    _shiftFilter,
    _complexFilter,
  ].where((filter) => filter != null).length;

  bool get isFirstLoad => _state.isLoading && _page.items.isEmpty;
  bool get isRefreshing => _state.isLoading && _page.items.isNotEmpty;

  /// The page as displayed. The server is asked to sort, but a backend that
  /// ignores `sortBy` would leave the header arrow lying, so the received page
  /// is ordered locally too.
  List<Employee> get _sortedRows {
    final rows = List<Employee>.from(_page.items);
    final by = _sort;
    if (by == null) return rows;

    int compare(Employee a, Employee b) {
      switch (by) {
        case EmployeeSort.code:
          return (a.employeeCode ?? '').toLowerCase().compareTo(
            (b.employeeCode ?? '').toLowerCase(),
          );
        case EmployeeSort.name:
          return a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          );
        case EmployeeSort.email:
          return (a.email ?? '').toLowerCase().compareTo(
            (b.email ?? '').toLowerCase(),
          );
        case EmployeeSort.department:
          return a.departmentLabel.compareTo(b.departmentLabel);
        case EmployeeSort.designation:
          return a.designationLabel.compareTo(b.designationLabel);
        case EmployeeSort.shift:
          return a.shiftLabel.compareTo(b.shiftLabel);
        case EmployeeSort.salary:
          return (a.salary ?? 0).compareTo(b.salary ?? 0);
        case EmployeeSort.status:
          return a.statusLabel.compareTo(b.statusLabel);
        case EmployeeSort.joining:
          final first = a.joiningDate;
          final second = b.joiningDate;
          if (first == null || second == null) return 0;
          return first.compareTo(second);
      }
    }

    rows.sort((a, b) {
      // Rows with nothing to sort by sink in BOTH directions — reversing the
      // comparison would otherwise float every blank to the top.
      final missingA = _isMissing(by, a);
      final missingB = _isMissing(by, b);
      if (missingA && missingB) return 0;
      if (missingA != missingB) return missingA ? 1 : -1;

      return _descending ? compare(b, a) : compare(a, b);
    });
    return rows;
  }

  static bool _isMissing(EmployeeSort by, Employee employee) {
    switch (by) {
      case EmployeeSort.code:
        return (employee.employeeCode ?? '').trim().isEmpty;
      case EmployeeSort.salary:
        return employee.salary == null;
      case EmployeeSort.joining:
        return employee.joiningDate == null;
      case EmployeeSort.department:
        return (employee.departmentRaw ?? '').trim().isEmpty;
      case EmployeeSort.designation:
        return (employee.designationRaw ?? '').trim().isEmpty;
      case EmployeeSort.shift:
        return (employee.shiftRaw ?? '').trim().isEmpty;
      case EmployeeSort.name:
      case EmployeeSort.email:
      case EmployeeSort.status:
        return false;
    }
  }

  // --- Loading ---------------------------------------------------------------

  Future<void> load({int? page}) async {
    final target = page ?? _requestedPage;
    final id = ++_requestId;

    AdminLog.state(
      'Employees loading → page=$target limit=$_limit '
      'search="${_search.trim()}" status=${_statusFilter?.slug ?? '-'} '
      'department=${_departmentFilter?.slug ?? '-'} '
      'shift=${_shiftFilter?.slug ?? '-'} complex=${_complexFilter ?? '-'} '
      'sort=${_sort?.wire ?? '-'}'
      '${_sort == null ? '' : (_descending ? ' desc' : ' asc')}',
    );

    _requestedPage = target;
    _state = ViewState.loading;
    _error = null;
    _safeNotify();

    try {
      final result = await _repository.fetchEmployees(
        page: target,
        limit: _limit,
        search: _search.trim().isEmpty ? null : _search.trim(),
        status: _statusFilter,
        department: _departmentFilter,
        shift: _shiftFilter,
        sportComplexId: _complexFilter,
        sortBy: _sort?.wire,
        descending: _descending,
      );

      if (_disposed || id != _requestId) {
        AdminLog.state('Employees response superseded — dropped');
        return;
      }

      _page = result;
      _requestedPage = result.page;
      _state = ViewState.ready;
      AdminLog.state(
        'Employees ready → ${result.items.length} rows, '
        'page ${result.page}/${result.effectiveTotalPages}, '
        'total ${result.total}',
      );
    } on ApiException catch (error) {
      if (_disposed || id != _requestId) return;
      _state = ViewState.failed;
      _error = error.message;
      AdminLog.failure('Employees load failed: ${error.message}', error: error);
    } catch (error, stackTrace) {
      if (_disposed || id != _requestId) return;
      _state = ViewState.failed;
      _error = 'Could not load employees. Please try again.';
      AdminLog.failure(
        'Employees load crashed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _safeNotify();
    }
  }

  Future<void> refresh() {
    AdminLog.ui('Employees refresh requested');
    return load();
  }

  /// Loads the venue list used by both the form and the complex filter.
  Future<void> loadComplexes({bool refresh = false}) async {
    if (_complexesState.isLoading) return;
    if (_complexes.isNotEmpty && !refresh) return;

    AdminLog.state('Employee venue list loading (refresh: $refresh)');
    _complexesState = ViewState.loading;
    _safeNotify();

    try {
      final result = await _repository.fetchSportComplexes(refresh: refresh);
      if (_disposed) return;
      _complexes = result;
      _complexesState = ViewState.ready;
      AdminLog.state('Employee venue list ready → ${result.length}');
    } catch (error, stackTrace) {
      if (_disposed) return;
      _complexesState = ViewState.failed;
      AdminLog.failure(
        'Employee venue list failed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _safeNotify();
    }
  }

  // --- Search, filters, paging ----------------------------------------------

  void onSearchChanged(String value) {
    if (_search == value) return;
    _search = value;
    AdminLog.ui(
      'Employee search typed: "$value" '
      '(debouncing ${searchDebounce.inMilliseconds}ms)',
    );
    notifyListeners();

    _debounce?.cancel();
    _debounce = Timer(searchDebounce, () {
      AdminLog.ui('Employee search settled: "${_search.trim()}"');
      load(page: 1);
    });
  }

  void clearSearch() {
    if (_search.isEmpty) return;
    AdminLog.ui('Employee search cleared');
    _debounce?.cancel();
    _search = '';
    load(page: 1);
  }

  void setStatusFilter(AdminUserStatus? status) {
    if (_statusFilter == status) return;
    AdminLog.ui('Employee status filter → ${status?.slug ?? 'All'}');
    _statusFilter = status;
    load(page: 1);
  }

  void setDepartmentFilter(Department? department) {
    if (_departmentFilter == department) return;
    AdminLog.ui('Employee department filter → ${department?.slug ?? 'All'}');
    _departmentFilter = department;
    load(page: 1);
  }

  void setShiftFilter(Shift? shift) {
    if (_shiftFilter == shift) return;
    AdminLog.ui('Employee shift filter → ${shift?.slug ?? 'All'}');
    _shiftFilter = shift;
    load(page: 1);
  }

  void setComplexFilter(int? sportComplexId) {
    if (_complexFilter == sportComplexId) return;
    AdminLog.ui('Employee complex filter → ${sportComplexId ?? 'All'}');
    _complexFilter = sportComplexId;
    load(page: 1);
  }

  void clearFilters() {
    if (!hasFilters) return;
    AdminLog.ui('All employee filters cleared');
    _debounce?.cancel();
    _search = '';
    _statusFilter = null;
    _departmentFilter = null;
    _shiftFilter = null;
    _complexFilter = null;
    load(page: 1);
  }

  void setLimit(int limit) {
    if (_limit == limit) return;
    AdminLog.ui('Employee page size → $limit');
    _limit = limit;
    load(page: 1);
  }

  /// Same column twice flips direction; a third tap hands ordering back to the
  /// server's default.
  void toggleSort(EmployeeSort column) {
    if (_sort != column) {
      _sort = column;
      _descending = false;
    } else if (!_descending) {
      _descending = true;
    } else {
      _sort = null;
      _descending = false;
    }
    AdminLog.ui(
      'Employee sort → ${_sort?.wire ?? 'default'}'
      '${_sort == null ? '' : (_descending ? ' desc' : ' asc')}',
    );
    load(page: 1);
  }

  void goToPage(int page) {
    final total = _page.effectiveTotalPages;
    final target = total > 0 ? page.clamp(1, total) : page;
    if (target == _page.page && _state.isReady) return;
    AdminLog.ui('Employees go to page $target');
    load(page: target);
  }

  // --- Detail ----------------------------------------------------------------

  /// Shows the row already in hand, then replaces it with the full record.
  Future<void> openEmployee(Employee employee) async {
    AdminLog.ui('Employee detail opened for ${employee.id}');
    _selected = employee;
    _detailState = ViewState.loading;
    _detailError = null;
    _safeNotify();

    try {
      final detail = await _repository.fetchEmployee(employee.id);
      if (_disposed || _selected?.id != employee.id) return;

      _selected = employee.mergedWith(detail);
      _detailState = ViewState.ready;
      AdminLog.state('Employee detail ready for ${employee.id}');
    } on ApiException catch (error) {
      if (_disposed || _selected?.id != employee.id) return;
      _detailState = ViewState.failed;
      _detailError = error.message;
      AdminLog.failure(
        'Employee detail failed: ${error.message}',
        error: error,
      );
    } catch (error, stackTrace) {
      if (_disposed || _selected?.id != employee.id) return;
      _detailState = ViewState.failed;
      _detailError = 'Could not load this employee.';
      AdminLog.failure(
        'Employee detail crashed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _safeNotify();
    }
  }

  void closeEmployee() {
    if (_selected == null) return;
    AdminLog.ui('Employee detail closed');
    _selected = null;
    _detailState = ViewState.idle;
    _detailError = null;
    _safeNotify();
  }

  // --- Writes ----------------------------------------------------------------

  Future<Employee> create(EmployeeDraft draft) async {
    AdminLog.ui('Create employee submitted');
    final created = await _repository.createEmployee(draft);
    await load(page: 1);
    return created;
  }

  Future<Employee> update(
    String id,
    EmployeeDraft draft, {
    bool clearAddress = false,
  }) async {
    AdminLog.ui('Update employee $id submitted');
    final updated = await _repository.updateEmployee(
      id,
      draft,
      clearAddress: clearAddress,
    );

    if (_selected?.id == id) {
      _selected = _selected!.mergedWith(updated);
      _safeNotify();
    }

    await load();
    return updated;
  }

  Future<void> delete(String id) async {
    AdminLog.ui('Delete employee $id confirmed');

    // Optimistic: the row disappears immediately, and is put back if the call
    // fails, so a failed delete never silently loses a row from the table.
    final previous = _page;
    _page = _page.copyWith(
      items: _page.items.where((employee) => employee.id != id).toList(),
      total: _page.total > 0 ? _page.total - 1 : 0,
    );
    if (_selected?.id == id) closeEmployee();
    _safeNotify();

    try {
      await _repository.deleteEmployee(id);
    } catch (error) {
      if (!_disposed) {
        AdminLog.failure('Delete failed — restoring the row', error: error);
        _page = previous;
        _safeNotify();
      }
      rethrow;
    }

    // Reconcile with the server; step back if that was the page's last row.
    final wasLastRowOnPage = previous.items.length == 1 && previous.page > 1;
    await load(page: wasLastRowOnPage ? previous.page - 1 : previous.page);
  }

  // --- Passwords -------------------------------------------------------------
  //
  // Credentials are returned to the caller and never held on this controller:
  // the dialog owns them for as long as it is open, and they go with it.

  Future<EmployeeCredentials> fetchCredentials(String id) {
    AdminLog.ui('View password requested for employee $id');
    return _repository.fetchCredentials(id);
  }

  Future<void> resetPassword(String id, String password) {
    AdminLog.ui('Password reset submitted for employee $id');
    return _repository.resetPassword(id, password);
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    AdminLog.life('EmployeesController disposed');
    super.dispose();
  }
}
