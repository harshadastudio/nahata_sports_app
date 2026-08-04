import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nahata_app/core/network/api_client.dart';
import 'package:nahata_app/core/network/api_exception.dart';
import 'package:nahata_app/features/admin/data/models/membership_model.dart';
import 'package:nahata_app/features/admin/data/repositories/membership_repository_impl.dart';
import 'package:nahata_app/features/admin/domain/entities/membership.dart';
import 'package:nahata_app/features/admin/domain/entities/paged.dart';
import 'package:nahata_app/features/admin/domain/repositories/membership_repository.dart';
import 'package:nahata_app/features/admin/presentation/state/memberships_controller.dart';
import 'package:nahata_app/features/admin/presentation/state/view_state.dart';

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

Membership _membership({
  required String id,
  String? userId,
  String? userName,
  String? planId,
  String? planName,
  num? price = 12000,
  num? totalAmount = 12000,
  int? validity = 365,
  int? bookings = 50,
  int? bookingsUsed,
  DateTime? start,
  DateTime? end,
  String status = 'Active',
  String payment = 'Paid',
}) {
  return Membership(
    id: id,
    userId: userId ?? 'u$id',
    userName: userName ?? 'Member $id',
    planId: planId ?? 'GOLD',
    planName: planName ?? 'Gold Annual',
    price: price,
    totalAmount: totalAmount,
    validityDays: validity,
    bookingLimit: bookings,
    bookingsUsed: bookingsUsed,
    startDate: start ?? DateTime(2026, 8, 1),
    endDate: end ?? DateTime(2027, 7, 31),
    statusRaw: status,
    paymentStatusRaw: payment,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _secureStore.clear();
    _mockSecureStorage();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  // ---------------------------------------------------------------------------
  group('Membership vocabularies', () {
    test('the slugs are the exact wire values the module documents', () {
      expect(MembershipStatus.values.map((s) => s.slug), [
        'Active',
        'Inactive',
        'Expired',
        'Cancelled',
      ]);
      expect(MembershipPaymentStatus.values.map((p) => p.slug), [
        'Paid',
        'Pending',
        'Failed',
        'Refunded',
      ]);
    });

    test('reads are case- and separator-insensitive', () {
      expect(MembershipStatus.tryParse('active'), MembershipStatus.active);
      expect(MembershipStatus.tryParse('CANCELLED'), MembershipStatus.cancelled);
      expect(
        MembershipPaymentStatus.tryParse('refunded'),
        MembershipPaymentStatus.refunded,
      );
      expect(MembershipStatus.tryParse(''), isNull);
      expect(MembershipStatus.tryParse(null), isNull);
    });

    test('a value outside the vocabulary still renders', () {
      expect(MembershipStatus.labelFor('on_hold'), 'On Hold');
      expect(MembershipPaymentStatus.labelFor(null), '—');
    });
  });

  // ---------------------------------------------------------------------------
  group('Membership', () {
    test('days remaining counts calendar days, not hours', () {
      final row = _membership(id: '1', end: DateTime(2026, 8, 20));
      expect(row.daysRemaining(now: DateTime(2026, 8, 5, 23, 30)), 15);
      expect(row.daysRemaining(now: DateTime(2026, 8, 20, 1)), 0);
      expect(row.daysRemaining(now: DateTime(2026, 8, 22)), -2);
    });

    test('a membership with no end date is unknown, never expired', () {
      const row = Membership(id: '1', statusRaw: 'Active');
      expect(row.daysRemaining(), isNull);
      expect(row.hasLapsed(), isFalse);
      expect(row.progress(), isNull);
    });

    test('progress is clamped to the term', () {
      final row = _membership(
        id: '1',
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 8, 11),
      );
      expect(row.progress(now: DateTime(2026, 8, 6)), closeTo(0.5, 0.01));
      expect(row.progress(now: DateTime(2026, 7, 1)), 0);
      expect(row.progress(now: DateTime(2027, 1, 1)), 1);
    });

    test('bookings left is null until both figures were reported', () {
      expect(_membership(id: '1', bookings: 50).bookingsRemaining, isNull);
      expect(
        _membership(id: '1', bookings: 50, bookingsUsed: 12).bookingsRemaining,
        38,
      );
      // Overrun never reads as a negative allowance.
      expect(
        _membership(id: '1', bookings: 10, bookingsUsed: 14).bookingsRemaining,
        0,
      );
    });

    test('search matches the member, the plan, the code and the contact', () {
      final row = Membership(
        id: '77',
        userName: 'Rahul Sharma',
        userEmail: 'rahul@example.com',
        planId: 'GOLD',
        planName: 'Gold Annual',
      );

      expect(row.matches('rahul'), isTrue);
      expect(row.matches('gold'), isTrue);
      expect(row.matches('example.com'), isTrue);
      expect(row.matches('77'), isTrue);
      expect(row.matches(''), isTrue);
      expect(row.matches('platinum'), isFalse);
    });

    test('the display names fall back rather than blanking', () {
      expect(const Membership(id: '1').displayPlan, 'Untitled plan');
      expect(const Membership(id: '1', planId: 'GOLD').displayPlan, 'GOLD');
      expect(const Membership(id: '1').displayUser, 'Unknown member');
      expect(const Membership(id: '1', userId: '9').displayUser, 'User #9');
      expect(_membership(id: '1', userName: 'Rahul Sharma').initials, 'RS');
    });

    test('a detail read fills the row in without dropping what it omits', () {
      final row = _membership(id: '7', userName: 'Rahul');
      const detail = Membership(
        id: '7',
        accessType: 'All Courts',
        features: ['Priority booking'],
      );

      final merged = row.mergedWith(detail);
      expect(merged.userName, 'Rahul');
      expect(merged.planName, 'Gold Annual');
      expect(merged.accessType, 'All Courts');
      expect(merged.features.single, 'Priority booking');
    });
  });

  // ---------------------------------------------------------------------------
  group('MembershipMapper', () {
    test('reads the documented field names', () {
      final row = MembershipMapper.fromJson({
        'id': 'm-77',
        'userId': '585',
        'planId': 'GOLD',
        'planName': 'Gold Annual',
        'price': 12000,
        'validity': 365,
        'bookings': 50,
        'discount': 10,
        'accessType': 'All Courts',
        'features': ['Priority booking', 'Free guest pass'],
        'startDate': '2026-08-01',
        'endDate': '2027-07-31',
        'status': 'Active',
        'paymentStatus': 'Paid',
        'autoRenew': false,
        'discountApplied': 0,
        'totalAmount': 12000,
        'user': {'id': '585', 'name': 'Rahul Sharma', 'email': 'r@x.com'},
      });

      expect(row.id, 'm-77');
      expect(row.userId, '585');
      expect(row.userName, 'Rahul Sharma');
      expect(row.userEmail, 'r@x.com');
      expect(row.planId, 'GOLD');
      expect(row.price, 12000);
      expect(row.validityDays, 365);
      expect(row.bookingLimit, 50);
      expect(row.discountPercent, 10);
      expect(row.features.length, 2);
      expect(row.startDate, DateTime(2026, 8, 1));
      expect(row.status, MembershipStatus.active);
      expect(row.paymentStatus, MembershipPaymentStatus.paid);
      expect(row.autoRenew, isFalse);
    });

    test('the row id never inherits the embedded user id', () {
      // The bug the security-guard module shipped with: descending into `user`
      // made every `/{id}` call address the wrong record.
      final row = MembershipMapper.fromJson({
        'id': '22',
        'userId': '585',
        'user': {'id': '585', 'name': 'Rahul'},
      });
      expect(row.id, '22');
      expect(row.userId, '585');
    });

    test('snake_case and a decimal-string price read the same', () {
      final row = MembershipMapper.fromJson({
        'data': {
          '_id': 'm-9',
          'user_id': '12',
          'plan_name': 'Silver',
          'price': '5000.00',
          'validity_days': 180,
          'booking_limit': 20,
          'start_date': '2026-01-01',
          'expiry_date': '2026-06-29',
          'payment_status': 'Pending',
          'auto_renew': true,
        },
      });

      expect(row.id, 'm-9');
      expect(row.userId, '12');
      expect(row.price, 5000);
      expect(row.validityDays, 180);
      expect(row.bookingLimit, 20);
      expect(row.endDate, DateTime(2026, 6, 29));
      expect(row.paymentStatus, MembershipPaymentStatus.pending);
      expect(row.autoRenew, isTrue);
    });

    test('features survive a comma-separated string', () {
      final row = MembershipMapper.fromJson({
        'id': '1',
        'features': 'Priority booking, Free guest pass',
      });
      expect(row.features, ['Priority booking', 'Free guest pass']);
    });

    test('rows without an id are dropped — they could not be acted on', () {
      final rows = MembershipMapper.listFrom({
        'data': [
          {'id': '1'},
          {'planName': 'no id'},
          {'id': '2'},
        ],
      });
      expect(rows.map((r) => r.id), ['1', '2']);
    });

    test('the documented list envelope is read', () {
      // `{success, message, data, total, page, limit}` — counters beside the
      // rows rather than in a meta block.
      final page = MembershipMapper.pageFrom(
        {
          'success': true,
          'message': 'Success',
          'data': [
            {'id': '1'},
            {'id': '2'},
          ],
          'total': 47,
          'page': 2,
          'limit': 20,
        },
        requestedPage: 2,
        requestedLimit: 20,
      );

      expect(page.items.length, 2);
      expect(page.page, 2);
      expect(page.total, 47);
      expect(page.effectiveTotalPages, 3);
      expect(page.hasNext, isTrue);
    });

    test('a total with no page count still exposes the later pages', () {
      final page = MembershipMapper.pageFrom(
        {
          'data': [
            {'id': '1'},
          ],
          'total': 47,
          'limit': 10,
        },
        requestedPage: 1,
        requestedLimit: 10,
      );
      expect(page.effectiveTotalPages, 5);
    });

    test('a bare list degrades to one complete page', () {
      final page = MembershipMapper.pageFrom(
        [
          {'id': '1'},
          {'id': '2'},
        ],
        requestedPage: 1,
        requestedLimit: 20,
      );
      expect(page.total, 2);
      expect(page.effectiveTotalPages, 1);
      expect(page.hasNext, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  group('MembershipStatsMapper', () {
    test('reads the counters and the revenue', () {
      final stats = MembershipStatsMapper.fromJson({
        'data': {
          'total': 120,
          'active': 80,
          'expired': 25,
          'cancelled': 15,
          'totalRevenue': '960000.00',
        },
      });

      expect(stats.total, 120);
      expect(stats.active, 80);
      expect(stats.expired, 25);
      expect(stats.cancelled, 15);
      expect(stats.revenue, 960000);
      expect(stats.isEmpty, isFalse);
    });

    test('counters grouped by status are read too', () {
      final stats = MembershipStatsMapper.fromJson({
        'data': {
          'totalMemberships': 10,
          'byStatus': {'Active': 6, 'Expired': 3, 'Cancelled': 1},
        },
      });
      expect(stats.total, 10);
      expect(stats.active, 6);
      expect(stats.expired, 3);
    });

    test('a missing counter stays null rather than becoming zero', () {
      final stats = MembershipStatsMapper.fromJson({
        'data': {'total': 10},
      });
      expect(stats.total, 10);
      expect(stats.active, isNull);
      expect(stats.revenue, isNull);
      expect(MembershipStatsMapper.fromJson(const {}).isEmpty, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  group('MembershipDraft', () {
    test('the create payload matches the documented body', () {
      final body = MembershipDraft(
        userId: ' 585 ',
        planId: 'GOLD',
        planName: 'Gold Annual',
        price: 12000,
        validityDays: 365,
        bookingLimit: 50,
        discountPercent: 10,
        accessType: 'All Courts',
        features: const ['Priority booking', 'Free guest pass'],
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2027, 7, 31),
        status: MembershipStatus.active,
        paymentStatus: MembershipPaymentStatus.paid,
        autoRenew: false,
        discountApplied: 0,
        totalAmount: 12000,
      ).toCreateJson();

      expect(body['userId'], '585');
      expect(body['planId'], 'GOLD');
      expect(body['price'], 12000);
      expect(body['validity'], 365);
      expect(body['bookings'], 50);
      expect(body['discount'], 10);
      expect(body['features'], ['Priority booking', 'Free guest pass']);
      expect(body['startDate'], '2026-08-01');
      expect(body['endDate'], '2027-07-31');
      expect(body['status'], 'Active');
      expect(body['paymentStatus'], 'Paid');
      expect(body['autoRenew'], false);
      expect(body['discountApplied'], 0);
      expect(body['totalAmount'], 12000);
    });

    test('create defaults to Active / Pending', () {
      final body = const MembershipDraft(userId: '1').toCreateJson();
      expect(body['status'], 'Active');
      expect(body['paymentStatus'], 'Pending');
      expect(body['autoRenew'], false);
    });

    test('the update payload carries only what was set', () {
      final body = MembershipDraft(
        planName: 'Gold Annual',
        price: 12000,
        endDate: DateTime(2027, 7, 31),
      ).toUpdateJson();

      expect(body, {
        'planName': 'Gold Annual',
        'price': 12000,
        'endDate': '2027-07-31',
      });
      expect(const MembershipDraft().toUpdateJson(), isEmpty);
    });

    test('status and payment status are never sent on the PUT', () {
      // Both have their own PATCH routes; sending them here would be a second,
      // undocumented way to set them.
      final body = const MembershipDraft(
        planName: 'Gold',
        status: MembershipStatus.cancelled,
        paymentStatus: MembershipPaymentStatus.refunded,
      ).toUpdateJson();

      expect(body.containsKey('status'), isFalse);
      expect(body.containsKey('paymentStatus'), isFalse);
    });

    test('features parse one per line, dropping the blanks', () {
      expect(
        MembershipDraft.parseFeatures(
          '  Priority booking \n\n Free guest pass \n   \n',
        ),
        ['Priority booking', 'Free guest pass'],
      );
      expect(MembershipDraft.parseFeatures('   '), isEmpty);
    });

    test('the derived end date is inclusive of the start day', () {
      // 365 days from 2026-08-01 ends 2027-07-31, exactly as the example shows.
      expect(
        MembershipDraft.endDateFor(DateTime(2026, 8, 1), 365),
        DateTime(2027, 7, 31),
      );
      expect(MembershipDraft.endDateFor(null, 365), isNull);
      expect(MembershipDraft.endDateFor(DateTime(2026, 8, 1), 0), isNull);
    });

    test('the derived amount applies the percentage discount', () {
      expect(MembershipDraft.amountFor(12000, 10), 10800);
      expect(MembershipDraft.amountFor(12000, 0), 12000);
      expect(MembershipDraft.amountFor(12000, null), 12000);
      expect(MembershipDraft.amountFor(null, 10), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  group('MembershipsSummary', () {
    test('counts each bucket and only paid revenue', () {
      final summary = MembershipsSummary.from([
        _membership(id: '1'),
        _membership(id: '2', status: 'Expired', payment: 'Paid'),
        _membership(id: '3', status: 'Cancelled', payment: 'Refunded'),
        _membership(id: '4', status: 'Inactive', payment: 'Pending'),
      ]);

      expect(summary.total, 4);
      expect(summary.active, 1);
      expect(summary.expired, 1);
      expect(summary.cancelled, 1);
      // Only the two paid rows count; refunded money is not revenue.
      expect(summary.revenue, 24000);
      expect(summary.countedLocally, isTrue);
    });

    test('revenue stays null when no row was paid', () {
      final summary = MembershipsSummary.from([
        _membership(id: '1', payment: 'Pending'),
      ]);
      expect(summary.revenue, isNull);
    });

    test('the endpoint figures win, and gaps are filled by counting', () {
      const stats = MembershipStats(total: 120, active: 80);
      final merged = MembershipsSummary.fromStats(
        stats,
      ).mergedWith(MembershipsSummary.from([_membership(id: '1')]));

      expect(merged.total, 120);
      expect(merged.active, 80);
      // Not sent by the endpoint, so counted — and the flag says so.
      expect(merged.expired, 0);
      expect(merged.countedLocally, isTrue);
    });

    test('a complete stats payload is not captioned as counted', () {
      const stats = MembershipStats(
        total: 120,
        active: 80,
        expired: 25,
        cancelled: 15,
        revenue: 960000,
      );
      final merged = MembershipsSummary.fromStats(
        stats,
      ).mergedWith(MembershipsSummary.from([_membership(id: '1')]));

      expect(merged.countedLocally, isFalse);
      expect(merged.revenue, 960000);
    });
  });

  // ---------------------------------------------------------------------------
  group('MembershipsController', () {
    test('the default read is one server page', () async {
      final repository = _FakeRepository(total: 47);
      final controller = MembershipsController(repository);
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.isCatalogueMode, isFalse);
      expect(repository.pageCalls, 1);
      expect(controller.page.total, 47);
      expect(controller.page.effectiveTotalPages, 3);
    });

    test('the status filter goes to the server, not the catalogue', () async {
      // It is a documented query parameter, so paging can stay on the server.
      final repository = _FakeRepository();
      final controller = MembershipsController(repository);
      addTearDown(controller.dispose);
      await controller.load();

      controller.setStatusFilter(MembershipStatus.expired);
      await Future<void>.delayed(Duration.zero);

      expect(controller.isCatalogueMode, isFalse);
      expect(repository.lastStatus, MembershipStatus.expired);
    });

    test('search pulls the catalogue, because one page is not enough',
        () async {
      final repository = _FakeRepository();
      final controller = MembershipsController(repository);
      addTearDown(controller.dispose);
      await controller.load();

      controller.onSearchChanged('rahul');
      await Future<void>.delayed(MembershipsController.searchDebounce * 2);
      await Future<void>.delayed(Duration.zero);

      expect(controller.isCatalogueMode, isTrue);
      expect(repository.cataloguePages, isNotEmpty);
    });

    test('the local filters are applied over the catalogue', () async {
      final controller = MembershipsController(
        _FakeRepository(
          rows: [
            _membership(id: '1', payment: 'Paid'),
            _membership(id: '2', payment: 'Pending'),
            _membership(id: '3', payment: 'Paid', status: 'Expired'),
          ],
        ),
      );
      addTearDown(controller.dispose);
      await controller.load();

      controller.setPaymentFilter(MembershipPaymentStatus.paid);
      await Future<void>.delayed(Duration.zero);
      expect(controller.visibleRows.map((r) => r.id), ['1', '3']);

      controller.setStatusFilter(MembershipStatus.active);
      await Future<void>.delayed(Duration.zero);
      expect(controller.visibleRows.single.id, '1');
    });

    test('"expiring soon" never sweeps in a plan with no end date', () async {
      final now = DateTime.now();
      final controller = MembershipsController(
        _FakeRepository(
          rows: [
            _membership(id: '1', end: now.add(const Duration(days: 10))),
            _membership(id: '2', end: now.add(const Duration(days: 200))),
            _membership(id: '3', end: now.subtract(const Duration(days: 5))),
            const Membership(id: '4', statusRaw: 'Active'),
          ],
        ),
      );
      addTearDown(controller.dispose);
      await controller.load();

      controller.setExpiringSoonOnly(true);
      await Future<void>.delayed(Duration.zero);

      // Only the one genuinely inside the window: not the far-off plan, not the
      // one already ended, and not the one whose end date is unknown.
      expect(controller.visibleRows.single.id, '1');
    });

    test('sorting cycles ascending, descending, then off', () async {
      final controller = MembershipsController(
        _FakeRepository(
          rows: [
            _membership(id: '1', planName: 'Silver'),
            _membership(id: '2', planName: 'bronze'),
            _membership(id: '3', planName: 'Gold'),
          ],
        ),
      );
      addTearDown(controller.dispose);
      await controller.load();

      controller.toggleSort(MembershipSort.plan);
      await Future<void>.delayed(Duration.zero);
      expect(controller.visibleRows.map((r) => r.id), ['2', '3', '1']);

      controller.toggleSort(MembershipSort.plan);
      await Future<void>.delayed(Duration.zero);
      expect(controller.visibleRows.map((r) => r.id), ['1', '3', '2']);

      controller.toggleSort(MembershipSort.plan);
      await Future<void>.delayed(Duration.zero);
      expect(controller.sort, isNull);
    });

    test('sorting by a nullable column never dereferences a missing value',
        () async {
      final controller = MembershipsController(
        _FakeRepository(
          rows: [
            _membership(id: '1', end: DateTime(2027, 1, 1)),
            const Membership(id: '2'),
            _membership(id: '3', end: DateTime(2026, 9, 1)),
          ],
        ),
      );
      addTearDown(controller.dispose);
      await controller.load();

      controller.toggleSort(MembershipSort.ends);
      await Future<void>.delayed(Duration.zero);
      expect(controller.visibleRows.map((r) => r.id), ['3', '1', '2']);

      // The blank sinks in both directions rather than floating to the top.
      controller.toggleSort(MembershipSort.ends);
      await Future<void>.delayed(Duration.zero);
      expect(controller.visibleRows.last.id, '2');
    });

    test('loadMore appends the next page and never duplicates rows', () async {
      final repository = _FakeRepository(total: 40, pageSize: 20);
      final controller = MembershipsController(repository);
      addTearDown(controller.dispose);
      await controller.load();

      expect(controller.rows.length, 20);
      expect(controller.hasMore, isTrue);

      await controller.loadMore();
      expect(controller.rows.length, 40);
      expect(controller.hasMore, isFalse);

      // At the end, another call is a no-op rather than a wasted request.
      final calls = repository.pageCalls;
      await controller.loadMore();
      expect(repository.pageCalls, calls);
    });

    test('a duplicate page from the server is not appended twice', () async {
      // A backend that echoes page one for an out-of-range page would
      // otherwise double every row on screen.
      final repository = _FakeRepository(total: 40, pageSize: 20, echoPageOne: true);
      final controller = MembershipsController(repository);
      addTearDown(controller.dispose);
      await controller.load();

      await controller.loadMore();
      expect(controller.rows.length, 20);
    });

    test('the cards prefer the stats endpoint and fall back to counting',
        () async {
      final controller = MembershipsController(
        _FakeRepository(
          rows: [_membership(id: '1')],
          stats: const MembershipStats(total: 120, active: 80),
        ),
      );
      addTearDown(controller.dispose);

      await controller.load();
      expect(controller.summary.total, 1);
      expect(controller.summary.countedLocally, isTrue);

      await controller.loadStats();
      expect(controller.summary.total, 120);
      expect(controller.summary.active, 80);
    });

    test('a failed stats read does not fail the page', () async {
      final controller = MembershipsController(
        _FakeRepository(rows: [_membership(id: '1')], failStats: true),
      );
      addTearDown(controller.dispose);

      await controller.load();
      await controller.loadStats();

      expect(controller.statsState.isFailed, isTrue);
      expect(controller.state.isReady, isTrue);
      // The cards keep working by counting the rows.
      expect(controller.summary.total, 1);
    });

    test('a failed load surfaces the server message', () async {
      final controller = MembershipsController(
        _FakeRepository(failList: true),
      );
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.state.isFailed, isTrue);
      expect(controller.error, 'The memberships service is down');
    });

    test('the detail read merges over the row and loads the user plans',
        () async {
      final repository = _FakeRepository(
        rows: [_membership(id: '7', userId: '585')],
        detail: const Membership(
          id: '7',
          accessType: 'All Courts',
          features: ['Priority booking'],
        ),
      );
      final controller = MembershipsController(repository);
      addTearDown(controller.dispose);
      await controller.load();

      await controller.openMembership(controller.rows.single);

      expect(controller.detailState.isReady, isTrue);
      expect(controller.selected?.planName, 'Gold Annual');
      expect(controller.selected?.accessType, 'All Courts');
      expect(repository.userPlanCalls, ['585']);
      expect(controller.userActive?.id, 'active-585');

      controller.closeMembership();
      expect(controller.selected, isNull);
      expect(controller.userHistory, isEmpty);
    });

    test('a status change is optimistic and reverts when refused', () async {
      final repository = _FakeRepository(
        rows: [_membership(id: '7')],
        failStatus: true,
      );
      final controller = MembershipsController(repository);
      addTearDown(controller.dispose);
      await controller.load();

      await expectLater(
        controller.setStatus('7', MembershipStatus.cancelled),
        throwsA(isA<ApiException>()),
      );

      expect(controller.rows.single.status, MembershipStatus.active);
      expect(controller.isRowBusy('7'), isFalse);
    });

    test('a payment change updates the row immediately', () async {
      final repository = _FakeRepository(rows: [_membership(id: '7')]);
      final controller = MembershipsController(repository);
      addTearDown(controller.dispose);
      await controller.load();

      await controller.setPaymentStatus('7', MembershipPaymentStatus.refunded);

      expect(
        controller.rows.single.paymentStatus,
        MembershipPaymentStatus.refunded,
      );
      expect(repository.payments, [MembershipPaymentStatus.refunded]);
    });

    test('cancelling sends the reason and refreshes', () async {
      final repository = _FakeRepository(rows: [_membership(id: '7')]);
      final controller = MembershipsController(repository);
      addTearDown(controller.dispose);
      await controller.load();

      await controller.cancel('7', 'Customer request');

      expect(repository.cancelReasons, ['Customer request']);
      expect(repository.pageCalls, 2);
    });

    test('renewing refreshes the detail and then the list', () async {
      final repository = _FakeRepository(rows: [_membership(id: '7')]);
      final controller = MembershipsController(repository);
      addTearDown(controller.dispose);
      await controller.load();
      await controller.openMembership(controller.rows.single);

      final detailReads = repository.detailCalls;
      await controller.renew('7', validityDays: 365, totalAmount: 12000);

      expect(repository.renewals, [(365, 12000)]);
      expect(repository.detailCalls, detailReads + 1);
    });

    test('a failed delete puts the row back', () async {
      final repository = _FakeRepository(
        rows: [_membership(id: '7'), _membership(id: '8')],
        failDelete: true,
      );
      final controller = MembershipsController(repository);
      addTearDown(controller.dispose);
      await controller.load();

      await expectLater(controller.delete('7'), throwsA(isA<ApiException>()));
      expect(controller.rows.map((r) => r.id), ['7', '8']);
    });

    test('the expiry sweep returns what the server reported', () async {
      final repository = _FakeRepository(rows: [_membership(id: '7')]);
      final controller = MembershipsController(repository);
      addTearDown(controller.dispose);
      await controller.load();

      expect(await controller.runExpirySweep(), 4);
      expect(repository.sweeps, 1);
    });
  });

  // ---------------------------------------------------------------------------
  group('MembershipRepositoryImpl — the wire', () {
    test('the list route sends paging and the status filter', () async {
      late Uri captured;

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          captured = request.url;
          return http.Response(jsonEncode({'success': true, 'data': []}), 200);
        }),
      );

      await MembershipRepositoryImpl().fetchMemberships(
        page: 2,
        limit: 50,
        status: MembershipStatus.active,
      );

      expect(captured.path, endsWith('/memberships'));
      expect(captured.queryParameters['page'], '2');
      expect(captured.queryParameters['limit'], '50');
      expect(captured.queryParameters['status'], 'Active');
    });

    test('an unset status is never sent as an empty parameter', () async {
      late Uri captured;

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          captured = request.url;
          return http.Response(jsonEncode({'success': true}), 200);
        }),
      );

      await MembershipRepositoryImpl().fetchMemberships();
      expect(captured.queryParameters.containsKey('status'), isFalse);
    });

    test('every route uses the path the module documents', () async {
      final calls = <String>[];

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          calls.add('${request.method} ${request.url.path}');
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {'id': 'm-7'},
            }),
            200,
          );
        }),
      );

      final repository = MembershipRepositoryImpl();
      await repository.fetchStats();
      await repository.fetchMembership('m-7');
      await repository.fetchForUser('585');
      await repository.fetchActiveForUser('585');
      await repository.updateMembership(
        'm-7',
        const MembershipDraft(planName: 'Gold Annual'),
      );
      await repository.setStatus('m-7', MembershipStatus.active);
      await repository.setPaymentStatus('m-7', MembershipPaymentStatus.paid);
      await repository.cancelMembership('m-7', 'Customer request');
      await repository.renewMembership(
        'm-7',
        validityDays: 365,
        totalAmount: 12000,
      );
      await repository.deleteMembership('m-7');
      await repository.checkExpired();

      expect(calls, [
        endsWith('GET /api/memberships/stats'),
        endsWith('GET /api/memberships/m-7'),
        endsWith('GET /api/memberships/user/585'),
        endsWith('GET /api/memberships/user/585/active'),
        endsWith('PUT /api/memberships/m-7'),
        endsWith('PATCH /api/memberships/m-7/status'),
        endsWith('PATCH /api/memberships/m-7/payment-status'),
        endsWith('PATCH /api/memberships/m-7/cancel'),
        endsWith('POST /api/memberships/m-7/renew'),
        endsWith('DELETE /api/memberships/m-7'),
        endsWith('POST /api/memberships/check-expired'),
      ]);
    });

    test('the PATCH bodies carry exactly the documented key', () async {
      final bodies = <String>[];

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          bodies.add(request.body);
          return http.Response(jsonEncode({'success': true}), 200);
        }),
      );

      final repository = MembershipRepositoryImpl();
      await repository.setStatus('m-7', MembershipStatus.cancelled);
      await repository.setPaymentStatus(
        'm-7',
        MembershipPaymentStatus.refunded,
      );
      await repository.cancelMembership('m-7', '  Customer request  ');

      expect(jsonDecode(bodies[0]), {'status': 'Cancelled'});
      expect(jsonDecode(bodies[1]), {'paymentStatus': 'Refunded'});
      expect(jsonDecode(bodies[2]), {'reason': 'Customer request'});
    });

    test('no active plan is an answer, not a failure', () async {
      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          return http.Response(
            jsonEncode({'success': false, 'message': 'Not found'}),
            404,
          );
        }),
      );

      expect(
        await MembershipRepositoryImpl().fetchActiveForUser('585'),
        isNull,
      );
    });

    test('create validates every required field before the round trip',
        () async {
      var called = false;
      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          called = true;
          return http.Response(jsonEncode({'success': true}), 200);
        }),
      );

      final repository = MembershipRepositoryImpl();
      final base = MembershipDraft(
        userId: '585',
        planId: 'GOLD',
        planName: 'Gold Annual',
        price: 12000,
        validityDays: 365,
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2027, 7, 31),
        totalAmount: 12000,
      );

      for (final draft in [
        const MembershipDraft(),
        const MembershipDraft(userId: '585'),
        const MembershipDraft(userId: '585', planId: 'GOLD'),
        const MembershipDraft(
          userId: '585',
          planId: 'GOLD',
          planName: 'Gold Annual',
        ),
        const MembershipDraft(
          userId: '585',
          planId: 'GOLD',
          planName: 'Gold Annual',
          price: 12000,
        ),
        const MembershipDraft(
          userId: '585',
          planId: 'GOLD',
          planName: 'Gold Annual',
          price: 12000,
          validityDays: 365,
        ),
        MembershipDraft(
          userId: '585',
          planId: 'GOLD',
          planName: 'Gold Annual',
          price: 12000,
          validityDays: 365,
          startDate: DateTime(2026, 8, 1),
          endDate: DateTime(2027, 7, 31),
        ),
      ]) {
        await expectLater(
          repository.createMembership(draft),
          throwsA(isA<ValidationException>()),
        );
      }

      expect(called, isFalse);

      await repository.createMembership(base);
      expect(called, isTrue);
    });

    test('an update with nothing in it is refused rather than sent', () async {
      var called = false;
      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          called = true;
          return http.Response(jsonEncode({'success': true}), 200);
        }),
      );

      await expectLater(
        MembershipRepositoryImpl().updateMembership(
          'm-7',
          const MembershipDraft(),
        ),
        throwsA(isA<BadRequestException>()),
      );
      expect(called, isFalse);
    });

    test('a cancellation without a reason never reaches the server', () async {
      var called = false;
      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          called = true;
          return http.Response(jsonEncode({'success': true}), 200);
        }),
      );

      await expectLater(
        MembershipRepositoryImpl().cancelMembership('m-7', '   '),
        throwsA(isA<ValidationException>()),
      );
      expect(called, isFalse);
    });

    test('the sweep reports a count only when the server sent one', () async {
      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {'updated': 4},
            }),
            200,
          );
        }),
      );
      expect(await MembershipRepositoryImpl().checkExpired(), 4);

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          return http.Response(jsonEncode({'success': true}), 200);
        }),
      );
      expect(await MembershipRepositoryImpl().checkExpired(), isNull);
    });
  });
}

