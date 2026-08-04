import 'admin_sports_complex.dart' show resolveMediaUrl;

/// The status vocabulary the module documents: Active, Inactive, Expired,
/// Cancelled.
///
/// A separate enum from `AdminUserStatus` even though two members overlap —
/// that one has `suspended` and no `expired`, and a membership can never be
/// suspended. Reads are case- and separator-insensitive; writes send [slug]
/// exactly, because the backend has rejected off-casing before.
enum MembershipStatus {
  active('Active'),
  inactive('Inactive'),
  expired('Expired'),
  cancelled('Cancelled');

  const MembershipStatus(this.slug);

  /// The wire value, which is also the label.
  final String slug;

  String get label => slug;

  static MembershipStatus? tryParse(Object? value) =>
      _match(MembershipStatus.values, value, (s) => s.slug);

  /// A value outside the vocabulary still renders, rather than vanishing.
  static String labelFor(String? raw) =>
      tryParse(raw)?.label ?? _titleise(raw);
}

/// Paid, Pending, Failed, Refunded.
enum MembershipPaymentStatus {
  paid('Paid'),
  pending('Pending'),
  failed('Failed'),
  refunded('Refunded');

  const MembershipPaymentStatus(this.slug);

  final String slug;

  String get label => slug;

  static MembershipPaymentStatus? tryParse(Object? value) =>
      _match(MembershipPaymentStatus.values, value, (s) => s.slug);

  static String labelFor(String? raw) =>
      tryParse(raw)?.label ?? _titleise(raw);
}

T? _match<T>(List<T> values, Object? raw, String Function(T) slugOf) {
  if (raw == null) return null;
  final needle = _normalise(raw.toString());
  if (needle.isEmpty) return null;
  for (final value in values) {
    if (_normalise(slugOf(value)) == needle) return value;
  }
  return null;
}

String _normalise(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'[\s_\-]+'), '');

String _titleise(String? raw) {
  final text = (raw ?? '').trim();
  if (text.isEmpty) return '—';
  return text
      .split(RegExp(r'[\s_\-]+'))
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
      .join(' ');
}

/// One membership (`/memberships`).
class Membership {
  const Membership({
    required this.id,
    this.userId,
    this.userName,
    this.userEmail,
    this.userPhone,
    this.planId,
    this.planName,
    this.price,
    this.validityDays,
    this.bookingLimit,
    this.bookingsUsed,
    this.discountPercent,
    this.discountApplied,
    this.totalAmount,
    this.accessType,
    this.features = const [],
    this.startDate,
    this.endDate,
    this.statusRaw,
    this.paymentStatusRaw,
    this.autoRenew,
    this.cancellationReason,
    this.createdAt,
    this.updatedAt,
    this.raw = const {},
  });

  /// The id every `/memberships/{id}` call addresses. Kept as a string because
  /// the documented `userId` is templated (`{{userId}}`) rather than shown as a
  /// number, so this backend may well use non-numeric ids here too.
  final String id;

  final String? userId;
  final String? userName;
  final String? userEmail;
  final String? userPhone;

  /// The plan code, e.g. `GOLD`.
  final String? planId;
  final String? planName;

  final num? price;

  /// `validity` on the wire — a day count, not a date.
  final int? validityDays;

  /// `bookings` on the wire: how many bookings the plan allows.
  final int? bookingLimit;

  /// Only if the payload reports it; never inferred.
  final int? bookingsUsed;

  /// `discount` — a percentage.
  final num? discountPercent;

  /// `discountApplied` — an amount in rupees.
  final num? discountApplied;

  final num? totalAmount;

  final String? accessType;
  final List<String> features;

  final DateTime? startDate;
  final DateTime? endDate;

  final String? statusRaw;
  final String? paymentStatusRaw;

  final bool? autoRenew;
  final String? cancellationReason;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  final Map<String, dynamic> raw;

  MembershipStatus? get status => MembershipStatus.tryParse(statusRaw);
  String get statusLabel => MembershipStatus.labelFor(statusRaw);
  bool get isActive => status == MembershipStatus.active;
  bool get isCancelled => status == MembershipStatus.cancelled;

  MembershipPaymentStatus? get paymentStatus =>
      MembershipPaymentStatus.tryParse(paymentStatusRaw);
  String get paymentLabel => MembershipPaymentStatus.labelFor(paymentStatusRaw);
  bool get isPaid => paymentStatus == MembershipPaymentStatus.paid;

  String get displayPlan {
    final trimmed = (planName ?? '').trim();
    if (trimmed.isNotEmpty) return trimmed;
    final code = (planId ?? '').trim();
    return code.isEmpty ? 'Untitled plan' : code;
  }

