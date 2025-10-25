import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// Import your CustomBottomNav
// import 'custom_bottom_nav.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../auth/login.dart';

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'Custombottombar.dart';

// class Viewpass extends StatefulWidget {
//   const Viewpass({super.key});
//
//   @override
//   _ViewpassState createState() => _ViewpassState();
// }
//
// class _ViewpassState extends State<Viewpass> with TickerProviderStateMixin {
//   late AnimationController _slideController;
//   late AnimationController _qrController;
//   late AnimationController _scanController;
//   late Animation<Offset> _slideAnimation;
//   late Animation<double> _qrAnimation;
//   late Animation<double> _scanAnimation;
//
//   bool isScanning = false;
//   bool isLoading = true;
//
//   Map<String, dynamic>? bookingData;
//   String? passcode;
//
//   @override
//   void initState() {
//     super.initState();
//
//     _slideController = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
//     _qrController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
//     _scanController = AnimationController(duration: const Duration(milliseconds: 2000), vsync: this);
//
//     _slideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
//         .animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
//     _qrAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _qrController, curve: Curves.elasticOut));
//     _scanAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _scanController, curve: Curves.easeInOut));
//
//     _slideController.forward();
//     Future.delayed(const Duration(milliseconds: 300), () => _qrController.forward());
//
//     // 🔹 Initialize passcode and fetch booking
//     _initPasscodeAndFetch();
//   }
//
//   Future<void> _initPasscodeAndFetch() async {
//     // Use current user's passcode if available
//     passcode = ApiService.currentUser?['passcode']?.toString();
//
//     // Ask user for passcode if none exists
//     if (passcode == null || passcode!.isEmpty) {
//       passcode = await _askForPasscode();
//       if (passcode == null || passcode!.isEmpty) {
//         _showSnack("Passcode required to continue");
//         setState(() => isLoading = false);
//         return;
//       }
//
//       // Optionally update passcode on backend
//       final updated = await _updatePasscode(passcode!);
//       if (updated == null) {
//         setState(() => isLoading = false);
//         return;
//       }
//       passcode = updated;
//     }
//
//     // Fetch booking with passcode
//     await fetchBooking();
//   }
//
//   Future<void> fetchBooking() async {
//     const apiUrl = "https://nahatasports.com/api/get_booking_by_passcode";
//
//     try {
//       final response = await http.post(
//         Uri.parse(apiUrl),
//         headers: {"Content-Type": "application/json"},
//         body: jsonEncode({"passcode": passcode}),
//       );
//
//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         final bookings = (data["data"]?["bookings"] ?? []) as List;
//         setState(() {
//           bookingData = bookings.isNotEmpty ? bookings.last : null;
//           isLoading = false;
//         });
//       } else if (response.statusCode == 404) {
//         _showSnack("Invalid passcode. Please try again.");
//         final newPasscode = await _askForPasscode();
//         if (newPasscode != null && newPasscode.isNotEmpty) {
//           final updated = await _updatePasscode(newPasscode);
//           if (updated != null) {
//             passcode = updated;
//             await fetchBooking(); // Retry fetching
//           }
//         }
//       } else {
//         setState(() => isLoading = false);
//         _showSnack("Error fetching booking: ${response.statusCode}");
//       }
//     } catch (e) {
//       print("Error fetching booking: $e");
//       setState(() => isLoading = false);
//       _showSnack("Error: $e");
//     }
//   }
//
//   Future<String?> _askForPasscode() async {
//     if (ApiService.currentUser == null) {
//       _showSnack("Please login first to continue.");
//       return null;
//     }
//
//     final controller = TextEditingController();
//     return showDialog<String>(
//       context: context,
//       barrierDismissible: false,
//       builder: (_) => AlertDialog(
//         title: const Text("Enter Passcode"),
//         content: TextField(controller: controller, decoration: const InputDecoration(hintText: "Enter passcode")),
//         actions: [
//           TextButton(onPressed: () => Navigator.pop(context, null), child: const Text("Cancel")),
//           ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text("Submit")),
//         ],
//       ),
//     );
//   }
//
//   Future<String?> _updatePasscode(String passcode) async {
//     const updateUrl = "https://nahatasports.com/api/update-passcode";
//     try {
//       final response = await http.post(
//         Uri.parse(updateUrl),
//         headers: {"Content-Type": "application/json"},
//         body: jsonEncode({"id": ApiService.currentUser?['id'], "passcode": passcode}),
//       );
//       final data = jsonDecode(response.body);
//       if (response.statusCode == 200 && data["status"] == true) {
//         ApiService.currentUser?['passcode'] = passcode;
//         return passcode;
//       } else {
//         _showSnack("Failed to update passcode: ${data["message"] ?? "Unknown error"}");
//         return null;
//       }
//     } catch (e) {
//       _showSnack("Error updating passcode: $e");
//       return null;
//     }
//   }
//
//   void _startScanning() {
//     setState(() => isScanning = true);
//     _scanController.repeat();
//
//     Future.delayed(const Duration(seconds: 3), () {
//       if (!mounted) return;
//       _scanController.stop();
//       _scanController.reset();
//       setState(() => isScanning = false);
//       _showSuccessDialog();
//     });
//   }
//
//   void _showSuccessDialog() {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (_) => AlertDialog(
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Container(width: 60, height: 60, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle), child: const Icon(Icons.check, color: Colors.white, size: 30)),
//             const SizedBox(height: 16),
//             const Text('Ticket Verified!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
//             const SizedBox(height: 8),
//             Text('Your ticket has been successfully verified.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
//           ],
//         ),
//         actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
//       ),
//     );
//   }
//
//   void _showSnack(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
//   }
//
//   @override
//   void dispose() {
//     _slideController.dispose();
//     _qrController.dispose();
//     _scanController.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black.withOpacity(0.7),
//       body: Stack(
//         children: [
//           Container(
//             decoration: BoxDecoration(
//               gradient: LinearGradient(
//                 colors: [
//                   const Color(0xFF1a237e).withOpacity(0.3),
//                   const Color(0xFF3949ab).withOpacity(0.3),
//                 ],
//                 begin: Alignment.topCenter,
//                 end: Alignment.bottomCenter,
//               ),
//             ),
//           ),
//           SlideTransition(
//             position: _slideAnimation,
//             child: Center(
//               child: Container(
//                 width: MediaQuery.of(context).size.width * 0.85,
//                 constraints: const BoxConstraints(maxWidth: 350),
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   borderRadius: BorderRadius.circular(20),
//                   boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
//                 ),
//                 child: isLoading
//                     ? const Padding(
//                   padding: EdgeInsets.all(50),
//                   child: Center(child: CircularProgressIndicator()),
//                 )
//                     : bookingData == null
//                     ? const Padding(
//                   padding: EdgeInsets.all(50),
//                   child: Center(child: Text("No bookings found.")),
//                 )
//                     : _buildBookingContent(),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildBookingContent() {
//     final qrUrl = bookingData!["qr_code"] ?? "";
//     final members = int.tryParse(bookingData!["members_count"] ?? "1") ?? 1;
//     final pricePerMember = double.tryParse(bookingData!["pass_price"] ?? "0") ?? 0;
//     final totalPrice = members * pricePerMember;
//
//     return Column(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               const SizedBox(width: 24),
//               const Text('View Pass', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87)),
//               GestureDetector(
//                 onTap: (){
//                   Navigator.pop(context);
//                    Navigator.push(context, MaterialPageRoute(builder: (context) => CustomBottomNav()));
//                 },
//                 child: Container(
//                   width: 24,
//                   height: 24,
//                   decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle),
//                   child: Icon(Icons.close, size: 16, color: Colors.grey[600]),
//                 ),
//               ),
//             ],
//           ),
//         ),
//         ScaleTransition(
//           scale: _qrAnimation,
//           child: Container(
//             margin: const EdgeInsets.symmetric(horizontal: 40),
//             child: Column(
//               children: [
//                 SizedBox(
//                   width: 200,
//                   height: 200,
//                   child: Container(
//                     decoration: BoxDecoration(
//                       color: Colors.white,
//                       borderRadius: BorderRadius.circular(12),
//                       border: Border.all(color: Colors.grey[300]!, width: 1),
//                     ),
//                     child: Center(
//                       child: Image.network(qrUrl, errorBuilder: (_, __, ___) => const Text("QR not available")),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 20),
//                 Text(bookingData!["tournament_title"] ?? "Event", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
//                 const SizedBox(height: 8),
//                 Text(bookingData!["pass_date"] ?? "-", style: TextStyle(fontSize: 16, color: Colors.grey[600])),
//                 const SizedBox(height: 4),
//                 Text("${bookingData!["start_time"] ?? "-"} - ${bookingData!["end_time"] ?? "-"}", style: TextStyle(fontSize: 16, color: Colors.grey[600], fontWeight: FontWeight.w500)),
//                 const SizedBox(height: 20),
//                 // Padding(
//                 //   padding: const EdgeInsets.symmetric(horizontal: 20),
//                 //   child: SizedBox(
//                 //     width: double.infinity,
//                 //     child: ElevatedButton(
//                 //       onPressed: isScanning ? null : _startScanning,
//                 //       style: ElevatedButton.styleFrom(
//                 //         backgroundColor: isScanning ? Colors.grey : const Color(0xFF1a237e),
//                 //         foregroundColor: Colors.white,
//                 //         padding: const EdgeInsets.symmetric(vertical: 14),
//                 //         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//                 //       ),
//                 //       child: isScanning
//                 //           ? Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
//                 //         SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))),
//                 //         SizedBox(width: 12),
//                 //         Text('Scanning...'),
//                 //       ])
//                 //       //     : Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
//                 //       //   Icon(Icons.qr_code_scanner, size: 20),
//                 //       //   SizedBox(width: 8),
//                 //       //   // Text('Scan Ticket', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
//                 //       // ]),
//                 //     ),
//                 //   ),
//                 // ),
//               ],
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }




