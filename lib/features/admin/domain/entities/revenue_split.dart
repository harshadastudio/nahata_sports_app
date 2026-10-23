/// Coaching Revenue > Revenue Split (`/revenue-splits`), ADMIN (super admin)
/// only — a rate is commercially sensitive, and even COMPLEX_ADMIN /
/// EMPLOYEE are refused on the read routes.
///
/// **The two rules that govern this whole module**, straight from the API's
/// own docs:
/// 1. Most specific rule wins: `batch` beats `sport_coach`, which beats
///    `sport`. Nothing matches → the payment is 100% Nahata and flagged
///    [RevenueSplitResolution.needsSplitRule], never a guessed percentage.
/// 2. Percentages are **frozen onto each payment** when the money is
///    received. Editing or deactivating a rule changes future payments only.
library;

/// `batch` beats `sport_coach`, which beats `sport`.
enum RevenueSplitScope {
  batch('batch', 'This batch'),
  sportCoach('sport_coach', 'This coach, in this sport'),
  sport('sport', 'This sport (default)');

  const RevenueSplitScope(this.wire, this.label);

  /// The exact string the API sends and expects — never case-folded.
  final String wire;

  final String label;

  static RevenueSplitScope? tryParse(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim().toLowerCase();
    for (final scope in RevenueSplitScope.values) {
      if (scope.wire == text) return scope;
    }
    return null;
  }
}

/// One rule from `GET /revenue-splits`.
class RevenueSplitRule {
  const RevenueSplitRule({
    required this.id,
    this.scopeRaw,
    this.batchId,
    this.sportId,
    this.coachId,
    this.sportComplexId,
    this.coachPercent = 0,
    num? nahataPercent,
    this.effectiveFrom,
    this.notes,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.batchName,
    this.batchFees,
    this.sportName,
    this.coachName,
    this.complexName,
    this.complexCity,
  }) : nahataPercent = nahataPercent ?? (100 - coachPercent);

  final int id;
  final String? scopeRaw;

  final int? batchId;
  final int? sportId;
  final int? coachId;
  final int? sportComplexId;

  final num coachPercent;

  /// `= 100 - coachPercent` — the database does not store it, so a mapper
  /// that receives it also derives it as a fallback.
  final num nahataPercent;

  /// A rule only applies to money received on or after this date.
  final DateTime? effectiveFrom;

  final String? notes;
  final bool isActive;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  final String? batchName;
  final num? batchFees;
  final String? sportName;
  final String? coachName;
  final String? complexName;
  final String? complexCity;

  RevenueSplitScope? get scope => RevenueSplitScope.tryParse(scopeRaw);

  String get scopeLabel => scope?.label ?? (scopeRaw ?? '—');

  /// What this rule actually targets, for the rules table's Target column.
  String get targetLabel {
    switch (scope) {
      case RevenueSplitScope.batch:
        return (batchName ?? '').trim().isEmpty
            ? 'Batch #$batchId'
            : batchName!.trim();
      case RevenueSplitScope.sportCoach:
        final sport = (sportName ?? '').trim();
        final coach = (coachName ?? '').trim();
        if (sport.isEmpty && coach.isEmpty) return '—';
        if (coach.isEmpty) return sport;
        if (sport.isEmpty) return coach;
        return '$coach · $sport';
      case RevenueSplitScope.sport:
        return (sportName ?? '').trim().isEmpty
            ? 'Sport #$sportId'
            : sportName!.trim();
      case null:
        return '—';
    }
  }

  String get complexLabel {
    final name = (complexName ?? '').trim();
    if (name.isEmpty) return '—';
    final city = (complexCity ?? '').trim();
    return city.isEmpty ? name : '$name · $city';
  }

  String get splitLabel => '$coachPercent% coach / $nahataPercent% Nahata';

  @override
  String toString() =>
      'RevenueSplitRule($id, $scopeRaw, $targetLabel, $coachPercent%, '
      'active: $isActive)';
}

/// The write payload for both create (`POST /revenue-splits`) and update
/// (`PUT /revenue-splits/{id}`) — the update route merges whatever is sent
/// onto the stored rule, and every field here always carries a real value, so
/// one body shape serves both.
class RevenueSplitDraft {
  const RevenueSplitDraft({
    required this.scope,
    this.batchId,
    this.sportId,
    this.coachId,
    required this.coachPercent,
    required this.effectiveFrom,
    this.notes,
  });

  final RevenueSplitScope scope;
  final int? batchId;
  final int? sportId;
  final int? coachId;
  final num coachPercent;
  final DateTime effectiveFrom;
  final String? notes;

