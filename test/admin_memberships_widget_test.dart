import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nahata_app/core/network/api_exception.dart';
import 'package:nahata_app/features/admin/domain/entities/membership.dart';
import 'package:nahata_app/features/admin/domain/entities/paged.dart';
import 'package:nahata_app/features/admin/domain/repositories/membership_repository.dart';
import 'package:nahata_app/features/admin/presentation/pages/memberships_page.dart';
import 'package:nahata_app/features/admin/presentation/state/memberships_controller.dart';
import 'package:nahata_app/features/admin/presentation/theme/admin_theme.dart';
import 'package:nahata_app/features/admin/presentation/widgets/membership_action_dialogs.dart';
import 'package:nahata_app/features/admin/presentation/widgets/membership_detail_panel.dart';
import 'package:nahata_app/features/admin/presentation/widgets/membership_form_dialog.dart';
import 'package:nahata_app/features/admin/presentation/widgets/memberships_table.dart';

/// Paints the Memberships page against a fake repository.
///
/// The eight-column table, the five summary cards, the mobile card list, the
/// detail drawer and all three dialogs get laid out for real, so an overflow
/// shows up here rather than on a device.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    required Size size,
    MembershipRepository? repository,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final controller = MembershipsController(repository ?? _FakeRepository());
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AdminTheme.build(Brightness.light),
        home: ChangeNotifierProvider<MembershipsController>.value(
          value: controller,
          child: const Scaffold(body: MembershipsPage()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('the desktop layout paints the table and the summary cards', (
    tester,
  ) async {
    await pumpPage(tester, size: const Size(1800, 1100));

    expect(find.text('Memberships'), findsWidgets);
    expect(find.byType(MembershipsTable), findsOneWidget);

    // The five summary cards.
    expect(find.text('Total memberships'), findsOneWidget);
    expect(find.text('Active'), findsWidgets);
    expect(find.text('Expired'), findsWidgets);
    expect(find.text('Cancelled'), findsWidgets);
    expect(find.text('Revenue'), findsOneWidget);

    expect(find.text('Rahul Sharma'), findsWidgets);
    expect(find.text('Gold Annual'), findsWidgets);

    expect(tester.takeException(), isNull);
  });

  testWidgets('the cards say when a figure was counted rather than reported', (
    tester,
  ) async {
    await pumpPage(tester, size: const Size(1800, 1100));

    // No stats endpoint figures in the fake, so the cards count the rows and
    // caption themselves — a different claim from the endpoint's own total.
    expect(find.textContaining('Counted'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the stats endpoint figures replace the counted ones', (
    tester,
  ) async {
    await pumpPage(
      tester,
      size: const Size(1800, 1100),
      repository: _FakeRepository(
        stats: const MembershipStats(
          total: 120,
          active: 80,
          expired: 25,
          cancelled: 15,
          revenue: 960000,
        ),
      ),
    );

    expect(find.text('120'), findsOneWidget);
    expect(find.textContaining('Counted'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a narrow viewport swaps the table for stacked cards', (
    tester,
  ) async {
    await pumpPage(tester, size: const Size(420, 900));

    expect(find.byType(MembershipsTable), findsNothing);
    expect(find.byType(MembershipCard), findsNWidgets(2));
    expect(find.text('Add Membership'), findsOneWidget);
    expect(find.byType(RefreshIndicator), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('the detail drawer opens beside the table on a desktop', (
    tester,
  ) async {
    await pumpPage(tester, size: const Size(1800, 1100));

    await tester.tap(find.text('Rahul Sharma').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(MembershipDetailPanel), findsOneWidget);
    expect(find.text('Membership details'), findsOneWidget);
    expect(find.text('Validity'), findsWidgets);
    expect(find.text('Features'), findsOneWidget);
    expect(find.text('Priority booking'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('the add dialog opens with the documented fields', (
    tester,
  ) async {
    await pumpPage(tester, size: const Size(1800, 1100));

    await tester.tap(find.text('Add Membership'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(MembershipFormDialog), findsOneWidget);
    expect(find.text('Add membership'), findsWidgets);
    // The field labels are rich text, so the hints stand in for them.
    expect(find.text('e.g. GOLD'), findsOneWidget);
    expect(find.text('e.g. Gold Annual'), findsOneWidget);
    expect(find.text('e.g. 365'), findsOneWidget);
    expect(find.text('Select a date'), findsNWidgets(2));

    expect(tester.takeException(), isNull);
  });

  testWidgets('the edit dialog explains what it will and will not send', (
    tester,
  ) async {
    await pumpPage(tester, size: const Size(1800, 1100));

    await tester.tap(find.byIcon(Icons.more_horiz_rounded).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Edit membership').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(MembershipFormDialog), findsOneWidget);
    // Only changed fields go out, and status/payment have their own routes.
    expect(find.textContaining('Only the fields you change'), findsOneWidget);
    expect(find.text('Set from the row menu.'), findsNWidgets(2));

    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelling asks for a reason before it will submit', (
    tester,
  ) async {
    await pumpPage(tester, size: const Size(1800, 1100));

    await tester.tap(find.byIcon(Icons.more_horiz_rounded).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Cancel membership').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(CancelMembershipDialog), findsOneWidget);
    expect(find.text('Customer request'), findsOneWidget);

    // Submitting empty is refused rather than cancelling without a reason.
    await tester.tap(find.text('Cancel membership').last);
    await tester.pump();
    expect(find.text('A reason is required.'), findsOneWidget);
    expect(find.byType(CancelMembershipDialog), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('the renew dialog seeds itself from the plan on record', (
    tester,
  ) async {
    await pumpPage(tester, size: const Size(1800, 1100));

    await tester.tap(find.byIcon(Icons.more_horiz_rounded).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Renew').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(RenewMembershipDialog), findsOneWidget);
    expect(find.widgetWithText(TextField, '365'), findsOneWidget);
    expect(find.widgetWithText(TextField, '12000'), findsOneWidget);
    // Said as an expectation, not a promise — the server computes the term.
    expect(find.textContaining('should run to'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty list explains itself instead of showing a table', (
    tester,
  ) async {
    await pumpPage(
      tester,
      size: const Size(1800, 1100),
      repository: _FakeRepository(rows: const []),
    );

    expect(find.text('No memberships found'), findsOneWidget);
    expect(find.byType(MembershipsTable), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a load failure offers a retry rather than an empty table', (
    tester,
  ) async {
    await pumpPage(
      tester,
      size: const Size(1800, 1100),
      repository: _FailingRepository(),
    );

    expect(find.text('Could not load the memberships'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeRepository implements MembershipRepository {
  _FakeRepository({List<Membership>? rows, this.stats})
    : rows =
          rows ??
          [
            Membership(
              id: 'm-77',
              userId: '585',
              userName: 'Rahul Sharma',
              userEmail: 'rahul@example.com',
              userPhone: '9876543210',
              planId: 'GOLD',
              planName: 'Gold Annual',
              price: 12000,
              validityDays: 365,
              bookingLimit: 50,
              bookingsUsed: 12,
              discountPercent: 10,
              discountApplied: 0,
              totalAmount: 12000,
              accessType: 'All Courts',
              features: const ['Priority booking', 'Free guest pass'],
              startDate: DateTime(2026, 8, 1),
              endDate: DateTime(2027, 7, 31),
              statusRaw: 'Active',
              paymentStatusRaw: 'Paid',
              autoRenew: false,
            ),
            Membership(
              id: 'm-78',
              userId: '586',
              userName: 'Priya Nair',
              planId: 'SILVER',
              planName: 'Silver Half-Year',
              price: 6000,
              totalAmount: 6000,
              validityDays: 180,
              bookingLimit: 20,
              startDate: DateTime(2026, 2, 1),
              endDate: DateTime(2026, 7, 30),
              statusRaw: 'Expired',
              paymentStatusRaw: 'Pending',
            ),
          ];

  final List<Membership> rows;
  final MembershipStats? stats;

  @override
  Future<Paged<Membership>> fetchMemberships({
    int page = 1,
    int limit = 20,
    MembershipStatus? status,
  }) async => Paged<Membership>(
    items: rows,
    page: page,
    limit: limit,
    total: rows.length,
    totalPages: 1,
  );

  @override
  Future<MembershipStats> fetchStats() async =>
      stats ?? const MembershipStats();

  @override
  Future<Membership> fetchMembership(String id) async =>
      rows.firstWhere((row) => row.id == id, orElse: () => Membership(id: id));

  @override
  Future<List<Membership>> fetchForUser(String userId) async => const [];

  @override
  Future<Membership?> fetchActiveForUser(String userId) async => null;

  @override
  Future<Membership> createMembership(MembershipDraft draft) async =>
      const Membership(id: 'new');

  @override
  Future<Membership> updateMembership(String id, MembershipDraft draft) async =>
      Membership(id: id);

  @override
  Future<void> setStatus(String id, MembershipStatus status) async {}

  @override
  Future<void> setPaymentStatus(
    String id,
    MembershipPaymentStatus payment,
  ) async {}

  @override
  Future<void> cancelMembership(String id, String reason) async {}

  @override
  Future<Membership> renewMembership(
    String id, {
    required int validityDays,
    required num totalAmount,
  }) async => Membership(id: id);

  @override
  Future<void> deleteMembership(String id) async {}

  @override
  Future<int?> checkExpired() async => 0;
}

class _FailingRepository extends _FakeRepository {
  @override
  Future<Paged<Membership>> fetchMemberships({
    int page = 1,
    int limit = 20,
    MembershipStatus? status,
  }) async => throw const ServerException('The memberships service is down');
}