// -----------------------------------------------------------------------------
// Fakes
// -----------------------------------------------------------------------------

class _FakeRepository implements MembershipRepository {
  _FakeRepository({
    List<Membership>? rows,
    this.detail,
    this.stats,
    this.total,
    this.pageSize,
    this.echoPageOne = false,
    this.failList = false,
    this.failStats = false,
    this.failStatus = false,
    this.failDelete = false,
  }) : rows = rows ?? [_membership(id: '1'), _membership(id: '2')];

  final List<Membership> rows;
  final Membership? detail;
  final MembershipStats? stats;
  final int? total;

  /// When set, the fake serves [total] rows in pages of this size.
  final int? pageSize;
  final bool echoPageOne;

  final bool failList;
  final bool failStats;
  final bool failStatus;
  final bool failDelete;

  int pageCalls = 0;
  int detailCalls = 0;
  int sweeps = 0;
  MembershipStatus? lastStatus;
  final List<int> cataloguePages = <int>[];
  final List<String> userPlanCalls = <String>[];
  final List<String> cancelReasons = <String>[];
  final List<MembershipPaymentStatus> payments = <MembershipPaymentStatus>[];
  final List<(int, num)> renewals = <(int, num)>[];
  final List<String> deleted = <String>[];

  @override
  Future<Paged<Membership>> fetchMemberships({
    int page = 1,
    int limit = 20,
    MembershipStatus? status,
  }) async {
    if (failList) {
      throw const ServerException('The memberships service is down');
    }
    lastStatus = status;

    if (limit == MembershipsController.cataloguePageSize) {
      cataloguePages.add(page);
      return Paged<Membership>(
        items: page == 1 ? rows : const [],
        page: page,
        limit: limit,
        total: rows.length,
        totalPages: 1,
      );
    }

    pageCalls++;

    if (pageSize != null && total != null) {
      final served = echoPageOne ? 1 : page;
      final start = (served - 1) * pageSize!;
      final items = [
        for (var i = start; i < start + pageSize! && i < total!; i++)
          _membership(id: '${i + 1}'),
      ];
      return Paged<Membership>(
        items: items,
        page: served,
        limit: pageSize!,
        total: total!,
        totalPages: (total! / pageSize!).ceil(),
      );
    }

    return Paged<Membership>(
      items: rows,
      page: page,
      limit: limit,
      total: total ?? rows.length,
      totalPages: total == null ? 1 : (total! / limit).ceil(),
    );
  }

