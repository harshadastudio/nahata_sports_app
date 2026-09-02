import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nahata_app/core/network/api_client.dart';
import 'package:nahata_app/core/network/api_exception.dart';
import 'package:nahata_app/core/storage/profile_cache.dart';
import 'package:nahata_app/features/admin/data/models/coupon_admin_model.dart';
import 'package:nahata_app/features/admin/data/repositories/coupons_repository_impl.dart';
import 'package:nahata_app/features/admin/domain/entities/admin_role.dart';
import 'package:nahata_app/features/admin/domain/entities/coupon.dart';
import 'package:nahata_app/features/admin/domain/entities/event_pass.dart';
import 'package:nahata_app/features/admin/domain/entities/paged.dart';
import 'package:nahata_app/features/admin/domain/entities/sport.dart';
import 'package:nahata_app/features/admin/domain/repositories/coupons_repository.dart';
import 'package:nahata_app/features/admin/presentation/state/coupons_controller.dart';
import 'package:nahata_app/features/admin/presentation/state/view_state.dart';
import 'package:nahata_app/models/sports_complex_model.dart';

final Map<String, String> _secureStore = <String, String>{};

void _mockSecureStorage() {
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
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

AdminCoupon _coupon({
  int id = 1,
  String code = 'WELCOME10',
  String type = 'Percentage',
  num value = 10,
  String appliesTo = 'Court',
  String platform = 'All',
  String status = 'Active',
  DateTime? validUntil,
  int? usageLimit,
  int? usedCount,
}) {
  return AdminCoupon(
    id: id,
    code: code,
    description: '10% off your first booking',
    discountTypeRaw: type,
    discountValue: value,
    maxDiscount: 200,
    appliesToRaw: appliesTo,
    platformRaw: platform,
    statusRaw: status,
    usageLimit: usageLimit,
    usedCount: usedCount,
    validUntil: validUntil ?? DateTime(2026, 12, 31),
  );
}

CouponDraft _draft({
  String? code = 'WELCOME10',
  CouponDiscountType? type = CouponDiscountType.percentage,
  num? value = 10,
  DateTime? validUntil,
  CouponAppliesTo? appliesTo = CouponAppliesTo.court,
  int? complexId = 3,
  int? sportId = 7,
  int? eventPassId,
  num? maxDiscount = 200,
  int? usageLimit = 100,
}) {
  return CouponDraft(
    code: code,
    description: '10% off your first booking',
    discountType: type,
    discountValue: value,
    maxDiscount: maxDiscount,
    validUntil: validUntil ?? DateTime(2026, 12, 31),
    usageLimit: usageLimit,
    status: AdminUserStatus.active,
    appliesTo: appliesTo,
    platform: CouponPlatform.all,
    sportComplexId: complexId,
    sportId: sportId,
    eventPassId: eventPassId,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    _secureStore.clear();
    _mockSecureStorage();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    // ProfileCache keeps the last profile in memory for the life of the
    // process, so without this a role read in one test would leak into the
    // next one.
    await ProfileCache.instance.clear();
  });

  tearDown(() => ApiClient.instance.overrideHttpClient(http.Client()));

  // ---------------------------------------------------------------------------
  group('The coupon vocabularies', () {
    test('the wire values are sent exactly as documented', () {
      expect(CouponDiscountType.percentage.slug, 'Percentage');
      expect(CouponDiscountType.fixed.slug, 'Fixed');
      expect(CouponAppliesTo.court.slug, 'Court');
      expect(CouponAppliesTo.event.slug, 'Event');
      expect(CouponPlatform.all.slug, 'All');
      expect(CouponPlatform.web.slug, 'Web');
      expect(CouponPlatform.app.slug, 'App');
    });

    test('spelling drift on the way back in is tolerated', () {
      expect(
        CouponDiscountType.tryParse('percent'),
        CouponDiscountType.percentage,
      );
      expect(CouponDiscountType.tryParse('FLAT'), CouponDiscountType.fixed);
      expect(CouponAppliesTo.tryParse('court'), CouponAppliesTo.court);
      expect(CouponAppliesTo.tryParse('EVENTS'), CouponAppliesTo.event);
      expect(CouponPlatform.tryParse('android'), CouponPlatform.app);
      expect(CouponPlatform.tryParse('website'), CouponPlatform.web);
    });

    test('an unrecognised value stays null rather than being coerced', () {
      expect(CouponDiscountType.tryParse('sliding scale'), isNull);
      expect(CouponAppliesTo.tryParse('membership'), isNull);
      expect(CouponPlatform.tryParse('kiosk'), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  group('AdminCoupon', () {
    test('the discount label reads the way the shop shows it', () {
      expect(_coupon().discountLabel, '10% OFF');
      expect(_coupon(type: 'Fixed', value: 150).discountLabel, '₹150 OFF');
      expect(const AdminCoupon(id: 1).discountLabel, '');
    });

    test('a coupon is live only when nothing has run out', () {
      final now = DateTime(2026, 8, 5);

      expect(_coupon(validUntil: DateTime(2026, 12, 31)).isLiveOn(now), isTrue);
      expect(
        _coupon(validUntil: DateTime(2026, 8, 1)).isLiveOn(now),
        isFalse,
        reason: 'expired',
      );
      expect(
        _coupon(status: 'Inactive').isLiveOn(now),
        isFalse,
        reason: 'switched off',
      );
      expect(
        _coupon(usageLimit: 5, usedCount: 5).isLiveOn(now),
        isFalse,
        reason: 'used up',
      );
    });

    test('validity runs to the end of the last day, not the start of it', () {
      final coupon = _coupon(validUntil: DateTime(2026, 8, 5));
      expect(coupon.hasExpiredOn(DateTime(2026, 8, 5, 23, 0)), isFalse);
      expect(coupon.hasExpiredOn(DateTime(2026, 8, 6, 0, 1)), isTrue);
    });

    test('remaining uses is null when the coupon is unlimited', () {
      expect(_coupon().remainingUses, isNull);
      expect(_coupon(usageLimit: 5, usedCount: 2).remainingUses, 3);
      // Never negative, even if the server over-counted.
      expect(_coupon(usageLimit: 5, usedCount: 9).remainingUses, 0);
    });

    test('the scope line names whatever the coupon is limited to', () {
      expect(_coupon().scopeLabel, 'Everywhere');
      expect(
        const AdminCoupon(
          id: 1,
          sportComplexName: 'Nahata Sports Complex',
          sportName: 'Badminton',
        ).scopeLabel,
        'Nahata Sports Complex · Badminton',
      );
    });
  });

  // ---------------------------------------------------------------------------
  group('CouponDraft', () {
    test('the create body matches the documented shape', () {
      final body = _draft().toCreateJson();

      expect(body['code'], 'WELCOME10');
      expect(body['discountType'], 'Percentage');
      expect(body['discountValue'], 10);
      expect(body['maxDiscount'], 200);
      expect(body['validUntil'], '2026-12-31');
      expect(body['usageLimit'], 100);
      expect(body['status'], 'Active');
      expect(body['appliesTo'], 'Court');
      expect(body['platform'], 'All');
      expect(body['sportComplexId'], 3);
      expect(body['sportId'], 7);
      expect(body['eventPassId'], isNull);
    });

    test('a code is upper-cased on the way out', () {
      expect(_draft(code: 'welcome10').toCreateJson()['code'], 'WELCOME10');
    });

    test('an Event coupon carries no court scope, and the reverse', () {
      final event = _draft(
        appliesTo: CouponAppliesTo.event,
        eventPassId: 31,
      ).toCreateJson();

      // One scope only: the court ids are dropped rather than sent alongside.
      expect(event['eventPassId'], 31);
      expect(event['sportComplexId'], isNull);
      expect(event['sportId'], isNull);

      final court = _draft(eventPassId: 31).toCreateJson();
      expect(court['eventPassId'], isNull);
      expect(court['sportComplexId'], 3);
    });

    test('an update sends only what was touched', () {
      final body = const CouponDraft(
        discountValue: 15,
        status: AdminUserStatus.active,
      ).toUpdateJson();

      expect(body, {'discountValue': 15, 'status': 'Active'});
    });

    test('switching scope in an edit clears the other side explicitly', () {
      // A `put` that skips nulls would leave the old sportId in place, so the
      // scope keys are written directly when appliesTo is part of the edit.
      final body = const CouponDraft(
        appliesTo: CouponAppliesTo.event,
        eventPassId: 31,
      ).toUpdateJson();

      expect(body['eventPassId'], 31);
      expect(body.containsKey('sportComplexId'), isTrue);
      expect(body['sportComplexId'], isNull);
      expect(body['sportId'], isNull);
    });

    test('an untouched draft is an empty update', () {
      expect(const CouponDraft().isEmptyUpdate, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  group('CouponMapper', () {
    test('reads the documented list envelope and its counters', () {
      final page = CouponMapper.pageFrom(
        {
          'success': true,
          'message': 'Success',
          'data': [
            {
              'id': 3,
              'code': 'WELCOME10',
              'discountType': 'Percentage',
              'discountValue': '10.00',
              'maxDiscount': '200.00',
              'appliesTo': 'Court',
              'platform': 'All',
              'status': 'Active',
              'validUntil': '2026-12-31T00:00:00.000Z',
              'usageLimit': 100,
              'usedCount': 4,
            },
            {'id': 4, 'code': 'FLAT50'},
          ],
          'total': 32,
          'page': 2,
          'limit': 20,
        },
        fallbackPage: 1,
        fallbackLimit: 20,
      );

      expect(page.items, hasLength(2));
      expect(page.total, 32);
      expect(page.page, 2);
      expect(page.effectiveTotalPages, 2);

      final coupon = page.items.first;
      // Money comes back as decimal strings on the live payload.
      expect(coupon.discountValue, 10);
      expect(coupon.maxDiscount, 200);
      expect(coupon.discountType, CouponDiscountType.percentage);
      expect(coupon.appliesTo, CouponAppliesTo.court);
      expect(coupon.platform, CouponPlatform.all);
      expect(coupon.usedCount, 4);
    });

    test('snake_case rows read the same as camelCase ones', () {
      final coupon = CouponMapper.fromJson({
        'id': 3,
        'coupon_code': 'WELCOME10',
        'discount_type': 'Fixed',
        'discount_value': 150,
        'max_discount': 300,
        'applies_to': 'Event',
        'valid_until': '2026-12-31',
        'usage_limit': 50,
        'used_count': 2,
        'event_pass_id': 31,
      });

      expect(coupon.code, 'WELCOME10');
      expect(coupon.discountType, CouponDiscountType.fixed);
      expect(coupon.discountValue, 150);
      expect(coupon.appliesTo, CouponAppliesTo.event);
      expect(coupon.eventPassId, 31);
      expect(coupon.validUntil, DateTime.parse('2026-12-31'));
    });

    test('the scope names are read from nested objects', () {
      final coupon = CouponMapper.fromJson({
        'id': 3,
        'code': 'WELCOME10',
        'sportComplex': {'id': 5, 'name': 'Kothrud Arena'},
        'sport': {'id': 9, 'name': 'Badminton'},
      });

      expect(coupon.sportComplexId, 5);
      expect(coupon.sportComplexName, 'Kothrud Arena');
      expect(coupon.sportId, 9);
      expect(coupon.sportName, 'Badminton');
      // The nested records' ids must never become the coupon's own.
      expect(coupon.id, 3);
    });

    test('rows with no id are dropped rather than shown inert', () {
      final coupons = CouponMapper.listFrom({
        'data': [
          {'code': 'GHOST'},
          {'id': 3, 'code': 'REAL'},
        ],
      });

      expect(coupons, hasLength(1));
      expect(coupons.single.code, 'REAL');
    });

    test('a bare envelope carries no coupon', () {
      expect(
        CouponMapper.maybeFromBody({'success': false, 'message': 'Not found'}),
        isNull,
      );
    });

    test('a validation answer keeps the amounts the server calculated', () {
      final check = CouponMapper.checkFrom({
        'success': true,
        'message': 'Coupon is valid',
        'data': {
          'id': 3,
          'code': 'NAHATA10',
          'discountType': 'Percentage',
          'discountValue': 10,
          'discountAmount': 20,
          'finalAmount': 180,
          'originalAmount': 200,
        },
      }, isValid: true);

      expect(check.isValid, isTrue);
      expect(check.message, 'Coupon is valid');
      expect(check.coupon?.code, 'NAHATA10');
      expect(check.originalAmount, 200);
      expect(check.discountAmount, 20);
      expect(check.finalAmount, 180);
    });
  });

  // ---------------------------------------------------------------------------
  group('CouponsRepositoryImpl — the wire', () {
    test('the list route sends paging and only a non-empty search', () async {
      final calls = <Uri>[];

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          calls.add(request.url);
          return http.Response(jsonEncode({'success': true, 'data': []}), 200);
        }),
      );

      final repository = CouponsRepositoryImpl();
      await repository.getCoupons(page: 2, limit: 50);
      await repository.getCoupons(search: 'welcome');

      expect(calls[0].path, endsWith('/admin/coupons'));
      expect(calls[0].queryParameters['page'], '2');
      expect(calls[0].queryParameters['limit'], '50');
      expect(calls[0].queryParameters.containsKey('search'), isFalse);
      expect(calls[1].queryParameters['search'], 'welcome');
    });

    test('detail, update and delete all use the id route', () async {
      final calls = <String>[];

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          calls.add('${request.method} ${request.url.path}');
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {'id': 7, 'code': 'WELCOME10'},
            }),
            200,
          );
        }),
      );

      final repository = CouponsRepositoryImpl();
      await repository.getCouponById(7);
      await repository.updateCoupon(7, const CouponDraft(discountValue: 15));
      await repository.deleteCoupon(7);

      expect(calls[0], 'GET /api/admin/coupons/7');
      expect(calls[1], 'PUT /api/admin/coupons/7');
      expect(calls[2], 'DELETE /api/admin/coupons/7');
    });

    test(
      'the code lookup encodes the segment and answers null on 404',
      () async {
        var path = '';

        ApiClient.instance.overrideHttpClient(
          MockClient((request) async {
            path = request.url.path;
            return http.Response(
              jsonEncode({'success': false, 'message': 'Coupon not found'}),
              404,
            );
          }),
        );

        final found = await CouponsRepositoryImpl().getCouponByCode(
          'SUMMER 25',
        );

        // "No coupon with this code" is the answer the create form wants, not a
        // failure it should surface.
        expect(found, isNull);
        expect(path, contains('/admin/coupons/code/'));
        expect(path, contains('SUMMER%2025'));
      },
    );

    test('create posts the documented body', () async {
      late Map<String, dynamic> body;

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {'id': 12, 'code': 'WELCOME10'},
            }),
            201,
          );
        }),
      );

      final created = await CouponsRepositoryImpl().createCoupon(_draft());

      expect(body['code'], 'WELCOME10');
      expect(body['discountType'], 'Percentage');
      expect(body['validUntil'], '2026-12-31');
      expect(body['platform'], 'All');
      expect(created.id, 12);
    });

    test(
      'a body the server could only reject never leaves the device',
      () async {
        var called = false;
        ApiClient.instance.overrideHttpClient(
          MockClient((request) async {
            called = true;
            return http.Response(jsonEncode({'success': true}), 200);
          }),
        );

        final repository = CouponsRepositoryImpl();

        await expectLater(
          repository.createCoupon(_draft(code: '')),
          throwsA(isA<ValidationException>()),
        );
        await expectLater(
          repository.createCoupon(_draft(type: null)),
          throwsA(isA<ValidationException>()),
        );
        await expectLater(
          repository.createCoupon(_draft(value: null)),
          throwsA(isA<ValidationException>()),
        );
        await expectLater(
          repository.createCoupon(_draft(value: 0)),
          throwsA(isA<ValidationException>()),
        );
        // 110% off would pay the customer to book.
        await expectLater(
          repository.createCoupon(_draft(value: 110)),
          throwsA(isA<ValidationException>()),
        );

        expect(called, isFalse);
      },
    );

    test(
      'a fixed discount over 100 is fine — only percentages are capped',
      () async {
        late Map<String, dynamic> body;

        ApiClient.instance.overrideHttpClient(
          MockClient((request) async {
            body = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {'id': 12, 'code': 'FLAT500'},
              }),
              201,
            );
          }),
        );

        await CouponsRepositoryImpl().createCoupon(
          _draft(code: 'FLAT500', type: CouponDiscountType.fixed, value: 500),
        );

        expect(body['discountValue'], 500);
      },
    );

    test('an empty update is refused before the round trip', () async {
      var called = false;
      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          called = true;
          return http.Response(jsonEncode({'success': true}), 200);
        }),
      );

      await expectLater(
        CouponsRepositoryImpl().updateCoupon(7, const CouponDraft()),
        throwsA(isA<BadRequestException>()),
      );
      expect(called, isFalse);
    });

    test(
      'validate carries the platform header and the whole documented body',
      () async {
        late http.Request captured;

        ApiClient.instance.overrideHttpClient(
          MockClient((request) async {
            captured = request;
            return http.Response(
              jsonEncode({
                'success': true,
                'message': 'Coupon is valid',
                'data': {
                  'id': 3,
                  'code': 'NAHATA10',
                  'discountAmount': 100,
                  'finalAmount': 900,
                  'originalAmount': 1000,
                },
              }),
              200,
            );
          }),
        );

        final check = await CouponsRepositoryImpl().validateCoupon(
          code: 'nahata10',
          amount: 1000,
          appliesTo: CouponAppliesTo.court,
          sportComplexId: 3,
          sportId: 7,
          eventPassId: 31,
        );

        expect(captured.url.path, endsWith('/coupons/validate'));
        // Mandatory: the backend enforces App-only and Web-only coupons with it.
        expect(captured.headers['x-client-platform'], 'android');

        final body = jsonDecode(captured.body) as Map<String, dynamic>;
        expect(body['code'], 'NAHATA10');
        expect(body['amount'], 1000);
        expect(body['appliesTo'], 'Court');
        expect(body['sportComplexId'], 3);
        expect(body['sportId'], 7);
        // A Court validation never carries an event, whatever the caller passed.
        expect(body['eventPassId'], isNull);

        expect(check.isValid, isTrue);
        expect(check.discountAmount, 100);
        expect(check.finalAmount, 900);
      },
    );

    test(
      'a rejected coupon is a result carrying the reason, not an exception',
      () async {
        ApiClient.instance.overrideHttpClient(
          MockClient((request) async {
            return http.Response(
              jsonEncode({
                'success': false,
                'message': 'This coupon is not valid for app bookings',
              }),
              400,
            );
          }),
        );

        final check = await CouponsRepositoryImpl().validateCoupon(
          code: 'WEBONLY',
          amount: 1000,
          appliesTo: CouponAppliesTo.court,
        );

        expect(check.isValid, isFalse);
        expect(check.message, 'This coupon is not valid for app bookings');
      },
    );

    test('a session failure during validation still propagates', () async {
      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          return http.Response(
            jsonEncode({'success': false, 'message': 'Forbidden'}),
            403,
          );
        }),
      );

      await expectLater(
        CouponsRepositoryImpl().validateCoupon(
          code: 'WELCOME10',
          amount: 1000,
          appliesTo: CouponAppliesTo.court,
        ),
        throwsA(isA<ForbiddenException>()),
      );
    });

    test('the active list is the customer route, with the header', () async {
      late http.Request captured;

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'success': true,
              'data': [
                {'id': 3, 'code': 'NAHATA10'},
              ],
            }),
            200,
          );
        }),
      );

      final coupons = await CouponsRepositoryImpl().getActiveCoupons(
        appliesTo: CouponAppliesTo.event,
      );

      expect(captured.url.path, endsWith('/coupons/active'));
      expect(captured.url.queryParameters['appliesTo'], 'Event');
      expect(captured.headers['x-client-platform'], 'android');
      expect(coupons.single.code, 'NAHATA10');
    });
  });

  // ---------------------------------------------------------------------------
  group('CouponsController', () {
    test('paging replaces the rows, scrolling appends them', () async {
      final repository = _FakeRepository(total: 5, pageSize: 2);
      final controller = CouponsController(repository);

      await controller.load();
      expect(controller.coupons, hasLength(2));
      expect(controller.state, ViewState.ready);

      await controller.loadMore();
      expect(controller.coupons, hasLength(4));
      expect(controller.page.page, 2);

      await controller.load(page: 1);
      expect(controller.coupons, hasLength(2));

      controller.dispose();
    });

    test('an overlapping page never shows the same coupon twice', () async {
      final repository = _FakeRepository(total: 4, pageSize: 2, overlap: true);
      final controller = CouponsController(repository);

      await controller.load();
      await controller.loadMore();

      final ids = controller.coupons.map((coupon) => coupon.id).toList();
      expect(ids.toSet(), hasLength(ids.length));

      controller.dispose();
    });

    test('a failed load keeps the rows already on screen', () async {
      final repository = _FakeRepository(total: 4, pageSize: 2);
      final controller = CouponsController(repository);

      await controller.load();
      repository.failNext = true;
      await controller.load(page: 2);

      expect(controller.state, ViewState.failed);
      expect(controller.error, isNotNull);
      expect(controller.coupons, hasLength(2));

      controller.dispose();
    });

    test('creating refreshes back to the first page', () async {
      final repository = _FakeRepository(total: 4, pageSize: 2);
      final controller = CouponsController(repository);

      await controller.load(page: 2);
      await controller.create(_draft());

      expect(controller.page.page, 1);
      expect(repository.created, 1);

      controller.dispose();
    });

    test('deleting the last row of a page steps back a page', () async {
      final repository = _FakeRepository(total: 3, pageSize: 1);
      final controller = CouponsController(repository);

      await controller.load(page: 3);
      expect(controller.coupons, hasLength(1));

      await controller.delete(controller.coupons.first.id);
      expect(controller.page.page, 2);

      controller.dispose();
    });

    test('the form option lists are fetched once and reused', () async {
      final repository = _FakeRepository();
      final controller = CouponsController(repository);

      await controller.loadFormOptions();
      await controller.loadFormOptions();
      expect(repository.complexCalls, 1);
      expect(repository.sportCalls, 1);
      expect(repository.eventCalls, 1);

      await controller.loadFormOptions(refresh: true);
      expect(repository.complexCalls, 2);

      controller.dispose();
    });

    test(
      'a complex admin may only issue court coupons for their own venue',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'user': jsonEncode({
            'id': 4,
            'name': 'Venue Manager',
            'role': 'COMPLEX_ADMIN',
            'sportComplexId': 2,
          }),
        });

        final repository = _FakeRepository();
        final controller = CouponsController(repository);

        await controller.loadRole();
        await controller.loadComplexes();

        expect(controller.isComplexScoped, isTrue);
        expect(controller.ownComplexId, 2);
        expect(controller.allowedScopes, [CouponAppliesTo.court]);
        expect(controller.selectableComplexes.map((c) => c.id), [2]);

        controller.dispose();
      },
    );

    test('an admin may issue coupons for either scope, at any venue', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'user': jsonEncode({'id': 1, 'name': 'Owner', 'role': 'ADMIN'}),
      });

      final repository = _FakeRepository();
      final controller = CouponsController(repository);

      await controller.loadRole();
      await controller.loadComplexes();

      expect(controller.isComplexScoped, isFalse);
      expect(controller.allowedScopes, CouponAppliesTo.values);
      expect(controller.selectableComplexes, hasLength(2));

      controller.dispose();
    });
  });
}