  String get displayUser {
    final trimmed = (userName ?? '').trim();
    if (trimmed.isNotEmpty) return trimmed;
    final id = (userId ?? '').trim();
    return id.isEmpty ? 'Unknown member' : 'User #$id';
  }

  String get initials {
    final parts = displayUser
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  /// The avatar image, when the embedded user carried one.
  String? get avatarUrl {
    final value = raw['profileImage'] ?? raw['avatar'];
    return value is String ? resolveMediaUrl(value) : null;
  }

  /// Days left before [endDate], or null when the payload gave no end date.
  /// Negative once the plan has run out — the caller decides how to say that.
  int? daysRemaining({DateTime? now}) {
    final end = endDate;
    if (end == null) return null;
    final today = now ?? DateTime.now();
    final from = DateTime(today.year, today.month, today.day);
    final to = DateTime(end.year, end.month, end.day);
    return to.difference(from).inDays;
  }

  /// True only when an end date exists and has passed. A membership with no
  /// end date is *unknown*, not expired.
  bool hasLapsed({DateTime? now}) {
    final days = daysRemaining(now: now);
    return days != null && days < 0;
  }

  /// How much of the term has elapsed, 0–1, or null when it cannot be known.
  double? progress({DateTime? now}) {
    final start = startDate;
    final end = endDate;
    if (start == null || end == null) return null;
    final total = end.difference(start).inSeconds;
    if (total <= 0) return null;
    final done = (now ?? DateTime.now()).difference(start).inSeconds;
    return (done / total).clamp(0.0, 1.0);
  }

  /// Bookings left, when both the limit and the usage were reported.
  int? get bookingsRemaining {
    final limit = bookingLimit;
    final used = bookingsUsed;
    if (limit == null || used == null) return null;
    final left = limit - used;
    return left < 0 ? 0 : left;
  }

  /// What a local search should match.
  bool matches(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    return displayPlan.toLowerCase().contains(needle) ||
        displayUser.toLowerCase().contains(needle) ||
        (planId ?? '').toLowerCase().contains(needle) ||
        (userEmail ?? '').toLowerCase().contains(needle) ||
        (userPhone ?? '').toLowerCase().contains(needle) ||
        id.toLowerCase().contains(needle);
  }

  /// Merges a detail read over the list row, keeping anything detail omitted.
  Membership mergedWith(Membership other) {
    return Membership(
      id: other.id.isEmpty ? id : other.id,
      userId: other.userId ?? userId,
      userName: other.userName ?? userName,
      userEmail: other.userEmail ?? userEmail,
      userPhone: other.userPhone ?? userPhone,
      planId: other.planId ?? planId,
      planName: other.planName ?? planName,
      price: other.price ?? price,
      validityDays: other.validityDays ?? validityDays,
      bookingLimit: other.bookingLimit ?? bookingLimit,
      bookingsUsed: other.bookingsUsed ?? bookingsUsed,
      discountPercent: other.discountPercent ?? discountPercent,
      discountApplied: other.discountApplied ?? discountApplied,
      totalAmount: other.totalAmount ?? totalAmount,
      accessType: other.accessType ?? accessType,
      features: other.features.isEmpty ? features : other.features,
      startDate: other.startDate ?? startDate,
      endDate: other.endDate ?? endDate,
      statusRaw: other.statusRaw ?? statusRaw,
      paymentStatusRaw: other.paymentStatusRaw ?? paymentStatusRaw,
      autoRenew: other.autoRenew ?? autoRenew,
      cancellationReason: other.cancellationReason ?? cancellationReason,
      createdAt: other.createdAt ?? createdAt,
      updatedAt: other.updatedAt ?? updatedAt,
      raw: {...raw, ...other.raw},
    );
  }

  /// A copy with one field changed, for the optimistic writes.
  Membership copyWith({
    String? statusRaw,
    String? paymentStatusRaw,
    DateTime? endDate,
    String? cancellationReason,
  }) {
    return Membership(
      id: id,
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      userPhone: userPhone,
      planId: planId,
      planName: planName,
      price: price,
      validityDays: validityDays,
      bookingLimit: bookingLimit,
      bookingsUsed: bookingsUsed,
      discountPercent: discountPercent,
      discountApplied: discountApplied,
      totalAmount: totalAmount,
      accessType: accessType,
      features: features,
      startDate: startDate,
      endDate: endDate ?? this.endDate,
      statusRaw: statusRaw ?? this.statusRaw,
      paymentStatusRaw: paymentStatusRaw ?? this.paymentStatusRaw,
      autoRenew: autoRenew,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      createdAt: createdAt,
      updatedAt: updatedAt,
      raw: raw,
    );
  }

  @override
  String toString() =>
      'Membership($id, $planName, user: $userId, $statusRaw/$paymentStatusRaw, '
      '$startDate → $endDate)';
}

/// `GET /memberships/stats`.
///
/// Every figure is nullable: a counter the endpoint did not send is shown as an
/// em dash, never as a 0, which would be a claim of its own.
class MembershipStats {
  const MembershipStats({
    this.total,
    this.active,
    this.inactive,
    this.expired,
    this.cancelled,
    this.revenue,
  });

