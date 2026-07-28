import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import your existing API service
// import '../services/api_service.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import 'Custombottombar.dart';
import 'morescreen.dart';

// Import your existing API service - uncomment when available
// import '../services/api_service.dart';
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
class PaymentScreen extends StatefulWidget {
  final Map<String, dynamic> bookingDetails;

  const PaymentScreen({super.key, required this.bookingDetails});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late Razorpay _razorpay;
  String selectedPaymentMethod = 'online';
  bool isLoading = false;
  bool agreedToTerms = false;  // Add this line
  bool _isVerifyingPayment = false;

  // 🔄 NEW API: base url + booking/order state carried across the Razorpay flow
  static const String _apiBase = "https://api.nahatasports.com/api";
  static const String _bookingType = "facility";
  List<int> _bookingIds = [];
  String? _rzpOrderId;
  String? _rzpKeyId;

  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('authToken');
  }
  @override
  void initState() {
    super.initState();
    _initializeRazorpay();
    _validateBookingDetails();
  }

  void _initializeRazorpay() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void _validateBookingDetails() {
    final required = ['location', 'game', 'slots', 'price', 'date'];
    final missing = <String>[];

    for (String key in required) {
      if (!widget.bookingDetails.containsKey(key) ||
          widget.bookingDetails[key] == null ||
          (widget.bookingDetails[key] is String &&
              widget.bookingDetails[key].isEmpty)) {
        missing.add(key);
      }
    }

    if (missing.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showErrorDialog("Missing booking details: ${missing.join(', ')}");
      });
    }

    if (widget.bookingDetails['slots'] != null &&
        widget.bookingDetails['slots'] is! List) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showErrorDialog("Invalid slots format. Expected List.");
      });
    }

    final price = widget.bookingDetails['price'];
    if (price == null ||
        (price is! int && price is! double) ||
        (price is num && price <= 0)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showErrorDialog("Invalid price. Must be a positive number.");
      });
    }
  }
  Future<String?> _getUserEmail() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('user');
      if (userJson != null) {
        final userData = jsonDecode(userJson);
        return userData['email']?.toString();
      }
      return null;
    } catch (e) {
      print("❌ SharedPreferences error: $e");
      return null;
    }
  }
  Future<String?> _getUserName() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('user'); // ✅ SAME AS EMAIL

      if (userJson != null) {
        final userData = jsonDecode(userJson);
        final name = userData['name']?.toString();
        print("👤 User Name: $name");
        return name;
      }

      return null;
    } catch (e) {
      print("❌ SharedPreferences error (name): $e");
      return null;
    }
  }


  Future<void> showBookingConfirmedNotification({
    required String date,
    required String slot,
    required int totalAmount,
  }) async {
    const AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      'booking_channel',
      'Booking Notifications',
      channelDescription: 'Booking confirmation notifications',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails notificationDetails =
    NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      '✅ Booking Confirmed',
      '📅 Date: $date\n⏰ Slot: $slot\n💰 Amount: ₹$totalAmount',
      notificationDetails,
      payload: 'booking',
    );
  }

  void onDidReceiveNotificationResponse(NotificationResponse response) {
    if (response.payload == 'booking') {
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const MyBookingsScreen()),
      );
    }
  }

  Future<bool> _isLoggedIn() async {
    final email = await _getUserEmail();
    if (email == null) print("❌ User not logged in - missing email");
    return email != null;
  }

  // Future<String?> _createRazorpayOrder(int amountInRupees)
  // async {
  //   try {
  //     final res = await http.post(
  //       Uri.parse("https://nahatasports.com/api/create-order-app"),
  //       headers: {"Content-Type": "application/json"},
  //       body: jsonEncode({
  //         "amount": amountInRupees, // 🔥 MUST BE PAISA
  //       }),
  //     );
  //
  //     print("📦 Create Order Response: ${res.body}");
  //
  //     if (res.statusCode == 200) {
  //       final data = jsonDecode(res.body);
  //       if (data["success"] == true) {
  //         return data["data"]["order_id"]; // safer
  //       }
  //     }
  //   } catch (e) {
  //     print("❌ Order Error: $e");
  //   }
  //   return null;
  // }

  // ---------------------- OLD API (commented out) ----------------------
  // Future<String?> _createRazorpayOrder(int amount) async {
  //   final res = await http.post(
  //     Uri.parse("https://nahatasports.com/api/create-order-app"),
  //     headers: {"Content-Type": "application/json"},
  //     body: jsonEncode({"amount": amount}),
  //   );
  //
  //   if (res.statusCode == 200) {
  //     final data = jsonDecode(res.body);
  //     return data["order_id"];
  //   }
  //   return null;
  // }

  // ---------------------- NEW API: reserve booking(s) ----------------------
  // POST /courts/bookings/create  (one call per selected slot)
  // Returns the list of created booking ids (paymentStatus = Pending).
  Future<List<int>> _createBookings({
    required String? token,
    required List<Map<String, dynamic>> slots,
  }) async {
    final List<int> ids = [];
    for (final s in slots) {
      final body = {
        "sportComplexId": s['sportComplexId'] ??
            widget.bookingDetails['sportComplexId'],
        "sportId": s['sportId'] ?? widget.bookingDetails['sportId'],
        "date": s['date'],
        "startTime": s['startTime'],
        "endTime": s['endTime'],
        "totalAmount": (s['price'] as num?)?.toInt() ?? 0,
      };

      final res = await http.post(
        Uri.parse("$_apiBase/courts/bookings/create"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
        body: jsonEncode(body),
      );

      print("📦 create booking (${res.statusCode}): ${res.body}");

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        final List bookings = data['data']?['bookings'] ?? [];
        for (final b in bookings) {
          final id = b['id'];
          if (id is int) {
            ids.add(id);
          } else {
            final parsed = int.tryParse('$id');
            if (parsed != null) ids.add(parsed);
          }
        }
      }
    }
    return ids;
  }

  // POST /payments/create-order  -> { orderId, amount(paise), keyId }
  Future<Map<String, dynamic>?> _createOrder({
    required String? token,
    required int bookingId,
    required int amount, // rupees
  }) async {
    final res = await http.post(
      Uri.parse("$_apiBase/payments/create-order"),
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "bookingType": _bookingType,
        "bookingId": bookingId,
        "amount": amount,
      }),
    );

    print("📦 create-order (${res.statusCode}): ${res.body}");

    if (res.statusCode == 200 || res.statusCode == 201) {
      final data = jsonDecode(res.body);
      return data['data'] as Map<String, dynamic>?;
    }
    return null;
  }



  /* ❌ Cash-only booking removed — online only (used old verify-payment-app API)
  Future<void> _storeBookingCashOnly({
    required String email,
    required String name,
    required List<Map<String, dynamic>> slots,
    required String date,
    required String courtName,
    required int cashAmount,
  }) async {
    if (isLoading) return;
    setState(() => isLoading = true);

    try {
      final total =
          (widget.bookingDetails['price'] as num?)?.toInt() ?? 0;


      final bookingData = {
        "selected_date": date,
        "selected_courts": [courtName],
        "selected_slots": slots
            .where((s) => s['time'] != null)
            .map((s) => {
          "court": s['court'],
          "time": s['time'],
          "date": s['date'],
        })
            .toList(),

        // "selected_slots": slots.map((s) => s['time']).toList(),
        "total_amount": total,
        "email": email,
        "name": email, // or user name
        "amount_paid": 0,
        "cash_amount": cashAmount,
        "booked_by": name,
        "location_id": widget.bookingDetails['location_id'] ?? 1,
      };


      print("📤 CASH BOOKING PAYLOAD: $bookingData");

      final res = await http.post(
         Uri.parse("https://nahatasports.com/api/verify-payment-app"),
        // Uri.parse("https://demo.nahatasports.com/booking/paymentverify"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode(bookingData),
      );
      print("🧪 onlinePaid:  0| cashAmount: $cashAmount | total:0");

      print("📥 CASH API RESPONSE (${res.statusCode}): ${res.body}");
      print(res);
      if (res.statusCode == 200) {
        // 🔔 Show booking notification
        final slotText = slots
            .map((s) => s['time']?.toString() ?? '')
            .where((t) => t.isNotEmpty)
            .join(', ');

        await showBookingConfirmedNotification(
          date: date,
          slot: slotText,
          totalAmount: total,
        );
        _showSuccessDialog();
      } else {
        _showErrorDialog("Cash booking failed");
      }
    } catch (e) {
      _showErrorDialog(e.toString());
    } finally {
      setState(() => isLoading = false);
    }
    // print(res);
  }
  */

  // 🔄 NEW API: verify the payment against every reserved booking id.
  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    print("🎉 Payment Success");
    print("PaymentId: ${response.paymentId}");
    print("OrderId: ${response.orderId}");
    print("Signature: ${response.signature}");

    final token = await _getAuthToken();

    bool allVerified = _bookingIds.isNotEmpty;
    String? failMessage;

    for (final bookingId in _bookingIds) {
      final ok = await _verifyPayment(
        token: token,
        bookingId: bookingId,
        orderId: response.orderId ?? _rzpOrderId ?? '',
        paymentId: response.paymentId ?? '',
        signature: response.signature ?? '',
      );
      if (!ok) {
        allVerified = false;
        failMessage = "Payment verification failed for booking #$bookingId";
      }
    }

    if (!mounted) return;
    setState(() => isLoading = false);

    if (allVerified) {
      final total = (widget.bookingDetails['price'] as num?)?.toInt() ?? 0;
      final List slots = widget.bookingDetails['slots'] ?? [];
      final slotText = slots
          .map((s) => (s is Map ? s['time']?.toString() : s.toString()) ?? '')
          .where((t) => t.isNotEmpty)
          .join(', ');
      await showBookingConfirmedNotification(
        date: widget.bookingDetails['date']?.toString() ?? '',
        slot: slotText,
        totalAmount: total,
      );
      _showSuccessDialog();
    } else {
      _showErrorDialog(failMessage ?? "Payment verification failed");
    }
  }
  // void _handlePaymentSuccess(PaymentSuccessResponse response) async {
  //   setState(() => isLoading = true); // Keep loading during verification
  //     print("🎉 Payment Success");
  //     print("PaymentId: ${response.paymentId}");
  //     print("OrderId: ${response.orderId}");
  //     print("Signature: ${response.signature}");
  //   final email = await _getUserEmail();
  //   final name = await _getUserName();
  //
  //   if (email == null || name == null) {
  //     _showErrorDialog("Session expired. Please login again.");
  //     return;
  //   }
  //
  //   final List<Map<String, dynamic>> slots =
  //   List<Map<String, dynamic>>.from(widget.bookingDetails['slots']);
  //
  //   final courtName = slots.isNotEmpty ? slots.first['court']?.toString() ?? '' : '';
  //
  //   // Get financial details
  //   final double totalAmount = (widget.bookingDetails['price'] as num?)?.toDouble() ?? 0.0;
  //   final double cashAmount = (widget.bookingDetails['cash'] as num?)?.toDouble() ?? 0.0;
  //
  //   // Logic: Online Paid = Total - What user promised to pay in cash later
  //   // final double onlinePaid = totalAmount - cashAmount;
  //   final int onlinePaid = (totalAmount - cashAmount).round();
  //
  //   if (onlinePaid <= 0) {
  //     _showErrorDialog("Invalid partial payment amount");
  //     setState(() => isLoading = false);
  //     return;
  //   }
  //
  //   // final bookingData = {
  //   //   "razorpay_payment_id": response.paymentId,
  //   //   "razorpay_order_id": response.orderId,
  //   //   "razorpay_signature": response.signature,
  //   //   "selected_date": widget.bookingDetails['date'],
  //   //   "court_name": courtName,
  //   //   "selected_slots": slots, // This will be json_encoded by the PHP side
  //   //   "total_amount": totalAmount,
  //   //   "online_paid": onlinePaid, // ✅ MATCHES PHP: 'online_paid'
  //   //   "booked_by": name,
  //   //   "email": email
  //   // };
  //
  //   final bookingData = {
  //     "razorpay_payment_id": response.paymentId,
  //     "razorpay_order_id": response.orderId,
  //     "razorpay_signature": response.signature,
  //     "selected_date": widget.bookingDetails['date'],
  //     "selected_courts": [courtName],
  //     "selected_slots": slots.map((s) => {
  //       "court": s['court'],
  //       "time": s['time'],
  //       "date": s['date'],
  //     }).toList(),
  //     "total_amount": (onlinePaid + cashAmount).toInt(), // ✅ FIX
  //     "email": email,
  //     "name": name,
  //     "amount_paid": onlinePaid,
  //     "cash_amount": cashAmount
  //   };
  //   // final bookingData = {
  //   //   "razorpay_payment_id": response.paymentId,
  //   //   "razorpay_order_id": response.orderId,
  //   //   "razorpay_signature": response.signature,
  //   //   "selected_date": widget.bookingDetails['date'],
  //   //   "selected_courts": [courtName],
  //   //   "selected_slots": slots
  //   //       .where((s) => s['time'] != null)
  //   //       .map((s) => {
  //   //     "court": s['court'],
  //   //     "time": s['time'],
  //   //     "date": s['date'],
  //   //   })
  //   //       .toList(),
  //   //
  //   //   // "selected_slots": slots.map((s) => s['time']).toList(),
  //   //   "total_amount": totalAmount.toInt(),
  //   //   "email": email,
  //   //   "name": name,
  //   //   "amount_paid": onlinePaid.toInt(),
  //   //   "cash_amount": cashAmount.toInt()
  //   // };
  //   print("🧪 onlinePaid: $onlinePaid | cashAmount: $cashAmount | total: $totalAmount");
  //
  //   print("📤 Verifying Partial/Full Payment: $bookingData");
  //   await _verifyPayment(bookingData);
  //   print("🧪 onlinePaid: $onlinePaid | cashAmount: $cashAmount | total: $totalAmount");
  //
  // }



  // ---------------------- OLD API (commented out) ----------------------
  // Future<void> _verifyPayment(Map<String, dynamic> data) async {
  //   final res = await http.post(
  //     Uri.parse("https://nahatasports.com/api/verify-payment-app"),
  //     headers: {"Content-Type": "application/json"},
  //     body: jsonEncode(data),
  //   );
  //
  //   final result = jsonDecode(res.body);
  // print(res);
  // print(res.body);
  // print(res.statusCode);
  //   if (result["success"] == true) {
  //     _showSuccessDialog();
  //   } else {
  //     _showErrorDialog(result["message"]);
  //   }
  // }

  // ---------------------- NEW API: POST /payments/verify ----------------------
  Future<bool> _verifyPayment({
    required String? token,
    required int bookingId,
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    try {
      final res = await http.post(
        Uri.parse("$_apiBase/payments/verify"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "bookingType": _bookingType,
          "bookingId": bookingId,
          "razorpay_order_id": orderId,
          "razorpay_payment_id": paymentId,
          "razorpay_signature": signature,
        }),
      );

      print("📥 verify (${res.statusCode}): ${res.body}");

      final result = jsonDecode(res.body);
      return result["success"] == true;
    } catch (e) {
      print("❌ verify error: $e");
      return false;
    }
  }

  // Future<void> _verifyPayment(Map<String, dynamic> data) async {
  //   try {
  //     final res = await http.post(
  //       Uri.parse("https://nahatasports.com/api/verify-payment-app"),
  //       headers: {
  //         "Content-Type": "application/json",
  //         "Accept": "application/json",
  //       },
  //       body: jsonEncode(data),
  //     );
  //
  //     print("📥 Verify Payment Response: ${res}");
  //     print(data);
  //     print("✅ Verify Response: ${res.body}");
  //
  //     if (res.statusCode == 200) {
  //       final result = jsonDecode(res.body);
  //       if (result["success"] == true) {
  //         setState(() => isLoading = false); // ✅ ADD THIS
  //         _showSuccessDialog();
  //         print("🎉 Booking confirmed: ${result["data"]["booking_id"]}");
  //         // ✅ Extract slots safely
  //         // final List slots = data["selected_slots"] ?? [];
  //         //
  //         // final String slotText = slots
  //         //     .map((s) => s["time"]?.toString() ?? "")
  //         //     .where((t) => t.isNotEmpty)
  //         //     .join(", ");
  //         final List slots = data["selected_slots"] ?? [];
  //
  //         final String slotText = slots
  //             .map((s) => s.toString())
  //             .where((t) => t.isNotEmpty)
  //             .join(", ");
  //
  //         final int totalAmount =
  //             (data["total_amount"] as num?)?.toInt() ?? 0;
  //
  //         await showBookingConfirmedNotification(
  //           date: data["selected_date"] ?? "",
  //           slot: slotText,
  //           totalAmount: totalAmount,
  //         );
  //
  //         // _showSuccessDialog();
  //       } else {
  //         _showErrorDialog("Payment verification failed");
  //       }
  //     } else {
  //       _showErrorDialog("Server error");
  //     }
  //   } catch (e) {
  //     _showErrorDialog("Verification error: $e");
  //   }
  // }



  void _handlePaymentError(PaymentFailureResponse response) {
    setState(() => isLoading = false);

    print("❌ Payment Error: ${response.code} - ${response.message}");

    if (response.code == 2) {
      _showErrorDialog(
          "Payment was cancelled or not completed.\nPlease try again."
      );
    } else {
      _showErrorDialog(response.message ?? "Payment failed");
    }
  }

  // void _handlePaymentError(PaymentFailureResponse response) {
  //   print("❌ Payment Error: ${response.code} - ${response.message}");
  //   String errorMessage = response.message ?? "Payment failed";
  //   _showErrorDialog(errorMessage);
  // }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline, color: Colors.red, size: 48),
            ),
            SizedBox(height: 16),
            Text(
              "Payment Failed",
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        // content: Text(
        //   message,
        //   textAlign: TextAlign.center,
        //   style: TextStyle(
        //     fontSize: 14,
        //     color: Colors.black87,
        //   ),
        // ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: brandBlue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                "OK",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  void _handleExternalWallet(ExternalWalletResponse response) {
    print("🔗 External Wallet: ${response.walletName}");
    _showErrorDialog(
        "Payment via ${response.walletName} is not supported currently.");
  }


  // 🔄 NEW API flow: reserve booking(s) -> create order -> open Razorpay.
  void _handleOnlinePayment() async {
    if (isLoading) return;

    if (!await _isLoggedIn()) {
      _showErrorDialog("Please log in to make a payment.");
      return;
    }

    final total = (widget.bookingDetails['price'] as num?)?.toInt() ?? 0;
    final cash = (widget.bookingDetails['cash'] as num?)?.toInt() ?? 0;
    final onlineAmount = total - cash;

    if (onlineAmount <= 0) {
      _showErrorDialog("Invalid payment amount.");
      return;
    }

    final slots =
        List<Map<String, dynamic>>.from(widget.bookingDetails['slots'] ?? []);
    if (slots.isEmpty) {
      _showErrorDialog("No slots selected.");
      return;
    }

    try {
      setState(() => isLoading = true);

      final token = await _getAuthToken();

      // ✅ STEP 1: RESERVE BOOKING(S)
      _bookingIds = await _createBookings(token: token, slots: slots);
      if (_bookingIds.isEmpty) {
        setState(() => isLoading = false);
        _showErrorDialog("Unable to reserve the slot(s). Please try again.");
        return;
      }

      // ✅ STEP 2: CREATE PAYMENT ORDER (for the total, against the first booking)
      // NOTE: multi-slot uses one order tied to the primary booking id, then
      // verifies every booking id on success. Adjust if the backend exposes a
      // dedicated multi-booking order endpoint.
      final orderData = await _createOrder(
        token: token,
        bookingId: _bookingIds.first,
        amount: onlineAmount,
      );

      if (orderData == null || orderData['orderId'] == null) {
        setState(() => isLoading = false);
        _showErrorDialog("Unable to create order. Please try again.");
        return;
      }

      // Everything (key, order, amount, currency) comes from the backend
      // create-order response — nothing hardcoded on the client.
      _rzpOrderId = orderData['orderId']?.toString();
      _rzpKeyId = orderData['keyId']?.toString();

      final email = (await _getUserEmail()) ?? '';
      final phone = widget.bookingDetails['phone']?.toString() ?? '';

      final options = {
        'key': _rzpKeyId,
        'order_id': _rzpOrderId,
        if (orderData['amount'] != null) 'amount': orderData['amount'],
        'currency': (orderData['currency'] ?? 'INR').toString(),
        'name': 'Nahata Sports',
        'description': '${widget.bookingDetails['game']} booking',
        'prefill': {
          if (email.isNotEmpty) 'email': email,
          if (phone.isNotEmpty) 'contact': phone,
        },
      };

      // ✅ Small delay prevents ANR
      await Future.delayed(const Duration(milliseconds: 200));

      _razorpay.open(options);
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorDialog('Payment gateway error: ${e.toString()}');
    }
  }


  /* ❌ Cash payment removed — online only
  void _handleCashPayment() async {
    if (isLoading) return;
    if (!await _isLoggedIn()) {
      _showErrorDialog("Please log in to make a booking.");
      return;
    }
    _showCashBookingDialog();
  }
  void _showCashBookingDialog() {
    final TextEditingController _cashController = TextEditingController();
    final total = (widget.bookingDetails['price'] as num?)?.toInt() ?? 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: brandBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.money, color: brandBlue, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                "Cash Payment",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Enter the amount you'll pay in cash at the venue:"),
            const SizedBox(height: 16),
            TextField(
              controller: _cashController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Cash Amount",
                hintText: "₹0 - ₹$total",
                prefixIcon: const Icon(Icons.currency_rupee),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final cash = int.tryParse(_cashController.text.trim()) ?? 0;

              if (cash < 0 || cash > total) {
                _showSnackBar(
                  "Enter amount between 0 and $total",
                  isError: true,
                );
                return;
              }

              Navigator.pop(context);

              final email = await _getUserEmail();
              if (email == null) {
                _showErrorDialog("Session expired. Please login again.");
                return;
              }
              final name = await _getUserName();
              if (name == null) {
                _showErrorDialog("Session expired. Please login again.");
                return;
              }

              final slots =
              List<Map<String, dynamic>>.from(widget.bookingDetails['slots']);

              if (slots.isEmpty) {
                _showErrorDialog("Slot information missing.");
                return;
              }

              final courtName = slots.first['court']?.toString() ?? '';
              if (courtName.isEmpty) {
                _showErrorDialog("Court name missing.");
                return;
              }

              final onlineAmount = total - cash;

              // 💵 FULL CASH PAYMENT
              if (onlineAmount == 0) {
                await _storeBookingCashOnly(
                  name: name,
                  email: email,
                  slots: slots, // ✅ LIST
                  date: widget.bookingDetails['date']?.toString() ?? '',
                  courtName: courtName,
                  cashAmount: cash,
                );
              }

              // 💳 PARTIAL CASH → ONLINE
              else {
                widget.bookingDetails['cash'] = cash;
                _showSnackBar(
                  "Proceeding to pay ₹$onlineAmount online",
                  isError: false,
                );
                await Future.delayed(const Duration(milliseconds: 400));
                _handleOnlinePayment();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: brandBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              "Confirm",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
  */

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Column(
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle, color: Colors.green[600], size: 48),
              ),
              SizedBox(height: 16),
              Text(
                "Booking Confirmed!",
                style: TextStyle(
                  color: Colors.green[700],
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Your booking has been confirmed successfully!",
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12),
              Text(
                "You will receive a confirmation mail shortly.",
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {

                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => CustomBottomNav()),
                        (Route<dynamic> route) => false, // remove all previous routes
                  );
                },
                child: Text("Continue"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red : Colors.green,
    ));
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  static const brandBlue = Color(0xFF1A237E);


  @override
  Widget build(BuildContext context) {
    final booking = widget.bookingDetails;
    final total = booking['price'] as int? ?? 0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: isLoading ? null : () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back, color: Colors.black87),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${booking['game']?.toString() ?? 'Game'}",
              style: TextStyle(
                color: Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              "at ${booking['location']?.toString() ?? 'Location'}",
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Venue Rules Section
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Venue Rule & Cancellation Policy",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "• Check cancellation terms",
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        Text(
                          "• Know the venues T&Cs",
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 24),

                  // Slot Details Section
                  Text(
                    "Slot Details(${_getSlotCount(booking['slots'])})",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),


                  SizedBox(height: 16),

                  // Selected Slots
                  ..._buildSlotsList(booking['slots']),

                  SizedBox(height: 24),

                  // Booking Summary Section
                  Text(
                    "Booking Summary",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),

                  SizedBox(height: 16),

                  // Summary Details
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildSummaryRow2(
                          "Sports",
                          booking['game']?.toString() ?? 'N/A',
                        ),
                        SizedBox(height: 12),
                        _buildSummaryRow2(
                          "Total Slot(s) Base Price(Incl.Taxes)",
                          "₹${total}",
                        ),
                        SizedBox(height: 16),
                        Divider(height: 1, color: Colors.grey.shade300),
                        SizedBox(height: 16),
                        _buildSummaryRow2(
                          "Slot Total",
                          "₹${total}",
                          isBold: true,
                        ),
                        SizedBox(height: 16),
                        Divider(height: 1, color: Colors.grey.shade300),
                        SizedBox(height: 16),
                        _buildSummaryRow2(
                          "Payable Amount",
                          "₹${total}",
                          isBold: true,
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 24),

                  // Checkbox
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: agreedToTerms,
                        onChanged: (value) {
                          setState(() {
                            agreedToTerms = value ?? false;
                          });
                        },
                        activeColor: Colors.green,
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              agreedToTerms = !agreedToTerms;
                            });
                          },
                          child: Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Text(
                              "I hereby agree to the terms and conditions",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 24),

                  // Payment Method Section
                  Text(
                    "Payment Method",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 16),

                  // Payment Options
                  _buildPaymentOption(
                    title: "Pay Online",
                    subtitle: "UPI, Cards, Net Banking, Wallets",
                    icon: Icons.credit_card,
                    value: 'online',
                    isSelected: selectedPaymentMethod == 'online',
                  ),
                  // SizedBox(height: 12),
                  // _buildPaymentOption(
                  //   title: "Pay with Cash at Venue",
                  //   subtitle: "Pay when you arrive at the venue",
                  //   icon: Icons.money,
                  //   value: 'cash',
                  //   isSelected: selectedPaymentMethod == 'cash',
                  // ),
                ],
              ),
            ),
          ),

          // Bottom Payment Button
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: brandBlue,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  // Online only — cash method removed
                  onPressed: (isLoading || total <= 0 || !agreedToTerms)
                      ? null
                      : _handleOnlinePayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: brandBlue,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    disabledBackgroundColor: Colors.grey[400],
                  ),
                  child: isLoading
                      ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(brandBlue),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        "Processing...",
                        style: TextStyle(
                          color: brandBlue,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                      : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "₹${total} Incl.Taxes",
                        style: TextStyle(
                          color: brandBlue,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(width: 60),
                      Text(
                        "PROCEED TO PAY",
                        style: TextStyle(
                          color: brandBlue,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 5),
                      Icon(Icons.arrow_forward, color: brandBlue, size: 13),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow2(String title, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
        SizedBox(width: 16),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            color: Colors.black87,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  int _getSlotCount(dynamic slots) {
    if (slots == null) return 0;
    if (slots is List) return slots.length;
    return 0;
  }

  List<Widget> _buildSlotsList(dynamic slots) {
    if (slots == null || slots is! List || slots.isEmpty) {
      return [
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            "No slots selected",
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      ];
    }

    // ✅ Group slots by date
    Map<String, List<Map<String, dynamic>>> groupedSlots = {};
    for (var slot in slots) {
      if (slot is Map<String, dynamic>) {
        String date = slot['date']?.toString() ?? 'Unknown Date';
        if (!groupedSlots.containsKey(date)) groupedSlots[date] = [];
        groupedSlots[date]!.add(slot);
      }
    }

    // ✅ Build UI grouped by date
    return groupedSlots.entries.map<Widget>((entry) {
      final date = entry.key;
      final slotList = entry.value;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date Header
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Text(
              "📅 $date",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),

          // Slot List for this date
          ...slotList.asMap().entries.map((entry2) {
            final slot = entry2.value;
            final index = entry2.key;
            final time = slot['time']?.toString() ?? 'Time not set';
            final court = slot['court']?.toString() ?? 'Court not set';

            return Container(
              margin: EdgeInsets.only(bottom: 8),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Slot Info
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        court,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),

                  // Remove Button
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        (widget.bookingDetails['slots'] as List)
                            .removeWhere((s) =>
                        s['time'] == time &&
                            s['court'] == court &&
                            s['date'] == date);
                      });

                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text("Slot removed successfully"),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 2),
                      ));
                    },
                    child: Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close, color: Colors.red, size: 16),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      );
    }).toList();
  }

  Widget _buildPaymentOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required String value,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : () {
        setState(() {
          selectedPaymentMethod = value;
        });
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Color(0xFF1A237E) : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
            if (isSelected)
              BoxShadow(
                color:Color(0xFF1A237E).withOpacity(0.1),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: Duration(milliseconds: 200),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? Color(0xFF1A237E).withOpacity(0.1) : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? Color(0xFF1A237E): Colors.grey[600],
                size: 24,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.black87 : Colors.black54,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: Duration(milliseconds: 200),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Color(0xFF1A237E): Colors.grey[400]!,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 200),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF1A237E),
                  ),
                ),
              )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  String _formatSlots(dynamic slots) {
    if (slots == null) return 'N/A';

    try {
      if (slots is List && slots.isNotEmpty) {
        return slots
            .map((slot) {
          if (slot is Map<String, dynamic>) {
            final court = slot['court']?.toString() ?? 'Court';
            final time = slot['time']?.toString() ?? 'Time';
            return "$court ($time)";
          }
          return slot.toString();
        })
            .join(", ");
      }
      return slots.toString();
    } catch (e) {
      print("❌ Error formatting slots: $e");
      return 'Invalid slot format';
    }
  }
}


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Widget build(BuildContext context) {
//   final booking = widget.bookingDetails;
//   final total = booking['price'] as int? ?? 0;
//
//   return Scaffold(
//     backgroundColor: Colors.grey[50],
//     body: SafeArea(
//       child: Column(
//         children: [
//           // Custom App Bar
//           Container(
//             padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(0.05),
//                   blurRadius: 8,
//                   offset: Offset(0, 2),
//                 ),
//               ],
//             ),
//             child: Row(
//               children: [
//                 IconButton(
//                   onPressed: isLoading ? null : () => Navigator.pop(context),
//                   icon: Icon(Icons.arrow_back_ios, size: 20),
//                   style: IconButton.styleFrom(
//                     backgroundColor: Colors.grey[100],
//                     padding: EdgeInsets.all(8),
//                   ),
//                 ),
//                 SizedBox(width: 16),
//                 Text(
//                   "Complete Your Payment",
//                   style: TextStyle(
//                     fontSize: 18,
//                     fontWeight: FontWeight.w600,
//                     color: Colors.black87,
//                   ),
//                 ),
//                 Spacer(),
//                 if (isLoading)
//                   SizedBox(
//                     width: 20,
//                     height: 20,
//                     child: CircularProgressIndicator(
//                       strokeWidth: 2,
//                       valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A237E)),
//                     ),
//                   ),
//               ],
//             ),
//           ),
//
//           // Main Content
//           Expanded(
//             child: SingleChildScrollView(
//               padding: EdgeInsets.all(20),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   // Booking Summary Card
//                   Container(
//                     decoration: BoxDecoration(
//                       gradient: LinearGradient(
//                         colors: [Color(0xFF1A237E), Color(0xFF1A237E)],
//                         begin: Alignment.topLeft,
//                         end: Alignment.bottomRight,
//                       ),
//                       borderRadius: BorderRadius.circular(20),
//                       boxShadow: [
//                         BoxShadow(
//                           color: Color(0xFF1A237E).withOpacity(0.3),
//                           blurRadius: 20,
//                           offset: Offset(0, 8),
//                         ),
//                       ],
//                     ),
//                     child: Stack(
//                       children: [
//                         // Background pattern/image can be added here
//                         Positioned(
//                           right: -20,
//                           top: -20,
//                           child: Container(
//                             width: 120,
//                             height: 120,
//                             decoration: BoxDecoration(
//                               color: Colors.white.withOpacity(0.1),
//                               shape: BoxShape.circle,
//                             ),
//                           ),
//                         ),
//                         Padding(
//                           padding: EdgeInsets.all(24),
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Row(
//                                 children: [
//                                   Icon(
//                                     Icons.sports_basketball,
//                                     color: Colors.white,
//                                     size: 24,
//                                   ),
//                                   SizedBox(width: 12),
//                                   Text(
//                                     "Booking Summary",
//                                     style: TextStyle(
//                                       color: Colors.white,
//                                       fontSize: 20,
//                                       fontWeight: FontWeight.bold,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                               SizedBox(height: 20),
//                               _buildSummaryRow("Location", booking['location']?.toString() ?? 'N/A'),
//                               _buildSummaryRow("Game", booking['game']?.toString() ?? 'N/A'),
//                               _buildSummaryRow("Date", booking['date']?.toString() ?? 'N/A'),
//                               _buildSummaryRow("Slots", _formatSlots(booking['slots'])),
//                               SizedBox(height: 16),
//                               Divider(color: Colors.white.withOpacity(0.3), thickness: 1),
//                               SizedBox(height: 16),
//                               Row(
//                                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                 children: [
//                                   Text(
//                                     "Total Amount",
//                                     style: TextStyle(
//                                       color: Colors.white,
//                                       fontSize: 18,
//                                       fontWeight: FontWeight.w600,
//                                     ),
//                                   ),
//                                   Text(
//                                     "₹ ${total.toStringAsFixed(2)}",
//                                     style: TextStyle(
//                                       color: Colors.white,
//                                       fontSize: 24,
//                                       fontWeight: FontWeight.bold,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//
//                   SizedBox(height: 32),
//
//                   // Payment Method Section
//                   Text(
//                     "Payment Method",
//                     style: TextStyle(
//                       fontSize: 20,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.black87,
//                     ),
//                   ),
//                   SizedBox(height: 16),
//
//                   // Payment Options
//                   _buildPaymentOption(
//                     title: "Pay Online",
//                     subtitle: "UPI, Cards, Net Banking, Wallets",
//                     icon: Icons.credit_card,
//                     value: 'online',
//                     isSelected: selectedPaymentMethod == 'online',
//                   ),
//                   SizedBox(height: 12),
//                   _buildPaymentOption(
//                     title: "Pay with Cash at Venue",
//                     subtitle: "Pay when you arrive at the venue",
//                     icon: Icons.money,
//                     value: 'cash',
//                     isSelected: selectedPaymentMethod == 'cash',
//                   ),
//                 ],
//               ),
//             ),
//           ),
//
//           // Bottom Payment Button
//           Container(
//             padding: EdgeInsets.all(20),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(0.1),
//                   blurRadius: 10,
//                   offset: Offset(0, -2),
//                 ),
//               ],
//             ),
//             child: SafeArea(
//               child: SizedBox(
//                 width: double.infinity,
//                 height: 56,
//                 child: ElevatedButton(
//                   onPressed: (isLoading || total <= 0) ? null : (selectedPaymentMethod == 'online'
//                       ? _handleOnlinePayment
//                       : _handleCashPayment),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Color(0xFF1A237E),
//                     elevation: 8,
//                     shadowColor: Color(0xFF1A237E).withOpacity(0.4),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(16),
//                     ),
//                     disabledBackgroundColor: Colors.grey[400],
//                   ),
//                   child: isLoading
//                       ? Row(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       SizedBox(
//                         width: 20,
//                         height: 20,
//                         child: CircularProgressIndicator(
//                           strokeWidth: 2,
//                           valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//                         ),
//                       ),
//                       SizedBox(width: 12),
//                       Text(
//                         "Processing...",
//                         style: TextStyle(
//                           color: Colors.white,
//                           fontSize: 18,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     ],
//                   )
//                       : Text(
//                     selectedPaymentMethod == 'online'
//                         ? "Pay Online ₹${total.toStringAsFixed(2)}"
//                         : "Set Cash Payment",
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontSize: 18,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     ),
//   );
// }
//
// Widget _buildSummaryRow(String title, String value) {
//   return Padding(
//     padding: EdgeInsets.only(bottom: 8),
//     child: Row(
//       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       children: [
//         Text(
//           title,
//           style: TextStyle(
//             color: Colors.white.withOpacity(0.9),
//             fontSize: 14,
//           ),
//         ),
//         Flexible(
//           child: Text(
//             value,
//             textAlign: TextAlign.right,
//             style: TextStyle(
//               color: Colors.white,
//               fontSize: 14,
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//         ),
//       ],
//     ),
//   );
// }
//
//
// Future<void> _storeBooking({
//   required String email,
//   required String slot,
//   required String date,
//   required String courtName,
//   required String transactionId,
//   required String razorpayPaymentId,
//   required String razorpayOrderId,
//   required String razorpaySignature,
//   required int cashAmount,
//   required int onlinePaid,
// }) async {
//   if (isLoading) return;
//
//   setState(() => isLoading = true);
//
//   try {
//     final price =
//         (widget.bookingDetails['price'] as num?)?.toInt() ?? 0;
//     final actualOnlinePaid = onlinePaid;
//
//     final txnId = (actualOnlinePaid > 0 && transactionId.isNotEmpty)
//         ? transactionId
//         : "CASH-${DateTime.now().millisecondsSinceEpoch}";
//
//     final formattedDate = date.isNotEmpty
//         ? date
//         : DateTime.now().toIso8601String().split("T").first;
//
//     final bookingData = {
//       "transaction_id": txnId,
//       "razorpay_payment_id":
//       transactionId.isNotEmpty ? transactionId : "N/A",
//       "selected_date": formattedDate,
//       "selected_slots": slot,
//       "total_amount": price.toString(),
//       "booked_by": email,
//       "amount_paid": actualOnlinePaid,
//       "cash_amount": cashAmount,
//       // "razorpay_payment_id": razorpayPaymentId,
//       "razorpay_order_id": razorpayOrderId,
//       "razorpay_signature": razorpaySignature,
//       "status": (actualOnlinePaid > 0 && cashAmount > 0)
//           ? "partial"
//           : "full",
//       "created_at": DateTime.now().toIso8601String(),
//     };
//
//     print("🔍 Booking Data: $bookingData");
//
//     final res = await http
//         .post(
//       Uri.parse("https://nahatasports.com/api/verifyPayment"),
//       headers: {
//         "Content-Type": "application/json",
//         "Accept": "application/json",
//       },
//       body: jsonEncode(bookingData),
//     )
//         .timeout(const Duration(seconds: 30));
//
//     print("📥 API Response (${res.statusCode}): ${res.body}");
//
//     if (res.statusCode == 200) {
//       final data = jsonDecode(res.body);
//       if (data["success"] == true || data["status"] == true) {
//
//         // 🔔 Show booking notification
//         await showBookingConfirmedNotification(
//           date: formattedDate,
//           slot: slot,
//           totalAmount: price,
//         );
//
//
//         _showSuccessDialog();
//       } else {
//         _showErrorDialog(
//             "Booking failed: ${data["message"] ?? 'Unknown error'}");
//       }
//     } else {
//       _showErrorDialog("Server error (${res.statusCode})");
//     }
//   } catch (e) {
//     print("❌ API Error: $e");
//     _showErrorDialog("Network error: ${e.toString()}");
//   } finally {
//     setState(() => isLoading = false);
//   }
// }
//





// void _handleOnlinePayment() async {
//   if (isLoading) return;
//
//   if (!await _isLoggedIn()) {
//     _showErrorDialog("Please log in to make a payment.");
//     return;
//   }
//
//   try {
//     final total = (widget.bookingDetails['price'] as num?)?.toInt() ?? 0;
//     final cash = (widget.bookingDetails['cash'] as num?)?.toInt() ?? 0;
//     final onlineAmount = total - cash;
//     if (onlineAmount <= 0) {
//       _showErrorDialog("Invalid payment amount. Online amount must be > 0.");
//       return;
//     }
//     setState(() => isLoading = true);
//     // _razorpay.open(options);
//     // 🔹 CREATE ORDER FIRST
//     final orderId = await _createRazorpayOrder(onlineAmount);
//
//     if (orderId == null) {
//       setState(() => isLoading = false);
//       _showErrorDialog("Unable to create order. Please try again.");
//       return;
//     }
//     final email = await _getUserEmail();
//     final phone = widget.bookingDetails['phone']?.toString() ?? '';
//
//     var options = {
//       // 'key': 'rzp_live_R7b5MMCgg9AlWn',
//         'key': 'rzp_test_YwYUHvAMatnKBY',
//       'order_id': orderId,
//       'amount': onlineAmount * 100,
//       'name': 'Nahata Sports',
//       'description': '${widget.bookingDetails['game'] ?? 'Sports'} booking',
//       'currency': 'INR',
//       'prefill': {'contact': phone, 'email': email},
//       'method': {'upi': true, 'card': true, 'netbanking': true, 'wallet': true},
//       'theme': {'color': '#4A90E2'},
//       // REMOVE the invalid 'modal' key
//     };
//
//     _razorpay.open(options);
//   } catch (e) {
//     _showErrorDialog('Payment gateway error: ${e.toString()}');
//   }
//   finally {
//     setState(() => isLoading = false);
//   }
// }

// Future<String?> _createRazorpayOrder(int amount) async {
//   try {
//     final res = await http.post(
//       Uri.parse("https://nahatasports.com/api/create-order-app"),
//       headers: {
//         "Content-Type": "application/json",
//         "Accept": "application/json",
//       },
//       body: jsonEncode({
//         // "amount": amount,
//         "online_paid": 1,
//         "total_amount": 200
//       }),
//     );
//
//     print("📦 Create Order Response: ${res.body}");
//
//     if (res.statusCode == 200) {
//       final data = jsonDecode(res.body);
//       if (data["success"] == true) {
//         return data["order_id"];
//       }
//     }
//   } catch (e) {
//     print("❌ Create Order Error: $e");
//   }
//   return null;
// }
// void _handlePaymentSuccess(PaymentSuccessResponse response) async {
//   setState(() => isLoading = false);
//
//   print("🎉 Payment Success");
//   print("PaymentId: ${response.paymentId}");
//   print("OrderId: ${response.orderId}");
//   print("Signature: ${response.signature}");
//
//   final email = await _getUserEmail();
//   if (email == null) {
//     _showErrorDialog("Session expired. Please login again.");
//     return;
//   }
//
//   final name = await _getUserName();
//   if (name == null) {
//     _showErrorDialog("Session expired. Please login again.");
//     return;
//   }
//
//
//   final List<Map<String, dynamic>> slots =
//   List<Map<String, dynamic>>.from(widget.bookingDetails['slots']);
//
//   final courtName =
//   slots.isNotEmpty ? slots.first['court']?.toString() ?? '' : '';
//
//
//
//
//
//   if (courtName.isEmpty) {
//     _showErrorDialog("Court name missing. Please try again.");
//     return;
//   }
//
//   final int cashAmount =
//       (widget.bookingDetails['cash'] as num?)?.toInt() ?? 0;
//
//   final int totalAmount =
//       (widget.bookingDetails['price'] as num?)?.toInt() ?? 0;
//
//   final int onlinePaid = totalAmount - cashAmount;
//
//   final bookingData = {
//     "transaction_id": response.paymentId,
//     "razorpay_payment_id": response.paymentId,
//     "razorpay_order_id": response.orderId,
//     "razorpay_signature": response.signature,
//     "selected_date": widget.bookingDetails['date'],
//     "court_name": courtName,
//     // "selected_court": courtName,
//     "selected_slots": slots,
//     "total_amount": totalAmount,
//     // "amount_paid": onlinePaid, // ✅ FIXED
//     "online_paid": onlinePaid,
//     "cash_amount": cashAmount,
//     "booked_by": email,
//     // "email": email
//   };
//
//
//   print("📤 Verify Payment Payload: $bookingData");
//
//   await _verifyPayment(bookingData);
// }
//
// Future<String?> _createRazorpayOrder(int amountInRupees) async                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  {
//   try {
//     final res = await http.post(
//       Uri.parse("https://nahatasports.com/api/create-order-app"),
//       headers: {"Content-Type": "application/json"},
//       body: jsonEncode({
//         "amount": amountInRupees, // Send as Rupees (e.g. 500)
//       }),
//     );
//     print("📦 Create Order Response: ${res.body}");
//     if (res.statusCode == 200) {
//       final data = jsonDecode(res.body);
//       if (data["success"] == true) return data["order_id"];
//     }
//   } catch (e) {
//     print("❌ Order Error: $e");
//   }
//   return null;
// }