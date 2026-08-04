import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nahata_app/features/admin/domain/entities/admin_role.dart';
import 'package:nahata_app/features/admin/domain/entities/admin_sports_complex.dart';
import 'package:nahata_app/features/admin/domain/repositories/sports_complex_admin_repository.dart';
import 'package:nahata_app/features/admin/presentation/pages/sports_complexes_page.dart';
import 'package:nahata_app/features/admin/presentation/state/sports_complexes_controller.dart';
import 'package:nahata_app/features/admin/presentation/theme/admin_theme.dart';
import 'package:nahata_app/features/admin/presentation/widgets/sports_complexes_table.dart';

/// Paints the Sports Complexes page against a fake repository.
///
/// This is the compile-and-paint check the console's other modules already
/// have: the eleven-column table, the summary card row and the mobile card
/// list all get laid out for real, so an overflow shows up here rather than on
/// a device.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    required Size size,
    SportsComplexAdminRepository? repository,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final controller = SportsComplexesController(
      repository ?? _FakeRepository(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AdminTheme.build(Brightness.light),
        home: ChangeNotifierProvider<SportsComplexesController>.value(
          value: controller,
          child: const Scaffold(body: SportsComplexesPage()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('the desktop layout paints the table and the summary cards', (
    tester,
  ) async {
    await pumpPage(tester, size: const Size(1800, 1000));

    expect(find.text('Sports Complexes'), findsWidgets);
    expect(find.byType(SportsComplexesTable), findsOneWidget);

    // The four summary cards, counted from the catalogue.
    expect(find.text('Total sports complexes'), findsOneWidget);
    expect(find.text('Active complexes'), findsOneWidget);
    expect(find.text('Hidden from frontend'), findsOneWidget);
    expect(find.text('Total cities'), findsOneWidget);

    // The rows themselves.
    expect(find.text('Kothrud Arena'), findsWidgets);
    expect(find.text('Marina Courts'), findsWidgets);

    // Every row carries a visibility switch.
    expect(find.byType(FrontendVisibilitySwitch), findsNWidgets(3));

    expect(tester.takeException(), isNull);
  });

  testWidgets('a narrow viewport swaps the table for stacked cards', (
    tester,
  ) async {
    await pumpPage(tester, size: const Size(420, 900));

    expect(find.byType(SportsComplexesTable), findsNothing);
    expect(find.byType(SportsComplexCard), findsNWidgets(3));
    expect(find.text('Add Sports Complex'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty catalogue explains itself instead of showing a table', (
    tester,
  ) async {
    await pumpPage(
      tester,
      size: const Size(1800, 1000),
      repository: _FakeRepository(complexes: const []),
    );

    expect(find.text('No sports complexes yet'), findsOneWidget);
    expect(find.byType(SportsComplexesTable), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a load failure offers a retry rather than an empty table', (
    tester,
  ) async {
    await pumpPage(
      tester,
      size: const Size(1800, 1000),
      repository: _FailingRepository(),
    );

    expect(find.text('Could not load sports complexes'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeRepository implements SportsComplexAdminRepository {
  _FakeRepository({List<AdminSportsComplex>? complexes})
    : complexes =
          complexes ??
          [
            AdminSportsComplex(
              id: 1,
              name: 'Kothrud Arena',
              address: 'Paud Road',
              city: 'Pune',
              state: 'Maharashtra',
              contactPhone: '02025551234',
              contactEmail: 'arena@example.com',
              openingHours: '6 AM - 11 PM',
              statusRaw: 'Active',
              showOnFrontend: true,
              createdAt: DateTime(2025, 2, 10),
            ),
            AdminSportsComplex(
              id: 2,
              name: 'Marina Courts',
              city: 'Chennai',
              state: 'Tamil Nadu',
              statusRaw: 'Inactive',
              showOnFrontend: false,
              createdAt: DateTime(2025, 5, 1),
            ),
            const AdminSportsComplex(
              id: 3,
              name: 'Baner Turf',
              city: 'Pune',
              statusRaw: 'Active',
            ),
          ];

  final List<AdminSportsComplex> complexes;

  @override
  Future<List<AdminSportsComplex>> fetchComplexes() async => complexes;

  @override
  Future<List<AdminSportsComplex>> fetchComplexesByCity(String city) async =>
      complexes;

  @override
  Future<List<AdminSportsComplex>> fetchComplexesByState(String state) async =>
      complexes;

  @override
  Future<AdminSportsComplex> fetchComplex(int id) async =>
      AdminSportsComplex(id: id);

  @override
  Future<SportsComplexStats> fetchStats(int id) async =>
      const SportsComplexStats(totalCourts: 8, activeCourts: 6);

  @override
  Future<AdminSportsComplex> createComplex(SportsComplexDraft draft) async =>
      const AdminSportsComplex(id: 99);

  @override
  Future<AdminSportsComplex> updateComplex(
    int id,
    SportsComplexDraft draft,
  ) async => AdminSportsComplex(id: id);

  @override
  Future<void> deleteComplex(int id) async {}

  @override
  Future<void> setStatus(int id, AdminUserStatus status) async {}

  @override
  Future<void> setVisibility(int id, bool showOnFrontend) async {}

  @override
  Future<String> uploadImage(String filePath, {String? filename}) async =>
      'https://cdn/x.jpg';

  @override
  Future<void> deleteImage(String imageUrl) async {}
}

class _FailingRepository extends _FakeRepository {
  @override
  Future<List<AdminSportsComplex>> fetchComplexes() async {
    throw Exception('boom');
  }
}
