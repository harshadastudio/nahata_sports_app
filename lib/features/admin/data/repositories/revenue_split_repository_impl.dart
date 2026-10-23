import '../../../../core/network/api_exception.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/revenue_split.dart';
import '../../domain/repositories/revenue_split_repository.dart';
import '../datasources/revenue_split_remote_data_source.dart';
import '../models/revenue_split_model.dart';

/// [RevenueSplitRepository] over the JWT backend.
class RevenueSplitRepositoryImpl implements RevenueSplitRepository {
  RevenueSplitRepositoryImpl({RevenueSplitRemoteDataSource? remote})
    : _remote = remote ?? RevenueSplitRemoteDataSource();

  final RevenueSplitRemoteDataSource _remote;

  @override
  Future<List<RevenueSplitRule>> getRules({
    bool includeInactive = false,
    String? scope,
    int? sportId,
    int? coachId,
    int? batchId,
  }) async {
    final response = await _remote.list(
      includeInactive: includeInactive,
      scope: scope,
      sportId: sportId,
      coachId: coachId,
      batchId: batchId,
    );
    if (!response.isOk) throw response.toException();

    final rules = RevenueSplitMapper.listFrom(response.data);
    AdminLog.data('Revenue split rules → ${rules.length}');
    return rules;
  }

  @override
  Future<RevenueSplitOptions> getOptions() async {
    final response = await _remote.options();
    if (!response.isOk) throw response.toException();

    final options = RevenueSplitMapper.optionsFrom(response.data);
    AdminLog.data(
      'Revenue split options → ${options.sports.length} sports, '
      '${options.coaches.length} coaches, ${options.batches.length} batches, '
      '${options.complexes.length} complexes',
    );
    return options;
  }

  @override
  Future<RevenueSplitCoverage> getCoverage() async {
    final response = await _remote.coverage();
    if (!response.isOk) throw response.toException();

    final coverage = RevenueSplitMapper.coverageFrom(response.data);
    AdminLog.data(
      'Revenue split coverage → clear=${coverage.clear}, '
      '${coverage.gaps.length} gap(s)',
    );
    return coverage;
  }

  @override
  Future<RevenueSplitResolution> resolve({
    int? batchId,
    int? sportId,
    int? coachId,
    DateTime? paidOn,
  }) async {
    if (batchId == null && sportId == null) {
      throw const ValidationException(
        'Pick a batch, or a sport, to check a rate for.',
      );
    }

    final response = await _remote.resolve(
      batchId: batchId,
      sportId: sportId,
      coachId: coachId,
      paidOn: paidOn == null ? null : RevenueSplitDraft.formatDate(paidOn),
    );
    if (!response.isOk) throw response.toException();

    final resolution = RevenueSplitMapper.resolutionFrom(response.data);
    AdminLog.data(
      'Revenue split resolve → matched=${resolution.matched}, '
      'coach=${resolution.coachPercent}%, needsRule=${resolution.needsSplitRule}',
    );
    return resolution;
  }

  @override
  Future<RevenueSplitRule> createRule(RevenueSplitDraft draft) async {
    _assertValid(draft);

    final response = await _remote.create(draft.toBody());
    if (!response.isOk) throw response.toException();

    final rule = RevenueSplitMapper.maybeFromBody(response.data);
    if (rule == null) {
      throw const ParseException(
        'The server did not confirm the new rule. Refresh the list to check.',
      );
    }

    AdminLog.success('Revenue split rule created (#${rule.id})');
    return rule;
  }

  @override
  Future<(RevenueSplitRule, int?)> updateRule(
    int id,
    RevenueSplitDraft draft,
  ) async {
    _assertValid(draft);

    final response = await _remote.update(id, draft.toBody());
    if (!response.isOk) throw response.toException();

    final rule = RevenueSplitMapper.maybeFromBody(response.data);
    final affected = RevenueSplitMapper.affectedExistingPayments(response.data);
    AdminLog.success(
      'Revenue split rule $id updated'
      '${affected == null ? '' : ' ($affected payment(s) unaffected)'}',
    );

    return (rule ?? RevenueSplitRule(id: id), affected);
  }

  @override
  Future<void> deactivateRule(int id) async {
    final response = await _remote.setActive(id, false);
    if (!response.isOk) throw response.toException();
    AdminLog.success('Revenue split rule $id deactivated');
  }

  @override
  Future<void> reactivateRule(int id) async {
    final response = await _remote.setActive(id, true);
    if (!response.isOk) throw response.toException();
    AdminLog.success('Revenue split rule $id reactivated');
  }

  @override
  Future<RevenueSplitBackfillPreview> dryRunBackfill() async {
    final response = await _remote.backfillDryRun();
    if (!response.isOk) throw response.toException();

    final preview = RevenueSplitMapper.previewFrom(response.data);
    AdminLog.data(
      'Backfill dry-run → wouldWrite=${preview.wouldWrite}, '
      'canApply=${preview.canApply}',
    );
    return preview;
  }

  @override
  Future<RevenueSplitBackfillResult> applyBackfill() async {
    final response = await _remote.backfillApply();
    if (!response.isOk) throw response.toException();

    final result = RevenueSplitMapper.applyResultFrom(response.data);
    AdminLog.success(
      'Backfill applied → written=${result.written}, skipped=${result.skipped}',
    );
    return result;
  }

  @override
  Future<RevenueSplitRollbackResult> rollbackBackfill() async {
    final response = await _remote.backfillRollback();
    if (!response.isOk) throw response.toException();

    final result = RevenueSplitMapper.rollbackResultFrom(response.data);
    AdminLog.success('Backfill rolled back → removed=${result.removed}');
    return result;
  }

  /// Refuses a draft the server could only reject.
  static void _assertValid(RevenueSplitDraft draft) {
    if (draft.scope == RevenueSplitScope.batch && draft.batchId == null) {
      throw const ValidationException('Pick the batch this rule applies to.');
    }
    if (draft.scope != RevenueSplitScope.batch && draft.sportId == null) {
      throw const ValidationException('Pick the sport this rule applies to.');
    }
    if (draft.scope == RevenueSplitScope.sportCoach && draft.coachId == null) {
      throw const ValidationException('Pick the coach this rule applies to.');
    }
    if (draft.coachPercent < 0 || draft.coachPercent > 100) {
      throw const ValidationException(
        "The coach's share must be between 0 and 100.",
      );
    }
  }
}
