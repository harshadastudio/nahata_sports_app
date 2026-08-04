import '../../domain/entities/employee.dart';
import '../../domain/entities/paged.dart';
import 'json_reader.dart';

/// Maps `/admin/employees` JSON onto [Employee].
class EmployeeMapper {
  const EmployeeMapper._();

  static Employee fromJson(Map<String, dynamic> json) {
    final source = _unwrap(json);

    final complex = _nested(source, const [
      'sportComplex',
      'sport_complex',
      'sportsComplex',
      'complex',
    ]);

    return Employee(
      // Top-level only: the row embeds a `user`, and inheriting its `id`
      // would address the wrong record on every `/{employeeId}` call.
      id:
          JsonReader.ownString(source, const ['id', '_id', 'employeeDbId']) ??
          '',
      // Distinct from `id`: the staff-facing code. `employeeId` is the key the
      // create payload uses for it, which is why it is read here and not as
      // the primary id.
      employeeCode: JsonReader.ownString(source, const [
        'employeeId',
        'employee_id',
        'employeeCode',
        'empId',
        'staffId',
      ]),
      fullName: JsonReader.string(source, const [
        'fullName',
        'full_name',
        'name',
        'employeeName',
      ]),
      email: JsonReader.string(source, const ['email', 'emailAddress']),
      phone: JsonReader.string(source, const [
        'phone',
        'phoneNumber',
        'phone_number',
        'mobile',
      ]),
      sportComplexId:
          JsonReader.integer(source, const [
            'sportComplexId',
            'sport_complex_id',
            'sportsComplexId',
            'complexId',
          ]) ??
          (complex == null
              ? null
              : JsonReader.integer(complex, const ['id', '_id'])),
      sportComplexName:
          JsonReader.string(source, const [
            'sportComplexName',
            'sport_complex_name',
            'complexName',
          ]) ??
          (complex == null
              ? null
              : JsonReader.string(complex, const ['name', 'title'])),
      departmentRaw: JsonReader.string(source, const ['department', 'dept']),
      designationRaw: JsonReader.string(source, const [
        'designation',
        'jobTitle',
        'role',
        'position',
      ]),
      shiftRaw: JsonReader.string(source, const ['shift', 'shiftType']),
      salary: _number(source, const ['salary', 'monthlySalary', 'pay']),
      statusRaw: JsonReader.string(source, const ['status', 'accountStatus']),
      joiningDate: JsonReader.date(source, const [
        'joiningDate',
        'joining_date',
        'dateOfJoining',
        'joinDate',
        'createdAt',
      ]),
      address: JsonReader.string(source, const [
        'address',
        'residentialAddress',
        'fullAddress',
      ]),
      raw: source,
    );
  }

  static List<Employee> listFrom(Object? body) {
    return JsonReader.records(
          body,
          keys: const ['employees', 'items', 'data', 'results', 'records'],
        )
        .map(fromJson)
        .where((employee) => employee.id.isNotEmpty)
        .toList(growable: false);
  }

  static Paged<Employee> pageFrom(
    Object? body, {
    required int fallbackPage,
    required int fallbackLimit,
  }) {
    final items = listFrom(body);
    final meta = JsonReader.meta(body);

    return Paged<Employee>(
      items: items,
      page:
          JsonReader.integer(meta, const [
            'page',
            'currentPage',
            'current_page',
          ]) ??
          fallbackPage,
      limit:
          JsonReader.integer(meta, const [
            'limit',
            'perPage',
            'per_page',
            'pageSize',
          ]) ??
          fallbackLimit,
      total:
          JsonReader.integer(meta, const [
            'total',
            'totalItems',
            'totalRecords',
            'totalEmployees',
            'count',
          ]) ??
          items.length,
      totalPages:
          JsonReader.integer(meta, const [
            'totalPages',
            'total_pages',
            'pageCount',
            'lastPage',
          ]) ??
          0,
    );
  }

  static Employee? maybeFromBody(Object? body) {
    if (body is! Map) return null;
    final employee = fromJson(Map<String, dynamic>.from(body));
    return employee.id.isEmpty ? null : employee;
  }

  /// Salary arrives as `35000`, `35000.50` or `"35000"`.
  static num? _number(Map<String, dynamic> json, List<String> keys) {
    final value = JsonReader.pick(json, keys);
    if (value == null) return null;
    if (value is num) return value;
    // Strip currency symbols and separators before parsing.
    final text = value.toString().trim().replaceAll(RegExp(r'[^\d.\-]'), '');
    if (text.isEmpty) return null;
    return num.tryParse(text);
  }

  static Map<String, dynamic>? _nested(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = json[key];
      if (value is Map) return Map<String, dynamic>.from(value);
    }
    return null;
  }

  static Map<String, dynamic> _unwrap(Map<String, dynamic> json) {
    // `user` is deliberately absent: an employee row embeds the person it
    // belongs to, and descending into it would swap the staff record for the
    // user. Display fields still resolve through JsonReader.pick's own
    // envelope fallback.
    for (final key in const ['employee', 'data', 'result']) {
      final inner = json[key];
      if (inner is Map) {
        final unwrapped = Map<String, dynamic>.from(inner);
        for (final nested in const ['employee', 'data']) {
          final deeper = unwrapped[nested];
          if (deeper is Map) return Map<String, dynamic>.from(deeper);
        }
        return unwrapped;
      }
    }
    return json;
  }
}

/// Maps `GET /admin/employees/{id}/password`.
class EmployeeCredentialsMapper {
  const EmployeeCredentialsMapper._();

  static EmployeeCredentials fromJson(Map<String, dynamic> json) {
    final source = _unwrap(json);

    return EmployeeCredentials(
      email: JsonReader.string(source, const ['email', 'emailAddress']),
      password: JsonReader.string(source, const [
        'temporaryPassword',
        'temporary_password',
        'tempPassword',
        'password',
        'plainPassword',
        'defaultPassword',
      ]),
    );
  }

  static Map<String, dynamic> _unwrap(Map<String, dynamic> json) {
    for (final key in const ['credentials', 'data', 'result']) {
      final inner = json[key];
      if (inner is Map) return Map<String, dynamic>.from(inner);
    }
    return json;
  }
}
