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
    this.sportId,
    this.sportName = '',
    this.coachId,
    this.coachName = '',
    this.isAllSports = false,
    this.status = 'Pending',
    this.message,
    this.referenceNumber,
    this.enrolments = const [],
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

  /// Carried so the edit form can preselect the dropdowns. Both are derived
  /// from the batch server-side when the create body omits them, so a row can
  /// have a sport and coach without the form ever having sent one.
  final int? sportId;
  final String sportName;

  final int? coachId;
  final String coachName;

  /// An "All Sports" enquiry: the prospect has not chosen a sport yet, so it
  /// has no batch and reaches every sports coach in the complex. Approving one
  /// enrols into the *calling* coach's own batch and leaves the enquiry open
  /// for the others, so it is not settled by the first approval.
  final bool isAllSports;

  /// `Pending` | `Reviewed` | `Contacted` | `Approved` | `Rejected`.
  final String status;

  final String? message;
  final String? referenceNumber;

  /// Every batch this prospect is *actually* enrolled in — not what the enquiry
  /// asked for. A student may train under several coaches across several
  /// sports, and an All Sports enquiry collects one entry per coach that
  /// enrolled them, so this is a list rather than a single record.
  ///
  /// Empty is the normal state for an enquiry nobody has approved yet.
  final List<EmployeeEnquiryEnrolment> enrolments;

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
      sportId: sportId,
      sportName: sportName,
      coachId: coachId,
      coachName: coachName,
      isAllSports: isAllSports,
      status: status ?? this.status,
      message: message,
      referenceNumber: referenceNumber,
      enrolments: enrolments,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Whether `PUT /coaching-enquiries/admin/{id}` will accept an edit.
  ///
  /// The API answers 400 once the enquiry is Approved — the enrolment already
  /// exists by then, and editing the enquiry would not move it — so the edit
  /// action is hidden rather than left to fail.
  bool get isEditable => !isApproved;

  /// The sport line for a row, which for an All Sports enquiry is a label
  /// rather than a name: there is no sport on the record to show.
  String get sportLabel {
    if (isAllSports) return 'All sports';
    return sportName;
  }

  @override
  String toString() => 'EmployeeEnquiry($id, $displayName, $status)';

  /// The statuses `PATCH /coaching-enquiries/{id}/status` accepts.
  ///
  /// `Approved` is deliberately absent: approving is done by
  /// `POST /coaching-enquiries/{id}/approve-and-enroll`, which also creates the
  /// student and the fee record. Setting the status alone would mark the
  /// enquiry done without enrolling anyone.
  static const List<String> settableStatuses = [
    'Pending',
    'Reviewed',
    'Contacted',
    'Rejected',
  ];
}

/// The create/edit form behind `POST /coaching-enquiries/admin/create` and
/// `PUT /coaching-enquiries/admin/{id}` — a walk-in enquiry typed at the desk.
///
/// `sportId` and `coachId` are optional on the wire: the backend derives both
/// from the batch when they are omitted, and moving an enquiry to another batch
/// re-derives them along with the complex. They are still sent when the form
/// has them so the dropdowns and the stored row cannot drift apart.
class EmployeeEnquiryDraft {
  const EmployeeEnquiryDraft({
    this.name = '',
    this.email = '',
    this.phone = '',
    this.sportId,
    this.batchId,
    this.coachId,
    this.message,
    this.isAllSports = false,
  });

  final String name;
  final String email;
  final String phone;

  final int? sportId;
  final int? batchId;
  final int? coachId;

  final String? message;

  /// When true the enquiry carries no sport, batch or coach and reaches every
  /// sports coach in the complex.
  final bool isAllSports;

  /// The server's rule: name, email and phone are always required, and a batch
  /// is required *unless* this is an All Sports enquiry.
  String? get validationError {
    if (name.trim().isEmpty) return 'Enter the name.';

    final address = email.trim();
    if (address.isEmpty) return 'Enter an email address.';
    if (!RegExp(r'^[^@\s]+@[^@\s.]+\.[^@\s]+$').hasMatch(address)) {
      return 'Enter a valid email address.';
    }

    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) return 'Enter a 10-digit phone number.';

    if (!isAllSports && (batchId == null || batchId! <= 0)) {
      return 'Choose a batch, or mark this as an all-sports enquiry.';
    }

