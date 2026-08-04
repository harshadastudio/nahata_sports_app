import '../../../../core/network/api_exception.dart';
import '../../../../models/sports_complex_model.dart';
import '../../../../repositories/sports_complex_repository.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/admin_role.dart';
import '../../domain/entities/employee.dart';
import '../../domain/entities/employee_vocabulary.dart';
import '../../domain/entities/paged.dart';
import '../../domain/repositories/employee_repository.dart';
import '../datasources/employee_remote_data_source.dart';
import '../models/employee_model.dart';

/// [EmployeeRepository] over the JWT backend.
///
/// The venue list is delegated to the app's shared [SportsComplexRepository],
/// the same one the Complex Admin form uses, so the two cannot disagree about
/// what venues exist.
class EmployeeRepositoryImpl implements EmployeeRepository {
  EmployeeRepositoryImpl({
    EmployeeRemoteDataSource? remote,
    SportsComplexRepository? complexes,
  }) : _remote = remote ?? EmployeeRemoteDataSource(),
       _complexes = complexes ?? SportsComplexRepository.instance;

  final EmployeeRemoteDataSource _remote;
  final SportsComplexRepository _complexes;

  @override
  Future<Paged<Employee>> fetchEmployees({
    int page = 1,
    int limit = 20,
    String? search,
    AdminUserStatus? status,
    Department? department,
    Shift? shift,
    int? sportComplexId,
    String? sortBy,
    bool descending = false,
  }) async {
    final response = await _remote.list(
      page: page,
      limit: limit,
      search: search,
      status: status,
      department: department,
      shift: shift,
      sportComplexId: sportComplexId,
      sortBy: sortBy,
      descending: descending,
    );
    if (!response.isOk) throw response.toException();

    final result = EmployeeMapper.pageFrom(
      response.data,
      fallbackPage: page,
      fallbackLimit: limit,
    );
    AdminLog.data('Employees → $result');
    return result;
  }

  @override
  Future<Employee> fetchEmployee(String id) async {
    final response = await _remote.detail(id);
    if (!response.isOk) throw response.toException();

    final employee = EmployeeMapper.fromJson(response.payload);
    AdminLog.data('Employee detail → $employee');
    return employee;
  }

  @override
  Future<Employee> createEmployee(EmployeeDraft draft) async {
    final body = draft.toCreateJson();

    // Fail before the round trip rather than let the server reject a body it
    // could never accept.
    if (body['sportComplexId'] == null) {
      throw const ValidationException('Pick a sports complex.');
    }

    final response = await _remote.create(body);
    if (!response.isOk) throw response.toException();

    final created = EmployeeMapper.maybeFromBody(response.data);
    AdminLog.success('Created employee ${created?.id ?? '(id not echoed)'}');

    return created ??
        Employee(
          id: '',
          employeeCode: draft.employeeCode,
          fullName: draft.fullName,
          email: draft.email,
          phone: draft.phone,
        );
  }

  @override
  Future<Employee> updateEmployee(
    String id,
    EmployeeDraft draft, {
    bool clearAddress = false,
  }) async {
    final body = draft.toUpdateJson(clearAddress: clearAddress);
    if (body.isEmpty) {
      throw const BadRequestException('Nothing to update.');
    }

    final response = await _remote.update(id, body);
    if (!response.isOk) throw response.toException();

    AdminLog.success('Updated employee $id');
    return EmployeeMapper.maybeFromBody(response.data) ?? Employee(id: id);
  }

  @override
  Future<void> deleteEmployee(String id) async {
    final response = await _remote.remove(id);
    if (!response.isOk) throw response.toException();
    AdminLog.success('Deleted employee $id');
  }

  @override
  Future<EmployeeCredentials> fetchCredentials(String id) async {
    final response = await _remote.credentials(id);
    if (!response.isOk) throw response.toException();

    final credentials = EmployeeCredentialsMapper.fromJson(response.payload);

    // Logs whether a password came back, never the password itself.
    AdminLog.data(
      'Credentials for $id → '
      'password ${credentials.hasPassword ? 'present' : 'absent'}',
    );
    return credentials;
  }

  @override
  Future<void> resetPassword(String id, String password) async {
    final response = await _remote.resetPassword(id, password);
    if (!response.isOk) throw response.toException();
    AdminLog.success('Password reset for employee $id');
  }

  @override
  Future<List<SportsComplex>> fetchSportComplexes({
    bool refresh = false,
  }) async {
    final complexes = await _complexes.fetchComplexes(
      refresh: refresh,
      includeHidden: true,
    );
    AdminLog.data('Sport complexes for employee form → ${complexes.length}');
    return complexes;
  }
}
