import '../../core/employee_log.dart';
import '../../domain/entities/employee_booking.dart';
import '../../domain/entities/employee_formats.dart';
import '../../domain/entities/employee_master.dart';
import '../../domain/entities/employee_paged.dart';
import '../../domain/repositories/employee_dashboard_repository.dart';
import 'employee_list_controller.dart';

/// Bookings Management.
///
/// Filters mirror the website's four: date, sport, payment status and booking
/// status. The sport and court lists are loaded once — they populate both the
/// filter and the edit form's pickers, and moving a booking to another court
/// needs the court list anyway.
class EmployeeBookingsController extends EmployeeListController<EmployeeBooking> {
  EmployeeBookingsController(this._repository);

  final EmployeeDashboardRepository _repository;

  /// The vocabularies the API accepts. Fixed server-side, so they are listed
  /// rather than fetched.
  static const List<String> paymentStatuses = [
    'Pending',
    'Paid',
    'Failed',
    'Refunded',
  ];
  static const List<String> bookingStatuses = [
    'Pending',
    'Confirmed',
    'Completed',
    'Cancelled',
  ];

  DateTime? _date;
  EmployeeOption? _sport;
  String? _paymentStatus;
  String? _bookingStatus;

  List<EmployeeSport> _sports = const [];
  List<EmployeeCourt> _courts = const [];
  bool _pickersLoaded = false;

  DateTime? get date => _date;
  EmployeeOption? get sport => _sport;
  String? get paymentStatus => _paymentStatus;
  String? get bookingStatus => _bookingStatus;

  List<EmployeeSport> get sports => _sports;
  List<EmployeeCourt> get courts => _courts;

  /// Courts for [sportId], or all of them when the sport is unset. Used by the
  /// edit sheet so changing the sport narrows the court list rather than
  /// offering a court the sport does not play on.
  List<EmployeeCourt> courtsForSport(int? sportId) {
    if (sportId == null) return _courts;
    return _courts.where((c) => c.sportId == sportId).toList(growable: false);
  }

  bool get isFiltered =>
      _date != null ||
      _sport != null ||
      _paymentStatus != null ||
      _bookingStatus != null;

  @override
  Future<EmployeePaged<EmployeeBooking>> fetchPage(int page) {
    return _repository.getBookings(
      page: page,
      limit: pageSize,
      date: _date == null ? null : formatIsoDate(_date!),
      sportId: _sport?.id,
      paymentStatus: _paymentStatus,
      bookingStatus: _bookingStatus,
    );
  }

