import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nahata_app/core/services/permission_service.dart';
import 'package:nahata_app/models/profile_model.dart';
import 'package:nahata_app/features/coach/presentation/navigation/coach_destination.dart';
import 'package:nahata_app/features/coach/presentation/pages/coach_home_page.dart';
import 'package:nahata_app/features/coach/presentation/pages/coach_overview_page.dart';
import 'package:nahata_app/features/coach/presentation/theme/coach_theme.dart';

import 'package:nahata_app/features/coach/domain/entities/coach_attendance.dart';
import 'package:nahata_app/features/coach/domain/entities/coach_batch.dart';
import 'package:nahata_app/features/coach/domain/entities/coach_enquiry.dart';
import 'package:nahata_app/features/coach/domain/entities/coach_enrollment.dart';
import 'package:nahata_app/features/coach/domain/entities/coach_fee.dart';
import 'package:nahata_app/features/coach/domain/entities/coach_notification.dart';
import 'package:nahata_app/features/coach/domain/entities/coach_option.dart';
import 'package:nahata_app/features/coach/domain/entities/coach_overview.dart';
import 'package:nahata_app/features/coach/domain/entities/coach_paged.dart';
import 'package:nahata_app/features/coach/domain/entities/coach_pass_scan.dart';
import 'package:nahata_app/features/coach/domain/entities/coach_progress.dart';
import 'package:nahata_app/features/coach/domain/entities/coach_student.dart';
import 'package:nahata_app/features/coach/domain/repositories/coach_dashboard_repository.dart';

import 'package:nahata_app/features/coach/presentation/pages/coach_enquiries_page.dart';
import 'package:nahata_app/features/coach/presentation/pages/coach_enrollments_page.dart';
import 'package:nahata_app/features/coach/presentation/pages/coach_fees_page.dart';
import 'package:nahata_app/features/coach/presentation/pages/coach_notifications_page.dart';
import 'package:nahata_app/features/coach/presentation/pages/coach_progress_page.dart';
import 'package:nahata_app/features/coach/presentation/pages/coach_schedule_page.dart';
import 'package:nahata_app/features/coach/presentation/pages/coach_students_page.dart';

