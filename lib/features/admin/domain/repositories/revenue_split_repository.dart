import '../entities/revenue_split.dart';

/// Coaching Revenue > Revenue Split, ADMIN (super admin) only.
///
/// Business rule enforced before anything leaves the device: a backfill
/// [applyBackfill] is only ever attempted after a fresh [coverage] or
/// [dryRunBackfill] reports `clear: true` — the server enforces the same
/// thing (409 otherwise), but a wizard that lets an admin click Apply on a
/// screen it knows is not clear is a worse experience than refusing earlier.
abstract class RevenueSplitRepository {
  /// `GET /revenue-splits?includeInactive=&scope=&sportId=&coachId=&batchId=`
  Future<List<RevenueSplitRule>> getRules({
    bool includeInactive = false,
    String? scope,
    int? sportId,
    int? coachId,
    int? batchId,
  });

  /// `GET /revenue-splits/options`
  Future<RevenueSplitOptions> getOptions();

  /// `GET /revenue-splits/coverage`
  Future<RevenueSplitCoverage> getCoverage();

  /// `GET /revenue-splits/resolve` — the CHECK A BATCH preview.
  Future<RevenueSplitResolution> resolve({
    int? batchId,
    int? sportId,
    int? coachId,
    DateTime? paidOn,
  });

  /// `POST /revenue-splits`
  Future<RevenueSplitRule> createRule(RevenueSplitDraft draft);

  /// `PUT /revenue-splits/{id}`. [affectedExistingPayments] on the returned
  /// pair says how many already-collected rows keep their frozen percentage.
  Future<(RevenueSplitRule, int?)> updateRule(int id, RevenueSplitDraft draft);

  /// `PATCH /revenue-splits/{id}/deactivate` with `{isActive: false}`.
  Future<void> deactivateRule(int id);

  /// Same endpoint, `{isActive: true}`.
  Future<void> reactivateRule(int id);

  /// `POST /revenue-splits/backfill/dry-run` — writes nothing.
  Future<RevenueSplitBackfillPreview> dryRunBackfill();

  /// `POST /revenue-splits/backfill/apply` — writes the historical ledger.
  Future<RevenueSplitBackfillResult> applyBackfill();

  /// `POST /revenue-splits/backfill/rollback` — undoes only what the backfill
  /// itself wrote.
  Future<RevenueSplitRollbackResult> rollbackBackfill();
}
