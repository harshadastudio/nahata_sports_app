import '../../domain/entities/revenue_split.dart';
import 'json_reader.dart';

/// Maps `/revenue-splits` JSON onto the [RevenueSplitRule] family.
///
/// Every read tolerates a missing or wrong-typed field — one odd row must
/// never take the rules table down.
class RevenueSplitMapper {
  const RevenueSplitMapper._();

  // ───────────────────────────────────────────────────────────────────────────
  // Rule
  // ───────────────────────────────────────────────────────────────────────────

  static RevenueSplitRule fromJson(Map<String, dynamic> json) {
    final batch = _nested(json, 'batch');
    final sport = _nested(json, 'sport');
    final coach = _nested(json, 'coach');
    final complex = _nested(json, 'sportComplex');

    final batchSport = batch == null ? null : _nested(batch, 'sport');
    final batchCoach = batch == null ? null : _nested(batch, 'coach');

    return RevenueSplitRule(
      id: JsonReader.ownInteger(json, const ['id']) ?? 0,
      scopeRaw: JsonReader.string(json, const ['scope']),
      batchId: JsonReader.integer(json, const ['batchId', 'batch_id']),
      sportId: JsonReader.integer(json, const ['sportId', 'sport_id']),
      coachId: JsonReader.integer(json, const ['coachId', 'coach_id']),
      sportComplexId: JsonReader.integer(
        json,
        const ['sportComplexId', 'sport_complex_id'],
      ),
      coachPercent: _number(json, const ['coachPercent', 'coach_percent']) ?? 0,
      nahataPercent: _number(json, const ['nahataPercent', 'nahata_percent']),
      effectiveFrom: JsonReader.date(
        json,
        const ['effectiveFrom', 'effective_from'],
      ),
      notes: JsonReader.string(json, const ['notes']),
      isActive: JsonReader.boolean(json, const ['isActive', 'is_active']) ?? true,
      createdAt: JsonReader.date(json, const ['createdAt', 'created_at']),
      updatedAt: JsonReader.date(json, const ['updatedAt', 'updated_at']),
      batchName: batch == null
          ? null
          : JsonReader.string(batch, const ['name']),
      batchFees: batch == null ? null : _number(batch, const ['fees']),
      sportName: JsonReader.string(sport ?? batchSport ?? const {}, const [
        'name',
      ]),
      coachName: JsonReader.string(coach ?? batchCoach ?? const {}, const [
        'name',
      ]),
      complexName: complex == null
          ? null
          : JsonReader.string(complex, const ['name']),
      complexCity: complex == null
          ? null
          : JsonReader.string(complex, const ['city']),
    );
  }

  static List<RevenueSplitRule> listFrom(Object? body) {
    // The list endpoint's `data` is a bare array — no rows/items wrapper —
    // and JsonReader.records already falls through to it.
    return JsonReader.records(body, keys: const ['rules'])
        .map(fromJson)
        .where((rule) => rule.id > 0)
        .toList(growable: false);
  }

  static List<Map<String, dynamic>> rowsIn(Object? body) =>
      JsonReader.records(body, keys: const ['rules']);

  /// The single rule inside a create/update response body.
  static RevenueSplitRule? maybeFromBody(Object? body) {
    if (body is! Map) return null;
    final map = Map<String, dynamic>.from(body);
    final data = map['data'];
    final source = data is Map ? Map<String, dynamic>.from(data) : map;
    if (source['id'] == null) return null;
    return fromJson(source);
  }

