/// Month-wise student enrollments, from
/// `GET /coach/dashboard/students/enrollments-by-month`.
///
/// Answers "who was in my batches in a given month?". A student is listed in
/// **every** month their enrollment is live, not only the month they joined:
/// the window runs from `enrollmentDate` to `validTill` (falling back to the
/// batch end date, open-ended when neither is set). So someone who joins on
/// 31 Jul with validity to 15 Aug appears in both July and August — flagged
/// `isNew` in July and carried over in August.
///
/// Dropped and transferred enrollments stop carrying forward past the month
/// they ended.
library;

/// One month in the picker, with how many enrollments were live in it.
class CoachEnrollmentMonth {
  const CoachEnrollmentMonth({
    required this.month,
    this.label = '',
    this.count = 0,
  });

  /// `yyyy-MM` — what the `month` query parameter takes.
  final String month;

  /// Pre-formatted by the API, e.g. `"August 2026"`.
  final String label;

  final int count;

  String get displayLabel => label.trim().isEmpty ? month : label.trim();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CoachEnrollmentMonth && other.month == month);

  @override
  int get hashCode => month.hashCode;

  @override
  String toString() => 'CoachEnrollmentMonth($month, $count)';
}

/// The counters across the selected month.
class CoachEnrollmentSummary {
  const CoachEnrollmentSummary({
    this.totalStudents = 0,
    this.totalBatches = 0,
    this.newThisMonth = 0,
    this.continuing = 0,
    this.expiring = 0,
    this.active = 0,
    this.paid = 0,
    this.pending = 0,
  });

  /// Enrollment rows live in the month — a student in two batches counts
  /// twice, matching how the rest of the coach dashboard counts.
  final int totalStudents;

  final int totalBatches;

  /// Joined during the selected month.
  final int newThisMonth;

  /// Carried over from an earlier month.
  final int continuing;

  /// Validity runs out inside the selected month — renewal due.
  final int expiring;

  final int active;
  final int paid;

  /// Everything whose `paymentStatus` is not `Paid`, so this includes
  /// partially paid enrollments.
  final int pending;

  static const CoachEnrollmentSummary empty = CoachEnrollmentSummary();

  bool get isEmpty => totalStudents == 0 && totalBatches == 0;

  @override
  String toString() =>
      'CoachEnrollmentSummary($totalStudents students, $newThisMonth new, '
      '$expiring expiring)';
}

/// One student's enrollment inside a batch, for the selected month.
class CoachEnrollment {
  const CoachEnrollment({
    required this.enrollmentId,
    this.studentId = 0,
    this.name = '',
    this.email = '',
    this.phone = '',
    this.enrollmentDate,
    this.validTill,
    this.validTillSource,
    this.isNew = false,
    this.expiring = false,
    this.statusRaw,
    this.paymentStatusRaw,
    this.approvalStatusRaw,
    this.amountPaid = 0,
    this.feesPaid = false,
  });

  /// The `StudentBatches` row id — also the number embedded in the student's
  /// gate pass code.
  final int enrollmentId;

  /// The `Student` row id.
  final int studentId;

  final String name;
  final String email;
  final String phone;

  /// `yyyy-MM-dd`.
  final String? enrollmentDate;

  /// Effective validity: the student's own date if set, else the batch end
  /// date, else null for open-ended.
  final String? validTill;

  /// Which of those two the date came from — `"enrollment"` or `"batch"`.
  /// Worth showing, because a date inherited from the batch is not a
  /// per-student commitment.
  final String? validTillSource;

  /// Joined during the selected month, rather than carried over.
  final bool isNew;

  /// Validity runs out inside the selected month.
  final bool expiring;

  final String? statusRaw;
  final String? paymentStatusRaw;
  final String? approvalStatusRaw;

  final num amountPaid;
  final bool feesPaid;

  String get displayName => name.trim().isEmpty ? 'Unknown' : name.trim();

  String get initial => displayName.substring(0, 1).toUpperCase();

  String get statusLabel => (statusRaw ?? '').trim();
  String get paymentLabel => (paymentStatusRaw ?? '').trim();
  String get approvalLabel => (approvalStatusRaw ?? '').trim();

  bool get isActive => statusLabel.toLowerCase() == 'active';
  bool get isPaid => paymentLabel.toLowerCase() == 'paid';

  /// A gate pass only works once the enrollment is `Approved`, so this is what
  /// decides whether the student can actually get in.
  bool get isApproved => approvalLabel.toLowerCase() == 'approved';

  /// Validity inherited from the batch rather than set for this student.
  bool get validityFromBatch =>
      (validTillSource ?? '').trim().toLowerCase() == 'batch';

  bool get isOpenEnded => (validTill ?? '').trim().isEmpty;

  String get contactLabel => [
        if (phone.trim().isNotEmpty) phone.trim(),
        if (email.trim().isNotEmpty) email.trim(),
      ].join(' · ');

  @override
  String toString() =>
      'CoachEnrollment($enrollmentId, $name, ${isNew ? 'new' : 'continuing'})';
}

