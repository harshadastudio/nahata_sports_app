/// One thread from `GET /user-feedback/mine` — the feedback a user submitted
/// plus every reply on it.
class FeedbackThread {
  const FeedbackThread({
    this.id,
    this.referenceNumber,
    this.subject,
    this.message,
    this.rating,
    this.status,
    this.createdAt,
    this.messages = const [],
  });

  final int? id;

  /// Server-issued reference the user quotes when following up.
  final String? referenceNumber;

  final String? subject;

  /// The original body. Replies live in [messages].
  final String? message;

  /// 1–5, or null when the user did not rate.
  final int? rating;

  /// `Open`, `Resolved` — whatever the console last set.
  final String? status;
  final String? createdAt;

  final List<FeedbackMessage> messages;

  factory FeedbackThread.fromJson(Map<String, dynamic> json) {
    final raw = json['messages'];

    return FeedbackThread(
      id: _int(json['id']),
      referenceNumber: _clean(json['referenceNumber']),
      subject: _clean(json['subject']),
      message: _clean(json['message']),
      rating: _int(json['rating']),
      status: _clean(json['status']),
      createdAt: _clean(json['createdAt']),
      messages: raw is List
          ? raw
                .whereType<Map>()
                .map(
                  (m) => FeedbackMessage.fromJson(Map<String, dynamic>.from(m)),
                )
                .toList(growable: false)
          : const [],
    );
  }

  bool get isResolved => (status ?? '').toLowerCase() == 'resolved';

  /// True once someone from the team has written back, which is the only thing
  /// a user actually scans this list for.
  bool get hasReply => messages.any((m) => m.isFromAdmin);

  static int? _int(Object? v) =>
      v is int ? v : int.tryParse(v?.toString() ?? '');

  static String? _clean(Object? v) {
    final t = v?.toString().trim();
    if (t == null || t.isEmpty || t == 'null') return null;
    return t;
  }
}

/// One message inside a [FeedbackThread].
class FeedbackMessage {
  const FeedbackMessage({
    this.id,
    this.message,
    this.senderName,
    this.senderType,
    this.createdAt,
  });

  final int? id;
  final String? message;
  final String? senderName;

  /// `user` or `admin` — who wrote it.
  final String? senderType;
  final String? createdAt;

  factory FeedbackMessage.fromJson(Map<String, dynamic> json) {
    return FeedbackMessage(
      id: FeedbackThread._int(json['id']),
      message: FeedbackThread._clean(json['message']),
      senderName: FeedbackThread._clean(json['senderName']),
      senderType: FeedbackThread._clean(
        json['senderType'] ?? json['sender_type'],
      ),
      createdAt: FeedbackThread._clean(json['createdAt']),
    );
  }

  bool get isFromAdmin => (senderType ?? '').toLowerCase() == 'admin';
}
