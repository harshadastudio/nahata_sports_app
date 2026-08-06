/// Where a coaching enquiry sits in its follow-up.
///
/// The five values the module documents, in the order the desk works through
/// them. [slug] is sent verbatim — the status route matches on it.
enum CoachingEnquiryStatus {
  isNew('New'),
  contacted('Contacted'),
  interested('Interested'),
  joined('Joined'),
  closed('Closed');

  const CoachingEnquiryStatus(this.slug);

  /// The exact string the API expects, and how it reads in the UI.
  final String slug;

  String get label => slug;

  /// True once the enquiry needs no further chasing.
  bool get isSettled =>
      this == CoachingEnquiryStatus.joined ||
      this == CoachingEnquiryStatus.closed;

  /// How far through the follow-up this is, for the timeline.
  int get step => index;

  static CoachingEnquiryStatus? tryParse(Object? value) {
    if (value == null) return null;
    final normalised = value.toString().trim().toLowerCase().replaceAll(
      RegExp(r'[\s\-]+'),
      '_',
    );
    if (normalised.isEmpty) return null;

    for (final status in CoachingEnquiryStatus.values) {
      if (status.slug.toLowerCase() == normalised) return status;
    }

    // Spellings other parts of this backend use for the same states — the
    // coach dashboard's own enquiry list says "Converted", and the live
    // enquiries card says "Pending".
    switch (normalised) {
      case 'pending':
      case 'open':
        return CoachingEnquiryStatus.isNew;
      case 'converted':
      case 'enrolled':
      case 'admitted':
        return CoachingEnquiryStatus.joined;
      case 'rejected':
      case 'cancelled':
      case 'canceled':
      case 'lost':
        return CoachingEnquiryStatus.closed;
      case 'following_up':
      case 'in_progress':
        return CoachingEnquiryStatus.contacted;
    }
    return null;
  }

  /// The status as it should be shown, falling back to the server's own text
  /// so an unrecognised value is never dropped.
  static String labelFor(String? raw) {
    final parsed = tryParse(raw);
    if (parsed != null) return parsed.label;
    final text = (raw ?? '').trim();
    if (text.isEmpty) return '';
    return text[0].toUpperCase() + text.substring(1);
  }
}

/// A coaching enquiry (`/coaching-enquiries`).
///
/// One class serves the list and the detail screen: the list route sends a
/// subset, and the fields it omits simply stay null until the detail call
/// fills them in — rather than a second near-identical type that the two
/// screens would have to convert between.
class CoachingEnquiry {
  const CoachingEnquiry({
    required this.id,
    this.referenceNumber,
    this.name,
    this.phone,
    this.email,
    this.message,
    this.statusRaw,
    this.remarks,
    this.sportId,
    this.sportName,
    this.sportComplexId,
    this.sportComplexName,
    this.assignedCoachId,
    this.assignedCoachName,
    this.batchId,
    this.batchName,
    this.createdAt,
    this.updatedAt,
    this.raw = const {},
  });

  final int id;

  /// e.g. `NSC-20260729-F0DAK`, when the backend issues one.
  final String? referenceNumber;

  final String? name;
  final String? phone;
  final String? email;
  final String? message;

  final String? statusRaw;

  /// The desk's own notes, set through the update route.
  final String? remarks;

  final int? sportId;
  final String? sportName;

  final int? sportComplexId;
  final String? sportComplexName;

  final int? assignedCoachId;
  final String? assignedCoachName;

  final int? batchId;
  final String? batchName;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// The untouched row, so the detail panel can show a field the mapper has no
  /// name for yet rather than dropping it.
  final Map<String, dynamic> raw;

  CoachingEnquiryStatus? get status =>
      CoachingEnquiryStatus.tryParse(statusRaw);

  String get statusLabel => CoachingEnquiryStatus.labelFor(statusRaw);

  bool get isAssigned => assignedCoachId != null;

  bool get hasRemarks => (remarks ?? '').trim().isNotEmpty;

  String get displayName {
    final trimmed = (name ?? '').trim();
    if (trimmed.isNotEmpty) return trimmed;
    final mail = (email ?? '').trim();
    if (mail.isNotEmpty) return mail;
    return 'Enquiry $id';
  }

