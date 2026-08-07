/// Fee records, from `/fees`.
///
/// A "fee record" is a `StudentBatches` row — the same object the enrollments
/// screen groups by month. Everything the fee system does hangs off its
/// payment and approval columns.
///
/// The backend scopes `GET /fees` and `GET /fees/stats` to the coach's own
/// batches automatically, so nothing here has to filter by coach.
///
/// **What a coach may and may not do** (from `feesRoutes.js`):
/// * ✅ read the list and the stats, create a record, edit one, record a
///   payment.
/// * ❌ approve, reject or delete — those are ADMIN / COMPLEX_ADMIN / EMPLOYEE
///   only and answer 403 for a coach.
library;

/// How much of the fee has been collected.
enum CoachPaymentStatus {
  pending('Pending'),
  paid('Paid'),
  partial('Partial'),
  overdue('Overdue');

  const CoachPaymentStatus(this.slug);

  final String slug;

  String get label => slug;

  /// The four a coach may set through `PATCH /fees/{id}/payment`.
  static const List<CoachPaymentStatus> settable = CoachPaymentStatus.values;

  static CoachPaymentStatus? tryParse(String? value) {
    final text = (value ?? '').trim().toLowerCase();
    if (text.isEmpty) return null;
    for (final status in CoachPaymentStatus.values) {
      if (status.slug.toLowerCase() == text) return status;
    }
    return null;
  }
}

/// Whether an admin has signed the payment off.
///
/// This is what actually unlocks the student's gate pass — a fee marked `Paid`
/// by a coach is still `Pending` approval until an admin or employee approves
/// it. A coach can never move this themselves.
enum CoachApprovalStatus {
  pending('Pending'),
  approved('Approved'),
  rejected('Rejected');

  const CoachApprovalStatus(this.slug);

  final String slug;

  String get label => slug;

  static CoachApprovalStatus? tryParse(String? value) {
    final text = (value ?? '').trim().toLowerCase();
    if (text.isEmpty) return null;
    for (final status in CoachApprovalStatus.values) {
      if (status.slug.toLowerCase() == text) return status;
    }
    return null;
  }
}

/// How the money came in.
enum CoachPaymentMode {
  cash('Cash'),
  upi('UPI'),
  card('Card'),
  bankTransfer('BankTransfer', 'Bank transfer'),
  cheque('Cheque'),
  other('Other');

  const CoachPaymentMode(this.slug, [String? label]) : _label = label;

  /// The wire value — the backend's ENUM is case-sensitive, and note that
  /// bank transfer is one word on the wire.
  final String slug;

  final String? _label;

  String get label => _label ?? slug;

  static CoachPaymentMode? tryParse(String? value) {
    final text = (value ?? '').trim().toLowerCase();
    if (text.isEmpty) return null;
    for (final mode in CoachPaymentMode.values) {
      if (mode.slug.toLowerCase() == text) return mode;
    }
    return null;
  }
}

/// One fee record.
class CoachFee {
  const CoachFee({
    required this.id,
    this.studentId = 0,
    this.studentName = '',
    this.studentPhone = '',
    this.batchId = 0,
    this.batchName = '',
    this.sportName,
    this.enrollmentDate,
    this.validTill,
    this.enrollmentStatusRaw,
    this.paymentStatusRaw,
    this.approvalStatusRaw,
    this.paymentModeRaw,
    this.amountPaid = 0,
    this.batchFees,
    this.notes,
    this.approvedAt,
  });

  /// The `StudentBatches` row id — what every write route takes.
  final int id;

  final int studentId;
  final String studentName;
  final String studentPhone;

  final int batchId;
  final String batchName;
  final String? sportName;

  /// `yyyy-MM-dd`.
  final String? enrollmentDate;

  /// How long this student's enrollment stays valid. Falls back to the batch
  /// end date server-side when null.
  final String? validTill;

  final String? enrollmentStatusRaw;
  final String? paymentStatusRaw;
  final String? approvalStatusRaw;
  final String? paymentModeRaw;

  final num amountPaid;

  /// The batch's own fee, for comparison against [amountPaid]. `null` when the
  /// batch has none set — distinct from a fee of zero.
  final num? batchFees;

  final String? notes;
  final DateTime? approvedAt;

  CoachPaymentStatus? get paymentStatus =>
      CoachPaymentStatus.tryParse(paymentStatusRaw);

  CoachApprovalStatus? get approvalStatus =>
      CoachApprovalStatus.tryParse(approvalStatusRaw);