/// A repository that answers from memory, so the controller can be exercised
/// without a socket.
class _FakeRepository implements CouponsRepository {
  _FakeRepository({this.total = 0, this.pageSize = 20, this.overlap = false});

  final int total;
  final int pageSize;

  /// Repeats the last row of the previous page, the way a live list does when
  /// a coupon is created while the desk is scrolling.
  final bool overlap;

  bool failNext = false;

  int listCalls = 0;
  int complexCalls = 0;
  int sportCalls = 0;
  int eventCalls = 0;
  int created = 0;
  final List<int> deleted = <int>[];

  @override
  Future<Paged<AdminCoupon>> getCoupons({
    int page = 1,
    int limit = 20,
    String? search,
    String? status,
  }) async {
    if (failNext) {
      failNext = false;
      throw const ServerException('Server is temporarily unavailable.');
    }

    listCalls++;

    final start = (page - 1) * pageSize - (overlap && page > 1 ? 1 : 0);
    final items = <AdminCoupon>[];
    for (
      var index = start;
      index < start + pageSize && index < total;
      index++
    ) {
      items.add(_coupon(id: index + 1, code: 'CODE${index + 1}'));
    }

    return Paged<AdminCoupon>(
      items: items,
      page: page,
      limit: pageSize,
      total: total,
      totalPages: (total / pageSize).ceil(),
    );
  }

