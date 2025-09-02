
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../screens/login_screen.dart';

// class CoachDashboardScreen extends StatefulWidget {
//   const CoachDashboardScreen({Key? key}) : super(key: key);
//
//   @override
//   State<CoachDashboardScreen> createState() => _CoachDashboardScreenState();
// }
//
// class _CoachDashboardScreenState extends State<CoachDashboardScreen> {
//   List<Map<String, dynamic>> students = []; // final merged list
//   bool isLoading = true;
//
//   String selectedFilter = "All"; // All, Paid, Unpaid
//   String searchQuery = "";
//
//   @override
//   void initState() {
//     super.initState();
//     fetchStudents();
//   }
//
//   // Future<void> fetchStudents() async {
//   //   setState(() => isLoading = true);
//   //
//   //   try {
//   //     // Fetch unpaid
//   //     final unpaidRes =
//   //     await http.get(Uri.parse("https://nahatasports.com/markfees/unpaid/14"));
//   //     print("Unpaid Response Status: ${unpaidRes.statusCode}");
//   //     print("Unpaid Response Body: ${unpaidRes.body}");
//   //
//   //     // Fetch paid
//   //     final paidRes =
//   //     await http.get(Uri.parse("https://nahatasports.com/markfees/paid/5"));
//   //     print("Paid Response Status: ${paidRes.statusCode}");
//   //     print("Paid Response Body: ${paidRes.body}");
//   //
//   //     if (unpaidRes.statusCode == 200 && paidRes.statusCode == 200) {
//   //       final unpaidData = jsonDecode(unpaidRes.body) as List;
//   //       final paidData = jsonDecode(paidRes.body) as List;
//   //
//   //       final unpaidList = unpaidData
//   //           .map((s) => {
//   //         "name": s["name"] ?? "Unknown",
//   //         "amount": s["amount"] ?? 0,
//   //         "paid": false,
//   //         "date": s["date"] ?? "-",
//   //       })
//   //           .toList();
//   //
//   //       final paidList = paidData
//   //           .map((s) => {
//   //         "name": s["name"] ?? "Unknown",
//   //         "amount": s["amount"] ?? 0,
//   //         "paid": true,
//   //         "date": s["date"] ?? "-",
//   //       })
//   //           .toList();
//   //
//   //       setState(() {
//   //         students = [...unpaidList, ...paidList];
//   //         isLoading = false;
//   //       });
//   //     } else {
//   //       throw Exception("Failed to fetch data");
//   //     }
//   //   } catch (e) {
//   //     setState(() => isLoading = false);
//   //     print("Error fetching students: $e");
//   //   }
//   // }
//
//
//   @override
//   Widget build(BuildContext context) {
//     // filter + search
//     List<Map<String, dynamic>> filteredStudents = students.where((student) {
//       final matchesSearch = student["name"]
//           .toString()
//           .toLowerCase()
//           .contains(searchQuery.toLowerCase());
//       final matchesFilter = selectedFilter == "All" ||
//           (selectedFilter == "Paid" && student["paid"] == true) ||
//           (selectedFilter == "Unpaid" && student["paid"] == false);
//       return matchesSearch && matchesFilter;
//     }).toList();
//
//     // stats
//     int total = students.length;
//     int paid = students.where((s) => s["paid"] == true).length;
//     int unpaid = students.where((s) => s["paid"] == false).length;
//
//     return Scaffold(
//       backgroundColor: Colors.grey[100],
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         elevation: 1,
//         title: const Row(
//           children: [
//             Icon(Icons.notifications, color: Colors.blue),
//             SizedBox(width: 8),
//             Text(
//               "Manage Student Fees",
//               style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
//             ),
//           ],
//         ),
//       ),
//       body: isLoading
//           ? const Center(child: CircularProgressIndicator())
//           : SingleChildScrollView(
//         padding: const EdgeInsets.all(12),
//         child: Column(
//           children: [
//             // Stats Row
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//               children: [
//                 _statCard("$total", "Total Records", Colors.black),
//                 _statCard("$paid", "Paid", Colors.green),
//                 _statCard("$unpaid", "Unpaid", Colors.red),
//               ],
//             ),
//             const SizedBox(height: 16),
//
//             // Search bar
//             TextField(
//               decoration: InputDecoration(
//                 prefixIcon: const Icon(Icons.search),
//                 hintText: "Search by student",
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//               ),
//               onChanged: (value) {
//                 setState(() => searchQuery = value);
//               },
//             ),
//             const SizedBox(height: 10),
//
//             // Filter Chips
//             Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 ChoiceChip(
//                   label: const Text("All"),
//                   selected: selectedFilter == "All",
//                   onSelected: (_) {
//                     setState(() => selectedFilter = "All");
//                   },
//                 ),
//                 const SizedBox(width: 8),
//                 ChoiceChip(
//                   label: const Text("Paid"),
//                   selected: selectedFilter == "Paid",
//                   selectedColor: Colors.green.shade100,
//                   onSelected: (_) {
//                     setState(() => selectedFilter = "Paid");
//                   },
//                 ),
//                 const SizedBox(width: 8),
//                 ChoiceChip(
//                   label: const Text("Unpaid"),
//                   selected: selectedFilter == "Unpaid",
//                   selectedColor: Colors.red.shade100,
//                   onSelected: (_) {
//                     setState(() => selectedFilter = "Unpaid");
//                   },
//                 ),
//               ],
//             ),
//             const SizedBox(height: 16),
//
//             // Student Fee Cards
//             Column(
//               children: filteredStudents.map((student) {
//                 return Card(
//                   margin: const EdgeInsets.symmetric(vertical: 6),
//                   shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(12)),
//                   child: Padding(
//                     padding: const EdgeInsets.all(12),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(student["name"],
//                             style: const TextStyle(
//                                 fontWeight: FontWeight.bold,
//                                 fontSize: 16)),
//                         const SizedBox(height: 6),
//                         Row(
//                           children: [
//                             const Icon(Icons.currency_rupee, size: 18),
//                             Text("Amount: ₹${student["amount"]}",
//                                 style: const TextStyle(fontSize: 14)),
//                           ],
//                         ),
//                         const SizedBox(height: 4),
//                         Row(
//                           children: [
//                             const Icon(Icons.calendar_today, size: 16),
//                             const SizedBox(width: 4),
//                             Text("Paid Date: ${student["date"]}",
//                                 style: const TextStyle(fontSize: 14)),
//                           ],
//                         ),
//                         const SizedBox(height: 8),
//                         Row(
//                           mainAxisAlignment:
//                           MainAxisAlignment.spaceBetween,
//                           children: [
//                             Chip(
//                               label: Text(
//                                   student["paid"] ? "Paid" : "Unpaid"),
//                               backgroundColor: student["paid"]
//                                   ? Colors.green.shade100
//                                   : Colors.red.shade100,
//                               labelStyle: TextStyle(
//                                 color: student["paid"]
//                                     ? Colors.green
//                                     : Colors.red,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                           ],
//                         )
//                       ],
//                     ),
//                   ),
//                 );
//               }).toList(),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _statCard(String count, String label, Color color) {
//     return Expanded(
//       child: Card(
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//         child: Padding(
//           padding: const EdgeInsets.symmetric(vertical: 16),
//           child: Column(
//             children: [
//               Text(count,
//                   style: TextStyle(
//                       fontSize: 22, fontWeight: FontWeight.bold, color: color)),
//               const SizedBox(height: 6),
//               Text(label, style: const TextStyle(fontSize: 14)),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
//

// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
//
// // class Fee {
// //   final String id;
// //   final String studentName;
// //   final String amount;
// //   final String status;
// //   final String dueDate;
// //   final String? sport;   // nullable
// //   final String? timing;  // nullable
// //   final String studentId; //
// //   Fee({
// //     required this.studentId,
// //     required this.id,
// //     required this.studentName,
// //     required this.amount,
// //     required this.status,
// //     required this.dueDate,
// //     this.sport,
// //     this.timing,
// //   });
// //
// //   factory Fee.fromJson(Map<String, dynamic> json) {
// //     return Fee(
// //       studentId: json['student_id'] ?? '',
// //       id: json['id'] ?? '',
// //       studentName: json['student_name'] ?? '',
// //       amount: json['amount'] ?? '0',
// //       status: json['status'] ?? '',
// //       dueDate: json['next_due_date'] ?? '',
// //       sport: json['sport'] ?? 'N/A',    // fallback if null
// //       timing: json['timing'] ?? 'N/A',  // fallback if null
// //     );
// //   }
// // }

class Fee {
  final int id;
  final String studentId;
  final String studentName;
  final double amount;
  final String status;
  final String? sport;
  final String? timing;
  final String dueDate;
  final String? paidDate;   // NEW

  Fee({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.amount,
    required this.status,
    this.sport,
    this.timing,
    required this.dueDate,
    this.paidDate,
  });
  factory Fee.fromJson(Map<String, dynamic> json) {
    return Fee(
      id: int.tryParse(json['id'].toString()) ?? 0,
      studentId: json['student_id']?.toString() ?? '',
      studentName: json['student_name'] ?? '',
      amount: double.tryParse(json['amount'].toString()) ?? 0.0,
      status: json['status'] ?? '',
      dueDate: json['next_due_date'] ?? '',
      sport: json['sport'] ?? 'N/A',
      timing: json['timing'] ?? 'N/A',
      paidDate: json['paid_date'], // add if backend gives it
    );
  }



  Fee copyWith({
    String? status,
    String? dueDate,
    String? paidDate,
  }) {
    return Fee(
      id: id,
      studentId: studentId,
      studentName: studentName,
      amount: amount,
      status: status ?? this.status,
      sport: sport,
      timing: timing,
      dueDate: dueDate ?? this.dueDate,
      paidDate: paidDate ?? this.paidDate,
    );
  }
}
class CoachDashboardScreen extends StatefulWidget {
  const CoachDashboardScreen({super.key});

  @override
  State<CoachDashboardScreen> createState() => _CoachDashboardScreenState();
}

