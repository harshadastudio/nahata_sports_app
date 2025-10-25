import 'dart:convert';
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

import 'Custombottombar.dart';

// Import your existing API service - uncomment when available
// import '../services/api_service.dart';

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

  // Future<String?> _getUserEmail() async {
  //   try {
  //     SharedPreferences prefs = await SharedPreferences.getInstance();
  //     final email =
  //         prefs.getString('userEmail') ?? prefs.getString('email') ?? '';
  //     return email.isNotEmpty ? email : null;
  //   } catch (e) {
  //     print("❌ SharedPreferences error: $e");
  //     return null;
  //   }
  // }

  Future<bool> _isLoggedIn() async {
    final email = await _getUserEmail();
    if (email == null) print("❌ User not logged in - missing email");
    return email != null;
  }

  Future<void> _storeBooking({
    required String email,
    required String slot,
    required String date,
    required String transactionId,
    required int cashAmount,
    required int onlinePaid,
  }) async {
    if (isLoading) return;

    setState(() => isLoading = true);

    try {
      final price =
          (widget.bookingDetails['price'] as num?)?.toInt() ?? 0;
      final actualOnlinePaid = onlinePaid;

      final txnId = (actualOnlinePaid > 0 && transactionId.isNotEmpty)
          ? transactionId
          : "CASH-${DateTime.now().millisecondsSinceEpoch}";

      final formattedDate = date.isNotEmpty
          ? date
          : DateTime.now().toIso8601String().split("T").first;

      final bookingData = {
        "transaction_id": txnId,
        "razorpay_payment_id":
        transactionId.isNotEmpty ? transactionId : "N/A",
        "selected_date": formattedDate,
        "selected_slots": slot,
        "total_amount": price.toString(),
        "booked_by": email,
        "amount_paid": actualOnlinePaid,
        "cash_amount": cashAmount,
        "status": (actualOnlinePaid > 0 && cashAmount > 0)
            ? "partial"
            : "full",
        "created_at": DateTime.now().toIso8601String(),
      };

      print("🔍 Booking Data: $bookingData");

      final res = await http
          .post(
        Uri.parse("https://nahatasports.com/api/verifyPayment"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode(bookingData),
      )
          .timeout(const Duration(seconds: 30));

      print("📥 API Response (${res.statusCode}): ${res.body}");

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data["success"] == true || data["status"] == true) {
          _showSuccessDialog();
        } else {
          _showErrorDialog(
              "Booking failed: ${data["message"] ?? 'Unknown error'}");
        }
      } else {
        _showErrorDialog("Server error (${res.statusCode})");
      }
    } catch (e) {
      print("❌ API Error: $e");
      _showErrorDialog("Network error: ${e.toString()}");
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    print("🎉 Payment Success: ${response.paymentId}");
    final email = await _getUserEmail();
    if (email == null) {
      _showErrorDialog("Session expired. Please login again.");
      return;
    }

    final slot = jsonEncode(widget.bookingDetails['slots']);
    final date = widget.bookingDetails['date']?.toString() ?? '';
    final price = (widget.bookingDetails['price'] as num?)?.toInt() ?? 0;
    final cashAmount = (widget.bookingDetails['cash'] as num?)?.toInt() ?? 0;
    final onlinePaid = price - cashAmount;
    final transactionId = response.paymentId ?? '';

    await _storeBooking(
      email: email,
      slot: slot,
      date: date,
      transactionId: transactionId,
      cashAmount: cashAmount,
      onlinePaid: onlinePaid,
    );
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    print("❌ Payment Error: ${response.code} - ${response.message}");
    String errorMessage = response.message ?? "Payment failed";
    _showErrorDialog(errorMessage);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    print("🔗 External Wallet: ${response.walletName}");
    _showErrorDialog(
        "Payment via ${response.walletName} is not supported currently.");
  }
  void _handleOnlinePayment() async {
    if (isLoading) return;

    if (!await _isLoggedIn()) {
      _showErrorDialog("Please log in to make a payment.");
      return;
    }

    try {
      final total = (widget.bookingDetails['price'] as num?)?.toInt() ?? 0;
      final cash = (widget.bookingDetails['cash'] as num?)?.toInt() ?? 0;
      final onlineAmount = total - cash;
      if (onlineAmount <= 0) {
        _showErrorDialog("Invalid payment amount. Online amount must be > 0.");
        return;
      }

      final email = await _getUserEmail();
      final phone = widget.bookingDetails['phone']?.toString() ?? '';

      var options = {
        'key': 'rzp_live_R7b5MMCgg9AlWn',
        //  'key': 'rzp_test_YwYUHvAMatnKBY',
        'amount': onlineAmount * 100,
        'name': 'Nahata Sports',
        'description': '${widget.bookingDetails['game'] ?? 'Sports'} booking',
        'currency': 'INR',
        'prefill': {'contact': phone, 'email': email},
        'method': {'upi': true, 'card': true, 'netbanking': true, 'wallet': true},
        'theme': {'color': '#4A90E2'},
        // REMOVE the invalid 'modal' key
      };

      _razorpay.open(options);
    } catch (e) {
      _showErrorDialog('Payment gateway error: ${e.toString()}');
    }
  }

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
  //       _showErrorDialog(
  //           "Invalid payment amount. Online amount must be > 0.");
  //       return;
  //     }
  //
  //     final email = await _getUserEmail();
  //     final phone = widget.bookingDetails['phone']?.toString() ?? '';
  //
  //     var options = {
  //       'key': 'rzp_test_YwYUHvAMatnKBY',
  //       // 'key': 'rzp_test_your_test_key', // Use test key here
  //       'amount': onlineAmount * 100,
  //       'name': 'Nahata Sports',
  //       'description': '${widget.bookingDetails['game'] ?? 'Sports'} booking',
  //       'currency': 'INR',
  //       'prefill': {'contact': phone, 'email': email},
  //       'method': {'upi': true, 'card': true, 'netbanking': true, 'wallet': true},
  //       'theme': {'color': '#4A90E2'},
  //       'modal': {
  //         'ondismiss': () {
  //           print("💭 Payment modal dismissed");
  //         }
  //       }
  //     };
  //
  //     _razorpay.open(options);
  //   } catch (e) {
  //     _showErrorDialog('Payment gateway error: ${e.toString()}');
  //   }
  // }

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
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Color(0xFF1A237E).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.money, color: Color(0xFF1A237E), size: 24),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                "Cash Payment",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Enter the amount you'll pay in cash at the venue:"),
            SizedBox(height: 16),
            TextField(
              controller: _cashController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Cash Amount",
                hintText: "₹0 - ₹$total",
                prefixIcon: Icon(Icons.currency_rupee),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel"),
          ),
          ElevatedButton(
    onPressed: () async {
    final cashText = _cashController.text.trim();
    final cash = int.tryParse(cashText) ?? 0;
    if (cash < 0 || cash > total) {
    _showSnackBar("Enter amount between 0 and $total", isError: true);
    return;
    }

    Navigator.pop(context); // Close dialog
    widget.bookingDetails['cash'] = cash;

    final onlineAmount = total - cash;
    final email = await _getUserEmail();
    if (email == null) {
    _showErrorDialog("Session expired. Please login again.");
    return;
    }

    if (onlineAmount <= 0) {
    await _storeBooking(
    email: email,
    slot: jsonEncode(widget.bookingDetails['slots']),
    date: widget.bookingDetails['date']?.toString() ?? '',
    transactionId: "",
    cashAmount: cash,
    onlinePaid: 0,
    );
    } else {
    _showSnackBar("Proceeding to pay ₹$onlineAmount online", isError: false);
    await Future.delayed(Duration(milliseconds: 500));
    selectedPaymentMethod = 'online';  // Ensure correct payment method is set
    _handleOnlinePayment();
    }
    },

    child: Text("Confirm"),
          ),
        ],
      ),
    );
  }

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
                "You will receive a confirmation shortly.",
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

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 12),
            Expanded(child: Text("Error")),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("OK"))
        ],
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

  @override
  Widget build(BuildContext context) {
    final booking = widget.bookingDetails;
    final total = booking['price'] as int? ?? 0;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // Custom App Bar
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: isLoading ? null : () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back_ios, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey[100],
                      padding: EdgeInsets.all(8),
                    ),
                  ),
                  SizedBox(width: 16),
                  Text(
                    "Complete Your Payment",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  Spacer(),
                  if (isLoading)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A237E)),
                      ),
                    ),
                ],
              ),
            ),

            // Main Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Booking Summary Card
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF1A237E), Color(0xFF1A237E)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFF1A237E).withOpacity(0.3),
                            blurRadius: 20,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          // Background pattern/image can be added here
                          Positioned(
                            right: -20,
                            top: -20,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.sports_basketball,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      "Booking Summary",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 20),
                                _buildSummaryRow("Location", booking['location']?.toString() ?? 'N/A'),
                                _buildSummaryRow("Game", booking['game']?.toString() ?? 'N/A'),
                                _buildSummaryRow("Date", booking['date']?.toString() ?? 'N/A'),
                                _buildSummaryRow("Slots", _formatSlots(booking['slots'])),
                                SizedBox(height: 16),
                                Divider(color: Colors.white.withOpacity(0.3), thickness: 1),
                                SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Total Amount",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      "₹ ${total.toStringAsFixed(2)}",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 32),

                    // Payment Method Section
                    Text(
                      "Payment Method",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
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
                    SizedBox(height: 12),
                    _buildPaymentOption(
                      title: "Pay with Cash at Venue",
                      subtitle: "Pay when you arrive at the venue",
                      icon: Icons.money,
                      value: 'cash',
                      isSelected: selectedPaymentMethod == 'cash',
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Payment Button
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
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
                    onPressed: (isLoading || total <= 0) ? null : (selectedPaymentMethod == 'online'
                        ? _handleOnlinePayment
                        : _handleCashPayment),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF1A237E),
                      elevation: 8,
                      shadowColor: Color(0xFF1A237E).withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
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
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          "Processing...",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    )
                        : Text(
                      selectedPaymentMethod == 'online'
                          ? "Pay Online ₹${total.toStringAsFixed(2)}"
                          : "Set Cash Payment",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String title, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
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