  @override
  Future<AdminCoupon> getCouponById(int id) async => _coupon(id: id);

  @override
  Future<AdminCoupon?> getCouponByCode(String code) async => null;

  @override
  Future<AdminCoupon> createCoupon(CouponDraft draft) async {
    created++;
    return _coupon(id: 99, code: draft.code ?? 'NEW');
  }

  @override
  Future<AdminCoupon> updateCoupon(int id, CouponDraft draft) async =>
      _coupon(id: id);

  @override
  Future<void> deleteCoupon(int id) async => deleted.add(id);

  @override
  Future<CouponCheck> validateCoupon({
    required String code,
    required num amount,
    required CouponAppliesTo appliesTo,
    int? sportComplexId,
    int? sportId,
    int? eventPassId,
  }) async {
    return CouponCheck(
      isValid: true,
      message: 'Coupon is valid',
      coupon: _coupon(code: code),
      originalAmount: amount,
      discountAmount: amount * 0.1,
      finalAmount: amount * 0.9,
    );
  }

  @override
  Future<List<AdminCoupon>> getActiveCoupons({
    CouponAppliesTo? appliesTo,
  }) async => [_coupon()];

  @override
  Future<List<SportsComplex>> fetchSportComplexes({
    bool refresh = false,
  }) async {
    complexCalls++;
    return const [
      SportsComplex(id: 1, name: 'Nahata Sports Complex', city: 'Pune'),
      SportsComplex(id: 2, name: 'Kothrud Arena', city: 'Pune'),
    ];
  }

  @override
  Future<List<Sport>> fetchSports({bool refresh = false}) async {
    sportCalls++;
    return const [Sport(id: 7, name: 'Badminton', sportComplexId: 2)];
  }

  @override
  Future<List<AdminEventPass>> fetchEventPasses({bool refresh = false}) async {
    eventCalls++;
    return const [AdminEventPass(id: 31, title: 'Summer Slam')];
  }
}
