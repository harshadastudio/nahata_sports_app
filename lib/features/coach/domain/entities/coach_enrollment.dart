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