class Viewpass extends StatefulWidget {
  const Viewpass({super.key});

  @override
  _ViewpassState createState() => _ViewpassState();
}

class _ViewpassState extends State<Viewpass> with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _qrController;
  late AnimationController _scanController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _qrAnimation;
  late Animation<double> _scanAnimation;

  bool isScanning = false;
  bool isLoading = true;
  bool _hasCheckedLogin = false;

  Map<String, dynamic>? bookingData;
  String? passcode;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _qrController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    _scanController = AnimationController(duration: const Duration(milliseconds: 2000), vsync: this);

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
    _qrAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _qrController, curve: Curves.elasticOut));
    _scanAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _scanController, curve: Curves.easeInOut));

    _slideController.forward();
    Future.delayed(const Duration(milliseconds: 300), () => _qrController.forward());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_hasCheckedLogin) {
      _hasCheckedLogin = true;

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (ApiService.currentUser == null) {
          _showNotLoggedInPopup();
        } else {
          await _initPasscodeAndFetch();
        }
      });
    }
  }


  void _showNotLoggedInPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon with background
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_outline,
                    size: 48, color: Colors.orange),
              ),
              const SizedBox(height: 20),

              // Title
              const Text(
                "Login Required",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              // Description
              const Text(
                "You need to log in to continue.\nRedirecting you shortly...",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.black87),
              ),

              const SizedBox(height: 24),

              // Loading Indicator
              const CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
              ),

              const SizedBox(height: 12),

              const Text(
                "Please wait...",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );

    // Auto-redirect after delay
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.pop(context); // Close popup
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
      );
    });
  }

  // void _showNotLoggedInPopup() {
  //   showDialog(
  //     context: context,
  //     barrierDismissible: false,
  //     builder: (_) => AlertDialog(
  //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  //       title: const Text("Not Logged In"),
  //       content: Column(
  //         mainAxisSize: MainAxisSize.min,
  //         children: const [
  //           Icon(Icons.warning_amber_rounded, size: 50, color: Colors.orange),
  //           SizedBox(height: 16),
  //           Text(
  //             "You are not logged in.\nRedirecting to Login Screen...",
  //             textAlign: TextAlign.center,
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  //
  //   Future.delayed(const Duration(seconds: 3), () {
  //     if (!mounted) return;
  //     Navigator.pop(context);  // Close the popup
  //     Navigator.pushAndRemoveUntil(
  //       context,
  //       MaterialPageRoute(builder: (context) => LoginScreen()),
  //           (route) => false,
  //     );
  //   });
  // }

  Future<void> _initPasscodeAndFetch() async {
    passcode = ApiService.currentUser?['passcode']?.toString();

    if (passcode == null || passcode!.isEmpty) {
      passcode = await _askForPasscode();
      if (passcode == null || passcode!.isEmpty) {
        _showSnack("Passcode required to continue");
        setState(() => isLoading = false);
        return;
      }

      final updated = await _updatePasscode(passcode!);
      if (updated == null) {
        setState(() => isLoading = false);
        return;
      }
      passcode = updated;
    }

    await fetchBooking();
  }

  Future<void> fetchBooking() async {
    const apiUrl = "https://nahatasports.com/api/get_booking_by_passcode";

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"passcode": passcode}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final bookings = (data["data"]?["bookings"] ?? []) as List;
        setState(() {
          bookingData = bookings.isNotEmpty ? bookings.last : null;
          isLoading = false;
        });
      } else if (response.statusCode == 404) {
        _showSnack("Invalid passcode. Please try again.");
        final newPasscode = await _askForPasscode();
        if (newPasscode != null && newPasscode.isNotEmpty) {
          final updated = await _updatePasscode(newPasscode);
          if (updated != null) {
            passcode = updated;
            await fetchBooking();
          }
        }
      } else {
        setState(() => isLoading = false);
        _showSnack("Error fetching booking: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching booking: $e");
      setState(() => isLoading = false);
      _showSnack("Error: $e");
    }
  }

  Future<String?> _askForPasscode() async {
    if (ApiService.currentUser == null) {
      _showSnack("Please login first to continue.");
      return null;
    }

    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Enter Passcode"),
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: "Enter passcode")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text("Submit")),
        ],
      ),
    );
  }

  Future<String?> _updatePasscode(String passcode) async {
    const updateUrl = "https://nahatasports.com/api/update-passcode";
    try {
      final response = await http.post(
        Uri.parse(updateUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"id": ApiService.currentUser?['id'], "passcode": passcode}),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data["status"] == true) {
        ApiService.currentUser?['passcode'] = passcode;
        return passcode;
      } else {
        _showSnack("Failed to update passcode: ${data["message"] ?? "Unknown error"}");
        return null;
      }
    } catch (e) {
      _showSnack("Error updating passcode: $e");
      return null;
    }
  }

  void _startScanning() {
    setState(() => isScanning = true);
    _scanController.repeat();

    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      _scanController.stop();
      _scanController.reset();
      setState(() => isScanning = false);
      _showSuccessDialog();
    });
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 60, height: 60, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle), child: const Icon(Icons.check, color: Colors.white, size: 30)),
            const SizedBox(height: 16),
            const Text('Ticket Verified!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Your ticket has been successfully verified.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _slideController.dispose();
    _qrController.dispose();
    _scanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.7),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1a237e).withOpacity(0.3),
                  const Color(0xFF3949ab).withOpacity(0.3),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SlideTransition(
            position: _slideAnimation,
            child: Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.85,
                constraints: const BoxConstraints(maxWidth: 350),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
                ),
                child: isLoading
                    ? const Padding(
                  padding: EdgeInsets.all(50),
                  child: Center(child: CircularProgressIndicator()),
                )
                    : bookingData == null
                    ? const Padding(
                  padding: EdgeInsets.all(50),
                  child: Center(child: Text("No bookings found.")),
                )
                    : _buildBookingContent(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingContent() {
    if (bookingData == null) {
      return const Padding(
        padding: EdgeInsets.all(50),
        child: Center(
          child: Text("You have not booked any event yet.", style: TextStyle(fontSize: 18, color: Colors.black87)),
        ),
      );
    }
    final qrUrl = bookingData!["qr_code"] ?? "";
    final members = int.tryParse(bookingData!["members_count"] ?? "1") ?? 1;
    final pricePerMember = double.tryParse(bookingData!["pass_price"] ?? "0") ?? 0;
    final totalPrice = members * pricePerMember;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 24),
              const Text('View Pass', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87)),
              GestureDetector(
                onTap: () {
                  // Navigator.pop(context);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => CustomBottomNav()),
                  );                },
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle),
                  child: Icon(Icons.close, size: 16, color: Colors.grey[600]),
                ),
              ),
            ],
          ),
        ),
        ScaleTransition(
          scale: _qrAnimation,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              children: [
                SizedBox(
                  width: 200,
                  height: 200,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!, width: 1),
                    ),
                    child: Center(
                      child: Image.network(qrUrl, errorBuilder: (_, __, ___) => const Text("QR not available")),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(bookingData!["tournament_title"] ?? "Event", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 8),
                Text(bookingData!["pass_date"] ?? "-", style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                const SizedBox(height: 4),
                Text("${bookingData!["start_time"] ?? "-"} - ${bookingData!["end_time"] ?? "-"}", style: TextStyle(fontSize: 16, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

