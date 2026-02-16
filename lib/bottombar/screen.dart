import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:table_calendar/table_calendar.dart';
import '../auth/login.dart';
import '../services/api_service.dart';
 // Assuming you have this model

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:table_calendar/table_calendar.dart';
import '../services/api_service.dart';


class Screen extends StatefulWidget {
  final String studentId;
  const Screen({Key? key, required this.studentId}) : super(key: key);

  @override
  State<Screen> createState() => _ScreenState();
}

class _ScreenState extends State<Screen> {
  static const brandBlue = Color(0xFF1A237E);
  bool isLoading = true;
  String userInitial = '';
  Map<DateTime, String> attendanceData = {};
  late Future<List<StudentData>> studentsFuture;

  @override
  void initState() {
    super.initState();
    studentsFuture = _initAndFetch();
    fetchUserInitial();
  }

  /// 🧩 Get user's first initial
  void fetchUserInitial() async {
    final user = await AuthService.getUser();
    userInitial = (user?['name'] ?? 'U').toString().substring(0, 1).toUpperCase();
    setState(() {});
  }

  /// 🔹 Load user data, then fetch student and attendance data
  Future<List<StudentData>> _initAndFetch() async {
    await ApiService.loadUserFromPrefs();

    final id = widget.studentId.isNotEmpty
        ? widget.studentId
        : (ApiService.currentUser?['student_id']?.toString() ??
        ApiService.currentUser?['id']?.toString() ??
        '');

    if (id.isEmpty) {
      throw Exception("Student ID is not available");
    }

    await fetchAttendance(id);
    return fetchStudents(int.parse(id));
  }

  /// 📡 Fetch student dashboard info
  Future<List<StudentData>> fetchStudents(int studentId) async {
    final url = Uri.parse(
      "https://nahatasports.com/api/student_dashboard?student_id=$studentId",
    );

    final response = await http.get(url, headers: {
      'Content-Type': 'application/json',
    });

    print("📘 Student Dashboard API → $studentId (${response.statusCode})");

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body['status'] == true && body['data'] != null) {
        return [StudentData.fromJson(body['data'])];
      } else {
        throw Exception("API returned false or null data");
      }
    } else {
      throw Exception("Failed to fetch student dashboard");
    }
  }

  /// ✅ Fetch attendance from API
  Future<void> fetchAttendance(String studentId) async {
    final url = Uri.parse(
      "https://nahatasports.com/student/attendance?student_id=$studentId",
    );

    try {
      final response = await http.get(url);
      print("📗 Attendance API (${response.statusCode}) for $studentId");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true && data['data'] != null) {
          final Map<DateTime, String> temp = {};
          for (var record in data['data']) {
            final dateParts = record['date'].split('-');
            if (dateParts.length == 3) {
              final date = DateTime(
                int.parse(dateParts[0]),
                int.parse(dateParts[1]),
                int.parse(dateParts[2]),
              );
              temp[date] = record['status'];
            }
          }
          setState(() => attendanceData = temp);
          print("✅ Attendance Loaded (${attendanceData.length}) records");
        }
      }
    } catch (e) {
      print("❌ Attendance fetch failed: $e");
    }
  }

  /// 🖼️ Build UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Profile',
          style: TextStyle(
            color: brandBlue,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              backgroundColor: brandBlue,
              child: Text(
                userInitial,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<StudentData>>(
        future: studentsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: brandBlue));
          } else if (snapshot.hasError) {
            return Center(child: Text("❌ Error: ${snapshot.error}"));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No student data available"));
          }

          final studentData = snapshot.data!.first;
          return RefreshIndicator(
            onRefresh: () => _initAndFetch(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  _buildStudentCard(studentData),
                  const SizedBox(height: 20),
                  _buildGatePassCard(studentData),
                  const SizedBox(height: 20),
                  _buildAttendanceCalendar(),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 🧾 Student Info Card
  Widget _buildStudentCard(StudentData studentData) {
    final student = studentData.student;
    final fee = studentData.fee;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Name: ${student['name'] ?? '-'}",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text("Student ID: ${student['id_card'] ?? '-'}",
              style: const TextStyle(color: Colors.grey)),
          const Divider(),
          const Text("Fee Details:", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildFeeDetailRow("Monthly Fee", "₹${fee?['amount'] ?? '0.00'}"),
          _buildFeeDetailRow("Paid Date", fee?['paid_date'] ?? '-'),
          _buildFeeDetailRow("Next Due", fee?['next_due_date'] ?? '-'),
        ],
      ),
    );
  }

  /// 🎫 Gate Pass Card
  Widget _buildGatePassCard(StudentData studentData) {
    final pass = studentData.gatePass;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          const Text("GATE PASS", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (pass != null && pass['qr_code'] != null)
            Image.memory(
              base64Decode(pass['qr_code'].split(',')[1]),
              width: 150,
              height: 150,
            )
          else
            const Text("Gate pass not issued yet",
                style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          if (pass?['valid_until'] != null)
            Text("Valid Until: ${pass!['valid_until']}",
                style: const TextStyle(color: Colors.black54, fontSize: 14)),
        ],
      ),
    );
  }

  /// 📅 Attendance Calendar
  Widget _buildAttendanceCalendar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          const Text("Attendance Calendar",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegend(Colors.green, "Present"),
              const SizedBox(width: 10),
              _buildLegend(Colors.red, "Absent"),
              const SizedBox(width: 10),
              _buildLegend(Colors.amber, "Holiday"),
            ],
          ),
          const SizedBox(height: 12),
          TableCalendar(
            firstDay: DateTime.utc(2024, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: DateTime.now(),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, focusedDay) {
                final status = attendanceData[DateTime(day.year, day.month, day.day)];
                Color? bgColor;
                if (status == "Present") bgColor = Colors.green;
                if (status == "Absent") bgColor = Colors.red;
                if (status == "Holiday") bgColor = Colors.amber;

                return Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    "${day.day}",
                    style: TextStyle(
                      color: bgColor != null ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Legend
  Widget _buildLegend(Color color, String label) {
    return Row(
      children: [
        Container(width: 14, height: 14, color: color),
        const SizedBox(width: 5),
        Text(label),
      ],
    );
  }

  Widget _buildFeeDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value,
              style:
              const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
        ],
      ),
    );
  }
}

class StudentData {
  final Map<String, dynamic> student;
  final Map<String, dynamic>? fee;
  final Map<String, dynamic>?
  gatePass;
  final String? coachName;

  StudentData({required this.student, this.fee, this.gatePass, this.coachName});

  factory StudentData.fromJson(Map<String, dynamic> json) {
    return StudentData(
      student: json['student'] ?? {},
      fee: json['fee'] is Map ? json['fee'] : null,
      gatePass: json['pass'] is Map ? json['pass'] : null,
      coachName: json['coach_name']?.toString(),
    );
  }
}
