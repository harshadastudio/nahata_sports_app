// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
//
// class AdminDashboardScreen extends StatelessWidget {
//   const AdminDashboardScreen({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       // backgroundColor: Colors.yellow[200],
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         elevation: 0,
//         title: const Text("Office Admin Dashboard", style: TextStyle(color: Colors.black)),
//         centerTitle: true,
//         iconTheme: const IconThemeData(color: Colors.black),
//         actions: [
//           Padding(
//             padding: const EdgeInsets.only(right: 12),
//             child: Chip(
//               label: const Text("3 Pending", style: TextStyle(color: Colors.red)),
//               backgroundColor: Colors.red.shade50,
//             ),
//           ),
//         ],
//       ),
//       body: SingleChildScrollView(
//         child: Padding(
//           padding: const EdgeInsets.all(12),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // ---------- Subtitle ----------
//               Card(
//                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                 child: const Padding(
//                   padding: EdgeInsets.all(16),
//                   child: Text(
//                     "Review and confirm fee payments marked by coaches",
//                     textAlign: TextAlign.center,
//                     style: TextStyle(color: Colors.black54),
//                   ),
//                 ),
//               ),
//
//               const SizedBox(height: 16),
//
//               // ---------- Stats Row ----------
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceAround,
//                 children:  [
//                   _statCard(Icons.access_time, "3", "Pending Confirmations", Colors.orange),
//                   _statCard(Icons.check_circle, "12", "Confirmed Today", Colors.green),
//                   _statCard(Icons.people, "156", "Total Students", Colors.blue),
//                 ],
//               ),
//
//               const SizedBox(height: 16),
//
//               // ---------- Search ----------
//               Card(
//                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                 child: Padding(
//                   padding: const EdgeInsets.all(12),
//                   child: TextField(
//                     decoration: InputDecoration(
//                       prefixIcon: const Icon(Icons.search, color: Colors.black),
//                       hintText: "Search by student name, sport, or coach...",
//                       border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(8),
//                         borderSide: BorderSide.none,
//                       ),
//                       filled: true,
//                       fillColor: Colors.grey[200],
//                     ),
//                   ),
//                 ),
//               ),
//
//               const SizedBox(height: 16),
//
//               // ---------- Section Title ----------
//               const Text(
//                 "Payments Awaiting Confirmation",
//                 style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//               ),
//
//               const SizedBox(height: 8),
//
//               // ---------- Payment Cards ----------
//               _paymentCard(
//                 name: "Mike Wilson",
//                 id: 107,
//                 due: "2025-09-30",
//                 amount: "\$150.00",
//                 coach: "Coach Sarah",
//                 markedDate: "2025-08-26 09:15:22",
//                 approvedByAdmin: false,
//                 gatePassIssued: false,
//                 qrCode: "",
//                 qrValidUntil: "",
//                 paymentId: 5,
//               ),
//
//               _paymentCard(
//                 name: "Mike Wilson",
//                 id: 107,
//                 due: "2025-09-30",
//                 amount: "\$150.00",
//                 coach: "Coach Sarah",
//                 markedDate: "2025-08-26 09:15:22",
//                 approvedByAdmin: false,
//                 gatePassIssued: false,
//                 qrCode: "",
//                 qrValidUntil: "",
//                 paymentId: 5,
//               ),
//
//               _paymentCard(
//                 name: "Mike Wilson",
//                 id: 107,
//                 due: "2025-09-30",
//                 amount: "\$150.00",
//                 coach: "Coach Sarah",
//                 markedDate: "2025-08-26 09:15:22",
//                 approvedByAdmin: false,
//                 gatePassIssued: false,
//                 qrCode: "",
//                 qrValidUntil: "",
//                 paymentId: 5,
//               ),
//
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   // ---------- Helper Widgets ----------
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
//               Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//   Widget _paymentCard({
//     required String name,
//     required int id,
//     required String due,
//     required String amount,
//     required String coach,
//     required String markedDate,
//     required bool approvedByAdmin,
//     required bool gatePassIssued,
//     required String qrCode,
//     required String qrValidUntil,
//     required int paymentId,
//   }) {
//     return StatefulBuilder(
//       builder: (context, setState) {
//         String status = "pending"; // pending / approved / rejected
//
//         void approve() {
//           setState(() {
//             status = "approved";
//           });
//           // TODO: call approve API here with paymentId
//         }
//
//         void reject() {
//           setState(() {
//             status = "rejected";
//           });
//           // TODO: call reject API here with paymentId
//         }
//
//         return Card(
//           margin: const EdgeInsets.symmetric(vertical: 8),
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//           child: Padding(
//             padding: const EdgeInsets.all(12),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 // Name
//                 Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
//                 const Divider(height: 6, thickness: 1),
//                 // ID and Due
//                 Text("ID: $id • Due: $due", style: const TextStyle(color: Colors.black54)),
//                 // Amount
//                 Text(amount, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
//                 // Marked by Coach
//                 Text("Marked by $coach", style: const TextStyle(fontSize: 12)),
//                 Text("on $markedDate", style: const TextStyle(fontSize: 12, color: Colors.black54)),
//                 const SizedBox(height: 8),
//
//                 // ----------------- Actions / Status -----------------
//                 if (status == "pending")
//                   Row(
//                     children: [
//                       OutlinedButton(onPressed: reject, child: const Text("Reject", style: TextStyle(fontSize: 12))),
//                       const SizedBox(width: 6),
//                       ElevatedButton(onPressed: approve, child: const Text("Approve", style: TextStyle(fontSize: 12))),
//                     ],
//                   )
//                 else if (status == "approved") ...[
//                   if (approvedByAdmin)
//                     Chip(label: const Text("Approved by Admin", style: TextStyle(fontSize: 12)), backgroundColor: Colors.green[100]),
//                   if (gatePassIssued)
//                     Chip(label: const Text("Gate Pass Issued", style: TextStyle(fontSize: 12)), backgroundColor: Colors.blue[100]),
//                   const SizedBox(height: 8),
//                   Row(
//                     children: [
//                       const Icon(Icons.qr_code, size: 20),
//                       const SizedBox(width: 6),
//                       Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text("QR Code: $qrCode", style: const TextStyle(fontSize: 12)),
//                           Text("Valid until $qrValidUntil", style: const TextStyle(fontSize: 12, color: Colors.black54)),
//                         ],
//                       )
//                     ],
//                   ),
//                 ] else if (status == "rejected") ...[
//                   Chip(label: const Text("Rejected by Admin", style: TextStyle(fontSize: 12)), backgroundColor: Colors.red[100]),
//                 ],
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }
//
//
// }
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
//
//
//
//
//
//
//
//
// // class AdminDashboardScreen extends StatefulWidget {
// //   const AdminDashboardScreen({super.key});
// //
// //   @override
// //   State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
// // }
// //
// // class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
// //   List<dynamic> payments = [];
// //   bool isLoading = true;
// //
// //   @override
// //   void initState() {
// //     super.initState();
// //     // fetchPayments();
// //   }
// //
// //
// //
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       appBar: AppBar(title: const Text("Admin Dashboard")),
// //       body: isLoading
// //           ? const Center(child: CircularProgressIndicator())
// //           : ListView(
// //         padding: const EdgeInsets.all(16),
// //         children: [
// //           const Text(
// //             "Payments Awaiting Confirmation",
// //             style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
// //           ),
// //           const SizedBox(height: 12),
// //           ...payments.map((p) => PaymentCard(
// //             data: p,
// //             onApprove: (){},
// //             onReject: () {},
// //           )),
// //         ],
// //       ),
// //     );
// //   }
// // }
// //
// // class PaymentCard extends StatelessWidget {
// //   final Map<String, dynamic> data;
// //   final VoidCallback onApprove;
// //   final VoidCallback onReject;
// //
// //   const PaymentCard({
// //     super.key,
// //     required this.data,
// //     required this.onApprove,
// //     required this.onReject,
// //   });
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     final isApproved = data["approvedByAdmin"] == true;
// //     final isRejected = data["rejectedByAdmin"] == true;
// //
// //     return Card(
// //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
// //       margin: const EdgeInsets.symmetric(vertical: 8),
// //       child: Padding(
// //         padding: const EdgeInsets.all(12),
// //         child: Column(
// //           crossAxisAlignment: CrossAxisAlignment.start,
// //           children: [
// //             Text(data["name"] ?? "",
// //                 style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
// //             Text("ID: ${data["id"]} • Due: ${data["due"]}"),
// //             Text(data["amount"] ?? ""),
// //             Text("Marked by ${data["coach"]} on ${data["markedDate"]}"),
// //
// //             const SizedBox(height: 8),
// //
// //             if (!isApproved && !isRejected) ...[
// //               Row(
// //                 children: [
// //                   ElevatedButton(
// //                     onPressed: onApprove,
// //                     child: const Text("Approve"),
// //                   ),
// //                   const SizedBox(width: 8),
// //                   ElevatedButton(
// //                     onPressed: onReject,
// //                     style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
// //                     child: const Text("Reject"),
// //                   ),
// //                 ],
// //               ),
// //             ],
// //
// //             if (isApproved) ...[
// //               const SizedBox(height: 8),
// //               const Text("✅ Approved by Admin"),
// //               if (data["qrCode"] != null && data["qrCode"].toString().isNotEmpty)
// //                 Text("QR Code: ${data["qrCode"]}"),
// //             ],
// //
// //             if (isRejected) ...[
// //               const SizedBox(height: 8),
// //               const Text("❌ Rejected by Admin", style: TextStyle(color: Colors.red)),
// //             ],
// //           ],
// //         ),
// //       ),
// //     );
// //   }
// // }
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
// // /// Fetch pending payments API
// // Future<void> fetchPayments() async {
// //   try {
// //     final response = await http.get(
// //       Uri.parse("https://nahatasports.com/admin/feesmodule/pending"),
// //     );
// //
// //     if (response.statusCode == 200) {
// //       final data = jsonDecode(response.body);
// //       setState(() {
// //         payments = data; // assuming API returns a list
// //         isLoading = false;
// //       });
// //     } else {
// //       throw Exception("Failed to fetch payments");
// //     }
// //   } catch (e) {
// //     setState(() => isLoading = false);
// //     print("Error fetching payments: $e");
// //   }
// // }
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
//
// //
// //
// // class AdminDashboardScreen extends StatefulWidget {
// //   const AdminDashboardScreen({super.key});
// //
// //   @override
// //   State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
// // }
// //
// // class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
// //     static Widget _statCard(IconData icon, String value, String label, Color color) {
// //     return Expanded(
// //       child: Card(
// //         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
// //         child: Padding(
// //           padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
// //           child: Column(
// //             children: [
// //               Icon(icon, color: color, size: 28),
// //               const SizedBox(height: 6),
// //               Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
// //               const SizedBox(height: 4),
// //               Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
// //             ],
// //           ),
// //         ),
// //       ),
// //     );
// //   }
// //   // Sample raw data for payments
// //   final List<Map<String, dynamic>> payments = const [
// //     {
// //       "initialName": "Swanandi Kholkute",
// //       "initialId": 117,
// //       "initialDue": "2025-09-26",
// //       "initialAmount": "\$111.00",
// //       "initialCoach": "Coach Coach",
// //       "initialMarkedDate": "2025-08-25 12:33:16",
// //       "fullDetails": {
// //         "name": "Mike Wilson",
// //         "id": 107,
// //         "due": "2025-09-30",
// //         "amount": "\$150.00",
// //         "coach": "Coach Sarah",
// //         "markedDate": "2025-08-26 09:15:22",
// //         "approvedByAdmin": false,
// //         "gatePassIssued": false,
// //         "qrCode": "",
// //         "qrValidUntil": "",
// //         "paymentId": 5,
// //       },
// //     },
// //     {
// //       "initialName": "Sarah Davis",
// //       "initialId": 118,
// //       "initialDue": "2025-09-28",
// //       "initialAmount": "\$120.00",
// //       "initialCoach": "Coach Mike",
// //       "initialMarkedDate": "2025-08-25 13:27:41",
// //       "fullDetails": {
// //         "name": "Sarah Davis",
// //         "id": 118,
// //         "due": "2025-09-28",
// //         "amount": "\$120.00",
// //         "coach": "Coach Mike",
// //         "markedDate": "2025-08-25 13:27:41",
// //         "approvedByAdmin": true,
// //         "gatePassIssued": true,
// //         "qrCode": "XYZ789",
// //         "qrValidUntil": "2025-09-28 00:00:00",
// //         "paymentId": 6,
// //       },
// //     },
// //     {
// //       "initialName": "Lisa Chen",
// //       "initialId": 119,
// //       "initialDue": "2025-09-29",
// //       "initialAmount": "\$180.00",
// //       "initialCoach": "Coach Sarah",
// //       "initialMarkedDate": "2025-08-26 09:45:00",
// //       "fullDetails": {
// //         "name": "Lisa Chen",
// //         "id": 119,
// //         "due": "2025-09-29",
// //         "amount": "\$180.00",
// //         "coach": "Coach Sarah",
// //         "markedDate": "2025-08-26 09:45:00",
// //         "approvedByAdmin": false,
// //         "gatePassIssued": false,
// //         "qrCode": "",
// //         "qrValidUntil": "",
// //         "paymentId": 7,
// //       },
// //     },
// //   ];
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       appBar: AppBar(
// //         backgroundColor: Colors.white,
// //         elevation: 0,
// //         title: const Text(
// //           "Office Admin Dashboard",
// //           style: TextStyle(color: Colors.black),
// //         ),
// //         centerTitle: true,
// //       ),
// //       body: SingleChildScrollView(
// //         padding: const EdgeInsets.all(12),
// //         child: Column(
// //           crossAxisAlignment: CrossAxisAlignment.start,
// //           children: [
// //                           Card(
// //                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
// //                 child: const Padding(
// //                   padding: EdgeInsets.all(16),
// //                   child: Text(
// //                     "Review and confirm fee payments marked by coaches",
// //                     textAlign: TextAlign.center,
// //                     style: TextStyle(color: Colors.black54),
// //                   ),
// //                 ),
// //               ),
// //
// //               const SizedBox(height: 16),
// //
// //               // ---------- Stats Row ----------
// //               Row(
// //                 mainAxisAlignment: MainAxisAlignment.spaceAround,
// //                 children:  [
// //                   _statCard(Icons.access_time, "3", "Pending Confirmations", Colors.orange),
// //                   _statCard(Icons.check_circle, "12", "Confirmed Today", Colors.green),
// //                   _statCard(Icons.people, "156", "Total Students", Colors.blue),
// //                 ],
// //               ),
// //
// //               const SizedBox(height: 16),
// //
// //               // ---------- Search ----------
// //               Card(
// //                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
// //                 child: Padding(
// //                   padding: const EdgeInsets.all(12),
// //                   child: TextField(
// //                     decoration: InputDecoration(
// //                       prefixIcon: const Icon(Icons.search, color: Colors.black),
// //                       hintText: "Search by student name, sport, or coach...",
// //                       border: OutlineInputBorder(
// //                         borderRadius: BorderRadius.circular(8),
// //                         borderSide: BorderSide.none,
// //                       ),
// //                       filled: true,
// //                       fillColor: Colors.grey[200],
// //                     ),
// //                   ),
// //                 ),
// //               ),
// //
// //               const SizedBox(height: 16),
// //
// //             const SizedBox(height: 16),
// //             const Text(
// //               "Payments Awaiting Confirmation",
// //               style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
// //             ),
// //             const SizedBox(height: 8),
// //
// //             // Render all payment cards dynamically
// //             ...payments.map((p) => PaymentCard(
// //               initialName: p["initialName"],
// //               initialId: p["initialId"],
// //               initialDue: p["initialDue"],
// //               initialAmount: p["initialAmount"],
// //               initialCoach: p["initialCoach"],
// //               initialMarkedDate: p["initialMarkedDate"],
// //               fullDetails: p["fullDetails"],
// //             )),
// //           ],
// //         ),
// //       ),
// //     );
// //   }
// // }
// //
// // // ---------------- Stateful Payment Card ----------------
// //
// // class PaymentCard extends StatefulWidget {
// //   final String initialName;
// //   final int initialId;
// //   final String initialDue;
// //   final String initialAmount;
// //   final String initialCoach;
// //   final String initialMarkedDate;
// //   final Map<String, dynamic> fullDetails;
// //
// //   const PaymentCard({
// //     super.key,
// //     required this.initialName,
// //     required this.initialId,
// //     required this.initialDue,
// //     required this.initialAmount,
// //     required this.initialCoach,
// //     required this.initialMarkedDate,
// //     required this.fullDetails,
// //   });
// //
// //   @override
// //   State<PaymentCard> createState() => _PaymentCardState();
// // }
// //
// // class _PaymentCardState extends State<PaymentCard> {
// //   String status = "pending"; // pending / approved / rejected
// //   bool loading = false;
// //
// //   Future<void> approvePayment() async {
// //     setState(() => loading = true);
// //     final paymentId = widget.fullDetails["paymentId"];
// //     final url = "https://nahatasports.com/admin/feesmodule/approve/$paymentId";
// //
// //     try {
// //       final response = await http.post(Uri.parse(url));
// //       if (response.statusCode == 200) {
// //         setState(() {
// //           status = "approved";
// //           print(response.body);
// //           print("Payment approved successfully");
// //         });
// //       } else {
// //         showError("Failed to approve payment");
// //       }
// //     } catch (e) {
// //       showError(e.toString());
// //     } finally {
// //       setState(() => loading = false);
// //     }
// //   }
// //
// //   Future<void> rejectPayment() async {
// //     setState(() => loading = true);
// //     final paymentId = widget.fullDetails["paymentId"];
// //     final url = "https://nahatasports.com/admin/feesmodule/reject/$paymentId";
// //
// //     try {
// //       final response = await http.post(Uri.parse(url));
// //       if (response.statusCode == 200) {
// //         setState(() {
// //           status = "rejected";
// //           print(response.body);
// //           print("Payment rejected successfully");
// //         });
// //       } else {
// //         showError("Failed to reject payment");
// //       }
// //     } catch (e) {
// //       showError(e.toString());
// //     } finally {
// //       setState(() => loading = false);
// //     }
// //   }
// //
// //   void showError(String message) {
// //     ScaffoldMessenger.of(context).showSnackBar(
// //       SnackBar(content: Text(message)),
// //     );
// //   }
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     final name = (status == "approved") ? widget.fullDetails["name"] : widget.initialName;
// //     final id = (status == "approved") ? widget.fullDetails["id"] : widget.initialId;
// //     final due = (status == "approved") ? widget.fullDetails["due"] : widget.initialDue;
// //     final amount = (status == "approved") ? widget.fullDetails["amount"] : widget.initialAmount;
// //     final coach = (status == "approved") ? widget.fullDetails["coach"] : widget.initialCoach;
// //     final markedDate = (status == "approved") ? widget.fullDetails["markedDate"] : widget.initialMarkedDate;
// //     final approvedByAdmin = (status == "approved") ? widget.fullDetails["approvedByAdmin"] : false;
// //     final gatePassIssued = (status == "approved") ? widget.fullDetails["gatePassIssued"] : false;
// //     final qrCode = (status == "approved") ? widget.fullDetails["qrCode"] : "";
// //     final qrValidUntil = (status == "approved") ? widget.fullDetails["qrValidUntil"] : "";
// //
// //     return Card(
// //       margin: const EdgeInsets.symmetric(vertical: 8),
// //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
// //       child: Padding(
// //         padding: const EdgeInsets.all(12),
// //         child: Column(
// //           crossAxisAlignment: CrossAxisAlignment.start,
// //           children: [
// //             Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
// //             const Divider(height: 6, thickness: 1),
// //             Text("ID: $id • Due: $due", style: const TextStyle(color: Colors.black54)),
// //             Text(amount, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
// //             Text("Marked by $coach", style: const TextStyle(fontSize: 12)),
// //             Text("on $markedDate", style: const TextStyle(fontSize: 12, color: Colors.black54)),
// //             const SizedBox(height: 8),
// //
// //             if (loading) const CircularProgressIndicator(),
// //             if (!loading)
// //               if (status == "pending")
// //                 Row(
// //                   children: [
// //                     OutlinedButton(onPressed: rejectPayment, child: const Text("Reject", style: TextStyle(fontSize: 12))),
// //                     const SizedBox(width: 6),
// //                     ElevatedButton(onPressed: approvePayment, child: const Text("Approve", style: TextStyle(fontSize: 12))),
// //                   ],
// //                 )
// //               else if (status == "approved") ...[
// //                 if (approvedByAdmin)
// //                   Chip(label: const Text("Approved by Admin", style: TextStyle(fontSize: 12)), backgroundColor: Colors.green[100]),
// //                 if (gatePassIssued)
// //                   Chip(label: const Text("Gate Pass Issued", style: TextStyle(fontSize: 12)), backgroundColor: Colors.blue[100]),
// //                 Row(
// //                   children: [
// //                     const Icon(Icons.qr_code, size: 20),
// //                     const SizedBox(width: 6),
// //                     Column(
// //                       crossAxisAlignment: CrossAxisAlignment.start,
// //                       children: [
// //                         Text("QR Code: $qrCode", style: const TextStyle(fontSize: 12)),
// //                         Text("Valid until $qrValidUntil", style: const TextStyle(fontSize: 12, color: Colors.black54)),
// //                       ],
// //                     )
// //                   ],
// //                 ),
// //               ] else if (status == "rejected") ...[
// //                 Chip(label: const Text("Rejected by Admin", style: TextStyle(fontSize: 12)), backgroundColor: Colors.red[100]),
// //               ],
// //           ],
// //         ),
// //       ),
// //     );
// //   }
// // }
// //
// //
// //
// //
// //
// //
// //
// //
// //
//
// // class _PaymentCardState extends State<PaymentCard> {
// //   String status = "pending"; // pending / approved / rejected
// //
// //   void approve() {
// //     setState(() {
// //       status = "approved";
// //     });
// //     // TODO: call approve API here using widget.fullDetails["paymentId"]
// //   }
// //
// //   void reject() {
// //     setState(() {
// //       status = "rejected";
// //     });
// //     // TODO: call reject API here using widget.fullDetails["paymentId"]
// //   }
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     // Use fullDetails if approved, else use initial values
// //     final name = (status == "approved") ? widget.fullDetails["name"] : widget.initialName;
// //     final id = (status == "approved") ? widget.fullDetails["id"] : widget.initialId;
// //     final due = (status == "approved") ? widget.fullDetails["due"] : widget.initialDue;
// //     final amount = (status == "approved") ? widget.fullDetails["amount"] : widget.initialAmount;
// //     final coach = (status == "approved") ? widget.fullDetails["coach"] : widget.initialCoach;
// //     final markedDate = (status == "approved") ? widget.fullDetails["markedDate"] : widget.initialMarkedDate;
// //     final approvedByAdmin = (status == "approved") ? widget.fullDetails["approvedByAdmin"] : false;
// //     final gatePassIssued = (status == "approved") ? widget.fullDetails["gatePassIssued"] : false;
// //     final qrCode = (status == "approved") ? widget.fullDetails["qrCode"] : "";
// //     final qrValidUntil = (status == "approved") ? widget.fullDetails["qrValidUntil"] : "";
// //
// //     return Card(
// //       margin: const EdgeInsets.symmetric(vertical: 8),
// //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
// //       child: Padding(
// //         padding: const EdgeInsets.all(12),
// //         child: Column(
// //           crossAxisAlignment: CrossAxisAlignment.start,
// //           children: [
// //             Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
// //             const Divider(height: 6, thickness: 1),
// //             Text("ID: $id • Due: $due", style: const TextStyle(color: Colors.black54)),
// //             Text(amount, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
// //             Text("Marked by $coach", style: const TextStyle(fontSize: 12)),
// //             Text("on $markedDate", style: const TextStyle(fontSize: 12, color: Colors.black54)),
// //             const SizedBox(height: 8),
// //
// //             if (status == "pending")
// //               Row(
// //                 children: [
// //                   OutlinedButton(onPressed: reject, child: const Text("Reject", style: TextStyle(fontSize: 12))),
// //                   const SizedBox(width: 6),
// //                   ElevatedButton(onPressed: approve, child: const Text("Approve", style: TextStyle(fontSize: 12))),
// //                 ],
// //               )
// //             else if (status == "approved") ...[
// //               if (approvedByAdmin)
// //                 Chip(label: const Text("Approved by Admin", style: TextStyle(fontSize: 12)), backgroundColor: Colors.green[100]),
// //               if (gatePassIssued)
// //                 Chip(label: const Text("Gate Pass Issued", style: TextStyle(fontSize: 12)), backgroundColor: Colors.blue[100]),
// //               Row(
// //                 children: [
// //                   const Icon(Icons.qr_code, size: 20),
// //                   const SizedBox(width: 6),
// //                   Column(
// //                     crossAxisAlignment: CrossAxisAlignment.start,
// //                     children: [
// //                       Text("QR Code: $qrCode", style: const TextStyle(fontSize: 12)),
// //                       Text("Valid until $qrValidUntil", style: const TextStyle(fontSize: 12, color: Colors.black54)),
// //                     ],
// //                   )
// //                 ],
// //               ),
// //             ] else if (status == "rejected") ...[
// //               Chip(label: const Text("Rejected by Admin", style: TextStyle(fontSize: 12)), backgroundColor: Colors.red[100]),
// //             ],
// //           ],
// //         ),
// //       ),
// //     );
// //   }
// // }
//
//
//
//
//
//
//
// // /// Approve payment API
// // Future<void> approvePayment(int paymentId) async {
// //   try {
// //     final response = await http.get(
// //       Uri.parse("https://nahatasports.com/admin/feesmodule/approve/$paymentId"),
// //     );
// //
// //     if (response.statusCode == 200) {
// //       setState(() {
// //         // Mark approved in UI
// //         payments = payments.map((p) {
// //           if (p["id"] == paymentId) {
// //             p["approvedByAdmin"] = true;
// //           }
// //           return p;
// //         }).toList();
// //       });
// //     } else {
// //       print("Failed to approve: ${response.body}");
// //     }
// //   } catch (e) {
// //     print("Error approving payment: $e");
// //   }
// // }
// //
// // /// Reject payment API
// // Future<void> rejectPayment(int paymentId) async {
// //   try {
// //     final response = await http.get(
// //       Uri.parse("https://nahatasports.com/admin/feesmodule/reject/$paymentId"),
// //     );
// //
// //     if (response.statusCode == 200) {
// //       setState(() {
// //         // Mark rejected in UI
// //         payments = payments.map((p) {
// //           if (p["id"] == paymentId) {
// //             p["rejectedByAdmin"] = true;
// //           }
// //           return p;
// //         }).toList();
// //       });
// //     } else {
// //       print("Failed to reject: ${response.body}");
// //     }
// //   } catch (e) {
// //     print("Error rejecting payment: $e");
// //   }
// // }
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
//
//
//
//
//
// //admin@gmail.com
// //admin@gmail.com

//
//
//
//
//
//
// import 'dart:convert';
// import 'dart:typed_data';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
//
// class AdminDashboardScreen extends StatefulWidget {
//   const AdminDashboardScreen({super.key});
//
//   @override
//   State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
// }
// class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
//   List<dynamic> studentsData = [];
//   bool isLoading = true;
//
//
//
//   @override
//   void initState() {
//     super.initState();
//     fetchStudents();
//   }
//
//   Future<void> fetchStudents() async {
//     setState(() => isLoading = true);
//     try {
//       final res = await http.get(
//         Uri.parse('https://nahatasports.com/admin/api/fees'),
//       );
//       if (res.statusCode == 200) {
//         final data = jsonDecode(res.body);
//         if (data['status'] == true) {
//           setState(() {
//             studentsData = data['data'];
//             isLoading = false;
//             print(studentsData);
//           });
//         }
//       } else {
//         throw Exception('Failed to load data');
//       }
//     } catch (e) {
//       setState(() => isLoading = false);
//       print("Error fetching students: $e");
//     }
//   }
//   // Make this a helper that doesn't depend on instance state directly.
//   static Map<String, int> _calculateStats(List<dynamic> data) {
//     int pendingConfirmations = 0;
//     int confirmedToday = 0;
//     int total = data.length;
//
//     final now = DateTime.now();
//
//     for (final item in data) {
//       final fee = (item['fee'] ?? {}) as Map<String, dynamic>;
//       final adminStatus = (fee['admin_status'] ?? '').toString();
//       final paidDateRaw = fee['paid_date']?.toString();
//
//       if (adminStatus != 'approved') {
//         pendingConfirmations++;
//       }
//
//       if (adminStatus == 'approved' && paidDateRaw != null && paidDateRaw.isNotEmpty) {
//         // Be tolerant of "YYYY-MM-DD HH:mm:ss"
//         final paid = DateTime.tryParse(paidDateRaw.replaceFirst(' ', 'T'));
//         if (paid != null &&
//             paid.year == now.year &&
//             paid.month == now.month &&
//             paid.day == now.day) {
//           confirmedToday++;
//         }
//       }
//     }
//
//     return {
//       'pending': pendingConfirmations,
//       'confirmedToday': confirmedToday,
//       'total': total,
//     };
//   }
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
//               Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final stats = _calculateStats(studentsData); //
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         elevation: 0,
//         title: const Text("Office Admin Dashboard", style: TextStyle(color: Colors.black)),
//         centerTitle: true,
//         iconTheme: const IconThemeData(color: Colors.black),
//       ),
//       body: isLoading
//           ? const Center(child: CircularProgressIndicator())
//           : SingleChildScrollView(
//         padding: const EdgeInsets.all(12),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Card(
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//               child: const Padding(
//                 padding: EdgeInsets.all(16),
//                 child: Text(
//                   "Review and confirm fee payments marked by coaches",
//                   textAlign: TextAlign.center,
//                   style: TextStyle(color: Colors.black54),
//                 ),
//               ),
//             ),
//
//             const SizedBox(height: 16),
//
//             // ---------- Stats Row ----------
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceAround,
//               children: [
//                 _statCard(Icons.access_time, stats["pending"].toString(), "Pending Confirmations", Colors.orange),
//                 _statCard(Icons.check_circle, stats["confirmedToday"].toString(), "Confirmed Today", Colors.green),
//                 _statCard(Icons.people, stats["total"].toString(), "Total Students", Colors.blue),
//               ],
//             ),
//
//             const SizedBox(height: 16),
//
//             // ---------- Search ----------
//             Card(
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//               child: Padding(
//                 padding: const EdgeInsets.all(12),
//                 child: TextField(
//                   decoration: InputDecoration(
//                     prefixIcon: const Icon(Icons.search, color: Colors.black),
//                     hintText: "Search by student name, sport, or coach...",
//                     border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(8),
//                       borderSide: BorderSide.none,
//                     ),
//                     filled: true,
//                     fillColor: Colors.grey[200],
//                   ),
//                 ),
//               ),
//             ),
//
//             const SizedBox(height: 16),
//             const Text(
//               "Payments Awaiting Confirmation",
//               style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 8),
//             ...studentsData.map((item) {
//               final student = item['student'];
//               final fee = item['fee'];
//               final gatePass = item['gatePass'];
//
//               return _paymentCard(
//                 name: student['name'] ?? '',
//                 id: int.tryParse(student['id'] ?? '0') ?? 0,
//                 due: fee['next_due_date'] ?? '',
//                 amount: "\$${fee['amount'] ?? '0'}",
//                 coach: item['coachName'] ?? '',
//                 markedDate: fee['paid_date'] ?? '',
//                 approvedByAdmin: fee['admin_status'] == 'approved',
//                 gatePassIssued: gatePass != null && gatePass['status'] == 'active',
//                 qrCode: gatePass != null ? gatePass['qr_code'] : '',
//                 qrValidUntil: gatePass != null ? gatePass['valid_until'] : '',
//                 paymentId: int.tryParse(fee['id'] ?? '0') ?? 0,
//                 onStatusChanged: fetchStudents,
//               );
//             }).toList(),
//           ],
//         ),
//       ),
//     );
//
//   }
//
//   // ---------------- Payment Card -----------------
//
//
// // inside _paymentCard
//   Widget _paymentCard({
//     required String name,
//     required int id,
//     required String due,
//     required String amount,
//     required String coach,
//     required String markedDate,
//     required bool approvedByAdmin,
//     required bool gatePassIssued,
//     required String qrCode,
//     required String qrValidUntil,
//     required int paymentId,
//     required VoidCallback onStatusChanged,
//   }) {
//     return StatefulBuilder(
//       builder: (context, setState) {
//         String status = approvedByAdmin ? "approved" : "pending";
//         bool localGatePass = gatePassIssued;
//         String localQr = qrCode;
//         String localValidUntil = qrValidUntil;
//
//         Uint8List? qrImageBytes;
//         if (localQr.startsWith("data:image")) {
//           final base64Str = localQr.split(',').last;
//           qrImageBytes = base64Decode(base64Str);
//         }
//
//         Future<void> approve() async {
//           setState(() => status = "loading");
//           try {
//             final res = await http.post(
//               Uri.parse("https://nahatasports.com/fees/approve/$paymentId"),
//               headers: {"Content-Type": "application/json"},
//               body: jsonEncode({"feeId": paymentId}),
//             );
//             print("Approve Response: ${res.body}"); // print response
//             final response = jsonDecode(res.body);
//             if (response['status'] == true) {
//               setState(() {
//                 status = "approved";
//                 localGatePass = response['pass']?['status'] == 'active';
//                 localQr = response['pass']?['qr_code'] ?? '';
//                 localValidUntil = response['pass']?['valid_until'] ?? '';
//                 if (localQr.startsWith("data:image")) {
//                   final base64Str = localQr.split(',').last;
//                   qrImageBytes = base64Decode(base64Str);
//                 }
//               });
//               onStatusChanged();
//               ScaffoldMessenger.of(context).showSnackBar(
//                 SnackBar(content: Text(response['message'] ?? "Approved!")),
//               );
//             } else {
//               setState(() => status = "pending");
//               ScaffoldMessenger.of(context).showSnackBar(
//                 SnackBar(content: Text("Failed: ${response['message']}")),
//               );
//             }
//           } catch (e) {
//             setState(() => status = "pending");
//             ScaffoldMessenger.of(context).showSnackBar(
//               SnackBar(content: Text("Error: $e")),
//             );
//           }
//         }
//
//         Future<void> reject() async {
//           setState(() => status = "loading");
//           try {
//             final res = await http.post(
//               Uri.parse("https://nahatasports.com/fees/reject/$paymentId"),
//               headers: {"Content-Type": "application/json"},
//               body: jsonEncode({"feeId": paymentId}),
//             );
//             print("Reject Response: ${res.body}"); // print response
//             final response = jsonDecode(res.body);
//             if (response['status'] == true) {
//               setState(() => status = "rejected");
//               onStatusChanged();
//               ScaffoldMessenger.of(context).showSnackBar(
//                 SnackBar(content: Text(response['message'] ?? "Rejected!")),
//               );
//             } else {
//               setState(() => status = "pending");
//               ScaffoldMessenger.of(context).showSnackBar(
//                 SnackBar(content: Text("Failed: ${response['message']}")),
//               );
//             }
//           } catch (e) {
//             setState(() => status = "pending");
//             ScaffoldMessenger.of(context).showSnackBar(
//               SnackBar(content: Text("Error: $e")),
//             );
//           }
//         }
//
//         return Card(
//           margin: const EdgeInsets.symmetric(vertical: 8),
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//           child: Padding(
//             padding: const EdgeInsets.all(12),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
//                 const Divider(height: 6, thickness: 1),
//                 Text("ID: $id • Due: $due", style: const TextStyle(color: Colors.black54)),
//                 Text(amount, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
//                 Text("Marked by $coach", style: const TextStyle(fontSize: 12)),
//                 Text("on $markedDate", style: const TextStyle(fontSize: 12, color: Colors.black54)),
//                 const SizedBox(height: 8),
//
//                 if (status == "pending")
//                   Row(
//                     children: [
//                       OutlinedButton(onPressed: reject, child: const Text("Reject", style: TextStyle(fontSize: 12))),
//                       const SizedBox(width: 6),
//                       ElevatedButton(onPressed: approve, child: const Text("Approve", style: TextStyle(fontSize: 12))),
//                     ],
//                   )
//                 else if (status == "approved") ...[
//                   if (approvedByAdmin || localGatePass)
//                     Chip(label: const Text("Approved by Admin", style: TextStyle(fontSize: 12)), backgroundColor: Colors.green[100]),
//                   if (localGatePass)
//                     Chip(label: const Text("Gate Pass Issued", style: TextStyle(fontSize: 12)), backgroundColor: Colors.blue[100]),
//                   const SizedBox(height: 8),
//                   if (qrImageBytes != null)
//                     Image.memory(qrImageBytes!, width: 100, height: 100),
//                   if (localValidUntil.isNotEmpty)
//                     Text("Valid until $localValidUntil", style: const TextStyle(fontSize: 12, color: Colors.black54)),
//                 ] else if (status == "rejected") ...[
//                   Chip(label: const Text("Rejected by Admin", style: TextStyle(fontSize: 12)), backgroundColor: Colors.red[100]),
//                 ] else if (status == "loading") ...[
//                   const Center(child: CircularProgressIndicator()),
//                 ],
//               ],
//             ),
//           ),
//         );
//       },
//     );
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
//
//
//

// Widget _paymentCard({
//   required String name,
//   required int id,
//   required String due,
//   required String amount,
//   required String coach,
//   required String markedDate,
//   required bool approvedByAdmin,
//   required bool gatePassIssued,
//   required String qrCode,
//   required String qrValidUntil,
//   required int paymentId,
//   required VoidCallback onStatusChanged,
// }) {
//   return StatefulBuilder(
//     builder: (context, setState) {
//       String status = approvedByAdmin ? "approved" : "pending";
//       String localQr = qrCode;
//       String localValidUntil = qrValidUntil;
//       bool localGatePass = gatePassIssued;
//
//       Future<void> approve() async {
//         try {
//           final res = await http.get(Uri.parse("https://nahatasports.com/fees/approve/$paymentId"));
//           if (res.statusCode == 200) {
//             final response = jsonDecode(res.body);
//             if (response['status'] == true) {
//               setState(() {
//                 status = "approved";
//                 localGatePass = response['pass']?['status'] == 'active';
//                 localQr = response['pass']?['qr_code'] ?? '';
//                 localValidUntil = response['pass']?['valid_until'] ?? '';
//                 print(response['pass']);
//               });
//               onStatusChanged();
//               ScaffoldMessenger.of(context).showSnackBar(
//                 SnackBar(content: Text(response['message'] ?? "Approved!")),
//               );
//             } else {
//               ScaffoldMessenger.of(context).showSnackBar(
//                 SnackBar(content: Text("Failed: ${response['message']}")),
//               );
//             }
//           }
//         } catch (e) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text("Error approving: $e")),
//           );
//         }
//       }
//
//       Future<void> reject() async {
//         try {
//           final res = await http.get(Uri.parse("https://nahatasports.com/fees/reject/$paymentId"));
//           if (res.statusCode == 200) {
//             final response = jsonDecode(res.body);
//             if (response['status'] == true) {
//               setState(() {
//                 status = "rejected";
//                 print(response['pass']);
//               });
//               onStatusChanged();
//               ScaffoldMessenger.of(context).showSnackBar(
//                 SnackBar(content: Text(response['message'] ?? "Rejected!")),
//               );
//             } else {
//               ScaffoldMessenger.of(context).showSnackBar(
//                 SnackBar(content: Text("Failed: ${response['message']}")),
//               );
//             }
//           }
//         } catch (e) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text("Error rejecting: $e")),
//           );
//         }
//       }
//       Uint8List? qrImageBytes;
//       if (localQr.startsWith("data:image")) {
//         try {
//           final base64Str = localQr.split(',')[1];
//           qrImageBytes = base64Decode(base64Str);
//         } catch (e) {
//           print("Error decoding QR: $e");
//         }
//       }
//       return Card(
//         margin: const EdgeInsets.symmetric(vertical: 8),
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//         child: Padding(
//           padding: const EdgeInsets.all(12),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
//               const Divider(height: 6, thickness: 1),
//               Text("ID: $id • Due: $due", style: const TextStyle(color: Colors.black54)),
//               Text(amount, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
//               Text("Marked by $coach", style: const TextStyle(fontSize: 12)),
//               Text("on $markedDate", style: const TextStyle(fontSize: 12, color: Colors.black54)),
//
//               const SizedBox(height: 8),
//               if (status == "pending")
//                 Row(
//                   children: [
//                     OutlinedButton(onPressed: reject, child: const Text("Reject", style: TextStyle(fontSize: 12))),
//                     const SizedBox(width: 6),
//                     ElevatedButton(onPressed: approve, child: const Text("Approve", style: TextStyle(fontSize: 12))),
//                   ],
//                 )
//               else if (status == "approved") ...[
//                 Chip(label: const Text("Approved by Admin", style: TextStyle(fontSize: 12)), backgroundColor: Colors.green[100]),
//                 if (localGatePass)
//                   Chip(label: const Text("Gate Pass Issued", style: TextStyle(fontSize: 12)), backgroundColor: Colors.blue[100]),
//                 const SizedBox(height: 8),
//                 if (qrImageBytes != null)
//                   Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Image.memory(qrImageBytes, width: 120, height: 120),
//                       const SizedBox(height: 4),
//                       Text("Valid until $localValidUntil", style: const TextStyle(fontSize: 12, color: Colors.black54)),
//                     ],
//                   ),
//               ] else if (status == "rejected") ...[
//                 Chip(label: const Text("Rejected by Admin", style: TextStyle(fontSize: 12)), backgroundColor: Colors.red[100]),
//               ],
//             ],
//           ),
//         ),
//       );
//     },
//   );
// }
// }

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../auth/login.dart';
import '../screens/login_screen.dart';

// class AdminDashboardScreen extends StatefulWidget {
//   const AdminDashboardScreen({super.key});
//
//   @override
//   State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
// }
//
// class _AdminDashboardScreenState extends State<AdminDashboardScreen>
//     with SingleTickerProviderStateMixin {
//   List<dynamic> studentsData = [];
//   List<dynamic> filteredStudentsData = []; // For search functionality
//   bool isLoading = true;
//   String searchQuery = ""; // Track search input
//
//   // Pagination / lazy loading
//   final ScrollController _scrollController = ScrollController();
//   final int pageSize = 10; // Number of items to load per batch
//   int loadedItems = 0; // Number of items currently visible
//   bool isLoadingMore = false;
//   int currentPage = 1;
//
//   int totalPages = 1;
//   late AnimationController _controller;
//   late Animation<double> _fadeAnimation;
//   final TextEditingController _searchController = TextEditingController();
//
//   @override
//   void initState() {
//     super.initState();
//     fetchStudents();
//
//     _controller = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 600),
//     );
//     _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
//
//     _scrollController.addListener(() {
//       if (_scrollController.position.pixels >=
//           _scrollController.position.maxScrollExtent - 200 &&
//           !isLoadingMore &&
//           loadedItems < filteredStudentsData.length) {
//         loadMoreItems();
//       }
//     });
//   }
//
//   @override
//   void dispose() {
//     _controller.dispose();
//     _searchController.dispose();
//     _scrollController.dispose();
//     super.dispose();
//   }
//
//   Future<void> fetchStudents() async {
//     setState(() => isLoading = true);
//     try {
//       final res = await http.get(
//         Uri.parse('https://nahatasports.com/admin/api/fees'),
//       );
//       if (res.statusCode == 200) {
//         final data = jsonDecode(res.body);
//         if (data['status'] == true) {
//           setState(() {
//             studentsData = data['data'];
//             filteredStudentsData = data['data']; // Initialize filtered data
//             totalPages = (filteredStudentsData.length / pageSize).ceil();
//             isLoading = false;
//             _controller.forward();
//           });
//         }
//       } else {
//         throw Exception('Failed to load data');
//       }
//     } catch (e) {
//       setState(() => isLoading = false);
//       debugPrint("Error fetching students: $e");
//     }
//   }
//
//   void loadMoreItems() {
//     setState(() => isLoadingMore = true);
//     Future.delayed(const Duration(milliseconds: 300), () {
//       setState(() {
//         final remaining = filteredStudentsData.length - loadedItems;
//         loadedItems += remaining >= pageSize ? pageSize : remaining;
//         isLoadingMore = false;
//       });
//     });
//   }
//
//   List<dynamic> get visibleStudents =>
//       filteredStudentsData.take(loadedItems).toList();
//
//   void _filterStudents(String query) {
//     setState(() {
//       searchQuery = query;
//       if (query.isEmpty) {
//         filteredStudentsData = studentsData;
//       } else {
//         filteredStudentsData = studentsData.where((item) {
//           final student = item['student'] ?? {};
//           final studentName = (student['name'] ?? '').toString().toLowerCase();
//           final coachName = (item['coachName'] ?? '').toString().toLowerCase();
//           final sport = (student['sport'] ?? '').toString().toLowerCase();
//           final searchLower = query.toLowerCase();
//
//           return studentName.contains(searchLower) ||
//               coachName.contains(searchLower) ||
//               sport.contains(searchLower);
//         }).toList();
//       }
//
//       // Reset loaded items on search
//       currentPage = 1;
//       totalPages = (filteredStudentsData.length / pageSize).ceil();
//     });
//   }
//
//   static Map<String, int> _calculateStats(List<dynamic> data) {
//     int pendingConfirmations = 0;
//     int confirmedToday = 0;
//     int total = data.length;
//
//     final now = DateTime.now();
//
//     for (final item in data) {
//       final fee = (item['fee'] ?? {}) as Map<String, dynamic>;
//       final adminStatus = (fee['admin_status'] ?? '').toString();
//       final paidDateRaw = fee['paid_date']?.toString();
//
//       if (adminStatus != 'approved') {
//         pendingConfirmations++;
//       }
//
//       if (adminStatus == 'approved' &&
//           paidDateRaw != null &&
//           paidDateRaw.isNotEmpty) {
//         final paid = DateTime.tryParse(paidDateRaw.replaceFirst(' ', 'T'));
//         if (paid != null &&
//             paid.year == now.year &&
//             paid.month == now.month &&
//             paid.day == now.day) {
//           confirmedToday++;
//         }
//       }
//     }
//
//     return {
//       'pending': pendingConfirmations,
//       'confirmedToday': confirmedToday,
//       'total': total,
//     };
//   }
//
//   static Widget _statCard(IconData icon, String value, String label, Color color) {
//     return Card(
//       elevation: 4,
//       shadowColor: color.withOpacity(0.4),
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       child: Padding(
//         padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
//         child: Column(
//           children: [
//             Icon(icon, color: color, size: 32),
//             const SizedBox(height: 8),
//             Text(
//               value,
//               style: TextStyle(
//                 fontSize: 20,
//                 fontWeight: FontWeight.bold,
//                 color: color,
//               ),
//             ),
//             const SizedBox(height: 4),
//             Text(
//               label,
//               textAlign: TextAlign.center,
//               style: const TextStyle(fontSize: 13, color: Colors.black87),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//   List<dynamic> get paginatedStudents {
//     final start = (currentPage - 1) * pageSize;
//     final end = (start + pageSize) > filteredStudentsData.length
//         ? filteredStudentsData.length
//         : start + pageSize;
//     return filteredStudentsData.sublist(start, end);
//   }
//
//   Widget _paginationControls() {
//     List<Widget> pages = [];
//
//     // Previous Button
//     pages.add(
//       IconButton(
//         icon: const Icon(Icons.arrow_back),
//         onPressed: currentPage > 1
//             ? () => setState(() => currentPage--)
//             : null,
//       ),
//     );
//     for (int i = 1; i <= totalPages; i++) {
//       pages.add(
//         GestureDetector(
//           onTap: () {
//             setState(() => currentPage = i);
//           },
//           child: Container(
//             margin: const EdgeInsets.symmetric(horizontal: 4),
//             padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
//             decoration: BoxDecoration(
//               color: currentPage == i ? Colors.blue : Colors.white,
//               borderRadius: BorderRadius.circular(8),
//               border: Border.all(color: Colors.blue),
//             ),
//             child: Text(
//               "$i",
//               style: TextStyle(
//                 color: currentPage == i ? Colors.white : Colors.blue,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//           ),
//         ),
//       );
//     }
//     pages.add(
//       IconButton(
//         icon: const Icon(Icons.arrow_forward),
//         onPressed: currentPage < totalPages
//             ? () => setState(() => currentPage++)
//             : null,
//       ),
//     );
//
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: pages,
//     );
//   }
//   @override
//   Widget build(BuildContext context) {
//     final stats = _calculateStats(studentsData);
//
//     return SafeArea(
//       child: Scaffold(
//         backgroundColor: Colors.grey[100],
//         appBar: AppBar(
//           backgroundColor: const Color(0xFF0A198D),
//           elevation: 0,
//           leading: IconButton(
//             icon: const Icon(Icons.arrow_back, color: Colors.white),
//             onPressed: () {
//               Navigator.pushReplacement(
//                 context,
//                 MaterialPageRoute(
//                   builder: (_) => LoginScreen(),
//                 ),
//               );
//             },
//           ),
//           title: const Text(
//             "Office Admin Dashboard",
//             style: TextStyle(
//               color: Colors.white,
//               fontWeight: FontWeight.bold,
//               fontSize: 20,
//             ),
//           ),
//           centerTitle: true,
//         ),
//         body: isLoading
//             ? const Center(child: CircularProgressIndicator())
//             : FadeTransition(
//           opacity: _fadeAnimation,
//           child: SingleChildScrollView(
//             controller: _scrollController,
//             padding: const EdgeInsets.all(16),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 // --- Info Card ---
//                 Card(
//                   color: Colors.indigo[50],
//                   elevation: 2,
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(16),
//                   ),
//                   child: const Padding(
//                     padding: EdgeInsets.all(18),
//                     child: Text(
//                       "Review and confirm fee payments marked by coaches",
//                       textAlign: TextAlign.center,
//                       style: TextStyle(color: Colors.black87, fontSize: 14),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 16),
//                 // --- Stats Cards ---
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Expanded(
//                       child: _statCard(
//                         Icons.access_time,
//                         stats["pending"].toString(),
//                         "Pending",
//                         Colors.orange,
//                       ),
//                     ),
//                     const SizedBox(width: 12),
//                     Expanded(
//                       child: _statCard(
//                         Icons.check_circle,
//                         stats["confirmedToday"].toString(),
//                         "Confirmed Today",
//                         Colors.green,
//                       ),
//                     ),
//                     const SizedBox(width: 12),
//                     Expanded(
//                       child: _statCard(
//                         Icons.people,
//                         stats["total"].toString(),
//                         "Total Students",
//                         Colors.blue,
//                       ),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 20),
//                 // --- Search Bar ---
//                 TextField(
//                   controller: _searchController,
//                   onChanged: _filterStudents,
//                   decoration: InputDecoration(
//                     prefixIcon: const Icon(Icons.search, color: Colors.black54),
//                     suffixIcon: searchQuery.isNotEmpty
//                         ? IconButton(
//                       icon: const Icon(Icons.clear),
//                       onPressed: () {
//                         _searchController.clear();
//                         _filterStudents("");
//                       },
//                     )
//                         : null,
//                     hintText: "Search by student name, sport, or coach...",
//                     filled: true,
//                     fillColor: Colors.white,
//                     contentPadding:
//                     const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
//                     border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(14),
//                       borderSide: BorderSide.none,
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 20),
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Text(
//                       searchQuery.isEmpty
//                           ? "Payments Awaiting Confirmation"
//                           : "Search Results",
//                       style: const TextStyle(
//                         fontSize: 17,
//                         fontWeight: FontWeight.bold,
//                         color: Colors.black87,
//                       ),
//                     ),
//                     if (searchQuery.isNotEmpty)
//                       Text(
//                         "${filteredStudentsData.length} result${filteredStudentsData.length != 1 ? 's' : ''}",
//                         style: const TextStyle(
//                           fontSize: 14,
//                           color: Colors.black54,
//                         ),
//                       ),
//                   ],
//                 ),
//                 const SizedBox(height: 10),
//                 if (filteredStudentsData.isEmpty && searchQuery.isNotEmpty) ...[
//                   Center(
//                     child: Padding(
//                       padding: const EdgeInsets.symmetric(vertical: 40),
//                       child: Column(
//                         children: [
//                           Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
//                           const SizedBox(height: 16),
//                           Text(
//                             "No results found for '$searchQuery'",
//                             style: TextStyle(fontSize: 16, color: Colors.grey[600]),
//                           ),
//                           const SizedBox(height: 8),
//                           Text(
//                             "Try searching with a different term",
//                             style: TextStyle(fontSize: 14, color: Colors.grey[500]),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ],
//                 // --- Payment Cards ---
//                 ...paginatedStudents.asMap().entries.map((entry) {
//                   final index = entry.key;
//                   final item = entry.value;
//                   final student = item['student'];
//                   final fee = item['fee'];
//                   final gatePass = item['gatePass'];
//
//                   return AnimatedSlide(
//                     duration: Duration(milliseconds: 300 + (index * 100)),
//                     curve: Curves.easeOut,
//                     offset: const Offset(0, 0),
//                     child: AnimatedOpacity(
//                       duration: Duration(milliseconds: 400 + (index * 100)),
//                       opacity: 1,
//                       child: _paymentCard(
//                         name: student['name'] ?? '',
//                         id: int.tryParse(student['id'] ?? '0') ?? 0,
//                         due: fee['next_due_date'] ?? '',
//                         amount: "${fee['amount'] ?? '0'}",
//                         coach: item['coachName'] ?? '',
//                         markedDate: fee['paid_date'] ?? '',
//                         approvedByAdmin: fee['admin_status'] == 'approved',
//                         gatePassIssued:
//                         gatePass != null && gatePass['status'] == 'active',
//                         qrCode: gatePass != null ? gatePass['qr_code'] : '',
//                         qrValidUntil: gatePass != null ? gatePass['valid_until'] : '',
//                         paymentId: int.tryParse(fee['id'] ?? '0') ?? 0,
//                         onStatusChanged: () {
//                           fetchStudents();
//                           if (searchQuery.isNotEmpty) _filterStudents(searchQuery);
//                         },
//                       ),
//                     ),
//                   );
//                 }).toList(),
//                 const SizedBox(height: 16),
//                 // Pagination controls
//                 if (totalPages > 1) _paginationControls(),
//                 // if (isLoadingMore)
//                 //   const Padding(
//                 //     padding: EdgeInsets.symmetric(vertical: 16),
//                 //     child: Center(child: CircularProgressIndicator()),
//                 //   ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// //
// // class AdminDashboardScreen extends StatefulWidget {
// //   const AdminDashboardScreen({super.key});
// //
// //   @override
// //   State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
// // }
// // class _AdminDashboardScreenState extends State<AdminDashboardScreen>
// //     with SingleTickerProviderStateMixin {
// //   List<dynamic> studentsData = [];
// //   List<dynamic> filteredStudentsData = []; // For search functionality
// //   bool isLoading = true;
// //   String searchQuery = ""; // Track search input
// //
// //   late AnimationController _controller;
// //   late Animation<double> _fadeAnimation;
// //   final TextEditingController _searchController = TextEditingController();
// //
// //   @override
// //   void initState() {
// //     super.initState();
// //     fetchStudents();
// //
// //     _controller = AnimationController(
// //       vsync: this,
// //       duration: const Duration(milliseconds: 600),
// //     );
// //     _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
// //   }
// //
// //   @override
// //   void dispose() {
// //     _controller.dispose();
// //     _searchController.dispose();
// //     super.dispose();
// //   }
// //
// //   Future<void> fetchStudents() async {
// //     setState(() => isLoading = true);
// //     try {
// //       final res = await http.get(
// //         Uri.parse('https://nahatasports.com/admin/api/fees'),
// //       );
// //       if (res.statusCode == 200) {
// //         final data = jsonDecode(res.body);
// //         if (data['status'] == true) {
// //           setState(() {
// //             studentsData = data['data'];
// //             filteredStudentsData = data['data']; // Initialize filtered data
// //             isLoading = false;
// //             _controller.forward(); // trigger animations when data loads
// //           });
// //         }
// //       } else {
// //         throw Exception('Failed to load data');
// //       }
// //     } catch (e) {
// //       setState(() => isLoading = false);
// //       debugPrint("Error fetching students: $e");
// //     }
// //   }
// //
// //   // Search functionality
// //   void _filterStudents(String query) {
// //     setState(() {
// //       searchQuery = query;
// //       if (query.isEmpty) {
// //         filteredStudentsData = studentsData;
// //       } else {
// //         filteredStudentsData = studentsData.where((item) {
// //           final student = item['student'] ?? {};
// //           final studentName = (student['name'] ?? '').toString().toLowerCase();
// //           final coachName = (item['coachName'] ?? '').toString().toLowerCase();
// //           final sport = (student['sport'] ?? '').toString().toLowerCase();
// //           final searchLower = query.toLowerCase();
// //
// //           return studentName.contains(searchLower) ||
// //               coachName.contains(searchLower) ||
// //               sport.contains(searchLower);
// //         }).toList();
// //       }
// //     });
// //   }
// //
// //   static Map<String, int> _calculateStats(List<dynamic> data) {
// //     int pendingConfirmations = 0;
// //     int confirmedToday = 0;
// //     int total = data.length;
// //
// //     final now = DateTime.now();
// //
// //     for (final item in data) {
// //       final fee = (item['fee'] ?? {}) as Map<String, dynamic>;
// //       final adminStatus = (fee['admin_status'] ?? '').toString();
// //       final paidDateRaw = fee['paid_date']?.toString();
// //
// //       if (adminStatus != 'approved') {
// //         pendingConfirmations++;
// //       }
// //
// //       if (adminStatus == 'approved' &&
// //           paidDateRaw != null &&
// //           paidDateRaw.isNotEmpty) {
// //         final paid = DateTime.tryParse(paidDateRaw.replaceFirst(' ', 'T'));
// //         if (paid != null &&
// //             paid.year == now.year &&
// //             paid.month == now.month &&
// //             paid.day == now.day) {
// //           confirmedToday++;
// //         }
// //       }
// //     }
// //
// //     return {
// //       'pending': pendingConfirmations,
// //       'confirmedToday': confirmedToday,
// //       'total': total,
// //     };
// //   }
// //
// //   static Widget _statCard(
// //       IconData icon,
// //       String value,
// //       String label,
// //       Color color,
// //       ) {
// //     return Card(
// //       elevation: 4,
// //       shadowColor: color.withOpacity(0.4),
// //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
// //       child: Padding(
// //         padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
// //         child: Column(
// //           children: [
// //             Icon(icon, color: color, size: 32),
// //             const SizedBox(height: 8),
// //             Text(
// //               value,
// //               style: TextStyle(
// //                 fontSize: 20,
// //                 fontWeight: FontWeight.bold,
// //                 color: color,
// //               ),
// //             ),
// //             const SizedBox(height: 4),
// //             Text(
// //               label,
// //               textAlign: TextAlign.center,
// //               style: const TextStyle(fontSize: 13, color: Colors.black87),
// //             ),
// //           ],
// //         ),
// //       ),
// //     );
// //   }
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     // Calculate stats from original data, not filtered data
// //     final stats = _calculateStats(studentsData);
// //
// //     return SafeArea(
// //       child: Scaffold(
// //         backgroundColor: Colors.grey[100],
// //         appBar: AppBar(
// //           backgroundColor: Color(0xFF0A198D),
// //           elevation: 0,
// //           leading: IconButton(
// //             icon: Icon(Icons.arrow_back, color: Colors.white),
// //             onPressed: () {
// //               Navigator.pushReplacement(
// //                 context,
// //                 MaterialPageRoute(
// //                   builder: (_) => LoginScreen(),
// //                 ), // or any other screen
// //               );
// //             },
// //           ),
// //           title: Text(
// //             "Office Admin Dashboard",
// //             style: TextStyle(
// //               color: Colors.white,
// //               fontWeight: FontWeight.bold,
// //               fontSize: 20,
// //             ),
// //           ),
// //           centerTitle: true,
// //         ),
// //
// //         body: isLoading
// //             ? const Center(child: CircularProgressIndicator())
// //             : FadeTransition(
// //           opacity: _fadeAnimation,
// //           child: SingleChildScrollView(
// //             padding: const EdgeInsets.all(16),
// //             child: Column(
// //               crossAxisAlignment: CrossAxisAlignment.start,
// //               children: [
// //                 // --- Info Card ---
// //                 Card(
// //                   color: Colors.indigo[50],
// //                   elevation: 2,
// //                   shape: RoundedRectangleBorder(
// //                     borderRadius: BorderRadius.circular(16),
// //                   ),
// //                   child: const Padding(
// //                     padding: EdgeInsets.all(18),
// //                     child: Text(
// //                       "Review and confirm fee payments marked by coaches",
// //                       textAlign: TextAlign.center,
// //                       style: TextStyle(color: Colors.black87, fontSize: 14),
// //                     ),
// //                   ),
// //                 ),
// //
// //                 const SizedBox(height: 16),
// //
// //                 // --- Stats Cards ---
// //                 Row(
// //                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
// //                   children: [
// //                     Expanded(
// //                       child: _statCard(
// //                         Icons.access_time,
// //                         stats["pending"].toString(),
// //                         "Pending",
// //                         Colors.orange,
// //                       ),
// //                     ),
// //                     const SizedBox(width: 12),
// //                     Expanded(
// //                       child: _statCard(
// //                         Icons.check_circle,
// //                         stats["confirmedToday"].toString(),
// //                         "Confirmed Today",
// //                         Colors.green,
// //                       ),
// //                     ),
// //                     const SizedBox(width: 12),
// //                     Expanded(
// //                       child: _statCard(
// //                         Icons.people,
// //                         stats["total"].toString(),
// //                         "Total Students",
// //                         Colors.blue,
// //                       ),
// //                     ),
// //                   ],
// //                 ),
// //
// //                 const SizedBox(height: 20),
// //
// //                 // --- Working Search Bar ---
// //                 TextField(
// //                   controller: _searchController,
// //                   onChanged: _filterStudents,
// //                   decoration: InputDecoration(
// //                     prefixIcon: const Icon(
// //                       Icons.search,
// //                       color: Colors.black54,
// //                     ),
// //                     suffixIcon: searchQuery.isNotEmpty
// //                         ? IconButton(
// //                       icon: const Icon(Icons.clear),
// //                       onPressed: () {
// //                         _searchController.clear();
// //                         _filterStudents("");
// //                       },
// //                     )
// //                         : null,
// //                     hintText: "Search by student name, sport, or coach...",
// //                     filled: true,
// //                     fillColor: Colors.white,
// //                     contentPadding: const EdgeInsets.symmetric(
// //                       vertical: 0,
// //                       horizontal: 12,
// //                     ),
// //                     border: OutlineInputBorder(
// //                       borderRadius: BorderRadius.circular(14),
// //                       borderSide: BorderSide.none,
// //                     ),
// //                   ),
// //                 ),
// //
// //                 const SizedBox(height: 20),
// //
// //                 // Show search results info
// //                 Row(
// //                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
// //                   children: [
// //                     Text(
// //                       searchQuery.isEmpty
// //                           ? "Payments Awaiting Confirmation"
// //                           : "Search Results",
// //                       style: const TextStyle(
// //                         fontSize: 17,
// //                         fontWeight: FontWeight.bold,
// //                         color: Colors.black87,
// //                       ),
// //                     ),
// //                     if (searchQuery.isNotEmpty)
// //                       Text(
// //                         "${filteredStudentsData.length} result${filteredStudentsData.length != 1 ? 's' : ''}",
// //                         style: const TextStyle(
// //                           fontSize: 14,
// //                           color: Colors.black54,
// //                         ),
// //                       ),
// //                   ],
// //                 ),
// //                 const SizedBox(height: 10),
// //
// //                 // Show message if no results found
// //                 if (filteredStudentsData.isEmpty && searchQuery.isNotEmpty) ...[
// //                   Center(
// //                     child: Padding(
// //                       padding: const EdgeInsets.symmetric(vertical: 40),
// //                       child: Column(
// //                         children: [
// //                           Icon(
// //                             Icons.search_off,
// //                             size: 64,
// //                             color: Colors.grey[400],
// //                           ),
// //                           const SizedBox(height: 16),
// //                           Text(
// //                             "No results found for '$searchQuery'",
// //                             style: TextStyle(
// //                               fontSize: 16,
// //                               color: Colors.grey[600],
// //                             ),
// //                           ),
// //                           const SizedBox(height: 8),
// //                           Text(
// //                             "Try searching with a different term",
// //                             style: TextStyle(
// //                               fontSize: 14,
// //                               color: Colors.grey[500],
// //                             ),
// //                           ),
// //                         ],
// //                       ),
// //                     ),
// //                   ),
// //                 ],
// //
// //                 // --- Payment Cards with animation (using filtered data) ---
// //                 ...filteredStudentsData.asMap().entries.map((entry) {
// //                   final index = entry.key;
// //                   final item = entry.value;
// //                   final student = item['student'];
// //                   final fee = item['fee'];
// //                   final gatePass = item['gatePass'];
// //
// //                   return AnimatedSlide(
// //                     duration: Duration(milliseconds: 300 + (index * 100)),
// //                     curve: Curves.easeOut,
// //                     offset: const Offset(0, 0),
// //                     child: AnimatedOpacity(
// //                       duration: Duration(milliseconds: 400 + (index * 100)),
// //                       opacity: 1,
// //                       child: _paymentCard(
// //                         name: student['name'] ?? '',
// //                         id: int.tryParse(student['id'] ?? '0') ?? 0,
// //                         due: fee['next_due_date'] ?? '',
// //                         amount: "${fee['amount'] ?? '0'}", // Removed $ since you're using ₹
// //                         coach: item['coachName'] ?? '',
// //                         markedDate: fee['paid_date'] ?? '',
// //                         approvedByAdmin: fee['admin_status'] == 'approved',
// //                         gatePassIssued:
// //                         gatePass != null &&
// //                             gatePass['status'] == 'active',
// //                         qrCode: gatePass != null ? gatePass['qr_code'] : '',
// //                         qrValidUntil: gatePass != null
// //                             ? gatePass['valid_until']
// //                             : '',
// //                         paymentId: int.tryParse(fee['id'] ?? '0') ?? 0,
// //                         onStatusChanged: () {
// //                           fetchStudents();
// //                           // Reapply search after data refresh
// //                           if (searchQuery.isNotEmpty) {
// //                             _filterStudents(searchQuery);
// //                           }
// //                         },
// //                       ),
// //                     ),
// //                   );
// //                 }).toList(),
// //               ],
// //             ),
// //           ),
// //         ),
// //       ),
// //     );
// //   }
//
//   // ---------------- Payment Card -----------------
//   Widget _paymentCard({
//     required String name,
//     required int id,
//     required String due,
//     required String amount,
//     required String coach,
//     required String markedDate,
//     required bool approvedByAdmin,
//     required bool gatePassIssued,
//     required String qrCode,
//     required String qrValidUntil,
//     required int paymentId,
//     required VoidCallback onStatusChanged,
//   }) {
//     return StatefulBuilder(
//       builder: (context, setState) {
//         // Local states
//         String status = approvedByAdmin ? "approved" : "pending";
//         bool localGatePass = gatePassIssued;
//         String localQr = qrCode;
//         String localValidUntil = qrValidUntil;
//
//         Uint8List? qrImageBytes;
//         if (localQr.startsWith("data:image")) {
//           final base64Str = localQr.split(',').last;
//           qrImageBytes = base64Decode(base64Str);
//         }
//
//         // --- Approve function ---
//         Future<void> approve() async {
//           setState(() => status = "loading");
//           try {
//             final res = await http.post(
//               Uri.parse("https://nahatasports.com/fees/approve/$paymentId"),
//               headers: {"Content-Type": "application/json"},
//               body: jsonEncode({"feeId": paymentId}),
//             );
//             print("Approve Response: ${res.body}");
//             final response = jsonDecode(res.body);
//             if (response['status'] == true) {
//               setState(() {
//                 status = "approved";
//                 localGatePass = response['pass']?['status'] == 'active';
//                 localQr = response['pass']?['qr_code'] ?? '';
//                 localValidUntil = response['pass']?['valid_until'] ?? '';
//                 if (localQr.startsWith("data:image")) {
//                   final base64Str = localQr.split(',').last;
//                   qrImageBytes = base64Decode(base64Str);
//                 }
//               });
//               onStatusChanged();
//               ScaffoldMessenger.of(context).showSnackBar(
//                 SnackBar(content: Text(response['message'] ?? "Approved!")),
//               );
//             } else {
//               setState(() => status = "pending");
//               ScaffoldMessenger.of(context).showSnackBar(
//                 SnackBar(content: Text("Failed: ${response['message']}")),
//               );
//             }
//           } catch (e) {
//             setState(() => status = "pending");
//             ScaffoldMessenger.of(context).showSnackBar(
//               SnackBar(content: Text("Error: $e")),
//             );
//           }
//         }
//
//         // --- Reject function ---
//         Future<void> reject() async {
//           setState(() => status = "loading");
//           try {
//             final res = await http.post(
//               Uri.parse("https://nahatasports.com/fees/reject/$paymentId"),
//               headers: {"Content-Type": "application/json"},
//               body: jsonEncode({"feeId": paymentId}),
//             );
//             print("Reject Response: ${res.body}");
//             final response = jsonDecode(res.body);
//             if (response['status'] == true) {
//               setState(() => status = "rejected");
//               onStatusChanged();
//               ScaffoldMessenger.of(context).showSnackBar(
//                 SnackBar(content: Text(response['message'] ?? "Rejected!")),
//               );
//             } else {
//               setState(() => status = "pending");
//               ScaffoldMessenger.of(context).showSnackBar(
//                 SnackBar(content: Text("Failed: ${response['message']}")),
//               );
//             }
//           } catch (e) {
//             setState(() => status = "pending");
//             ScaffoldMessenger.of(context).showSnackBar(
//               SnackBar(content: Text("Error: $e")),
//             );
//           }
//         }
//
//         // --- UI ---
//         return Card(
//           margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//           elevation: 3,
//           child: Padding(
//             padding: const EdgeInsets.all(12),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 // --- Student Info ---
//                 Text(name,
//                     style: const TextStyle(
//                         fontSize: 16, fontWeight: FontWeight.bold)),
//                 const SizedBox(height: 4),
//                 Text("ID: $id"),
//                 Text("Coach: $coach"),
//                 Text("Marked Date: $markedDate"),
//                 const SizedBox(height: 6),
//
//                 // --- Fee Info ---
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Text("Due: $due",
//                         style: const TextStyle(color: Colors.redAccent)),
//                     Text("Amount: ₹$amount",
//                         style: const TextStyle(
//                             fontWeight: FontWeight.bold, fontSize: 14)),
//                   ],
//                 ),
//                 const Divider(height: 20),
//
//                 // --- Action / Status UI ---
//                 if (status == "pending") ...[
//                   Row(
//                     children: [
//                       Expanded(
//                         child: OutlinedButton.icon(
//                           onPressed: reject,
//                           style: OutlinedButton.styleFrom(
//                             foregroundColor: Colors.red,
//                             side: const BorderSide(color: Colors.red),
//                             shape: RoundedRectangleBorder(
//                                 borderRadius: BorderRadius.circular(12)),
//                           ),
//                           icon: const Icon(Icons.close, size: 16),
//                           label: const Text("Reject", style: TextStyle(fontSize: 13)),
//                         ),
//                       ),
//                       const SizedBox(width: 8),
//                       Expanded(
//                         child: ElevatedButton.icon(
//                           onPressed: approve,
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: Colors.green,
//                             shape: RoundedRectangleBorder(
//                                 borderRadius: BorderRadius.circular(12)),
//                           ),
//                           icon: const Icon(Icons.check,
//                               size: 16, color: Colors.white),
//                           label: const Text("Approve",
//                               style: TextStyle(fontSize: 13, color: Colors.white)),
//                         ),
//                       ),
//                     ],
//                   )
//                 ] else if (status == "approved") ...[
//                   Wrap(
//                     spacing: 8,
//                     runSpacing: 4,
//                     children: [
//                       Chip(
//                         avatar: const Icon(Icons.verified,
//                             color: Colors.green, size: 16),
//                         label: const Text("Approved by Admin",
//                             style: TextStyle(fontSize: 12)),
//                         backgroundColor: Colors.green[50],
//                         side: BorderSide.none,
//                       ),
//                       if (localGatePass)
//                         Chip(
//                           avatar: const Icon(Icons.qr_code,
//                               color: Colors.blue, size: 16),
//                           label: const Text("Gate Pass Issued",
//                               style: TextStyle(fontSize: 12)),
//                           backgroundColor: Colors.blue[50],
//                           side: BorderSide.none,
//                         ),
//                     ],
//                   ),
//                   const SizedBox(height: 10),
//                   if (qrImageBytes != null)
//                     Center(
//                       child: Column(
//                         children: [
//                           ClipRRect(
//                             borderRadius: BorderRadius.circular(8),
//                             child: Image.memory(qrImageBytes!,
//                                 width: 120, height: 120),
//                           ),
//                           const SizedBox(height: 6),
//                           if (localValidUntil.isNotEmpty)
//                             Text("Valid until $localValidUntil",
//                                 style: const TextStyle(
//                                     fontSize: 12, color: Colors.black54)),
//                         ],
//                       ),
//                     ),
//                 ] else if (status == "rejected") ...[
//                   Chip(
//                     avatar:
//                     const Icon(Icons.block, color: Colors.red, size: 16),
//                     label: const Text("Rejected by Admin",
//                         style: TextStyle(fontSize: 12)),
//                     backgroundColor: Colors.red[50],
//                     side: BorderSide.none,
//                   ),
//                 ] else if (status == "loading") ...[
//                   const Center(child: CircularProgressIndicator()),
//                 ],
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }
//
// }

import 'dart:math' as math;

import '../services/api_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> studentsData = [];
  List<dynamic> filteredStudentsData = []; // For search functionality
  bool isLoading = true;
  String searchQuery = ""; // Track search input

  // Pagination variables
  final ScrollController _scrollController = ScrollController();
  int pageSize = 10; // Made non-final to allow changes
  int currentPage = 1;
  int totalPages = 1;

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchStudents();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> fetchStudents() async {
    setState(() => isLoading = true);
    try {
      final res = await http.get(
        Uri.parse('https://nahatasports.com/admin/api/fees'),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['status'] == true) {
          setState(() {
            studentsData = data['data'];
            filteredStudentsData = data['data']; // Initialize filtered data
            totalPages = (filteredStudentsData.length / pageSize).ceil();
            isLoading = false;
            _controller.forward();
          });
        }
      } else {
        throw Exception('Failed to load data');
      }
    } catch (e) {
      setState(() => isLoading = false);
      debugPrint("Error fetching students: $e");
    }
  }

  void _filterStudents(String query) {
    setState(() {
      searchQuery = query;
      if (query.isEmpty) {
        filteredStudentsData = studentsData;
      } else {
        filteredStudentsData = studentsData.where((item) {
          final student = item['student'] ?? {};
          final studentName = (student['name'] ?? '').toString().toLowerCase();
          final coachName = (item['coachName'] ?? '').toString().toLowerCase();
          final sport = (student['sport'] ?? '').toString().toLowerCase();
          final searchLower = query.toLowerCase();

          return studentName.contains(searchLower) ||
              coachName.contains(searchLower) ||
              sport.contains(searchLower);
        }).toList();
      }

      // Reset pagination on search
      currentPage = 1;
      totalPages = (filteredStudentsData.length / pageSize).ceil();
    });
  }

  static Map<String, int> _calculateStats(List<dynamic> data) {
    int pendingConfirmations = 0;
    int confirmedToday = 0;
    int total = data.length;

    final now = DateTime.now();

    for (final item in data) {
      final fee = (item['fee'] ?? {}) as Map<String, dynamic>;
      final adminStatus = (fee['admin_status'] ?? '').toString();
      final paidDateRaw = fee['paid_date']?.toString();

      if (adminStatus != 'approved') {
        pendingConfirmations++;
      }

      if (adminStatus == 'approved' &&
          paidDateRaw != null &&
          paidDateRaw.isNotEmpty) {
        final paid = DateTime.tryParse(paidDateRaw.replaceFirst(' ', 'T'));
        if (paid != null &&
            paid.year == now.year &&
            paid.month == now.month &&
            paid.day == now.day) {
          confirmedToday++;
        }
      }
    }

    return {
      'pending': pendingConfirmations,
      'confirmedToday': confirmedToday,
      'total': total,
    };
  }

  static Widget _statCard(IconData icon, String value, String label, Color color) {
    return Card(
      elevation: 4,
      shadowColor: color.withOpacity(0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }
  List<dynamic> get paginatedStudents {
    final start = (currentPage - 1) * pageSize;
    final end = math.min(start + pageSize, filteredStudentsData.length);
    return filteredStudentsData.sublist(start, end);
  }

  // List<dynamic> get paginatedStudents {
  //   final start = (currentPage - 1) * pageSize;
  //   final end = (start + pageSize) > filteredStudentsData.length
  //       ? filteredStudentsData.length
  //       : start + pageSize;
  //   return filteredStudentsData.sublist(start, end);
  // }

  // Enhanced pagination controls with better UX
  Widget _paginationControls() {
    List<Widget> pages = [];

    // Show page info
    pages.add(
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Text(
          "Page $currentPage of $totalPages",
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );

    // Previous Button
    pages.add(
      IconButton(
        icon: const Icon(Icons.arrow_back_ios),
        onPressed: currentPage > 1
            ? () {
          setState(() => currentPage--);
          _scrollController.animateTo(0, duration: Duration(milliseconds: 300), curve: Curves.easeInOut);
        }
            : null,

        // onPressed: currentPage > 1
        //     ? () => setState(() => currentPage--)
        //     : null,
        tooltip: "Previous Page",
      ),
    );

    // Page numbers with smart truncation
    if (totalPages <= 7) {
      // Show all pages if 7 or fewer
      for (int i = 1; i <= totalPages; i++) {
        pages.add(_buildPageNumber(i));
      }
    } else {
      // Smart pagination with ellipsis
      pages.add(_buildPageNumber(1));

      if (currentPage > 4) {
        pages.add(_buildEllipsis());
      }

      int start = math.max(2, currentPage - 1);
      int end = math.min(totalPages - 1, currentPage + 1);

      for (int i = start; i <= end; i++) {
        pages.add(_buildPageNumber(i));
      }

      if (currentPage < totalPages - 3) {
        pages.add(_buildEllipsis());
      }

      if (totalPages > 1) {
        pages.add(_buildPageNumber(totalPages));
      }
    }

    // Next Button
    pages.add(
      IconButton(
        icon: const Icon(Icons.arrow_forward_ios),
        onPressed: currentPage < totalPages
            ? () => setState(() => currentPage++)
            : null,
        tooltip: "Next Page",
      ),
    );

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: pages,
        ),
      ),
    );
  }

  Widget _buildPageNumber(int pageNumber) {
    final bool isCurrentPage = currentPage == pageNumber;

    return GestureDetector(
      onTap: () {
        setState(() => currentPage = pageNumber);
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        // setState(() => currentPage = pageNumber);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isCurrentPage ? const Color(0xFF0A198D) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isCurrentPage ? const Color(0xFF0A198D) : Colors.grey.shade300,
          ),
        ),
        child: Text(
          "$pageNumber",
          style: TextStyle(
            color: isCurrentPage ? Colors.white : Colors.black87,
            fontWeight: isCurrentPage ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildEllipsis() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: const Text(
        "...",
        style: TextStyle(
          color: Colors.black54,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Enhanced items per page selector
  Widget _itemsPerPageSelector() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Items per page:",
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(width: 8),
            DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: pageSize,
                items: [5, 10, 20, 50].map((int value) {
                  return DropdownMenuItem<int>(
                    value: value,
                    child: Text(value.toString()),
                  );
                }).toList(),
                onChanged: (int? newValue) {
                  if (newValue != null) {
                    setState(() {
                      pageSize = newValue;
                      totalPages = (filteredStudentsData.length / pageSize).ceil();
                      currentPage = 1; // Reset to first page
                    });
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Add this method to show pagination info
  Widget _paginationInfo() {
    if (filteredStudentsData.isEmpty) return const SizedBox.shrink();

    final int startItem = ((currentPage - 1) * pageSize) + 1;
    final int endItem = math.min(currentPage * pageSize, filteredStudentsData.length);
    final int totalItems = filteredStudentsData.length;

    return Card(
      elevation: 1,
      color: Colors.blue.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          "Showing $startItem-$endItem of $totalItems ${searchQuery.isNotEmpty ? 'filtered ' : ''}results",
          style: const TextStyle(
            fontSize: 13,
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = _calculateStats(studentsData);

    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          backgroundColor: const Color(0xFF0A198D),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              SystemNavigator.pop();
            },
          ),
          title: const Text(
            "Office Admin Dashboard",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: () async {
                await AuthService.logout();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                );
              },
            ),
          ],
        ),

        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Info Card ---
                Card(
                  color: Colors.indigo[50],
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(18),
                    child: Text(
                      "Review and confirm fee payments marked by coaches",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black87, fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // --- Stats Cards ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: _statCard(
                        Icons.access_time,
                        stats["pending"].toString(),
                        "Pending",
                        Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _statCard(
                        Icons.check_circle,
                        stats["confirmedToday"].toString(),
                        "Confirmed Today",
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _statCard(
                        Icons.people,
                        stats["total"].toString(),
                        "Total Students",
                        Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // --- Search Bar ---
                TextField(
                  controller: _searchController,
                  onChanged: _filterStudents,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, color: Colors.black54),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _filterStudents("");
                      },
                    )
                        : null,
                    hintText: "Search by student name, sport, or coach...",
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      searchQuery.isEmpty
                          ? "Payments Awaiting Confirmation"
                          : "Search Results",
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    if (searchQuery.isNotEmpty)
                      Text(
                        "${filteredStudentsData.length} result${filteredStudentsData.length != 1 ? 's' : ''}",
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // Pagination info
                // if (filteredStudentsData.isNotEmpty) _paginationInfo(),
                if (filteredStudentsData.isNotEmpty && totalPages > 1) _paginationControls(),

                // const SizedBox(height: 8),

                // Items per page selector
                // if (filteredStudentsData.length > 5)
                //   Align(
                //     alignment: Alignment.centerRight,
                //     child: _itemsPerPageSelector(),
                //   ),

                const SizedBox(height: 10),

                if (filteredStudentsData.isEmpty && searchQuery.isNotEmpty) ...[
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            "No results found for '$searchQuery'",
                            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Try searching with a different term",
                            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                // --- Payment Cards ---
                ...paginatedStudents.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final student = item['student'];
                  final fee = item['fee'];
                  final gatePass = item['gatePass'];

                  return AnimatedSlide(
                    duration: Duration(milliseconds: 300 + (index * 100)),
                    curve: Curves.easeOut,
                    offset: const Offset(0, 0),
                    child: AnimatedOpacity(
                      duration: Duration(milliseconds: 400 + (index * 100)),
                      opacity: 1,
                      child: _paymentCard(
                        name: student['name'] ?? '',
                        id: int.tryParse(student['id'] ?? '0') ?? 0,
                        due: fee['next_due_date'] ?? '',
                        amount: "${fee['amount'] ?? '0'}",
                        coach: item['coachName'] ?? '',
                        markedDate: fee['paid_date'] ?? '',
                        approvedByAdmin: fee['admin_status'] == 'approved',
                        gatePassIssued:
                        gatePass != null && gatePass['status'] == 'active',
                        qrCode: gatePass != null ? gatePass['qr_code'] : '',
                        qrValidUntil: gatePass != null ? gatePass['valid_until'] : '',
                        paymentId: int.tryParse(fee['id'] ?? '0') ?? 0,
                        onStatusChanged: () {
                          fetchStudents();
                          if (searchQuery.isNotEmpty) _filterStudents(searchQuery);
                        },
                      ),
                    ),
                  );
                }).toList(),

                const SizedBox(height: 16),
                // Enhanced pagination controls
                if (totalPages > 1) _paginationControls(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- Payment Card -----------------
  Widget _paymentCard({
    required String name,
    required int id,
    required String due,
    required String amount,
    required String coach,
    required String markedDate,
    required bool approvedByAdmin,
    required bool gatePassIssued,
    required String qrCode,
    required String qrValidUntil,
    required int paymentId,
    required VoidCallback onStatusChanged,
  }) {
    return StatefulBuilder(
      builder: (context, setState) {
        // Local states
        String status = approvedByAdmin ? "approved" : "pending";
        bool localGatePass = gatePassIssued;
        String localQr = qrCode;
        String localValidUntil = qrValidUntil;

        Uint8List? qrImageBytes;
        if (localQr.startsWith("data:image")) {
          final base64Str = localQr.split(',').last;
          qrImageBytes = base64Decode(base64Str);
        }

        // --- Approve function ---
        Future<void> approve() async {
          setState(() => status = "loading");
          try {
            final res = await http.post(
              Uri.parse("https://nahatasports.com/fees/approve/$paymentId"),
              headers: {"Content-Type": "application/json"},
              body: jsonEncode({"feeId": paymentId}),
            );
            print("Approve Response: ${res.body}");
            final response = jsonDecode(res.body);
            if (response['status'] == true) {
              setState(() {
                status = "approved";
                localGatePass = response['pass']?['status'] == 'active';
                localQr = response['pass']?['qr_code'] ?? '';
                localValidUntil = response['pass']?['valid_until'] ?? '';
                if (localQr.startsWith("data:image")) {
                  final base64Str = localQr.split(',').last;
                  qrImageBytes = base64Decode(base64Str);
                }
              });
              onStatusChanged();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(response['message'] ?? "Approved!")),
              );
            } else {
              setState(() => status = "pending");
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Failed: ${response['message']}")),
              );
            }
          } catch (e) {
            setState(() => status = "pending");
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Error: $e")),
            );
          }
        }

        // --- Reject function ---
        Future<void> reject() async {
          setState(() => status = "loading");
          try {
            final res = await http.post(
              Uri.parse("https://nahatasports.com/fees/reject/$paymentId"),
              headers: {"Content-Type": "application/json"},
              body: jsonEncode({"feeId": paymentId}),
            );
            print("Reject Response: ${res.body}");
            final response = jsonDecode(res.body);
            if (response['status'] == true) {
              setState(() => status = "rejected");
              onStatusChanged();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(response['message'] ?? "Rejected!")),
              );
            } else {
              setState(() => status = "pending");
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Failed: ${response['message']}")),
              );
            }
          } catch (e) {
            setState(() => status = "pending");
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Error: $e")),
            );
          }
        }

        // --- UI ---
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 3,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Student Info ---
                Text(name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text("ID: $id"),
                Text("Coach: $coach"),
                Text("Marked Date: $markedDate"),
                const SizedBox(height: 6),

                // --- Fee Info ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Due: $due",
                        style: const TextStyle(color: Colors.redAccent)),
                    Text("Amount: ₹$amount",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
                const Divider(height: 20),

                // --- Action / Status UI ---
                if (status == "pending") ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: reject,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text("Reject", style: TextStyle(fontSize: 13)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: approve,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.check,
                              size: 16, color: Colors.white),
                          label: const Text("Approve",
                              style: TextStyle(fontSize: 13, color: Colors.white)),
                        ),
                      ),
                    ],
                  )
                ] else if (status == "approved") ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Chip(
                        avatar: const Icon(Icons.verified,
                            color: Colors.green, size: 16),
                        label: const Text("Approved by Admin",
                            style: TextStyle(fontSize: 12)),
                        backgroundColor: Colors.green[50],
                        side: BorderSide.none,
                      ),
                      if (localGatePass)
                        Chip(
                          avatar: const Icon(Icons.qr_code,
                              color: Colors.blue, size: 16),
                          label: const Text("Gate Pass Issued",
                              style: TextStyle(fontSize: 12)),
                          backgroundColor: Colors.blue[50],
                          side: BorderSide.none,
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (qrImageBytes != null)
                    Center(
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(qrImageBytes!,
                                width: 120, height: 120),
                          ),
                          const SizedBox(height: 6),
                          if (localValidUntil.isNotEmpty)
                            Text("Valid until $localValidUntil",
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.black54)),
                        ],
                      ),
                    ),
                ] else if (status == "rejected") ...[
                  Chip(
                    avatar:
                    const Icon(Icons.block, color: Colors.red, size: 16),
                    label: const Text("Rejected by Admin",
                        style: TextStyle(fontSize: 12)),
                    backgroundColor: Colors.red[50],
                    side: BorderSide.none,
                  ),
                ] else if (status == "loading") ...[
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}













































































