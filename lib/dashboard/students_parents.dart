import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';

class StudentsParentsScreen extends StatefulWidget {
  final String studentId;

  const StudentsParentsScreen({super.key, required this.studentId});



  @override
  State<StudentsParentsScreen> createState() => _StudentsParentsScreenState();
}
class _StudentsParentsScreenState extends State<StudentsParentsScreen> {
  late final String studentId;
  late Future<List<StudentData>> studentsFuture;
  String? parentNumber;

  @override
  void initState() {
    super.initState();
    studentId = ApiService.currentUser?['student_id']?.toString() ?? '';
    if (widget.studentId.isEmpty) {
      studentsFuture = Future.error("Student ID is not available");
    } else {
      studentsFuture = fetchStudents(int.parse(widget.studentId));
    }
  }

  Future<List<StudentData>> fetchStudents(int studentId) async {
    final url = Uri.parse(
        "https://nahatasports.com/api/student_dashboard?student_id=$studentId");

    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        if (ApiService.currentUser != null &&
            ApiService.currentUser!.containsKey('token'))
          'Authorization': 'Bearer ${ApiService.currentUser!['token']}',
      },
    );

    print("studentId: $studentId");
    print("Status: ${response.statusCode}");
    print("Body: ${response.body}");

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);

      if (body['status'] == true) {
        final data = body['data'];

        // ✅ extract parent number directly from student data
        setState(() {
          parentNumber = data['student']['parent_contact'];
        });

        return [
          StudentData.fromJson({
            "student": data['student'],
            "fee": data['fee'],
            "gatePass": data['pass'],
            "coachName": data['coach_name'],
          })
        ];
      } else {
        throw Exception("API returned false status");
      }
    } else {
      throw Exception("Failed to fetch data");
    }
  }

  // Clean number for tel:/wa.me links
  String _cleanNumber(String number) {
    return number.replaceAll(RegExp(r'[^0-9]'), '');
  }

  void _callParent() async {
    if (parentNumber == null) {
      debugPrint("❌ parentNumber is NULL, cannot call");
      return;
    }

    String cleanedNumber = _cleanNumber(parentNumber!);

    final Uri callUri = Uri(scheme: 'tel', path: cleanedNumber);
    if (await canLaunchUrl(callUri)) {
      await launchUrl(callUri);
      print("📞 Calling: $callUri");
    } else {
      debugPrint('❌ Could not launch $callUri');
    }
  }

  void _openWhatsApp() async {
    if (parentNumber == null) {
      debugPrint("❌ parentNumber is NULL, cannot open WhatsApp");
      return;
    }

    String cleanedNumber = _cleanNumber(parentNumber!);

    final Uri whatsappUri = Uri.parse('https://wa.me/$cleanedNumber');
    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      print("💬 Opening WhatsApp: $whatsappUri");
    } else {
      debugPrint('❌ Could not launch $whatsappUri');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF0A198D),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              // Navigator.pushReplacement(
              //   context,
              //   MaterialPageRoute(
              //     builder: (_) => LoginScreen(),
              //   ),
              // );
            },
          ),
          title: const Text("Students & Parents"),
          // centerTitle: true,
        ),
        body: FutureBuilder<List<StudentData>>(
          future: studentsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text("Error: ${snapshot.error}"));
            }

            final students = snapshot.data ?? [];

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: students.length,
              itemBuilder: (context, index) {
                final s = students[index];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ✅ Payment Banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.yellow[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.verified, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Payment ${s.fee?.status.toUpperCase()} by ${s.coachName ?? 'N/A'} • NEXT DUE: ${s.fee?.nextDueDate ?? 'N/A'}",
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: s.fee?.status == "paid"
                                  ? Colors.green
                                  : Colors.red,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              s.fee?.status?.toUpperCase() ?? "N/A",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ✅ Student Info
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Name & ID
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Name: ${s.student.name}",
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  "ID: ${s.student.id}",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // ✅ Call Parent & WhatsApp
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  ElevatedButton(
                                    onPressed: parentNumber == null
                                        ? null
                                        : _callParent,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.yellow[700],
                                    ),
                                    child: const Text("CALL PARENT"),
                                  ),
                                  const SizedBox(width: 12),
                                  ElevatedButton.icon(
                                    onPressed: parentNumber == null
                                        ? null
                                        : _openWhatsApp,
                                    icon: const Icon(
                                      Icons.chat,
                                      color: Colors.white,
                                    ),
                                    label: const Text("WHATSAPP"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Fee Details
                            const Text(
                              "FEE DETAILS:",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 12,
                              runSpacing: 4,
                              children: [
                                Text(
                                  "MONTHLY FEE: ₹${s.fee?.amount ?? "N/A"}",
                                  style: const TextStyle(color: Colors.green),
                                ),
                                Text("LAST PAYMENT: ${s.fee?.paidDate ?? "N/A"}"),
                                Text("NEXT DUE: ${s.fee?.nextDueDate ?? "N/A"}"),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // ✅ Gate Pass
                    Card(
                      color: Colors.indigo[50],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                      child: Center(
                        child: Column(
                          children: [
                            const Text(
                              "GATE PASS",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (s.gatePass != null)
                              Image.memory(
                                base64Decode(
                                    s.gatePass!.qrCode.split(",").last),
                                height: 120,
                                width: 120,
                              )
                            else
                              const Icon(
                                Icons.qr_code,
                                size: 80,
                                color: Colors.grey,
                              ),
                            const SizedBox(height: 4),
                            Text(
                              s.gatePass != null
                                  ? "Valid until: ${s.gatePass!.validUntil}"
                                  : "Gate pass not issued yet.",
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// class _StudentsParentsScreenState extends State<StudentsParentsScreen> {
//   late final String studentId;
//   late Future<List<StudentData>> studentsFuture;
//   String? parentNumber;
//   bool isLoading = true;
//   @override
//   void initState() {
//     super.initState();
//     fetchParentContact();
//     studentId = ApiService.currentUser?['student_id']?.toString() ?? '';
//     if (widget.studentId.isEmpty) {
//       // Handle null/empty ID safely
//       studentsFuture = Future.error("Student ID is not available");
//     } else {
//       studentsFuture = fetchStudents(int.parse(widget.studentId));
//     }
//
//   }
//   Future<void> fetchParentContact() async {
//     try {
//       final response = await http.get(
//         Uri.parse('https://yourapi.com/student/${widget.studentId}'),
//       );
//
//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         setState(() {
//           parentNumber = data['parent_contact'];
//           isLoading = false;
//         });
//       } else {
//         throw Exception('Failed to fetch parent contact');
//       }
//     } catch (e) {
//       setState(() {
//         isLoading = false;
//       });
//       debugPrint('Error fetching parent contact: $e');
//     }
//   }
//   Future<List<StudentData>> fetchStudents(int studentId) async {
//     final url = Uri.parse("https://nahatasports.com/api/student_dashboard?student_id=$studentId");
//
//     final response = await http.get(
//       url,
//       headers: {
//         'Content-Type': 'application/json',
//         if (ApiService.currentUser != null &&
//             ApiService.currentUser!.containsKey('token'))
//           'Authorization': 'Bearer ${ApiService.currentUser!['token']}',
//       },
//     );
//   print("studentId: $studentId");
//     print("Status: ${response.statusCode}");
//     print("Body: ${response.body}");
//
//     if (response.statusCode == 200) {
//       final body = jsonDecode(response.body);
//
//       if (body['status'] == true) {
//         final data = body['data'];
//
//         return [
//           StudentData.fromJson({
//             "student": data['student'],
//             "fee": data['fee'],
//             "gatePass": data['pass'],
//             "coachName": data['coach_name'],
//           })
//         ];
//       } else {
//         throw Exception("API returned false status");
//       }
//     } else {
//       throw Exception("Failed to fetch data");
//     }
//   }
//
//
//
//
//
// // Helper function to clean number (remove +, spaces, dashes, brackets, etc.)
//   String _cleanNumber(String number) {
//     return number.replaceAll(RegExp(r'[^0-9]'), '');
//   }
//
//   void _callParent() async {
//     if (parentNumber == null) return;
//
//     String cleanedNumber = _cleanNumber(parentNumber!);
//
//     final Uri callUri = Uri(scheme: 'tel', path: cleanedNumber);
//     if (await canLaunchUrl(callUri)) {
//       await launchUrl(callUri);
//       print("callUri: $callUri");
//     }
//
//     else {
//       debugPrint('Could not launch $callUri');
//     }
//
//   }
//
//   void _openWhatsApp() async {
//     if (parentNumber == null) return;
//
//     String cleanedNumber = _cleanNumber(parentNumber!);
//
//     final Uri whatsappUri = Uri.parse('https://wa.me/$cleanedNumber');
//
//     if (await canLaunchUrl(whatsappUri)) {
//       await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
//     } else {
//       debugPrint('Could not launch $whatsappUri');
//     }
//   }
//
//
//   // Future<List<StudentData>> fetchStudents() async {
//   //   final url = Uri.parse("https://nahatasports.com/admin/feesmodule/api");
//   //
//   //   final response = await http.get(
//   //     url,
//   //     headers: {
//   //       // 'Content-Type': 'application/json',
//   //       // // You can pass token if API requires:
//   //       // if (ApiService.currentUser != null && ApiService.currentUser!.containsKey('token'))
//   //       //   'Authorization': 'Bearer ${ApiService.currentUser!['token']}',
//   //       'Content-Type': 'application/json',
//   //       'Authorization': 'Bearer ${ApiService.currentUser!['token']}',
//   //     },
//   //   );
//   //
//   //   print("Status: ${response.statusCode}");
//   //   print("Body: ${response.body}");
//   //
//   //   if (response.statusCode == 200) {
//   //     final body = jsonDecode(response.body);
//   //
//   //     if (body['status'] == true) {
//   //       final List data = body['data'];
//   //       return data.map((e) => StudentData.fromJson(e)).toList();
//   //     } else {
//   //       throw Exception("API returned false status");
//   //     }
//   //   } else {
//   //     throw Exception("Failed to fetch data");
//   //   }
//   // }
//
//   @override
//   Widget build(BuildContext context) {
//     return SafeArea(
//       child: Scaffold(
//         appBar: AppBar(
//           title: const Text("Students & Parents"),
//           centerTitle: true,
//         ),
//         body: FutureBuilder<List<StudentData>>(
//           // future: fetchStudents(int.parse(studentId.currentUser!['id'])),
//           // future: fetchStudents(int.parse(widget.studentId)),
//           future: studentsFuture,
//           builder: (context, snapshot) {
//             if (snapshot.connectionState == ConnectionState.waiting) {
//               return const Center(child: CircularProgressIndicator());
//             }
//             if (snapshot.hasError) {
//               return Center(child: Text("Error: ${snapshot.error}"));
//             }
//
//             final students = snapshot.data ?? [];
//
//             return ListView.builder(
//               padding: const EdgeInsets.all(16),
//               itemCount: students.length,
//               itemBuilder: (context, index) {
//                 final s = students[index];
//
//                 return Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     // ✅ Payment Banner (from API)
//                     Container(
//                       width: double.infinity,
//                       padding: const EdgeInsets.all(12),
//                       decoration: BoxDecoration(
//                         color: Colors.yellow[100],
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                       child: Row(
//                         children: [
//                           const Icon(Icons.verified, color: Colors.green),
//                           const SizedBox(width: 8),
//                           Expanded(
//                             child: Text(
//                               "Payment ${s.fee?.status.toUpperCase()} by ${s.coachName ?? 'N/A'} • NEXT DUE: ${s.fee?.nextDueDate ?? 'N/A'}",
//                               style: const TextStyle(fontWeight: FontWeight.w600),
//                             ),
//                           ),
//                           Container(
//                             padding: const EdgeInsets.symmetric(
//                               horizontal: 8,
//                               vertical: 4,
//                             ),
//                             decoration: BoxDecoration(
//                               color: s.fee?.status == "paid"
//                                   ? Colors.green
//                                   : Colors.red,
//                               borderRadius: BorderRadius.circular(4),
//                             ),
//                             child: Text(
//                               s.fee?.status?.toUpperCase() ?? "N/A",
//                               style: const TextStyle(
//                                 color: Colors.white,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//
//                     const SizedBox(height: 16),
//
//                     // ✅ Student Info (from API)
//                     Card(
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                       elevation: 4,
//                       child: Padding(
//                         padding: const EdgeInsets.all(16),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             // Name & ID
//                             Row(
//                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                               children: [
//                                 Text(
//                                   "Name: ${s.student.name}",
//                                   style: const TextStyle(
//                                     fontSize: 18,
//                                     fontWeight: FontWeight.bold,
//                                   ),
//                                 ),
//                                 Text(
//                                   "ID: ${s.student.id}",
//                                   style: const TextStyle(
//                                     fontSize: 16,
//                                     color: Colors.grey,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                             const SizedBox(height: 12),
//
//                             // Call Parent & WhatsApp
//                             SingleChildScrollView(
//                               scrollDirection: Axis.horizontal,
//                               child: Row(
//                                 children: [
//                                   ElevatedButton(
//                                     onPressed:_callParent,
//                                     style: ElevatedButton.styleFrom(
//                                       backgroundColor: Colors.yellow[700],
//                                     ),
//                                     child: const Text("CALL PARENT"),
//                                   ),
//                                   const SizedBox(width: 12),
//                                   ElevatedButton.icon(
//                                     onPressed: _openWhatsApp,
//                                     icon: const Icon(
//                                       Icons.chat,
//                                       color: Colors.white,
//                                     ),
//                                     label: const Text("WHATSAPP"),
//                                     style: ElevatedButton.styleFrom(
//                                       backgroundColor: Colors.green,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                             const SizedBox(height: 16),
//
//                             // Fee Details
//                             const Text(
//                               "FEE DETAILS:",
//                               style: TextStyle(
//                                 fontSize: 16,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                             const SizedBox(height: 8),
//                             Wrap(
//                               spacing: 12,
//                               runSpacing: 4,
//                               children: [
//                                 Text(
//                                   "MONTHLY FEE: ₹${s.fee?.amount?? "N/A"}",
//                                   style: const TextStyle(color: Colors.green),
//                                 ),
//                                 Text("LAST PAYMENT: ${s.fee?.paidDate ?? "N/A"}"),
//                                 Text("NEXT DUE: ${s.fee?.nextDueDate?? "N/A"}"),
//                               ],
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//
//                     const SizedBox(height: 10),
//
//                     // ✅ Gate Pass (from API)
//                     Card(
//                       color: Colors.indigo[50],
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                       elevation: 4,
//                       child: Center(
//                         child: Column(
//                           children: [
//                             const Text(
//                               "GATE PASS",
//                               style: TextStyle(
//                                 fontSize: 16,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                             const SizedBox(height: 8),
//                             if (s.gatePass != null)
//                               Image.memory(
//                                 base64Decode(s.gatePass!.qrCode.split(",").last),
//                                 height: 120,
//                                 width: 120,
//                               )
//                             else
//                               const Icon(
//                                 Icons.qr_code,
//                                 size: 80,
//                                 color: Colors.grey,
//                               ),
//                             const SizedBox(height: 4),
//                             Text(
//                               s.gatePass != null
//                                   ? "Valid until: ${s.gatePass!.validUntil}"
//                                   : "Gate pass not issued yet.",
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//
//                     const SizedBox(height: 20),
//                   ],
//                 );
//               },
//             );
//           },
//         ),
//       ),
//     );
//   }
// }

class StudentData {
  final Student student;
  final Fee? fee;
  final String? coachName;
  final GatePass? gatePass;

  StudentData({
    required this.student,
    required this.fee,
    required this.coachName,
    this.gatePass,
  });

  factory StudentData.fromJson(Map<String, dynamic> json) {
    return StudentData(
      student: Student.fromJson(json['student']),
      fee: json['fee'] != null ? Fee.fromJson(json['fee']) : null,
      coachName: json['coach_name'], // match API key
      gatePass: json['pass'] != null ? GatePass.fromJson(json['pass']) : null,
      // student: Student.fromJson(json['student']),
      // fee: Fee.fromJson(json['fee']),
      // coachName: json['coachName'],
      // gatePass: json['gatePass'] != null
      //     ? GatePass.fromJson(json['gatePass'])
      //     : null,
    );
  }
}


















class Student {
  final String id;
  final String name;
  final String phone;
  final String email;

  Student({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'],
      name: json['name'],
      phone: json['phone'],
      email: json['email'],
    );
  }
}

class Fee {
  final String amount;
  final String status;
  final String? paidDate;
  final String nextDueDate;

  Fee({
    required this.amount,
    required this.status,
    this.paidDate,
    required this.nextDueDate,
  });

  factory Fee.fromJson(Map<String, dynamic> json) {
    return Fee(
      amount: json['amount'],
      status: json['status'],
      paidDate: json['paid_date'],
      nextDueDate: json['next_due_date'],
    );
  }
}

class GatePass {
  final String qrCode;
  final String validUntil;
  final String status;

  GatePass({
    required this.qrCode,
    required this.validUntil,
    required this.status,
  });

  factory GatePass.fromJson(Map<String, dynamic> json) {
    return GatePass(
      qrCode: json['qr_code'],
      validUntil: json['valid_until'],
      status: json['status'],
    );
  }
}







// sachink@gmail.com
//1234@1234