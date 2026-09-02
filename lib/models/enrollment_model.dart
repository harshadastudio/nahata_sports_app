/// One row of `GET /students/me/enrollments`.
///
/// The backend fills every text field with `'—'` rather than null when the
/// join is missing, so a blank here means the column really was empty.
class EnrollmentModel {
  const EnrollmentModel({
    this.id,
    this.batchId,
    this.batchName,
    this.sportName,
    this.coachName,
    this.complexName,
    this.enrollmentDate,
    this.validTill,
    this.status,
    this.approvalStatus,
    this.paymentStatus,
    this.isActive = false,
  });

  final int? id;
  final int? batchId;
  final String? batchName;
  final String? sportName;
  final String? coachName;
  final String? complexName;

  /// `YYYY-MM-DD`.
  final String? enrollmentDate;

  /// Per-student validity set by the coach, falling back server-side to the
  /// batch end date. Null means open-ended.
  final String? validTill;

  final String? status;
  final String? approvalStatus;
  final String? paymentStatus;

  /// Computed by the backend: `status == 'Active'` and not past [validTill].
  /// Trusted rather than recomputed, so the app and the console never disagree
  /// about whose clock decides.
  final bool isActive;

  factory EnrollmentModel.fromJson(Map<String, dynamic> json) {
    return EnrollmentModel(
      id: _int(json['id']),
      batchId: _int(json['batchId']),
      batchName: _text(json['batchName']),
      sportName: _text(json['sportName']),
      coachName: _text(json['coachName']),
      complexName: _text(json['complexName']),
      enrollmentDate: _text(json['enrollmentDate']),
      validTill: _text(json['validTill']),
      status: _text(json['status']),
      approvalStatus: _text(json['approvalStatus']),
      paymentStatus: _text(json['paymentStatus']),
      isActive: json['isActive'] == true,
    );
  }

  bool get isApproved => (approvalStatus ?? '').toLowerCase() == 'approved';
  bool get isPending => (approvalStatus ?? '').toLowerCase() == 'pending';
  bool get isPaid => (paymentStatus ?? '').toLowerCase() == 'paid';

  static int? _int(Object? value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '');

  /// Null for the backend's `'—'` placeholder too: a UI that hides a missing
  /// row reads better than one showing an em dash it did not choose.
  static String? _text(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text == 'null' || text == '—') {
      return null;
    }
    return text;
  }
}

/// One row of `GET /fees/my` — an approved enrolment rendered as a gate pass.
///
/// The pass code and the QR image URL are built server-side, so nothing here
/// has to know how a pass code is composed.
class GatePassModel {
  const GatePassModel({
    this.id,
    this.passCode,
    this.qrCode,
    this.studentName,
    this.studentPhone,
    this.bloodGroup,
    this.dob,
    this.batchId,
    this.batchName,
    this.sportName,
    this.sportImage,
    this.coachName,
    this.amountPaid,
    this.batchFee,
    this.paymentStatus,
    this.approvalStatus,
    this.enrollmentDate,
    this.validTill,
    this.approvedAt,
    this.status,
    this.notes,
    this.batchDays,
    this.startTime,
    this.endTime,
  });

  final int? id;

  /// Server-issued, e.g. `NSC-…`. What the gate scanner reads.
  final String? passCode;

  /// Absolute URL of the QR image the backend generated.
  final String? qrCode;

  final String? studentName;
  final String? studentPhone;
  final String? bloodGroup;
  final String? dob;

  final int? batchId;
  final String? batchName;
  final String? sportName;
  final String? sportImage;
  final String? coachName;

  final String? amountPaid;
  final String? batchFee;
  final String? paymentStatus;
  final String? approvalStatus;

  final String? enrollmentDate;
  final String? validTill;
  final String? approvedAt;
  final String? status;
  final String? notes;

  final String? batchDays;
  final String? startTime;
  final String? endTime;

  factory GatePassModel.fromJson(Map<String, dynamic> json) {
    return GatePassModel(
      id: EnrollmentModel._int(json['id']),
      passCode: EnrollmentModel._text(json['passCode']),
      qrCode: EnrollmentModel._text(json['qrCode']),
      studentName: EnrollmentModel._text(json['studentName']),
      studentPhone: EnrollmentModel._text(json['studentPhone']),
      bloodGroup: EnrollmentModel._text(json['bloodGroup']),
      dob: EnrollmentModel._text(json['dob']),
      batchId: EnrollmentModel._int(json['batchId']),
      batchName: EnrollmentModel._text(json['batchName']),
      sportName: EnrollmentModel._text(json['sportName']),
      sportImage: EnrollmentModel._text(json['sportImage']),
      coachName: EnrollmentModel._text(json['coachName']),
      // Fees arrive as numbers or as decimal strings depending on the driver,
      // so they are kept as text and formatted where they are shown.
      amountPaid: EnrollmentModel._text(json['amountPaid']),
      batchFee: EnrollmentModel._text(json['batchFee']),
      paymentStatus: EnrollmentModel._text(json['paymentStatus']),
      approvalStatus: EnrollmentModel._text(json['approvalStatus']),
      enrollmentDate: EnrollmentModel._text(json['enrollmentDate']),
      validTill: EnrollmentModel._text(json['validTill']),
      approvedAt: EnrollmentModel._text(json['approvedAt']),
      status: EnrollmentModel._text(json['status']),
      notes: EnrollmentModel._text(json['notes']),
      batchDays: EnrollmentModel._text(json['batchDays']),
      startTime: EnrollmentModel._text(json['startTime']),
      endTime: EnrollmentModel._text(json['endTime']),
    );
  }