  @override
  Future<MembershipStats> fetchStats() async {
    if (failStats) throw const ServerException('Stats are down');
    return stats ?? const MembershipStats();
  }

  @override
  Future<Membership> fetchMembership(String id) async {
    detailCalls++;
    return detail ?? Membership(id: id);
  }

  @override
  Future<List<Membership>> fetchForUser(String userId) async {
    userPlanCalls.add(userId);
    return [_membership(id: 'old-$userId', status: 'Expired')];
  }

  @override
  Future<Membership?> fetchActiveForUser(String userId) async =>
      _membership(id: 'active-$userId');

  @override
  Future<Membership> createMembership(MembershipDraft draft) async =>
      const Membership(id: 'new');

  @override
  Future<Membership> updateMembership(String id, MembershipDraft draft) async =>
      Membership(id: id);

  @override
  Future<void> setStatus(String id, MembershipStatus status) async {
    if (failStatus) throw const ServerException('Rejected');
  }

  @override
  Future<void> setPaymentStatus(
    String id,
    MembershipPaymentStatus payment,
  ) async {
    payments.add(payment);
  }

  @override
  Future<void> cancelMembership(String id, String reason) async {
    cancelReasons.add(reason);
  }

  @override
  Future<Membership> renewMembership(
    String id, {
    required int validityDays,
    required num totalAmount,
  }) async {
    renewals.add((validityDays, totalAmount));
    return Membership(id: id);
  }

  @override
  Future<void> deleteMembership(String id) async {
    if (failDelete) throw const ServerException('Rejected');
    deleted.add(id);
  }

  @override
  Future<int?> checkExpired() async {
    sweeps++;
    return 4;
  }
}
