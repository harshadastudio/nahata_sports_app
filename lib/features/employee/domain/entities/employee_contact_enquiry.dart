import 'employee_formats.dart';

/// A "Contact Us" message from the public site, from `GET /contact-us/admin`.
///
/// The desk reads it, marks where it got to, and deletes it when it is done.
/// There is no reply endpoint on this route family — replying happens by email
/// or phone, which is why nothing here composes one.
class EmployeeContactEnquiry {
  const EmployeeContactEnquiry({
    required this.id,
    this.name = '',
    this.email = '',
    this.phone = '',
    this.subject = '',
    this.message = '',
    this.status = 'New',
    this.createdAt,
    this.updatedAt,
  });

  /// A UUID on this route, not a number — `contact_us` rows are keyed by
  /// `uuid`, so an int id would parse to 0 and the row would be dropped.
  final String id;

  final String name;
  final String email;
  final String phone;

  final String subject;
  final String message;

  /// Stored lower-case on the wire: `new` | `read` | `replied`.
  /// Compare through [isNew] / [isReplied] rather than against a literal.
  final String status;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get displayName =>
      name.trim().isEmpty ? 'Enquiry $shortId' : name.trim();

  /// The first block of the UUID — enough to tell two rows apart in a title
  /// without spilling a 36-character key across the sheet header.
  String get shortId {
    final text = id.trim();
    if (text.isEmpty) return '#?';
    final head = text.split('-').first;
    return '#${head.length > 8 ? head.substring(0, 8) : head}';
  }

  String get initial =>
      displayName.trim().isEmpty ? '?' : displayName.trim()[0].toUpperCase();

  String get displaySubject =>
      subject.trim().isEmpty ? 'No subject' : subject.trim();

  bool get isNew => status.toLowerCase() == 'new';
  bool get isReplied => status.toLowerCase() == 'replied';
  bool get isRead => status.toLowerCase() == 'read';

  /// `replied` → `Replied`. The API stores these lower-case; a raw value in a
  /// status chip reads as a bug rather than a state.
  String get displayStatus => labelFor(status);

  String get receivedLabel => formatRelative(createdAt);

  String get receivedExactLabel => formatDateTime(createdAt);

  /// The message flattened to one line for the list row. Collapsing the
  /// whitespace matters: these come from a textarea and arrive full of newlines
  /// that would otherwise blow the row's height out.
  String get preview => message.replaceAll(RegExp(r'\s+'), ' ').trim();

  EmployeeContactEnquiry copyWith({String? status, DateTime? updatedAt}) {
    return EmployeeContactEnquiry(
      id: id,
      name: name,
      email: email,
      phone: phone,
      subject: subject,
      message: message,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// The wire vocabulary, lower-case exactly as the column stores it — these
  /// are sent to `PATCH /contact-us/admin/{id}/status`, so they are not
  /// display strings. Use [labelFor] for that.
  static const List<String> statuses = ['new', 'read', 'replied'];

  /// Title-cases a wire status for display, leaving an unknown value readable
  /// rather than forcing it into one of the three.
  static String labelFor(String status) {
    final text = status.trim();
    if (text.isEmpty) return 'Unknown';
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  @override
  String toString() => 'EmployeeContactEnquiry($id, $displayName, $status)';
}

/// The `statusCounts` block `GET /contact-us/admin` sends beside its rows.
///
/// This route is the only one in the console that nests its pagination *inside*
/// `data` and adds a counter block next to it, so the counts are carried on
/// their own object rather than bent into the shared page shape.
class EmployeeContactEnquiryCounts {
  const EmployeeContactEnquiryCounts({this.byStatus = const {}});

  /// Lower-cased status → count, so a lookup does not depend on the casing the
  /// backend happened to use.
  final Map<String, int> byStatus;

  int countOf(String status) => byStatus[status.trim().toLowerCase()] ?? 0;

  /// The server sends `total` as one of the buckets (`{new, read, replied,
  /// total}`), so summing the map would count every row twice. The reported
  /// total wins; the sum is only the fallback for a payload without one.
  int get total {
    final reported = byStatus['total'];
    if (reported != null) return reported;
    return byStatus.values.fold(0, (sum, value) => sum + value);
  }

  int get unread => countOf('new');

  bool get isEmpty => byStatus.isEmpty;

  static const EmployeeContactEnquiryCounts none =
      EmployeeContactEnquiryCounts();

  @override
  String toString() => 'EmployeeContactEnquiryCounts($byStatus)';
}