class _CoachDashboardScreenState extends State<CoachDashboardScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  TextEditingController searchController = TextEditingController();
  // List<Map<String, dynamic>> displayedFees = [];
  bool isLoading = true;
  List<Fee> fees = []; // all fees
  List<Fee> displayedFees = []; // filtered fees
  // TextEditingController searchController = TextEditingController();


  // Animation
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    fetchFees();

    _controller =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }
  Future<void> fetchFees() async {
    try {
      final response = await http.get(Uri.parse('https://nahatasports.com/api/fees'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body)['data'] as List;
        setState(() {
          fees = data.map((json) => Fee.fromJson(json)).toList();
          displayedFees = List<Fee>.from(fees); // copy for filtering
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  // Future<void> fetchFees() async {
  //   try {
  //     final response = await http.get(Uri.parse('https://nahatasports.com/api/fees'));
  //     if (response.statusCode == 200) {
  //       final data = json.decode(response.body)['data'] as List;
  //       setState(() {
  //         // fees = List<Map<String, dynamic>>.from(data);
  //
  //          fees = data.map((e) => Fee.fromJson(e)).toList();
  //         isLoading = false;
  //       });
  //     } else {
  //       setState(() => isLoading = false);
  //     }
  //   } catch (e) {
  //     setState(() => isLoading = false);
  //   }
  // }

  Future<void> markAsPaid(int feeId) async {
    try {
      final response = await http.post(
        Uri.parse("https://nahatasports.com/api/fees/markPaid/$feeId"),
      );

      final data = json.decode(response.body);
      print("Mark Paid Response: $data");

      if (response.statusCode == 200 && data['status'] == true) {
        setState(() {
          final index = fees.indexWhere((f) => f.id == feeId);
          if (index != -1) {
            fees[index] = fees[index].copyWith(
              status: "paid",
              dueDate: data['data']['next_due_date'],
              paidDate: data['data']['paid_date'],
            );
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? "Fee marked as paid ✅")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? "Failed to update")),
        );
      }
    } catch (e) {
      print("Error in markAsPaid: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'overdue':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
  void _filterFees(String query) {
    setState(() {
      if (query.isEmpty) {
        displayedFees = List<Fee>.from(fees);
      } else {
        displayedFees = fees
            .where((fee) => fee.studentName.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          backgroundColor: const Color(0xFF0A198D),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => LoginScreen()),
              );
            },
          ),
          title: const Text(
            "Coach Dashboard",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
          ),
          centerTitle: true,
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // HEADER SUMMARY
                Row(
                  children: [
                    _statCard(Icons.people, fees.length.toString(), "Students", Colors.blue),
                    const SizedBox(width: 12),
                    _statCard(
                      Icons.check_circle,
                      fees.where((f) => f.status.toLowerCase() == 'paid').length.toString(),
                      "Paid",
                      Colors.green,
                    ),
                    const SizedBox(width: 12),
                    _statCard(
                      Icons.warning,
                      fees.where((f) => f.status.toLowerCase() != 'paid').length.toString(),
                      "Pending",
                      Colors.orange,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // SEARCH BAR
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [Colors.blueAccent.withOpacity(0.3), Colors.lightBlueAccent.withOpacity(0.2)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      )
                    ],
                  ),
                  child: TextField(
                    controller: searchController,
                    onChanged: _filterFees,
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.search, color: Colors.blueAccent),
                      hintText: "Search students...",
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.all(14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  )

                ),

                const SizedBox(height: 20),
                // STUDENT CARDS
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: displayedFees.length,
                  itemBuilder: (context, index) {
                    final fee = displayedFees[index];
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: _studentCard(
                        fee.studentName,
                        fee.sport ?? 'N/A',
                        fee.timing ?? 'N/A',
                        fee.status,
                        fee.dueDate,
                        getStatusColor(fee.status),
                        "Mark Paid",
                        paidDate: fee.paidDate,
                        amount: fee.amount,
                        onMarkPaid: fee.status.toLowerCase() == "paid"
                            ? null
                            : () => markAsPaid(fee.id),
                      ),
                    );
                  },
                ),


                // AnimatedList(
                //   key: _listKey,
                //   shrinkWrap: true,
                //   physics: const NeverScrollableScrollPhysics(),
                //   initialItemCount: fees.length,
                //   itemBuilder: (context, index, animation) {
                //     final fee = fees[index];
                //     return SizeTransition(
                //       sizeFactor: animation,
                //       child: _studentCard(
                //         fee.studentName,
                //         fee.sport ?? 'N/A',
                //         fee.timing ?? 'N/A',
                //         fee.status,
                //         fee.dueDate,
                //         getStatusColor(fee.status),
                //         "Mark Paid",
                //         paidDate: fee.paidDate,
                //         amount: fee.amount,
                //         onMarkPaid: fee.status.toLowerCase() == "paid"
                //             ? null
                //             : () => markAsPaid(fee.id),
                //       ),
                //     );
                //   },
                // ),
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: Colors.blueAccent,
          child: const Icon(Icons.add),
          onPressed: () => _showAddFeeBottomSheet(context),
        ),
      ),
    );
  }
  void _showAddFeeBottomSheet(BuildContext context) {
    final _formKey = GlobalKey<FormState>();
    String? selectedStudentId;
    DateTime? startDate;
    DateTime? endDate;
    final TextEditingController amountController = TextEditingController();
    bool isAddingFee = false;

    // Unique students for dropdown
    final uniqueStudents = {
      for (var fee in fees) fee.studentId: fee.studentName
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.7,
            maxChildSize: 0.95,
            minChildSize: 0.5,
            builder: (context, scrollController) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -4))
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    controller: scrollController,
                    children: [
                      Center(
                        child: Container(
                          width: 50,
                          height: 5,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                      const Text(
                        "➕ Add New Fee",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),

                      // Student Dropdown
                      DropdownButtonFormField<String>(
                        value: selectedStudentId,
                        decoration: InputDecoration(
                          labelText: "Select Student",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                        items: uniqueStudents.entries.map((entry) {
                          return DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text(entry.value),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => selectedStudentId = val),
                        validator: (val) => val == null ? "Select a student" : null,
                      ),
                      const SizedBox(height: 12),

                      // Start Date
                      TextFormField(
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: "Start Date",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          suffixIcon: const Icon(Icons.calendar_today),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                        controller: TextEditingController(
                          text: startDate == null
                              ? ''
                              : "${startDate!.month}/${startDate!.day}/${startDate!.year}",
                        ),
                        onTap: () async {
                          DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) setState(() => startDate = picked);
                        },
                        validator: (val) => startDate == null ? "Select start date" : null,
                      ),
                      const SizedBox(height: 12),

                      // End Date
                      TextFormField(
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: "End Date",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          suffixIcon: const Icon(Icons.calendar_today),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                        controller: TextEditingController(
                          text: endDate == null
                              ? ''
                              : "${endDate!.month}/${endDate!.day}/${endDate!.year}",
                        ),
                        onTap: () async {
                          DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) setState(() => endDate = picked);
                        },
                        validator: (val) => endDate == null ? "Select end date" : null,
                      ),
                      const SizedBox(height: 12),

                      // Amount
                      TextFormField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: "Amount",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                        validator: (val) => val == null || val.isEmpty ? "Enter amount" : null,
                      ),
                      const SizedBox(height: 20),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: isAddingFee
                              ? null
                              : () async {
                            if (!_formKey.currentState!.validate()) return;

                            setState(() => isAddingFee = true);

                            try {
                              final body = json.encode({
                                "student_id": int.parse(selectedStudentId!),
                                "amount": double.parse(amountController.text),
                                "start_date": startDate!.toIso8601String().split('T')[0],
                                "end_date": endDate!.toIso8601String().split('T')[0],
                                "status": "unpaid",
                              });

                              final response = await http.post(
                                Uri.parse('https://nahatasports.com/api/fees/add'),
                                headers: {'Content-Type': 'application/json'},
                                body: body,
                              );

                              final data = json.decode(response.body);

                              if ((response.statusCode == 200 || response.statusCode == 201) &&
                                  data['status'] == true) {
                                // Convert API data to Fee object
                                final newFee = Fee.fromJson(data['data']);

                                fees.add(newFee);
                                _listKey.currentState?.insertItem(
                                  fees.length - 1,
                                  duration: const Duration(milliseconds: 500),
                                );

                                Navigator.pop(context); // close sheet

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(data['message'] ?? "✅ Fee added successfully"),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(data['message'] ?? "❌ Failed to add fee"),
                                  ),
                                );
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Error: $e")),
                              );
                            } finally {
                              setState(() => isAddingFee = false);
                            }
                          },
                          child: isAddingFee
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text("Add Fee", style: TextStyle(fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        });
      },
    );
  }

  Widget _statCard(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color.withOpacity(0.8), color]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  static Widget _studentCard(
      String name,
      String sport,
      String timing,
      String status,
      String due,
      Color statusColor,
      String actionText, {
        double? amount,
        String? paidDate,
        VoidCallback? onMarkPaid,
      }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 6,
      margin: const EdgeInsets.symmetric(vertical: 10),
      shadowColor: Colors.black26,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.white, Colors.grey[50]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar with premium accent border
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Colors.blueAccent, Colors.lightBlueAccent],
                ),
              ),
              padding: const EdgeInsets.all(2),
              child: const CircleAvatar(
                radius: 28,
                backgroundColor: Colors.grey,
                child: Icon(Icons.person, color: Colors.white),
              ),
            ),
            const SizedBox(width: 16),

            // Info Section
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    sport,
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timing,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 6),

                  // Paid / Due Info
                  status.toLowerCase() == "paid"
                      ? RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 12),
                      children: [
                        TextSpan(
                            text: "Paid on: $paidDate  ",
                            style: const TextStyle(color: Colors.green)),
                        TextSpan(
                            text: "\nNext Due: $due",
                            style: const TextStyle(color: Colors.black54)),
                        TextSpan(
                            text: "\n₹$amount",
                            style: const TextStyle(color: Colors.black87)),
                      ],
                    ),
                  )
                      : Text(
                    "Due: $due\n₹$amount",
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),

            // Status & Action Button
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ),
                const SizedBox(height: 6),
                if (status.toLowerCase() != "paid")
                  ElevatedButton(
                    onPressed: onMarkPaid,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent[700],
                      foregroundColor: Colors.white,
                      minimumSize: const Size(70, 28), // smaller button
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 3,
                    ),
                    child: Text(
                      actionText,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }



