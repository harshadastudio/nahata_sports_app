import 'package:flutter/material.dart';

import '../core/services/permission_service.dart';
import '../core/storage/profile_cache.dart';
import '../core/utils/app_logger.dart';
import '../models/coach_dashboard_model.dart';
import '../repositories/coach_repository.dart';

/// Coach dashboard, backed by the JWT API:
///
/// * `GET /coach/dashboard/stats` — the six headline numbers
/// * `GET /coach/dashboard/schedule/today` — today's sessions
/// * `GET /coach/dashboard/students/top-performers`
///
/// The coach is identified by the bearer token, so no id is sent and none has
/// to be read out of SharedPreferences first.
///
/// Old API (commented out at the bottom of this file): the legacy
/// `POST nahatasports.com/api/dashboard` with `{user_id, role}`, which carried
/// the fee totals this screen used to chart. The new stats endpoint has no fee
/// figures — those live on the Mark Fees screen.
class CoachDashboardScreen1 extends StatefulWidget {
  const CoachDashboardScreen1({super.key});

  @override
  State<CoachDashboardScreen1> createState() => _CoachDashboardScreen1State();
}

class _CoachDashboardScreen1State extends State<CoachDashboardScreen1> {
  static const Color brandBlue = Color(0xFF0A198D);

  bool isLoading = true;

  CoachStats stats = CoachStats.empty;
  List<CoachSession> schedule = const <CoachSession>[];
  List<TopPerformer> performers = const <TopPerformer>[];

  /// Venue the coach is attached to, from the cached `/auth/profile`.
  String? venueName;

  @override
  void initState() {
    super.initState();
    _loadVenue();
    fetchDashboardData();
  }

  /// `sportComplex` is not a typed field on [ProfileModel], so it arrives in
  /// `extras` verbatim.
  Future<void> _loadVenue() async {
    final profile = await ProfileCache.instance.read();
    final complex = profile?.extras['sportComplex'];
    final name = complex is Map ? complex['name']?.toString() : null;

    if (!mounted || name == null || name.isEmpty) return;
    setState(() => venueName = name);
  }

  Future<void> fetchDashboardData() async {
    if (mounted) setState(() => isLoading = true);

    // One dead section must not blank the others, so these are awaited
    // together and each repository call already swallows its own failure.
    final results = await Future.wait([
      CoachRepository.instance.fetchStats(),
      CoachRepository.instance.fetchTodaySchedule(),
      CoachRepository.instance.fetchTopPerformers(),
    ]);

    if (!mounted) return;

    setState(() {
      stats = results[0] as CoachStats;
      schedule = results[1] as List<CoachSession>;
      performers = results[2] as List<TopPerformer>;
      isLoading = false;
    });

    AppLogger.debug(
      'Dashboard: ${stats.totalStudents} students, '
      '${schedule.length} sessions today, ${performers.length} performers',
      name: 'Coach',
    );
  }

  // ----------------- UI WIDGETS -----------------------