  static String formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  /// Scope decides which target fields travel — the API nulls the rest
  /// itself, but sending them null here keeps an edit from leaving a stale
  /// id behind when the scope changes.
  Map<String, dynamic> toBody() {
    return <String, dynamic>{
      'scope': scope.wire,
      'batchId': scope == RevenueSplitScope.batch ? batchId : null,
      'sportId': scope == RevenueSplitScope.batch ? null : sportId,
      'coachId': scope == RevenueSplitScope.sportCoach ? coachId : null,
      'coachPercent': coachPercent,
      'effectiveFrom': formatDate(effectiveFrom),
      'notes': (notes ?? '').trim().isEmpty ? null : notes!.trim(),
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Form options
// ─────────────────────────────────────────────────────────────────────────────

class RevenueSplitSportOption {
  const RevenueSplitSportOption({
    required this.id,
    this.name = '',
    this.sportComplexId,
  });

  final int id;
  final String name;
  final int? sportComplexId;

  String get displayName => name.trim().isEmpty ? 'Sport #$id' : name.trim();
}

class RevenueSplitCoachOption {
  const RevenueSplitCoachOption({
    required this.id,
    this.name = '',
    this.email,
    this.sportId,
    this.sportComplexId,
  });

  final int id;
  final String name;
  final String? email;
  final int? sportId;
  final int? sportComplexId;

  String get displayName => name.trim().isEmpty ? 'Coach #$id' : name.trim();
}

class RevenueSplitBatchOption {
  const RevenueSplitBatchOption({
    required this.id,
    this.name = '',
    this.sportId,
    this.coachId,
    this.sportComplexId,
    this.fees,
    this.sportName,
    this.coachName,
  });

  final int id;
  final String name;
  final int? sportId;
  final int? coachId;
  final int? sportComplexId;
  final num? fees;
  final String? sportName;
  final String? coachName;

  String get displayName => name.trim().isEmpty ? 'Batch #$id' : name.trim();

  /// `Badminton · Dashrath Birhamane`, whatever half is known.
  String get subtitle {
    final parts = <String>[
      if ((sportName ?? '').trim().isNotEmpty) sportName!.trim(),
      if ((coachName ?? '').trim().isNotEmpty) coachName!.trim(),
    ];
    return parts.join(' · ');
  }
}

class RevenueSplitComplexOption {
  const RevenueSplitComplexOption({required this.id, this.name = '', this.city});

  final int id;
  final String name;
  final String? city;

  String get displayName => name.trim().isEmpty ? 'Complex #$id' : name.trim();
}

/// Everything `GET /revenue-splits/options` returns in one call.
class RevenueSplitOptions {
  const RevenueSplitOptions({
    this.sports = const [],
    this.coaches = const [],
    this.batches = const [],
    this.complexes = const [],
  });

  final List<RevenueSplitSportOption> sports;
  final List<RevenueSplitCoachOption> coaches;

  /// **Not filtered to Active** — unlike sports and coaches. An inactive
  /// batch can still need a rate for money already collected against it.
  final List<RevenueSplitBatchOption> batches;
  final List<RevenueSplitComplexOption> complexes;

  static const RevenueSplitOptions empty = RevenueSplitOptions();
}

// ─────────────────────────────────────────────────────────────────────────────
// Coverage (the backfill gate)
// ─────────────────────────────────────────────────────────────────────────────

class RevenueSplitCoverageGap {
  const RevenueSplitCoverageGap({
    this.batchId,
    this.batchName,
    this.sportName,
    this.coachName,
    this.complexName,
    this.enrolments = 0,
    this.collected = 0,
  });

  final int? batchId;
  final String? batchName;
  final String? sportName;
  final String? coachName;
  final String? complexName;
  final int enrolments;
  final num collected;

  String get displayName =>
      (batchName ?? '').trim().isEmpty ? 'Batch #$batchId' : batchName!.trim();
}

/// Shared by `coverage.summary` and the backfill dry-run's `totals` — the two
/// carry the same field set.
class RevenueSplitSummary {
  const RevenueSplitSummary({
    this.enrolments = 0,
    this.pending = 0,
    this.alreadyLedgered = 0,
    this.unmatched = 0,
    this.totalReceived = 0,
    this.pendingReceived = 0,
    this.pendingCoachTotal = 0,
    this.pendingNahataTotal = 0,
    this.withDiscountWarning = 0,
    this.reconciles = true,
  });

  final int enrolments;
  final int pending;
  final int alreadyLedgered;
  final int unmatched;
  final num totalReceived;
  final num pendingReceived;
  final num pendingCoachTotal;
  final num pendingNahataTotal;
  final int withDiscountWarning;
  final bool reconciles;

  static const RevenueSplitSummary empty = RevenueSplitSummary();
}

/// `GET /revenue-splits/coverage` — which sports/coaches/batches have
/// collected money but no rule that resolves for them.
class RevenueSplitCoverage {
  const RevenueSplitCoverage({
    this.clear = false,
    this.gaps = const [],
    this.uncoveredAmount = 0,
    this.summary = RevenueSplitSummary.empty,
  });

  /// The ONLY state in which a backfill apply is permitted.
  final bool clear;
  final List<RevenueSplitCoverageGap> gaps;
  final num uncoveredAmount;
  final RevenueSplitSummary summary;

  static const RevenueSplitCoverage empty = RevenueSplitCoverage();
}

// ─────────────────────────────────────────────────────────────────────────────
// Resolve / Check a Batch
// ─────────────────────────────────────────────────────────────────────────────

class RevenueSplitResolveContext {
  const RevenueSplitResolveContext({
    this.batchId,
    this.sportId,
    this.coachId,
    this.paidOn,
    this.batchFee,
  });

  final int? batchId;
  final int? sportId;
  final int? coachId;
  final DateTime? paidOn;
  final num? batchFee;
}

/// The CHECK A BATCH preview — runs the *same* resolver the write path uses.
class RevenueSplitResolution {
  const RevenueSplitResolution({
    this.matched = false,
    this.rule,
    this.coachPercent = 0,
    this.nahataPercent = 100,
    this.needsSplitRule = true,
    this.context = const RevenueSplitResolveContext(),
  });

  final bool matched;
  final RevenueSplitRule? rule;
  final num coachPercent;
  final num nahataPercent;

  /// True when nothing matched — the honest answer, never a guess.
  final bool needsSplitRule;

  final RevenueSplitResolveContext context;
}

// ─────────────────────────────────────────────────────────────────────────────
// Backfill wizard
// ─────────────────────────────────────────────────────────────────────────────

class RevenueSplitBackfillRow {
  const RevenueSplitBackfillRow({
    this.studentBatchId,
    this.studentId,
    this.batchId,
    this.batchName,
    this.sportName,
    this.coachName,
    this.complexName,
    this.paidOn,
    this.grossFee,
    this.amountReceived,
    this.ruleId,
    this.ruleScope,
    this.ruleCoachPercent,
    this.coachPercent = 0,
    this.nahataPercent = 100,
    this.coachAmount = 0,
    this.nahataAmount = 0,
    this.needsSplitRule = false,
    this.noCoachAssigned = false,
    this.coachExceedsCash = false,
    this.status = 'pending',
  });

  final int? studentBatchId;
  final int? studentId;
  final int? batchId;
  final String? batchName;
  final String? sportName;
  final String? coachName;
  final String? complexName;
  final DateTime? paidOn;
  final num? grossFee;
  final num? amountReceived;

  final int? ruleId;
  final String? ruleScope;
  final num? ruleCoachPercent;

  final num coachPercent;
  final num nahataPercent;
  final num coachAmount;
  final num nahataAmount;

  final bool needsSplitRule;
  final bool noCoachAssigned;

  /// A discounted enrolment where the coach's entitlement is more than the
  /// cash actually collected.
  final bool coachExceedsCash;

  /// `pending` | `skipped`.
  final String status;

  bool get isPending => status.toLowerCase() == 'pending';

  String get displayName =>
      (batchName ?? '').trim().isEmpty ? 'Batch #$batchId' : batchName!.trim();
}

/// `POST /revenue-splits/backfill/dry-run` — report only, writes nothing.
class RevenueSplitBackfillPreview {
  const RevenueSplitBackfillPreview({
    this.wouldWrite = 0,
    this.canApply = false,
    this.blockedReason,
    this.coverage = RevenueSplitCoverage.empty,
    this.totals = RevenueSplitSummary.empty,
    this.rows = const [],
  });

  final int wouldWrite;
  final bool canApply;
  final String? blockedReason;
  final RevenueSplitCoverage coverage;
  final RevenueSplitSummary totals;
  final List<RevenueSplitBackfillRow> rows;

  static const RevenueSplitBackfillPreview empty = RevenueSplitBackfillPreview();
}

/// `POST /revenue-splits/backfill/apply`.
class RevenueSplitBackfillResult {
  const RevenueSplitBackfillResult({
    this.written = 0,
    this.skipped = 0,
    this.ledgerTotal = 0,
    this.expected = 0,
    this.message,
  });

  final int written;
  final int skipped;
  final num ledgerTotal;
  final num expected;
  final String? message;
}

/// `POST /revenue-splits/backfill/rollback`.
class RevenueSplitRollbackResult {
  const RevenueSplitRollbackResult({this.removed = 0, this.message});

  final int removed;
  final String? message;
}
