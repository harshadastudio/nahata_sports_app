import '../../core/employee_log.dart';
import '../../domain/entities/employee_coach.dart';
import '../../domain/entities/employee_formats.dart';
import '../../domain/entities/employee_master.dart';
import '../../domain/repositories/employee_dashboard_repository.dart';
import 'employee_collection_controller.dart';

/// Employee → Sports.
///
/// No `sportComplexId` is ever sent: `complexScope.js` stamps the employee's
/// own complex on a write and filters reads by it, so a client-supplied value
/// would be ignored and a complex picker would imply a choice that is not
/// there.
class EmployeeSportsController
    extends EmployeeCollectionController<EmployeeSport> {
  EmployeeSportsController(this._repository);

  final EmployeeDashboardRepository _repository;

  @override
  Future<List<EmployeeSport>> fetch() => _repository.getSports();

  Future<String?> save({
    required int? id,
    required String name,
    String? description,
    String? category,
    int? minAge,
    int? maxAge,
    int? allowedMembers,
    required String status,
  }) {
    final body = <String, dynamic>{
      'name': name.trim(),
      'description': _orNull(description),
      'category': _orNull(category),
      'minAge': minAge,
      'maxAge': maxAge,
      'allowedMembers': allowedMembers,
      'status': status,
    };

    return write(
      id == null ? 'Sport create' : 'Sport update',
      () => id == null
          ? _repository.createSport(body)
          : _repository.updateSport(id, body),
    );
  }

  Future<String?> delete(EmployeeSport sport) =>
      write('Sport delete', () => _repository.deleteSport(sport.id));
}

/// Employee → Court.
///
/// Carries the sport list too: a court belongs to a sport, and the form cannot
/// be filled in without it.
class EmployeeCourtsController
    extends EmployeeCollectionController<EmployeeCourt> {
  EmployeeCourtsController(this._repository);

  final EmployeeDashboardRepository _repository;

  List<EmployeeSport> _sports = const [];
  List<EmployeeSport> get sports => _sports;

  /// Whether a court can be added at all. A court needs a sport, so an empty
  /// complex has to start there.
  bool get canCreate => _sports.isNotEmpty;

  @override
  Future<List<EmployeeCourt>> fetch() async {
    // Fired together: the form needs both, and the sport list is small.
    final results = await Future.wait([
      _repository.getCourts(),
      _repository.getSports(),
    ]);

    _sports = results[1] as List<EmployeeSport>;
    return results[0] as List<EmployeeCourt>;
  }

  Future<String?> save({
    required int? id,
    required String name,
    required int sportId,
    int? capacity,
    String? surfaceType,
    required bool lightingAvailable,
    required num hourlyRate,
    required String status,
  }) {
    final body = <String, dynamic>{
      'name': name.trim(),
      'sportId': sportId,
      'capacity': capacity,
      'surfaceType': _orNull(surfaceType),
      'lightingAvailable': lightingAvailable,
      'hourlyRate': hourlyRate,
      'status': status,
    };

    return write(
      id == null ? 'Court create' : 'Court update',
      () => id == null
          ? _repository.createCourt(body)
          : _repository.updateCourt(id, body),
    );
  }

  Future<String?> delete(EmployeeCourt court) =>
      write('Court delete', () => _repository.deleteCourt(court.id));
}