  /// True while [validTill] is today or later. An open-ended pass never
  /// expires, which is what a null validity means on this endpoint.
  bool get isValid {
    final until = validTill;
    if (until == null) return true;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return until.compareTo(today) >= 0;
  }

  /// The card's title: `"Basketball · Regular (Evening)"`, degrading to
  /// whichever half the payload actually carries.
  String get title => [
        if ((sportName ?? '').isNotEmpty) sportName!,
        if ((batchName ?? '').isNotEmpty) batchName!,
      ].join(' · ');

  /// `"Mon, Wed, Fri"` — the API packs the days as `"Mon,Wed,Fri"`.
  String get daysLabel => (batchDays ?? '')
      .split(',')
      .map((d) => d.trim())
      .where((d) => d.isNotEmpty)
      .join(', ');

  /// `"6:00 PM - 7:30 PM"` from the API's 24-hour `"18:00:00"` pair.
  String get sessionLabel {
    final from = _clock(startTime);
    final to = _clock(endTime);
    if (from.isEmpty) return to;
    return to.isEmpty ? from : '$from - $to';
  }

  /// `"06 Nov 2026"` from `"2026-11-06"`.
  String get validTillLabel => _day(validTill);

  String get enrolledOnLabel => _day(enrollmentDate);

  /// A pass is usable at the gate only once it is approved, paid and unexpired
  /// — the three things the guard's scanner checks. Anything short of that
  /// shows as pending rather than as a green "active" the student would rely on
  /// and then be turned away for.
  bool get isUsable =>
      (approvalStatus ?? '').toLowerCase() == 'approved' &&
      (paymentStatus ?? '').toLowerCase() == 'paid' &&
      isValid;

  /// What the badge on the card says.
  String get statusLabel {
    if (isUsable) return 'ACTIVE PASS';
    if (!isValid) return 'EXPIRED';
    final approval = (approvalStatus ?? '').trim();
    if (approval.isNotEmpty && approval.toLowerCase() != 'approved') {
      return approval.toUpperCase();
    }
    final payment = (paymentStatus ?? '').trim();
    if (payment.isNotEmpty && payment.toLowerCase() != 'paid') {
      return 'PAYMENT $payment'.toUpperCase();
    }
    return 'PENDING';
  }

  /// Flat shape the Your Pass card reads.
  ///
  /// `pass_kind` is what tells the card this is a coaching pass rather than a
  /// court booking; the two live in the same list and carry different fields.
  Map<String, dynamic> toPassMap() => <String, dynamic>{
        'pass_kind': 'coaching',
        'booking_id': id?.toString() ?? '',
        'qr_code': qrCode ?? '',
        'pass_code': passCode ?? '',
        'title': title,
        'sport_name': sportName ?? '',
        'sport_image': sportImage ?? '',
        'batch_name': batchName ?? '',
        'coach_name': coachName ?? '',
        'student_name': studentName ?? '',
        'blood_group': bloodGroup ?? '',
        'days_label': daysLabel,
        'session_label': sessionLabel,
        'valid_till': validTillLabel,
        'enrolled_on': enrolledOnLabel,
        'amount_paid': amountPaid ?? '',
        'approval_status': approvalStatus ?? '',
        'payment_status': paymentStatus ?? '',
        'status': status ?? '',
        'is_usable': isUsable,
        'status_label': statusLabel,
      };

  /// `"18:00:00"` → `"6:00 PM"`. Returns empty for anything unparseable so a
  /// malformed time simply drops out of the label.
  static String _clock(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return '';

    final parts = value.split(':');
    final hour = int.tryParse(parts.first);
    if (hour == null || parts.length < 2) return value;
    final minute = int.tryParse(parts[1]) ?? 0;

    final suffix = hour >= 12 ? 'PM' : 'AM';
    final twelve = hour % 12 == 0 ? 12 : hour % 12;
    return '$twelve:${minute.toString().padLeft(2, '0')} $suffix';
  }

  /// `"2026-11-06"` → `"06 Nov 2026"`, or the raw value if it is not a date.
  static String _day(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return '';

    final date = DateTime.tryParse(value);
    if (date == null) return value;

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final day = date.day.toString().padLeft(2, '0');
    return '$day ${months[date.month - 1]} ${date.year}';
  }
}
