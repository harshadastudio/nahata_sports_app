// import 'dart:convert';
//
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:http/http.dart' as http;
// import 'package:nahata_app/dashboard/admin_screen.dart';
// import 'package:nahata_app/dashboard/security_screen.dart';
// import 'package:nahata_app/dashboard/students_parents.dart';
// import 'package:nahata_app/screens/login_screen.dart';
//
// import '../events2.dart';
// import '../screens/Events.dart';
// import '../services/api_service.dart';
// import '../services/event3.dart';
// import 'coach_screen.dart';
//
// // class DashboardScreen extends StatefulWidget {
// //   const DashboardScreen({super.key});
// //   @override
// //   State<DashboardScreen> createState() => _DashboardScreenState();
// // }
// //
// // class _DashboardScreenState extends State<DashboardScreen> {
// //   int _selectedIndex = 0;
// //   Widget _buildNavItem(IconData icon, String label, Widget targetScreen, int index) {
// //     final isSelected = _selectedIndex == index;
// //     final color = isSelected ? Colors.blue : Colors.grey;
// //
// //     return GestureDetector(
// //       onTap: () {
// //         setState(() {
// //           _selectedIndex = index; // update selected index
// //         });
// //         Navigator.push(
// //           context,
// //           MaterialPageRoute(builder: (_) => targetScreen),
// //         );
// //       },
// //       child: Column(
// //         mainAxisSize: MainAxisSize.min,
// //         children: [
// //           Text(label, style: TextStyle(color: color, fontSize: 14, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
// //           const SizedBox(height: 4),
// //           Icon(icon, color: color, size: 24),
// //         ],
// //       ),
// //     );
// //   }
// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       appBar: AppBar(
// //         title: const Text("Nahata Sports Dashboard"),
// //         centerTitle: true,
// //       ),
// //       body: SingleChildScrollView(
// //         padding: const EdgeInsets.all(16),
// //         child: Column(
// //           crossAxisAlignment: CrossAxisAlignment.start,
// //           children: [
// //             // Fees & Receipts
// //             Card(
// //               child: ListTile(
// //                 leading: const Icon(Icons.sports_bar),
// //                 title: const Text("Sports"),
// //                 subtitle: const Text("View Sports"),
// //                 onTap: () {
// //                   // Navigate to fees details
// //                 },
// //               ),
// //             ),
// //
// //             // Attendance
// //             Card(
// //               child: ListTile(
// //                 leading: const Icon(Icons.check_circle_outline),
// //                 title: const Text("Booked Court Response"),
// //                 subtitle: const Text("Court Responses"),
// //                 onTap: () {
// //                   // Navigate to attendance screen
// //                 },
// //               ),
// //             ),
// //
// //             // Coach Feedback
// //             Card(
// //               child: ListTile(
// //                 leading: const Icon(Icons.feedback_outlined),
// //                 title: const Text("Feedback"),
// //                 subtitle: const Text("See feedback"),
// //                 onTap: () {
// //                   // Navigate to feedback screen
// //                 },
// //               ),
// //             ),
// //
// //             // Book & Play — Upcoming Bookings
// //             Card(
// //               child: ListTile(
// //                 leading: const Icon(Icons.sports_baseball),
// //                 title: const Text("Book & Play"),
// //                 subtitle: const Text("Reserve courts or sessions"),
// //                 onTap: () {
// //                   Navigator.pushNamed(context, '/location');
// //                 },
// //               ),
// //             ),
// //             Card(
// //               child: ListTile(
// //                 leading: const Icon(Icons.people_alt_outlined),
// //                 title: const Text("Students & Parents"),
// //                 subtitle: const Text("View details"),
// //                 onTap: () {
// //                   final studentId = ApiService.currentUser?['student_id']?.toString() ?? '';
// //
// //                   if (studentId.isEmpty) {
// //                     ScaffoldMessenger.of(context).showSnackBar(
// //                       const SnackBar(content: Text("Student ID is not available")),
// //                     );
// //                     return; // stop navigation
// //                   }
// //
// //                   Navigator.push(
// //                     context,
// //                     MaterialPageRoute(
// //                       builder: (_) => StudentsParentsScreen(studentId: studentId),
// //                     ),
// //                   );
// //                 },
// //               ),
// //             ),
// //
// //
// //             // Card(
// //             //   child: ListTile(
// //             //     leading: const Icon(Icons.people_alt_outlined),
// //             //     title: const Text("Students & Parents"),
// //             //     subtitle: const Text("View details"),
// //             //     onTap: () {
// //             //       // Navigate to dashboard after login
// //             //       Navigator.push(
// //             //         context,
// //             //         MaterialPageRoute(
// //             //           builder: (_) => StudentsParentsScreen(studentId: ApiService.currentUser?['student_id']?.toString() ?? '',),
// //             //         ),
// //             //       );
// //             //
// //             //     },
// //             //   ),
// //             // ),
// //             const SizedBox(height: 20),
// //             // Upcoming Events & Announcements
// //             const Text(
// //               "Announcements & Events",
// //               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
// //             ),
// //             const SizedBox(height: 8),
// //             // Example announcement items
// //             ...[
// //               "Free Training Camps",
// //               "Holiday Notices",
// //               "Upcoming Tournaments"
// //             ].map((item) =>
// //                 Card(
// //                   child: ListTile(
// //                     title: Text(item),
// //                     trailing: const Icon(Icons.arrow_forward_ios, size: 16),
// //                     onTap: () {
// //                       // Navigate to announcement detail
// //                     },
// //                   ),
// //                 )),
// //           ],
// //         ),
// //       ),
// //
// //       // bottomNavigationBar: BottomNavigationBar(
// //       //   items: const [
// //       //     BottomNavigationBarItem(icon: Icon(Icons.people,color: Colors.black,), label: "Students"),
// //       //     BottomNavigationBarItem(icon: Icon(Icons.perm_contact_cal,color: Colors.black,), label: "Coach"),
// //       //     BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings,color: Colors.black,), label: "Admin"),
// //       //     BottomNavigationBarItem(icon: Icon(Icons.security,color: Colors.black,), label: "Security"),
// //       //   ],
// //       //   onTap: (index) {
// //       //     // Handle bottom nav tap
// //       //   },
// //       // ),
// //
// //       // bottomNavigationBar: BottomAppBar(
// //       //   color: Colors.white,
// //       //   elevation: 10,
// //       //   child: Row(
// //       //     mainAxisAlignment: MainAxisAlignment.spaceAround,
// //       //     children: [
// //       //       _buildNavItem(Icons.people, "Students", DashboardScreen(), 0),
// //       //       _buildNavItem(Icons.perm_contact_cal, "Coach", CoachDashboardScreen(), 1),
// //       //       _buildNavItem(Icons.admin_panel_settings, "Admin", AdminDashboardScreen(), 2),
// //       //       _buildNavItem(Icons.security, "Security", security_screen(), 3),
// //       //     ],
// //       //   ),
// //       // ),
// //
// //
// //     );
// //   }
// //   //
// //   // Widget _buildNavItem(IconData icon, String label, Widget targetScreen,
// //   //     BuildContext context) {
// //   //   return GestureDetector(
// //   //     onTap: () {
// //   //       Navigator.push(
// //   //         context,
// //   //         MaterialPageRoute(builder: (_) => targetScreen),
// //   //       );
// //   //     },
// //   //     child: Column(
// //   //       mainAxisSize: MainAxisSize.min,
// //   //       children: [
// //   //         Text(
// //   //             label, style: const TextStyle(color: Colors.black, fontSize: 14)),
// //   //         const SizedBox(height: 4),
// //   //         Icon(icon, color: Colors.black, size: 24),
// //   //       ],
// //   //     ),
// //   //   );
// //   // }
// //
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
// class BookPlayScreen extends StatefulWidget {
//   const BookPlayScreen({super.key});
//
//   @override
//   State<BookPlayScreen> createState() => _BookPlayScreenState();
// }
//
// class _BookPlayScreenState extends State<BookPlayScreen>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _controller;
//   late Animation<double> _fadeAnimation;
//
//   @override
//   void initState() {
//     super.initState();
//     _controller =
//         AnimationController(vsync: this, duration: Duration(milliseconds: 600));
//     _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
//     _controller.forward();
//
//
//       // Redirect if logged-in user is admin/coach/security
//       final role = ApiService.currentUser?['role'];
//       if (role != null && role != 'user') {
//         WidgetsBinding.instance.addPostFrameCallback((_) {
//           Widget nextScreen;
//           if (role == 'admin') {
//             nextScreen = AdminDashboardScreen();
//           } else if (role == 'coach') {
//             nextScreen = CoachDashboardScreen();
//           } else if (role == 'security') {
//             nextScreen = SecurityGateScannerScreen();
//           } else {
//             nextScreen = BookPlayScreen();
//           }
//
//           Navigator.pushReplacement(
//             context,
//             MaterialPageRoute(builder: (_) => nextScreen),
//           );
//         });
//       }
//     }
//
//
//
//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }
//   void _showSnack(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text(message)),
//     );
//   }
//   /// fetch booking QR codes by passcode
//
//
//
//
//   Future<void> _showQrForEvents(BuildContext context, {String? referralCode}) async {
//     const String apiUrl = "https://nahatasports.com/api/get_booking_by_passcode";
//     const String updatePasscodeUrl = "https://nahatasports.com/api/update-passcode";
//
//     // ✅ Determine which passcode to use (no fallback to ID)
//     String? passcode = (referralCode != null && referralCode.trim().isNotEmpty)
//         ? referralCode.trim()
//         : (ApiService.currentUser?['passcode'] != null &&
//         ApiService.currentUser!['passcode'].toString().trim().isNotEmpty)
//         ? ApiService.currentUser!['passcode'].toString().trim()
//         : null;
//
//     // 🔹 If no passcode → ask user for one
//     if (passcode == null || passcode.isEmpty) {
//       final enteredPasscode = await _askForPasscode(context);
//       if (enteredPasscode == null || enteredPasscode.isEmpty) {
//         _showSnack("Passcode required to continue");
//         return;
//       }
//
//       final updatedPasscode = await _updatePasscode(enteredPasscode, updatePasscodeUrl);
//       if (updatedPasscode == null) return;
//
//       passcode = updatedPasscode; // ✅ use new passcode
//     }
//
//     print("🔑 Using passcode: $passcode");
//
//     try {
//       final response = await http.post(
//         Uri.parse(apiUrl),
//         headers: {"Content-Type": "application/json"},
//         body: jsonEncode({"passcode": passcode}),
//       );
//
//       print("📡 API Response: ${response.statusCode} - ${response.body}");
//
//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//
//         if (data["status"] == true && data["data"]["bookings"] != null) {
//           final bookings = data["data"]["bookings"] as List;
//
//           // 🔹 Filter today's bookings
//           final today = DateTime.now().toString().split(' ')[0];
//           final todayBookings =
//           bookings.where((b) => b["pass_date"] == today).toList();
//
//           final bookingToShow = todayBookings.isNotEmpty
//               ? todayBookings.last
//               : (bookings.isNotEmpty ? bookings.last : null);
//
//           if (bookingToShow != null) {
//             // Fix QR URL
//             String qrUrl = bookingToShow["qr_code"] ?? "";
//             if (qrUrl.contains("nahatasports.com/https:/")) {
//               qrUrl = qrUrl.replaceAll("https://nahatasports.com/", "");
//             }
//
//             // Calculate total price
//             final members =
//                 int.tryParse(bookingToShow["members_count"] ?? "1") ?? 1;
//             final pricePerMember =
//                 double.tryParse(bookingToShow["pass_price"] ?? "0") ?? 0;
//             final totalPrice = members * pricePerMember;
//
//             // Show Booking Dialog
//             showDialog(
//               context: context,
//               barrierDismissible: false,
//
//               builder: (_) => AlertDialog(
//                 title: Text(
//                   "Event Pass - ${bookingToShow["tournament_title"] ?? "Event"}",
//                 ),
//                 content: SingleChildScrollView(
//                   child: ConstrainedBox(
//                     constraints: const BoxConstraints(
//                       maxWidth: 400, // prevents full screen width
//                       maxHeight: 500, // prevents infinite height
//                     ),
//                     child: Column(
//                       mainAxisSize: MainAxisSize.min,
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         if (qrUrl.isNotEmpty)
//                           Center(
//                             child: Image.network(
//                               qrUrl,
//                               height: 220,
//                               fit: BoxFit.contain,
//                               errorBuilder: (_, __, ___) =>
//                               const Text("QR not available"),
//                             ),
//                           )
//                         else
//                           const Text("QR not available"),
//                         const SizedBox(height: 12),
//                         Text("👤 Name: ${bookingToShow["name"] ?? "-"}"),
//                         Text("📧 Email: ${bookingToShow["email"] ?? "-"}"),
//                         Text("👥 Members: $members"),
//                         Text("📅 Date: ${bookingToShow["pass_date"] ?? "-"}"),
//                         Text("⏰ Slot: ${bookingToShow["start_time"] ?? "-"} - ${bookingToShow["end_time"] ?? "-"}"),
//                         Text("🎟️ Tournament: ${bookingToShow["tournament_title"] ?? "-"}"),
//                         Text("💰 Price per Member: ₹$pricePerMember"),
//                         Text("💵 Total Price: ₹$totalPrice"),
//                       ],
//                     ),
//                   ),
//                 ),
//                 actions: [
//                   TextButton(
//                     onPressed: () => Navigator.pop(context),
//                     child: const Text("Close"),
//                   )
//                 ],
//               ),
//             );
//
//           } else {
//             _showSnack("No booking found for today.");
//           }
//         } else {
//           _showSnack("No bookings found");
//         }
//       } else if (response.statusCode == 404) {
//         // 🔹 Handle invalid passcode
//         final data = jsonDecode(response.body);
//         if (data["message"] == "Invalid passcode") {
//           final newPasscode = await _askForPasscode(context);
//           if (newPasscode == null || newPasscode.isEmpty) {
//             _showSnack("Passcode required to continue");
//             return;
//           }
//
//           final updatedPasscode = await _updatePasscode(newPasscode, updatePasscodeUrl);
//           if (updatedPasscode == null) return;
//
//           // 🔄 Retry instantly with new passcode
//           return _showQrForEvents(context, referralCode: updatedPasscode);
//         } else {
//           _showSnack("Error: ${data["message"] ?? "Something went wrong"}");
//         }
//       } else {
//         _showSnack("Error: ${response.statusCode}");
//       }
//     } catch (e) {
//       _showSnack("Error: $e");
//     }
//   }
//
//
//
//
//
//   /// 🔹 Show input popup
//   Future<String?> _askForPasscode(BuildContext context) async {
//     if (ApiService.currentUser == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("Please login first to continue.")),
//       );
//       return null;
//     }
//
//     final controller = TextEditingController();
//     return showDialog<String>(
//       context: context,
//       barrierDismissible: false,
//       builder: (_) => AlertDialog(
//         title: const Text("Enter Passcode"),
//         content: TextField(
//           controller: controller,
//           decoration: const InputDecoration(hintText: "Enter a passcode"),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context, null),
//             child: const Text("Cancel"),
//           ),
//           ElevatedButton(
//             onPressed: () => Navigator.pop(context, controller.text.trim()),
//             child: const Text("Submit"),
//           ),
//         ],
//       ),
//     );
//   }
//
//   /// 🔹 Update passcode in backend
//   Future<String?> _updatePasscode(String passcode, String updateUrl) async {
//     try {
//       final updateResponse = await http.post(
//         Uri.parse(updateUrl),
//         headers: {"Content-Type": "application/json"},
//         body: jsonEncode({
//           "id": ApiService.currentUser?['id'],
//           "passcode": passcode,
//         }),
//       );
//   print("📡 API Response: ${updateResponse.statusCode} - ${updateResponse.body}");
//       final updateData = jsonDecode(updateResponse.body);
//
//       if (updateResponse.statusCode == 200 && updateData["status"] == true) {
//         ApiService.currentUser?['passcode'] = passcode;
//         return passcode; // ✅ return updated passcode
//       } else {
//         _showSnack("Failed to update passcode: ${updateData["message"] ?? "Unknown error"}");
//         return null;
//       }
//     } catch (e) {
//       _showSnack("Error updating passcode: $e");
//       return null;
//     }
//   }
//
//
//
//
//
//   Widget _buildCard(String title, IconData icon, VoidCallback onTap) {
//     return FadeTransition(
//       opacity: _fadeAnimation,
//       child: GestureDetector(
//         onTap: onTap,
//         child: Container(
//           padding: EdgeInsets.all(20),
//           margin: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(16),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black12,
//                 blurRadius: 10,
//                 offset: Offset(0, 5),
//               ),
//             ],
//           ),
//           child: Row(
//             children: [
//               CircleAvatar(
//                 radius: 25,
//                 backgroundColor: Color(0xFF0A198D),
//                 child: Icon(icon, color: Colors.white, size: 28),
//               ),
//               SizedBox(width: 20),
//               Text(
//                 title,
//                 style: TextStyle(
//                     fontSize: 18,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.black87),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return SafeArea(
//       child: Scaffold(
//         // appBar:
//         // AppBar(
//         //   backgroundColor: Color(0xFF0A198D),
//         //   elevation: 0,
//         //   leading: IconButton(
//         //     icon: Icon(Icons.arrow_back, color: Colors.white),
//         //    onPressed: (){
//         //      Navigator.pushReplacement(
//         //        context,
//         //        MaterialPageRoute(builder: (_) => LoginScreen()), // or any other screen
//         //      );
//         //    },
//         //   ),
//         //   title: Text(
//         //     "Students & Parents",
//         //     style: TextStyle(
//         //       color: Colors.white,
//         //       fontWeight: FontWeight.bold,
//         //       fontSize: 20,
//         //     ),
//         //   ),
//         //   centerTitle: true,
//         // ),
//           appBar: AppBar(
//             backgroundColor: const Color(0xFF0A198D),
//             elevation: 0,
//             title: const Text(
//               "Book & Play",
//               style: TextStyle(
//                 color: Colors.white,
//                 fontWeight: FontWeight.bold,
//                 fontSize: 20,
//               ),
//             ),
//             actions: [
//               Builder(
//                 builder: (context) {
//                   final role = ApiService.currentUser?['role'];
//
//                   // If user → show logout
//                   if (role == 'user') {
//                     return IconButton(
//                       icon: const Icon(Icons.logout, color: Colors.white),
//                       onPressed: () async {
//                         bool confirm = await showDialog(
//                           context: context,
//                           builder: (ctx) => AlertDialog(
//                             title: const Text("Logout"),
//                             content: const Text("Are you sure you want to logout?"),
//                             actions: [
//                               TextButton(
//                                 onPressed: () => Navigator.pop(ctx, false),
//                                 child: const Text("Cancel"),
//                               ),
//                               TextButton(
//                                 onPressed: () => Navigator.pop(ctx, true),
//                                 child: const Text("Logout"),
//                               ),
//                             ],
//                           ),
//                         ) ?? false;
//
//                         if (confirm) {
//                           await ApiService.logout();
//                           if (context.mounted) {
//                             Navigator.pushAndRemoveUntil(
//                               context,
//                               MaterialPageRoute(builder: (_) => LoginScreen()),
//                                   (route) => false,
//                             );
//                           }
//                         }
//                       },
//                     );
//                   }
//
//                   // If admin/coach/security → show login
//                   return IconButton(
//                     icon: const Icon(Icons.login, color: Colors.white),
//                     onPressed: () {
//                       Navigator.pushReplacement(
//                         context,
//                         MaterialPageRoute(builder: (_) => LoginScreen()),
//                       );
//                     },
//                   );
//                 },
//               ),
//             ],
//           ),
//
//
//
//
//           backgroundColor: Color(0xFFF5F5F5),
//         body: Column(
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             SizedBox(height: 20),
//             _buildCard("Book and Play", Icons.sports_basketball, () {
//               Navigator.pushNamed(context, '/location');
//             }),
//             _buildCard("Students and Parents", Icons.people, () async {
//               bool loggedIn = await ApiService.isLoggedIn();
//
//               if (loggedIn) {
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (_) => StudentsParentsScreen(
//                       studentId: ApiService.currentUser?['student_id']?.toString() ?? '',
//                     ),
//                   ),
//                 );
//               } else {
//                 // Show snackbar first
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(
//                     content: Text("Please login to continue"),
//                     duration: Duration(seconds: 2),
//                   ),
//                 );
//
//                 // Redirect to login screen after short delay so user sees snackbar
//                 Future.delayed(const Duration(milliseconds: 500), () {
//                   Navigator.pushAndRemoveUntil(
//                     context,
//                     MaterialPageRoute(builder: (_) => LoginScreen()),
//                         (route) => false,
//                   );
//                 });
//               }
//             }),
//
//
//             // _buildCard("Students and Parents", Icons.people, () {
//             //                     Navigator.push(
//             //           context,
//             //           MaterialPageRoute(
//             //             builder: (_) => StudentsParentsScreen(studentId: ApiService.currentUser?['student_id']?.toString() ?? '',),
//             //           ),
//             //         );
//             //                         (route) => false;
//             //
//             // }),
//
//
//             _buildCard("Events", Icons.event, (){
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(
//                   builder: (_) =>EventsListPage(),
//                 ),
//               );
//                   (route) => false;
//
//             }),
//
//             _buildCard("Show Qr For Events", Icons.qr_code, () async {
//               await _showQrForEvents(context);
//             }),
//
//
//         ],
//         ),
//       ),
//     );
//   }
// }