  /// Sports and courts are pulled once, after the first page is on screen —
  /// they only feed the filter and the edit form, so they must not sit in front
  /// of the rows the user came to see.
  @override
  Future<void> onFirstPageLoaded() async {
    if (_pickersLoaded) return;
    _pickersLoaded = true;

    try {
      final results = await Future.wait([
        _repository.getSports(),
        _repository.getCourts(),
      ]);
      if (isDisposed) return;

      _sports = results[0] as List<EmployeeSport>;
      _courts = results[1] as List<EmployeeCourt>;
      notify();
    } catch (e) {
      // Non-fatal: the list still works, the pickers are just empty. An
      // employee without the Sports permission gets a 403 here and should
      // still be able to read bookings.
      _pickersLoaded = false;
      EmployeeLog.failure('Booking pickers failed', error: e);
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Filters
  // ───────────────────────────────────────────────────────────────────────────

  void setDate(DateTime? value) {
    if (value == _date) return;
    _date = value;
    EmployeeLog.ui('Booking date filter → ${value == null ? 'any' : formatIsoDate(value)}');
    reload();
  }

  void setSport(EmployeeOption? value) {
    if (value?.id == _sport?.id) return;
    _sport = value;
    EmployeeLog.ui('Booking sport filter → ${value?.name ?? 'all'}');
    reload();
  }

  void setPaymentStatus(String? value) {
    if (value == _paymentStatus) return;
    _paymentStatus = value;
    EmployeeLog.ui('Booking payment filter → ${value ?? 'all'}');
    reload();
  }

  void setBookingStatus(String? value) {
    if (value == _bookingStatus) return;
    _bookingStatus = value;
    EmployeeLog.ui('Booking status filter → ${value ?? 'all'}');
    reload();
  }

  void clearFilters() {
    if (!isFiltered) return;
    _date = null;
    _sport = null;
    _paymentStatus = null;
    _bookingStatus = null;
    EmployeeLog.ui('Booking filters cleared');
    reload();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Writes
  //
  // Each returns null on success and the server's message on failure, so the
  // caller can show a snackbar without the list ever entering an error state —
  // a refused update must not blank the rows.
  // ───────────────────────────────────────────────────────────────────────────

  /// Marks the payment. Sends only `paymentStatus`, so a note or a custom name
  /// on the booking survives untouched.
  Future<String?> setBookingPaymentStatus(
    EmployeeBooking booking,
    String status,
  ) async {
    try {
      await _repository.updateBooking(booking.id, paymentStatus: status);
      _patch(booking.id, paymentStatus: status);
      return null;
    } catch (e) {
      return reportFailure('Booking payment update failed', e);
    }
  }

  /// Completes or cancels the booking.
  Future<String?> setBookingStatusFor(
    EmployeeBooking booking,
    String status,
  ) async {
    try {
      await _repository.updateBooking(booking.id, bookingStatus: status);
      _patch(booking.id, bookingStatus: status);
      return null;
    } catch (e) {
      return reportFailure('Booking status update failed', e);
    }
  }

  /// The full edit. Re-loads afterwards rather than patching in place: moving a
  /// booking to another court changes the court and venue names too, and those
  /// come from joins this side cannot recompute.
  Future<String?> saveBooking(
    int id, {
    required String customerName,
    required DateTime date,
    required String startTime,
    required String endTime,
    num? totalAmount,
    String? notes,
    required String bookingStatus,
    required String paymentStatus,
    int? sportId,
    int? courtId,
  }) async {
    try {
      await _repository.updateBooking(
        id,
        customerName: customerName,
        date: formatIsoDate(date),
        startTime: startTime,
        endTime: endTime,
        totalAmount: totalAmount,
        notes: notes ?? '',
        bookingStatus: bookingStatus,
        paymentStatus: paymentStatus,
        sportId: sportId,
        courtId: courtId,
      );
      await refresh();
      return null;
    } catch (e) {
      return reportFailure('Booking save failed', e);
    }
  }

  Future<String?> deleteBooking(EmployeeBooking booking) async {
    try {
      await _repository.deleteBooking(booking.id);
      removeItem((b) => b.id == booking.id);
      return null;
    } catch (e) {
      return reportFailure('Booking delete failed', e);
    }
  }

  /// Rewrites one row's status fields in place.
  void _patch(int id, {String? paymentStatus, String? bookingStatus}) {
    replaceItem(
      (b) => b.id == id,
      (b) => EmployeeBooking(
        id: b.id,
        customerName: b.customerName,
        userName: b.userName,
        userEmail: b.userEmail,
        userPhone: b.userPhone,
        sportId: b.sportId,
        sportName: b.sportName,
        courtId: b.courtId,
        courtName: b.courtName,
        venueName: b.venueName,
        date: b.date,
        startTime: b.startTime,
        endTime: b.endTime,
        source: b.source,
        paymentStatus: paymentStatus ?? b.paymentStatus,
        bookingStatus: bookingStatus ?? b.bookingStatus,
        totalAmount: b.totalAmount,
        transactionId: b.transactionId,
        passCode: b.passCode,
        qrCode: b.qrCode,
        maxPersons: b.maxPersons,
        notes: b.notes,
        movedFromCourtId: b.movedFromCourtId,
        moveReason: b.moveReason,
        createdAt: b.createdAt,
      ),
    );
  }
}
