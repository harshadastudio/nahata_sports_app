import 'employee_formats.dart';

/// A notification in the employee's own inbox, from `GET /notifications`.
///
/// Not `GET /notifications/admin` — that one is unscoped and would return every
/// notification in the system. The website's employee screen reads the same
/// personal inbox, so what an employee sees on the phone matches the web.
class EmployeeNotification {
  const EmployeeNotification({
    required this.id,
    this.title = '',
    this.message = '',
    this.type = 'System',
    this.targetRole,
    this.isRead = false,
    this.actionUrl,
    this.sentAt,
    this.createdAt,
  });

  final int id;
  final String title;
  final String message;

  /// `System` | `Booking` | `Payment` | `Alert` | `Promotion` | `Feedback`.
  final String type;

  final String? targetRole;
  final bool isRead;
  final String? actionUrl;

  final DateTime? sentAt;
  final DateTime? createdAt;

  String get displayTitle =>
      title.trim().isEmpty ? '(no title)' : title.trim();

  /// The timestamp that actually means "when this arrived" — `sentAt` when the
  /// backend set one, else the row's creation.
  DateTime? get at => sentAt ?? createdAt;

  String get timeLabel => formatDateTime(at);
  String get relativeLabel => formatRelative(at);

  EmployeeNotification copyWith({bool? isRead}) {
    return EmployeeNotification(
      id: id,
      title: title,
      message: message,
      type: type,
      targetRole: targetRole,
      isRead: isRead ?? this.isRead,
      actionUrl: actionUrl,
      sentAt: sentAt,
      createdAt: createdAt,
    );
  }

  @override
  String toString() => 'EmployeeNotification($id, $type, read: $isRead)';
}

/// The notification types the compose sheet offers. Fixed server-side.
const List<String> employeeNotificationTypes = [
  'System',
  'Booking',
  'Payment',
  'Alert',
  'Promotion',
  'Feedback',
];

/// One addressable person, from `GET /notifications/audience`.
///
/// A coach appears in both lists: [EmployeeAudience.coaches] keys off the
/// **coach** id (what `coachIds` wants), while their entry in
/// [EmployeeAudience.people] keys off their **user** id (what `userIds` wants).
/// Mixing the two silently addresses the wrong person, so they are kept apart.
class EmployeeRecipient {
  const EmployeeRecipient({required this.id, this.name = '', this.email});

  final int id;
  final String name;
  final String? email;

  String get displayName => name.trim().isEmpty ? '#$id' : name.trim();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is EmployeeRecipient && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'EmployeeRecipient($id, $name)';
}

/// Everyone this employee may message — the coaches and students of their own
/// complex, as `GET /notifications/audience` resolves them.
///
/// The send route intersects any client-supplied ids with this same set, so a
/// picker built from it can never address someone outside the complex, and a
/// tampered request would be filtered server-side anyway.
class EmployeeAudience {
  const EmployeeAudience({
    this.coaches = const [],
    this.people = const [],
  });

  /// Keyed by **coach** id — send as `coachIds`.
  final List<EmployeeRecipient> coaches;

  /// Coaches (by user id) and students, merged and de-duplicated — send as
  /// `userIds`.
  final List<EmployeeRecipient> people;

  static const EmployeeAudience empty = EmployeeAudience();

  bool get isEmpty => coaches.isEmpty && people.isEmpty;

  @override
  String toString() =>
      'EmployeeAudience(${coaches.length} coaches, ${people.length} people)';
}

/// Who a broadcast goes to.
enum EmployeeRecipientMode {
  /// Everyone at this complex — the backend resolves the list itself.
  all('all', 'Everyone in my complex'),

  /// Hand-picked coaches and students, addressed by user id.
  selected('selected', 'Select people'),

  /// Pick coaches; the message reaches each coach **and every student in their
  /// batches**, which is far wider than picking those coaches by hand.
  coaches('coaches', 'Coach-wise students');

  const EmployeeRecipientMode(this.wire, this.label);

  /// The `recipient` value the send body carries.
  final String wire;
  final String label;
}

/// A composed broadcast, ready to send.
class EmployeeNotificationDraft {
  const EmployeeNotificationDraft({
    required this.title,
    required this.message,
    this.type = 'System',
    this.mode = EmployeeRecipientMode.all,
    this.coachIds = const [],
    this.userIds = const [],
  });

  final String title;
  final String message;
  final String type;
  final EmployeeRecipientMode mode;
  final List<int> coachIds;
  final List<int> userIds;

  /// `POST /notifications/send`. The id list is only included for the mode that
  /// uses it — sending `userIds` alongside `recipient: 'all'` would be read as
  /// a targeted send by the non-employee branch of the controller.
  Map<String, dynamic> toBody() {
    return {
      'title': title.trim(),
      'message': message.trim(),
      'type': type,
      'recipient': mode.wire,
      if (mode == EmployeeRecipientMode.coaches) 'coachIds': coachIds,
      if (mode == EmployeeRecipientMode.selected) 'userIds': userIds,
    };
  }
}
