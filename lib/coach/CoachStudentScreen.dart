import 'dart:convert';
import '../core/utils/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:nahata_app/core/network/http_logged.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:nahata_app/core/network/http_logged.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  bool isLoading = true;
  List<dynamic> students = [];
  int? studentId;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadStudentId();
    if (studentId != null) {
      await fetchStudents();
    } else {
      AppLogger.debug("⚠️ No studentId found, skipping fetchStudents()", name: 'CoachStudentScreen');
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadStudentId() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user');

    if (userJson != null) {
      final userData = jsonDecode(userJson);
      final rawId = userData['student_id'] ?? userData['id'];
      final parsedId = (rawId is String) ? int.tryParse(rawId) : rawId as int?;
      setState(() {
        studentId = parsedId;
      });
      AppLogger.debug('🎓 Student ID: $studentId', name: 'CoachStudentScreen');
    } else {
      AppLogger.debug('⚠️ No user data found in SharedPreferences', name: 'CoachStudentScreen');
    }
  }

  Future<void> fetchStudents() async {
    if (studentId == null) {
      AppLogger.debug("⚠️ Cannot fetch students — studentId is null", name: 'CoachStudentScreen');
      return;
    }

    final url = Uri.parse('https://nahatasports.com/api/students?coach_id=$studentId');
    AppLogger.debug("🌐 Fetching students from: $url", name: 'CoachStudentScreen');

    try {
      final response = await http.get(url);
      AppLogger.debug("📩 Response: ${response.statusCode}", name: 'CoachStudentScreen');
      AppLogger.debug("📩 Body: ${response.body}", name: 'CoachStudentScreen');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true && data['data'] != null) {
          setState(() {
            students = data['data'];
            isLoading = false;
          });
          AppLogger.debug("✅ Students loaded: ${students.length}", name: 'CoachStudentScreen');
        } else {
          AppLogger.debug("⚠️ API returned no data", name: 'CoachStudentScreen');
          setState(() => isLoading = false);
        }
      } else {
        AppLogger.debug("❌ Server Error: ${response.statusCode}", name: 'CoachStudentScreen');
        setState(() => isLoading = false);
      }
    } catch (e) {
      AppLogger.debug("❌ Exception fetching students: $e", name: 'CoachStudentScreen');
      setState(() => isLoading = false);
    }
  }

  void _openFeedbackPage(Map<String, dynamic> student) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FeedbackPage(
          studentId: student['id'].toString(),
          studentName: student['name'] ?? 'Student',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A198D),
        title: const Text(
          'Students',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color(0xFFF7F9FC),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : students.isEmpty
          ? const Center(
        child: Text(
          'No students found',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: students.length,
        itemBuilder: (context, index) {
          final student = students[index];

          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 25,
                        backgroundColor:
                        Colors.blueAccent.withOpacity(0.2),
                        child: const Icon(
                          Icons.person,
                          color: Colors.blueAccent,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              student['name'] ?? 'N/A',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              student['email'] ?? '',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              student['phone'] ?? '',
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          AppLogger.debug("👀 View pressed for ${student['name']}", name: 'CoachStudentScreen');
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ViewStudentScreen(
                                studentId: student['id'].toString(),
                              ),
                            ),
                          );

                        },
                        icon: const Icon(Icons.visibility, size: 18),
                        label: const Text('View'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0A198D),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: () => _openFeedbackPage(student),
                        icon: const Icon(Icons.feedback_outlined,
                            size: 18),
                        label: const Text('Feedback'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0A198D),
                          side: const BorderSide(
                              color: Color(0xFF0A198D)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class FeedbackPage extends StatefulWidget {
  final String studentId;
  final String studentName;

  const FeedbackPage({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final TextEditingController feedbackController = TextEditingController();
  bool isSubmitting = false;
  int? coachId;

  @override
  void initState() {
    super.initState();
    _loadCoachId();
  }

  Future<void> _loadCoachId() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user');

    if (userJson != null) {
      final userData = jsonDecode(userJson);
      final rawId = userData['student_id'] ?? userData['id'];
      setState(() {
        coachId = (rawId is String) ? int.tryParse(rawId) : rawId as int?;
      });
      AppLogger.debug("🧑‍🏫 Coach ID: $coachId", name: 'CoachStudentScreen');
    } else {
      AppLogger.debug("⚠️ No user data found in prefs", name: 'CoachStudentScreen');
    }
  }

  Future<void> _submitFeedback() async {
    final feedback = feedbackController.text.trim();
    if (feedback.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter feedback")),
      );
      return;
    }

    if (coachId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Coach ID not found")),
      );
      return;
    }

    setState(() => isSubmitting = true);

    final url = Uri.parse('https://nahatasports.com/api/feedback/${widget.studentId}');
    AppLogger.debug("📤 Sending feedback to: $url", name: 'CoachStudentScreen');

    final body = {
      "user_id": coachId.toString(),
      "feedback": feedback,
    };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      AppLogger.debug("📩 Response: ${response.statusCode} => ${response.body}", name: 'CoachStudentScreen');

      final data = jsonDecode(response.body);
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          data['status'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Feedback submitted successfully")),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Failed: ${data['message'] ?? 'Error'}")),
        );
      }

    } catch (e) {
      AppLogger.debug("❌ Exception submitting feedback: $e", name: 'CoachStudentScreen');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Something went wrong")),
      );
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Feedback - ${widget.studentName}",style: TextStyle(color: Colors.white),),
        backgroundColor: const Color(0xFF0A198D),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: feedbackController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: "Enter your feedback",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: isSubmitting ? null : _submitFeedback,
              icon: const Icon(Icons.send),
              label: Text(isSubmitting ? "Submitting..." : "Submit"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A198D),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class ViewStudentScreen extends StatefulWidget {
  final String studentId;

  const ViewStudentScreen({super.key, required this.studentId});

  @override
  State<ViewStudentScreen> createState() => _ViewStudentScreenState();
}