/// The enrollments for one batch, in the selected month.
class CoachEnrollmentGroup {
  const CoachEnrollmentGroup({
    required this.batchId,
    this.name = '',
    this.sportName,
    this.schedule,
    this.days,
    this.startTime,
    this.endTime,
    this.batchStatusRaw,
    this.fees,
    this.maxStudents,
    this.students = const [],
    this.count = 0,
    this.newCount = 0,
  });

  final int batchId;
  final String name;

  /// `"—"` when the batch has no sport joined.
  final String? sportName;

  final String? schedule;
  final String? days;

  /// Unlike the batches route, this one does send real clock values when the
  /// batch has them.
  final String? startTime;
  final String? endTime;

  final String? batchStatusRaw;

  /// `null` when the batch has no fee set — distinct from a fee of zero.
  final num? fees;

  final int? maxStudents;

  final List<CoachEnrollment> students;

  /// Sent by the API; equal to `students.length` for the selected month.
  final int count;

  /// How many of [count] joined during the selected month.
  final int newCount;

  String get displayName =>
      name.trim().isEmpty ? 'Batch #$batchId' : name.trim();

  String get batchStatusLabel => (batchStatusRaw ?? '').trim();

  /// `"Mon, Wed, Fri · 06:00 - 07:00"`, preferring real clock values over the
  /// free-text `schedule` when both are present.
  String get timingLabel {
    final clock = [
      (startTime ?? '').trim(),
      (endTime ?? '').trim(),
    ].where((p) => p.isNotEmpty).join(' - ');

    final time = clock.isNotEmpty ? clock : (schedule ?? '').trim();

    return [
      if ((days ?? '').trim().isNotEmpty) days!.trim(),
      if (time.isNotEmpty) time,
    ].join(' · ');
  }

  int get expiringCount => students.where((s) => s.expiring).length;
  int get unpaidCount => students.where((s) => !s.isPaid).length;

  @override
  String toString() =>
      'CoachEnrollmentGroup($batchId, $name, $count students)';
}

/// One month's answer in full.
class CoachEnrollmentMonthView {
  const CoachEnrollmentMonthView({
    this.month = '',
    this.label = '',
    this.months = const [],
    this.summary = CoachEnrollmentSummary.empty,
    this.batches = const [],
  });

  /// The month actually returned — the API falls back to the current month, or
  /// to the most recent month that has data, when the request named neither.
  /// Always read the selection back from here rather than assuming the
  /// requested month was honoured.
  final String month;

  /// Pre-formatted, e.g. `"August 2026"`.
  final String label;

  /// Every month with enrollments, newest first.
  final List<CoachEnrollmentMonth> months;

  final CoachEnrollmentSummary summary;

  /// Batches with at least one enrollment live in [month], busiest first.
  final List<CoachEnrollmentGroup> batches;

  static const CoachEnrollmentMonthView empty = CoachEnrollmentMonthView();

  String get displayLabel => label.trim().isEmpty ? month : label.trim();

  bool get isEmpty => batches.isEmpty;

  /// True when this coach has no enrollment history at all, as opposed to none
  /// in the selected month — which the UI phrases very differently.
  bool get hasNoHistory => months.isEmpty;

  @override
  String toString() =>
      'CoachEnrollmentMonthView($month, ${batches.length} batches, '
      '${summary.totalStudents} students)';
}

/// One student row inside a [CoachRenewalBatchGroup] — Copy to Next Month's
/// preview, from `GET /coach/dashboard/students/renewal-preview`.
class CoachRenewalLine {
  const CoachRenewalLine({
    required this.enrollmentId,
    this.studentId = 0,
    this.name = '',
    this.email = '',
    this.phone = '',
    this.statusRaw,
    this.paymentStatusRaw,
    this.approvalStatusRaw,
    this.amountPaid = 0,
    this.alreadyCovered = false,
    this.alreadyRenewed = false,
    this.note = '',
    this.suggestedFee = 0,
    this.defaultSelected = false,
  });

  final int enrollmentId;
  final int studentId;
  final String name;
  final String email;
  final String phone;

  final String? statusRaw;
  final String? paymentStatusRaw;
  final String? approvalStatusRaw;
  final num amountPaid;

  /// Already valid into the target month — still listed, just flagged rather
  /// than hidden.
  final bool alreadyCovered;

  /// The target month was already renewed **and** paid.
  final bool alreadyRenewed;

  /// A ready-made explanation to show verbatim next to the row, e.g. "Already
  /// valid through Oct 2026." Empty for a plain continuing student.
  final String note;

  /// Pre-fill for the fee input — the batch fee, or `0` when the batch has
  /// none.
  final num suggestedFee;

  /// The tick state to start with: false for already-covered / already-renewed
  /// / Dropped rows.
  final bool defaultSelected;

  String get displayName => name.trim().isEmpty ? 'Unknown' : name.trim();

  String get statusLabel => (statusRaw ?? '').trim();

  @override
  String toString() => 'CoachRenewalLine($enrollmentId, $name)';
}

