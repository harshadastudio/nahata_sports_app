/// Notifications, from `/notifications`.
///
/// The coach screen is built on the **user** routes (`GET /notifications`,
/// `/unread-count`, `PATCH /{id}/read`, `PATCH /mark-all-read`), which are
/// scoped to the signed-in user's own rows, plus `POST /notifications/send`
/// to compose one.
///
/// `GET /notifications/admin` is deliberately **not** used: it applies no
/// scoping at all, so a coach calling it would receive every notification
/// raised across the whole system.
library;

/// The categories the backend's ENUM accepts. Case-sensitive on the wire.
enum CoachNotificationType {
  system('System'),
  alert('Alert'),
  booking('Booking'),
  payment('Payment'),
  promotion('Promotion'),
  feedback('Feedback');

  const CoachNotificationType(this.slug);

  final String slug;

  String get label => slug;

  static CoachNotificationType? tryParse(String? value) {
    final text = (value ?? '').trim().toLowerCase();
    if (text.isEmpty) return null;
    for (final type in CoachNotificationType.values) {
      if (type.slug.toLowerCase() == text) return type;
    }
    return null;
  }
}

/// One notification in the coach's inbox.
class CoachNotification {
  const CoachNotification({
    required this.id,
    this.title = '',
    this.message = '',
    this.typeRaw,
    this.isRead = false,
    this.actionUrl,
    this.sentAt,
  });

  final int id;
  final String title;
  final String message;
  final String? typeRaw;
  final bool isRead;

  /// A path into the **web** dashboard (e.g. `/coaching-enquiry`), not an app
  /// route — so it is shown as context rather than made tappable.
  final String? actionUrl;

  final DateTime? sentAt;

  CoachNotificationType? get type => CoachNotificationType.tryParse(typeRaw);

  /// Falls back to the raw string so an unmapped type is still shown.
  String get typeLabel => type?.label ?? (typeRaw ?? '').trim();

  String get displayTitle =>
      title.trim().isEmpty ? 'Notification' : title.trim();

  CoachNotification copyWith({bool? isRead}) => CoachNotification(
        id: id,
        title: title,
        message: message,
        typeRaw: typeRaw,
        isRead: isRead ?? this.isRead,
        actionUrl: actionUrl,
        sentAt: sentAt,
      );

  @override
  String toString() =>
      'CoachNotification($id, $title, ${isRead ? 'read' : 'unread'})';
}

/// Someone a notification can be addressed to, from `GET /notifications/users`.
class CoachNotificationRecipient {
  const CoachNotificationRecipient({
    required this.id,
    this.name = '',
    this.email = '',
    this.role,
  });

  /// The **user** id — what `userIds` on the send route takes.
  final int id;

  final String name;
  final String email;
  final String? role;

  String get displayName => name.trim().isEmpty ? 'User #$id' : name.trim();

  String get initial => displayName.substring(0, 1).toUpperCase();

  String get roleLabel => (role ?? '').trim();

  /// Whether this row matches a search box, across name, email and role.
  bool matches(String term) {
    final text = term.trim().toLowerCase();
    if (text.isEmpty) return true;
    return name.toLowerCase().contains(text) ||
        email.toLowerCase().contains(text) ||
        roleLabel.toLowerCase().contains(text);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CoachNotificationRecipient && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'CoachNotificationRecipient($id, $name)';
}

/// Who a new notification goes to.
enum CoachNotificationAudience {
  /// Named recipients only.
  selected,

  /// **Every user in the system.** The backend places no ceiling on this for a
  /// coach — `recipient: 'all'` from a coach reaches website users and other
  /// complexes too, not just their own students. The UI confirms before
  /// sending one.
  everyone,
}

/// A notification a coach is composing.
class CoachNotificationDraft {
  const CoachNotificationDraft({
    required this.title,
    required this.message,
    this.type = CoachNotificationType.system,
    this.audience = CoachNotificationAudience.selected,
    this.userIds = const [],
  });

  final String title;
  final String message;
  final CoachNotificationType type;
  final CoachNotificationAudience audience;

  /// Required when [audience] is [CoachNotificationAudience.selected].
  final List<int> userIds;

  bool get isBroadcast => audience == CoachNotificationAudience.everyone;

  Map<String, dynamic> toJson() => {
        'title': title.trim(),
        'message': message.trim(),
        'type': type.slug,
        'recipient': isBroadcast ? 'all' : 'selected',
        if (!isBroadcast) 'userIds': userIds,
      };

  @override
  String toString() =>
      'CoachNotificationDraft($title, ${audience.name}, '
      '${userIds.length} recipients)';
}