// Add Fee BottomSheet remains mostly same, just update to add Fee objects instead of Map
}


















// class CoachDashboardScreen extends StatefulWidget {
//   const CoachDashboardScreen({super.key});
//
//   @override
//   State<CoachDashboardScreen> createState() => _CoachDashboardScreenState();
// }
//
// class _CoachDashboardScreenState extends State<CoachDashboardScreen> {
//
//
//   List<Fee> allFees = [];
//   List<Fee> displayedFees = [];
//   bool isLoading = true;
//   String searchQuery = '';
//   String selectedFilter = 'All';
//   String? selectedStudentId;
//   DateTime? startDate;
//   DateTime? endDate;
//   TextEditingController amountController = TextEditingController();
//   bool isAddingFee = false;
//
//   @override
//   void initState() {
//     super.initState();
//     fetchFees();
//   }
//
//
//   Future<void> fetchFees() async {
//     try {
//       final response = await http.get(
//           Uri.parse('https://nahatasports.com/api/fees'));
//       if (response.statusCode == 200) {
//         final data = json.decode(response.body)['data'] as List;
//         setState(() {
//           allFees = data.map((json) => Fee.fromJson(json)).toList();
//           applyFilters();
//           isLoading = false;
//         });
//         print('Fees fetched successfully');
//         print(data);
//       } else {
//         print('Failed to load fees: ${response.statusCode}');
//         setState(() => isLoading = false);
//       }
//     } catch (e) {
//       print('Error fetching fees: $e');
//       setState(() => isLoading = false);
//     }
//   }
//
//   Future<void> addFee() async {
//     if (selectedStudentId == null || startDate == null || endDate == null || amountController.text.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Please fill all fields')),
//       );
//       return;
//     }
//
//     setState(() => isAddingFee = true);
//
//     try {
//       final response = await http.post(
//         Uri.parse('https://nahatasports.com/api/fees/add'),
//         headers: {'Content-Type': 'application/json'},
//         body: json.encode({
//           "student_id": int.parse(selectedStudentId!),
//           "amount": double.parse(amountController.text),
//           "start_date": startDate!.toIso8601String().split('T')[0],
//           "end_date": endDate!.toIso8601String().split('T')[0],
//           "status": "unpaid",
//         }),
//       );
//       print("Request Body: ${json.encode({
//         "student_id": int.parse(selectedStudentId!),
//         "amount": double.parse(amountController.text),
//         "start_date": startDate!.toIso8601String().split('T')[0],
//         "end_date": endDate!.toIso8601String().split('T')[0],
//         "status": "unpaid",
//       })}");
//       final data = json.decode(response.body);
//       if (response.statusCode == 200 && data['status'] == true) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Fee added successfully!')),
//         );
//
//         // Add new fee to dashboard
//         setState(() {
//           allFees.add(Fee.fromJson(data['data']));
//           applyFilters();
//
//           // Clear form
//           selectedStudentId = null;
//           startDate = null;
//           endDate = null;
//           amountController.clear();
//         });
//         print('Fee added successfully');
//         print(data);
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text(data['message'] ?? 'Failed to add fee')),
//         );
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error: $e')),
//       );
//     } finally {
//       setState(() => isAddingFee = false);
//     }
//   }
//
//   void applyFilters() {
//     List<Fee> filtered = allFees;
//
//     if (selectedFilter != 'All') {
//       filtered = filtered.where((fee) =>
//       fee.status.toLowerCase() ==
//           selectedFilter.toLowerCase()).toList();
//     }
//
//     if (searchQuery.isNotEmpty) {
//       filtered = filtered
//           .where((fee) =>
//           fee.studentName.toLowerCase().contains(searchQuery.toLowerCase()))
//           .toList();
//     }
//
//     setState(() {
//       displayedFees = filtered;
//     });
//   }
//
//   Color getStatusColor(String status) {
//     switch (status.toLowerCase()) {
//       case 'paid':
//         return Colors.green;
//       case 'pending':
//         return Colors.orange;
//       case 'overdue':
//         return Colors.red;
//       default:
//         return Colors.grey;
//     }
//   }
//
//   String getActionText(String status) {
//     switch (status.toLowerCase()) {
//       case 'paid':
//         return 'Confirmed';
//       case 'pending':
//       case 'overdue':
//         return 'Mark as Paid';
//       default:
//         return 'Update';
//     }
//   }
//
//   static Widget _statCard(IconData icon, String value, String label,
//       Color color) {
//     return Expanded(
//       child: Card(
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//         child: Padding(
//           padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
//           child: Column(
//             children: [
//               Icon(icon, color: color, size: 28),
//               const SizedBox(height: 6),
//               Text(value, style: TextStyle(
//                   fontSize: 18, fontWeight: FontWeight.bold, color: color)),
//               const SizedBox(height: 4),
//               Text(label, style: const TextStyle(fontSize: 12)),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   static Widget _filterChip(String label, bool isSelected,
//       Function(bool) onSelected) {
//     return ChoiceChip(
//       label: Text(label),
//       selected: isSelected,
//       selectedColor: Colors.blue,
//       onSelected: onSelected,
//     );
//   }
//
//   static Widget _studentCard(
//       String name,
//       String sport,
//       String timing,
//       String status,
//       String due,
//       Color statusColor,
//       String actionText, {
//         double? amount,
//         String? paidDate, // <-- add this
//         VoidCallback? onMarkPaid,
//       }) {
//     return Card(
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       margin: const EdgeInsets.symmetric(vertical: 8),
//       child: Padding(
//         padding: const EdgeInsets.all(12),
//         child: Row(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const CircleAvatar(radius: 24, backgroundColor: Colors.grey),
//             const SizedBox(width: 12),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(name,
//                       style: const TextStyle(fontWeight: FontWeight.w600)),
//                   const SizedBox(height: 4),
//
//                   // 👇 show "Paid on" if status is paid, otherwise show "Due"
//                   status.toLowerCase() == "paid"
//                       ? Text(
//                     "Paid on: $paidDate • Next Due: $due • ₹$amount",
//                     style: const TextStyle(
//                         fontSize: 12, color: Colors.green),
//                   )
//                       : Text(
//                     "Due: $due • ₹$amount",
//                     style: const TextStyle(
//                         fontSize: 12, color: Colors.black54),
//                   ),
//                 ],
//               ),
//             ),
//             Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Container(
//                   padding:
//                   const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                   decoration: BoxDecoration(
//                     color: statusColor.withOpacity(0.1),
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                   child: Text(status,
//                       style: TextStyle(color: statusColor, fontSize: 12)),
//                 ),
//                 const SizedBox(height: 6),
//
//                 // Only show button if not paid
//                 if (status.toLowerCase() != "paid")
//                   ElevatedButton(
//                     onPressed: onMarkPaid,
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.green,
//                       foregroundColor: Colors.white,
//                       minimumSize: const Size(90, 30),
//                       shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(8)),
//                     ),
//                     child:
//                     Text(actionText, style: const TextStyle(fontSize: 12)),
//                   ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Future<void> markAsPaid(int feeId) async {
//     try {
//       final response = await http.post(
//         Uri.parse("https://nahatasports.com/api/fees/markPaid/$feeId"),
//       );
//
//       final data = json.decode(response.body);
//       print("Mark Paid Response: $data");
//
//       if (response.statusCode == 200 && data['status'] == true) {
//         setState(() {
//           final index = allFees.indexWhere((f) => f.id == feeId);
//           if (index != -1) {
//             allFees[index] = allFees[index].copyWith(
//               status: "paid",
//               dueDate: data['data']['next_due_date'],
//               paidDate: data['data']['paid_date'], // add this field in Fee model
//             );
//           }
//           applyFilters();
//         });
//
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text(data['message'] ?? "Fee marked as paid ✅")),
//         );
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text(data['message'] ?? "Failed to update")),
//         );
//       }
//     } catch (e) {
//       print("Error in markAsPaid: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text("Error: $e")),
//       );
//     }
//   }
//
//
//
//
//
//
//
//
//
//
//   @override
//   Widget build(BuildContext context) {
//     // inside build(BuildContext context)
//     final uniqueStudents = {
//       for (var fee in allFees) fee.studentId: fee.studentName
//     };
//
//     int totalStudents = allFees.length;
//     int paidCount = allFees.where((f) => f.status.toLowerCase() == 'paid').length;
//     int pendingCount = allFees.where((f) => f.status.toLowerCase() == 'pending').length;
//     int overdueCount = allFees.where((f) => f.status.toLowerCase() == 'overdue').length;
//
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         elevation: 0,
//         title: const Text("Coach Dashboard", style: TextStyle(color: Colors.black)),
//         centerTitle: true,
//         iconTheme: const IconThemeData(color: Colors.black),
//       ),
//       body: isLoading
//           ? const Center(child: CircularProgressIndicator())
//           : SingleChildScrollView(
//         child: Padding(
//           padding: const EdgeInsets.all(12),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.center,
//             children: [
//               Card(
//                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                 child: Padding(
//                   padding: const EdgeInsets.all(16),
//                   child: const Text(
//                     "Mark provisional fee payments for office confirmation",
//                     textAlign: TextAlign.center,
//                     style: TextStyle(color: Colors.black54),
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 16),
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceAround,
//                 children: [
//                   _statCard(Icons.people, "$totalStudents", "Total Students", Colors.blue),
//                   _statCard(Icons.check_circle, "$paidCount", "Fees Paid", Colors.green),
//                   _statCard(Icons.access_time, "$pendingCount", "Pending", Colors.orange),
//                   _statCard(Icons.error, "$overdueCount", "Overdue", Colors.red),
//                 ],
//               ),
//               const SizedBox(height: 16),
//               Card(
//                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                 child: Padding(
//                   padding: const EdgeInsets.all(12),
//                   child: Column(
//                     children: [
//                       TextField(
//                         onChanged: (value) {
//                           searchQuery = value;
//                           applyFilters();
//                         },
//                         decoration: InputDecoration(
//                           prefixIcon: const Icon(Icons.search, color: Colors.black),
//                           hintText: "Search students by name...",
//                           border: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(8),
//                             borderSide: BorderSide.none,
//                           ),
//                           filled: true,
//                           fillColor: Colors.grey[200],
//                         ),
//                       ),
//                       const SizedBox(height: 12),
//                       Card(
//                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                         margin: const EdgeInsets.symmetric(vertical: 16),
//                         child: Padding(
//                           padding: const EdgeInsets.all(16),
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               const Text(
//                                 "Add Fee Record",
//                                 style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//                               ),
//                               const SizedBox(height: 12),
//
//                               // Student Dropdown
//                               DropdownButtonFormField<String>(
//                                 value: uniqueStudents.containsKey(selectedStudentId) ? selectedStudentId : null,
//                                 decoration: InputDecoration(
//                                   labelText: "Select Student",
//                                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
//                                   contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                                 ),
//                                 items: uniqueStudents.entries.map((entry) {
//                                   return DropdownMenuItem<String>(
//                                     value: entry.key,
//                                     child: Text(entry.value),
//                                   );
//                                 }).toList(),
//                                 onChanged: (value) => setState(() => selectedStudentId = value),
//                               ),
//
//
//                               const SizedBox(height: 12),
//
//                               // Start Date
//                               TextFormField(
//                                 readOnly: true,
//                                 decoration: InputDecoration(
//                                   labelText: "Start Date",
//                                   hintText: "mm/dd/yyyy",
//                                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
//                                   suffixIcon: const Icon(Icons.calendar_today),
//                                 ),
//                                 controller: TextEditingController(text: startDate == null ? '' : "${startDate!.month}/${startDate!.day}/${startDate!.year}"),
//                                 onTap: () async {
//                                   DateTime? picked = await showDatePicker(
//                                     context: context,
//                                     initialDate: DateTime.now(),
//                                     firstDate: DateTime(2000),
//                                     lastDate: DateTime(2100),
//                                   );
//                                   if (picked != null) setState(() => startDate = picked);
//                                 },
//                               ),
//
//                               const SizedBox(height: 12),
//
//                               // End Date
//                               TextFormField(
//                                 readOnly: true,
//                                 decoration: InputDecoration(
//                                   labelText: "End Date",
//                                   hintText: "mm/dd/yyyy",
//                                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
//                                   suffixIcon: const Icon(Icons.calendar_today),
//                                 ),
//                                 controller: TextEditingController(text: endDate == null ? '' : "${endDate!.month}/${endDate!.day}/${endDate!.year}"),
//                                 onTap: () async {
//                                   DateTime? picked = await showDatePicker(
//                                     context: context,
//                                     initialDate: DateTime.now(),
//                                     firstDate: DateTime(2000),
//                                     lastDate: DateTime(2100),
//                                   );
//                                   if (picked != null) setState(() => endDate = picked);
//                                 },
//                               ),
//
//                               const SizedBox(height: 12),
//
//                               // Amount
//                               TextFormField(
//                                 controller: amountController,
//                                 keyboardType: TextInputType.number,
//                                 decoration: InputDecoration(
//                                   labelText: "Amount",
//                                   hintText: "Enter Amount",
//                                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
//                                 ),
//                               ),
//
//                               const SizedBox(height: 16),
//
//                               // Submit button
//                               SizedBox(
//                                 width: double.infinity,
//                                 child: ElevatedButton(
//                                   onPressed: isAddingFee ? null : addFee,
//                                   style: ElevatedButton.styleFrom(
//                                     backgroundColor: Colors.green,
//                                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//                                   ),
//                                   child: isAddingFee
//                                       ? const CircularProgressIndicator(color: Colors.white)
//                                       : const Text("Add Fee"),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//
//
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                         children: [
//                           _filterChip("All", selectedFilter == "All", (selected) {
//                             selectedFilter = "All";
//                             applyFilters();
//                           }),
//                           _filterChip("Paid", selectedFilter == "Paid", (selected) {
//                             selectedFilter = "Paid";
//                             applyFilters();
//                           }),
//                           _filterChip("Pending", selectedFilter == "Pending", (selected) {
//                             selectedFilter = "Pending";
//                             applyFilters();
//                           }),
//                           _filterChip("Overdue", selectedFilter == "Overdue", (selected) {
//                             selectedFilter = "Overdue";
//                             applyFilters();
//                           }),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 16),
//               Column(
//                 children: displayedFees.map((fee) {
//                   return _studentCard(
//                     fee.studentName,
//                     fee.sport ?? 'N/A',
//                     fee.timing ?? 'N/A',
//                     fee.status,
//                     fee.dueDate,                        // Next due
//                     getStatusColor(fee.status),
//                     getActionText(fee.status),
//                     paidDate: fee.paidDate,             // 👈 add this
//                     onMarkPaid: fee.status.toLowerCase() == "paid"
//                         ? null
//                         : () => markAsPaid(fee.id),
//                     amount: fee.amount,
//                   );
//                 }).toList(),
//               ),
//
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }











//
//
// class CoachDashboardScreen extends StatefulWidget {
//   const CoachDashboardScreen({super.key});
//
//   @override
//   State<CoachDashboardScreen> createState() => _CoachDashboardScreenState();
//
//   // static Widget _roleButton(String label, IconData icon, bool isSelected) {
//   //   return Expanded(
//   //     child: Container(
//   //       margin: const EdgeInsets.symmetric(horizontal: 4),
//   //       child: ElevatedButton.icon(
//   //         style: ElevatedButton.styleFrom(
//   //           backgroundColor: isSelected ? Colors.green : Colors.blue,
//   //           foregroundColor: Colors.black,
//   //           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10), // reduce padding
//   //           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//   //         ),
//   //         onPressed: () {},
//   //         icon: Icon(icon, size: 14), // smaller icon
//   //         label: Flexible( // ensures text wraps instead of overflow
//   //           child: Text(
//   //             label,
//   //             style: const TextStyle(fontSize: 11), // smaller text
//   //             overflow: TextOverflow.ellipsis,
//   //             maxLines: 1,
//   //           ),
//   //         ),
//   //       ),
//   //     ),
//   //   );
//   // }
//
//
//   static Widget _statCard(IconData icon, String value, String label, Color color) {
//     return Expanded(
//       child: Card(
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//         child: Padding(
//           padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
//           child: Column(
//             children: [
//               Icon(icon, color: color, size: 28),
//               const SizedBox(height: 6),
//               Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
//               const SizedBox(height: 4),
//               Text(label, style: const TextStyle(fontSize: 12)),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   static Widget _filterChip(String label, bool isSelected) {
//     return ChoiceChip(
//       label: Text(label),
//       selected: isSelected,
//       selectedColor: Colors.blue,
//       onSelected: (_) {},
//     );
//   }
//
//   static Widget _studentCard(String name, String subtitle, String status,
//       String due, Color statusColor, String actionText) {
//     return Card(
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       margin: const EdgeInsets.symmetric(vertical: 8),
//       child: Padding(
//         padding: const EdgeInsets.all(12),
//         child: Row(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const CircleAvatar(radius: 24, backgroundColor: Colors.grey),
//             const SizedBox(width: 12),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
//                   Text(subtitle),
//                   const SizedBox(height: 4),
//                   Text(due, style: const TextStyle(fontSize: 12, color: Colors.black54)),
//                 ],
//               ),
//             ),
//             Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                   decoration: BoxDecoration(
//                     color: statusColor.withOpacity(0.1),
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                   child: Text(status,
//                       style: TextStyle(color: statusColor, fontSize: 12)),
//                 ),
//                 const SizedBox(height: 6),
//                 ElevatedButton(
//                   onPressed: () {},
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.green,
//                     foregroundColor: Colors.white,
//                     minimumSize: const Size(90, 30),
//                     shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(8)),
//                   ),
//                   child: Text(actionText, style: const TextStyle(fontSize: 12)),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
// }
//
// class _CoachDashboardScreenState extends State<CoachDashboardScreen> {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       // backgroundColor: Colors.yellow[200], // background like screenshot
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         elevation: 0,
//         title: const Text("Coach Dashboard", style: TextStyle(color: Colors.black)),
//         centerTitle: true,
//         iconTheme: const IconThemeData(color: Colors.black),
//       ),
//       body: SingleChildScrollView(
//         child: Padding(
//           padding: const EdgeInsets.all(12),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.center,
//             children: [
//               // --------- Role Selector ---------
//               // Card(
//               //   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//               //   child: Padding(
//               //     padding: const EdgeInsets.all(12),
//               //     child: Row(
//               //       mainAxisAlignment: MainAxisAlignment.spaceAround,
//               //       children: [
//               //         _roleButton("Student/Parent", Icons.person, false),
//               //         _roleButton("Coach", Icons.sports, true),
//               //         _roleButton("Office Admin", Icons.admin_panel_settings, false),
//               //         _roleButton("Security", Icons.security, false),
//               //         _roleButton("Manager/Owner", Icons.manage_accounts, false),
//               //       ],
//               //     ),
//               //   ),
//               // ),
//
//               // const SizedBox(height: 16),
//
//               // --------- Dashboard Heading ---------
//               Card(
//                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                 child: Padding(
//                   padding: const EdgeInsets.all(16),
//                   child: Column(
//                     children: const [
//                       // Text("Coach Dashboard", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//                       // SizedBox(height: 6),
//                       Text("Mark provisional fee payments for office confirmation",
//                           textAlign: TextAlign.center,
//                           style: TextStyle(color: Colors.black54)),
//                     ],
//                   ),
//                 ),
//               ),
//
//               const SizedBox(height: 16),
//
//               // --------- Stats Row ---------
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceAround,
//                 children:  [
//                   CoachDashboardScreen._statCard(Icons.people, "4", "Total Students", Colors.blue),
//                   CoachDashboardScreen._statCard(Icons.check_circle, "2", "Fees Paid", Colors.green),
//                   CoachDashboardScreen._statCard(Icons.access_time, "0", "Pending", Colors.orange),
//                   CoachDashboardScreen._statCard(Icons.error, "2", "Overdue", Colors.red),
//                 ],
//               ),
//
//               const SizedBox(height: 16),
//
//               // --------- Search & Filters ---------
//               Card(
//                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                 child: Padding(
//                   padding: const EdgeInsets.all(12),
//                   child: Column(
//                     children: [
//                       TextField(
//                         decoration: InputDecoration(
//                           prefixIcon: const Icon(Icons.search, color: Colors.black),
//                           hintText: "Search students by name or sport...",
//                           border: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(8),
//                             borderSide: BorderSide.none,
//                           ),
//                           filled: true,
//                           fillColor: Colors.grey[200],
//                         ),
//                       ),
//                       const SizedBox(height: 12),
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                         children: [
//                           CoachDashboardScreen._filterChip("All", true),
//                           CoachDashboardScreen._filterChip("Paid", false),
//                           CoachDashboardScreen._filterChip("Pending", false),
//                           CoachDashboardScreen._filterChip("Overdue", false),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//
//               const SizedBox(height: 16),
//
//               // --------- Student List ---------
//               CoachDashboardScreen._studentCard("Alex Johnson", "Badminton • Evening (5:00–7:00 PM)", "Paid",
//                   "Due: 2024-03-15 • \$150", Colors.green, "Confirmed"),
//               CoachDashboardScreen._studentCard("Sarah Davis", "Basketball • Morning (8:00–10:00 AM)", "Overdue",
//                   "Due: 2024-01-15 • \$120", Colors.red, "Mark as Paid"),
//               CoachDashboardScreen._studentCard("Mike Wilson", "Badminton • Evening (6:00–8:00 PM)", "Overdue",
//                   "Due: 2024-02-01 • \$150", Colors.red, "Mark as Paid"),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }



// coach@gmail.com
// admin@gmail.com




































//
//
//
// static Widget _studentCard(
// String name,
// String sport,
// String timing,
// String status,
// String due,
// Color statusColor,
// String actionText, {
// String? paidDate,
// double? amount,
// VoidCallback? onMarkPaid,
// }) {
// // pick amount color based on status
// Color amountColor;
// switch (status.toLowerCase()) {
// case "paid":
// amountColor = Colors.green;
// break;
// case "overdue":
// amountColor = Colors.red;
// break;
// default:
// amountColor = Colors.orange; // pending/unpaid
// }
//
// return Card(
// shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
// margin: const EdgeInsets.symmetric(vertical: 8),
// child: Padding(
// padding: const EdgeInsets.all(12),
// child: Row(
// crossAxisAlignment: CrossAxisAlignment.start,
// children: [
// const CircleAvatar(radius: 24, backgroundColor: Colors.grey),
// const SizedBox(width: 12),
// Expanded(
// child: Column(
// crossAxisAlignment: CrossAxisAlignment.start,
// children: [
// Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
// const SizedBox(height: 4),
//
// // status-specific text
// status.toLowerCase() == "paid"
// ? Text(
// "Paid on: $paidDate\nNext Due: $due",
// style: const TextStyle(
// fontSize: 12,
// color: Colors.black54,
// ),
// )
//     : Text(
// "Due: $due",
// style: const TextStyle(
// fontSize: 12,
// color: Colors.black54,
// ),
// ),
//
// const SizedBox(height: 4),
//
// // amount line
// if (amount != null)
// Text(
// "₹${amount.toStringAsFixed(2)}",
// style: TextStyle(
// fontSize: 13,
// fontWeight: FontWeight.w600,
// color: amountColor,
// ),
// ),
// ],
// ),
// ),
// Column(
// mainAxisAlignment: MainAxisAlignment.center,
// children: [
// Container(
// padding:
// const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
// decoration: BoxDecoration(
// color: statusColor.withOpacity(0.1),
// borderRadius: BorderRadius.circular(8),
// ),
// child: Text(status,
// style: TextStyle(color: statusColor, fontSize: 12)),
// ),
// ],
// ),
// ],
// ),
// ),
// );
// }