// class _AdminDashboardScreenState extends State<AdminDashboardScreen>
//     with SingleTickerProviderStateMixin {
//   List<dynamic> studentsData = [];
//   bool isLoading = true;
//
//   late AnimationController _controller;
//   late Animation<double> _fadeAnimation;
//
//   @override
//   void initState() {
//     super.initState();
//     fetchStudents();
//
//     _controller = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 600),
//     );
//     _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
//   }
//
//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }
//
//   Future<void> fetchStudents() async {
//     setState(() => isLoading = true);
//     try {
//       final res = await http.get(
//         Uri.parse('https://nahatasports.com/admin/api/fees'),
//       );
//       if (res.statusCode == 200) {
//         final data = jsonDecode(res.body);
//         if (data['status'] == true) {
//           setState(() {
//             studentsData = data['data'];
//             isLoading = false;
//             _controller.forward(); // trigger animations when data loads
//           });
//         }
//       } else {
//         throw Exception('Failed to load data');
//       }
//     } catch (e) {
//       setState(() => isLoading = false);
//       debugPrint("Error fetching students: $e");
//     }
//   }
//
//   static Map<String, int> _calculateStats(List<dynamic> data) {
//     int pendingConfirmations = 0;
//     int confirmedToday = 0;
//     int total = data.length;
//
//     final now = DateTime.now();
//
//     for (final item in data) {
//       final fee = (item['fee'] ?? {}) as Map<String, dynamic>;
//       final adminStatus = (fee['admin_status'] ?? '').toString();
//       final paidDateRaw = fee['paid_date']?.toString();
//
//       if (adminStatus != 'approved') {
//         pendingConfirmations++;
//       }
//
//       if (adminStatus == 'approved' &&
//           paidDateRaw != null &&
//           paidDateRaw.isNotEmpty) {
//         final paid = DateTime.tryParse(paidDateRaw.replaceFirst(' ', 'T'));
//         if (paid != null &&
//             paid.year == now.year &&
//             paid.month == now.month &&
//             paid.day == now.day) {
//           confirmedToday++;
//         }
//       }
//     }
//
//     return {
//       'pending': pendingConfirmations,
//       'confirmedToday': confirmedToday,
//       'total': total,
//     };
//   }
//
//   static Widget _statCard(
//     IconData icon,
//     String value,
//     String label,
//     Color color,
//   ) {
//     return Card(
//       elevation: 4,
//       shadowColor: color.withOpacity(0.4),
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       child: Padding(
//         padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
//         child: Column(
//           children: [
//             Icon(icon, color: color, size: 32),
//             const SizedBox(height: 8),
//             Text(
//               value,
//               style: TextStyle(
//                 fontSize: 20,
//                 fontWeight: FontWeight.bold,
//                 color: color,
//               ),
//             ),
//             const SizedBox(height: 4),
//             Text(
//               label,
//               textAlign: TextAlign.center,
//               style: const TextStyle(fontSize: 13, color: Colors.black87),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final stats = _calculateStats(studentsData);
//
//     return Scaffold(
//       backgroundColor: Colors.grey[100],
//       appBar: AppBar(
//         backgroundColor: Color(0xFF0A198D),
//         elevation: 0,
//         leading: IconButton(
//           icon: Icon(Icons.arrow_back, color: Colors.white),
//           onPressed: () {
//             Navigator.pushReplacement(
//               context,
//               MaterialPageRoute(
//                 builder: (_) => LoginScreen(),
//               ), // or any other screen
//             );
//           },
//         ),
//         title: Text(
//           "Office Admin Dashboard",
//           style: TextStyle(
//             color: Colors.white,
//             fontWeight: FontWeight.bold,
//             fontSize: 20,
//           ),
//         ),
//         centerTitle: true,
//       ),
//
//       body: isLoading
//           ? const Center(child: CircularProgressIndicator())
//           : FadeTransition(
//               opacity: _fadeAnimation,
//               child: SingleChildScrollView(
//                 padding: const EdgeInsets.all(16),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     // --- Info Card ---
//                     Card(
//                       color: Colors.indigo[50],
//                       elevation: 2,
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(16),
//                       ),
//                       child: const Padding(
//                         padding: EdgeInsets.all(18),
//                         child: Text(
//                           "Review and confirm fee payments marked by coaches",
//                           textAlign: TextAlign.center,
//                           style: TextStyle(color: Colors.black87, fontSize: 14),
//                         ),
//                       ),
//                     ),
//
//                     const SizedBox(height: 16),
//
//                     // --- Stats Cards ---
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         Expanded(
//                           child: _statCard(
//                             Icons.access_time,
//                             stats["pending"].toString(),
//                             "Pending",
//                             Colors.orange,
//                           ),
//                         ),
//                         const SizedBox(width: 12),
//                         Expanded(
//                           child: _statCard(
//                             Icons.check_circle,
//                             stats["confirmedToday"].toString(),
//                             "Confirmed Today",
//                             Colors.green,
//                           ),
//                         ),
//                         const SizedBox(width: 12),
//                         Expanded(
//                           child: _statCard(
//                             Icons.people,
//                             stats["total"].toString(),
//                             "Total Students",
//                             Colors.blue,
//                           ),
//                         ),
//                       ],
//                     ),
//
//                     const SizedBox(height: 20),
//
//                     // --- Search Bar ---
//                     TextField(
//                       decoration: InputDecoration(
//                         prefixIcon: const Icon(
//                           Icons.search,
//                           color: Colors.black54,
//                         ),
//                         hintText: "Search by student name, sport, or coach...",
//                         filled: true,
//                         fillColor: Colors.white,
//                         contentPadding: const EdgeInsets.symmetric(
//                           vertical: 0,
//                           horizontal: 12,
//                         ),
//                         border: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(14),
//                           borderSide: BorderSide.none,
//                         ),
//                       ),
//                     ),
//
//                     const SizedBox(height: 20),
//                     const Text(
//                       "Payments Awaiting Confirmation",
//                       style: TextStyle(
//                         fontSize: 17,
//                         fontWeight: FontWeight.bold,
//                         color: Colors.black87,
//                       ),
//                     ),
//                     const SizedBox(height: 10),
//
//                     // --- Payment Cards with animation ---
//                     ...studentsData.asMap().entries.map((entry) {
//                       final index = entry.key;
//                       final item = entry.value;
//                       final student = item['student'];
//                       final fee = item['fee'];
//                       final gatePass = item['gatePass'];
//
//                       return AnimatedSlide(
//                         duration: Duration(milliseconds: 300 + (index * 100)),
//                         curve: Curves.easeOut,
//                         offset: const Offset(0, 0),
//                         child: AnimatedOpacity(
//                           duration: Duration(milliseconds: 400 + (index * 100)),
//                           opacity: 1,
//                           child: _paymentCard(
//                             name: student['name'] ?? '',
//                             id: int.tryParse(student['id'] ?? '0') ?? 0,
//                             due: fee['next_due_date'] ?? '',
//                             amount: "\$${fee['amount'] ?? '0'}",
//                             coach: item['coachName'] ?? '',
//                             markedDate: fee['paid_date'] ?? '',
//                             approvedByAdmin: fee['admin_status'] == 'approved',
//                             gatePassIssued:
//                                 gatePass != null &&
//                                 gatePass['status'] == 'active',
//                             qrCode: gatePass != null ? gatePass['qr_code'] : '',
//                             qrValidUntil: gatePass != null
//                                 ? gatePass['valid_until']
//                                 : '',
//                             paymentId: int.tryParse(fee['id'] ?? '0') ?? 0,
//                             onStatusChanged: fetchStudents,
//                           ),
//                         ),
//                       );
//                     }).toList(),
//                   ],
//                 ),
//               ),
//             ),
//     );
//   }
//
//   // ---------------- Payment Card -----------------
//   Widget _paymentCard({
//     required String name,
//     required int id,
//     required String due,
//     required String amount,
//     required String coach,
//     required String markedDate,
//     required bool approvedByAdmin,
//     required bool gatePassIssued,
//     required String qrCode,
//     required String qrValidUntil,
//     required int paymentId,
//     required VoidCallback onStatusChanged,
//   }) {
//     return StatefulBuilder(
//       builder: (context, setState) {
//         // Local states
//         String status = approvedByAdmin ? "approved" : "pending";
//         bool localGatePass = gatePassIssued;
//         String localQr = qrCode;
//         String localValidUntil = qrValidUntil;
//
//         Uint8List? qrImageBytes;
//         if (localQr.startsWith("data:image")) {
//           final base64Str = localQr.split(',').last;
//           qrImageBytes = base64Decode(base64Str);
//         }
//
//         // --- Approve function ---
//         Future<void> approve() async {
//           setState(() => status = "loading");
//           try {
//             final res = await http.post(
//               Uri.parse("https://nahatasports.com/fees/approve/$paymentId"),
//               headers: {"Content-Type": "application/json"},
//               body: jsonEncode({"feeId": paymentId}),
//             );
//             print("Approve Response: ${res.body}");
//             final response = jsonDecode(res.body);
//             if (response['status'] == true) {
//               setState(() {
//                 status = "approved";
//                 localGatePass = response['pass']?['status'] == 'active';
//                 localQr = response['pass']?['qr_code'] ?? '';
//                 localValidUntil = response['pass']?['valid_until'] ?? '';
//                 if (localQr.startsWith("data:image")) {
//                   final base64Str = localQr.split(',').last;
//                   qrImageBytes = base64Decode(base64Str);
//                 }
//               });
//               onStatusChanged();
//               ScaffoldMessenger.of(context).showSnackBar(
//                 SnackBar(content: Text(response['message'] ?? "Approved!")),
//               );
//             } else {
//               setState(() => status = "pending");
//               ScaffoldMessenger.of(context).showSnackBar(
//                 SnackBar(content: Text("Failed: ${response['message']}")),
//               );
//             }
//           } catch (e) {
//             setState(() => status = "pending");
//             ScaffoldMessenger.of(context).showSnackBar(
//               SnackBar(content: Text("Error: $e")),
//             );
//           }
//         }
//
//         // --- Reject function ---
//         Future<void> reject() async {
//           setState(() => status = "loading");
//           try {
//             final res = await http.post(
//               Uri.parse("https://nahatasports.com/fees/reject/$paymentId"),
//               headers: {"Content-Type": "application/json"},
//               body: jsonEncode({"feeId": paymentId}),
//             );
//             print("Reject Response: ${res.body}");
//             final response = jsonDecode(res.body);
//             if (response['status'] == true) {
//               setState(() => status = "rejected");
//               onStatusChanged();
//               ScaffoldMessenger.of(context).showSnackBar(
//                 SnackBar(content: Text(response['message'] ?? "Rejected!")),
//               );
//             } else {
//               setState(() => status = "pending");
//               ScaffoldMessenger.of(context).showSnackBar(
//                 SnackBar(content: Text("Failed: ${response['message']}")),
//               );
//             }
//           } catch (e) {
//             setState(() => status = "pending");
//             ScaffoldMessenger.of(context).showSnackBar(
//               SnackBar(content: Text("Error: $e")),
//             );
//           }
//         }
//
//         // --- UI ---
//         return Card(
//           margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//           elevation: 3,
//           child: Padding(
//             padding: const EdgeInsets.all(12),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 // --- Student Info ---
//                 Text(name,
//                     style: const TextStyle(
//                         fontSize: 16, fontWeight: FontWeight.bold)),
//                 const SizedBox(height: 4),
//                 Text("ID: $id"),
//                 Text("Coach: $coach"),
//                 Text("Marked Date: $markedDate"),
//                 const SizedBox(height: 6),
//
//                 // --- Fee Info ---
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Text("Due: $due",
//                         style: const TextStyle(color: Colors.redAccent)),
//                     Text("Amount: ₹$amount",
//                         style: const TextStyle(
//                             fontWeight: FontWeight.bold, fontSize: 14)),
//                   ],
//                 ),
//                 const Divider(height: 20),
//
//                 // --- Action / Status UI ---
//                 if (status == "pending") ...[
//                   Row(
//                     children: [
//                       Expanded(
//                         child: OutlinedButton.icon(
//                           onPressed: reject,
//                           style: OutlinedButton.styleFrom(
//                             foregroundColor: Colors.red,
//                             side: const BorderSide(color: Colors.red),
//                             shape: RoundedRectangleBorder(
//                                 borderRadius: BorderRadius.circular(12)),
//                           ),
//                           icon: const Icon(Icons.close, size: 16),
//                           label: const Text("Reject", style: TextStyle(fontSize: 13)),
//                         ),
//                       ),
//                       const SizedBox(width: 8),
//                       Expanded(
//                         child: ElevatedButton.icon(
//                           onPressed: approve,
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: Colors.green,
//                             shape: RoundedRectangleBorder(
//                                 borderRadius: BorderRadius.circular(12)),
//                           ),
//                           icon: const Icon(Icons.check,
//                               size: 16, color: Colors.white),
//                           label: const Text("Approve",
//                               style: TextStyle(fontSize: 13, color: Colors.white)),
//                         ),
//                       ),
//                     ],
//                   )
//                 ] else if (status == "approved") ...[
//                   Wrap(
//                     spacing: 8,
//                     runSpacing: 4,
//                     children: [
//                       Chip(
//                         avatar: const Icon(Icons.verified,
//                             color: Colors.green, size: 16),
//                         label: const Text("Approved by Admin",
//                             style: TextStyle(fontSize: 12)),
//                         backgroundColor: Colors.green[50],
//                         side: BorderSide.none,
//                       ),
//                       if (localGatePass)
//                         Chip(
//                           avatar: const Icon(Icons.qr_code,
//                               color: Colors.blue, size: 16),
//                           label: const Text("Gate Pass Issued",
//                               style: TextStyle(fontSize: 12)),
//                           backgroundColor: Colors.blue[50],
//                           side: BorderSide.none,
//                         ),
//                     ],
//                   ),
//                   const SizedBox(height: 10),
//                   if (qrImageBytes != null)
//                     Center(
//                       child: Column(
//                         children: [
//                           ClipRRect(
//                             borderRadius: BorderRadius.circular(8),
//                             child: Image.memory(qrImageBytes!,
//                                 width: 120, height: 120),
//                           ),
//                           const SizedBox(height: 6),
//                           if (localValidUntil.isNotEmpty)
//                             Text("Valid until $localValidUntil",
//                                 style: const TextStyle(
//                                     fontSize: 12, color: Colors.black54)),
//                         ],
//                       ),
//                     ),
//                 ] else if (status == "rejected") ...[
//                   Chip(
//                     avatar:
//                     const Icon(Icons.block, color: Colors.red, size: 16),
//                     label: const Text("Rejected by Admin",
//                         style: TextStyle(fontSize: 12)),
//                     backgroundColor: Colors.red[50],
//                     side: BorderSide.none,
//                   ),
//                 ] else if (status == "loading") ...[
//                   const Center(child: CircularProgressIndicator()),
//                 ],
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }
//
// }
