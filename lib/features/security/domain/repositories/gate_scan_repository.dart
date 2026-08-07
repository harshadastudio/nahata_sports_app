import '../../../admin/domain/entities/paged.dart';
import '../entities/gate_scan.dart';

/// Every gate the security console can scan at.
///
/// The four modules are separate backends with separate response shapes; this
/// is the one place that difference is absorbed. Above it, a scan is a
/// [GateScanResult] whatever gate produced it.
///
/// **No scan method throws for a refused pass.** "Already checked out",
/// "expired", "not found" and "cancelled" all come back as a result carrying
/// the reason, because a guard has to be shown *why* somebody is being turned
/// away. Only a session failure, a permission failure or a transport failure
/// propagates — and even those are caught at the edge and turned into a
/// [GateScanOutcome.error] result so the gate never sees a crash.
abstract class GateScanRepository {
  // --- Visitor passes --------------------------------------------------------

  /// `POST /visitor-passes/verify`
  Future<GateScanResult> scanVisitorPass({
    required String passCode,
    required GateDirection direction,
  });

  // --- Event passes ----------------------------------------------------------

  /// `GET /event-passes/{eventPassId}/scan-stats`
  Future<ScanStats> eventScanStats(Object eventPassId);

  /// `POST /event-passes/scan`
  Future<GateScanResult> scanEventPass({
    required String passCode,
    required GateDirection direction,
  });

  /// `POST /event-passes/members/{memberId}/scan` — one person on a group
  /// booking, scanned without their own QR.
  Future<GateScanResult> scanEventMember({
    required Object memberId,
    required GateDirection direction,
  });

  // --- Court bookings --------------------------------------------------------

  /// `GET /courts/bookings/scan-stats?courtId=&date=`
  Future<ScanStats> courtScanStats({Object? courtId, String? date});

  /// `POST /courts/bookings/scan`
  Future<GateScanResult> scanCourtBooking({
    required String passCode,
    required GateDirection direction,
  });

  /// `POST /courts/members/{bookingMemberId}/scan`
  Future<GateScanResult> scanCourtMember({
    required Object memberId,
    required GateDirection direction,
  });

  /// `POST /courts/bookings/{bookingId}/members/{memberId}/send-email`
  ///
  /// Returns the server's confirmation sentence. Throws on failure — unlike a
  /// scan, there is no partial outcome worth rendering.
  Future<String> sendBookingEmail({
    required Object bookingId,
    required Object memberId,
    required String recipientEmail,
  });

  // --- Coaching gate passes --------------------------------------------------

  /// `POST /fees/scan-pass` — marks attendance and returns the student's card.
  Future<GateScanResult> scanCoachingPass(String passCode);

  /// `GET /fees/scan-logs?page=&limit=&date=&scannerRole=`
  Future<Paged<ScanLogEntry>> scanLogs({
    int page,
    int limit,
    String? date,
    String? scannerRole,
    String? search,
  });
}