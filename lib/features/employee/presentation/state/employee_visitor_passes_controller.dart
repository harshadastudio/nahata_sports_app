import '../../core/employee_log.dart';
import '../../domain/entities/employee_paged.dart';
import '../../domain/entities/employee_visitor_pass.dart';
import '../../domain/repositories/employee_dashboard_repository.dart';
import 'employee_list_controller.dart';

/// Visitor List — generate a gate pass, email it, delete it.
///
/// Scanning is not here. The lifecycle a pass moves through (`Active → In →
/// Out`) is driven by the security console, so nothing in this controller
/// advances a status; the desk only issues and revokes.
///
/// The route takes no filters, so this is the one list screen with none. It is
/// still paginated, so it still appends.
class EmployeeVisitorPassesController
    extends EmployeeListController<EmployeeVisitorPass> {
  EmployeeVisitorPassesController(this._repository);

  final EmployeeDashboardRepository _repository;

  /// The pass the last successful [generate] produced.
  ///
  /// Held so the confirmation sheet can be shown straight from the create
  /// answer, without a round trip for a pass that is already in hand.
  EmployeeVisitorPass? _lastGenerated;

  EmployeeVisitorPass? get lastGenerated => _lastGenerated;

  @override
  Future<EmployeePaged<EmployeeVisitorPass>> fetchPage(int page) {
    return _repository.getVisitorPasses(page: page, limit: pageSize);
  }

  /// Generates a pass and reloads the list. Returns null on success, else the
  /// server's message; read [lastGenerated] for the pass itself.
  Future<String?> generate(EmployeeVisitorPassDraft draft) async {
    try {
      _lastGenerated = await _repository.createVisitorPass(draft);
      await refresh();
      return null;
    } catch (e) {
      _lastGenerated = null;
      return reportFailure('Visitor pass generate failed', e);
    }
  }

  /// Re-reads one pass and patches it onto the list.
  ///
  /// The route takes the numeric id or the pass number, and it is the only way
  /// to see the gate's current status — the desk never advances it, so a row
  /// that was `Active` when the list loaded may since have been scanned in.
  ///
  /// Returns null when the read fails; the sheet then keeps the row it opened
  /// with rather than showing an error over details already on screen.
  Future<EmployeeVisitorPass?> loadPass(EmployeeVisitorPass pass) async {
    try {
      final fresh = await _repository.getVisitorPass(pass.id);
      replaceItem((p) => p.id == pass.id, (_) => fresh);
      return fresh;
    } catch (e) {
      EmployeeLog.failure('Visitor pass ${pass.id} read failed', error: e);
      return null;
    }
  }

  void clearLastGenerated() {
    if (_lastGenerated == null) return;
    _lastGenerated = null;
    notify();
  }

  Future<String?> email(EmployeeVisitorPass pass, String address) async {
    final draft = EmployeeVisitorPassEmailDraft(email: address);
    if (!draft.isValid) return 'Enter a valid email address.';

    try {
      await _repository.emailVisitorPass(pass.id, draft);
      EmployeeLog.ui('Pass ${pass.displayCode} emailed to ${address.trim()}');
      return null;
    } catch (e) {
      return reportFailure('Visitor pass email failed', e);
    }
  }

  Future<String?> delete(EmployeeVisitorPass pass) async {
    try {
      await _repository.deleteVisitorPass(pass.id);
      removeItem((p) => p.id == pass.id);
      return null;
    } catch (e) {
      return reportFailure('Visitor pass delete failed', e);
    }
  }
}