/// Renders every coach page against a stub repository.
///
/// These exist because the whole module shipped without once being run: a
/// layout fault in the shared card blanked every screen at runtime while the
/// analyzer and the APK build both stayed green. A compiling screen is not a
/// rendering screen, and only pumping one proves it.
///
/// Each page is pumped twice — - once with rows and once empty — because the
/// empty state is a different widget tree, and it is the one a brand-new coach
/// account actually sees first.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The home and overview pages read the cached profile and the permission
  // set. Granting every destination's own permission is what a fully-enabled
  // coach account looks like, and it is the widest tree the pages can build.
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PermissionService.instance.sync(
      ProfileModel(
        id: 1,
        name: 'Test Coach',
        email: 'coach@example.com',
        role: 'COACH',
        permissions: CoachDestination.values
            .map((d) => d.permission)
            .toList(growable: false),
      ),
    );
  });

  tearDown(PermissionService.instance.clear);

  Widget host(Widget child) => MaterialApp(home: child);

  /// Pumps and asserts nothing was thrown during layout or paint.
  Future<void> pumpClean(WidgetTester tester, Widget page) async {
    await tester.pumpWidget(host(page));
    // Two pumps: the first frame is the loading state, the second is what the
    // stub's data resolves into.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
  }

  // The screen a coach actually lands on, and the one that was blank: its menu
  // is a SliverList of CoachCards, which is exactly the unbounded-height
  // position the card's layout fault fired in.
  group('the landing screens', () {
    testWidgets('Home renders its menu', (t) async {
      await pumpClean(t, const CoachHomePage());

      // Only the visible slice is asserted: the menu is a lazy SliverList, so
      // the tiles below the fold are genuinely not built yet and `find.text`
      // would not see them however many are granted.
      expect(find.text('My Students'), findsOneWidget);
      expect(find.byType(CoachCard), findsWidgets);
    });

    testWidgets('Home scrolls to the tiles below the fold', (t) async {
      await pumpClean(t, const CoachHomePage());

      await t.drag(find.byType(CustomScrollView), const Offset(0, -1200));
      await t.pump();

      expect(t.takeException(), isNull);
      expect(find.text('Fees Management'), findsOneWidget);
    });

    testWidgets('Overview renders with data', (t) async {
      await pumpClean(t, CoachOverviewPage(repository: _StubCoachRepository()));
    });

    testWidgets('Overview renders empty', (t) async {
      await pumpClean(
        t,
        CoachOverviewPage(repository: _StubCoachRepository(empty: true)),
      );
    });

    testWidgets('Overview renders when every read fails', (t) async {
      await pumpClean(
        t,
        CoachOverviewPage(repository: _StubCoachRepository(failing: true)),
      );
    });
  });

  group('populated', () {
    final repo = _StubCoachRepository();

    testWidgets('My Students', (t) async {
      await pumpClean(t, CoachStudentsPage(repository: repo));
    });
    testWidgets('Student Enrollments', (t) async {
      await pumpClean(t, CoachEnrollmentsPage(repository: repo));
    });
    testWidgets('My Schedule', (t) async {
      await pumpClean(t, CoachSchedulePage(repository: repo));
    });
    testWidgets('Student Progress', (t) async {
      await pumpClean(t, CoachProgressPage(repository: repo));
    });
    testWidgets('Coaching Enquiries', (t) async {
      await pumpClean(t, CoachEnquiriesPage(repository: repo));
    });
    testWidgets('Fees Management', (t) async {
      await pumpClean(
        t,
        CoachFeesPage(mode: CoachFeesMode.management, repository: repo),
      );
    });
    testWidgets('Fees Approval', (t) async {
      await pumpClean(
        t,
        CoachFeesPage(mode: CoachFeesMode.approval, repository: repo),
      );
    });
    testWidgets('Notifications', (t) async {
      await pumpClean(t, CoachNotificationsPage(repository: repo));
    });
  });

  // The Fees Approval sheet is where the money, the edit form and the gate
  // pass all live, and none of it is on screen until a card is tapped — so the
  // pumps above would never have touched it.
  group('Fees Approval — the record sheet', () {
    /// The sheet's own route animation, pumped out by hand: the screen keeps a
    /// LinearProgressIndicator in the tree at zero opacity, so pumpAndSettle
    /// would wait on an animation that never ends.
    Future<void> openSheet(WidgetTester t) async {
      // The stats, the notice and the row itself push the button past the fold
      // of an 800×600 test window, and a tap on an off-screen target lands on
      // whatever happens to be at those coordinates instead.
      final button = find.text('View details');
      await t.ensureVisible(button);
      await t.pump();

      await t.tap(button);
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
    }

    testWidgets('opens the details, and the edit form behind them', (t) async {
      await pumpClean(
        t,
        CoachFeesPage(
          mode: CoachFeesMode.approval,
          repository: _StubCoachRepository(),
        ),
      );

      await openSheet(t);
      expect(t.takeException(), isNull);
      expect(find.text('Record #1'), findsOneWidget);
      // Not approved yet, so there is deliberately no pass to show.
      expect(find.byType(QrImageView), findsNothing);

      await t.tap(find.byIcon(Icons.edit_outlined));
      await t.pump();
      expect(find.text('Save changes'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('draws the gate pass once a record is approved', (t) async {
      await pumpClean(
        t,
        CoachFeesPage(
          mode: CoachFeesMode.approval,
          repository: _StubCoachRepository(approved: true),
        ),
      );

      await openSheet(t);
      expect(t.takeException(), isNull);
      // The hand-off sits in the sheet's footer, so it is on screen at once.
      expect(find.text('Send gate pass on WhatsApp'), findsOneWidget);

      // The pass itself is below the detail rows, and the sheet's list builds
      // lazily — it has to be scrolled to before it exists.
      await t.scrollUntilVisible(
        find.byType(QrImageView),
        300,
        scrollable: find.byType(Scrollable).last,
      );

      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.textContaining('GATEPASS-'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });

  group('empty — what a new coach account sees', () {
    final repo = _StubCoachRepository(empty: true);

    testWidgets('My Students', (t) async {
      await pumpClean(t, CoachStudentsPage(repository: repo));
    });
    testWidgets('Student Enrollments', (t) async {
      await pumpClean(t, CoachEnrollmentsPage(repository: repo));
    });
    testWidgets('My Schedule', (t) async {
      await pumpClean(t, CoachSchedulePage(repository: repo));
    });
    testWidgets('Student Progress', (t) async {
      await pumpClean(t, CoachProgressPage(repository: repo));
    });
    testWidgets('Coaching Enquiries', (t) async {
      await pumpClean(t, CoachEnquiriesPage(repository: repo));
    });
    testWidgets('Fees Management', (t) async {
      await pumpClean(
        t,
        CoachFeesPage(mode: CoachFeesMode.management, repository: repo),
      );
    });
    testWidgets('Notifications', (t) async {
      await pumpClean(t, CoachNotificationsPage(repository: repo));
    });
  });

  group('failing — every read throws', () {
    final repo = _StubCoachRepository(failing: true);

    testWidgets('My Students shows an error, not a crash', (t) async {
      await pumpClean(t, CoachStudentsPage(repository: repo));
    });
    testWidgets('Fees Management shows an error, not a crash', (t) async {
      await pumpClean(
        t,
        CoachFeesPage(mode: CoachFeesMode.management, repository: repo),
      );
    });
    testWidgets('Notifications shows an error, not a crash', (t) async {
      await pumpClean(t, CoachNotificationsPage(repository: repo));
    });
  });
}

/// A repository that answers instantly with fixed data.
///
/// [empty] returns nothing everywhere; [failing] throws on every read, which
/// is what an expired session or a coach with no linked Coach row produces.
class _StubCoachRepository implements CoachDashboardRepository {
  _StubCoachRepository({
    this.empty = false,
    this.failing = false,
    this.approved = false,
  });

  final bool empty;
  final bool failing;

  /// Flips the fee record to signed-off, which is the only state that draws a
  /// gate pass.
  final bool approved;

  void _guard() {
    if (failing) throw Exception('stub failure');
  }

  List<T> _rows<T>(List<T> rows) => empty ? const [] : rows;

  CoachPaged<T> _page<T>(List<T> rows) {
    final items = _rows(rows);
    return CoachPaged<T>(
      items: items,
      page: 1,
      limit: 20,
      total: items.length,
      totalPages: items.isEmpty ? 0 : 1,
    );
  }

  @override
  Future<CoachDashboardStats> getStats() async {
    _guard();
    return const CoachDashboardStats(totalStudents: 4, presentToday: 3);
  }

  @override
  Future<List<CoachSession>> getTodaySchedule() async {
    _guard();
    return _rows([const CoachSession(id: 1, batchName: 'Evening Batch')]);
  }

  @override
  Future<List<CoachTopPerformer>> getTopPerformers() async {
    _guard();
    return _rows([const CoachTopPerformer(id: 1, name: 'Asha', score: 88)]);
  }

  @override
  Future<CoachPaged<CoachStudent>> getStudents({
    int page = 1,
    int limit = 20,
    String? search,
    String? status,
  }) async {
    _guard();
    return _page([
      const CoachStudent(
        id: 1,
        name: 'Asha Rao',
        email: 'asha@example.com',
        phone: '9000000000',
        batchName: 'Evening Batch',
        attendanceRaw: '80%',
        performanceRaw: '88%',
        statusRaw: 'Active',
      ),
    ]);
  }

  @override
  Future<CoachEnrollmentMonthView> getEnrollmentsByMonth({
    String? month,
    String? search,
    String? status,
  }) async {
    _guard();
    if (empty) return CoachEnrollmentMonthView.empty;

    return const CoachEnrollmentMonthView(
      month: '2026-08',
      label: 'August 2026',
      months: [
        CoachEnrollmentMonth(month: '2026-08', label: 'August 2026', count: 1),
      ],
      summary: CoachEnrollmentSummary(totalStudents: 1, totalBatches: 1),
      batches: [
        CoachEnrollmentGroup(
          batchId: 1,
          name: 'Evening Batch',
          sportName: 'Badminton',
          count: 1,
          newCount: 1,
          students: [
            CoachEnrollment(
              enrollmentId: 10,
              studentId: 1,
              name: 'Asha Rao',
              email: 'asha@example.com',
              phone: '9000000000',
              enrollmentDate: '2026-08-01',
              validTill: '2026-08-31',
              isNew: true,
              statusRaw: 'Active',
              paymentStatusRaw: 'Paid',
              approvalStatusRaw: 'Pending',
            ),
          ],
        ),
      ],
    );
  }

  @override
  Future<CoachPaged<CoachBatch>> getBatches({
    int page = 1,
    int limit = 20,
    String? status,
    int? sportId,
  }) async {
    _guard();
    return _page([
      CoachBatch(
        id: 1,
        name: 'Evening Batch',
        sportName: 'Badminton',
        schedule: '5pm to 6pm',
        days: 'Mon, Wed, Fri',
        studentCount: 8,
        maxStudents: 20,
        statusRaw: 'Active',
        fees: 1500,
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2026, 12, 31),
      ),
    ]);
  }

  @override
  Future<CoachPaged<CoachProgress>> getProgress({
    int page = 1,
    int limit = 20,
    int? studentId,
    int? sportId,
  }) async {
    _guard();
    return _page([
      CoachProgress(
        id: 1,
        studentId: 1,
        sportId: 1,
        studentName: 'Asha Rao',
        sportName: 'Badminton',
        batchName: 'Evening Batch',
        currentScore: 88,
        skillLevelRaw: 'Intermediate',
        previousScore: 83,
        improvementRaw: '+5',
        lastUpdated: DateTime(2026, 8, 1),
        notes: 'Footwork much improved.',
      ),
    ]);
  }

  @override
  Future<CoachPaged<CoachAttendanceRecord>> getAttendanceRecords({
    int page = 1,
    int limit = 20,
    String? date,
    String? status,
    int? batchId,
  }) async {
    _guard();
    return _page([
      CoachAttendanceRecord(
        id: 1,
        studentName: 'Asha Rao',
        batchName: 'Evening Batch',
        date: DateTime(2026, 8, 6),
        statusRaw: 'Present',
      ),
    ]);
  }

  @override
  Future<CoachPaged<CoachEnquiry>> getEnquiries({
    int page = 1,
    int limit = 20,
    CoachEnquiryStatus? status,
  }) async {
    _guard();
    return _page([
      CoachEnquiry(
        id: 1,
        name: 'Ravi Kumar',
        email: 'ravi@example.com',
        phone: '9111111111',
        statusRaw: 'Pending',
        batchName: 'Evening Batch',
        sportName: 'Badminton',
        referenceNumber: 'NSC-20260806-AB12X',
        createdAt: DateTime(2026, 8, 6),
        message: 'Interested in evening coaching.',
      ),
    ]);
  }

  @override
  Future<CoachPaged<CoachFee>> getFees({
    int page = 1,
    int limit = 20,
    CoachPaymentStatus? paymentStatus,
    CoachApprovalStatus? approvalStatus,
    String? search,
    int? batchId,
  }) async {
    _guard();
    return _page([
      CoachFee(
        id: 1,
        studentId: 1,
        studentName: 'Asha Rao',
        studentPhone: '9000000000',
        batchId: 1,
        batchName: 'Evening Batch',
        sportName: 'Badminton',
        enrollmentDate: '2026-08-01',
        validTill: '2026-08-31',
        paymentStatusRaw: 'Paid',
        approvalStatusRaw: approved ? 'Approved' : 'Pending',
        paymentModeRaw: 'Cash',
        amountPaid: 1500,
        batchFees: 1500,
        approvedAt: approved ? DateTime(2026, 8, 7, 10, 30) : null,
      ),
    ]);
  }

  @override
  Future<CoachFeeStats> getFeeStats() async {
    _guard();
    if (empty) return CoachFeeStats.empty;
    return const CoachFeeStats(
      total: 4,
      paid: 2,
      unpaid: 1,
      overdue: 1,
      pendingApproval: 2,
    );
  }

  @override
  Future<CoachPaged<CoachNotification>> getNotifications({
    int page = 1,
    int limit = 20,
  }) async {
    _guard();
    return _page([
      CoachNotification(
        id: 1,
        title: 'Practice moved',
        message: 'Evening batch shifts to 6pm tomorrow.',
        typeRaw: 'System',
        sentAt: DateTime(2026, 8, 6),
      ),
    ]);
  }

  @override
  Future<int> getUnreadNotificationCount() async {
    _guard();
    return empty ? 0 : 1;
  }

  @override
  Future<List<CoachNotificationRecipient>> getNotificationRecipients() async {
    _guard();
    return _rows([
      const CoachNotificationRecipient(
        id: 1,
        name: 'Asha Rao',
        email: 'asha@example.com',
        role: 'USER',
      ),
    ]);
  }

  @override
  Future<List<CoachOption>> searchStudents({String? search}) async {
    _guard();
    return _rows([const CoachOption(id: 1, name: 'Asha Rao')]);
  }

  @override
  Future<List<CoachOption>> searchSports({String? search}) async {
    _guard();
    return _rows([const CoachOption(id: 1, name: 'Badminton')]);
  }

  @override
  Future<List<CoachOption>> searchBatches({String? search}) async {
    _guard();
    return _rows([const CoachOption(id: 1, name: 'Evening Batch')]);
  }

  @override
  Future<CoachPassScan> scanStudentPass(String passCode) async => throw
      UnimplementedError('the scanner needs a camera, so it is not pumped');

  // ── Writes: never exercised by a smoke pump ───────────────────────────────
  @override
  Future<void> createProgress(CoachProgressDraft draft) async {}
  @override
  Future<void> updateProgress(int id, CoachProgressDraft draft) async {}
  @override
  Future<void> deleteProgress(int id) async {}
  @override
  Future<void> markAttendance(CoachAttendanceDraft draft) async {}
  @override
  Future<List<({CoachAttendanceDraft draft, String error})>>
      markAttendanceSheet(List<CoachAttendanceDraft> drafts) async => const [];
  @override
  Future<void> createEnquiry(CoachEnquiryDraft draft) async {}
  @override
  Future<void> updateEnquiryStatus({
    required int id,
    required CoachEnquiryStatus status,
  }) async {}
  @override
  Future<void> deleteEnquiry(int id) async {}
  @override
  Future<void> approveAndEnroll({
    required int id,
    CoachPaymentStatus? paymentStatus,
    num? amountPaid,
    String? notes,
  }) async {}
  @override
  Future<void> recordPayment({
    required int id,
    required CoachPaymentDraft draft,
  }) async {}
  @override
  Future<void> updateFeeRecord({
    required int id,
    required CoachFeeEdit edit,
  }) async {}
  @override
  Future<void> markNotificationRead(int id) async {}
  @override
  Future<void> markAllNotificationsRead() async {}
  @override
  Future<void> sendNotification(CoachNotificationDraft draft) async {}
}
