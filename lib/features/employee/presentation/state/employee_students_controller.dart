import '../../core/employee_log.dart';
import '../../domain/entities/employee_paged.dart';
import '../../domain/entities/employee_student.dart';
import '../../domain/repositories/employee_dashboard_repository.dart';
import 'employee_list_controller.dart';

/// Student List — the desk's roster.
///
/// Edits are patched into the row in place rather than re-read: the five fields
/// the form owns are all shown on the card, so the list can be corrected
/// locally without a round trip that would lose the user's scroll position.
/// A delete removes the row for the same reason.
class EmployeeStudentsController extends EmployeeListController<EmployeeStudent> {
  EmployeeStudentsController(this._repository);

  final EmployeeDashboardRepository _repository;

  String _search = '';

  String get search => _search;

  bool get isFiltered => _search.trim().isNotEmpty;

  @override
  Future<EmployeePaged<EmployeeStudent>> fetchPage(int page) {
    return _repository.getStudents(
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
      EmployeeLog.ui('Student search → "${_search.trim()}"');
      load();
    });
  }

  void clearFilters() {
    cancelDebounce();
    if (!isFiltered) return;
    _search = '';
    reload();
  }

  /// Saves the panel form's five fields. Returns null on success, else the
  /// server's own message.
  Future<String?> save(EmployeeStudent student, EmployeeStudentDraft draft) async {
    try {
      await _repository.updateStudent(student.id, draft);

      replaceItem(
        (s) => s.id == student.id,
        (s) => s.copyWith(
          name: draft.name,
          phone: draft.phone,
          gender: draft.gender,
          bloodGroup: draft.bloodGroup,
          dob: draft.dob,
        ),
      );
      return null;
    } catch (e) {
      return reportFailure('Student save failed', e);
    }
  }

  Future<String?> delete(EmployeeStudent student) async {
    try {
      await _repository.deleteStudent(student.id);
      removeItem((s) => s.id == student.id);
      return null;
    } catch (e) {
      return reportFailure('Student delete failed', e);
    }
  }

  /// Sends a note the student sees on their own dashboard. Nothing on the list
  /// changes, so no row is touched.
  Future<String?> sendFeedback(
    EmployeeStudent student,
    EmployeeStudentFeedbackDraft draft,
  ) async {
    try {
      await _repository.sendStudentFeedback(student.id, draft);
      return null;
    } catch (e) {
      return reportFailure('Student feedback failed', e);
    }
  }
}
