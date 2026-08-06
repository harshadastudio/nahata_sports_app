import 'admin_role.dart';

/// How a coupon takes money off.
enum CouponDiscountType {
  percentage('Percentage', 'Percentage'),
  fixed('Fixed', 'Fixed amount');

  const CouponDiscountType(this.slug, this.label);

  /// The exact string the API expects — sent verbatim, never case-folded.
  final String slug;

  final String label;

  static CouponDiscountType? tryParse(Object? value) {
    if (value == null) return null;
    final normalised = value.toString().trim().toLowerCase();
    if (normalised.isEmpty) return null;
    // "percent", "percentage" and "%" all mean the same thing; anything else
    // that is not recognised stays null and is shown as the server wrote it.
    if (normalised.startsWith('per') || normalised == '%') {
      return CouponDiscountType.percentage;
    }
    if (normalised.startsWith('fix') ||
        normalised == 'flat' ||
        normalised == 'amount') {
      return CouponDiscountType.fixed;
    }
    return null;
  }
}

/// The one thing a coupon can be spent on.
///
/// A coupon targets a single scope — Court **or** Event, never both — which is
/// why the form clears the other scope's fields when this changes.
enum CouponAppliesTo {
  court('Court', 'Court booking'),
  event('Event', 'Event pass');

  const CouponAppliesTo(this.slug, this.label);

  final String slug;
  final String label;

  bool get isCourt => this == CouponAppliesTo.court;
  bool get isEvent => this == CouponAppliesTo.event;

  static CouponAppliesTo? tryParse(Object? value) {
    if (value == null) return null;
    final normalised = value.toString().trim().toLowerCase();
    switch (normalised) {
      case 'court':
      case 'courts':
      case 'facility':
      case 'booking':
        return CouponAppliesTo.court;
      case 'event':
      case 'events':
      case 'eventpass':
      case 'event_pass':
        return CouponAppliesTo.event;
    }
    return null;
  }
}

/// Where a coupon may be redeemed.
///
/// The backend enforces this against the `x-client-platform` header the client
/// sends — see `ApiConfig.platformHeader`. Nothing here restricts anything on
/// its own; this is the value being administered, not a client-side check.
enum CouponPlatform {
  all('All', 'All platforms'),
  web('Web', 'Website only'),
  app('App', 'Mobile app only');

  const CouponPlatform(this.slug, this.label);

  final String slug;
  final String label;

  static CouponPlatform? tryParse(Object? value) {
    if (value == null) return null;
    final normalised = value.toString().trim().toLowerCase();
    switch (normalised) {
      case 'all':
      case 'both':
        return CouponPlatform.all;
      case 'web':
      case 'website':
        return CouponPlatform.web;
      case 'app':
      case 'mobile':
      case 'android':
      case 'ios':
        return CouponPlatform.app;
    }
    return null;
  }
}

/// A coupon as the console administers it (`/admin/coupons`).
class AdminCoupon {
  const AdminCoupon({
    required this.id,
    this.code,
    this.description,
    this.discountTypeRaw,
    this.discountValue,
    this.maxDiscount,
    this.minOrderAmount,
    this.appliesToRaw,
    this.platformRaw,
    this.statusRaw,
    this.usageLimit,
    this.usedCount,
    this.validFrom,
    this.validUntil,
    this.sportComplexId,
    this.sportComplexName,
    this.sportId,
    this.sportName,
    this.eventPassId,
    this.eventPassTitle,
    this.createdAt,
    this.raw = const {},
  });

  final int id;

  final String? code;
  final String? description;

  final String? discountTypeRaw;

  /// Percent when [discountType] is percentage, rupees when it is fixed.
  final num? discountValue;

  /// Rupee cap on a percentage discount.
  final num? maxDiscount;

  /// Minimum order value the coupon needs to be usable, when the API sends one.
  final num? minOrderAmount;

  final String? appliesToRaw;
  final String? platformRaw;
  final String? statusRaw;

