import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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


















class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  List<dynamic> payments = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchPayments();
  }

  /// Fetch pending payments API
  Future<void> fetchPayments() async {
    try {
      final response = await http.get(
        Uri.parse("https://nahatasports.com/admin/feesmodule/pending"),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          payments = data; // assuming API returns a list
          isLoading = false;
        });
      } else {
        throw Exception("Failed to fetch payments");
      }
    } catch (e) {
      setState(() => isLoading = false);
      print("Error fetching payments: $e");
    }
  }

  /// Approve payment API
  Future<void> approvePayment(int paymentId) async {
    try {
      final response = await http.get(
        Uri.parse("https://nahatasports.com/admin/feesmodule/approve/$paymentId"),
      );

      if (response.statusCode == 200) {
        setState(() {
          // Mark approved in UI
          payments = payments.map((p) {
            if (p["id"] == paymentId) {
              p["approvedByAdmin"] = true;
            }
            return p;
          }).toList();
        });
      } else {
        print("Failed to approve: ${response.body}");
      }
    } catch (e) {
      print("Error approving payment: $e");
    }
  }

  /// Reject payment API
  Future<void> rejectPayment(int paymentId) async {
    try {
      final response = await http.get(
        Uri.parse("https://nahatasports.com/admin/feesmodule/reject/$paymentId"),
      );

      if (response.statusCode == 200) {
        setState(() {
          // Mark rejected in UI
          payments = payments.map((p) {
            if (p["id"] == paymentId) {
              p["rejectedByAdmin"] = true;
            }
            return p;
          }).toList();
        });
      } else {
        print("Failed to reject: ${response.body}");
      }
    } catch (e) {
      print("Error rejecting payment: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Admin Dashboard")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            "Payments Awaiting Confirmation",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...payments.map((p) => PaymentCard(
            data: p,
            onApprove: () => approvePayment(p["id"]),
            onReject: () => rejectPayment(p["id"]),
          )),
        ],
      ),
    );
  }
}

class PaymentCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const PaymentCard({
    super.key,
    required this.data,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final isApproved = data["approvedByAdmin"] == true;
    final isRejected = data["rejectedByAdmin"] == true;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data["name"] ?? "",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text("ID: ${data["id"]} • Due: ${data["due"]}"),
            Text(data["amount"] ?? ""),
            Text("Marked by ${data["coach"]} on ${data["markedDate"]}"),

            const SizedBox(height: 8),

            if (!isApproved && !isRejected) ...[
              Row(
                children: [
                  ElevatedButton(
                    onPressed: onApprove,
                    child: const Text("Approve"),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: onReject,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text("Reject"),
                  ),
                ],
              ),
            ],

            if (isApproved) ...[
              const SizedBox(height: 8),
              const Text("✅ Approved by Admin"),
              if (data["qrCode"] != null && data["qrCode"].toString().isNotEmpty)
                Text("QR Code: ${data["qrCode"]}"),
            ],

            if (isRejected) ...[
              const SizedBox(height: 8),
              const Text("❌ Rejected by Admin", style: TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
    );
  }
}




















































//
//
// class AdminDashboardScreen extends StatefulWidget {
//   const AdminDashboardScreen({super.key});
//
//   @override
//   State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
// }
//
// class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
//     static Widget _statCard(IconData icon, String value, String label, Color color) {
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
//   // Sample raw data for payments
//   final List<Map<String, dynamic>> payments = const [
//     {
//       "initialName": "Swanandi Kholkute",
//       "initialId": 117,
//       "initialDue": "2025-09-26",
//       "initialAmount": "\$111.00",
//       "initialCoach": "Coach Coach",
//       "initialMarkedDate": "2025-08-25 12:33:16",
//       "fullDetails": {
//         "name": "Mike Wilson",
//         "id": 107,
//         "due": "2025-09-30",
//         "amount": "\$150.00",
//         "coach": "Coach Sarah",
//         "markedDate": "2025-08-26 09:15:22",
//         "approvedByAdmin": false,
//         "gatePassIssued": false,
//         "qrCode": "",
//         "qrValidUntil": "",
//         "paymentId": 5,
//       },
//     },
//     {
//       "initialName": "Sarah Davis",
//       "initialId": 118,
//       "initialDue": "2025-09-28",
//       "initialAmount": "\$120.00",
//       "initialCoach": "Coach Mike",
//       "initialMarkedDate": "2025-08-25 13:27:41",
//       "fullDetails": {
//         "name": "Sarah Davis",
//         "id": 118,
//         "due": "2025-09-28",
//         "amount": "\$120.00",
//         "coach": "Coach Mike",
//         "markedDate": "2025-08-25 13:27:41",
//         "approvedByAdmin": true,
//         "gatePassIssued": true,
//         "qrCode": "XYZ789",
//         "qrValidUntil": "2025-09-28 00:00:00",
//         "paymentId": 6,
//       },
//     },
//     {
//       "initialName": "Lisa Chen",
//       "initialId": 119,
//       "initialDue": "2025-09-29",
//       "initialAmount": "\$180.00",
//       "initialCoach": "Coach Sarah",
//       "initialMarkedDate": "2025-08-26 09:45:00",
//       "fullDetails": {
//         "name": "Lisa Chen",
//         "id": 119,
//         "due": "2025-09-29",
//         "amount": "\$180.00",
//         "coach": "Coach Sarah",
//         "markedDate": "2025-08-26 09:45:00",
//         "approvedByAdmin": false,
//         "gatePassIssued": false,
//         "qrCode": "",
//         "qrValidUntil": "",
//         "paymentId": 7,
//       },
//     },
//   ];
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         elevation: 0,
//         title: const Text(
//           "Office Admin Dashboard",
//           style: TextStyle(color: Colors.black),
//         ),
//         centerTitle: true,
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(12),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//                           Card(
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
//             const SizedBox(height: 16),
//             const Text(
//               "Payments Awaiting Confirmation",
//               style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 8),
//
//             // Render all payment cards dynamically
//             ...payments.map((p) => PaymentCard(
//               initialName: p["initialName"],
//               initialId: p["initialId"],
//               initialDue: p["initialDue"],
//               initialAmount: p["initialAmount"],
//               initialCoach: p["initialCoach"],
//               initialMarkedDate: p["initialMarkedDate"],
//               fullDetails: p["fullDetails"],
//             )),
//           ],
//         ),
//       ),
//     );
//   }
// }
//
// // ---------------- Stateful Payment Card ----------------
//
// class PaymentCard extends StatefulWidget {
//   final String initialName;
//   final int initialId;
//   final String initialDue;
//   final String initialAmount;
//   final String initialCoach;
//   final String initialMarkedDate;
//   final Map<String, dynamic> fullDetails;
//
//   const PaymentCard({
//     super.key,
//     required this.initialName,
//     required this.initialId,
//     required this.initialDue,
//     required this.initialAmount,
//     required this.initialCoach,
//     required this.initialMarkedDate,
//     required this.fullDetails,
//   });
//
//   @override
//   State<PaymentCard> createState() => _PaymentCardState();
// }
//
// class _PaymentCardState extends State<PaymentCard> {
//   String status = "pending"; // pending / approved / rejected
//   bool loading = false;
//
//   Future<void> approvePayment() async {
//     setState(() => loading = true);
//     final paymentId = widget.fullDetails["paymentId"];
//     final url = "https://nahatasports.com/admin/feesmodule/approve/$paymentId";
//
//     try {
//       final response = await http.post(Uri.parse(url));
//       if (response.statusCode == 200) {
//         setState(() {
//           status = "approved";
//           print(response.body);
//           print("Payment approved successfully");
//         });
//       } else {
//         showError("Failed to approve payment");
//       }
//     } catch (e) {
//       showError(e.toString());
//     } finally {
//       setState(() => loading = false);
//     }
//   }
//
//   Future<void> rejectPayment() async {
//     setState(() => loading = true);
//     final paymentId = widget.fullDetails["paymentId"];
//     final url = "https://nahatasports.com/admin/feesmodule/reject/$paymentId";
//
//     try {
//       final response = await http.post(Uri.parse(url));
//       if (response.statusCode == 200) {
//         setState(() {
//           status = "rejected";
//           print(response.body);
//           print("Payment rejected successfully");
//         });
//       } else {
//         showError("Failed to reject payment");
//       }
//     } catch (e) {
//       showError(e.toString());
//     } finally {
//       setState(() => loading = false);
//     }
//   }
//
//   void showError(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text(message)),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final name = (status == "approved") ? widget.fullDetails["name"] : widget.initialName;
//     final id = (status == "approved") ? widget.fullDetails["id"] : widget.initialId;
//     final due = (status == "approved") ? widget.fullDetails["due"] : widget.initialDue;
//     final amount = (status == "approved") ? widget.fullDetails["amount"] : widget.initialAmount;
//     final coach = (status == "approved") ? widget.fullDetails["coach"] : widget.initialCoach;
//     final markedDate = (status == "approved") ? widget.fullDetails["markedDate"] : widget.initialMarkedDate;
//     final approvedByAdmin = (status == "approved") ? widget.fullDetails["approvedByAdmin"] : false;
//     final gatePassIssued = (status == "approved") ? widget.fullDetails["gatePassIssued"] : false;
//     final qrCode = (status == "approved") ? widget.fullDetails["qrCode"] : "";
//     final qrValidUntil = (status == "approved") ? widget.fullDetails["qrValidUntil"] : "";
//
//     return Card(
//       margin: const EdgeInsets.symmetric(vertical: 8),
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       child: Padding(
//         padding: const EdgeInsets.all(12),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
//             const Divider(height: 6, thickness: 1),
//             Text("ID: $id • Due: $due", style: const TextStyle(color: Colors.black54)),
//             Text(amount, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
//             Text("Marked by $coach", style: const TextStyle(fontSize: 12)),
//             Text("on $markedDate", style: const TextStyle(fontSize: 12, color: Colors.black54)),
//             const SizedBox(height: 8),
//
//             if (loading) const CircularProgressIndicator(),
//             if (!loading)
//               if (status == "pending")
//                 Row(
//                   children: [
//                     OutlinedButton(onPressed: rejectPayment, child: const Text("Reject", style: TextStyle(fontSize: 12))),
//                     const SizedBox(width: 6),
//                     ElevatedButton(onPressed: approvePayment, child: const Text("Approve", style: TextStyle(fontSize: 12))),
//                   ],
//                 )
//               else if (status == "approved") ...[
//                 if (approvedByAdmin)
//                   Chip(label: const Text("Approved by Admin", style: TextStyle(fontSize: 12)), backgroundColor: Colors.green[100]),
//                 if (gatePassIssued)
//                   Chip(label: const Text("Gate Pass Issued", style: TextStyle(fontSize: 12)), backgroundColor: Colors.blue[100]),
//                 Row(
//                   children: [
//                     const Icon(Icons.qr_code, size: 20),
//                     const SizedBox(width: 6),
//                     Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text("QR Code: $qrCode", style: const TextStyle(fontSize: 12)),
//                         Text("Valid until $qrValidUntil", style: const TextStyle(fontSize: 12, color: Colors.black54)),
//                       ],
//                     )
//                   ],
//                 ),
//               ] else if (status == "rejected") ...[
//                 Chip(label: const Text("Rejected by Admin", style: TextStyle(fontSize: 12)), backgroundColor: Colors.red[100]),
//               ],
//           ],
//         ),
//       ),
//     );
//   }
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

// class _PaymentCardState extends State<PaymentCard> {
//   String status = "pending"; // pending / approved / rejected
//
//   void approve() {
//     setState(() {
//       status = "approved";
//     });
//     // TODO: call approve API here using widget.fullDetails["paymentId"]
//   }
//
//   void reject() {
//     setState(() {
//       status = "rejected";
//     });
//     // TODO: call reject API here using widget.fullDetails["paymentId"]
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     // Use fullDetails if approved, else use initial values
//     final name = (status == "approved") ? widget.fullDetails["name"] : widget.initialName;
//     final id = (status == "approved") ? widget.fullDetails["id"] : widget.initialId;
//     final due = (status == "approved") ? widget.fullDetails["due"] : widget.initialDue;
//     final amount = (status == "approved") ? widget.fullDetails["amount"] : widget.initialAmount;
//     final coach = (status == "approved") ? widget.fullDetails["coach"] : widget.initialCoach;
//     final markedDate = (status == "approved") ? widget.fullDetails["markedDate"] : widget.initialMarkedDate;
//     final approvedByAdmin = (status == "approved") ? widget.fullDetails["approvedByAdmin"] : false;
//     final gatePassIssued = (status == "approved") ? widget.fullDetails["gatePassIssued"] : false;
//     final qrCode = (status == "approved") ? widget.fullDetails["qrCode"] : "";
//     final qrValidUntil = (status == "approved") ? widget.fullDetails["qrValidUntil"] : "";
//
//     return Card(
//       margin: const EdgeInsets.symmetric(vertical: 8),
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       child: Padding(
//         padding: const EdgeInsets.all(12),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
//             const Divider(height: 6, thickness: 1),
//             Text("ID: $id • Due: $due", style: const TextStyle(color: Colors.black54)),
//             Text(amount, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
//             Text("Marked by $coach", style: const TextStyle(fontSize: 12)),
//             Text("on $markedDate", style: const TextStyle(fontSize: 12, color: Colors.black54)),
//             const SizedBox(height: 8),
//
//             if (status == "pending")
//               Row(
//                 children: [
//                   OutlinedButton(onPressed: reject, child: const Text("Reject", style: TextStyle(fontSize: 12))),
//                   const SizedBox(width: 6),
//                   ElevatedButton(onPressed: approve, child: const Text("Approve", style: TextStyle(fontSize: 12))),
//                 ],
//               )
//             else if (status == "approved") ...[
//               if (approvedByAdmin)
//                 Chip(label: const Text("Approved by Admin", style: TextStyle(fontSize: 12)), backgroundColor: Colors.green[100]),
//               if (gatePassIssued)
//                 Chip(label: const Text("Gate Pass Issued", style: TextStyle(fontSize: 12)), backgroundColor: Colors.blue[100]),
//               Row(
//                 children: [
//                   const Icon(Icons.qr_code, size: 20),
//                   const SizedBox(width: 6),
//                   Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text("QR Code: $qrCode", style: const TextStyle(fontSize: 12)),
//                       Text("Valid until $qrValidUntil", style: const TextStyle(fontSize: 12, color: Colors.black54)),
//                     ],
//                   )
//                 ],
//               ),
//             ] else if (status == "rejected") ...[
//               Chip(label: const Text("Rejected by Admin", style: TextStyle(fontSize: 12)), backgroundColor: Colors.red[100]),
//             ],
//           ],
//         ),
//       ),
//     );
//   }
// }






















//admin@gmail.com
//admin@gmail.com