class _ViewStudentScreenState extends State<ViewStudentScreen> {
  bool isLoading = true;

  List<dynamic> studentEnrollments = []; // FIXED ✔

  @override
  void initState() {
    super.initState();
    fetchStudentDetails();
  }

  // 🔹 Fetch Enrollments
  Future<void> fetchStudentDetails() async {
    final url = Uri.parse(
        "https://nahatasports.com/api/my-enrollments?user_id=${widget.studentId}");
    AppLogger.debug("📤 GET: $url", name: 'CoachStudentScreen');

    try {
      final response = await http.get(url);
      AppLogger.debug("📩 Response: ${response.statusCode}", name: 'CoachStudentScreen');
      AppLogger.debug("📩 Body: ${response.body}", name: 'CoachStudentScreen');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data["status"] == true) {
          setState(() {
            studentEnrollments = data["data"]; // <-- LIST ✔
            isLoading = false;
          });
        } else {
          setState(() => isLoading = false);
        }
      }
    } catch (e) {
      AppLogger.debug("❌ Error: $e", name: 'CoachStudentScreen');
      setState(() => isLoading = false);
    }
  }

  // 🔹 Update Enrollment Status API
  Future<void> updateStatus(String enrollId, String status) async {
    final url =
    Uri.parse("https://nahatasports.com/api/enrollment/status/$enrollId");

    AppLogger.debug("📤 POST: $url", name: 'CoachStudentScreen');

    try {
      final response = await http.post(
        url,
        body: {"status": status},
      );

      AppLogger.debug("📩 Response: ${response.statusCode}", name: 'CoachStudentScreen');
      AppLogger.debug("📩 Body: ${response.body}", name: 'CoachStudentScreen');

      final data = jsonDecode(response.body);

      if (data["status"] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Status Updated to $status")),
        );
        fetchStudentDetails();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed: ${data['message']}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error updating status")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
        const Text("Student Details", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0A198D),
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      // ================= UI =================
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : studentEnrollments.isEmpty
          ? const Center(child: Text("No enrollments found"))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: studentEnrollments.length,
        itemBuilder: (context, index) {
          final enroll = studentEnrollments[index];

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Coach: ${enroll['coach_name']}",
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  Text("Sport: ${enroll['sport_name']}"),
                  Text("Price: ₹${enroll['price']}"),
                  Text("Enrollment Date: ${enroll['created_at']}"),
                  const SizedBox(height: 10),

                  // 🔹 Status Tag
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: enroll['status'] == 'approved'
                          ? Colors.green.withOpacity(0.2)
                          : enroll['status'] == 'pending'
                          ? Colors.orange.withOpacity(0.2)
                          : Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "Status: ${enroll['status']}",
                      style: TextStyle(
                        color: enroll['status'] == 'approved'
                            ? Colors.green
                            : enroll['status'] == 'pending'
                            ? Colors.orange
                            : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 🔹 Action Buttons
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: () => updateStatus(
                            enroll['id'], "approved"),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green),
                        child: const Text("Approve"),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () => updateStatus(
                            enroll['id'], "disapproved"),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red),
                        child: const Text("Disapprove"),
                      ),
                    ],
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}


