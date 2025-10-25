// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import 'package:flutter/material.dart';
// import 'package:razorpay_flutter/razorpay_flutter.dart';
// import 'package:shared_preferences/shared_preferences.dart';
//
// import '../services/api_service.dart';
//
// class PaymentScreen extends StatefulWidget {
//   final Map<String, dynamic> bookingDetails;
//
//   const PaymentScreen({super.key, required this.bookingDetails});
//
//   @override
//   State<PaymentScreen> createState() => _PaymentScreenState();
// }
//
// class _PaymentScreenState extends State<PaymentScreen> {
//   late Razorpay _razorpay;
//
//   @override
//   void initState() {
//     super.initState();
//     _razorpay = Razorpay();
//     _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
//     _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
//   }
//
//   /// Ensure user is logged in before payment
//   Future<bool> _isLoggedIn() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     return prefs.containsKey('userEmail');
//   }
//
//   /// API call to store booking after payment
//   Future<void> _storeBooking({
//     required String email,
//     required String slot,
//     required String date,
//     required String transactionId,
//     required int cashAmount,
//     required onlinePaid,
//   }) async {
//     final price = widget.bookingDetails['price'] ?? 0;
//     final onlinePaid = price - cashAmount;
//
//     // ✅ If no online payment, create a CASH transaction ID
//     final txnId = (onlinePaid > 0 && transactionId.isNotEmpty)
//         ? transactionId
//         : "CASH-${DateTime.now().millisecondsSinceEpoch}";
//     // ✅ Ensure all required booking data is present
//     final bookingData = {
//       "transaction_id": txnId,
//
//       // "transaction_id": transactionId.isNotEmpty ? transactionId : "N/A",
//       "razorpay_payment_id": transactionId.isNotEmpty ? transactionId : "N/A",
//       "selected_date": date.isNotEmpty ? date : DateTime.now().toIso8601String().split("T").first,
//       // "selected_slots": jsonEncode([slot.isNotEmpty ? slot : "Default Slot"]),
//       "selected_slots": jsonEncode(widget.bookingDetails['slots']),
//
//       "total_amount": price.toString(),
//       "booked_by": email,
//       "amount_paid": onlinePaid,   // ✅ Changed from online_paid
//       "cash_amount": cashAmount,   // ✅ Changed from cash_pending
//       "status": (onlinePaid > 0 && cashAmount > 0) ? "partial" : "full",
//       "created_at": DateTime.now().toIso8601String(),
//     };
//
//     print("💳 Online Paid: ₹$onlinePaid");
//     print("💵 Cash Amount: ₹$cashAmount");
//     // print("📤 Sending booking data to API:");
//     // print(const JsonEncoder.withIndent('  ').convert(bookingData));
//     // print("📥 API Response:");
//     // print("transaction_id");
//
//     try {
//       final res = await http.post(
//         Uri.parse("https://nahatasports.com/api/verifyPayment"),
//         headers: {"Content-Type": "application/json"},
//         body: jsonEncode(bookingData),
//       );
//
//       print("📥 API Response (${res.statusCode}): ${res.body}");
//       final data = jsonDecode(res.body);
//
//       if (data["success"] == true) {
//         print("✅ Booking stored successfully.");
//       } else {
//         print("❌ Booking failed: ${data["message"]}");
//       }
//     } catch (e) {
//       print("❌ API Error: $e");
//     }
//   }
//
//   void _handlePaymentSuccess(PaymentSuccessResponse response) async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     final email = prefs.getString('userEmail') ?? '';
//
//     final slot = widget.bookingDetails['slots'] ?? '';
//     final date = widget.bookingDetails['date'] ?? '';
//     final price = widget.bookingDetails['price'] ?? 0;
//     final cashAmount = widget.bookingDetails['cash'] ?? 0;
//     final onlinePaid = price - cashAmount;
//     final transactionId = response.paymentId ?? '';
//
//     // 🖨️ Print all details to console
//     print("========= 📌 Booking Details =========");
//     print("📧 Email           : $email");
//     print("🎯 Slot            : $slot");
//     print("📅 Date            : $date");
//     print("💰 Total Price     : ₹$price");
//     print("💵 Cash Amount     : ₹$cashAmount");
//     print("💳 Online Paid     : ₹$onlinePaid");
//     print("🔑 Transaction ID  : $transactionId");
//     print("======================================");
//
//     await _storeBooking(
//       email: email,
//       slot: slot,
//       date: date,
//       transactionId: transactionId,
//       cashAmount: cashAmount,
//       onlinePaid: onlinePaid,
//     );
//
//     _showDialog("✅ Success", "Booking stored successfully", goToLocation: true,);
//   }
//
//   /// Handle full cash payment without Razorpay
//   void _handleCashBooking() {
//     final TextEditingController _cashController = TextEditingController();
//     final total = widget.bookingDetails['price'] as int;
//
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text("Enter Cash Payment"),
//         content: TextField(
//           controller: _cashController,
//           keyboardType: TextInputType.number,
//           decoration: const InputDecoration(
//             labelText: "Cash Amount (₹)",
//             hintText: "",
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context), // Cancel
//             child: const Text("Cancel"),
//           ),
//           TextButton(
//             onPressed: () async {
//               final cash = int.tryParse(_cashController.text.trim()) ?? 0;
//
//               if (cash < 0 || cash > total) {
//                 Navigator.pop(context);
//                 if (mounted) {
//                   _showDialog("❌ Invalid Amount",
//                       "Enter a value between 0 and $total.");
//                 }
//                 return;
//               }
//
//               Navigator.pop(context);
//
//               final onlineAmount = total - cash;
//
//               setState(() {
//                 widget.bookingDetails['cash'] = cash;
//               });
//
//               // 🟢 If full cash, save booking directly
//               if (onlineAmount <= 0) {
//                 SharedPreferences prefs =
//                 await SharedPreferences.getInstance();
//                 final email = prefs.getString('userEmail') ?? '';
//
//                 await _storeBooking(
//                   email: email,
//                   // slot: widget.bookingDetails['slot'] ?? '',
//                   slot: jsonEncode(widget.bookingDetails['slots']),
//                   date: widget.bookingDetails['date'] ?? '',
//                   transactionId: "",
//                   cashAmount: cash,
//                   onlinePaid: 0,
//                 );
//
//                 _showDialog("✅ Cash Booking", "Booking stored successfully",
//                     goToLocation: true);
//               } else {
//                 // 🟢 If partial payment, go to Razorpay for remaining amount
//                 _payOnline();
//               }
//             },
//             child: const Text("Confirm"),
//           ),
//         ],
//       ),
//     );
//   }
//
//
//
//   void _handlePaymentError(PaymentFailureResponse response) {
//     _showDialog("❌ Payment Failed", response.message ?? 'Unknown error');
//   }
//
//   /// Trigger Razorpay payment
//   void _startPayment() async {
//     if (!await _isLoggedIn()) {
//       _showDialog("⚠️ Login Required", "Please log in to make a payment.");
//       return;
//     }
//
//     final amount = widget.bookingDetails['price'] ?? 0;
//     final cashPaid = widget.bookingDetails['cash_paid'] ?? 0;
//     final onlineAmount = amount - cashPaid;
//
//     var options = {
//       'key': 'rzp_live_R7b5MMCgg9AlWn',
//           'amount': onlineAmount * 100, // in paise
//       'name': 'Nahata Sports',
//       'description': 'Booking Payment',
//       'currency': 'INR',
//       'prefill': {
//         'email': (await SharedPreferences.getInstance()).getString('userEmail') ?? '',
//         'contact': ApiService.currentUser?['phone'] ?? '',
//       },
//       'method': {'upi': true},
//       'upi': {'flow': 'collect'},
//     };
//
//     try {
//       _razorpay.open(options);
//     } catch (e) {
//       print('❌ Razorpay error: $e');
//     }
//   }
//
//   void _showDialog(String title, String message, {bool goToLocation = false}) {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (_) => AlertDialog(
//         title: Text(title),
//         content: Text(message),
//         actions: [
//           TextButton(
//             onPressed: () {
//               Navigator.pop(context); // Close dialog
//               if (goToLocation && mounted) {
//                 // Use rootNavigator to ensure correct context
//                 Future.delayed(const Duration(milliseconds: 100), () {
//                   Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
//                     '/location',
//                         (route) => false,
//                   );
//                 });
//               }
//             },
//             child: const Text("OK"),
//           ),
//         ],
//       ),
//     );
//   }
//
//
//   void _promptCashAmount(BuildContext context) {
//     final TextEditingController _cashController = TextEditingController();
//     final total = widget.bookingDetails['price'] as int;
//
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text("Enter Cash Payment"),
//         content: TextField(
//           controller: _cashController,
//           keyboardType: TextInputType.number,
//           decoration: const InputDecoration(
//             labelText: "Cash Amount (₹)",
//             hintText: "e.g. 100",
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context), // Cancel
//             child: const Text("Cancel"),
//           ),
//           TextButton(
//             onPressed: () {
//               final cash = int.tryParse(_cashController.text.trim()) ?? 0;
//
//               if (cash < 0 || cash > total) {
//                 Navigator.pop(context);
//                 if (mounted) {
//                   _showDialog("❌ Invalid Amount",
//                       "Enter a value between 0 and $total.");
//                 }
//                 return;
//               }
//
//               setState(() {
//                 widget.bookingDetails['cash'] = cash;
//               });
//
//               Navigator.pop(context);
//
//               if (mounted) {
//                 _payOnline(); // Start Razorpay with updated amount
//               }
//             },
//             child: const Text("Confirm"),
//           ),
//         ],
//       ),
//     );
//   }
//
//   void _payOnline() async {
//     final total = widget.bookingDetails['price'] as int;
//     final cash = widget.bookingDetails['cash'] as int? ?? 0;
//     final onlineAmount = total - cash;
//
//     if (onlineAmount <= 0) {
//       _showDialog("❌ Invalid Payment", "Full amount already marked as cash.");
//       return;
//     }
//
//     final prefs = await SharedPreferences.getInstance();
//     final email = prefs.getString('userEmail') ;
//     final phone = widget.bookingDetails['phone'];
//
//     var options = {
//       'key': 'rzp_live_R7b5MMCgg9AlWn',
//       'amount': onlineAmount * 100, // paise
//       'name': 'Nahata Sports',
//       'description': '${widget.bookingDetails['game']} booking',
//       'currency': 'INR',
//       'prefill': {
//         'contact': phone,
//         'email': email,
//       },
//       'method': {
//         'upi': true,
//         'card': true,
//         'netbanking': true,
//         'wallet': true,
//       },
//     };
//
//     try {
//       _razorpay.open(options);
//     } catch (e) {
//       debugPrint('❌ Razorpay error: $e');
//     }
//   }
//
//   @override
//   void dispose() {
//     _razorpay.clear();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final booking = widget.bookingDetails;
//     final total = booking['price'] as int? ?? 0;
//     final cash = booking['cash'] as int? ?? 0;
//     final razorpayAmount = total - cash;
//     final razorpayDisabled = razorpayAmount <= 0;
//
//
//
//
//
//
//     return SafeArea(
//       child: Scaffold(
//         // backgroundColor: const Color(0xFFF9FAFB),
//         body:Stack(
//           children: [
//             // Container(
//             //   decoration: const BoxDecoration(
//             //     gradient: LinearGradient(
//             //       colors: [Color(0xFF1D2B64), Color(0xFFf8cdda)],
//             //       begin: Alignment.topCenter,
//             //       end: Alignment.bottomCenter,
//             //     ),
//             //   ),
//             // ),
//             SafeArea(
//               child: SingleChildScrollView(
//                 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     // 🔵 Page Title
//                     const Text(
//                       "Complete Your Payment",
//                       style: const TextStyle(
//                         fontSize: 24,
//                         fontWeight: FontWeight.bold,
//                         color: Color(0xFF0A198D),
//                       ),
//                     ),
//                     const SizedBox(height: 24),
//
//                     // 📋 Booking Summary
//                     Container(
//                       decoration: BoxDecoration(
//                         color: Colors.white,
//                         borderRadius: BorderRadius.circular(16),
//                         boxShadow: [
//                           BoxShadow(
//                             color: Colors.black.withOpacity(0.05),
//                             blurRadius: 12,
//                             offset: const Offset(0, 6),
//                           ),
//                         ],
//                       ),
//                       padding: const EdgeInsets.all(20),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           const Text(
//                             "📋 Booking Summary",
//                             style: TextStyle(
//                               fontSize: 20,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                           const SizedBox(height: 16),
//                           _infoRow("📍 Location", booking['location']),
//                           _infoRow("🎯 Game", booking['game']),
//                           _infoRow("📅 Date", booking['date']),
//                           _infoRow("⏰ Slots", (booking['slots'] as List)
//                               .map((s) => "${s['court']} (${s['time']})")
//                               .join(", ")
//                           ),
//                           const Divider(height: 32),
//                           _infoRow(
//                             "💰 Total Price",
//                             "₹${booking['price']}",
//                             isBold: true,
//                           ),
//                         ],
//                       ),
//                     ),
//
//                     const SizedBox(height: 32),
//
//                     // 💳 Payment Method Section
//                     const Text(
//                       "Select Payment Method",
//                       style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
//                     ),
//                     const SizedBox(height: 16),
//
//                     // 🔘 Online Payment Button
//                     Container(
//                       width: double.infinity,
//                       height: 55,
//                       decoration: BoxDecoration(
//                         color: razorpayDisabled ? Colors.grey[400] : const Color(0xFF0A198D),
//                         borderRadius: BorderRadius.circular(14),
//                       ),
//                       child: ElevatedButton.icon(
//                         onPressed: razorpayDisabled ? null : _payOnline,
//                         icon: const Icon(Icons.credit_card_rounded, size: 22),
//                         label: Text(
//                           "Pay Online ₹$razorpayAmount",
//                           style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
//                         ),
//                         style: ElevatedButton.styleFrom(
//                           elevation: 0,
//                           backgroundColor: Colors.transparent,
//                           shadowColor: Colors.transparent,
//                           foregroundColor: Colors.white,
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(14),
//                           ),
//                         ),
//                       ),
//                     ),
//
//                     const SizedBox(height: 20),
//
//                     ElevatedButton.icon(
//                       onPressed: _handleCashBooking,
//                       icon: const Icon(Icons.money_rounded, color: Colors.white),
//                       label: const Text(
//                         "Pay with Cash at Venue",
//                         style: TextStyle(
//                           fontSize: 16,
//                           fontWeight: FontWeight.bold,
//                           color: Colors.white,
//                         ),
//                       ),
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: Color(0xFF0A198D), // same dark blue
//                         foregroundColor: Colors.white,
//                         elevation: 5,
//                         minimumSize: const Size(double.infinity, 48),
//                         padding: const EdgeInsets.symmetric(vertical: 14),
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(14),
//                         ),
//                       ),
//                     ),
//
//                     // 💵 Cash Button
//                     // OutlinedButton.icon(
//                     //   onPressed: _handleCashBooking,
//                     //   icon: const Icon(Icons.money_rounded, color: Colors.green),
//                     //   label: const Text(
//                     //     "Pay with Cash at Venue",
//                     //     style: TextStyle(fontSize: 16),
//                     //   ),
//                     //   style: OutlinedButton.styleFrom(
//                     //     foregroundColor: Colors.green[800],
//                     //     side: const BorderSide(color: Colors.green),
//                     //     minimumSize: const Size(double.infinity, 48),
//                     //     padding: const EdgeInsets.symmetric(vertical: 14),
//                     //     shape: RoundedRectangleBorder(
//                     //       borderRadius: BorderRadius.circular(14),
//                     //     ),
//                     //   ),
//                     // ),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         )
//       ),
//     );
//   }
//
// // 🔹 Helper widget for rows
//   Widget _infoRow(String title, String? value, {bool isBold = false}) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 10),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Text(title, style: const TextStyle(fontSize: 16)),
//           Flexible(
//             child: Text(
//               value ?? '',
//               textAlign: TextAlign.right,
//               // overflow: TextOverflow.ellipsis,
//               style: TextStyle(
//                 fontSize: 16,
//                 fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
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
// // void _handleCashPayment() async {
// //   SharedPreferences prefs = await SharedPreferences.getInstance();
// //   final userEmail = prefs.getString('userEmail') ?? "";
// //   final booking = widget.bookingDetails;
// //   final cash = booking['price'] as int;
// //
// //   final success = await sendBookingToDatabase(
// //     userEmail: userEmail,
// //     location: booking['location'] ?? '',
// //     game: booking['game'] ?? '',
// //     date: booking['date'] ?? '',
// //     timeSlot: booking['slot'] ?? '',
// //     paymentId: 'N/A',
// //     paymentMode: 'cash',
// //     cashPaid: cash,
// //     razorpayPaid: 0,
// //   );
// //
// //   if (success) {
// //     _showDialog(
// //       "✅ Booking Confirmed",
// //       "You chose to pay full ₹$cash in cash.",
// //       goToLocation: true,
// //     );
// //   } else {
// //     _showDialog("❌ Booking Failed", "Could not store booking in database.");
// //   }
// // }
//
//
//
//
// //
// // Scaffold(
// // backgroundColor: const Color(0xFFF2F4F7),
// // body: SafeArea(
// // child: Padding(
// // padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
// // child: Column(
// // crossAxisAlignment: CrossAxisAlignment.start,
// // children: [
// // // 🔵 Title
// // const Text(
// // "Payment",
// // style: TextStyle(
// // fontSize: 26,
// // fontWeight: FontWeight.bold,
// // color: Colors.indigo,
// // ),
// // ),
// // const SizedBox(height: 20),
// //
// // // 📋 Booking Summary Card
// // Card(
// // elevation: 3,
// // shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
// // child: Padding(
// // padding: const EdgeInsets.all(16),
// // child: Column(
// // crossAxisAlignment: CrossAxisAlignment.start,
// // children: [
// // const Text(
// // "Booking Summary",
// // style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
// // ),
// // const Divider(thickness: 1.2),
// // Text("📍 Location: ${booking['location']}"),
// // Text("🎯 Game: ${booking['game']}"),
// // Text("📅 Date: ${booking['date']}"),
// // // Text("🏟️ Court: ${booking['court']}"),
// // Text("⏰ Slot: ${booking['slot']}"),
// // Text(
// // "💵 Price: ₹${booking['price']}",
// // style: const TextStyle(fontWeight: FontWeight.bold),
// // ),
// // ],
// // ),
// // ),
// // ),
// //
// // const SizedBox(height: 30),
// //
// // const Text(
// // "Choose Payment Method",
// // style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
// // ),
// // const SizedBox(height: 10),
// //
// //
// // ElevatedButton.icon(
// // onPressed: razorpayDisabled ? null : _payOnline,
// // icon: const Icon(Icons.payment, size: 22),
// // label: Text(
// // "Pay Online ₹$razorpayAmount",
// // style: const TextStyle(fontSize: 16),
// // ),
// // style: ElevatedButton.styleFrom(
// // backgroundColor: razorpayDisabled ? Colors.grey : Colors.indigo,
// // foregroundColor: Colors.white,
// // elevation: 4,
// // shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
// // minimumSize: const Size(double.infinity, 50),
// // ),
// // ),
// //
// //
// // const SizedBox(height: 20),
// // TextButton.icon(
// // onPressed: () =>   _handleCashBooking(),
// // icon: const Icon(Icons.money, color: Colors.green),
// // label: const Text(
// // "Pay with Cash at Venue",
// // style: TextStyle(fontSize: 16),
// // ),
// // style: TextButton.styleFrom(
// // foregroundColor: Colors.green[800],
// // minimumSize: const Size(double.infinity, 48),
// // shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
// // side: const BorderSide(color: Colors.green),
// // ),
// // ),
// //
// //
// //
// // ],
// // ),
// // ),
// // ),
// // );
// //
// //
// //
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
// // void _handleSuccess(PaymentSuccessResponse response) async {
// //   final paymentId = response.paymentId ?? "N/A";
// //
// //   // Merge payment details with original booking info
// //   final bookingWithUpi = {
// //     ...widget.bookingDetails,
// //     'upi_id': 'testuser@upi', // Replace with real UPI if available
// //     'payment_id': paymentId,
// //   };
// //
// //   try {
// //     final res = await http.post(
// //       Uri.parse('https://nahatasports.com/verify-payment'),
// //       headers: {'Content-Type': 'application/json'},
// //       body: jsonEncode(bookingWithUpi),
// //     );
// //
// //     if (res.statusCode == 200) {
// //       final data = jsonDecode(res.body);
// //       if (data['status'] == true) {
// //         _showDialog(
// //           "✅ Payment Successful",
// //           "Booking Confirmed!\nPayment ID: $paymentId",
// //           goToLocation: true,
// //         );
// //       } else {
// //         _showDialog("❌ Verification Failed", data['message'] ?? "Unknown error");
// //         print("❌ Verification Failed: ${data['message'] ?? "Unknown error"}");
// //       }
// //     } else {
// //       _showDialog("❌ Server Error", "Code: ${res.statusCode}");
// //       print("❌ Server Error: Code: ${res.statusCode}");
// //     }
// //   } catch (e) {
// //     _showDialog("❌ Error in payment verification", e.toString());
// //     print("❌ Error in payment verification: $e");
// //   }
// // }
//
//
// // void _handleCashPayment() async {
// //   final bookingWithCash = {
// //     ...widget.bookingDetails,
// //     'payment_mode': 'cash',
// //     'payment_id': 'N/A',
// //     'upi_id': '',
// //   };
// //
// //   try {
// //     final res = await http.post(
// //       Uri.parse('https://nahatasports.com/verify-payment'),
// //       headers: {'Content-Type': 'application/json'},
// //       body: jsonEncode(bookingWithCash),
// //     );
// //
// //     if (res.statusCode == 200) {
// //       final data = jsonDecode(res.body);
// //       if (data['status'] == true) {
// //         _showDialog(
// //           "✅ Booking Confirmed",
// //           "You chose to pay with Cash at venue.",
// //           goToLocation: true,
// //         );
// //       } else {
// //         _showDialog("❌ Booking Failed", data['message'] ?? "Unknown error");
// //       }
// //     } else {
// //       _showDialog("❌ Server Error", "Code: ${res.statusCode}");
// //     }
// //   } catch (e) {
// //     _showDialog("❌ Error in booking", e.toString());
// //   }
// // }
//
//
// // void _payOnline() {
// //   final amount = widget.bookingDetails['price'] as int;
// //
// //   var options = {
// //     'key': 'rzp_test_YwYUHvAMatnKBY',
// //     'amount': amount * 100,
// //     'name': 'Nahata Sports',
// //     'description': '${widget.bookingDetails['game']} booking',
// //     'currency': 'INR',
// //     'prefill': {
// //       'contact': '9876543210',
// //       'email': 'test@example.com',
// //       'vpa': 'testuser@upi',
// //     },
// //     'method': {
// //       'upi': true,
// //       'card': false,
// //       'netbanking': false,
// //       'wallet': false,
// //     },
// //   };
// //
// //   try {
// //     _razorpay.open(options);
// //   } catch (e) {
// //     debugPrint('Error opening Razorpay: $e');
// //   }
// // }
//
//
// // 💳 Payment Button
// // ElevatedButton.icon(
// //   onPressed: _payOnline,
// //   icon: const Icon(Icons.payment, size: 22),
// //   label: const Text("Pay Online (Razorpay)", style: TextStyle(fontSize: 16)),
// //   style: ElevatedButton.styleFrom(
// //     backgroundColor: Colors.indigo,
// //     foregroundColor: Colors.white,
// //     elevation: 4,
// //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
// //     minimumSize: const Size(double.infinity, 50),
// //   ),
// // ),
//
//
//
// //
// // void _promptCashAmount(BuildContext context) {
// //   final TextEditingController _cashController = TextEditingController();
// //   final total = widget.bookingDetails['price'] as int;
// //
// //   showDialog(
// //     context: context,
// //     builder: (context) => AlertDialog(
// //       title: const Text("Enter Cash Payment"),
// //       content: TextField(
// //         controller: _cashController,
// //         keyboardType: TextInputType.number,
// //         decoration: const InputDecoration(
// //           labelText: "Cash Amount (₹)",
// //           hintText: "e.g. 100",
// //         ),
// //       ),
// //       actions: [
// //         TextButton(
// //           onPressed: () => Navigator.pop(context), // Close dialog
// //           child: const Text("Cancel"),
// //         ),
// //         TextButton(
// //           onPressed: () {
// //             final cash = int.tryParse(_cashController.text.trim()) ?? 0;
// //
// //             if (cash < 0 || cash > total) {
// //               Navigator.pop(context); // Close dialog
// //               if (mounted) {
// //                 _showDialog("❌ Invalid Amount",
// //                     "Enter a value between 0 and $total.");
// //               }
// //               return;
// //             }
// //
// //             setState(() {
// //               widget.bookingDetails['cash'] = cash;
// //             });
// //
// //             // ✅ Close the amount dialog first
// //             Navigator.pop(context);
// //
// //             // ✅ Navigate safely after pop
// //             if (mounted) {
// //               Navigator.pushNamedAndRemoveUntil(
// //                 context,
// //                 '/location',
// //                     (_) => false,
// //               );
// //             }
// //           },
// //           child: const Text("Confirm"),
// //         ),
// //       ],
// //     ),
// //   );
// // }
//
//
//
//
// // void _handleSuccess(PaymentSuccessResponse response) async {
// //   final paymentId = response.paymentId ?? "N/A";
// //   final total = widget.bookingDetails['price'] as int;
// //   final cash = widget.bookingDetails['cash'] as int? ?? 0;
// //   final onlinePaid = total - cash;
// //
// //   final bookingWithUpi = {
// //     ...widget.bookingDetails,
// //     'upi_id': 'testuser@upi',
// //     'payment_id': paymentId,
// //     'payment_mode': 'online',
// //     'cash_paid': cash,
// //     'razorpay_paid': onlinePaid,
// //   };
// //
// //   try {
// //     final res = await http.post(
// //       Uri.parse('https://nahatasports.com/verify-payment'),
// //       headers: {'Content-Type': 'application/json'},
// //       body: jsonEncode(bookingWithUpi),
// //     );
// //
// //     if (res.statusCode == 200) {
// //       final data = jsonDecode(res.body);
// //       if (data['status'] == true) {
// //         _showDialog(
// //           "✅ Payment Successful",
// //           "Booking Confirmed!\nPayment ID: $paymentId",
// //           goToLocation: true,
// //         );
// //       } else {
// //         _showDialog("❌ Verification Failed", data['message'] ?? "Unknown error");
// //       }
// //     } else {
// //       _showDialog("❌ Server Error", "Code: ${res.statusCode}");
// //     }
// //   } catch (e) {
// //     _showDialog("❌ Error in payment verification", e.toString());
// //   }
// // }
//
//
// // final success = await sendBookingToDatabase(
// // userEmail: userEmail,
// // location: booking['location'] ?? '',
// // game: booking['game'] ?? '',
// // date: booking['date'] ?? '',
// // timeSlot: booking['slot'] ?? '',
// // upiId: booking['upi_id'] ?? 'testuser@upi',
// // paymentId: paymentId,
// // paymentMode: 'online',
// // cashPaid: booking['cash'] ?? 0,
// // razorpayPaid: (booking['price'] ?? 0) - (booking['cash'] ?? 0),
// // );
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
// // @override
// // Widget build(BuildContext context) {
// //   final booking = widget.bookingDetails;
// //   final total = booking['price'] as int;
// //   final cash = booking['cash'] as int? ?? 0;
// //   final razorpayAmount = total - cash;
// //   final razorpayDisabled = razorpayAmount <= 0;
// //
// //   return Scaffold(
// //     backgroundColor: const Color(0xFFF2F4F7),
// //     body: SafeArea(
// //       child: Padding(
// //         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
// //         child: Column(
// //           crossAxisAlignment: CrossAxisAlignment.start,
// //           children: [
// //             // 🔵 Title
// //             const Text(
// //               "Payment",
// //               style: TextStyle(
// //                 fontSize: 26,
// //                 fontWeight: FontWeight.bold,
// //                 color: Colors.indigo,
// //               ),
// //             ),
// //             const SizedBox(height: 20),
// //
// //             // 📋 Booking Summary Card
// //             Card(
// //               elevation: 3,
// //               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
// //               child: Padding(
// //                 padding: const EdgeInsets.all(16),
// //                 child: Column(
// //                   crossAxisAlignment: CrossAxisAlignment.start,
// //                   children: [
// //                     const Text(
// //                       "Booking Summary",
// //                       style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
// //                     ),
// //                     const Divider(thickness: 1.2),
// //                     Text("📍 Location: ${booking['location']}"),
// //                     Text("🎯 Game: ${booking['game']}"),
// //                     Text("📅 Date: ${booking['date']}"),
// //                     // Text("🏟️ Court: ${booking['court']}"),
// //                     Text("⏰ Slot: ${booking['slot']}"),
// //                     Text(
// //                       "💵 Price: ₹${booking['price']}",
// //                       style: const TextStyle(fontWeight: FontWeight.bold),
// //                     ),
// //                   ],
// //                 ),
// //               ),
// //             ),
// //
// //             const SizedBox(height: 30),
// //
// //             const Text(
// //               "Choose Payment Method",
// //               style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
// //             ),
// //             const SizedBox(height: 10),
// //
// //
// //             ElevatedButton.icon(
// //               onPressed: razorpayDisabled ? null : _payOnline,
// //               icon: const Icon(Icons.payment, size: 22),
// //               label: Text(
// //                 "Pay Online ₹$razorpayAmount",
// //                 style: const TextStyle(fontSize: 16),
// //               ),
// //               style: ElevatedButton.styleFrom(
// //                 backgroundColor: razorpayDisabled ? Colors.grey : Colors.indigo,
// //                 foregroundColor: Colors.white,
// //                 elevation: 4,
// //                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
// //                 minimumSize: const Size(double.infinity, 50),
// //               ),
// //             ),
// //
// //
// //             const SizedBox(height: 20),
// //             TextButton.icon(
// //               onPressed: () =>   _handleCashBooking(),
// //               icon: const Icon(Icons.money, color: Colors.green),
// //               label: const Text(
// //                 "Pay with Cash at Venue",
// //                 style: TextStyle(fontSize: 16),
// //               ),
// //               style: TextButton.styleFrom(
// //                 foregroundColor: Colors.green[800],
// //                 minimumSize: const Size(double.infinity, 48),
// //                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
// //                 side: const BorderSide(color: Colors.green),
// //               ),
// //             ),
// //
// //
// //
// //           ],
// //         ),
// //       ),
// //     ),
// //   );
// // }