  final int? total;
  final int? active;
  final int? inactive;
  final int? expired;
  final int? cancelled;
  final num? revenue;

  bool get isEmpty =>
      total == null &&
      active == null &&
      inactive == null &&
      expired == null &&
      cancelled == null &&
      revenue == null;

  @override
  String toString() =>
      'MembershipStats(total: $total, active: $active, expired: $expired, '
      'cancelled: $cancelled, revenue: $revenue)';
}

/// The write payload for `POST /memberships` and `PUT /memberships/{id}`.
class MembershipDraft {
  const MembershipDraft({
    this.userId,
    this.planId,
    this.planName,
    this.price,
    this.validityDays,
    this.bookingLimit,
    this.discountPercent,
    this.accessType,
    this.features,
    this.startDate,
    this.endDate,
    this.status,
    this.paymentStatus,
    this.autoRenew,
    this.discountApplied,
    this.totalAmount,
  });

  final String? userId;
  final String? planId;
  final String? planName;
  final num? price;
  final int? validityDays;
  final int? bookingLimit;
  final num? discountPercent;
  final String? accessType;
  final List<String>? features;
  final DateTime? startDate;
  final DateTime? endDate;
  final MembershipStatus? status;
  final MembershipPaymentStatus? paymentStatus;
  final bool? autoRenew;
  final num? discountApplied;
  final num? totalAmount;

  /// `yyyy-MM-dd`, as the documented payload sends it.
  static String? formatDate(DateTime? value) {
    if (value == null) return null;
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  /// One feature per line in the form; blank lines are dropped rather than
  /// posted as empty strings.
  static List<String> parseFeatures(String text) => text
      .split(RegExp(r'[\r\n]+'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);

  static String joinFeatures(List<String> features) => features.join('\n');

  /// The end date implied by a start date and a validity in days.
  ///
  /// Inclusive of the start day: a 365-day plan starting 2026-08-01 ends
  /// 2027-07-31, exactly as the documented example shows.
  static DateTime? endDateFor(DateTime? start, int? validityDays) {
    if (start == null || validityDays == null || validityDays <= 0) return null;
    return DateTime(start.year, start.month, start.day)
        .add(Duration(days: validityDays - 1));
  }

  /// The amount payable after the percentage discount, when both are known.
  static num? amountFor(num? price, num? discountPercent) {
    if (price == null) return null;
    final percent = discountPercent ?? 0;
    if (percent <= 0) return price;
    final due = price - (price * percent / 100);
    return due < 0 ? 0 : num.parse(due.toStringAsFixed(2));
  }

  /// `POST /memberships` — the documented body, in full.
  Map<String, dynamic> toCreateJson() {
    return <String, dynamic>{
      'userId': (userId ?? '').trim(),
      'planId': (planId ?? '').trim(),
      'planName': (planName ?? '').trim(),
      'price': price,
      'validity': validityDays,
      'bookings': bookingLimit,
      'discount': discountPercent ?? 0,
      'accessType': (accessType ?? '').trim(),
      'features': features ?? const <String>[],
      'startDate': formatDate(startDate),
      'endDate': formatDate(endDate),
      'status': (status ?? MembershipStatus.active).slug,
      'paymentStatus':
          (paymentStatus ?? MembershipPaymentStatus.pending).slug,
      'autoRenew': autoRenew ?? false,
      'discountApplied': discountApplied ?? 0,
      'totalAmount': totalAmount,
    };
  }

  /// `PUT /memberships/{id}` — **only the fields that changed**.
  ///
  /// The module documents the body by a three-field example (planName, price,
  /// endDate) and says "update only changed fields", so this sends exactly what
  /// the caller set and nothing else. Status and payment status have their own
  /// PATCH routes and are never sent here.
  Map<String, dynamic> toUpdateJson() {
    final body = <String, dynamic>{};

    void put(String key, Object? value) {
      if (value == null) return;
      body[key] = value is String ? value.trim() : value;
    }

    put('planId', planId);
    put('planName', planName);
    put('price', price);
    put('validity', validityDays);
    put('bookings', bookingLimit);
    put('discount', discountPercent);
    put('accessType', accessType);
    if (features != null) body['features'] = features;
    put('startDate', formatDate(startDate));
    put('endDate', formatDate(endDate));
    put('autoRenew', autoRenew);
    put('discountApplied', discountApplied);
    put('totalAmount', totalAmount);

    return body;
  }
}
