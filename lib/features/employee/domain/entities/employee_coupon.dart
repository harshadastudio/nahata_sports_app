import 'employee_formats.dart';

/// A discount coupon, from `GET /admin/coupons`.
///
/// Note the `/admin` prefix on the route: coupon administration is a different
/// route family from the two customer-facing `/coupons/*` endpoints, not a
/// variant of them. EMPLOYEE is granted it, and `complexScope` narrows the rows
/// to the employee's own complex.
class EmployeeCoupon {
  const EmployeeCoupon({
    required this.id,
    this.code = '',
    this.discountType = 'Percentage',
    this.discountValue = 0,
    this.maxDiscount,
    this.description,
    this.validFrom,
    this.validUntil,
    this.usageLimit,
    this.usedCount = 0,
    this.status = 'Active',
    this.appliesTo = 'Court',
    this.platform = 'All',
    this.createdAt,
  });

  final int id;

  /// Always uppercase — the API uppercases it on create, and it cannot be
  /// changed afterwards.
  final String code;

  /// `Percentage` | `Flat`.
  final String discountType;
  final num discountValue;

  /// The cap on a percentage discount. Null means uncapped, which is different
  /// from a cap of zero, so it stays nullable.
  final num? maxDiscount;

  final String? description;

  final DateTime? validFrom;
  final DateTime? validUntil;

  /// Total redemptions allowed. Null means unlimited.
  final int? usageLimit;
  final int usedCount;

  /// `Active` | `Expired` — the stored state. A coupon is retired by moving it
  /// to `Expired`; there is no separate inactive state on this route.
  final String status;

  /// `Court` | `Event` — what the code may be spent on.
  final String appliesTo;

  /// `All` | `App` | `Web`. The backend enforces this from the
  /// `x-client-platform` header the customer endpoints send.
  final String platform;

  final DateTime? createdAt;

  String get displayCode => code.trim().isEmpty ? 'Coupon #$id' : code.trim();

  bool get isPercentage => discountType.toLowerCase() == 'percentage';

  bool get isActive => status.toLowerCase() == 'active';

  /// `20% off` / `₹100 off`, and `20% off (max ₹150)` when a cap applies.
  String get discountLabel {
    final base = isPercentage
        ? '${_trimZeros(discountValue)}% off'
        : '${formatRupees(discountValue)} off';

    final cap = maxDiscount;
    if (isPercentage && cap != null && cap > 0) {
      return '$base (max ${formatRupees(cap)})';
    }
    return base;
  }

  /// `120 / 500 used`, or `120 used` when the coupon is uncapped.
  String get usageLabel {
    final limit = usageLimit;
    if (limit == null || limit <= 0) return '$usedCount used';
    return '$usedCount / $limit used';
  }

  /// True only when the coupon actually reported a limit and has reached it.
  bool get isExhausted {
    final limit = usageLimit;
    if (limit == null || limit <= 0) return false;
    return usedCount >= limit;
  }

  /// True when [validUntil] is in the past. An absent expiry never counts as
  /// expired — "no end date" is a valid coupon, not a broken one.
  bool get isExpired {
    final end = validUntil;
    if (end == null) return false;
    return end.isBefore(DateTime.now());
  }

  /// What the row should actually read as, which is not always [status]: a
  /// coupon can be stored as Active and still be spent or out of date.
  ///
  /// A status the API sends that this build does not know is shown as it came
  /// rather than forced into one of the two — the vocabulary is the server's.
  String get effectiveStatus {
    if (!isActive) return status.trim().isEmpty ? 'Expired' : status.trim();
    if (isExpired) return 'Expired';
    if (isExhausted) return 'Exhausted';
    return 'Active';
  }

  /// Whether the code can still be redeemed right now.
  bool get isRedeemable => isActive && !isExpired && !isExhausted;

  String get validUntilLabel => formatDay(validUntil);

  static String _trimZeros(num value) {
    if (value == value.roundToDouble()) return value.round().toString();
    return value.toString();
  }

  @override
  String toString() => 'EmployeeCoupon($id, $code, $effectiveStatus)';
}

/// The create/edit form behind `POST /admin/coupons` and
/// `PUT /admin/coupons/{id}`.
///
/// `code` is write-once: the API uppercases it on create and refuses to change
/// it afterwards, so [toJson] only sends it when [isEdit] is false rather than
/// letting an edit fail on a field the form did not mean to touch.
class EmployeeCouponDraft {
  const EmployeeCouponDraft({
    this.code = '',
    this.discountType = 'Percentage',
    this.discountValue,
    this.maxDiscount,
    this.description,
    this.validUntil,
    this.usageLimit,
    this.status = 'Active',
    this.appliesTo = 'Court',
    this.platform = 'All',
    this.isEdit = false,
  });

  final String code;
  final String discountType;
  final num? discountValue;
  final num? maxDiscount;
  final String? description;
  final DateTime? validUntil;
  final int? usageLimit;
  final String status;
  final String appliesTo;
  final String platform;

  /// True when this drafts a `PUT`, which must not carry `code`.
  final bool isEdit;

  static const List<String> discountTypes = ['Percentage', 'Flat'];

  /// The two the API accepts. `Expired` is how a coupon is retired — there is
  /// no `Inactive` on this route.
  static const List<String> statuses = ['Active', 'Expired'];

  static const List<String> appliesToOptions = ['Court', 'Event'];

  /// `Web`-only and `App`-only codes are enforced server-side from the
  /// `X-Client-Platform` header, not from this field — it only records intent.
  static const List<String> platforms = ['All', 'Web', 'App'];

  /// The server's own rule: code, discountType, discountValue and validUntil
  /// are required on create. Checked here so the form can refuse before the
  /// round trip.
  String? get validationError {
    if (!isEdit && code.trim().isEmpty) return 'Enter a coupon code.';

    final value = discountValue;
    if (value == null || value <= 0) {
      return 'Enter a discount greater than zero.';
    }
    if (discountType.toLowerCase() == 'percentage' && value > 100) {
      return 'A percentage discount cannot be more than 100.';
    }
    if (validUntil == null) return 'Choose the date this coupon expires.';

    return null;
  }

  Map<String, dynamic> toJson() {
    final body = <String, dynamic>{
      // Uppercased here as well as server-side, so the value the form shows
      // after a save matches what was actually stored.
      if (!isEdit) 'code': code.trim().toUpperCase(),
      'discountType': discountType,
      'discountValue': discountValue,
      'status': status,
      'appliesTo': appliesTo,
      'platform': platform,
    };

    final end = validUntil;
    if (end != null) body['validUntil'] = formatIsoDate(end);

    // Explicit null clears the cap, which is the documented way to remove one —
    // so this is sent even when null, unlike the optional text fields below.
    body['maxDiscount'] =
        discountType.toLowerCase() == 'percentage' ? maxDiscount : null;

    final note = description?.trim();
    if (note != null && note.isNotEmpty) body['description'] = note;

    final limit = usageLimit;
    if (limit != null && limit > 0) body['usageLimit'] = limit;

    return body;
  }
}
