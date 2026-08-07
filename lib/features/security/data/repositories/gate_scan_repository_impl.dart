import '../../../../core/network/api_exception.dart';
import '../../../../core/network/api_response.dart';
import '../../../admin/core/admin_log.dart';
import '../../../admin/domain/entities/paged.dart';
import '../../domain/entities/gate_scan.dart';
import '../../domain/repositories/gate_scan_repository.dart';
import '../datasources/gate_scan_remote_data_source.dart';
import '../models/gate_scan_mapper.dart';

/// [GateScanRepository] over the JWT backend.
///
/// The whole class exists to make one promise good: **a scan never throws at
/// the gate.** Three things can go wrong and all three have to reach the guard
/// as something readable —
///
///  * a 2xx that says `success: false` (a refusal with a reason),
///  * a 4xx whose body is lost to the typed exception (`_isRefusal`),
///  * a 401/403/5xx/network failure, which says nothing about the pass and must
///    therefore never be mistaken for one being valid.
///
/// The first two become a refusal result; the third becomes
/// [GateScanOutcome.error], which the UI colours red and never treats as entry.
class GateScanRepositoryImpl implements GateScanRepository {
  GateScanRepositoryImpl({GateScanRemoteDataSource? remote})
      : _remote = remote ?? GateScanRemoteDataSource();

  final GateScanRemoteDataSource _remote;

  // --- Visitor ---------------------------------------------------------------

  @override
  Future<GateScanResult> scanVisitorPass({
    required String passCode,
    required GateDirection direction,
  }) {
    return _scan(
      kind: GateScanKind.visitor,
      passCode: passCode,
      direction: direction,
      call: (code) => _remote.verifyVisitor(
        passCode: code,
        scanType: direction.slug,
      ),
    );
  }

  // --- Event -----------------------------------------------------------------

  @override
  Future<ScanStats> eventScanStats(Object eventPassId) async {
    final response = await _remote.eventScanStats(eventPassId);
    if (!response.isOk) throw response.toException();

    final stats = ScanStats.fromJson(_statsBody(response));
    AdminLog.data('Event scan stats → ${stats.totalPasses} passes');
    return stats;
  }

  @override
  Future<GateScanResult> scanEventPass({
    required String passCode,
    required GateDirection direction,
  }) {
    return _scan(
      kind: GateScanKind.event,
      passCode: passCode,
      direction: direction,
      call: (code) => _remote.scanEvent(
        passCode: code,
        scanType: direction.slug,
      ),
    );
  }

  @override
  Future<GateScanResult> scanEventMember({
    required Object memberId,
    required GateDirection direction,
  }) {
    return _scan(
      kind: GateScanKind.event,
      // A member scan carries no pass code — the member id is the reference.
      passCode: 'member:$memberId',
      direction: direction,
      requireCode: false,
      call: (_) => _remote.scanEventMember(
        memberId: memberId,
        scanType: direction.slug,
      ),
    );
  }

  // --- Court booking ---------------------------------------------------------

  @override
  Future<ScanStats> courtScanStats({Object? courtId, String? date}) async {
    final response = await _remote.courtScanStats(courtId: courtId, date: date);
    if (!response.isOk) throw response.toException();

    final stats = ScanStats.fromJson(_statsBody(response));
    AdminLog.data('Court scan stats → ${stats.totalPasses} bookings');
    return stats;
  }

  @override
  Future<GateScanResult> scanCourtBooking({
    required String passCode,
    required GateDirection direction,
  }) {
    return _scan(
      kind: GateScanKind.courtBooking,
      passCode: passCode,
      direction: direction,
      call: (code) => _remote.scanCourtBooking(
        passCode: code,
        scanType: direction.slug,
      ),
    );
  }

  @override
  Future<GateScanResult> scanCourtMember({
    required Object memberId,
    required GateDirection direction,
  }) {
    return _scan(
      kind: GateScanKind.courtBooking,
      passCode: 'member:$memberId',
      direction: direction,
      requireCode: false,
      call: (_) => _remote.scanCourtMember(
        memberId: memberId,
        scanType: direction.slug,
      ),
    );
  }