/// Employee → Slot.
///
/// Slots hang off a court, so the court is picked first and the list re-reads
/// when it changes. The first court is selected automatically — landing on an
/// empty screen with a picker the user has not noticed is worse than showing
/// one court's slots.
class EmployeeSlotsController
    extends EmployeeCollectionController<EmployeeSlot> {
  EmployeeSlotsController(this._repository);

  final EmployeeDashboardRepository _repository;

  List<EmployeeCourt> _courts = const [];
  EmployeeCourt? _court;

  List<EmployeeCourt> get courts => _courts;
  EmployeeCourt? get court => _court;

  bool get hasCourt => _court != null;

  @override
  Future<List<EmployeeSlot>> fetch() async {
    if (_courts.isEmpty) {
      _courts = await _repository.getCourts();
      _court ??= _courts.isEmpty ? null : _courts.first;
    }

    final court = _court;
    if (court == null) return const [];

    return _repository.getSlots(court.id);
  }

  void selectCourt(EmployeeCourt? court) {
    if (court?.id == _court?.id) return;
    _court = court;
    EmployeeLog.ui('Slot court → ${court?.displayName ?? 'none'}');
    load();
  }

  Future<String?> save({
    required int? id,
    required EmployeeSlotDraft draft,
  }) {
    final court = _court;
    if (court == null) {
      return Future.value('Pick a court first.');
    }

    return write(
      id == null ? 'Slot create' : 'Slot update',
      () => id == null
          ? _repository.createSlot(court.id, draft.toBody())
          : _repository.updateSlot(court.id, id, draft.toBody()),
    );
  }

  /// Flips the slot **template**, which applies to every date. A one-day block
  /// belongs on the Blocked Slots screen.
  Future<String?> toggleStatus(EmployeeSlot slot) {
    final court = _court;
    if (court == null) return Future.value('Pick a court first.');

    final next = slot.isActive ? 'Inactive' : 'Active';
    return write(
      'Slot toggle',
      () => _repository.setSlotStatus(court.id, slot.id, next),
    );
  }

  Future<String?> delete(EmployeeSlot slot) {
    final court = _court;
    if (court == null) return Future.value('Pick a court first.');

    return write('Slot delete', () => _repository.deleteSlot(court.id, slot.id));
  }
}

/// Employee → Batch.
///
/// Carries the sport and coach lists for the form. A coach is optional — an
/// unassigned batch is a real state, not a half-filled form.
class EmployeeBatchesController
    extends EmployeeCollectionController<EmployeeBatch> {
  EmployeeBatchesController(this._repository);

  final EmployeeDashboardRepository _repository;

  List<EmployeeSport> _sports = const [];
  List<EmployeeCoach> _coaches = const [];

  List<EmployeeSport> get sports => _sports;
  List<EmployeeCoach> get coaches => _coaches;

  bool get canCreate => _sports.isNotEmpty;

  @override
  Future<List<EmployeeBatch>> fetch() async {
    final batches = await _repository.getBatches();

    // The pickers are secondary — a failure here must not stop the batch list
    // from rendering, so they are pulled separately and swallowed. An employee
    // without the Sports or Coaches permission gets a 403 and should still be
    // able to read their batches.
    try {
      final sports = _repository.getSports();
      // Coaches come back paginated; one page of 200 covers a complex.
      final coaches = _repository.getCoaches(limit: 200);
      _sports = await sports;
      _coaches = (await coaches).items;
    } catch (e) {
      EmployeeLog.failure('Batch pickers failed', error: e);
    }

    return batches;
  }

  Future<String?> save({
    required int? id,
    required String name,
    required int sportId,
    int? coachId,
    String? schedule,
    String? days,
    required DateTime startDate,
    DateTime? endDate,
    int? maxStudents,
    required num fees,
    required String status,
  }) {
    final body = <String, dynamic>{
      'name': name.trim(),
      'sportId': sportId,
      'coachId': coachId,
      'schedule': _orNull(schedule),
      'days': _orNull(days),
      'startDate': formatIsoDate(startDate),
      'endDate': endDate == null ? null : formatIsoDate(endDate),
      'maxStudents': maxStudents ?? 20,
      'fees': fees,
      'status': status,
    };

    return write(
      id == null ? 'Batch create' : 'Batch update',
      () => id == null
          ? _repository.createBatch(body)
          : _repository.updateBatch(id, body),
    );
  }

  Future<String?> delete(EmployeeBatch batch) =>
      write('Batch delete', () => _repository.deleteBatch(batch.id));
}

/// A blank string is stored as null — the API reads null as "not set" and an
/// empty string as a value, and every one of these fields means the former.
String? _orNull(String? value) {
  final text = value?.trim();
  return (text == null || text.isEmpty) ? null : text;
}
