import '../../core/employee_log.dart';
import '../../domain/entities/employee_coach.dart';
import '../../domain/entities/employee_paged.dart';
import '../../domain/repositories/employee_dashboard_repository.dart';
import 'employee_list_controller.dart';

/// Coaches Management.
///
/// Read-only: creating and editing a coach are admin routes. The desk uses this
/// to look up who runs a batch and how to reach them, which is what the
/// website's screen does too.
class EmployeeCoachesController extends EmployeeListController<EmployeeCoach> {
  EmployeeCoachesController(this._repository);

  final EmployeeDashboardRepository _repository;

  String _search = '';

  String get search => _search;
  bool get isFiltered => _search.trim().isNotEmpty;

  @override
  Future<EmployeePaged<EmployeeCoach>> fetchPage(int page) {
    return _repository.getCoaches(
      page: page,
      limit: pageSize,
      search: _search.trim().isEmpty ? null : _search.trim(),
    );
  }

  void onSearchChanged(String value) {
    if (value == _search) return;
    _search = value;
    notify();

    debounce(() {
      EmployeeLog.ui('Coach search → "${_search.trim()}"');
      load();
    });
  }

  void clearSearch() {
    cancelDebounce();
    if (_search.isEmpty) return;
    _search = '';
    load();
  }
}