/// One batch's students inside a Copy to Next Month preview.
class CoachRenewalBatchGroup {
  const CoachRenewalBatchGroup({
    required this.batchId,
    this.name = '',
    this.sportName,
    this.schedule,
    this.days,
    this.startTime,
    this.endTime,
    this.fees,
    this.batchEndDate,
    this.students = const [],
    this.count = 0,
  });

  final int batchId;
  final String name;
  final String? sportName;
  final String? schedule;
  final String? days;
  final String? startTime;
  final String? endTime;
  final num? fees;

  /// So the UI can warn when a renewal would run past the batch's own end
  /// date.
  final String? batchEndDate;

  final List<CoachRenewalLine> students;
  final int count;

  String get displayName =>
      name.trim().isEmpty ? 'Batch #$batchId' : name.trim();

  @override
  String toString() => 'CoachRenewalBatchGroup($batchId, $name)';
}

/// Copy to Next Month, step 1 — the whole editable preview.
class CoachRenewalPreview {
  const CoachRenewalPreview({
    this.fromMonth = '',
    this.fromLabel = '',
    this.toMonth = '',
    this.toLabel = '',
    this.defaultValidTill,
    this.candidates = 0,
    this.selectedByDefault = 0,
    this.alreadyCovered = 0,
    this.alreadyRenewed = 0,
    this.feeIfAllCollected = 0,
    this.batches = const [],
  });

  final String fromMonth;
  final String fromLabel;
  final String toMonth;
  final String toLabel;

  /// Last day of [toMonth] — pre-fill the "valid till" input with this.
  final String? defaultValidTill;

  final int candidates;
  final int selectedByDefault;
  final int alreadyCovered;
  final int alreadyRenewed;

  /// Rupee total if every pre-ticked row is marked collected at its
  /// suggested fee.
  final num feeIfAllCollected;

  final List<CoachRenewalBatchGroup> batches;

  static const CoachRenewalPreview empty = CoachRenewalPreview();

  bool get isEmpty => batches.isEmpty;

  @override
  String toString() =>
      'CoachRenewalPreview($fromMonth → $toMonth, $candidates candidates)';
}

/// One ticked row in the Copy to Next Month commit request.
class CoachRenewItem {
  const CoachRenewItem({
    required this.enrollmentId,
    this.collected = false,
    this.fee,
    this.validTill,
    this.paymentMode,
  });

  final int enrollmentId;

  /// `true` records a fee payment (and coach earnings); `false` extends the
  /// month without money changing hands.
  final bool collected;

  /// Defaults server-side to the batch fee when omitted.
  final num? fee;

  /// `yyyy-MM-dd`. Defaults server-side to the last day of the target month.
  final String? validTill;

  /// `Cash | UPI | Card | BankTransfer | Cheque | Other`. Only meaningful
  /// with [collected].
  final String? paymentMode;

  Map<String, dynamic> toJson() => {
        'enrollmentId': enrollmentId,
        'collected': collected,
        if (fee != null) 'fee': fee,
        if ((validTill ?? '').trim().isNotEmpty) 'validTill': validTill!.trim(),
        if (collected && (paymentMode ?? '').trim().isNotEmpty)
          'paymentMode': paymentMode!.trim(),
      };
}

/// Copy to Next Month, step 2 — the commit request body.
class CoachRenewMonthRequest {
  const CoachRenewMonthRequest({required this.toMonth, required this.items});

  final String toMonth;
  final List<CoachRenewItem> items;

  Map<String, dynamic> toJson() => {
        'toMonth': toMonth,
        'items': items.map((i) => i.toJson()).toList(growable: false),
      };
}

/// One outcome row from a Copy to Next Month commit.
class CoachRenewOutcome {
  const CoachRenewOutcome({
    required this.enrollmentId,
    this.name = '',
    this.reason,
    this.feeCharged = 0,
    this.collected = false,
  });

  final int enrollmentId;
  final String name;

  /// Present on `skipped`/`failed` rows — the server's explanation.
  final String? reason;

  final num feeCharged;
  final bool collected;

  @override
  String toString() => 'CoachRenewOutcome($enrollmentId, $name)';
}

/// The response after committing Copy to Next Month.
class CoachRenewMonthResult {
  const CoachRenewMonthResult({
    this.toMonth = '',
    this.toLabel = '',
    this.validTill,
    this.renewedCount = 0,
    this.skippedCount = 0,
    this.failedCount = 0,
    this.feeCollected = 0,
    this.feePending = 0,
    this.renewed = const [],
    this.skipped = const [],
    this.failed = const [],
    this.message = '',
  });

  final String toMonth;
  final String toLabel;
  final String? validTill;

  final int renewedCount;
  final int skippedCount;
  final int failedCount;
  final num feeCollected;
  final num feePending;

  final List<CoachRenewOutcome> renewed;
  final List<CoachRenewOutcome> skipped;
  final List<CoachRenewOutcome> failed;

  final String message;

  static const CoachRenewMonthResult empty = CoachRenewMonthResult();

  @override
  String toString() =>
      'CoachRenewMonthResult(renewed: $renewedCount, skipped: $skippedCount, '
      'failed: $failedCount)';
}
