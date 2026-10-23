import '../../core/employee_log.dart';
import '../../domain/entities/employee_event.dart';
import '../../domain/entities/employee_paged.dart';
import '../../domain/repositories/employee_dashboard_repository.dart';
import 'employee_list_controller.dart';

/// Events — the complex's event passes and the slots people buy.
///
/// The upcoming/past split is a **server-side** filter, not a local one: a past
/// event can be many pages back, so switching tabs re-runs the query rather
/// than sieving the rows already in hand.
class EmployeeEventsController extends EmployeeListController<EmployeeEvent> {
  EmployeeEventsController(this._repository);

  final EmployeeDashboardRepository _repository;

  EmployeeEventTimeframe _timeframe = EmployeeEventTimeframe.upcoming;

  EmployeeEventTimeframe get timeframe => _timeframe;

  @override
  Future<EmployeePaged<EmployeeEvent>> fetchPage(int page) {
    return _repository.getEvents(
      page: page,
      limit: pageSize,
      timeframe: _timeframe,
    );
  }

  void setTimeframe(EmployeeEventTimeframe value) {
    if (value == _timeframe) return;
    _timeframe = value;
    EmployeeLog.ui('Events timeframe → ${value.label}');
    reload();
  }

  /// Re-reads one event in full.
  ///
  /// The list route does not reliably carry the custom fields and FAQs, so the
  /// edit form opens on this rather than on the row it was tapped from —
  /// otherwise saving would send back empty arrays and delete them.
  Future<EmployeeEvent?> loadDetail(int id) async {
    try {
      return await _repository.getEvent(id);
    } catch (e) {
      reportFailure('Event detail failed', e);
      return null;
    }
  }

  Future<String?> create(EmployeeEventDraft draft) =>
      _write('Event create', () => _repository.createEvent(draft));

  Future<String?> update(int id, EmployeeEventDraft draft) =>
      _write('Event update', () => _repository.updateEvent(id, draft));

  Future<String?> delete(EmployeeEvent event) async {
    try {
      await _repository.deleteEvent(event.id);
      removeItem((e) => e.id == event.id);
      return null;
    } catch (e) {
      return reportFailure('Event delete failed', e);
    }
  }

  /// A write always re-reads: the server assigns ids to new slots, fields and
  /// FAQs, and an edit form reopened on the un-refreshed row would send those
  /// children back without ids and duplicate them.
  Future<String?> _write(String what, Future<void> Function() action) async {
    try {
      await action();
      await refresh();
      return null;
    } catch (e) {
      return reportFailure('$what failed', e);
    }
  }
}
