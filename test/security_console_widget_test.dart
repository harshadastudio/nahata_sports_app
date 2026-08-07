import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nahata_app/features/admin/domain/entities/paged.dart';
import 'package:nahata_app/features/admin/domain/entities/visitor_pass.dart';
import 'package:nahata_app/features/admin/domain/repositories/visitor_pass_repository.dart';
import 'package:nahata_app/features/admin/presentation/theme/admin_theme.dart';
import 'package:nahata_app/features/security/domain/entities/gate_scan.dart';
import 'package:nahata_app/features/security/domain/repositories/gate_scan_repository.dart';
import 'package:nahata_app/features/security/presentation/pages/security_guard_dashboard_page.dart';
import 'package:nahata_app/features/security/presentation/state/scan_journal.dart';
import 'package:nahata_app/features/security/presentation/state/security_guard_controller.dart';
import 'package:nahata_app/features/security/presentation/widgets/guard_stat_grid.dart';
import 'package:nahata_app/features/security/presentation/widgets/scan_activity_feed.dart';
import 'package:nahata_app/models/sports_complex_model.dart';

/// Renders the guard dashboard end to end against fake repositories.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 8, 7, 14, 30);
  final today = DateTime(2026, 8, 7);

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  VisitorPass pass({required int id, String? status, DateTime? entry}) =>
      VisitorPass(
        id: id,
        passCode: 'VP-$id',
        visitorName: 'Visitor $id',
        statusRaw: status,
        entryTime: entry,
        createdAt: today.add(Duration(hours: 8 + id)),
      );

  Future<SecurityGuardController> pumpDashboard(
    WidgetTester tester, {
    List<VisitorPass> passes = const [],
    Size size = const Size(1500, 2400),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final journal = ScanJournal();
    final controller = SecurityGuardController(
      visitorPasses: _FakeVisitorPasses(passes),
      gates: _FakeGates(),
      journal: journal,
      clock: () => now,
    );
    addTearDown(controller.dispose);
    addTearDown(journal.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SecurityGuardController>.value(
            value: controller,
          ),
          ChangeNotifierProvider<ScanJournal>.value(value: journal),
        ],
        child: MaterialApp(
          theme: AdminTheme.build(Brightness.light),
          home: const Scaffold(body: SecurityGuardDashboardPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    return controller;
  }

  testWidgets('shows all eight counters and the quick scans', (tester) async {
    await pumpDashboard(
      tester,
      passes: [
        pass(id: 1, status: 'Pending'),
        pass(
          id: 2,
          status: 'Checked In',
          entry: today.add(const Duration(hours: 10)),
        ),
        pass(id: 3, status: 'Checked Out'),
      ],
    );

    expect(find.byType(GuardStatGrid), findsOneWidget);
    for (final label in const [
      'Visitor Passes Today',
      'Visitors Inside',
      'Visitors Checked Out',
      'Event Pass Entries',
      'Court Booking Entries',
      'Coaching Pass Scans',
      'Total Scans Today',
      'Invalid QR Attempts',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }

    for (final label in const [
      'Visitor Scan',
      'Event Scan',
      'Court Booking Scan',
      'Coaching Pass Scan',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }

    expect(find.text('Recent Scan Activity'), findsOneWidget);
    expect(find.text('Global pass search'), findsOneWidget);
  });

  testWidgets('counts visitors from the server and scans from the journal',
      (tester) async {
    final controller = await pumpDashboard(
      tester,
      passes: [
        pass(id: 1, status: 'Pending'),
        pass(
          id: 2,
          status: 'Checked In',
          entry: today.add(const Duration(hours: 10)),
        ),
        pass(id: 3, status: 'Checked Out'),
      ],
    );

    expect(controller.counters.visitorPassesToday, 3);
    expect(controller.counters.visitorsInside, 1);
    expect(controller.counters.visitorsCheckedOut, 1);
    // Nothing scanned on this device yet.
    expect(controller.counters.totalScans, 0);
    expect(controller.counters.invalidAttempts, 0);

    await controller.recordScan(
      GateScanResult(
        kind: GateScanKind.event,
        outcome: GateScanOutcome.granted,
        passCode: 'EVTPASS-1',
        at: now,
        personName: 'Asha',
      ),
    );
    await controller.recordScan(
      GateScanResult(
        kind: GateScanKind.coaching,
        outcome: GateScanOutcome.invalid,
        passCode: 'GATEPASS-9',
        at: now,
      ),
    );
    await tester.pumpAndSettle();

    expect(controller.counters.eventEntries, 1);
    expect(controller.counters.coachingScans, 1);
    expect(controller.counters.totalScans, 2);
    // The refusal no backend records is the whole point of the journal.
    expect(controller.counters.invalidAttempts, 1);
  });

  testWidgets('the activity feed lists successes and refusals', (tester) async {
    final controller = await pumpDashboard(tester);

    await controller.recordScan(
      GateScanResult(
        kind: GateScanKind.courtBooking,
        outcome: GateScanOutcome.alreadyCheckedOut,
        passCode: 'BOOK-1',
        at: now,
        personName: 'Bhavesh',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ScanActivityFeed), findsOneWidget);
    expect(find.text('Bhavesh'), findsWidgets);
    expect(find.text('Already Checked Out'), findsWidgets);
  });

  testWidgets('says where the device-scoped figures come from', (tester) async {
    await pumpDashboard(tester);
    expect(find.byType(GuardCounterNote), findsOneWidget);
  });

  testWidgets('renders on a phone without overflowing', (tester) async {
    await pumpDashboard(tester, size: const Size(420, 3200));

    expect(find.byType(GuardStatGrid), findsOneWidget);
    expect(find.text('Quick Scan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('surfaces a failed load with a retry', (tester) async {
    tester.view.physicalSize = const Size(1500, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final journal = ScanJournal();
    final controller = SecurityGuardController(
      visitorPasses: _ThrowingVisitorPasses(),
      gates: _FakeGates(),
      journal: journal,
      clock: () => now,
    );
    addTearDown(controller.dispose);
    addTearDown(journal.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SecurityGuardController>.value(
            value: controller,
          ),
          ChangeNotifierProvider<ScanJournal>.value(value: journal),
        ],
        child: MaterialApp(
          theme: AdminTheme.build(Brightness.light),
          home: const Scaffold(body: SecurityGuardDashboardPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dashboard unavailable'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}

class _FakeVisitorPasses implements VisitorPassRepository {
  _FakeVisitorPasses(this.rows);

  final List<VisitorPass> rows;

  @override
  Future<Paged<VisitorPass>> fetchVisitorPasses({
    int page = 1,
    int limit = 20,
    String? search,
  }) async =>
      Paged<VisitorPass>(
        items: page == 1 ? rows : const [],
        page: page,
        limit: limit,
        total: rows.length,
        totalPages: 1,
      );

  @override
  Future<VisitorPass> fetchVisitorPass(String idOrCode) async => rows.first;

  @override
  Future<VisitorPass> createVisitorPass(VisitorPassDraft draft) async =>
      rows.first;

  @override
  Future<VisitorPassCheck> verifyPass({
    required String passCode,
    required VisitorScanType scanType,
  }) async =>
      const VisitorPassCheck(success: true, readOnly: false);

  @override
  Future<VisitorPassCheck> lookupPass(String passCode) async =>
      const VisitorPassCheck(success: true, readOnly: true);

  @override
  Future<String> sendPassEmail({
    required String idOrCode,
    required String recipientEmail,
    required String recipientName,
  }) async =>
      'Sent';

  @override
  Future<void> deleteVisitorPass(String idOrCode) async {}

  @override
  Future<List<SportsComplex>> fetchSportComplexes({
    bool refresh = false,
  }) async =>
      const [];
}

class _ThrowingVisitorPasses extends _FakeVisitorPasses {
  _ThrowingVisitorPasses() : super(const []);

  @override
  Future<Paged<VisitorPass>> fetchVisitorPasses({
    int page = 1,
    int limit = 20,
    String? search,
  }) async {
    throw Exception('gate offline');
  }
}

class _FakeGates implements GateScanRepository {
  GateScanResult _ok(GateScanKind kind, String code) => GateScanResult(
        kind: kind,
        outcome: GateScanOutcome.granted,
        passCode: code,
        at: DateTime(2026, 8, 7),
      );

  @override
  Future<GateScanResult> scanVisitorPass({
    required String passCode,
    required GateDirection direction,
  }) async =>
      _ok(GateScanKind.visitor, passCode);

  @override
  Future<ScanStats> eventScanStats(Object eventPassId) async =>
      ScanStats.empty;

  @override
  Future<GateScanResult> scanEventPass({
    required String passCode,
    required GateDirection direction,
  }) async =>
      _ok(GateScanKind.event, passCode);

  @override
  Future<GateScanResult> scanEventMember({
    required Object memberId,
    required GateDirection direction,
  }) async =>
      _ok(GateScanKind.event, 'member:$memberId');

  @override
  Future<ScanStats> courtScanStats({Object? courtId, String? date}) async =>
      ScanStats.empty;

  @override
  Future<GateScanResult> scanCourtBooking({
    required String passCode,
    required GateDirection direction,
  }) async =>
      _ok(GateScanKind.courtBooking, passCode);

  @override
  Future<GateScanResult> scanCourtMember({
    required Object memberId,
    required GateDirection direction,
  }) async =>
      _ok(GateScanKind.courtBooking, 'member:$memberId');

  @override
  Future<String> sendBookingEmail({
    required Object bookingId,
    required Object memberId,
    required String recipientEmail,
  }) async =>
      'Email sent successfully.';

  @override
  Future<GateScanResult> scanCoachingPass(String passCode) async =>
      _ok(GateScanKind.coaching, passCode);

  @override
  Future<Paged<ScanLogEntry>> scanLogs({
    int page = 1,
    int limit = 50,
    String? date,
    String? scannerRole,
    String? search,
  }) async =>
      const Paged<ScanLogEntry>();
}