    return null;
  }

  Map<String, dynamic> toJson() {
    final body = <String, dynamic>{
      'name': name.trim(),
      'email': email.trim(),
      'phone': phone.replaceAll(RegExp(r'\D'), ''),
    };

    if (isAllSports) {
      // An All Sports enquiry must carry no sport, batch or coach — sending one
      // alongside the flag would contradict it.
      body['isAllSports'] = true;
    } else {
      if (batchId != null && batchId! > 0) body['batchId'] = batchId;
      if (sportId != null && sportId! > 0) body['sportId'] = sportId;
      if (coachId != null && coachId! > 0) body['coachId'] = coachId;
    }

    final note = message?.trim();
    if (note != null && note.isNotEmpty) body['message'] = note;

    return body;
  }

  /// Seeds the edit form from an enquiry already on screen.
  factory EmployeeEnquiryDraft.from(EmployeeEnquiry enquiry) {
    return EmployeeEnquiryDraft(
      name: enquiry.name,
      email: enquiry.email,
      phone: enquiry.phone,
      sportId: enquiry.sportId,
      batchId: enquiry.batchId,
      coachId: enquiry.coachId,
      message: enquiry.message,
      isAllSports: enquiry.isAllSports,
    );
  }
}

/// The body of `POST /coaching-enquiries/{id}/approve-and-enroll`.
///
/// Every field is optional — the route defaults the fee record it opens to
/// `Pending` / `0` when nothing is sent, which is what the plain "Approve"
/// action uses. The form exists for the desk that collects the first
/// instalment at the same time as enrolling.
class EmployeeEnquiryApprovalDraft {
  const EmployeeEnquiryApprovalDraft({
    this.paymentStatus = 'Pending',
    this.amountPaid = 0,
    this.notes,
  });

  /// `Pending` | `Partial` | `Paid`.
  final String paymentStatus;
  final num amountPaid;
  final String? notes;

  static const List<String> paymentStatuses = ['Pending', 'Partial', 'Paid'];

  /// The default the plain Approve button sends: a `Pending` fee of zero, which
  /// matches what the route does with no body at all.
  static const EmployeeEnquiryApprovalDraft pending =
      EmployeeEnquiryApprovalDraft();

  Map<String, dynamic> toJson() {
    final note = notes?.trim();
    return <String, dynamic>{
      'paymentStatus': paymentStatus,
      'amountPaid': amountPaid,
      'notes': note == null ? '' : note,
    };
  }
}

/// One batch a prospect is enrolled in, from the `enrolments[]` array every
/// listed enquiry carries.
///
/// This is a *result*, not a request: the enquiry names the batch that was
/// asked for, while these name the batches the student ended up training in.
/// The two differ whenever an All Sports enquiry was approved by more than one
/// coach — each approval enrols into that coach's own batch and leaves the
/// enquiry open for the rest.
class EmployeeEnquiryEnrolment {
  const EmployeeEnquiryEnrolment({
    this.id,
    this.batchName = '',
    this.sportName = '',
    this.coachName = '',
    this.status = '',
  });

  /// Null on a payload that only named the batch — the row is still worth
  /// showing, so an absent id does not drop it.
  final int? id;

  final String batchName;
  final String sportName;
  final String coachName;

  /// The enrolment's own status (`Active`, `Completed`, …), which is not the
  /// enquiry's.
  final String status;

  String get displayBatch =>
      batchName.trim().isEmpty ? 'Batch' : batchName.trim();

  /// `Badminton · Coach Rao`, or whichever half actually arrived.
  String get detailLabel => [
        if (sportName.trim().isNotEmpty) sportName.trim(),
        if (coachName.trim().isNotEmpty) coachName.trim(),
      ].join(' · ');

  @override
  String toString() => 'EmployeeEnquiryEnrolment($displayBatch, $status)';
}

/// What `POST /coaching-enquiries/admin/create` answers with.
///
/// Creating an enquiry also **registers the student**: the route creates a User
/// and a Student when the email is new and emails them their login. The desk
/// needs to know which of the two happened — telling a walk-in to check their
/// inbox for credentials that were never sent is worse than saying nothing.
class EmployeeEnquiryCreateResult {
  const EmployeeEnquiryCreateResult({
    this.enquiryId,
    this.userId,
    this.studentId,
    this.isNewAccount = false,
  });

  final int? enquiryId;

  /// From `studentAccount`. Both are null when the response did not carry the
  /// block — an older build of the API, and not a failure.
  final int? userId;
  final int? studentId;

  /// True when this enquiry created the account, so credentials were emailed.
  final bool isNewAccount;

  /// The line to show after a successful create.
  String get message => isNewAccount
      ? 'Enquiry added — login details were emailed to the student.'
      : 'Enquiry added';

  @override
  String toString() =>
      'EmployeeEnquiryCreateResult($enquiryId, new=$isNewAccount)';
}
