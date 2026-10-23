import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/revenue_split.dart';
import '../../domain/repositories/revenue_split_repository.dart';
import 'view_state.dart';

/// Revenue Split: the rules table, its form options, the backfill-gate
/// coverage banner, the Check-a-Batch resolver and the backfill wizard.
///
/// The rules list is **not server-paginated** (`GET /revenue-splits` answers
/// a bare array), so it is held and filtered the way Sports/Courts are: one
/// catalogue load per server-side filter change (`scope`, `includeInactive`),
/// with the Search box filtering that catalogue locally.
class RevenueSplitController extends ChangeNotifier {
  RevenueSplitController(this._repository) {
    AdminLog.life('RevenueSplitController created');
  }

  final RevenueSplitRepository _repository;

  bool _disposed = false;

  // --- Rules -------------------------------------------------------------

  ViewState _state = ViewState.idle;
  List<RevenueSplitRule> _rules = const [];
  String? _error;

  String _search = '';
  RevenueSplitScope? _scopeFilter;
  bool _includeInactive = false;

  ViewState get state => _state;
  String? get error => _error;
  String get search => _search;
  RevenueSplitScope? get scopeFilter => _scopeFilter;
  bool get includeInactive => _includeInactive;

  bool get isFirstLoad => _state.isLoading && _rules.isEmpty;
  bool get isRefreshing => _state.isLoading && _rules.isNotEmpty;

  bool get hasFilters => _search.trim().isNotEmpty || _scopeFilter != null;

