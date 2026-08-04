/// Where an enquiry sits in its lifecycle.
///
/// [slug] is what the API sends; anything the enum does not cover still renders
/// through [LiveEnquiryStatus.labelFor] rather than being dropped.
enum LiveEnquiryStatus {
  pending('Pending'),
  approved('Approved'),
  rejected('Rejected'),
  contacted('Contacted'),
  converted('Converted');

  const LiveEnquiryStatus(this.label);

  final String label;

  static LiveEnquiryStatus? tryParse(Object? value) {
    if (value == null) return null;
    final normalised = value.toString().trim().toLowerCase();
    if (normalised.isEmpty) return null;

    for (final status in LiveEnquiryStatus.values) {
      if (status.label.toLowerCase() == normalised) return status;
    }
    // A couple of spellings the backend uses interchangeably.
    switch (normalised) {
      case 'new':
      case 'open':
        return LiveEnquiryStatus.pending;
      case 'accepted':
      case 'confirmed':
        return LiveEnquiryStatus.approved;
      case 'declined':
      case 'cancelled':
        return LiveEnquiryStatus.rejected;
    }
    return null;
  }

  static String labelFor(String? raw) {
    final parsed = tryParse(raw);
    if (parsed != null) return parsed.label;
    final text = (raw ?? '').trim();
    if (text.isEmpty) return '—';
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }
}

/// A row in the Recent Enquiries card (`GET /dashboard/live-enquiries`).
class LiveEnquiry {
  const LiveEnquiry({
    required this.id,
    this.name,
    this.email,
    this.phone,
    this.sport,
    this.statusRaw,
    this.createdAt,
    this.timeAgoRaw,
    this.avatarUrl,
    this.raw = const {},
  });

  final String id;
  final String? name;
  final String? email;
  final String? phone;
  final String? sport;
  final String? statusRaw;

  final DateTime? createdAt;

  /// Some backends send a pre-rendered "2 hours ago" string. When present it is
  /// preferred over recomputing, so the dashboard agrees with the rest of the
  /// system about what "recent" means.
  final String? timeAgoRaw;

  final String? avatarUrl;

  final Map<String, dynamic> raw;

  LiveEnquiryStatus? get status => LiveEnquiryStatus.tryParse(statusRaw);

  String get statusLabel => LiveEnquiryStatus.labelFor(statusRaw);

  String get displayName {
    final trimmed = (name ?? '').trim();
    if (trimmed.isNotEmpty) return trimmed;
    final mail = (email ?? '').trim();
    return mail.isEmpty ? 'Unnamed enquiry' : mail;
  }

  /// Up to two initials, for the generated avatar when none was sent.
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

  bool get hasAvatar {
    final url = (avatarUrl ?? '').trim();
    return url.startsWith('http://') || url.startsWith('https://');
  }

  @override
  String toString() => 'LiveEnquiry($id, $name, $sport, $statusRaw)';
}
