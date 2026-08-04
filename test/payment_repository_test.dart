import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nahata_app/core/network/api_client.dart';
import 'package:nahata_app/core/storage/token_storage.dart';
import 'package:nahata_app/repositories/payment_repository.dart';

final Map<String, String> _secureStore = <String, String>{};

void _mockSecureStorage() {
  const channel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall call) async {
    final args = (call.arguments as Map?)?.cast<String, dynamic>() ?? {};
    final key = args['key'] as String?;
    switch (call.method) {
      case 'read':
        return _secureStore[key];
      case 'write':
        _secureStore[key!] = args['value'] as String;
        return null;
      case 'delete':
        _secureStore.remove(key);
        return null;
      case 'readAll':
        return Map<String, String>.from(_secureStore);
      default:
        return null;
    }
  });
}

/// Verbatim response to `POST /payments/create-order`.
const String _orderJson = '''
{
  "success": true,
  "data": {
    "orderId": "order_TJcBHy6zz7XCk0",
    "amount": 20000,
    "currency": "INR",
    "keyId": "rzp_test_SXk5CPBTFyKNac"
  }
}
''';

/// Verbatim response to `POST /payments/verify`.
const String _verifyJson = '''
{
  "success": true,
  "message": "Payment verified successfully",
  "data": {
    "paymentId": "pay_TJcFjWaEXN7lJf",
    "orderId": "order_TJcBHy6zz7XCk0"
  }
}
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<http.Request> requests;

  setUp(() async {
    _secureStore.clear();
    SharedPreferences.setMockInitialValues({});
    _mockSecureStorage();

    await TokenStorage.instance.clear();
    await TokenStorage.instance
        .saveTokens(accessToken: 'access-1', refreshToken: 'refresh-1');

    requests = <http.Request>[];
  });

  tearDown(() => ApiClient.instance.overrideHttpClient(http.Client()));

  void serve(String body, {int status = 200}) {
    ApiClient.instance.overrideHttpClient(MockClient((request) async {
      requests.add(request);
      return http.Response(body, status);
    }));
  }

  Map<String, dynamic> lastBody() =>
      jsonDecode(requests.last.body) as Map<String, dynamic>;

  group('create-order', () {
    test('sends the documented body for an event booking', () async {
      serve(_orderJson);

      await PaymentRepository.instance.createOrder(
        bookingType: BookingType.event,
        bookingId: 19,
        amount: 200,
      );

      expect(requests.single.url.path, '/api/payments/create-order');
      expect(requests.single.method, 'POST');
      expect(lastBody(), {
        'bookingType': 'event',
        'bookingId': 19,
        'amount': 200,
      });
    });

    test('amount goes in rupees, even when the total is fractional', () async {
      serve(_orderJson);

      await PaymentRepository.instance.createOrder(
        bookingType: BookingType.event,
        bookingId: 19,
        amount: 199.6,
      );

      expect(lastBody()['amount'], 200);
    });

    test('carries the bearer token', () async {
      serve(_orderJson);

      await PaymentRepository.instance.createOrder(
        bookingType: BookingType.event,
        bookingId: 19,
        amount: 200,
      );

      expect(requests.single.headers['Authorization'], 'Bearer access-1');
    });

    test('reads the order, its amount in paise and the Razorpay key',
        () async {
      serve(_orderJson);

      final order = await PaymentRepository.instance.createOrder(
        bookingType: BookingType.event,
        bookingId: 19,
        amount: 200,
      );

      expect(order, isNotNull);
      expect(order!.orderId, 'order_TJcBHy6zz7XCk0');
      expect(order.amountPaise, 20000);
      expect(order.currency, 'INR');
      expect(order.keyId, 'rzp_test_SXk5CPBTFyKNac');
    });

    test('a rejected order yields null rather than an exception', () async {
      serve(jsonEncode({'success': false, 'message': 'Booking not found'}),
          status: 400);

      final order = await PaymentRepository.instance.createOrder(
        bookingType: BookingType.event,
        bookingId: 19,
        amount: 200,
      );

      expect(order, isNull);
    });

    test('an order without a keyId is not usable', () async {
      serve(jsonEncode({
        'success': true,
        'data': {'orderId': 'order_1', 'amount': 20000}
      }));

      expect(
        await PaymentRepository.instance.createOrder(
          bookingType: BookingType.event,
          bookingId: 19,
          amount: 200,
        ),
        isNull,
      );
    });
  });

  group('verify', () {
    test('sends the booking alongside the Razorpay triple', () async {
      serve(_verifyJson);

      final ok = await PaymentRepository.instance.verifyPayment(
        bookingType: BookingType.event,
        bookingId: 19,
        orderId: 'order_TJcBHy6zz7XCk0',
        paymentId: 'pay_TJcFjWaEXN7lJf',
        signature: 'sig-1',
      );

      expect(ok, isTrue);
      expect(requests.single.url.path, '/api/payments/verify');
      expect(lastBody(), {
        'bookingType': 'event',
        'bookingId': 19,
        'razorpay_order_id': 'order_TJcBHy6zz7XCk0',
        'razorpay_payment_id': 'pay_TJcFjWaEXN7lJf',
        'razorpay_signature': 'sig-1',
      });
    });

    test('a failed verification reports false, not a crash', () async {
      serve(jsonEncode({'success': false, 'message': 'Invalid signature'}),
          status: 400);

      final ok = await PaymentRepository.instance.verifyPayment(
        bookingType: BookingType.event,
        bookingId: 19,
        orderId: 'order_1',
        paymentId: 'pay_1',
        signature: 'bad',
      );

      expect(ok, isFalse);
    });

    test('facility bookings use the same endpoint with their own type',
        () async {
      serve(_verifyJson);

      await PaymentRepository.instance.verifyPayment(
        bookingType: BookingType.facility,
        bookingId: 64,
        orderId: 'order_1',
        paymentId: 'pay_1',
        signature: 'sig-1',
      );

      expect(lastBody()['bookingType'], 'facility');
    });
  });
}
