import '../../../../models/sports_complex_model.dart';
import '../entities/admin_role.dart';
import '../entities/employee.dart';
import '../entities/employee_vocabulary.dart';
import '../entities/paged.dart';

/// Employee CRUD, password management, and the venue list its form needs.
///
/// Reads and writes both throw so the page or dialog can surface the server's
/// own message rather than a generic failure.
abstract class EmployeeRepository {
  /// `GET /admin/employees?page=&limit=&search=` plus the filter parameters.
  Future<Paged<Employee>> fetchEmployees({
    int page,
    int limit,
    String? search,
    AdminUserStatus? status,
    Department? department,
    Shift? shift,
    int? sportComplexId,
    String? sortBy,
    bool descending,
  });

  /// `GET /admin/employees/{employeeId}`
  Future<Employee> fetchEmployee(String id);

  /// `POST /admin/employees`
  Future<Employee> createEmployee(EmployeeDraft draft);

  /// `PUT /admin/employees/{employeeId}`
  Future<Employee> updateEmployee(
    String id,
    EmployeeDraft draft, {
    bool clearAddress,
  });

  /// `DELETE /admin/employees/{employeeId}`
  Future<void> deleteEmployee(String id);

  /// `GET /admin/employees/{employeeId}/password`
  ///
  /// The result is shown once and never persisted.
  Future<EmployeeCredentials> fetchCredentials(String id);

  /// `POST /admin/employees/{employeeId}/reset-password`
  Future<void> resetPassword(String id, String password);

  /// Venues for the form's searchable dropdown, from `GET /sports-complexes`.
  Future<List<SportsComplex>> fetchSportComplexes({bool refresh});
}