  CoachPaymentMode? get paymentMode =>
      CoachPaymentMode.tryParse(paymentModeRaw);

  /// Falls back to the raw string so an unmapped value is still shown.
  String get paymentLabel =>
      paymentStatus?.label ?? (paymentStatusRaw ?? '').trim();

  String get approvalLabel =>
      approvalStatus?.label ?? (approvalStatusRaw ?? '').trim();

  String get enrollmentStatusLabel => (enrollmentStatusRaw ?? '').trim();

  bool get isPaid => paymentStatus == CoachPaymentStatus.paid;
  bool get isOverdue => paymentStatus == CoachPaymentStatus.overdue;
  bool get isPartial => paymentStatus == CoachPaymentStatus.partial;

  bool get isApproved => approvalStatus == CoachApprovalStatus.approved;
  bool get isRejected => approvalStatus == CoachApprovalStatus.rejected;
  bool get awaitingApproval => approvalStatus == CoachApprovalStatus.pending;

  /// Collected in full but still not signed off — the state a coach most needs
  /// to see, because the student's gate pass will not work yet.
  bool get paidButUnapproved => isPaid && awaitingApproval;

  String get displayName =>
      studentName.trim().isEmpty ? 'Unknown' : studentName.trim();

  String get initial => displayName.substring(0, 1).toUpperCase();

  /// What is still owed, or `null` when the batch has no fee to compare
  /// against.
  num? get outstanding {
    final total = batchFees;
    if (total == null) return null;
    final due = total - amountPaid;
    return due > 0 ? due : 0;
  }

  /// `"₹1200 / ₹1500"`, or just what was paid when there is nothing to
  /// compare against.
  String get amountLabel {
    final total = batchFees;
    if (total == null) return '₹${amountPaid.round()}';
    return '₹${amountPaid.round()} / ₹${total.round()}';
  }

  /// `"Badminton · Evening Batch"`, skipping whichever part is missing.
  String get contextLabel => [
        if ((sportName ?? '').trim().isNotEmpty) sportName!.trim(),
        if (batchName.trim().isNotEmpty) batchName.trim(),
      ].join(' · ');

  @override
  String toString() =>
      'CoachFee($id, $studentName, $paymentLabel/$approvalLabel)';
}

/// The counters above the fee list. Scoped to the coach's own batches by the
/// backend, so they always match the rows below them.
class CoachFeeStats {
  const CoachFeeStats({
    this.total = 0,
    this.paid = 0,
    this.unpaid = 0,
    this.overdue = 0,
    this.pendingApproval = 0,
  });

  final int total;
  final int paid;

  /// Counts `paymentStatus == 'Pending'` only — `Partial` is in neither
  /// [paid] nor [unpaid], which is why these do not add up to [total].
  final int unpaid;

  final int overdue;

  /// Records awaiting an admin's sign-off. This is the Fees Approval queue.
  final int pendingApproval;

  static const CoachFeeStats empty = CoachFeeStats();

  bool get isEmpty => total == 0;

  @override
  String toString() =>
      'CoachFeeStats(total: $total, paid: $paid, pending approval: '
      '$pendingApproval)';
}

/// A payment a coach is recording against a fee record.
///
/// ⚠️ **Recording a payment as a coach always resets `approvalStatus` to
/// `Pending`** and stamps the coach as `receivedBy`. That is deliberate
/// server-side: collecting the money is not the same as approving it, and the
/// student's gate pass stays locked until an admin signs off. It also re-queues
/// a record that had been `Rejected`.
class CoachPaymentDraft {
  const CoachPaymentDraft({
    this.paymentStatus,
    this.amountPaid,
    this.paymentMode,
    this.notes,
  });

  final CoachPaymentStatus? paymentStatus;
  final num? amountPaid;
  final CoachPaymentMode? paymentMode;
  final String? notes;

  /// Notes are sent whenever non-null, empty string included, because
  /// clearing them is a legitimate edit.
  Map<String, dynamic> toJson() => {
        if (paymentStatus != null) 'paymentStatus': paymentStatus!.slug,
        if (amountPaid != null) 'amountPaid': amountPaid,
        if (paymentMode != null) 'paymentMode': paymentMode!.slug,
        if (notes != null) 'notes': notes!.trim(),
      };

  bool get isEmpty => toJson().isEmpty;

  @override
  String toString() =>
      'CoachPaymentDraft(${paymentStatus?.slug}, $amountPaid, '
      '${paymentMode?.slug})';
}