  final int? usageLimit;
  final int? usedCount;

  final DateTime? validFrom;
  final DateTime? validUntil;

  final int? sportComplexId;
  final String? sportComplexName;

  final int? sportId;
  final String? sportName;

  final int? eventPassId;
  final String? eventPassTitle;

  final DateTime? createdAt;

  /// The untouched row, so the detail panel can show a field the mapper has no
  /// name for yet rather than dropping it.
  final Map<String, dynamic> raw;

  CouponDiscountType? get discountType =>
      CouponDiscountType.tryParse(discountTypeRaw);

  CouponAppliesTo? get appliesTo => CouponAppliesTo.tryParse(appliesToRaw);

  CouponPlatform? get platform => CouponPlatform.tryParse(platformRaw);

  AdminUserStatus? get status => AdminUserStatus.tryParse(statusRaw);

  String get statusLabel => status?.label ?? (statusRaw ?? '').trim();

  String get platformLabel => platform?.label ?? (platformRaw ?? '').trim();

  String get appliesToLabel => appliesTo?.label ?? (appliesToRaw ?? '').trim();

  String get displayCode {
    final trimmed = (code ?? '').trim();
    return trimmed.isEmpty ? 'Coupon $id' : trimmed.toUpperCase();
  }

  bool get isPercentage => discountType == CouponDiscountType.percentage;

  /// "20% OFF" / "₹100 OFF".
  String get discountLabel {
    final value = discountValue;
    if (value == null) return '';
    final text = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
    return isPercentage ? '$text% OFF' : '₹$text OFF';
  }

  /// True once every permitted redemption has been used.
  bool get isExhausted {
    final limit = usageLimit;
    return limit != null && limit > 0 && (usedCount ?? 0) >= limit;
  }

  /// Redemptions left, or null when the coupon is unlimited.
  int? get remainingUses {
    final limit = usageLimit;
    if (limit == null || limit <= 0) return null;
    final left = limit - (usedCount ?? 0);
    return left < 0 ? 0 : left;
  }

  bool hasExpiredOn(DateTime now) {
    final until = validUntil;
    if (until == null) return false;
    // `validUntil` is a date, so the coupon lives to the end of that day.
    return now.isAfter(
      DateTime(until.year, until.month, until.day, 23, 59, 59),
    );
  }

  bool hasStartedOn(DateTime now) {
    final from = validFrom;
    if (from == null) return true;
    return !now.isBefore(DateTime(from.year, from.month, from.day));
  }

  /// Whether a customer could actually redeem this today.
  ///
  /// Deliberately separate from [status]: a coupon can be Active and still be
  /// unusable because it has expired or run out, and the list has to say which.
  bool isLiveOn(DateTime now) {
    return status == AdminUserStatus.active &&
        hasStartedOn(now) &&
        !hasExpiredOn(now) &&
        !isExhausted;
  }

  /// The venue/sport/event this coupon is limited to, as one line.
  String get scopeLabel {
    final parts = <String>[
      if ((sportComplexName ?? '').trim().isNotEmpty) sportComplexName!.trim(),
      if ((sportName ?? '').trim().isNotEmpty) sportName!.trim(),
      if ((eventPassTitle ?? '').trim().isNotEmpty) eventPassTitle!.trim(),
    ];
    return parts.isEmpty ? 'Everywhere' : parts.join(' · ');
  }

  @override
  String toString() =>
      'AdminCoupon($id, ${code ?? '-'}, $discountTypeRaw $discountValue, '
      '$appliesToRaw/$platformRaw, $statusRaw)';
}

/// The write payload for create and update.
///
/// Create sends the whole documented body; update sends only what was touched,
/// so an edit never blanks a column the admin did not change.
class CouponDraft {
  const CouponDraft({
    this.code,
    this.description,
    this.discountType,
    this.discountValue,
    this.maxDiscount,
    this.validUntil,
    this.usageLimit,
    this.status,
    this.appliesTo,
    this.platform,
    this.sportComplexId,
    this.sportId,
    this.eventPassId,
  });