  /// The catalogue filtered by the Search box — client-side, as the website
  /// does it, against whatever the rule targets and its notes.
  List<RevenueSplitRule> get rules {
    final query = _search.trim().toLowerCase();
    if (query.isEmpty) return _rules;

    return _rules.where((rule) {
      final haystack = [
        rule.targetLabel,
        rule.complexLabel,
        rule.notes ?? '',
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList(growable: false);
  }

  Future<void> load() async {
    _state = ViewState.loading;
    _error = null;
    _safeNotify();

    try {
      final rules = await _repository.getRules(
        includeInactive: _includeInactive,
        scope: _scopeFilter?.wire,
      );
      if (_disposed) return;
      _rules = rules;
      _state = ViewState.ready;
      AdminLog.state('Revenue split rules ready → ${rules.length}');
    } on ApiException catch (error) {
      if (_disposed) return;
      _state = ViewState.failed;
      _error = error.message;
      AdminLog.failure('Revenue split rules failed', error: error);
    } catch (error, stackTrace) {
      if (_disposed) return;
      _state = ViewState.failed;
      _error = 'Could not load the rules. Please try again.';
      AdminLog.failure(
        'Revenue split rules crashed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _safeNotify();
    }
  }

  Future<void> refresh() => load();

  void onSearchChanged(String value) {
    if (_search == value) return;
    _search = value;
    _safeNotify();
  }

  void clearSearch() {
    if (_search.isEmpty) return;
    _search = '';
    _safeNotify();
  }

  void setScopeFilter(RevenueSplitScope? scope) {
    if (scope == _scopeFilter) return;
    AdminLog.ui('Revenue split scope filter → ${scope?.wire ?? 'all'}');
    _scopeFilter = scope;
    load();
  }

  void setIncludeInactive(bool value) {
    if (value == _includeInactive) return;
    AdminLog.ui('Revenue split show-inactive → $value');
    _includeInactive = value;
    load();
  }

  // --- Form options --------------------------------------------------------

  RevenueSplitOptions _options = RevenueSplitOptions.empty;
  ViewState _optionsState = ViewState.idle;

  RevenueSplitOptions get options => _options;
  ViewState get optionsState => _optionsState;

  Future<void> loadOptions({bool refresh = false}) async {
    if (_optionsState.isLoading) return;
    if (_options.sports.isNotEmpty && !refresh) return;

    _optionsState = ViewState.loading;
    _safeNotify();

    try {
      final options = await _repository.getOptions();
      if (_disposed) return;
      _options = options;
      _optionsState = ViewState.ready;
    } catch (error, stackTrace) {
      if (_disposed) return;
      _optionsState = ViewState.failed;
      AdminLog.failure(
        'Revenue split options failed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _safeNotify();
    }
  }

  // --- Coverage (the backfill gate) -----------------------------------------

  RevenueSplitCoverage _coverage = RevenueSplitCoverage.empty;
  ViewState _coverageState = ViewState.idle;

  RevenueSplitCoverage get coverage => _coverage;
  ViewState get coverageState => _coverageState;

  Future<void> loadCoverage() async {
    _coverageState = ViewState.loading;
    _safeNotify();

    try {
      final coverage = await _repository.getCoverage();
      if (_disposed) return;
      _coverage = coverage;
      _coverageState = ViewState.ready;
      AdminLog.state(
        'Revenue split coverage → clear=${coverage.clear}, '
        '${coverage.gaps.length} gap(s)',
      );
    } catch (error, stackTrace) {
      if (_disposed) return;
      _coverageState = ViewState.failed;
      AdminLog.failure(
        'Revenue split coverage failed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _safeNotify();
    }
  }

  // --- Writes ----------------------------------------------------------------

  /// The count the last successful [update] returned — read by the caller
  /// right after `await`, before anything else can overwrite it.
  int? lastAffectedExistingPayments;

  Future<RevenueSplitRule> create(RevenueSplitDraft draft) async {
    AdminLog.ui('Create revenue split rule submitted');
    final created = await _repository.createRule(draft);
    await load();
    unawaited(loadCoverage());
    return created;
  }

  Future<RevenueSplitRule> update(int id, RevenueSplitDraft draft) async {
    AdminLog.ui('Update revenue split rule $id submitted');
    final (updated, affected) = await _repository.updateRule(id, draft);
    lastAffectedExistingPayments = affected;
    await load();
    unawaited(loadCoverage());
    return updated;
  }

  /// Optimistic, with rollback — matches the pattern the rest of this
  /// console uses for a single-field toggle.
  Future<String?> setActive(RevenueSplitRule rule, bool active) async {
    final index = _rules.indexWhere((r) => r.id == rule.id);
    if (index == -1) return null;

    final previous = _rules[index];
    _replaceAt(index, _withActive(previous, active));

    try {
      if (active) {
        await _repository.reactivateRule(rule.id);
      } else {
        await _repository.deactivateRule(rule.id);
      }
      unawaited(loadCoverage());
      return null;
    } catch (error) {
      _replaceAt(index, previous);
      AdminLog.failure('Revenue split rule ${rule.id} toggle failed', error: error);
      return error is ApiException
          ? error.message
          : 'Could not update this rule. Please try again.';
    }
  }

  void _replaceAt(int index, RevenueSplitRule rule) {
    final next = List<RevenueSplitRule>.of(_rules);
    next[index] = rule;
    _rules = next;
    _safeNotify();
  }

  static RevenueSplitRule _withActive(RevenueSplitRule rule, bool active) {
    return RevenueSplitRule(
      id: rule.id,
      scopeRaw: rule.scopeRaw,
      batchId: rule.batchId,
      sportId: rule.sportId,
      coachId: rule.coachId,
      sportComplexId: rule.sportComplexId,
      coachPercent: rule.coachPercent,
      nahataPercent: rule.nahataPercent,
      effectiveFrom: rule.effectiveFrom,
      notes: rule.notes,
      isActive: active,
      createdAt: rule.createdAt,
      updatedAt: rule.updatedAt,
      batchName: rule.batchName,
      batchFees: rule.batchFees,
      sportName: rule.sportName,
      coachName: rule.coachName,
      complexName: rule.complexName,
      complexCity: rule.complexCity,
    );
  }

  // --- Check a Batch -----------------------------------------------------

  Future<RevenueSplitResolution> checkBatch({
    int? batchId,
    int? sportId,
    int? coachId,
    DateTime? paidOn,
  }) {
    AdminLog.ui('Check a batch → batchId=$batchId sportId=$sportId');
    return _repository.resolve(
      batchId: batchId,
      sportId: sportId,
      coachId: coachId,
      paidOn: paidOn,
    );
  }

  // --- Backfill wizard -----------------------------------------------------

  ViewState _previewState = ViewState.idle;
  RevenueSplitBackfillPreview? _preview;
  String? _previewError;

  ViewState get previewState => _previewState;
  RevenueSplitBackfillPreview? get preview => _preview;
  String? get previewError => _previewError;

  Future<void> loadBackfillPreview() async {
    _previewState = ViewState.loading;
    _previewError = null;
    _safeNotify();

    try {
      final preview = await _repository.dryRunBackfill();
      if (_disposed) return;
      _preview = preview;
      _previewState = ViewState.ready;
      AdminLog.data(
        'Backfill preview → wouldWrite=${preview.wouldWrite}, '
        'canApply=${preview.canApply}',
      );
    } catch (error, stackTrace) {
      if (_disposed) return;
      _previewState = ViewState.failed;
      _previewError = error is ApiException
          ? error.message
          : 'Could not preview the backfill. Please try again.';
      AdminLog.failure(
        'Backfill preview failed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _safeNotify();
    }
  }

  /// Throws on failure — the wizard dialog stays open and shows why.
  Future<RevenueSplitBackfillResult> applyBackfill() async {
    AdminLog.ui('Backfill apply confirmed');
    final result = await _repository.applyBackfill();
    unawaited(loadCoverage());
    _preview = null;
    return result;
  }

  Future<RevenueSplitRollbackResult> rollbackBackfill() async {
    AdminLog.ui('Backfill rollback confirmed');
    final result = await _repository.rollbackBackfill();
    unawaited(loadCoverage());
    return result;
  }

  void clearBackfillPreview() {
    _preview = null;
    _previewState = ViewState.idle;
    _previewError = null;
    _safeNotify();
  }

  // --- Plumbing --------------------------------------------------------------

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    AdminLog.life('RevenueSplitController disposed');
    super.dispose();
  }
}
