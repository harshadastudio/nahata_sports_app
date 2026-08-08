import '../../../../models/sports_complex_model.dart';
import 'paged.dart';

/// Where a contact enquiry currently sits.
///
/// The three values the live payload's `statusCounts` names: `new`, `read`,
/// `replied`. An unrecognised value is never coerced into one of these — it
/// keeps its own text through [labelFor], the same way every other vocabulary
/// in this console behaves.
enum ContactInquiryStatus {
  // `new` is a Dart keyword, so the member is `isNew` while the wire value
  // stays `new` — the same shape `CoachingEnquiryStatus` already uses.
  isNew('new', 'New'),
  read('read', 'Read'),
  replied('replied', 'Replied');

  const ContactInquiryStatus(this.slug, this.label);

  /// The value the API sends and expects.
  final String slug;

  /// What the console shows.
  final String label;

  /// Case- and separator-insensitive. Null for anything unrecognised, so the
  /// caller can tell "not one of ours" from "unset".
  static ContactInquiryStatus? tryParse(String? raw) {
    final key = (raw ?? '').trim().toLowerCase().replaceAll(
      RegExp(r'[-\s_]+'),
      '',
    );
    if (key.isEmpty) return null;

    for (final status in values) {
      if (status.slug == key) return status;
    }
    return null;
  }

  /// A label for any value, recognised or not — an unknown status is shown as
  /// the server spelled it rather than as "Unknown".
  static String labelFor(String? raw) {
    final parsed = tryParse(raw);
    if (parsed != null) return parsed.label;

    final text = (raw ?? '').trim();
    if (text.isEmpty) return '—';
    return text[0].toUpperCase() + text.substring(1);
  }
}

/// `data.statusCounts` — the authoritative totals for the summary cards.
///
/// These are **whole-dataset** figures, not counts of the page on screen, which
/// is exactly why they are read from the payload rather than derived from the
/// rows: counting ten loaded rows would answer a different question.
class ContactStatusCounts {
  const ContactStatusCounts({
    this.isNew = 0,
    this.read = 0,
    this.replied = 0,
    this.total = 0,
  });

  final int isNew;
  final int read;
  final int replied;
  final int total;

  int countOf(ContactInquiryStatus status) {
    switch (status) {
      case ContactInquiryStatus.isNew:
        return isNew;
      case ContactInquiryStatus.read:
        return read;
      case ContactInquiryStatus.replied:
        return replied;
    }
  }

  /// The API's own `total` when it sent one, otherwise the three states added
  /// up — a payload that omits `total` should not show 0 beside three non-zero
  /// cards.
  int get effectiveTotal => total > 0 ? total : isNew + read + replied;

  /// This state's share of the whole, for the card's progress ring. Null when
  /// there is nothing to take a share of, so the ring is hidden rather than
  /// drawn at zero.
  double? shareOf(ContactInquiryStatus status) {
    final whole = effectiveTotal;
    if (whole <= 0) return null;
    return (countOf(status) / whole).clamp(0.0, 1.0);
  }

  bool get isEmpty => effectiveTotal == 0;

  @override
  String toString() =>
      'ContactStatusCounts(new: $isNew, read: $read, replied: $replied, '
      'total: $total)';
}

/// One row of `GET /contact-us/admin`.
///
/// [id] is a **UUID string**, not an int — the live payload sends
/// `"df57972a-c0f6-458d-b7e0-e728e6c944fb"`. Nothing here parses it as a
/// number, and every route that ever takes it will take it as text.
class ContactInquiry {
  const ContactInquiry({
    required this.id,
    required this.fullName,
    this.email,
    this.subject,
    this.message,
    this.statusRaw,
    this.referenceNumber,
    this.sportComplexId,
    this.sportComplex,
    this.ipAddress,
    this.userAgent,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String fullName;
  final String? email;
  final String? subject;
  final String? message;

  /// Kept raw so an unrecognised state still renders. [status] is the parsed
  /// form, null when the value is not one this build knows.
  final String? statusRaw;

  final String? referenceNumber;
  final int? sportComplexId;

  /// The venue envelope the row carries. Reuses the app-wide [SportsComplex]
  /// (id / name / city) — the payload sends exactly those three fields.
  final SportsComplex? sportComplex;

  /// Diagnostics. Deliberately **not** shown in the list: they are of no use
  /// when scanning a queue and they are the sort of thing that should not be
  /// on screen over someone's shoulder. The detail view shows them behind an
  /// expander.
  final String? ipAddress;
  final String? userAgent;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Set when the row is soft-deleted. Null for a live enquiry.
  final DateTime? deletedAt;

  ContactInquiryStatus? get status => ContactInquiryStatus.tryParse(statusRaw);

  String get statusLabel => ContactInquiryStatus.labelFor(statusRaw);

  /// Never blank — a nameless enquiry still needs something to click on.
  String get displayName {
    final name = fullName.trim();
    if (name.isNotEmpty) return name;
    final address = (email ?? '').trim();
    if (address.isNotEmpty) return address;
    return referenceNumber?.trim().isNotEmpty == true
        ? referenceNumber!.trim()
        : 'Unnamed enquiry';
  }

  String get subjectLabel {
    final text = (subject ?? '').trim();
    return text.isEmpty ? 'No subject' : text;
  }

  /// The venue name from the nested object, falling back to nothing rather
  /// than to the bare id — "1" is not a venue name.
  String get sportComplexName => sportComplex?.name.trim() ?? '';

  String get sportComplexLabel {
    final name = sportComplexName;
    if (name.isEmpty) return '';
    final city = sportComplex?.city?.trim() ?? '';
    return city.isEmpty ? name : '$name, $city';
  }

  /// The venue this row belongs to: the nested object first, the flat id
  /// second. Used for scope checks, so it must not depend on the envelope
  /// being present.
  int? get effectiveComplexId => sportComplex?.id ?? sportComplexId;

  bool get isDeleted => deletedAt != null;

  /// A one-line preview for the table. Collapses the newlines a free-text
  /// message arrives with, so a row cannot grow to the height of the message.
  String preview({int max = 90}) {
    final text = (message ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) return '';
    if (text.length <= max) return text;
    return '${text.substring(0, max).trimRight()}…';
  }

  @override
  String toString() =>
      'ContactInquiry($id, $fullName, ${referenceNumber ?? '-'}, '
      '${statusRaw ?? '-'})';
}

/// One answer from `GET /contact-us/admin`: the page of rows *and* the
/// dataset-wide status counts that came with it.
///
/// They travel together because they arrive together — separating them would
/// invite a screen that shows page 3's rows beside page 1's counters.
class ContactInquiryPage {
  const ContactInquiryPage({
    this.page = const Paged<ContactInquiry>(),
    this.counts = const ContactStatusCounts(),
  });

  final Paged<ContactInquiry> page;
  final ContactStatusCounts counts;

  List<ContactInquiry> get items => page.items;
  bool get isEmpty => page.isEmpty;
}