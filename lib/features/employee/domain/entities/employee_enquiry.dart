import 'employee_formats.dart';

/// A coaching enquiry in the staff queue, from `GET /coaching-enquiries/all`.
///
/// A prospect submits one publicly; the desk reviews it and, when the batch has
/// room, approves it. **Approving is not a status change** — it creates the
/// student (or reuses their account), enrolls them in the batch and opens a
/// `Pending` fee record, all inside one transaction. That fee then needs its own
/// approval on the Fees Approval screen before the student's gate pass unlocks.
class EmployeeEnquiry {
  const EmployeeEnquiry({
    required this.id,
    this.name = '',
    this.email = '',
    this.phone = '',
    this.batchId,
    this.batchName = '',
    this.batchFees,
    this.batchMaxStudents,
    this.batchCurrentStudents,
    this.sportName = '',
    this.coachName = '',
    this.status = 'Pending',
    this.message,
    this.referenceNumber,
    this.createdAt,
    this.updatedAt,
  });

  final int id;

  /// Resolved from the linked account when the enquiry came from a signed-in
  /// user, else the free-text name the public form captured.
  final String name;
  final String email;
  final String phone;

  final int? batchId;
  final String batchName;
  final num? batchFees;

  /// Null when the row did not carry capacity — which is different from "the
  /// batch has no cap", so [isBatchFull] answers false rather than guessing.
  final int? batchMaxStudents;
  final int? batchCurrentStudents;

  final String sportName;
  final String coachName;

  /// `Pending` | `Reviewed` | `Contacted` | `Approved` | `Rejected`.
  final String status;

  final String? message;
  final String? referenceNumber;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get displayName => name.trim().isEmpty ? 'Enquiry #$id' : name.trim();

  String get initial =>
      displayName.trim().isEmpty ? '?' : displayName.trim()[0].toUpperCase();

  bool get isApproved => status.toLowerCase() == 'approved';
  bool get isRejected => status.toLowerCase() == 'rejected';

  /// Whether Approve & Enroll is still on the table. A settled enquiry is not
  /// re-approvable — the API answers 400.
  bool get isActionable => !isApproved && !isRejected;

  /// True only when the row actually reported both numbers and the batch is at
  /// or over capacity. The API refuses the enrollment in that case, so the
  /// button is disabled rather than left to fail.
  bool get isBatchFull {
    final max = batchMaxStudents;
    final current = batchCurrentStudents;
    if (max == null || current == null) return false;
    return current >= max;
  }

  /// `12/20 enrolled`, or null when capacity is unknown.
  String? get capacityLabel {
    final max = batchMaxStudents;
    final current = batchCurrentStudents;
    if (max == null || current == null) return null;
    return '$current/$max enrolled';
  }

  String? get feesLabel => batchFees == null ? null : formatRupees(batchFees);

  String get submittedLabel => formatDateTime(createdAt);

  EmployeeEnquiry copyWith({String? status, DateTime? updatedAt}) {
    return EmployeeEnquiry(
      id: id,
      name: name,
      email: email,
      phone: phone,
      batchId: batchId,
      batchName: batchName,
      batchFees: batchFees,
      batchMaxStudents: batchMaxStudents,
      batchCurrentStudents: batchCurrentStudents,
      sportName: sportName,
      coachName: coachName,
      status: status ?? this.status,
      message: message,
      referenceNumber: referenceNumber,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'EmployeeEnquiry($id, $displayName, $status)';
}
