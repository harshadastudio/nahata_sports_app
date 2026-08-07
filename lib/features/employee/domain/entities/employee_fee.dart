import 'employee_formats.dart';

/// A student fee record, from `GET /fees`.
///
/// Two employee screens read this same row for different jobs:
///
/// * **Fees Approval** — a coach collected money and recorded it; the desk
///   approves or rejects. Approving is what unlocks the student's gate pass,
///   which is why it is an ADMIN/COMPLEX_ADMIN/EMPLOYEE route and not a coach
///   one.
/// * **Fees Management** — creating, correcting and deleting the record itself.
///   Gated separately on `employee_fees_management`, so an admin can grant one
///   without the other.
///
/// The two statuses are independent: [paymentStatus] is how much has been
/// collected, [approvalStatus] is whether the desk has signed it off.
class EmployeeFee {
  const EmployeeFee({
    required this.id,
    this.studentId = 0,
    this.batchId = 0,
    this.studentName = '',
    this.studentPhone = '',
    this.studentEmail = '',
    this.batchName = '',
    this.sportName = '',
    this.batchFees,
    this.amountPaid = 0,
    this.paymentStatus = 'Pending',
    this.approvalStatus = 'Pending',
    this.paymentMode,
    this.enrollmentDate,
    this.notes,
  });

  final int id;
  final int studentId;
  final int batchId;

  final String studentName;
  final String studentPhone;
  final String studentEmail;

  final String batchName;
  final String sportName;

  /// What the batch costs. Null when the join found nothing — different from a
  /// batch that is genuinely free.
  final num? batchFees;

  final num amountPaid;

  /// `Pending` | `Paid` | `Partial` | `Overdue`.
  final String paymentStatus;

  /// `Pending` | `Approved` | `Rejected`.
  final String approvalStatus;

  final String? paymentMode;

  /// `DATEONLY` on the wire.
  final DateTime? enrollmentDate;

  final String? notes;

  String get displayName =>
      studentName.trim().isEmpty ? 'Student #$studentId' : studentName.trim();

  String get initial =>
      displayName.trim().isEmpty ? '?' : displayName.trim()[0].toUpperCase();

  String get displayBatch =>
      batchName.trim().isEmpty ? 'Batch #$batchId' : batchName.trim();

  bool get isApproved => approvalStatus.toLowerCase() == 'approved';
  bool get isRejected => approvalStatus.toLowerCase() == 'rejected';

  /// Whether Approve / Reject are still on the table.
  bool get isAwaitingApproval => !isApproved && !isRejected;

  String get paidLabel => formatRupees(amountPaid);
  String? get batchFeesLabel =>
      batchFees == null ? null : formatRupees(batchFees);

  /// `₹1,500 / ₹2,000` when the batch fee is known, else just what was paid.
  String get amountLabel {
    final full = batchFeesLabel;
    return full == null ? paidLabel : '$paidLabel / $full';
  }

  String get enrolledLabel => formatDay(enrollmentDate);

  /// The gate-pass code the website prints on the WhatsApp message and the QR
  /// preview. Derived, not stored — it is a function of the record id and the
  /// current year, exactly as `FeesApproval.tsx` builds it.
  String get gatePassCode =>
      'GATEPASS-${DateTime.now().year}-${id.toString().padLeft(6, '0')}';

  EmployeeFee copyWith({String? approvalStatus}) {
    return EmployeeFee(
      id: id,
      studentId: studentId,
      batchId: batchId,
      studentName: studentName,
      studentPhone: studentPhone,
      studentEmail: studentEmail,
      batchName: batchName,
      sportName: sportName,
      batchFees: batchFees,
      amountPaid: amountPaid,
      paymentStatus: paymentStatus,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      paymentMode: paymentMode,
      enrollmentDate: enrollmentDate,
      notes: notes,
    );
  }

  @override
  String toString() => 'EmployeeFee($id, $displayName, $approvalStatus)';
}

/// The counters above the approval queue, from `GET /fees/stats`.
class EmployeeFeeStats {
  const EmployeeFeeStats({
    this.total = 0,
    this.paid = 0,
    this.unpaid = 0,
    this.pendingApproval = 0,
  });

  /// Fee records in total — the website labels this "Total Students", which is
  /// only the same number when each student holds exactly one record.
  final int total;

  final int paid;
  final int unpaid;

  /// Records waiting on someone at the desk. The number the queue exists for.
  final int pendingApproval;

  static const EmployeeFeeStats empty = EmployeeFeeStats();

  @override
  String toString() =>
      'EmployeeFeeStats(pending: $pendingApproval, paid: $paid, total: $total)';
}

/// The fields Fees Management writes. Create needs all of them; an edit sends
/// only the three the API accepts on `PUT /fees/{id}`.
class EmployeeFeeDraft {
  const EmployeeFeeDraft({
    this.studentId,
    this.batchId,
    this.amountPaid = 0,
    this.paymentStatus = 'Pending',
    this.enrollmentDate,
    this.notes,
  });

  final int? studentId;
  final int? batchId;
  final num amountPaid;
  final String paymentStatus;
  final DateTime? enrollmentDate;
  final String? notes;

  /// The create body. `studentId` and `batchId` are what make the record, so
  /// they are only sent on create — the API ignores them on update.
  Map<String, dynamic> toCreateBody() => {
        'studentId': studentId,
        'batchId': batchId,
        'amountPaid': amountPaid,
        'paymentStatus': paymentStatus,
        'enrollmentDate':
            formatIsoDate(enrollmentDate ?? DateTime.now()),
        'notes': (notes ?? '').trim().isEmpty ? null : notes!.trim(),
      };

  Map<String, dynamic> toUpdateBody() => {
        'amountPaid': amountPaid,
        'paymentStatus': paymentStatus,
        'notes': (notes ?? '').trim().isEmpty ? null : notes!.trim(),
      };
}
