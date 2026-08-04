import '../../../../core/network/api_exception.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/membership.dart';
import '../../domain/entities/paged.dart';
import '../../domain/repositories/membership_repository.dart';
import '../datasources/membership_remote_data_source.dart';
import '../models/json_reader.dart';
import '../models/membership_model.dart';

/// [MembershipRepository] over the JWT backend.
class MembershipRepositoryImpl implements MembershipRepository {
  MembershipRepositoryImpl({MembershipRemoteDataSource? remote})
    : _remote = remote ?? MembershipRemoteDataSource();

  final MembershipRemoteDataSource _remote;

  @override
  Future<Paged<Membership>> fetchMemberships({
    int page = 1,
    int limit = 20,
    MembershipStatus? status,
  }) async {
    final response = await _remote.list(
      page: page,
      limit: limit,
      status: status,
    );
    if (!response.isOk) throw response.toException();

    final result = MembershipMapper.pageFrom(
      response.data,
      requestedPage: page,
      requestedLimit: limit,
    );
    _warnIfUnreadable(
      rows: MembershipMapper.rowsIn(response.data),
      parsed: result.items.length,
      body: response.data,
    );
    AdminLog.data('Memberships → $result');
    return result;
  }

  @override
  Future<MembershipStats> fetchStats() async {
    final response = await _remote.stats();
    if (!response.isOk) throw response.toException();

    final stats = MembershipStatsMapper.fromJson(response.data);
    AdminLog.data('Membership stats → $stats');
    return stats;
  }

  @override
  Future<Membership> fetchMembership(String id) async {
    final response = await _remote.detail(id);
    if (!response.isOk) throw response.toException();

    final membership = MembershipMapper.fromJson(response.payload);
    AdminLog.data('Membership detail → $membership');
    return membership;
  }

  @override
  Future<List<Membership>> fetchForUser(String userId) async {
    final response = await _remote.forUser(userId);
    if (!response.isOk) throw response.toException();

    final memberships = MembershipMapper.listFrom(response.data);
    AdminLog.data('Memberships for user $userId → ${memberships.length}');
    return memberships;
  }

  @override
  Future<Membership?> fetchActiveForUser(String userId) async {
    try {
      final response = await _remote.activeForUser(userId);
      if (!response.isOk) {
        // "No active plan" is an answer, not a failure — a backend is as likely
        // to say it with `success: false` as with a 404.
        if (response.statusCode == 404) return null;
        throw response.toException();
      }

      // The route may answer with the object, or with a one-item list.
      final single = MembershipMapper.maybeFromBody(response.payload);
      if (single != null) return single;

      final list = MembershipMapper.listFrom(response.data);
      return list.isEmpty ? null : list.first;
    } on NotFoundException {
      AdminLog.data('User $userId has no active membership');
      return null;
    }
  }

  @override
  Future<Membership> createMembership(MembershipDraft draft) async {
    final body = draft.toCreateJson();

    // Fail before the round trip rather than let the server reject a body it
    // could never accept.
    if ((body['userId'] as String).isEmpty) {
      throw const ValidationException('Pick the member this plan is for.');
    }
    if ((body['planId'] as String).isEmpty) {
      throw const ValidationException('Give the plan a code, e.g. GOLD.');
    }
    if ((body['planName'] as String).isEmpty) {
      throw const ValidationException('Give the plan a name.');
    }
    if (body['price'] == null) {
      throw const ValidationException('Enter the plan price.');
    }
    if (body['validity'] == null || (body['validity'] as int) < 1) {
      throw const ValidationException('Validity must be at least one day.');
    }
    if (body['startDate'] == null || body['endDate'] == null) {
      throw const ValidationException('Pick the start and end dates.');
    }
    if (body['totalAmount'] == null) {
      throw const ValidationException('Enter the amount payable.');
    }

    final response = await _remote.create(body);
    if (!response.isOk) throw response.toException();

    final created = MembershipMapper.maybeFromBody(response.data);
    AdminLog.success('Created membership ${created?.id ?? '(id not echoed)'}');

    return created ??
        Membership(
          id: '',
          userId: draft.userId,
          planId: draft.planId,
          planName: draft.planName,
        );
  }

