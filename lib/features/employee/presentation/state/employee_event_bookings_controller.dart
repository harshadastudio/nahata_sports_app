import '../../core/employee_log.dart';
import '../../domain/entities/employee_event_booking.dart';
import '../../domain/entities/employee_paged.dart';
import '../../domain/repositories/employee_dashboard_repository.dart';
import 'employee_list_controller.dart';

/// Issue Event Pass — the bookings made against this complex's events, and the
/// individual passes issued on each.
///
/// Two things here are not like the other list screens:
///
/// * **A booking is not a pass.** Emailing "the booking" means calling the
///   individual-pass route once per pass, which is what [emailAllPasses] does —
///   and why it reports how many of them actually landed rather than a bare
///   success. The passes themselves arrive on the booking row's own
///   `individualPasses[]`, so nothing here fetches them separately.
/// * **Rows can be multi-selected** for the bulk delete, so the selection lives
///   here rather than in the widget: a reload must not silently keep ids that
///   are no longer on screen.
class EmployeeEventBookingsController
    extends EmployeeListController<EmployeeEventBooking> {
  EmployeeEventBookingsController(this._repository);

  final EmployeeDashboardRepository _repository;

  final Set<int> _selected = <int>{};

  Set<int> get selected => Set.unmodifiable(_selected);

  bool get isSelecting => _selected.isNotEmpty;

  int get selectedCount => _selected.length;

  bool isSelected(int id) => _selected.contains(id);

  @override
  Future<EmployeePaged<EmployeeEventBooking>> fetchPage(int page) {
    return _repository.getEventBookings(page: page, limit: pageSize);
  }

  @override
  Future<void> load({bool silent = false}) async {
    await super.load(silent: silent);
    // Rows that are no longer listed cannot stay selected — the bulk delete
    // would otherwise act on something the user can no longer see.
    _pruneSelection();
  }

  void toggleSelected(int id) {
    if (!_selected.remove(id)) _selected.add(id);
    notify();
  }

  void clearSelection() {
    if (_selected.isEmpty) return;
    _selected.clear();
    notify();
  }

  void selectAllLoaded() {
    _selected.addAll(items.map((booking) => booking.id));
    notify();
  }

  void _pruneSelection() {
    if (_selected.isEmpty) return;
    final visible = items.map((booking) => booking.id).toSet();
    final before = _selected.length;
    _selected.retainWhere(visible.contains);
    if (_selected.length != before) notify();
  }

  Future<String?> emailPass(
    EmployeeIndividualPass pass,
    String address, {
    String? recipientName,
  }) async {
    final draft = EmployeeEventPassEmailDraft(
      email: address,
      recipientName: recipientName,
    );
    if (!draft.isValid) return 'Enter a valid email address.';

    try {
      await _repository.emailEventPass(pass.id, draft);
      return null;
    } catch (e) {
      return reportFailure('Event pass email failed', e);
    }
  }

  /// Emails every pass on a booking, one call per pass.
  ///
  /// The passes are sent one at a time on purpose — the route takes a single
  /// pass id, and firing them together would make a partial failure impossible
  /// to report accurately. Returns null when all of them landed, else a message
  /// naming how many did not: telling a guest "sent" when three of five
  /// bounced is worse than telling the truth.
  Future<String?> emailAllPasses(
    EmployeeEventBooking booking,
    String address,
  ) async {
    final draft = EmployeeEventPassEmailDraft(email: address);
    if (!draft.isValid) return 'Enter a valid email address.';

    // The passes ride along with the booking row — there is no route that
    // fetches them on their own, so an empty list here means the booking
    // genuinely has none.
    final passes = booking.passes;
    if (passes.isEmpty) return 'There are no passes on this booking to send.';

    var failed = 0;
    for (final pass in passes) {
      try {
        await _repository.emailEventPass(
          pass.id,
          EmployeeEventPassEmailDraft(
            email: address,
            recipientName:
                pass.holderName.trim().isEmpty ? null : pass.holderName.trim(),
          ),
        );
      } catch (e) {
        failed += 1;
        EmployeeLog.failure('Pass ${pass.id} email failed', error: e);
      }
    }

    if (failed == 0) return null;
    if (failed == passes.length) {
      return 'None of the ${passes.length} passes could be sent.';
    }
    return '$failed of ${passes.length} passes could not be sent.';
  }

  Future<String?> delete(EmployeeEventBooking booking) async {
    try {
      await _repository.deleteEventBooking(booking.id);
      removeItem((b) => b.id == booking.id);
      _selected.remove(booking.id);
      notify();
      return null;
    } catch (e) {
      return reportFailure('Event booking delete failed', e);
    }
  }

  /// Deletes every selected booking in one call.
  Future<String?> deleteSelected() async {
    if (_selected.isEmpty) return null;

    final ids = _selected.toList(growable: false);
    try {
      await _repository.deleteEventBookings(ids);

      final removed = ids.toSet();
      for (final id in ids) {
        removeItem((b) => b.id == id);
      }
      _selected.removeAll(removed);
      notify();
      return null;
    } catch (e) {
      return reportFailure('Event bookings bulk delete failed', e);
    }
  }
}
