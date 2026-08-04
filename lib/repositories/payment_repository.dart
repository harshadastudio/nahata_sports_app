import '../core/config/api_config.dart';
import '../core/network/api_client.dart';
import '../core/utils/app_logger.dart';

/// Booking kinds accepted by `/payments/*`.
class BookingType {
  const BookingType._();

  static const String facility = 'facility';
  static const String event = 'event';
}

/// A Razorpay order created by `POST /payments/create-order`.
///
/// The key id comes back with the order, so nothing Razorpay-specific is
/// hardcoded in the app.
class PaymentOrder {
  const PaymentOrder({
    required this.orderId,
    required this.amountPaise,
    required this.currency,
    required this.keyId,
  });

  final String orderId;

  /// Razorpay works in paise; the request sends rupees.
  final int amountPaise;

  final String currency;
  final String keyId;

  static PaymentOrder? fromJson(Object? data) {
    if (data is! Map) return null;

    final orderId = data['orderId']?.toString();
    final keyId = data['keyId']?.toString();
    if (orderId == null || orderId.isEmpty || keyId == null || keyId.isEmpty) {
      return null;
    }

    final amount = data['amount'];
    return PaymentOrder(
      orderId: orderId,
      amountPaise:
          amount is int ? amount : int.tryParse(amount?.toString() ?? '') ?? 0,
      currency: data['currency']?.toString() ?? 'INR',
      keyId: keyId,
    );
  }
}

/// `POST /payments/create-order` and `POST /payments/verify`.
class PaymentRepository {
  PaymentRepository._();

  static final PaymentRepository instance = PaymentRepository._();

  final ApiClient _api = ApiClient.instance;

  /// Creates the Razorpay order for [bookingId].
  ///
  /// [amount] is in **rupees** — the response echoes it back in paise.
  /// Returns null when the order could not be created.
  Future<PaymentOrder?> createOrder({
    required String bookingType,
    required int bookingId,
    required num amount,
  }) async {
    try {
      final response = await _api.post(
        ApiEndpoints.createOrder,
        body: {
          'bookingType': bookingType,
          'bookingId': bookingId,
          'amount': amount is int ? amount : amount.round(),
        },
      );

      if (!response.isOk) {
        AppLogger.error(
          'create-order failed: ${response.message}',
          name: 'Payments',
        );
        return null;
      }

      final body = response.data;
      return PaymentOrder.fromJson(body is Map ? body['data'] : null);
    } catch (e) {
      AppLogger.error('create-order error', name: 'Payments', error: e);
      return null;
    }
  }

  /// Confirms the payment against the booking. True when the server accepted
  /// the Razorpay signature.
  Future<bool> verifyPayment({
    required String bookingType,
    required int bookingId,
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    try {
      final response = await _api.post(
        ApiEndpoints.verifyPayment,
        body: {
          'bookingType': bookingType,
          'bookingId': bookingId,
          'razorpay_order_id': orderId,
          'razorpay_payment_id': paymentId,
          'razorpay_signature': signature,
        },
      );

      if (!response.isOk) {
        AppLogger.error(
          'verify failed: ${response.message}',
          name: 'Payments',
        );
      }
      return response.isOk;
    } catch (e) {
      AppLogger.error('verify error', name: 'Payments', error: e);
      return false;
    }
  }
}