  @override
  Future<Membership> updateMembership(String id, MembershipDraft draft) async {
    final body = draft.toUpdateJson();
    if (body.isEmpty) {
      throw const BadRequestException('Nothing to update.');
    }

    final response = await _remote.update(id, body);
    if (!response.isOk) throw response.toException();

    AdminLog.success('Updated membership $id');
    return MembershipMapper.maybeFromBody(response.data) ?? Membership(id: id);
  }

  @override
  Future<void> setStatus(String id, MembershipStatus status) async {
    final response = await _remote.setStatus(id, status);
    if (!response.isOk) throw response.toException();
    AdminLog.success('Membership $id is now ${status.slug}');
  }

  @override
  Future<void> setPaymentStatus(
    String id,
    MembershipPaymentStatus payment,
  ) async {
    final response = await _remote.setPaymentStatus(id, payment);
    if (!response.isOk) throw response.toException();
    AdminLog.success('Membership $id payment is now ${payment.slug}');
  }

  @override
  Future<void> cancelMembership(String id, String reason) async {
    final trimmed = reason.trim();
    if (trimmed.isEmpty) {
      throw const ValidationException('Give a reason for the cancellation.');
    }

    final response = await _remote.cancel(id, trimmed);
    if (!response.isOk) throw response.toException();
    AdminLog.success('Cancelled membership $id');
  }

  @override
  Future<Membership> renewMembership(
    String id, {
    required int validityDays,
    required num totalAmount,
  }) async {
    if (validityDays < 1) {
      throw const ValidationException('Renew for at least one day.');
    }
    if (totalAmount < 0) {
      throw const ValidationException('The amount cannot be negative.');
    }

    final response = await _remote.renew(
      id,
      validityDays: validityDays,
      totalAmount: totalAmount,
    );
    if (!response.isOk) throw response.toException();

    AdminLog.success('Renewed membership $id for $validityDays days');
    return MembershipMapper.maybeFromBody(response.data) ?? Membership(id: id);
  }

  @override
  Future<void> deleteMembership(String id) async {
    final response = await _remote.remove(id);
    if (!response.isOk) throw response.toException();
    AdminLog.success('Deleted membership $id');
  }

  @override
  Future<int?> checkExpired() async {
    final response = await _remote.checkExpired();
    if (!response.isOk) throw response.toException();

    // The count is reported under several names, and some backends send none —
    // null then means "done, and it did not say how many".
    final body = response.data;
    final count = body is Map
        ? JsonReader.integer(Map<String, dynamic>.from(body), const [
                'updated',
                'updatedCount',
                'expired',
                'expiredCount',
                'count',
                'affected',
              ]) ??
              JsonReader.integer(response.payload, const [
                'updated',
                'updatedCount',
                'expired',
                'expiredCount',
                'count',
                'affected',
              ])
        : null;

    AdminLog.success('Expiry sweep finished (${count ?? 'count not reported'})');
    return count;
  }

  /// Says in the log which kind of empty this was.
  ///
  /// No row sample was supplied for this module, so "the list is empty" and
  /// "this mapper could not read the list" look identical on screen. This tells
  /// them apart and names the keys it saw, so a fix is one edit away.
  static void _warnIfUnreadable({
    required List<Map<String, dynamic>> rows,
    required int parsed,
    required Object? body,
  }) {
    if (parsed > 0) return;

    if (rows.isEmpty) {
      final keys = body is Map ? body.keys.toList() : const <String>[];
      AdminLog.data(
        'No memberships in the response. Top-level keys: $keys — if the list '
        'is in one of these, add it to MembershipMapper.listKeys.',
      );
      return;
    }

    AdminLog.failure(
      '${rows.length} membership rows were returned but none carried a '
      'readable id, so all were dropped. Row keys: ${rows.first.keys.toList()}',
    );
  }
}
