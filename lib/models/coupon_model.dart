/// Models for `GET /coupons/active?appliesTo=…`.
library;

/// A discount coupon offered for a booking type.
///
/// The live endpoint currently returns an empty list, so every field is read
/// defensively and the common naming variants are accepted — nothing here
/// assumes a key that has not been seen on the wire.
class CouponModel {
  const CouponModel({
    this.id,
    this.code,
    this.title,
    this.description,
    this.discountType,
    this.discountValue = 0,
    this.maxDiscount,
    this.minOrderAmount,
    this.appliesTo,
    this.sportComplexId,
    this.status,
    this.validFrom,
    this.validTill,
    this.usageLimit,
    this.usedCount,
  });

  final int? id;

  /// The code the user types, e.g. `HOLI20`.
  final String? code;

  final String? title;
  final String? description;

  /// `Percentage` or `Fixed` — anything starting with "per" counts as percent.
  final String? discountType;

  /// Percent (when [isPercentage]) or rupees.
  final double discountValue;

  /// Rupee cap on a percentage discount.
  final double? maxDiscount;

  /// Minimum order value the coupon needs to be usable.
  final double? minOrderAmount;

  final String? appliesTo;

  /// Venue the coupon is limited to; null means every complex.
  final int? sportComplexId;

  final String? status;
  final DateTime? validFrom;

  /// `validUntil` on the wire.
  final DateTime? validTill;

  /// How many times the coupon may be redeemed overall, and how often it
  /// already has been.
  final int? usageLimit;
  final int? usedCount;

  /// `/coupons/active` only returns live coupons, so a missing status counts
  /// as active.
  bool get isActive => (status ?? 'Active').toLowerCase() == 'active';

  bool get isExhausted {
    final limit = usageLimit;
    return limit != null && limit > 0 && (usedCount ?? 0) >= limit;
  }

  bool get isPercentage =>
      (discountType ?? 'Percentage').toLowerCase().startsWith('per');

  /// Live today, according to whatever validity window the API sent.
  bool get isWithinValidity {
    final now = DateTime.now();
    final from = validFrom;
    final till = validTill;
    if (from != null && now.isBefore(DateTime(from.year, from.month, from.day))) {
      return false;
    }
    if (till != null &&
        now.isAfter(DateTime(till.year, till.month, till.day, 23, 59, 59))) {
      return false;
    }
    return true;
  }

  bool get isUsable => isActive && isWithinValidity && !isExhausted;

  /// True when [amount] clears the coupon's minimum order value.
  bool meetsMinimum(double amount) =>
      minOrderAmount == null || amount >= minOrderAmount!;

  /// Rupees off [amount]. Never more than [amount] itself, and never more
  /// than [maxDiscount] when the coupon is a percentage one.
  double discountFor(double amount) {
    if (!isUsable || !meetsMinimum(amount) || amount <= 0) return 0;

    var off = isPercentage ? amount * discountValue / 100 : discountValue;
    final cap = maxDiscount;
    if (isPercentage && cap != null && off > cap) off = cap;

    if (off < 0) return 0;
    return off > amount ? amount : off;
  }

  /// "20% OFF" / "₹100 OFF" — the label shown on the coupon chip.
  String get shortLabel {
    final value = discountValue == discountValue.roundToDouble()
        ? discountValue.toStringAsFixed(0)
        : discountValue.toStringAsFixed(2);
    return isPercentage ? '$value% OFF' : '₹$value OFF';
  }

  factory CouponModel.fromJson(Map<String, dynamic> json) => CouponModel(
        id: _asInt(json['id']),
        code: _asString(json['code'] ?? json['couponCode'] ?? json['coupon_code']),
        title: _asString(json['title'] ?? json['name']),
        description: _asString(json['description'] ?? json['details']),
        discountType: _asString(
            json['discountType'] ?? json['discount_type'] ?? json['type']),
        discountValue: _asDouble(json['discountValue'] ??
                json['discount_value'] ??
                json['discount'] ??
                json['value']) ??
            0,
        maxDiscount: _asDouble(json['maxDiscount'] ??
            json['max_discount'] ??
            json['maxDiscountAmount']),
        minOrderAmount: _asDouble(json['minOrderAmount'] ??
            json['min_order_amount'] ??
            json['minOrderValue'] ??
            json['minPurchase']),
        appliesTo: _asString(json['appliesTo'] ?? json['applies_to']),
        sportComplexId:
            _asInt(json['sportComplexId'] ?? json['sport_complex_id']),
        status: _asString(json['status']),
        validFrom: _asDate(
            json['validFrom'] ?? json['valid_from'] ?? json['startDate']),
        validTill: _asDate(json['validUntil'] ??
            json['validTill'] ??
            json['valid_till'] ??
            json['validTo'] ??
            json['endDate'] ??
            json['expiryDate']),
        usageLimit: _asInt(json['usageLimit'] ?? json['usage_limit']),
        usedCount: _asInt(json['usedCount'] ?? json['used_count']),
      );

  static List<CouponModel> listFrom(Object? data) {
    if (data is! List) return const <CouponModel>[];
    return data
        .whereType<Map>()
        .map((e) => CouponModel.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }
}

/// Outcome of `POST /coupons/validate`.
///
/// The server does the arithmetic, so [discountAmount] and [finalAmount] are
/// authoritative — the client never has to recompute them.
class CouponValidation {
  const CouponValidation({
    required this.isValid,
    this.message,
    this.coupon,
    this.originalAmount,
    this.discountAmount,
    this.finalAmount,
  });

  final bool isValid;

  /// Server-supplied text, shown as-is when a coupon is rejected.
  final String? message;

  final CouponModel? coupon;
  final double? originalAmount;
  final double? discountAmount;
  final double? finalAmount;

  factory CouponValidation.invalid(String? message) =>
      CouponValidation(isValid: false, message: message);

  factory CouponValidation.fromJson(Map<String, dynamic> json, {String? message}) {
    return CouponValidation(
      isValid: true,
      message: message,
      coupon: CouponModel.fromJson(json),
      originalAmount: _asDouble(json['originalAmount']),
      discountAmount: _asDouble(json['discountAmount']),
      finalAmount: _asDouble(json['finalAmount']),
    );
  }
}

int? _asInt(Object? value) =>
    value is int ? value : int.tryParse(value?.toString() ?? '');

double? _asDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

String? _asString(Object? value) {
  final text = value?.toString().trim();
  return (text == null || text.isEmpty) ? null : text;
}

DateTime? _asDate(Object? value) {
  final text = _asString(value);
  return text == null ? null : DateTime.tryParse(text);
}
