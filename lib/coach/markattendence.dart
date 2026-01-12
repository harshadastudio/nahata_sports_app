// import 'dart:convert';
//
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
//
// class Attendance {
//   final String date;
//   final String status;
//   final String time;
//   final String coachId;
//
//   Attendance({
//     required this.date,
//     required this.status,
//     required this.time,
//     required this.coachId,
//   });
//
//   factory Attendance.fromJson(Map<String, dynamic> json) {
//     return Attendance(
//       date: json['date'] ?? '',
//       status: json['status'] ?? '',
//       time: json['time'] ?? '',
//       coachId: json['coach_id'] ?? '',
//     );
//   }
// }
// class AttendanceScreen extends StatefulWidget {
//
//   const AttendanceScreen({super.key, });
//
//   @override
//   State<AttendanceScreen> createState() => _AttendanceScreenState();
// }
//
// class _AttendanceScreenState extends State<AttendanceScreen> {
//   late Future<List<Attendance>> _attendanceFuture;
//
//   @override
//   void initState() {
//     super.initState();
//   }
//
//   Color getStatusColor(String status) {
//     switch (status.toLowerCase()) {
//       case 'present':
//         return Colors.green;
//       case 'absent':
//         return Colors.red;
//       case 'holiday':
//         return Colors.orange;
//       default:
//         return Colors.grey;
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Mark Attendance')),
//       body: FutureBuilder<List<Attendance>>(
//         future: _attendanceFuture,
//         builder: (context, snapshot) {
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return const Center(child: CircularProgressIndicator());
//           } else if (snapshot.hasError) {
//             return Center(child: Text('Error: ${snapshot.error}'));
//           } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
//             return const Center(child: Text('No attendance records found'));
//           }
//
//           final attendanceList = snapshot.data!;
//
//           return ListView(
//             padding: const EdgeInsets.all(16),
//             children: [
//               const Text(
//                 'Date: mm/dd/yyyy',
//                 style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
//               ),
//               const SizedBox(height: 10),
//               Table(
//                 border: TableBorder.all(color: Colors.grey),
//                 columnWidths: const {
//                   0: FixedColumnWidth(30),
//                   1: FlexColumnWidth(),
//                   2: FixedColumnWidth(100),
//                 },
//                 children: [
//                   const TableRow(
//                     decoration: BoxDecoration(color: Colors.grey),
//                     children: [
//                       Padding(
//                         padding: EdgeInsets.all(8.0),
//                         child: Text('#', style: TextStyle(fontWeight: FontWeight.bold)),
//                       ),
//                       Padding(
//                         padding: EdgeInsets.all(8.0),
//                         child: Text('Student Name', style: TextStyle(fontWeight: FontWeight.bold)),
//                       ),
//                       Padding(
//                         padding: EdgeInsets.all(8.0),
//                         child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold)),
//                       ),
//                     ],
//                   ),
//                   for (int i = 0; i < attendanceList.length; i++)
//                     TableRow(
//                       children: [
//                         Padding(
//                           padding: const EdgeInsets.all(8.0),
//                           child: Text('${i + 1}'),
//                         ),
//                         Padding(
//                           padding: const EdgeInsets.all(8.0),
//                           child: Text('Student ${i + 1}'),
//                         ),
//                         Padding(
//                           padding: const EdgeInsets.all(8.0),
//                           child: Row(
//                             children: [
//                               Icon(Icons.circle, color: getStatusColor(attendanceList[i].status), size: 14),
//                               const SizedBox(width: 5),
//                               Text(attendanceList[i].status),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ),
//                 ],
//               ),
//             ],
//           );
//         },
//       ),
//     );
//   }
// }
//
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  DateTime selectedDate = DateTime.now();
  bool isLoading = true;
  List<Map<String, dynamic>> students = [];
  Map<int, String> attendanceStatus = {};
  int? studentId;

  @override
  void initState() {
    super.initState();
    // _loadCoachIdAndFetchStudents();
    _loadStudentId();
  }

  Future<void> _loadStudentId() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user');

    if (userJson != null) {
      final userData = jsonDecode(userJson);

      setState(() {
        final rawId = userData['student_id'] ?? userData['id'];
        studentId = rawId is int ? rawId : int.tryParse(rawId.toString());
      });

      print('🎓 Student ID: $studentId');
      // ✅ Now safe to fetch students
      await fetchStudents();
    } else {
      print('⚠️ No user data found in SharedPreferences');
    }
  }

  Future<void> fetchStudents() async {
    // setState(() => isLoading = true);

    final url = Uri.parse(
        'https://nahatasports.com/api/attendance/students?coach_id=$studentId');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true && data['data'] != null) {
          final List<dynamic> fetched = data['data'];
          setState(() {
            students = List<Map<String, dynamic>>.from(fetched);
            for (var s in students) {
              attendanceStatus[int.parse(s['id'])] = 'Absent';
            }
          });
          print('✅ Students fetched: ${students.length}');
        } else {
          print("⚠️ API returned empty data: ${data['message']}");
        }
      } else {
        print("❌ Server error: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Failed to fetch students: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  // Pick date
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime(2030, 12, 31),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('dd MMM yyyy').format(selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance',style: TextStyle(color: Colors.white),),
        // centerTitle: true,
        backgroundColor: const Color(0xFF0A198D),
        iconTheme: const IconThemeData(color: Colors.white), // ✅ White back arrow

      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : students.isEmpty
          ? const Center(
        child: Text(
          'No students found',
          style: TextStyle(fontSize: 16),
        ),
      )
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Date Selector
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blueAccent),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      formattedDate,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Icon(Icons.calendar_today,
                        color: Colors.blueAccent),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Student List
            Expanded(
              child: ListView.builder(
                itemCount: students.length,
                itemBuilder: (context, index) {
                  final student = students[index];
                  final studentId = int.parse(student['id']);
                  final status =
                      attendanceStatus[studentId] ?? 'Absent';

                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 3,
                    margin:
                    const EdgeInsets.symmetric(vertical: 8.0),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                      child:

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            flex: 2,
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: Colors.blue.shade100,
                                  backgroundImage: student['student_photo'] != null
                                      ? NetworkImage("https://nahatasports.com/storage/${student['student_photo']}")
                                      : null,
                                  child: student['student_photo'] == null
                                      ? const Icon(Icons.person, color: Colors.grey)
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(student['name'] ?? 'Unknown',
                                          style: const TextStyle(
                                              fontSize: 16, fontWeight: FontWeight.w600),
                                          overflow: TextOverflow.ellipsis),
                                      Text(student['email'] ?? '',
                                          style: TextStyle(
                                              fontSize: 13, color: Colors.grey.shade600),
                                          overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            flex: 3,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _statusButton(studentId, 'Present', Colors.green),
                                  const SizedBox(width: 8),
                                  _statusButton(studentId, 'Absent', Colors.red),
                                  const SizedBox(width: 8),
                                  _statusButton(studentId, 'Holiday', Colors.orange),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                    ),
                  );
                },
              ),
            ),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  print('📤 Attendance Submitted: $attendanceStatus');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Attendance submitted!')),
                  );
                },
                icon: const Icon(Icons.save,color: Colors.white,),
                label: const Text('Save Attendance',style: TextStyle(color: Colors.white),),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A198D),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusButton(int studentId, String status, Color color) {
    final isSelected = attendanceStatus[studentId] == status;

    return GestureDetector(
      onTap: () {
        setState(() {
          attendanceStatus[studentId] = status;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          status[0],
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

// class AttendanceScreen extends StatefulWidget {
//   final List<Map<String, dynamic>> students; // Pass list of students here
//   const AttendanceScreen({super.key, required this.students});
//
//   @override
//   State<AttendanceScreen> createState() => _AttendanceScreenState();
// }
//
// class _AttendanceScreenState extends State<AttendanceScreen> {
//   DateTime selectedDate = DateTime.now();
//
//   // Store attendance status for each student
//   Map<int, String> attendanceStatus = {};
//
//   @override
//   void initState() {
//     super.initState();
//     // Initialize all students as Absent by default
//     for (var student in widget.students) {
//       attendanceStatus[int.parse(student['id'])] = 'Absent';
//     }
//   }
//
//   // Date picker
//   Future<void> _pickDate() async {
//     final picked = await showDatePicker(
//       context: context,
//       initialDate: selectedDate,
//       firstDate: DateTime(2024, 1, 1),
//       lastDate: DateTime(2030, 12, 31),
//     );
//     if (picked != null && picked != selectedDate) {
//       setState(() {
//         selectedDate = picked;
//       });
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final formattedDate = DateFormat('dd MMM yyyy').format(selectedDate);
//
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Attendance'),
//         centerTitle: true,
//         backgroundColor: Colors.blueAccent,
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           children: [
//             // Date selector
//             GestureDetector(
//               onTap: _pickDate,
//               child: Container(
//                 padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
//                 decoration: BoxDecoration(
//                   color: Colors.blue.shade50,
//                   borderRadius: BorderRadius.circular(12),
//                   border: Border.all(color: Colors.blueAccent),
//                 ),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Text(
//                       formattedDate,
//                       style: const TextStyle(
//                         fontSize: 16,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                     const Icon(Icons.calendar_today, color: Colors.blueAccent),
//                   ],
//                 ),
//               ),
//             ),
//             const SizedBox(height: 16),
//
//             // Student list
//             Expanded(
//               child: ListView.builder(
//                 itemCount: widget.students.length,
//                 itemBuilder: (context, index) {
//                   final student = widget.students[index];
//                   final studentId = int.parse(student['id']);
//                   final status = attendanceStatus[studentId] ?? 'Absent';
//
//                   return Card(
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(16),
//                     ),
//                     elevation: 3,
//                     margin: const EdgeInsets.symmetric(vertical: 8),
//                     child: Padding(
//                       padding: const EdgeInsets.symmetric(
//                           vertical: 12, horizontal: 16),
//                       child: Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           // Student Info
//                           Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text(
//                                 student['name'] ?? 'Unknown',
//                                 style: const TextStyle(
//                                   fontSize: 16,
//                                   fontWeight: FontWeight.w600,
//                                 ),
//                               ),
//                               Text(
//                                 student['email'] ?? '',
//                                 style: TextStyle(
//                                   fontSize: 13,
//                                   color: Colors.grey.shade600,
//                                 ),
//                               ),
//                             ],
//                           ),
//
//                           // Status buttons
//                           Row(
//                             children: [
//                               _statusButton(studentId, 'Present', Colors.green),
//                               const SizedBox(width: 8),
//                               _statusButton(studentId, 'Absent', Colors.red),
//                               const SizedBox(width: 8),
//                               _statusButton(studentId, 'Holiday', Colors.orange),
//                             ],
//                           ),
//                         ],
//                       ),
//                     ),
//                   );
//                 },
//               ),
//             ),
//
//             // Save Button
//             SizedBox(
//               width: double.infinity,
//               child: ElevatedButton.icon(
//                 onPressed: () {
//                   print('📤 Attendance Submitted: $attendanceStatus');
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     const SnackBar(content: Text('Attendance submitted!')),
//                   );
//                 },
//                 icon: const Icon(Icons.save),
//                 label: const Text('Save Attendance'),
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.blueAccent,
//                   padding: const EdgeInsets.symmetric(vertical: 14),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   // Custom status button widget
//   Widget _statusButton(int studentId, String status, Color color) {
//     final isSelected = attendanceStatus[studentId] == status;
//
//     return GestureDetector(
//       onTap: () {
//         setState(() {
//           attendanceStatus[studentId] = status;
//         });
//       },
//       child: Container(
//         padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
//         decoration: BoxDecoration(
//           color: isSelected ? color : Colors.grey.shade200,
//           borderRadius: BorderRadius.circular(8),
//         ),
//         child: Text(
//           status[0], // Show only first letter (P / A / H)
//           style: TextStyle(
//             color: isSelected ? Colors.white : Colors.black87,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//       ),
//     );
//   }
// }
