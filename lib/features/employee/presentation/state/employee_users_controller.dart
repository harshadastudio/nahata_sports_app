import '../../core/employee_log.dart';
import '../../domain/entities/employee_paged.dart';
import '../../domain/entities/employee_user.dart';
import '../../domain/repositories/employee_dashboard_repository.dart';
import 'employee_list_controller.dart';

/// Users Management.
///
/// View and edit only. `POST /admin/create-user` and `DELETE /admin/users/{id}`
/// do not grant EMPLOYEE, so the app offers neither — the website's screen
/// makes the same cut.
class EmployeeUsersController extends EmployeeListController<EmployeeUser> {
  EmployeeUsersController(this._repository);

  final EmployeeDashboardRepository _repository;

  String _search = '';
  String? _status;
  String? _membershipType;

  String get search => _search;
  String? get status => _status;
  String? get membershipType => _membershipType;

  bool get isFiltered =>
      _search.trim().isNotEmpty || _status != null || _membershipType != null;

  @override
  Future<EmployeePaged<EmployeeUser>> fetchPage(int page) {
    return _repository.getUsers(
      page: page,
      limit: pageSize,
      search: _search.trim().isEmpty ? null : _search.trim(),
      status: _status,
      membershipType: _membershipType,
    );
  }

  void onSearchChanged(String value) {
    if (value == _search) return;
    _search = value;
    notify();

    debounce(() {
      EmployeeLog.ui('User search → "${_search.trim()}"');
      load();
    });
  }

  void setStatus(String? value) {
    if (value == _status) return;
    _status = value;
    EmployeeLog.ui('User status filter → ${value ?? 'all'}');
    reload();
  }

  void setMembershipType(String? value) {
    if (value == _membershipType) return;
    _membershipType = value;
    EmployeeLog.ui('User membership filter → ${value ?? 'all'}');
    reload();
  }

  void clearFilters() {
    cancelDebounce();
    if (!isFiltered) return;
    _search = '';
    _status = null;
    _membershipType = null;
    reload();
  }

  /// Saves the six editable fields.
  ///
  /// [EmployeeUser.role] is round-tripped rather than offered: the route echoes
  /// whatever it is given, and an employee has no business changing someone's
  /// role — but omitting the key entirely would blank it.
  Future<String?> save(
    EmployeeUser user, {
    required String name,
    required String phoneNumber,
    required String email,
    required String membershipType,
    required String status,
  }) async {
    try {
      await _repository.updateUser(
        user.id,
        employeeUserUpdateBody(
          name: name,
          phoneNumber: phoneNumber,
          email: email,
          role: user.role,
          membershipType: membershipType,
          status: status,
        ),
      );

      replaceItem(
        (u) => u.id == user.id,
        (u) => u.copyWith(
          name: name.trim(),
          phoneNumber: phoneNumber.trim(),
          email: email.trim(),
          membershipType: membershipType,
          status: status,
        ),
      );
      return null;
    } catch (e) {
      return reportFailure('User save failed', e);
    }
  }
}