  final String? code;
  final String? description;
  final CouponDiscountType? discountType;
  final num? discountValue;
  final num? maxDiscount;
  final DateTime? validUntil;
  final int? usageLimit;
  final AdminUserStatus? status;
  final CouponAppliesTo? appliesTo;
  final CouponPlatform? platform;
  final int? sportComplexId;
  final int? sportId;
  final int? eventPassId;

  /// `yyyy-MM-dd`, the format the documented body uses.
  static String? formatDate(DateTime? value) {
    if (value == null) return null;
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  /// The create body, exactly as the endpoint documents it.
  ///
  /// The scope keys are always present — including as nulls — because a coupon
  /// that applies to Court must positively say it has no event pass, and vice
  /// versa; an omitted key would leave the other scope ambiguous.
  Map<String, dynamic> toCreateJson() {
    final court = appliesTo?.isCourt ?? true;

    return <String, dynamic>{
      'code': (code ?? '').trim().toUpperCase(),
      'discountType': discountType?.slug,
      'discountValue': discountValue,
      'maxDiscount': maxDiscount,
      'description': (description ?? '').trim().isEmpty
          ? null
          : description!.trim(),
      'validUntil': formatDate(validUntil),
      'usageLimit': usageLimit,
      'status': (status ?? AdminUserStatus.active).slug,
      'appliesTo': appliesTo?.slug,
      // Only the chosen scope's ids travel; the other side is explicitly null.
      'sportComplexId': court ? sportComplexId : null,
      'sportId': court ? sportId : null,
      'eventPassId': court ? null : eventPassId,
      'platform': (platform ?? CouponPlatform.all).slug,
    };
  }

  /// Only the fields that were actually set.
  Map<String, dynamic> toUpdateJson() {
    final body = <String, dynamic>{};

    void put(String key, Object? value) {
      if (value == null) return;
      if (value is String && value.trim().isEmpty) return;
      body[key] = value is String ? value.trim() : value;
    }

    put('code', code?.toUpperCase());
    put('description', description);
    put('discountType', discountType?.slug);
    put('discountValue', discountValue);
    put('maxDiscount', maxDiscount);
    put('validUntil', formatDate(validUntil));
    put('usageLimit', usageLimit);
    put('status', status?.slug);
    put('appliesTo', appliesTo?.slug);
    put('platform', platform?.slug);

    // Changing the scope has to be able to clear the other side, so when
    // `appliesTo` is part of this edit both scope keys are sent — nulls
    // included — rather than being filtered out by `put`.
    final scope = appliesTo;
    if (scope != null) {
      body['sportComplexId'] = scope.isCourt ? sportComplexId : null;
      body['sportId'] = scope.isCourt ? sportId : null;
      body['eventPassId'] = scope.isCourt ? null : eventPassId;
    } else {
      put('sportComplexId', sportComplexId);
      put('sportId', sportId);
      put('eventPassId', eventPassId);
    }

    return body;
  }

  bool get isEmptyUpdate => toUpdateJson().isEmpty;
}

/// The outcome of `POST /coupons/validate` as the console reports it.
///
/// The server does the arithmetic, so [discountAmount] and [finalAmount] are
/// authoritative — nothing here recomputes them.
class CouponCheck {
  const CouponCheck({
    required this.isValid,
    this.message,
    this.coupon,
    this.originalAmount,
    this.discountAmount,
    this.finalAmount,
  });

  const CouponCheck.invalid(String? message)
    : this(isValid: false, message: message);

  final bool isValid;

  /// The server's own words, shown verbatim when a coupon is rejected.
  final String? message;

  final AdminCoupon? coupon;
  final num? originalAmount;
  final num? discountAmount;
  final num? finalAmount;

  @override
  String toString() =>
      'CouponCheck(valid: $isValid, discount: $discountAmount, '
      'final: $finalAmount)';
}