// class ViewStudentScreen extends StatefulWidget {
//   final String studentId;
//
//   const ViewStudentScreen({super.key, required this.studentId});
//
//   @override
//   State<ViewStudentScreen> createState() => _ViewStudentScreenState();
// }
//
// class _ViewStudentScreenState extends State<ViewStudentScreen> {
//   bool isLoading = true;
//   Map<String, dynamic>? student;
//
//   @override
//   void initState() {
//     super.initState();
//     fetchStudentDetails();
//   }
//
//   Future<void> fetchStudentDetails() async {
//     final url = Uri.parse("https://nahatasports.com/api/feedback/${widget.studentId}");
//     print("📤 GET: $url");
//
//     try {
//       final response = await http.get(url);
//       print("📩 Response: ${response.statusCode}");
//       print("📩 Body: ${response.body}");
//
//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//
//         if (data["status"] == true) {
//           setState(() {
//             student = data["data"];
//             isLoading = false;
//           });
//         }
//       }
//     } catch (e) {
//       print("❌ Error: $e");
//       setState(() => isLoading = false);
//     }
//   }
//
//   Future<void> updateStatus(String status) async {
//     final enrollId = widget.studentId; // using studentId as per API example
//     final url = Uri.parse("https://nahatasports.com/api/enrollment/status/$enrollId");
//
//     print("📤 POST: $url");
//
//     try {
//       final response = await http.post(
//         url,
//         body: {"status": status},
//       );
//
//       print("📩 Response: ${response.statusCode}");
//       print("📩 Body: ${response.body}");
//
//       final data = jsonDecode(response.body);
//
//       if (data["status"] == true) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text("Status Updated to $status")),
//         );
//
//         fetchStudentDetails(); // refresh data
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text("Failed: ${data['message']}")),
//         );
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("Error updating status")),
//       );
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("Student Details", style: TextStyle(color: Colors.white)),
//         backgroundColor: const Color(0xFF0A198D),
//         iconTheme: const IconThemeData(color: Colors.white),
//       ),
//       body: isLoading
//           ? const Center(child: CircularProgressIndicator())
//           : student == null
//           ? const Center(child: Text("No details found"))
//           : Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text("Name: ${student!['name']}", style: const TextStyle(fontSize: 18)),
//             Text("Phone: ${student!['phone']}"),
//             Text("Coach ID: ${student!['coach_id']}"),
//             Text("Coach Name: ${student!['coach_name']}"),
//             Text("Sport: Football"),     // Replace with actual field
//             Text("Price: 1200"),        // Replace with actual field
//             Text("Enrollment Date: 2025-11-02"), // Replace with field
//             const SizedBox(height: 20),
//
//             Text("Status: Pending", style: TextStyle(fontSize: 16)),
//
//             const SizedBox(height: 20),
//
//             Row(
//               children: [
//                 ElevatedButton(
//                   onPressed: () => updateStatus("approved"),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.green,
//                   ),
//                   child: const Text("Approve"),
//                 ),
//                 const SizedBox(width: 12),
//                 ElevatedButton(
//                   onPressed: () => updateStatus("disapproved"),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.red,
//                   ),
//                   child: const Text("Disapprove"),
//                 ),
//               ],
//             )
//           ],
//         ),
//       ),
//     );
//   }
// }