  @override
  Future<String> sendBookingEmail({
    required Object bookingId,
    required Object memberId,
    required String recipientEmail,
  }) async {
    final email = recipientEmail.trim();
    if (!RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(email)) {
      throw const ValidationException('Enter a valid email address.');
    }

    final response = await _remote.sendBookingEmail(
      bookingId: bookingId,
      memberId: memberId,
      recipientEmail: email,
    );
    if (!response.isOk) throw response.toException();

    AdminLog.success('Emailed booking $bookingId member $memberId to $email');
    return response.message ?? 'Email sent successfully.';
  }

  // --- Coaching --------------------------------------------------------------

  @override
  Future<GateScanResult> scanCoachingPass(String passCode) {
    return _scan(
      kind: GateScanKind.coaching,
      passCode: passCode,
      // Attendance has no direction: a student is marked present, full stop.
      direction: null,
      call: (code) => _remote.scanCoachingPass(code),
    );
  }

  @override
  Future<Paged<ScanLogEntry>> scanLogs({
    int page = 1,
    int limit = 50,
    String? date,
    String? scannerRole,
    String? search,
  }) async {
    final response = await _remote.scanLogs(
      page: page,
      limit: limit,
      date: date,
      scannerRole: scannerRole,
      search: search,
    );
    if (!response.isOk) throw response.toException();

    final result = GateScanMapper.logPageFrom(
      response.data,
      fallbackPage: page,
      fallbackLimit: limit,
    );

    AdminLog.data('Scan logs → ${result.items.length} rows');
    return result;
  }

  // --- The one scan path -----------------------------------------------------

  /// Runs a scan call and turns every possible ending into a [GateScanResult].
  ///
  /// [requireCode] is false for the member routes, which identify the person by
  /// id and send no code at all.
  Future<GateScanResult> _scan({
    required GateScanKind kind,
    required String passCode,
    required GateDirection? direction,
    required Future<ApiResponse> Function(String code) call,
    bool requireCode = true,
  }) async {
    final code = passCode.trim();
    if (requireCode && code.isEmpty) {
      return GateScanResult.failure(
        kind: kind,
        passCode: '',
        direction: direction,
        outcome: GateScanOutcome.invalid,
        message: 'Enter or scan a pass code.',
      );
    }

    try {
      final response = await call(code);

      final result = GateScanMapper.fromResponse(
        response,
        kind: kind,
        passCode: code,
        direction: direction,
      );

      if (result.isSuccess) {
        AdminLog.success('${kind.label} scan ok for $code → ${result.outcome.label}');
      } else {
        AdminLog.failure(
          '${kind.label} scan refused for $code: ${result.message}',
        );
      }
      return result;
    } on ApiException catch (error) {
      // A refusal that arrived as a 4xx: the body is gone, but the message the
      // backend chose survives on the exception and is what the guard needs.
      if (_isRefusal(error)) {
        AdminLog.failure(
          '${kind.label} scan rejected for $code: ${error.message}',
        );
        return GateScanResult(
          kind: kind,
          outcome: GateScanOutcome.fromMessage(
            error.message,
            direction: direction,
          ),
          passCode: code,
          at: DateTime.now(),
          direction: direction,
          message: error.message,
        );
      }

      // 401, 403, 5xx, offline, timeout. Nothing is known about the pass, so
      // this is reported as a failed scan rather than any kind of verdict on it.
      AdminLog.failure('${kind.label} scan failed for $code', error: error);
      return GateScanResult.failure(
        kind: kind,
        passCode: code,
        direction: direction,
        message: error.message,
      );
    } catch (error, stackTrace) {
      AdminLog.failure(
        '${kind.label} scan crashed for $code',
        error: error,
        stackTrace: stackTrace,
      );
      return GateScanResult.failure(
        kind: kind,
        passCode: code,
        direction: direction,
        message: 'Something went wrong. Please try again.',
      );
    }
  }

  /// The stats object, wherever the envelope put it.
  static Map<String, dynamic> _statsBody(ApiResponse response) {
    final payload = response.payload;
    for (final key in const ['stats', 'scanStats', 'data']) {
      final nested = response.objectAt(key);
      if (nested != null && nested.isNotEmpty) return nested;
    }
    return payload;
  }

  /// Statuses that mean "the server considered this pass and said no", as
  /// opposed to "the request never got a verdict".
  static bool _isRefusal(ApiException error) {
    return error is BadRequestException ||
        error is NotFoundException ||
        error is ConflictException ||
        error is ValidationException;
  }
}