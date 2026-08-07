import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_response.dart';
import '../../../admin/core/admin_log.dart';

/// The gate routes across all four modules.
///
/// Auth, refresh, timeouts and error mapping all come from [ApiClient]; this
/// layer only shapes requests and traces them, exactly like the console's other
/// data sources.
class GateScanRemoteDataSource {
  GateScanRemoteDataSource({ApiClient? client})
      : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  // --- Visitor ---------------------------------------------------------------

  /// `POST /visitor-passes/verify` — **advances the pass**.
  Future<ApiResponse> verifyVisitor({
    required String passCode,
    required String scanType,
  }) {
    AdminLog.call(
      'POST ${ApiEndpoints.visitorPassVerify} scanType=$scanType '
      'passCode=$passCode',
    );
    return _api.post(
      ApiEndpoints.visitorPassVerify,
      body: {'passCode': passCode, 'scanType': scanType},
    );
  }

  // --- Event -----------------------------------------------------------------

  /// `GET /event-passes/{eventPassId}/scan-stats`
  Future<ApiResponse> eventScanStats(Object eventPassId) {
    AdminLog.call('GET ${ApiEndpoints.eventPassScanStats(eventPassId)}');
    return _api.get(ApiEndpoints.eventPassScanStats(eventPassId));
  }

  /// `POST /event-passes/scan`
  Future<ApiResponse> scanEvent({
    required String passCode,
    required String scanType,
  }) {
    AdminLog.call(
      'POST ${ApiEndpoints.eventPassScan} scanType=$scanType '
      'passCode=$passCode',
    );
    return _api.post(
      ApiEndpoints.eventPassScan,
      body: {'passCode': passCode, 'scanType': scanType},
    );
  }

  /// `POST /event-passes/members/{memberId}/scan`
  Future<ApiResponse> scanEventMember({
    required Object memberId,
    required String scanType,
  }) {
    AdminLog.call(
      'POST ${ApiEndpoints.eventPassMemberScan(memberId)} scanType=$scanType',
    );
    return _api.post(
      ApiEndpoints.eventPassMemberScan(memberId),
      body: {'scanType': scanType},
    );
  }

  // --- Court booking ---------------------------------------------------------

  /// `GET /courts/bookings/scan-stats?courtId=&date=`
  Future<ApiResponse> courtScanStats({Object? courtId, String? date}) {
    final query = <String, dynamic>{
      if (courtId != null) 'courtId': courtId,
      if (date != null && date.trim().isNotEmpty) 'date': date.trim(),
    };

    AdminLog.call('GET ${ApiEndpoints.courtBookingScanStats} $query');
    return _api.get(ApiEndpoints.courtBookingScanStats, query: query);
  }

  /// `POST /courts/bookings/scan`
  Future<ApiResponse> scanCourtBooking({
    required String passCode,
    required String scanType,
  }) {
    AdminLog.call(
      'POST ${ApiEndpoints.courtBookingScan} scanType=$scanType '
      'passCode=$passCode',
    );
    return _api.post(
      ApiEndpoints.courtBookingScan,
      body: {'passCode': passCode, 'scanType': scanType},
    );
  }

  /// `POST /courts/members/{bookingMemberId}/scan`
  Future<ApiResponse> scanCourtMember({
    required Object memberId,
    required String scanType,
  }) {
    AdminLog.call(
      'POST ${ApiEndpoints.courtBookingMemberScan(memberId)} '
      'scanType=$scanType',
    );
    return _api.post(
      ApiEndpoints.courtBookingMemberScan(memberId),
      body: {'scanType': scanType},
    );
  }

  /// `POST /courts/bookings/{bookingId}/members/{memberId}/send-email`
  Future<ApiResponse> sendBookingEmail({
    required Object bookingId,
    required Object memberId,
    required String recipientEmail,
  }) {
    AdminLog.call(
      'POST ${ApiEndpoints.courtBookingMemberEmail(bookingId, memberId)} '
      'to=$recipientEmail',
    );
    return _api.post(
      ApiEndpoints.courtBookingMemberEmail(bookingId, memberId),
      body: {'recipientEmail': recipientEmail},
    );
  }

  // --- Coaching --------------------------------------------------------------

  /// `POST /fees/scan-pass` — marks attendance for a student gate pass.
  Future<ApiResponse> scanCoachingPass(String passCode) {
    AdminLog.call('POST ${ApiEndpoints.feesScanPass} passCode=$passCode');
    return _api.post(
      ApiEndpoints.feesScanPass,
      body: {'passCode': passCode},
    );
  }

  /// `GET /fees/scan-logs?page=&limit=&date=&scannerRole=&search=`
  Future<ApiResponse> scanLogs({
    required int page,
    required int limit,
    String? date,
    String? scannerRole,
    String? search,
  }) {
    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (date != null && date.trim().isNotEmpty) 'date': date.trim(),
      if (scannerRole != null && scannerRole.trim().isNotEmpty)
        'scannerRole': scannerRole.trim(),
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
    };

    AdminLog.call('GET ${ApiEndpoints.feesScanLogs} $query');
    return _api.get(ApiEndpoints.feesScanLogs, query: query);
  }
}