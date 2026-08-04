import '../entities/membership.dart';
import '../entities/paged.dart';

/// Membership reads and writes.
///
/// The list envelope is documented (`{success, message, data, total, page,
/// limit}`); the row shape is not, so `MembershipMapper` reads through ordered
/// candidate keys.
abstract class MembershipRepository {
  /// `GET /memberships?page=&limit=&status=`
  Future<Paged<Membership>> fetchMemberships({
    int page,
    int limit,
    MembershipStatus? status,
  });

  /// `GET /memberships/stats`
  Future<MembershipStats> fetchStats();

  /// `GET /memberships/{membershipId}`
  Future<Membership> fetchMembership(String id);

  /// `GET /memberships/user/{userId}` — every membership a user has held.
  Future<List<Membership>> fetchForUser(String userId);

  /// `GET /memberships/user/{userId}/active`
  ///
  /// Returns null when the user has no plan in force — a 404 here is an answer,
  /// not a failure, so it is mapped rather than thrown.
  Future<Membership?> fetchActiveForUser(String userId);

  /// `POST /memberships`
  Future<Membership> createMembership(MembershipDraft draft);

  /// `PUT /memberships/{membershipId}` — only the changed fields.
  Future<Membership> updateMembership(String id, MembershipDraft draft);

  /// `PATCH /memberships/{membershipId}/status`
  Future<void> setStatus(String id, MembershipStatus status);

  /// `PATCH /memberships/{membershipId}/payment-status`
  Future<void> setPaymentStatus(String id, MembershipPaymentStatus payment);

  /// `PATCH /memberships/{membershipId}/cancel` — the reason is required.
  Future<void> cancelMembership(String id, String reason);

  /// `POST /memberships/{membershipId}/renew`
  Future<Membership> renewMembership(
    String id, {
    required int validityDays,
    required num totalAmount,
  });

  /// `DELETE /memberships/{membershipId}`
  Future<void> deleteMembership(String id);

  /// `POST /memberships/check-expired` — marks lapsed memberships expired.
  /// Returns how many were changed when the response says so.
  Future<int?> checkExpired();
}
