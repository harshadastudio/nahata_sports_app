import '../../../../models/sports_complex_model.dart';
import '../entities/coupon.dart';
import '../entities/event_pass.dart';
import '../entities/paged.dart';
import '../entities/sport.dart';

/// The whole coupon module: administration, validation and the customer's
/// active list.
///
/// Business rules the implementation enforces before anything leaves the
/// device, because the server can only answer with a rejection:
///
/// * a coupon targets exactly one scope — Court **or** Event, never both,
/// * code, discount type, discount value and valid-until are required,
/// * a percentage discount cannot exceed 100.
abstract class CouponsRepository {
  /// `GET /admin/coupons?page=&limit=&search=`
  Future<Paged<AdminCoupon>> getCoupons({
    int page,
    int limit,
    String? search,
    String? status,
  });

  /// `GET /admin/coupons/{couponId}`
  Future<AdminCoupon> getCouponById(int id);

  /// `GET /admin/coupons/code/{couponCode}`
  ///
  /// Returns null when no coupon carries the code — the create form asks this
  /// to refuse a duplicate before posting, and "not found" is the good answer
  /// there, not an error.
  Future<AdminCoupon?> getCouponByCode(String code);

  /// `POST /admin/coupons`
  Future<AdminCoupon> createCoupon(CouponDraft draft);

  /// `PUT /admin/coupons/{couponId}`
  Future<AdminCoupon> updateCoupon(int id, CouponDraft draft);

  /// `DELETE /admin/coupons/{couponId}`
  Future<void> deleteCoupon(int id);

  /// `POST /coupons/validate` — what a shopper would get for [code] on
  /// [amount], decided entirely by the server.
  ///
  /// A rejected coupon is a result, not an exception: it comes back as a
  /// [CouponCheck] carrying the backend's own message. Only transport and
  /// session failures propagate.
  Future<CouponCheck> validateCoupon({
    required String code,
    required num amount,
    required CouponAppliesTo appliesTo,
    int? sportComplexId,
    int? sportId,
    int? eventPassId,
  });

  /// `GET /coupons/active?appliesTo=` — what the app would currently offer.
  Future<List<AdminCoupon>> getActiveCoupons({CouponAppliesTo? appliesTo});

  /// Venues for the form, from `GET /sports-complexes`.
  Future<List<SportsComplex>> fetchSportComplexes({bool refresh});

  /// Sports for the form, from `GET /sports`.
  Future<List<Sport>> fetchSports({bool refresh});

  /// Events for the form's Event scope, from `GET /event-passes`.
  Future<List<AdminEventPass>> fetchEventPasses({bool refresh});
}
