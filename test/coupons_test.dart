import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nahata_app/core/network/api_client.dart';
import 'package:nahata_app/core/storage/token_storage.dart';
import 'package:nahata_app/models/coupon_model.dart';
import 'package:nahata_app/repositories/coupon_repository.dart';

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

  void serve(Object body, {int status = 200}) {
    ApiClient.instance.overrideHttpClient(MockClient((request) async {
      requests.add(request);
      return http.Response(jsonEncode(body), status);
    }));
  }

  Map<String, dynamic> lastBody() =>
      jsonDecode(requests.last.body) as Map<String, dynamic>;

  group('GET /coupons/active', () {
    test('asks for the event coupons', () async {
      serve({'success': true, 'data': []});
      await CouponRepository.instance.fetchActiveCoupons();

      expect(requests.single.url.path, '/api/coupons/active');
      expect(requests.single.url.queryParameters['appliesTo'], 'Event');
    });

    test('names the event and venue, so a scoped coupon can match', () async {
      // The server matches each scope as "unscoped OR equal to this", so a
      // coupon tied to one event never comes back unless the request says
      // which event. Leaving these out is what kept the live "TEST" coupon —
      // Active, 10%, scoped to Test Event — off the offers strip.
      serve({'success': true, 'data': []});

      await CouponRepository.instance.fetchActiveCoupons(
        appliesTo: 'Event',
        eventPassId: 9,
        sportComplexId: 1,
      );

      final query = requests.single.url.queryParameters;
      expect(query['appliesTo'], 'Event');
      expect(query['eventPassId'], '9');
      expect(query['sportComplexId'], '1');
    });

    test('names the venue and sport for a court booking', () async {
      serve({'success': true, 'data': []});

      await CouponRepository.instance.fetchActiveCoupons(
        appliesTo: 'Court',
        sportComplexId: 1,
        sportId: 19,
      );

      final query = requests.single.url.queryParameters;
      expect(query['appliesTo'], 'Court');
      expect(query['sportComplexId'], '1');
      expect(query['sportId'], '19');
    });

    test('a scope the screen does not know is left out entirely', () async {
      // Sending an explicit null would narrow the match to unscoped coupons —
      // the opposite of what an unknown scope should mean.
      serve({'success': true, 'data': []});

      await CouponRepository.instance.fetchActiveCoupons(appliesTo: 'Event');

      final query = requests.single.url.queryParameters;
      expect(query.containsKey('eventPassId'), isFalse);
      expect(query.containsKey('sportComplexId'), isFalse);
      expect(query.containsKey('sportId'), isFalse);
    });

    test('the live empty response yields no coupons', () async {
      // Verbatim: {"success":true,"data":[]}
      serve({'success': true, 'data': []});

      expect(await CouponRepository.instance.fetchActiveCoupons(), isEmpty);
    });

    test('parses a coupon list', () async {
      serve({
        'success': true,
        'data': [
          {
            'id': 3,
            'code': 'HOLI20',
            'title': 'Holi offer',
            'description': '20% off event passes',
            'discountType': 'Percentage',
            'discountValue': 20,
            'maxDiscount': 100,
            'minOrderAmount': 200,
            'appliesTo': 'Event',
            'status': 'Active',
          }
        ]
      });

      final coupon = (await CouponRepository.instance.fetchActiveCoupons())
          .single;

      expect(coupon.id, 3);
      expect(coupon.code, 'HOLI20');
      expect(coupon.isPercentage, isTrue);
      expect(coupon.discountValue, 20);
      expect(coupon.maxDiscount, 100);
      expect(coupon.minOrderAmount, 200);
      expect(coupon.shortLabel, '20% OFF');
    });

    test('drops coupons that are inactive or out of their validity window',
        () async {
      serve({
        'success': true,
        'data': [
          {'id': 1, 'code': 'LIVE', 'discountValue': 10, 'status': 'Active'},
          {'id': 2, 'code': 'OFF', 'discountValue': 10, 'status': 'Inactive'},
          {
            'id': 3,
            'code': 'EXPIRED',
            'discountValue': 10,
            'status': 'Active',
            'validTill': '2020-01-01'
          },
          {
            'id': 4,
            'code': 'FUTURE',
            'discountValue': 10,
            'status': 'Active',
            'validFrom': '2099-01-01'
          },
        ]
      });

      final coupons = await CouponRepository.instance.fetchActiveCoupons();
      expect(coupons.map((c) => c.code), ['LIVE']);
    });

    test('a failing request leaves the screen without offers, not an error',
        () async {
      serve({'success': false, 'message': 'nope'}, status: 500);

      expect(await CouponRepository.instance.fetchActiveCoupons(), isEmpty);
    });

    test('parses the live NAHATA10 payload', () {
      // Verbatim from /coupons/active?appliesTo=Event — note the decimal
      // strings and `validUntil`.
      const json = <String, dynamic>{
        'id': 3,
        'code': 'NAHATA10',
        'discountType': 'Percentage',
        'discountValue': '10.00',
        'maxDiscount': '150.00',
        'description': null,
        'validUntil': '2026-07-31T00:00:00.000Z',
        'usageLimit': 5,
        'usedCount': 1,
        'appliesTo': 'Event',
        'sportComplexId': null,
      };

      final coupon = CouponModel.fromJson(json);

      expect(coupon.id, 3);
      expect(coupon.code, 'NAHATA10');
      expect(coupon.isPercentage, isTrue);
      expect(coupon.discountValue, 10);
      expect(coupon.maxDiscount, 150);
      expect(coupon.description, isNull);
      expect(coupon.validTill, DateTime.parse('2026-07-31T00:00:00.000Z'));
      expect(coupon.usageLimit, 5);
      expect(coupon.usedCount, 1);
      expect(coupon.sportComplexId, isNull);
      expect(coupon.isExhausted, isFalse);
      expect(coupon.shortLabel, '10% OFF');

      // The captured coupon expired on 2026-07-31, so `discountFor` on it
      // correctly returns nothing once that date has passed. The arithmetic is
      // therefore asserted on the same coupon with a validity that has not run
      // out — otherwise this test would start failing on 2026-08-01 for a
      // reason that has nothing to do with parsing.
      expect(coupon.isWithinValidity, isFalse);
      expect(coupon.discountFor(200), 0);

      final live = CouponModel.fromJson({
        ...json,
        'validUntil': DateTime.now()
            .add(const Duration(days: 30))
            .toIso8601String(),
      });

      // 10% of 200, well under the ₹150 cap — matches the server's answer.
      expect(live.discountFor(200), 20);
    });

    test('drops a coupon whose usage limit is spent', () async {
      serve({
        'success': true,
        'data': [
          {
            'id': 3,
            'code': 'SPENT',
            'discountValue': '10.00',
            'validUntil': '2099-01-01T00:00:00.000Z',
            'usageLimit': 5,
            'usedCount': 5,
          },
          {
            'id': 4,
            'code': 'LEFT',
            'discountValue': '10.00',
            'validUntil': '2099-01-01T00:00:00.000Z',
            'usageLimit': 5,
            'usedCount': 4,
          },
        ]
      });

      final coupons = await CouponRepository.instance.fetchActiveCoupons();
      expect(coupons.map((c) => c.code), ['LEFT']);
    });

    test('tolerates a paginated wrapper around the list', () async {
      serve({
        'success': true,
        'data': {
          'coupons': [
            {'id': 1, 'code': 'WRAPPED', 'discountValue': 5, 'status': 'Active'}
          ]
        }
      });

      final coupons = await CouponRepository.instance.fetchActiveCoupons();
      expect(coupons.single.code, 'WRAPPED');
    });
  });

  group('POST /coupons/validate', () {
    /// Verbatim response for NAHATA10 on a ₹200 booking.
    const validResponse = {
      'success': true,
      'message': 'Coupon is valid',
      'data': {
        'id': 3,
        'code': 'NAHATA10',
        'discountType': 'Percentage',
        'discountValue': 10,
        'maxDiscount': 150,
        'description': null,
        'validUntil': '2026-07-31T00:00:00.000Z',
        'discountAmount': 20,
        'finalAmount': 180,
        'originalAmount': 200,
      }
    };

    test('sends the documented body', () async {
      serve(validResponse);

      await CouponRepository.instance.validateCoupon(
        code: 'NAHATA10',
        amount: 200,
      );

      expect(requests.single.url.path, '/api/coupons/validate');
      // Every documented key travels, nulls included — an absent key is not
      // the same as a null one to a validator that reads the scope.
      expect(lastBody(), {
        'code': 'NAHATA10',
        'amount': 200,
        'appliesTo': 'Event',
        'sportComplexId': null,
        'sportId': null,
        'eventPassId': null,
      });
    });

    test('carries the platform header the backend enforces coupons with',
        () async {
      serve(validResponse);

      await CouponRepository.instance.validateCoupon(
        code: 'NAHATA10',
        amount: 200,
      );

      // Without this the backend cannot tell app traffic from web traffic,
      // and App-only coupons would be withheld from the app itself.
      expect(requests.single.headers['x-client-platform'], 'android');
    });

    test('passes the sport and the event through when the checkout knows them',
        () async {
      serve(validResponse);

      await CouponRepository.instance.validateCoupon(
        code: 'NAHATA10',
        amount: 200,
        sportId: 7,
        eventPassId: 31,
      );

      expect(lastBody()['sportId'], 7);
      expect(lastBody()['eventPassId'], 31);
    });

    test('passes the venue through when the event has one', () async {
      serve(validResponse);

      await CouponRepository.instance.validateCoupon(
        code: 'NAHATA10',
        amount: 200,
        sportComplexId: 2,
      );

      expect(lastBody()['sportComplexId'], 2);
    });

    test('reads the server-calculated amounts', () async {
      serve(validResponse);

      final result = await CouponRepository.instance
          .validateCoupon(code: 'NAHATA10', amount: 200);

      expect(result.isValid, isTrue);
      expect(result.message, 'Coupon is valid');
      expect(result.originalAmount, 200);
      expect(result.discountAmount, 20);
      expect(result.finalAmount, 180);
      expect(result.coupon?.code, 'NAHATA10');
      expect(result.coupon?.maxDiscount, 150);
    });

    test('a fractional amount is sent in whole rupees', () async {
      serve(validResponse);

      await CouponRepository.instance
          .validateCoupon(code: 'NAHATA10', amount: 199.6);

      expect(lastBody()['amount'], 200);
    });

    test('a rejected coupon surfaces the server message', () async {
      serve({'success': false, 'message': 'Coupon has expired'}, status: 400);

      final result = await CouponRepository.instance
          .validateCoupon(code: 'OLD', amount: 200);

      expect(result.isValid, isFalse);
      expect(result.message, 'Coupon has expired');
      expect(result.discountAmount, isNull);
    });

    test('a success without data is treated as invalid', () async {
      serve({'success': true, 'message': 'Coupon is valid'});

      final result = await CouponRepository.instance
          .validateCoupon(code: 'NAHATA10', amount: 200);

      expect(result.isValid, isFalse);
    });
  });

  group('discount maths', () {
    CouponModel coupon(Map<String, dynamic> json) => CouponModel.fromJson(json);

    test('percentage off, capped by maxDiscount', () {
      final c = coupon({
        'code': 'P20',
        'discountType': 'Percentage',
        'discountValue': 20,
        'maxDiscount': 100,
      });

      expect(c.discountFor(200), 40);
      expect(c.discountFor(1000), 100); // cap
    });

    test('flat amount off', () {
      final c = coupon({
        'code': 'FLAT50',
        'discountType': 'Fixed',
        'discountValue': 50,
      });

      expect(c.discountFor(200), 50);
      expect(c.shortLabel, '₹50 OFF');
    });

    test('never discounts more than the amount itself', () {
      final c = coupon({
        'code': 'BIG',
        'discountType': 'Fixed',
        'discountValue': 500,
      });

      expect(c.discountFor(200), 200);
    });

    test('nothing off below the minimum order value', () {
      final c = coupon({
        'code': 'MIN300',
        'discountType': 'Percentage',
        'discountValue': 10,
        'minOrderAmount': 300,
      });

      expect(c.meetsMinimum(200), isFalse);
      expect(c.discountFor(200), 0);
      expect(c.discountFor(300), 30);
    });

    test('an unusable coupon discounts nothing', () {
      final expired = coupon({
        'code': 'OLD',
        'discountValue': 50,
        'discountType': 'Fixed',
        'validTill': '2020-01-01',
      });

      expect(expired.isUsable, isFalse);
      expect(expired.discountFor(500), 0);
    });

    test('reads snake_case field names too', () {
      final c = coupon({
        'coupon_code': 'SNAKE',
        'discount_type': 'percentage',
        'discount_value': '15',
        'min_order_amount': '100',
      });

      expect(c.code, 'SNAKE');
      expect(c.isPercentage, isTrue);
      expect(c.discountFor(200), 30);
    });
  });
}