  /// `affectedExistingPayments` sits beside `data` on the update response,
  /// not inside it.
  static int? affectedExistingPayments(Object? body) {
    if (body is! Map) return null;
    return JsonReader.ownInteger(Map<String, dynamic>.from(body), const [
      'affectedExistingPayments',
    ]);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Options
  // ───────────────────────────────────────────────────────────────────────────

  static RevenueSplitOptions optionsFrom(Object? body) {
    final source = _envelope(body);

    return RevenueSplitOptions(
      sports: _list(source['sports'])
          .map(_sportOption)
          .where((option) => option.id > 0)
          .toList(growable: false),
      coaches: _list(source['coaches'])
          .map(_coachOption)
          .where((option) => option.id > 0)
          .toList(growable: false),
      batches: _list(source['batches'])
          .map(_batchOption)
          .where((option) => option.id > 0)
          .toList(growable: false),
      complexes: _list(source['complexes'])
          .map(_complexOption)
          .where((option) => option.id > 0)
          .toList(growable: false),
    );
  }

  static RevenueSplitSportOption _sportOption(Map<String, dynamic> json) {
    return RevenueSplitSportOption(
      id: JsonReader.ownInteger(json, const ['id']) ?? 0,
      name: JsonReader.string(json, const ['name']) ?? '',
      sportComplexId: JsonReader.integer(
        json,
        const ['sportComplexId', 'sport_complex_id'],
      ),
    );
  }

  static RevenueSplitCoachOption _coachOption(Map<String, dynamic> json) {
    return RevenueSplitCoachOption(
      id: JsonReader.ownInteger(json, const ['id']) ?? 0,
      name: JsonReader.string(json, const ['name']) ?? '',
      email: JsonReader.string(json, const ['email']),
      sportId: JsonReader.integer(json, const ['sportId', 'sport_id']),
      sportComplexId: JsonReader.integer(
        json,
        const ['sportComplexId', 'sport_complex_id'],
      ),
    );
  }

  static RevenueSplitBatchOption _batchOption(Map<String, dynamic> json) {
    final sport = _nested(json, 'sport');
    final coach = _nested(json, 'coach');

    return RevenueSplitBatchOption(
      id: JsonReader.ownInteger(json, const ['id']) ?? 0,
      name: JsonReader.string(json, const ['name']) ?? '',
      sportId: JsonReader.integer(json, const ['sportId', 'sport_id']),
      coachId: JsonReader.integer(json, const ['coachId', 'coach_id']),
      sportComplexId: JsonReader.integer(
        json,
        const ['sportComplexId', 'sport_complex_id'],
      ),
      fees: _number(json, const ['fees']),
      sportName: sport == null ? null : JsonReader.string(sport, const ['name']),
      coachName: coach == null ? null : JsonReader.string(coach, const ['name']),
    );
  }

  static RevenueSplitComplexOption _complexOption(Map<String, dynamic> json) {
    return RevenueSplitComplexOption(
      id: JsonReader.ownInteger(json, const ['id']) ?? 0,
      name: JsonReader.string(json, const ['name']) ?? '',
      city: JsonReader.string(json, const ['city']),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Coverage
  // ───────────────────────────────────────────────────────────────────────────

  static RevenueSplitCoverage coverageFrom(Object? body) {
    final source = _envelope(body);
    return RevenueSplitCoverage(
      clear: JsonReader.boolean(source, const ['clear']) ?? false,
      gaps: _list(source['gaps'])
          .map(_gap)
          .toList(growable: false),
      uncoveredAmount: _number(source, const ['uncoveredAmount']) ?? 0,
      summary: _summary(_nested(source, 'summary') ?? const {}),
    );
  }

  static RevenueSplitCoverageGap _gap(Map<String, dynamic> json) {
    return RevenueSplitCoverageGap(
      batchId: JsonReader.integer(json, const ['batchId']),
      batchName: JsonReader.string(json, const ['batchName']),
      sportName: JsonReader.string(json, const ['sportName']),
      coachName: JsonReader.string(json, const ['coachName']),
      complexName: JsonReader.string(json, const ['complexName']),
      enrolments: JsonReader.integer(json, const ['enrolments']) ?? 0,
      collected: _number(json, const ['collected']) ?? 0,
    );
  }

  static RevenueSplitSummary _summary(Map<String, dynamic> json) {
    return RevenueSplitSummary(
      enrolments: JsonReader.integer(json, const ['enrolments']) ?? 0,
      pending: JsonReader.integer(json, const ['pending']) ?? 0,
      alreadyLedgered: JsonReader.integer(json, const ['alreadyLedgered']) ?? 0,
      unmatched: JsonReader.integer(json, const ['unmatched']) ?? 0,
      totalReceived: _number(json, const ['totalReceived']) ?? 0,
      pendingReceived: _number(json, const ['pendingReceived']) ?? 0,
      pendingCoachTotal: _number(json, const ['pendingCoachTotal']) ?? 0,
      pendingNahataTotal: _number(json, const ['pendingNahataTotal']) ?? 0,
      withDiscountWarning:
          JsonReader.integer(json, const ['withDiscountWarning']) ?? 0,
      reconciles: JsonReader.boolean(json, const ['reconciles']) ?? true,
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Resolve
  // ───────────────────────────────────────────────────────────────────────────

  static RevenueSplitResolution resolutionFrom(Object? body) {
    final source = _envelope(body);
    final ruleJson = _nested(source, 'rule');
    final context = _nested(source, 'context') ?? const {};

    return RevenueSplitResolution(
      matched: JsonReader.boolean(source, const ['matched']) ?? false,
      rule: ruleJson == null ? null : fromJson(ruleJson),
      coachPercent: _number(source, const ['coachPercent']) ?? 0,
      nahataPercent: _number(source, const ['nahataPercent']) ?? 100,
      needsSplitRule:
          JsonReader.boolean(source, const ['needsSplitRule']) ?? true,
      context: RevenueSplitResolveContext(
        batchId: JsonReader.integer(context, const ['batchId']),
        sportId: JsonReader.integer(context, const ['sportId']),
        coachId: JsonReader.integer(context, const ['coachId']),
        paidOn: JsonReader.date(context, const ['paidOn']),
        batchFee: _number(context, const ['batchFee']),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Backfill
  // ───────────────────────────────────────────────────────────────────────────

  static RevenueSplitBackfillPreview previewFrom(Object? body) {
    final source = _envelope(body);

    return RevenueSplitBackfillPreview(
      wouldWrite: JsonReader.integer(source, const ['wouldWrite']) ?? 0,
      canApply: JsonReader.boolean(source, const ['canApply']) ?? false,
      blockedReason: JsonReader.string(source, const ['blockedReason']),
      coverage: coverageFrom(<String, dynamic>{
        'data': _nested(source, 'coverage') ?? const {},
      }),
      totals: _summary(_nested(source, 'totals') ?? const {}),
      rows: _list(source['rows']).map(_row).toList(growable: false),
    );
  }

  static RevenueSplitBackfillRow _row(Map<String, dynamic> json) {
    final rule = _nested(json, 'rule');

    return RevenueSplitBackfillRow(
      studentBatchId: JsonReader.integer(json, const ['studentBatchId']),
      studentId: JsonReader.integer(json, const ['studentId']),
      batchId: JsonReader.integer(json, const ['batchId']),
      batchName: JsonReader.string(json, const ['batchName']),
      sportName: JsonReader.string(json, const ['sportName']),
      coachName: JsonReader.string(json, const ['coachName']),
      complexName: JsonReader.string(json, const ['complexName']),
      paidOn: JsonReader.date(json, const ['paidOn']),
      grossFee: _number(json, const ['grossFee']),
      amountReceived: _number(json, const ['amountReceived']),
      ruleId: rule == null ? null : JsonReader.ownInteger(rule, const ['id']),
      ruleScope: rule == null ? null : JsonReader.string(rule, const ['scope']),
      ruleCoachPercent: rule == null
          ? null
          : _number(rule, const ['coachPercent']),
      coachPercent: _number(json, const ['coachPercent']) ?? 0,
      nahataPercent: _number(json, const ['nahataPercent']) ?? 100,
      coachAmount: _number(json, const ['coachAmount']) ?? 0,
      nahataAmount: _number(json, const ['nahataAmount']) ?? 0,
      needsSplitRule:
          JsonReader.boolean(json, const ['needsSplitRule']) ?? false,
      noCoachAssigned:
          JsonReader.boolean(json, const ['noCoachAssigned']) ?? false,
      coachExceedsCash:
          JsonReader.boolean(json, const ['coachExceedsCash']) ?? false,
      status: JsonReader.string(json, const ['status']) ?? 'pending',
    );
  }

  static RevenueSplitBackfillResult applyResultFrom(Object? body) {
    final source = _envelope(body);
    return RevenueSplitBackfillResult(
      written: JsonReader.integer(source, const ['written']) ?? 0,
      skipped: JsonReader.integer(source, const ['skipped']) ?? 0,
      ledgerTotal: _number(source, const ['ledgerTotal']) ?? 0,
      expected: _number(source, const ['expected']) ?? 0,
      message: (body is Map)
          ? JsonReader.string(Map<String, dynamic>.from(body), const [
              'message',
            ])
          : null,
    );
  }

  static RevenueSplitRollbackResult rollbackResultFrom(Object? body) {
    final source = _envelope(body);
    return RevenueSplitRollbackResult(
      removed: JsonReader.integer(source, const ['removed']) ?? 0,
      message: (body is Map)
          ? JsonReader.string(Map<String, dynamic>.from(body), const [
              'message',
            ])
          : null,
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Helpers
  // ───────────────────────────────────────────────────────────────────────────

  /// The `data` object of a `{success, data: {...}}` body, or the body
  /// itself when it was not wrapped.
  static Map<String, dynamic> _envelope(Object? body) {
    if (body is! Map) return const {};
    final map = Map<String, dynamic>.from(body);
    final data = map['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return map;
  }

  static Map<String, dynamic>? _nested(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static List<Map<String, dynamic>> _list(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }

  static num? _number(Map<String, dynamic> json, List<String> keys) {
    final value = JsonReader.pick(json, keys);
    if (value == null) return null;
    if (value is num) return value;
    return num.tryParse(value.toString().trim());
  }
}
