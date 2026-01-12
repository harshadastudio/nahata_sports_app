import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';

class CoachDashboardScreen1 extends StatefulWidget {
  const CoachDashboardScreen1({super.key});

  @override
  State<CoachDashboardScreen1> createState() => _CoachDashboardScreen1State();
}

class _CoachDashboardScreen1State extends State<CoachDashboardScreen1> {
  bool isLoading = true;

  int totalStudents = 0;
  String totalPaidFees = "0.00";
  String totalPendingFees = "0.00";
  int pendingFeeCount = 0;

  int? coachId;

  int approvedAdmin = 0;
  int pendingAdmin = 0;
  int rejectedAdmin = 0;

  @override
  void initState() {
    super.initState();
    _loadCoachId();
  }

  // ----------------- LOAD USER ID -----------------------
  Future<void> _loadCoachId() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user');

    if (userJson == null) {
      print("⚠ No user stored in SharedPreferences");
      setState(() => isLoading = false);
      return;
    }

    final user = jsonDecode(userJson);

    final rawId = user['coach_id'] ?? user['id'];
    coachId = rawId is int ? rawId : int.tryParse(rawId.toString());

    print("✅ Loaded Coach ID: $coachId");

    if (coachId != null) {
      fetchDashboardData();
    } else {
      print("⚠ Coach ID is NULL");
      setState(() => isLoading = false);
    }
  }

  // ----------------- FETCH DASHBOARD DATA -----------------------
  Future<void> fetchDashboardData() async {
    try {
      const url = "https://nahatasports.com/api/dashboard";

      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": coachId.toString(),
          "role": "coach",
        }),
      );

      print("📩 Dashboard Response: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          totalStudents = int.tryParse(data["students_under_coach"].toString()) ?? 0;
          totalPaidFees = data["fees"]["paid"] ?? "0.00";
          totalPendingFees = data["fees"]["pending"] ?? "0.00";
          pendingFeeCount = int.tryParse(data["pending_fee_count"].toString()) ?? 0;

          approvedAdmin = int.tryParse(data["admin_status"]["approved"].toString()) ?? 0;
          pendingAdmin = int.tryParse(data["admin_status"]["pending"].toString()) ?? 0;
          rejectedAdmin = int.tryParse(data["admin_status"]["rejected"].toString()) ?? 0;

          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      print("❌ Error: $e");
      setState(() => isLoading = false);
    }
  }

  // ----------------- UI WIDGETS -----------------------

  Widget statCard(String title, String value, Color c1, Color c2) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(bottom: 14),
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
        children: [
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- PIE CHART ----------------
  Widget feesPieChart() {
    final paid = double.tryParse(totalPaidFees) ?? 0;
    final pending = double.tryParse(totalPendingFees) ?? 0;

    // Avoid crash when both values = 0
    final showPaid = paid == 0 && pending == 0 ? 1.0 : paid;
    final showPending = paid == 0 && pending == 0 ? 0.0 : pending;

    return PieChart(
      PieChartData(
        sectionsSpace: 3,
        centerSpaceRadius: 45,
        sections: [
          PieChartSectionData(
            color: Colors.green,
            value: showPaid,
            title: "Paid",
            radius: 55,
            titleStyle: const TextStyle(color: Colors.white),
          ),
          PieChartSectionData(
            color: Colors.red,
            value: showPending,
            title: "Pending",
            radius: 55,
            titleStyle: const TextStyle(color: Colors.white),
          )
        ],
      ),
    );
  }

  // ----------------- BAR CHART -----------------
  Widget adminBarChart() {
    return BarChart(
      BarChartData(
        barGroups: [
          BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: approvedAdmin.toDouble(), color: Colors.green)]),
          BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: pendingAdmin.toDouble(), color: Colors.orange)]),
          BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: rejectedAdmin.toDouble(), color: Colors.red)]),
        ],
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, getTitlesWidget: (val, meta) {
              return Text(
                val == 0 ? "Approved" : val == 1 ? "Pending" : "Rejected",
                style: const TextStyle(fontSize: 12),
              );
            }),
          ),
        ),
      ),
    );
  }

  // ----------------- LINE CHART ----------------
  Widget enrollmentLineChart() {
    return LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(
            isCurved: true,
            color: Colors.indigo,
            barWidth: 4,
            spots: const [
              FlSpot(0, 2),
              FlSpot(1, 5),
              FlSpot(2, 3),
              FlSpot(3, 4),
              FlSpot(4, 6),
              FlSpot(5, 8),
            ],
          )
        ],
      ),
    );
  }

  // ----------------- BUILD UI -----------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Coach Dashboard", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0A198D),
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            statCard("Total Students", "$totalStudents",
                Colors.purple, Colors.deepPurple),

            statCard("Total Fees Collected", "₹$totalPaidFees",
                Colors.green, Colors.lightGreen),

            statCard("Pending Fees", "₹$totalPendingFees",
                Colors.red, Colors.orange),

            statCard("Pending Fee Count", "$pendingFeeCount",
                Colors.blue, Colors.lightBlue),

            const SizedBox(height: 20),
            const Text("Fees Breakdown (Pie Chart)",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            SizedBox(height: 220, child: feesPieChart()),
            //
            // const SizedBox(height: 20),
            // const Text("Admin Fee Status",
            //     style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            // SizedBox(height: 200, child: adminBarChart()),

            // const SizedBox(height: 20),
            // const Text("Student Growth (Line Chart)",
            //     style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            // SizedBox(height: 220, child: enrollmentLineChart()),
          ],
        ),
      ),
    );
  }
}
