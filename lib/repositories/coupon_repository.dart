import '../core/config/api_config.dart';
import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../core/utils/app_logger.dart';
import '../models/coupon_model.dart';

/// `GET /coupons/active` — offers that can be applied to a booking.
class CouponRepository {
  CouponRepository._();

  static final CouponRepository instance = CouponRepository._();

  final ApiClient _api = ApiClient.instance;

  /// Coupons currently on offer for [appliesTo] ("Event", "Facility", …).
  ///
  /// Returns an empty list rather than throwing — an offers strip is never
  /// worth failing a screen over.
  Future<List<CouponModel>> fetchActiveCoupons({
    String appliesTo = 'Event',
  }) async {
    try {
      final response = await _api.get(
        ApiEndpoints.activeCoupons,
        query: {'appliesTo': appliesTo},
        // Without this the backend cannot tell app traffic from web traffic,
        // and App-only coupons would be withheld from the app itself.
        headers: ApiConfig.platformHeader,
      );

      if (!response.isOk) return const <CouponModel>[];

      final body = response.data;
      final data = body is Map ? body['data'] : null;

      // `data` is a bare list today; tolerate a paginated wrapper too.
      final raw = data is Map ? (data['coupons'] ?? data['data']) : data;

      return CouponModel.listFrom(raw).where((c) => c.isUsable).toList();
    } catch (e) {
      AppLogger.error('Could not load coupons', name: 'Coupons', error: e);
      return const <CouponModel>[];
    }
  }

  /// `POST /coupons/validate` — the server decides whether [code] applies to
  /// [amount] and how much comes off.
  ///
  /// [sportComplexId] scopes venue-specific coupons; null means "any venue",
  /// which is what the site sends for events that are not venue-bound.
  /// [sportId] and [eventPassId] scope it further where the checkout knows
  /// them — a coupon issued for one sport or one event must not come off a
  /// booking for another.
  ///
  /// The nulls are sent explicitly rather than omitted: the documented body
  /// carries all five keys, and an absent key is not the same as a null one to
  /// a validator that reads them positionally.
  Future<CouponValidation> validateCoupon({
    required String code,
    required num amount,
    String appliesTo = 'Event',
    int? sportComplexId,
    int? sportId,
    int? eventPassId,
  }) async {
    try {
      final response = await _api.post(
        ApiEndpoints.validateCoupon,
        headers: ApiConfig.platformHeader,
        body: {
          'code': code,
          'amount': amount is int ? amount : amount.round(),
          'appliesTo': appliesTo,
          'sportComplexId': sportComplexId,
          'sportId': sportId,
          'eventPassId': eventPassId,
        },
      );

      final body = response.data;
      final message = response.message;

      if (!response.isOk) {
        return CouponValidation.invalid(message ?? 'Invalid coupon code');
      }

      final data = body is Map ? body['data'] : null;
      if (data is! Map) {
        return CouponValidation.invalid(message ?? 'Invalid coupon code');
      }

      return CouponValidation.fromJson(
        Map<String, dynamic>.from(data),
        message: message,
      );
    } on ApiException catch (e) {
      // A rejected coupon comes back as 4xx with the reason in the body.
      AppLogger.debug('Coupon $code rejected: ${e.message}', name: 'Coupons');
      return CouponValidation.invalid(e.message);
    } catch (e) {
      AppLogger.error('Could not validate coupon', name: 'Coupons', error: e);
      return CouponValidation.invalid('Could not check that coupon. Try again.');
    }
  }
}
