import '../../../../models/sports_complex_model.dart';
import '../entities/paged.dart';
import '../entities/visitor_pass.dart';

/// The visitor-pass module: issue a pass, read it, scan it in and out, share
/// it, and delete it.
///
/// The lifecycle rule the whole module hangs on: `/verify` is the only call
/// that changes a pass, the first one records the entry and the second the
/// exit, and a pass that has been checked out is spent for good. `/lookup` is
/// the read-only twin used wherever the desk wants to see a pass without
/// consuming a leg of it.
abstract class VisitorPassRepository {
  /// `GET /visitor-passes?page=&limit=`
  Future<Paged<VisitorPass>> fetchVisitorPasses({
    int page,
    int limit,
    String? search,
  });

  /// `GET /visitor-passes/{visitorPassId}` — accepts a numeric id or a pass
  /// code, and never changes the status.
  Future<VisitorPass> fetchVisitorPass(String idOrCode);

  /// `POST /visitor-passes`
  Future<VisitorPass> createVisitorPass(VisitorPassDraft draft);

  /// `POST /visitor-passes/verify` — records the IN or the OUT leg.
  ///
  /// Never throws for a refused scan: an "already checked out" or "expired"
  /// answer comes back as a [VisitorPassCheck] carrying the reason and, where
  /// the server sent them, the visitor's details and current status. Only a
  /// transport failure or a session problem propagates.
  Future<VisitorPassCheck> verifyPass({
    required String passCode,
    required VisitorScanType scanType,
  });

  /// `POST /visitor-passes/lookup` — read-only verification.
  Future<VisitorPassCheck> lookupPass(String passCode);

  /// `POST /visitor-passes/{visitorPassId}/send-email`
  Future<String> sendPassEmail({
    required String idOrCode,
    required String recipientEmail,
    required String recipientName,
  });

  /// `DELETE /visitor-passes/{visitorPassId}` — ADMIN and COMPLEX_ADMIN only.
  Future<void> deleteVisitorPass(String idOrCode);

  /// Venues for the create form, from `GET /sports-complexes`.
  Future<List<SportsComplex>> fetchSportComplexes({bool refresh});
}