  String get initials {
    final parts = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  /// "Badminton at Kothrud Arena" — what the enquiry is actually about.
  String get interestLabel {
    final sport = (sportName ?? '').trim();
    final venue = (sportComplexName ?? '').trim();
    if (sport.isEmpty && venue.isEmpty) return '';
    if (venue.isEmpty) return sport;
    if (sport.isEmpty) return venue;
    return '$sport at $venue';
  }

  CoachingEnquiry copyWith({
    int? id,
    String? referenceNumber,
    String? name,
    String? phone,
    String? email,
    String? message,
    String? statusRaw,
    String? remarks,
    int? sportId,
    String? sportName,
    int? sportComplexId,
    String? sportComplexName,
    int? assignedCoachId,
    String? assignedCoachName,
    int? batchId,
    String? batchName,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? raw,
  }) {
    return CoachingEnquiry(
      id: id ?? this.id,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      message: message ?? this.message,
      statusRaw: statusRaw ?? this.statusRaw,
      remarks: remarks ?? this.remarks,
      sportId: sportId ?? this.sportId,
      sportName: sportName ?? this.sportName,
      sportComplexId: sportComplexId ?? this.sportComplexId,
      sportComplexName: sportComplexName ?? this.sportComplexName,
      assignedCoachId: assignedCoachId ?? this.assignedCoachId,
      assignedCoachName: assignedCoachName ?? this.assignedCoachName,
      batchId: batchId ?? this.batchId,
      batchName: batchName ?? this.batchName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      raw: raw ?? this.raw,
    );
  }

  @override
  String toString() =>
      'CoachingEnquiry($id, $name, ${sportName ?? '-'}, $statusRaw, '
      'coach: ${assignedCoachName ?? '-'})';
}

/// The create payload for `POST /coaching-enquiries`.
class CoachingEnquiryDraft {
  const CoachingEnquiryDraft({
    required this.name,
    required this.phone,
    required this.email,
    required this.sportId,
    required this.sportComplexId,
    required this.message,
  });

  final String name;
  final String phone;
  final String email;
  final int? sportId;
  final int? sportComplexId;
  final String message;

  /// Digits only — the field accepts formatting while typing, and the backend
  /// wants ten digits.
  String get normalisedPhone => phone.replaceAll(RegExp(r'\D'), '');

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name.trim(),
      'phone': normalisedPhone,
      'email': email.trim(),
      'sportId': sportId,
      'sportComplexId': sportComplexId,
      'message': message.trim(),
    };
  }
}

/// The update payload for `PUT /coaching-enquiries/{id}` — status and remarks,
/// the two things the desk edits together.
class CoachingEnquiryUpdate {
  const CoachingEnquiryUpdate({this.status, this.remarks});

  final CoachingEnquiryStatus? status;
  final String? remarks;

  /// Only what was touched, so an edit never blanks the other field.
  ///
  /// A deliberately emptied remarks box is the exception: an empty string is
  /// sent, because clearing a note is a real edit that `put`-style skipping
  /// would silently discard.
  Map<String, dynamic> toJson() {
    final body = <String, dynamic>{};
    if (status != null) body['status'] = status!.slug;
    if (remarks != null) body['remarks'] = remarks!.trim();
    return body;
  }

  bool get isEmpty => toJson().isEmpty;
}

/// The counters behind the dashboard cards (`GET /coaching-enquiries/stats`).
class CoachingEnquiryStats {
  const CoachingEnquiryStats({
    this.total,
    this.newCount,
    this.contacted,
    this.interested,
    this.joined,
    this.closed,
    this.raw = const {},
  });

  final int? total;
  final int? newCount;
  final int? contacted;
  final int? interested;
  final int? joined;
  final int? closed;

  final Map<String, dynamic> raw;

  /// The total the API sent, or the sum of the states when it sent none.
  int? get effectiveTotal {
    if (total != null) return total;
    final parts = [
      newCount,
      contacted,
      interested,
      joined,
      closed,
    ].whereType<int>().toList();
    if (parts.isEmpty) return null;
    return parts.reduce((sum, value) => sum + value);
  }

  int? countOf(CoachingEnquiryStatus status) {
    switch (status) {
      case CoachingEnquiryStatus.isNew:
        return newCount;
      case CoachingEnquiryStatus.contacted:
        return contacted;
      case CoachingEnquiryStatus.interested:
        return interested;
      case CoachingEnquiryStatus.joined:
        return joined;
      case CoachingEnquiryStatus.closed:
        return closed;
    }
  }

  /// This state's share of the total, for the meter on the card. Null when
  /// there is nothing to take a share of.
  double? shareOf(CoachingEnquiryStatus status) {
    final count = countOf(status);
    final all = effectiveTotal;
    if (count == null || all == null || all <= 0) return null;
    return (count / all).clamp(0, 1).toDouble();
  }

  bool get isEmpty =>
      total == null &&
      newCount == null &&
      contacted == null &&
      interested == null &&
      joined == null &&
      closed == null;

  @override
  String toString() =>
      'CoachingEnquiryStats(total: $total, new: $newCount, '
      'contacted: $contacted, interested: $interested, joined: $joined, '
      'closed: $closed)';
}