  Widget statCard(
    String title,
    String value,
    IconData icon,
    Color c1,
    Color c2,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [c1, c2]),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: c1.withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(2, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: Colors.white70, size: 22),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget sectionTitle(String title, {String? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          if (trailing != null)
            Text(
              trailing,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
        ],
      ),
    );
  }

  Widget card({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(2, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget emptyCard(String message, IconData icon) {
    return card(
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade400, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- TODAY'S SCHEDULE ----------------
  Widget sessionCard(CoachSession session) {
    return card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  session.batchName ?? 'Session',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              if ((session.status ?? '').isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: session.isActive
                        ? Colors.green.shade50
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    session.status!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: session.isActive
                          ? Colors.green.shade700
                          : Colors.grey.shade700,
                    ),
                  ),
                ),
            ],
          ),
          if ((session.sportName ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              session.sportName!,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.schedule, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(
                session.timeLabel,
                style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
              ),
              const SizedBox(width: 16),
              Icon(Icons.people_outline, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(
                session.studentLabel,
                style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
              ),
            ],
          ),
          if (session.hasCourt) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.place_outlined, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(
                  session.court!,
                  style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ---------------- TOP PERFORMERS ----------------
  Widget performerCard(TopPerformer performer, int rank) {
    return card(
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: brandBlue.withOpacity(0.1),
            backgroundImage: (performer.avatar ?? '').isNotEmpty
                ? NetworkImage(performer.avatar!)
                : null,
            child: (performer.avatar ?? '').isNotEmpty
                ? null
                : Text(
                    performer.initial,
                    style: const TextStyle(
                      color: brandBlue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$rank. ${performer.displayName}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                if (performer.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    performer.subtitle,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
          Text(
            performer.scoreLabel,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  // ----------------- BUILD UI -----------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text("Coach Dashboard",
            style: TextStyle(color: Colors.white)),
        backgroundColor: brandBlue,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: isLoading ? null : fetchDashboardData,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: fetchDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (venueName != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          children: [
                            Icon(Icons.place_outlined,
                                size: 18, color: Colors.grey.shade600),
                            const SizedBox(width: 6),
                            Text(
                              venueName!,
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 1.35,
                      children: [
                        statCard("Total Students", "${stats.totalStudents}",
                            Icons.people, Colors.purple, Colors.deepPurple),
                        statCard("Present Today", stats.attendanceLabel,
                            Icons.how_to_reg, Colors.green, Colors.lightGreen),
                        statCard("Sessions Today", "${stats.sessionsToday}",
                            Icons.event_available, Colors.blue,
                            Colors.lightBlue),
                        statCard("Total Batches", "${stats.totalBatches}",
                            Icons.groups, Colors.teal, Colors.tealAccent),
                        statCard("Avg Performance", stats.performanceLabel,
                            Icons.trending_up, Colors.orange, Colors.amber),
                        statCard("Active Enquiries", "${stats.activeEnquiries}",
                            Icons.question_answer, Colors.redAccent,
                            Colors.orangeAccent),
                      ],
                    ),

                    sectionTitle(
                      "Today's Schedule",
                      trailing: schedule.isEmpty ? null : '${schedule.length}',
                    ),
                    if (schedule.isEmpty)
                      emptyCard(
                          'No sessions scheduled for today', Icons.event_busy)
                    else
                      ...schedule.map(sessionCard),

                    // Performance is a separate grant, so the section is only
                    // shown to coaches who have it.
                    if (PermissionService.instance
                        .hasPermission(CoachPermissions.performance)) ...[
                      sectionTitle("Top Performers"),
                      if (performers.isEmpty)
                        emptyCard('No performance data yet',
                            Icons.emoji_events_outlined)
                      else
                        ...performers.asMap().entries.map(
                              (e) => performerCard(e.value, e.key + 1),
                            ),
                    ],

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
}

// ---------------------- OLD API (commented out) ----------------------
//
// Backed by `POST nahatasports.com/api/dashboard` with `{user_id, role}`,
// which returned `students_under_coach`, `fees.paid`, `fees.pending`,
// `pending_fee_count` and `admin_status`. The coach id had to be dug out of
// SharedPreferences first; the JWT API identifies the coach by bearer token.
//
// The fee totals and the pie/bar charts below have no equivalent on
// `/coach/dashboard/stats` — fees are handled by the Mark Fees screen.
//
// Future<void> _loadCoachId() async {
//   final prefs = await SharedPreferences.getInstance();
//   final userJson = prefs.getString('user');
//
//   if (userJson == null) {
//     print("⚠ No user stored in SharedPreferences");
//     setState(() => isLoading = false);
//     return;
//   }
//
//   final user = jsonDecode(userJson);
//
//   final rawId = user['coach_id'] ?? user['id'];
//   coachId = rawId is int ? rawId : int.tryParse(rawId.toString());
//
//   if (coachId != null) {
//     fetchDashboardData();
//   } else {
//     setState(() => isLoading = false);
//   }
// }
//
// Future<void> fetchDashboardData() async {
//   try {
//     const url = "https://nahatasports.com/api/dashboard";
//
//     final response = await http.post(
//       Uri.parse(url),
//       headers: {"Content-Type": "application/json"},
//       body: jsonEncode({
//         "user_id": coachId.toString(),
//         "role": "coach",
//       }),
//     );
//
//     if (response.statusCode == 200) {
//       final data = jsonDecode(response.body);
//
//       setState(() {
//         totalStudents = int.tryParse(data["students_under_coach"].toString()) ?? 0;
//         totalPaidFees = data["fees"]["paid"] ?? "0.00";
//         totalPendingFees = data["fees"]["pending"] ?? "0.00";
//         pendingFeeCount = int.tryParse(data["pending_fee_count"].toString()) ?? 0;
//
//         approvedAdmin = int.tryParse(data["admin_status"]["approved"].toString()) ?? 0;
//         pendingAdmin = int.tryParse(data["admin_status"]["pending"].toString()) ?? 0;
//         rejectedAdmin = int.tryParse(data["admin_status"]["rejected"].toString()) ?? 0;
//
//         isLoading = false;
//       });
//     } else {
//       setState(() => isLoading = false);
//     }
//   } catch (e) {
//     setState(() => isLoading = false);
//   }
// }
//
// // ---------------- PIE CHART ----------------
// Widget feesPieChart() {
//   final paid = double.tryParse(totalPaidFees) ?? 0;
//   final pending = double.tryParse(totalPendingFees) ?? 0;
//
//   // Avoid crash when both values = 0
//   final showPaid = paid == 0 && pending == 0 ? 1.0 : paid;
//   final showPending = paid == 0 && pending == 0 ? 0.0 : pending;
//
//   return PieChart(
//     PieChartData(
//       sectionsSpace: 3,
//       centerSpaceRadius: 45,
//       sections: [
//         PieChartSectionData(
//           color: Colors.green,
//           value: showPaid,
//           title: "Paid",
//           radius: 55,
//           titleStyle: const TextStyle(color: Colors.white),
//         ),
//         PieChartSectionData(
//           color: Colors.red,
//           value: showPending,
//           title: "Pending",
//           radius: 55,
//           titleStyle: const TextStyle(color: Colors.white),
//         )
//       ],
//     ),
//   );
// }
//
// // ----------------- BAR CHART -----------------
// Widget adminBarChart() {
//   return BarChart(
//     BarChartData(
//       barGroups: [
//         BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: approvedAdmin.toDouble(), color: Colors.green)]),
//         BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: pendingAdmin.toDouble(), color: Colors.orange)]),
//         BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: rejectedAdmin.toDouble(), color: Colors.red)]),
//       ],
//       titlesData: FlTitlesData(
//         bottomTitles: AxisTitles(
//           sideTitles: SideTitles(showTitles: true, getTitlesWidget: (val, meta) {
//             return Text(
//               val == 0 ? "Approved" : val == 1 ? "Pending" : "Rejected",
//               style: const TextStyle(fontSize: 12),
//             );
//           }),
//         ),
//       ),
//     ),
//   );
// }
