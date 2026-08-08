import '../../core/employee_log.dart';
import '../../domain/entities/employee_attendance.dart';
import '../../domain/entities/employee_formats.dart';
import '../../domain/entities/employee_paged.dart';
import '../../domain/repositories/employee_dashboard_repository.dart';
import 'employee_list_controller.dart';

/// Attendance Management.
///
/// **Read-only, deliberately.** Attendance is marked by the coach who runs the
/// batch and at the gate when a student pass is scanned. `POST /attendance`
/// does grant EMPLOYEE, but it upserts on `(studentId, batchId, date)` — a
/// second person marking the same session silently overwrites the coach's
/// record. The website's employee screen drops the Mark button for the same
/// reason, so the app does not offer it either.
class EmployeeAttendanceController
    extends EmployeeListController<EmployeeAttendanceRecord> {
  EmployeeAttendanceController(this._repository);

  final EmployeeDashboardRepository _repository;

  static const List<String> statuses = ['Present', 'Absent', 'Late'];

  DateTime? _date;
  String? _status;

  DateTime? get date => _date;
  String? get status => _status;

  bool get isFiltered => _date != null || _status != null;

  @override
  Future<EmployeePaged<EmployeeAttendanceRecord>> fetchPage(int page) {
    return _repository.getAttendance(
      page: page,
      limit: pageSize,
      date: _date == null ? null : formatIsoDate(_date!),
      status: _status,
    );
  }

  void setDate(DateTime? value) {
    if (value == _date) return;
    _date = value;
    EmployeeLog.ui(
      'Attendance date filter → ${value == null ? 'any' : formatIsoDate(value)}',
    );
    reload();
  }

  void setStatus(String? value) {
    if (value == _status) return;
    _status = value;
    EmployeeLog.ui('Attendance status filter → ${value ?? 'all'}');
    reload();
  }

  void clearFilters() {
    if (!isFiltered) return;
    _date = null;
    _status = null;
    reload();
  }
}
