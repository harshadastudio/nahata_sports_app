/// Coaching enquiries as a coach sees them.
///
/// Routes: `GET /coaching-enquiries/coach/my-enquiries`,
/// `POST /coaching-enquiries/coach/create`,
/// `PATCH /coaching-enquiries/coach/{id}/status`,
/// `DELETE /coaching-enquiries/coach/{id}`.
///
/// A coach only ever sees enquiries assigned to them: every write re-checks
/// `enquiry.coachId == coach.id` and answers 403 otherwise.
library;

/// The enquiry lifecycle.
///
/// A coach may only move an enquiry to [pending], [reviewed], [contacted] or
/// [rejected] — see [CoachEnquiryStatus.coachSettable]. [approved] is reachable
/// by an admin only, so the app must not offer it; the backend rejects it with
/// a 400.
enum CoachEnquiryStatus {
  pending('Pending'),
  reviewed('Reviewed'),
  contacted('Contacted'),
  approved('Approved'),
  rejected('Rejected');

  const CoachEnquiryStatus(this.slug);

  /// The wire value. Case matters — the backend compares against this exact
  /// spelling.
  final String slug;

  String get label => slug;

  /// The four a coach is allowed to set.
  static const List<CoachEnquiryStatus> coachSettable = [
    CoachEnquiryStatus.pending,
    CoachEnquiryStatus.reviewed,
    CoachEnquiryStatus.contacted,
    CoachEnquiryStatus.rejected,
  ];

  bool get isCoachSettable => coachSettable.contains(this);

  static CoachEnquiryStatus? tryParse(String? value) {
    final text = (value ?? '').trim().toLowerCase();
    if (text.isEmpty) return null;
    for (final status in CoachEnquiryStatus.values) {
      if (status.slug.toLowerCase() == text) return status;
    }
    return null;
  }
}

/// One enquiry on the coach's desk.
class CoachEnquiry {
  const CoachEnquiry({
    required this.id,
    this.referenceNumber,
    this.name = '',
    this.email = '',
    this.phone = '',
    this.message,
    this.statusRaw,
    this.sportName,
    this.batchName,
    this.createdAt,
  });

  final int id;

  /// e.g. `NSC-20260729-F0DAK`. Generated server-side on create.
  final String? referenceNumber;

  /// The prospective student's details — these are the enquiry's own columns,
  /// not the logged-in coach's account.
  final String name;
  final String email;
  final String phone;

  final String? message;
  final String? statusRaw;
  final String? sportName;
  final String? batchName;
  final DateTime? createdAt;

  CoachEnquiryStatus? get status => CoachEnquiryStatus.tryParse(statusRaw);

  /// Falls back to the raw string so an unmapped status is still shown rather
  /// than silently blank.
  String get statusLabel => status?.label ?? (statusRaw ?? '').trim();

  /// Still needs the coach's attention.
  bool get isOpen {
    final current = status;
    return current == null ||
        current == CoachEnquiryStatus.pending ||
        current == CoachEnquiryStatus.reviewed ||
        current == CoachEnquiryStatus.contacted;
  }

  String get displayName => name.trim().isEmpty ? 'Unknown' : name.trim();

  String get initial => displayName.substring(0, 1).toUpperCase();

  /// `"9876543210 · riya@example.com"`, skipping whichever part is missing.
  String get contactLabel => [
        if (phone.trim().isNotEmpty) phone.trim(),
        if (email.trim().isNotEmpty) email.trim(),
      ].join(' · ');

  /// `"Badminton · Evening Batch"`, skipping whichever part is missing.
  String get contextLabel => [
        if ((sportName ?? '').trim().isNotEmpty) sportName!.trim(),
        if ((batchName ?? '').trim().isNotEmpty) batchName!.trim(),
      ].join(' · ');

  CoachEnquiry copyWith({String? statusRaw}) => CoachEnquiry(
        id: id,
        referenceNumber: referenceNumber,
        name: name,
        email: email,
        phone: phone,
        message: message,
        statusRaw: statusRaw ?? this.statusRaw,
        sportName: sportName,
        batchName: batchName,
        createdAt: createdAt,
      );

  @override
  String toString() => 'CoachEnquiry($id, $name, $statusLabel)';
}

/// A new enquiry a coach is logging on a prospect's behalf.
///
/// The backend requires `batchId`, `name`, `email` and `phone`; `sportId` and
/// `message` are optional. `coachId` is deliberately not sent — the backend
/// stamps the enquiry with the coach resolved from the token, and sending one
/// would only let a coach file against someone else.
class CoachEnquiryDraft {
  const CoachEnquiryDraft({
    required this.name,
    required this.email,
    required this.phone,
    required this.batchId,
    this.sportId,
    this.message,
  });

  final String name;
  final String email;
  final String phone;
  final int batchId;
  final int? sportId;
  final String? message;

  /// Digits only, capped at 10 — the website enforces exactly 10 before it
  /// will submit, and the same rule is applied here so the two agree.
  String get normalisedPhone {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return digits.length > 10 ? digits.substring(0, 10) : digits;
  }

  Map<String, dynamic> toJson() => {
        'name': name.trim(),
        'email': email.trim(),
        'phone': normalisedPhone,
        'batchId': batchId,
        if (sportId != null && sportId! > 0) 'sportId': sportId,
        if ((message ?? '').trim().isNotEmpty) 'message': message!.trim(),
      };

  @override
  String toString() => 'CoachEnquiryDraft($name, batch: $batchId)';
}
