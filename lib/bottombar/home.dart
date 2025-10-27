// import 'dart:convert';
//
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:share_plus/share_plus.dart';
// import 'package:nahata_app/bottombar/event.dart';
// import 'package:nahata_app/bottombar/profile.dart';
// import 'package:url_launcher/url_launcher.dart';
//
// import '../auth/login.dart';
// import 'BookPlay.dart';
// import 'Custombottombar.dart';
// import 'Viewpass.dart';
//

// //
// //   Widget _buildContactButton(IconData icon, Color color, VoidCallback onTap) {
// //     return GestureDetector(
// //       onTap: onTap,
// //       child: Container(
// //         width: 50,
// //         height: 50,
// //         decoration: BoxDecoration(
// //           color: color.withOpacity(0.1),
// //           shape: BoxShape.circle,
// //           border: Border.all(
// //             color: color.withOpacity(0.3),
// //             width: 1,
// //           ),
// //         ),
// //         child: Icon(
// //           icon,
// //           color: color,
// //           size: 24,
// //         ),
// //       ),
// //     );
// //   }
// // }
// // class StudentData {
// //   final Map<String, dynamic> student;
// //   final Map<String, dynamic>? fee;
// //   final Map<String, dynamic>? gatePass;
// //   final String? coachName;
// //
// //   StudentData({
// //     required this.student,
// //     this.fee,
// //     this.gatePass,
// //     this.coachName,
// //   });
// //
// //   factory StudentData.fromJson(Map<String, dynamic> json) {
// //     return StudentData(
// //       student: json['student'],
// //       fee: json['fee'],
// //       gatePass: json['pass'], // Make sure you access the 'pass' key
// //       coachName: json['coach_name'],
// //     );
// //   }
// // }
//
//
// class HomeScreen extends StatefulWidget {
//   final String studentId;
//   const HomeScreen({Key? key, required this.studentId}) : super(key: key);
//
//   @override
//   State<HomeScreen> createState() => _HomeScreenState();
// }
//
// class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
//   static const brandBlue = Color(0xFF1A237E);
//   int _selectedIndex = 0;
//   bool isLoading = true;
//   bool isLoggedIn = false;
//   StudentData? studentData;
//   late final String studentId;
//   late Future<List<StudentData>> studentsFuture;
//   String userInitial = '';
//
//   // Animation controllers for login prompt
//   late AnimationController _fadeController;
//   late AnimationController _scaleController;
//   late AnimationController _slideController;
//   late Animation<double> _fadeAnimation;
//   late Animation<double> _scaleAnimation;
//   late Animation<Offset> _slideAnimation;
//
//   @override
//   void initState() {
//     super.initState();
//     studentsFuture = _initAndFetch();
//     fetchUserInitial();
//     _initializeAnimations();
//   }
//
//   void _initializeAnimations() {
//     // Fade animation
//     _fadeController = AnimationController(
//       duration: const Duration(milliseconds: 1200),
//       vsync: this,
//     );
//     _fadeAnimation = Tween<double>(
//       begin: 0.0,
//       end: 1.0,
//     ).animate(CurvedAnimation(
//       parent: _fadeController,
//       curve: Curves.easeInOut,
//     ));
//
//     // Scale animation
//     _scaleController = AnimationController(
//       duration: const Duration(milliseconds: 800),
//       vsync: this,
//     );
//     _scaleAnimation = Tween<double>(
//       begin: 0.8,
//       end: 1.0,
//     ).animate(CurvedAnimation(
//       parent: _scaleController,
//       curve: Curves.elasticOut,
//     ));
//
//     // Slide animation
//     _slideController = AnimationController(
//       duration: const Duration(milliseconds: 1000),
//       vsync: this,
//     );
//     _slideAnimation = Tween<Offset>(
//       begin: const Offset(0, 0.3),
//       end: Offset.zero,
//     ).animate(CurvedAnimation(
//       parent: _slideController,
//       curve: Curves.easeOutCubic,
//     ));
//
//     // Start animations
//     _fadeController.forward();
//     _scaleController.forward();
//     _slideController.forward();
//   }
//
//   @override
//   void dispose() {
//     _fadeController.dispose();
//     _scaleController.dispose();
//     _slideController.dispose();
//     super.dispose();
//   }
//
//   void fetchUserInitial() async {
//     final user = await AuthService.getUser();
//
//     if (user != null && user['name'] != null && user['name'].toString().isNotEmpty) {
//       userInitial = user['name'].toString().substring(0, 1).toUpperCase();
//       isLoggedIn = true;
//     } else {
//       userInitial = '?';
//       isLoggedIn = false;
//     }
//
//     setState(() {});
//   }
//
//   Future<List<StudentData>> _initAndFetch() async {
//     await ApiService.loadUserFromPrefs();
//
//     final id = widget.studentId.isNotEmpty
//         ? widget.studentId
//         : (ApiService.currentUser?['student_id']?.toString() ?? '');
//
//     if (id.isEmpty) {
//       return []; // Empty list to handle non-logged in case gracefully
//     }
//
//     return fetchStudents(int.parse(id));
//   }
//
//   Future<List<StudentData>> fetchStudents(int studentId) async {
//     final url = Uri.parse(
//         "https://nahatasports.com/api/student_dashboard?student_id=$studentId");
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
//
//     if (response.statusCode == 200) {
//       final body = jsonDecode(response.body);
//
//       if (body['status'] == true) {
//         final data = body['data'];
//
//         return [StudentData.fromJson(data)];
//       } else {
//         throw Exception("API returned false status");
//       }
//     } else {
//       throw Exception("Failed to fetch data");
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.grey[50],
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         elevation: 0,
//         title: const Text(
//           'Nahata Sport',
//           style: TextStyle(
//             color: brandBlue,
//             fontSize: 20,
//             fontWeight: FontWeight.w600,
//           ),
//         ),
//         centerTitle: false,
//         actions: [
//           const SizedBox(width: 8),
//           GestureDetector(
//             onTap: () {
//               if (isLoggedIn) {
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(builder: (context) => UserOptionsPage()),
//                 );
//               } else {
//                 Navigator.pushAndRemoveUntil(
//                   context,
//                   MaterialPageRoute(builder: (context) => LoginScreen()),
//                       (route) => false,  // Remove all previous routes
//                 );
//               }
//             },
//             child: Container(
//               margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
//               child: Stack(
//                 alignment: Alignment.center,
//                 children: [
//                   CircleAvatar(
//                     radius: 18,
//                     backgroundColor: brandBlue,
//                     child: Text(
//                       userInitial.isNotEmpty ? userInitial : '?',
//                       style: const TextStyle(
//                         color: Colors.white,
//                         fontWeight: FontWeight.bold,
//                         fontSize: 16,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//       body: FutureBuilder<List<StudentData>>(
//         future: studentsFuture,
//         builder: (context, snapshot) {
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return const Center(
//                 child: CircularProgressIndicator(color: brandBlue));
//           } else if (snapshot.hasError) {
//             return Center(child: Text("❌ Error: ${snapshot.error}"));
//           } else {
//             final hasData = snapshot.hasData && snapshot.data!.isNotEmpty;
//             final student = hasData ? snapshot.data!.first : null;
//
//             return SingleChildScrollView(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   buildHeroSection(),
//                   buildRecommendedSection(),
//                   const SizedBox(height: 24),
//                   Padding(
//                     padding: const EdgeInsets.symmetric(horizontal: 16),
//                     child: isLoggedIn && hasData
//                         ? buildUserProfile(student!)
//                         : buildProfessionalLoginPrompt(),
//                   ),
//                   const SizedBox(height: 24),
//                   // Only show gate pass section when user is logged in
//                   if (isLoggedIn && hasData) buildGatePassSection(student),
//                   const SizedBox(height: 20),
//                 ],
//               ),
//             );
//           }
//         },
//       ),
//     );
//   }
//
//   Widget buildHeroSection() {
//     return Container(
//       margin: const EdgeInsets.all(16),
//       height: 120,
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(16),
//         gradient: LinearGradient(
//           colors: [brandBlue, brandBlue.withOpacity(0.8)],
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//         ),
//         boxShadow: [
//           BoxShadow(
//             color: brandBlue.withOpacity(0.3),
//             blurRadius: 12,
//             offset: const Offset(0, 4),
//           ),
//         ],
//       ),
//       child: Stack(
//         children: [
//           Positioned(
//             right: -20,
//             top: -20,
//             child: Container(
//               width: 100,
//               height: 100,
//               decoration: BoxDecoration(
//                 color: Colors.white.withOpacity(0.1),
//                 shape: BoxShape.circle,
//               ),
//             ),
//           ),
//           Padding(
//             padding: const EdgeInsets.all(20),
//             child: Row(
//               children: [
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: const [
//                       Text(
//                         'Welcome Back!',
//                         style: TextStyle(
//                           color: Colors.white,
//                           fontSize: 18,
//                           fontWeight: FontWeight.w600,
//                         ),
//                       ),
//                       SizedBox(height: 4),
//                       Text(
//                         'Ready for your next game?',
//                         style: TextStyle(
//                           color: Colors.white70,
//                           fontSize: 14,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 Container(
//                   width: 60,
//                   height: 60,
//                   decoration: BoxDecoration(
//                     color: Colors.white.withOpacity(0.2),
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                   child: const Icon(
//                     Icons.sports_soccer,
//                     color: Colors.white,
//                     size: 32,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget buildRecommendedSection() {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 16),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text(
//             'Recommended',
//             style: TextStyle(
//               fontSize: 20,
//               fontWeight: FontWeight.w600,
//               color: Color(0xFF2D3748),
//             ),
//           ),
//           const SizedBox(height: 16),
//           Row(
//             children: [
//               Expanded(
//                 child: _buildRecommendedCard(
//                   'Let\'s figure out what live events look like now',
//                   'assets/sports1.jpg',
//                   Colors.orange[100]!,
//                 ),
//               ),
//               const SizedBox(width: 12),
//               Expanded(
//                 child: _buildRecommendedCard(
//                   'Explore game happening now!',
//                   'assets/sports2.jpg',
//                   Colors.blue[100]!,
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget buildUserProfile(StudentData studentData) {
//     return Container(
//       padding: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(16),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.grey.withOpacity(0.1),
//             blurRadius: 10,
//             offset: const Offset(0, 4),
//           ),
//         ],
//       ),
//       child: Column(
//         children: [
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Text(
//                 'Name: ${studentData.student['name'] ?? "-"}',
//                 style: const TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.w500,
//                 ),
//               ),
//               Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                 decoration: BoxDecoration(
//                   color: Colors.grey[100],
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: Text(
//                   'ID: ${studentData.student['id'] ?? "-"}',
//                   style: const TextStyle(
//                     fontSize: 12,
//                     color: Colors.grey,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 16),
//           const Align(
//             alignment: Alignment.centerLeft,
//             child: Text(
//               'Fee Details:',
//               style: TextStyle(
//                 fontSize: 16,
//                 fontWeight: FontWeight.w500,
//               ),
//             ),
//           ),
//           const SizedBox(height: 12),
//           _buildFeeDetailRow('Monthly fee', '₹${studentData.fee?['monthly_fee'] ?? "0.00"}'),
//           _buildFeeDetailRow('Last Payment', studentData.fee?['last_payment_date'] ?? "-"),
//           _buildFeeDetailRow('Next Due', studentData.fee?['next_due_date'] ?? "-"),
//           const SizedBox(height: 20),
//         ],
//       ),
//     );
//   }
//   Widget buildProfessionalLoginPrompt() {
//     return Center(child: _LockLoginWidget());
//   }
//
//   // Widget buildProfessionalLoginPrompt() {
//   //   return AnimatedBuilder(
//   //     animation: Listenable.merge([_fadeAnimation, _scaleAnimation, _slideAnimation]),
//   //     builder: (context, child) {
//   //       return FadeTransition(
//   //         opacity: _fadeAnimation,
//   //         child: SlideTransition(
//   //           position: _slideAnimation,
//   //           child: ScaleTransition(
//   //             scale: _scaleAnimation,
//   //             child: Container(
//   //               padding: const EdgeInsets.all(24),
//   //               decoration: BoxDecoration(
//   //                 color: Colors.white,
//   //                 borderRadius: BorderRadius.circular(20),
//   //                 boxShadow: [
//   //                   BoxShadow(
//   //                     color: brandBlue.withOpacity(0.1),
//   //                     blurRadius: 20,
//   //                     offset: const Offset(0, 8),
//   //                   ),
//   //                   BoxShadow(
//   //                     color: Colors.grey.withOpacity(0.05),
//   //                     blurRadius: 10,
//   //                     offset: const Offset(0, 2),
//   //                   ),
//   //                 ],
//   //                 border: Border.all(
//   //                   color: brandBlue.withOpacity(0.1),
//   //                   width: 1,
//   //                 ),
//   //               ),
//   //               child: Column(
//   //                 children: [
//   //                   // Animated icon with pulse effect
//   //                   TweenAnimationBuilder(
//   //                     tween: Tween<double>(begin: 0.8, end: 1.2),
//   //                     duration: const Duration(milliseconds: 1500),
//   //                     curve: Curves.easeInOut,
//   //                     builder: (context, scale, child) {
//   //                       return Transform.scale(
//   //                         scale: scale,
//   //                         child: Container(
//   //                           width: 80,
//   //                           height: 80,
//   //                           decoration: BoxDecoration(
//   //                             gradient: LinearGradient(
//   //                               colors: [
//   //                                 brandBlue.withOpacity(0.2),
//   //                                 brandBlue.withOpacity(0.1),
//   //                               ],
//   //                               begin: Alignment.topLeft,
//   //                               end: Alignment.bottomRight,
//   //                             ),
//   //                             borderRadius: BorderRadius.circular(40),
//   //                             border: Border.all(
//   //                               color: brandBlue.withOpacity(0.3),
//   //                               width: 2,
//   //                             ),
//   //                           ),
//   //                           child: Icon(
//   //                             Icons.lock_outline_rounded,
//   //                             size: 40,
//   //                             color: brandBlue,
//   //                           ),
//   //                         ),
//   //                       );
//   //                     },
//   //                     onEnd: () {
//   //                       // Restart animation for continuous pulse effect
//   //                       Future.delayed(const Duration(milliseconds: 500), () {
//   //                         if (mounted) {
//   //                           setState(() {});
//   //                         }
//   //                       });
//   //                     },
//   //                   ),
//   //                   const SizedBox(height: 20),
//   //
//   //                   // Main heading with gradient text effect
//   //                   ShaderMask(
//   //                     shaderCallback: (bounds) => LinearGradient(
//   //                       colors: [brandBlue, brandBlue.withOpacity(0.7)],
//   //                       begin: Alignment.topLeft,
//   //                       end: Alignment.bottomRight,
//   //                     ).createShader(bounds),
//   //                     child: const Text(
//   //                       'Authentication Required',
//   //                       style: TextStyle(
//   //                         fontSize: 22,
//   //                         fontWeight: FontWeight.w700,
//   //                         color: Colors.white,
//   //                         letterSpacing: 0.5,
//   //                       ),
//   //                       textAlign: TextAlign.center,
//   //                     ),
//   //                   ),
//   //
//   //                 ],
//   //               ),
//   //             ),
//   //           ),
//   //         ),
//   //       );
//   //     },
//   //   );
//   // }
//
//   Widget buildGatePassSection(StudentData? studentData) {
//     return Center(
//       child: Container(
//         margin: const EdgeInsets.symmetric(horizontal: 16),
//         padding: const EdgeInsets.all(20),
//         width: double.infinity,
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(16),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.grey.withOpacity(0.1),
//               blurRadius: 10,
//               offset: const Offset(0, 4),
//             ),
//           ],
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.center,
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             const Text(
//               'GATE PASS',
//               style: TextStyle(
//                 fontSize: 16,
//                 fontWeight: FontWeight.w600,
//                 letterSpacing: 1.2,
//               ),
//             ),
//             const SizedBox(height: 16),
//             if (studentData != null &&
//                 studentData.gatePass != null &&
//                 studentData.gatePass!['qr_code'] != null)
//               Image.memory(
//                 base64Decode(studentData.gatePass!['qr_code'].split(',')[1]),
//                 width: 150,
//                 height: 150,
//               )
//             else
//               const Text(
//                 "Gate pass not issued yet",
//                 style: TextStyle(
//                   color: Colors.grey,
//                   fontSize: 14,
//                 ),
//               ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildRecommendedCard(String text, String imagePath, Color bgColor) {
//     return Container(
//       height: 120,
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: bgColor,
//         borderRadius: BorderRadius.circular(12),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.grey.withOpacity(0.1),
//             blurRadius: 8,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Container(
//             width: 40,
//             height: 40,
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(8),
//             ),
//             child: const Icon(
//               Icons.sports_basketball,
//               color: brandBlue,
//               size: 24,
//             ),
//           ),
//           const SizedBox(height: 8),
//           Expanded(
//             child: Text(
//               text,
//               style: const TextStyle(
//                 fontSize: 12,
//                 fontWeight: FontWeight.w500,
//                 color: Color(0xFF2D3748),
//               ),
//               maxLines: 3,
//               overflow: TextOverflow.ellipsis,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildFeeDetailRow(String label, String value) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 4),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Text(
//             label,
//             style: TextStyle(
//               color: Colors.grey[600],
//               fontSize: 14,
//             ),
//           ),
//           Text(
//             value,
//             style: const TextStyle(
//               fontWeight: FontWeight.w500,
//               fontSize: 14,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// class _LockLoginWidget extends StatefulWidget {
//   const _LockLoginWidget({super.key});
//
//   @override
//   State<_LockLoginWidget> createState() => _LockLoginWidgetState();
// }
//
// class _LockLoginWidgetState extends State<_LockLoginWidget>
//     with SingleTickerProviderStateMixin {
//   static const brandBlue = Color(0xFF1A237E);
//
//   late AnimationController _controller;
//   late Animation<double> _animation;
//   bool isLocked = true;
//
//   @override
//   void initState() {
//     super.initState();
//
//     _controller = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 1000),
//     );
//
//     _animation = Tween<double>(begin: 0, end: 1).animate(
//       CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
//     );
//
//     Future.delayed(const Duration(milliseconds: 500), () {
//       if (mounted) {
//         _toggleLock();
//       }
//     });
//   }
//
//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }
//
//   void _toggleLock() {
//     if (isLocked) {
//       _controller.forward();
//     } else {
//       _controller.reverse();
//     }
//     isLocked = !isLocked;
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       mainAxisSize: MainAxisSize.min, // So it stays centered
//       children: [
//
//         SizedBox(height: 80,),
//         GestureDetector(
//           onTap: () {
//             _toggleLock();
//           },
//           child: AnimatedBuilder(
//             animation: _animation,
//             builder: (context, child) {
//               return Transform.rotate(
//                 angle: _animation.value * 0.0, // subtle rotation
//                 child: Icon(
//                   isLocked ? Icons.lock_open : Icons.lock,
//                   size: 100,
//                   color: Colors.grey,
//                 ),
//               );
//             },
//           ),
//         ),
//         const SizedBox(height: 10),
//         InkWell(
//           onTap: () {
//             Navigator.pushAndRemoveUntil(
//               context,
//               MaterialPageRoute(builder: (context) => LoginScreen()),
//                   (route) => false,  // Remove all previous routes
//             );
//           },
//           borderRadius: BorderRadius.circular(4),
//           splashColor: brandBlue.withOpacity(0.2),
//           highlightColor: Colors.transparent,
//           child: Text(
//             "Click here to login",
//             style: TextStyle(
//               color: Colors.grey,
//               fontWeight: FontWeight.w500,
//               // decoration: TextDecoration.underline,
//               fontSize: 16,
//             ),
//           ),
//         ),
//       ],
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
// class StudentData {
//   final Map<String, dynamic> student;
//   final Map<String, dynamic>? fee;
//   final Map<String, dynamic>? gatePass;
//   final String? coachName;
//
//   StudentData({
//     required this.student,
//     this.fee,
//     this.gatePass,
//     this.coachName,
//   });
//
//   factory StudentData.fromJson(Map<String, dynamic> json) {
//     return StudentData(
//       student: json['student'],
//       fee: json['fee'],
//       gatePass: json['pass'],
//       coachName: json['coach_name'],
//     );
//   }
// }
//
// // class StudentData {
// //   final Map<String, dynamic> student;
// //   final Map<String, dynamic>? fee;
// //   final Map<String, dynamic>? gatePass;
// //   final String? coachName;
// //
// //   StudentData({
// //     required this.student,
// //     this.fee,
// //     this.gatePass,
// //     this.coachName,
// //   });
// //
// //   factory StudentData.fromJson(Map<String, dynamic> json) {
// //     return StudentData(
// //       student: json['student'] ?? {},
// //       fee: json['fee'] is Map ? json['fee'] : null,
// //       gatePass: json['pass'] is Map ? json['pass'] : null,
// //       coachName: json['coach_name']?.toString(),
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




import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_options.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:nahata_app/bottombar/profile.dart';
import 'package:nahata_app/bottombar/slotbook.dart';
import 'package:nahata_app/bottombar/event.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../auth/login.dart';
import '../main.dart';
import '../notification.dart';
import 'BookPlay.dart';
import 'Custombottombar.dart';
import 'Viewgame.dart';
import 'event.dart';

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:timeago/timeago.dart' as timeago;
class UserOptionsPage extends StatefulWidget {
  const UserOptionsPage({super.key});

  @override
  State<UserOptionsPage> createState() => _UserOptionsPageState();
}

class _UserOptionsPageState extends State<UserOptionsPage> {
  final String supportNumber = "+919876543210";

  Future<void> _callSupport() async {
    final Uri phoneUri = Uri(scheme: 'tel', path: supportNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      print("Cannot launch phone dialer");
    }
  }

  Future<void> _logout(BuildContext context) async {
    await AuthService.logout();
    // await AuthService.logout(); // clears prefs
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
      );
    }
    // // Navigate to login page after logout
    // Navigator.pushReplacement(
    //     context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.black87,
              size: 18,
            ),
          ),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => CustomBottomNav()),
            );


          },
        ),
        title: const Text(
          'User Options',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        // actions: [
        //   IconButton(
        //     icon: Container(
        //       padding: const EdgeInsets.all(8),
        //       decoration: BoxDecoration(
        //         color: Colors.white,
        //         borderRadius: BorderRadius.circular(12),
        //         boxShadow: [
        //           BoxShadow(
        //             color: Colors.black.withOpacity(0.1),
        //             blurRadius: 10,
        //             offset: const Offset(0, 2),
        //           ),
        //         ],
        //       ),
        //       child: const Icon(
        //         Icons.notifications_outlined,
        //         color: Colors.black87,
        //         size: 18,
        //       ),
        //     ),
        //     onPressed: () {},
        //   ),
        //   const SizedBox(width: 16),
        // ],
      ),
      body:Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ListTile(
              leading:  Icon(Icons.person),
              title: const Text('Profile'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => Screen(studentId: ApiService.currentUser?['student_id']?.toString() ?? '',)),
                );

              },
            ),

            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () => _logout(context),
            ),
            // ListTile(
            //   leading: const Icon(Icons.support_agent),
            //   title: const Text('Contact Support'),
            //   onTap: _callSupport,
            // ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share App'),
              onTap: () {
                Share.share('Check out this amazing app: https://play.google.com/store/apps/details?id=com.nahata_sports_app&pcampaignid=web_share');
              },
            ),
          ],
        ),
      ),
    );
  }
}

//
//
// class BlinkTooltip extends StatefulWidget {
//   @override
//   _BlinkTooltipState createState() => _BlinkTooltipState();
// }
//
// class _BlinkTooltipState extends State<BlinkTooltip> with SingleTickerProviderStateMixin {
//   late AnimationController _controller;
//   late Animation<double> _animation;
//
//   @override
//   void initState() {
//     super.initState();
//     _controller = AnimationController(
//       vsync: this,
//       duration: const Duration(seconds: 1),
//     )..repeat(reverse: true);
//
//     _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
//   }
//
//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return FadeTransition(
//       opacity: _animation,
//       child: Material(
//         elevation: 4,
//         shape: CircleBorder(),
//         color: Colors.redAccent,
//         child: Padding(
//           padding: const EdgeInsets.all(6.0),
//           child: Text(
//             "Login here",
//             style: TextStyle(
//               color: Colors.white,
//               fontSize: 10,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }




class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late PageController _pageController;
  int _currentPage = 0;
  String _locationText = 'Fetching location...';
  bool _isLoadingLocation = true;
  String userInitial = '?';
  bool isLoggedIn = false;

  final List<Map<String, String>> _venues = [
    {
      'name': 'Gangadham Chowk',
      'image': 'assets/23.webp',
    },
    {
      'name': 'Sinhgad Rd',
      'image': 'assets/56.jpg',
    },
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _getCurrentLocation();
    _fetchUserInitial();

    // Auto-slide every 3 seconds
    Future.delayed(const Duration(seconds: 2), _autoSlide);
  }
  void _fetchUserInitial() async {
    final user = await AuthService.getUser();
    print("👤 AuthService.getUser() result: $user"); // 👈 add this for debugging

    if (user != null && user['name'] != null && user['name'].toString().isNotEmpty) {
      userInitial = user['name'].toString().substring(0, 1).toUpperCase();
      isLoggedIn = true;
      print("✅ Logged in as: ${user['name']} | Initial: $userInitial");
    } else {
      userInitial = '?';
      isLoggedIn = false;
      print("⚠️ No user found, showing default '?'");
    }

    setState(() {});
  }
  Future<void> _getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationText = 'Enable Location';
          _isLoadingLocation = false;
        });
        return;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationText = 'Location Permission Denied';
            _isLoadingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationText = 'Enable Location Permission';
          _isLoadingLocation = false;
        });
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Reverse geocode using OpenStreetMap Nominatim (Free API)
      await _reverseGeocode(position.latitude, position.longitude);
    } catch (e) {
      setState(() {
        _locationText = 'Location Error';
        _isLoadingLocation = false;
      });
    }
  }
  Future<void> _reverseGeocode(double lat, double lon) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=18&addressdetails=1',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'NahataSportsApp/1.0'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'];
        print("📍 Raw Address: $address");

        // Collect parts safely (skip nulls and duplicates)
        List parts = [
          address['road'],
          address['neighbourhood'],
          address['suburb'],
          address['village'],
          address['town'],
          address['city_district'],
          address['city'],
          address['county'],
          address['state_district'],
          address['state'],
          address['postcode'],
          address['country'],
        ].where((e) => e != null && e.toString().trim().isNotEmpty).toSet().toList();

        // Join nicely
        String formatted = parts.join(', ');

        print("✅ Formatted Address: $formatted");

        setState(() {
          _locationText = formatted;
          _isLoadingLocation = false;
        });
      } else {
        print("⚠️ Error: ${response.statusCode}");
        setState(() {
          _locationText = 'Location Not Found';
          _isLoadingLocation = false;
        });
      }
    } catch (e) {
      print("❌ Reverse geocode error: $e");
      setState(() {
        _locationText = 'Location Error';
        _isLoadingLocation = false;
      });
    }
  }

  // Future<void> _reverseGeocode(double lat, double lon) async {
  //   try {
  //     // Using OpenStreetMap Nominatim API (Free, no API key required)
  //     final url = Uri.parse(
  //       'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=18&addressdetails=1',
  //     );
  //
  //     final response = await http.get(
  //       url,
  //       headers: {'User-Agent': 'FlutterSportsApp/1.0'},
  //     );
  //
  //     if (response.statusCode == 200) {
  //       final data = json.decode(response.body);
  //       final address = data['address'];
  //
  //       // Extract locality or suburb or town
  //       String location = address['suburb'] ??
  //           address['locality'] ??
  //           address['town'] ??
  //           address['city'] ??
  //           'Unknown Location';
  //
  //       setState(() {
  //         _locationText = location;
  //         _isLoadingLocation = false;
  //       });
  //     } else {
  //       setState(() {
  //         _locationText = 'Location Not Found';
  //         _isLoadingLocation = false;
  //       });
  //     }
  //   } catch (e) {
  //     setState(() {
  //       _locationText = 'Location Error';
  //       _isLoadingLocation = false;
  //     });
  //   }
  // }

  void _autoSlide() {
    if (!mounted) return;

    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;

      int nextPage = (_currentPage + 1) % _venues.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );

      _autoSlide();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            // Padding(
            //   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            //   child: Row(
            //     children: [
            //       // Live Location
            //       Expanded(
            //         child: Row(
            //           children: [
            //             Container(
            //               width: 6,
            //               height: 6,
            //               decoration: const BoxDecoration(
            //                 color: Colors.red,
            //                 shape: BoxShape.circle,
            //               ),
            //             ),
            //             const SizedBox(width: 6),
            //             const Text(
            //               'Live Location',
            //               style: TextStyle(
            //                 fontSize: 14,
            //                 color: Colors.black87,
            //                 fontWeight: FontWeight.w500,
            //               ),
            //             ),
            //             const Icon(
            //               Icons.keyboard_arrow_down,
            //               size: 20,
            //               color: Colors.black87,
            //             ),
            //           ],
            //         ),
            //       ),
            //       // Profile Avatar
            //       CircleAvatar(
            //         radius: 18,
            //         backgroundColor: Colors.grey[200],
            //         child: const Icon(
            //           Icons.person,
            //           color: Colors.grey,
            //           size: 20,
            //         ),
            //       ),
            //     ],
            //   ),
            // ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // 📍 Location section
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _isLoadingLocation
                              ? const Text(
                            'Fetching location...',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          )
                              : Text(
                            _locationText,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        // Dropdown icon
                        GestureDetector(
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: Colors.white,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                              ),
                              builder: (context) => Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[400],
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Location',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      _locationText,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Close'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          child: const Icon(
                            Icons.keyboard_arrow_down,
                            size: 22,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 🔔 Notification Icon
                  GestureDetector(
                    onTap: () {
                      // Navigate to Notifications screen
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const NotificationsPage()),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(Icons.notifications_none, size: 26, color: Colors.black87),
                          // Positioned(
                          //   right: 0,
                          //   top: -2,
                          //   child: Container(
                          //     width: 8,
                          //     height: 8,
                          //     decoration: const BoxDecoration(
                          //       color: Colors.red,
                          //       shape: BoxShape.circle,
                          //     ),
                          //   ),
                          // ),
                        ],
                      ),
                    ),
                  ),

                  // 👤 Profile Avatar
                  GestureDetector(
                    onTap: () {
                      print("🟢 Avatar tapped | isLoggedIn = $isLoggedIn");

                      if (isLoggedIn) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => Screen(
                              studentId: ApiService.currentUser?['student_id']?.toString() ?? '',
                            ),
                          ),
                        );
                      } else {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                              (route) => false,
                        );
                      }
                    },
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.blueAccent,
                      child: Text(
                        userInitial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),



            // Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  const SizedBox(height: 8),
                  // Main Booking Card
                  GestureDetector(
                    onTap: (){
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => VenueListScreen()),
                      );
                    },
                    child: Container(
                      height: 180,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        image: const DecorationImage(
                          image: NetworkImage(
                            'https://images.unsplash.com/photo-1612872087720-bb876e2e67d1?w=800',
                          ),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.3),
                            ],
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Book',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Book your slots in venues nearby',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Train With Us Card
                  GestureDetector(
                    onTap: (){
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SportsScreen()),
                      );
                    },
                    child: Container(
                      height: 95,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Image
                          ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              bottomLeft: Radius.circular(16),
                            ),
                            child: Image.network(
                              'https://images.unsplash.com/photo-1461896836934-ffe607ba8211?w=400',
                              width: 90,
                              height: 90,
                              fit: BoxFit.cover,
                            ),
                          ),
                          // Text Content
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'Train With Us',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Connect with certified coaches\nnearby to level up your game',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Basketball Court Card - Auto Sliding Carousel
                  Container(
                    height: 160,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: PageView.builder(
                            controller: _pageController,
                            onPageChanged: (index) {
                              setState(() {
                                _currentPage = index;
                              });
                            },
                            itemCount: _venues.length,
                            itemBuilder: (context, index) {
                              return GestureDetector(
                                onTap: () {
                                  // 👇 Navigate to Viewgame instead of SlotBookingScreen
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => Viewgame(locationName: _venues[index]['name']!),
                                    ),
                                  );

                                  // 👇 Print for debugging
                                  print("🟢 Navigating to Viewgame for location: ${_venues[index]['name']}");
                                },
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.asset(
                                      _venues[index]['image']!,
                                      fit: BoxFit.cover,
                                    ),
                                    Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.black.withOpacity(0.3),
                                            Colors.black.withOpacity(0.5),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.9),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              _venues[index]['name']!,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),

                        // ClipRRect(
                        //   borderRadius: BorderRadius.circular(16),
                        //   child: PageView.builder(
                        //     controller: _pageController,
                        //     onPageChanged: (index) {
                        //       setState(() {
                        //         _currentPage = index;
                        //       });
                        //     },
                        //     itemCount: _venues.length,
                        //     itemBuilder: (context, index) {
                        //       return Stack(
                        //         fit: StackFit.expand,
                        //         children: [
                        //           Image.network(
                        //             _venues[index]['image']!,
                        //             fit: BoxFit.cover,
                        //           ),
                        //           Container(
                        //             decoration: BoxDecoration(
                        //               gradient: LinearGradient(
                        //                 begin: Alignment.topCenter,
                        //                 end: Alignment.bottomCenter,
                        //                 colors: [
                        //                   Colors.black.withOpacity(0.3),
                        //                   Colors.black.withOpacity(0.5),
                        //                 ],
                        //               ),
                        //             ),
                        //           ),
                        //           Padding(
                        //             padding: const EdgeInsets.all(16),
                        //             child: Column(
                        //               crossAxisAlignment: CrossAxisAlignment.start,
                        //               children: [
                        //                 Container(
                        //                   padding: const EdgeInsets.symmetric(
                        //                     horizontal: 10,
                        //                     vertical: 4,
                        //                   ),
                        //                   decoration: BoxDecoration(
                        //                     color: Colors.white.withOpacity(0.9),
                        //                     borderRadius: BorderRadius.circular(6),
                        //                   ),
                        //                   child: Text(
                        //                     _venues[index]['name']!,
                        //                     style: const TextStyle(
                        //                       fontSize: 11,
                        //                       fontWeight: FontWeight.w600,
                        //                       color: Colors.black87,
                        //                     ),
                        //                   ),
                        //                 ),
                        //               ],
                        //             ),
                        //           ),
                        //         ],
                        //       );
                        //     },
                        //   ),
                        // ),
                        // Carousel Dots
                        Positioned(
                          bottom: 12,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              _venues.length,
                                  (index) => Container(
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: _currentPage == index
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.4),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Bottom Cards Row
                  Row(
                    children: [
                      // Bookings Card

                         Expanded(
                          child: GestureDetector(
                            onTap: (){
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => VenueListScreen()),
                              );
                            },
                            child: Container(
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.calendar_today_outlined,
                                        color: Colors.blue[600],
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Text(
                                            'Bookings',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Game History',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(width: 12),
                      // Events Card

                     Expanded(
                          child: GestureDetector(
                            onTap: (){
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => EventsScreen()),
                              );
                            },
                            child: Container(
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.event_outlined,
                                        color: Colors.blue[600],
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Text(
                                            'Events',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Upcoming Events',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// //////////////////////////////////////////////////////////////
//
// class HomeScreen extends StatefulWidget {
//   const HomeScreen({super.key});
//
//   @override
//   State<HomeScreen> createState() => _HomeScreenState();
// }
//
// class _HomeScreenState extends State<HomeScreen> {
//   int _currentBanner = 0;
//   // final List<Map<String, String>> banners = [
//   //   {
//   //     "image": "assets/1.jpg",
//   //     "url": "https://nahatasports.com/about_us?location=sinhagad"
//   //   },
//   //   {
//   //     "image": "assets/2.jpg",
//   //     "url": "https://nahatasports.com/about_us?location=gangadham"
//   //   },
//   //   {
//   //     "image": "assets/3.jpg",
//   //     "url": "https://nahatasports.com/about_us"
//   //   },
//   // ];
//   final List<String> banners = [
//     "assets/image.png",
//     "assets/23.webp",
//
//     // "assets/3.jpg",
//   ];
//
//
//   void _showBannerDetails() {
//     showDialog(
//       context: context,
//       builder: (context) => Dialog(
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//         child: SingleChildScrollView(
//           padding: EdgeInsets.all(16),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 "Sinhagad Road",
//                 style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//               ),
//               SizedBox(height: 10),
//               Text(
//                 "Transforming Future Champions, One Game at a Time\n\n"
//                     "At Nahata Sports, we're on a mission to inspire, train, and empower the next generation of athletes across Maharashtra. With facilities at Sinhagad Road and Gangadham Chowk, our multi-center complexes offer world-class training and seamless booking experiences that make sports easily accessible for all.",
//               ),
//               SizedBox(height: 15),
//               Text(
//                 "Expert Coaching Across Multiple Disciplines",
//                 style: TextStyle(fontWeight: FontWeight.bold),
//               ),
//               SizedBox(height: 5),
//               Text(
//                 "Our comprehensive programs cater to every skill level—from beginner to advanced. Athletes can choose from:\n\n"
//                     "- Cricket (in partnership with Rajasthan Royals Academy, Pune)\n"
//                     "- Badminton\n"
//                     "- Basketball\n"
//                     "- Skating\n"
//                     "- Karate\n"
//                     "- Dance & Zumba\n"
//                     "- Fun Fitness programs for motor skill development in children aged 3+",
//               ),
//               SizedBox(height: 15),
//               Text(
//                 "Book Your Game Anytime, Anywhere",
//                 style: TextStyle(fontWeight: FontWeight.bold),
//               ),
//               SizedBox(height: 5),
//               Text(
//                 "Need a space to play or train? Our Book & Play feature lets you reserve courts and grounds in real time—with hassle-free QR code payments offering fast, secure, and convenient access. Available for sports such as Badminton, Football, Pickleball, and Cricket.",
//               ),
//               SizedBox(height: 15),
//               Align(
//                 alignment: Alignment.centerRight,
//                 child: TextButton(
//                   onPressed: () => Navigator.pop(context),
//                   child: Text("Close"),
//                 ),
//               )
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   List<EventModel> _events = [];
//   bool _loadingEvents = true;
//
//   final List<String> categories = [
//     "Cricket",
//     "Basketball",
//     "Badminton",
//     "Skating",
//     "Karate",
//     "Dance",
//   ];
//
//   final List<Map<String, dynamic>> actionCategories = [
//     {"title": "Book & Play", "icon": Icons.sports_soccer},
//     {"title": "Coaching", "icon": Icons.person_2_rounded},
//     {"title": "Events", "icon": Icons.event},
//   ];
//
//   @override
//   void initState() {
//     super.initState();
//     _fetchUpcomingEvents();
//     initNotifications();
//
//   }
//
//   void initNotifications() async {
//     FirebaseMessaging messaging = FirebaseMessaging.instance;
//
//     // Request permission
//     await messaging.requestPermission(
//       alert: true,
//       badge: true,
//       sound: true,
//     );
//
//     // Get device token (optional, for sending targeted notifications)
//     String? token = await messaging.getToken();
//     print("Device FCM Token: $token");
//
//     // Foreground message
//     FirebaseMessaging.onMessage.listen((RemoteMessage message) {
//       RemoteNotification? notification = message.notification;
//       AndroidNotification? android = message.notification?.android;
//
//       if (notification != null && android != null) {
//         flutterLocalNotificationsPlugin.show(
//           notification.hashCode,
//           notification.title,
//           notification.body,
//           NotificationDetails(
//             android: AndroidNotificationDetails(
//               'high_importance_channel',
//               'High Importance Notifications',
//               channelDescription:
//               'This channel is used for important notifications.',
//               importance: Importance.high,
//               priority: Priority.high,
//             ),
//           ),
//         );
//       }
//     });
//
//     // When app opened from notification
//     FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
//       Navigator.push(
//         context,
//         MaterialPageRoute(builder: (_) => const NotificationsPage()),
//       );
//     });
//   }
//   void _openLocationPage() {
//     // Navigate to the new page with TabBar
//     Navigator.push(
//       context,
//       MaterialPageRoute(builder: (context) => LocationInfoPage()),
//     );
//   }
//
//   Future<void> _fetchUpcomingEvents() async {
//     try {
//       final res = await http.get(
//         Uri.parse("https://nahatasports.com/api/tournaments"),
//         headers: {"Content-Type": "application/json"},
//       );
//
//       if (!mounted) return;
//
//       if (res.statusCode == 200) {
//         final body = jsonDecode(res.body);
//         final List data = body['data'] ?? [];
//
//         setState(() {
//           _events = data.map((e) => EventModel.fromJson(e)).toList();
//           _loadingEvents = false;
//         });
//       } else {
//         setState(() => _loadingEvents = false);
//         _showSnack("Failed to fetch events");
//       }
//     } catch (e, st) {
//       debugPrint("Error fetching events: $e\n$st");
//       setState(() => _loadingEvents = false);
//       _showSnack("Error loading events");
//     }
//   }
//
//   List<dynamic> notifications = [];
//
//   Future<void> fetchNotifications() async {
//     final response = await http.get(
//       Uri.parse('https://nahatasports.com/api/notifications/status'),
//     );
//
//     if (response.statusCode == 200) {
//       final data = json.decode(response.body);
//       setState(() {
//         notifications = data['notifications'];
//       });
//       print(notifications);
//       print(data);
//       print(response.body);
//     } else {
//       // Handle error
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Failed to fetch notifications')),
//       );
//     }
//   }
//
//   void showNotificationsDialog() {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Notifications'),
//         content: SizedBox(
//           width: double.maxFinite,
//           child: notifications.isEmpty
//               ? const Text('No notifications')
//               : ListView.builder(
//             shrinkWrap: true,
//             itemCount: notifications.length,
//             itemBuilder: (context, index) {
//               final notif = notifications[index];
//               return ListTile(
//                 leading: notif['image'] != null
//                     ? Image.network(
//                   notif['image'],
//                   width: 40,
//                   height: 40,
//                   fit: BoxFit.cover,
//                 )
//                     : const Icon(Icons.notifications),
//                 title: Text(notif['title']),
//                 subtitle: Text(notif['body']),
//                 trailing: Text(notif['status']),
//               );
//             },
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Close'),
//           ),
//         ],
//       ),
//     );
//   }
//
//
//
//   void _showSnack(String msg) {
//     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
//   }
//   final List<Map<String, String>> events = [
//     {
//       "title": "Cricket Coaching",
//       "image": "assets/cricket.png",
//       "location": "Sinhgad Road",
//       // "date": "20 Sep 2025",
//     },
//     {
//       "title": "Badminton",
//       "image": "assets/bad.jpg",
//       "location": "Sinhgad Road",
//       "subtitle": "Enjoy your Happy Hour Prime Hour", // 👈 extra text only for badminton
//     },
//     // {
//     //   "title": "Zumba Dance Workshop",
//     //   "image": "assets/3.jpg",
//     //   "location": "FC Road",
//     //   "date": "28 Sep 2025",
//     // },
//   ];
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         elevation: 0,
//         backgroundColor: Colors.white,
//         title: Row(
//           children: [
//             const Icon(Icons.location_on, color: Color(0xFF1A237E)),
//             const SizedBox(width: 4),
//             Expanded(
//               child: Text(
//                 "Pune",
//                 style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
//               ),
//             ),
//             // IconButton(
//             //   icon: const Icon(Icons.notifications, color: Colors.black),
//             //   onPressed: () async {
//             //     await fetchNotifications();
//             //     showNotificationsDialog();
//             //   },
//             // ),
//             IconButton(
//               icon: const Icon(Icons.notifications, color: Colors.black),
//               onPressed: () {
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(builder: (_) => const NotificationsPage()),
//                 );
//               },
//             ),
//
//             IconButton(
//               icon: const Icon(Icons.person, color: Colors.black),
//               onPressed: () {
//                 Navigator.pushReplacement(
//                     context, MaterialPageRoute(builder: (_) => const UserOptionsPage()));
//               },
//             ),
//           ],
//         ),
//       ),
//       body: SingleChildScrollView(
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//         CarouselSlider(
//         options: CarouselOptions(
//         height: 180,
//           autoPlay: true,
//           viewportFraction: 0.9,
//           enlargeCenterPage: true,
//           onPageChanged: (index, reason) {
//             setState(() => _currentBanner = index);
//           },
//         ),
//         items: banners.asMap().entries.map((entry) {
//           int index = entry.key;
//           String asset = entry.value;
//           return GestureDetector(
//             onTap: () {
//               // Navigate to LocationInfoPage with the correct tab
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(
//                   builder: (context) => LocationInfoPage(initialTab: index),
//                 ),
//               );
//             },
//             child: ClipRRect(
//               borderRadius: BorderRadius.circular(12),
//               child: Image.asset(
//                 asset,
//                 fit: BoxFit.cover,
//                 width: double.infinity,
//               ),
//             ),
//           );
//         }).toList(),
//       ),        // CarouselSlider(
//         //   options: CarouselOptions(
//         //     height: 180,
//         //     autoPlay: true,
//         //     viewportFraction: 0.9,
//         //     enlargeCenterPage: true,
//         //     onPageChanged: (index, reason) {
//         //       setState(() => _currentBanner = index);
//         //     },
//         //   ),
//         //   items: banners.map((asset) {
//         //     return GestureDetector(
//         //       onTap: _showBannerDetails,
//         //       child: ClipRRect(
//         //         borderRadius: BorderRadius.circular(12),
//         //         child: Image.asset(
//         //           asset,
//         //           fit: BoxFit.cover,
//         //           width: double.infinity,
//         //         ),
//         //       ),
//         //     );
//         //   }).toList(),
//         // ),
//
//             Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: banners.asMap().entries.map((entry) {
//                 return Container(
//                   width: 8,
//                   height: 8,
//                   margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 3.0),
//                   decoration: BoxDecoration(
//                     shape: BoxShape.circle,
//                     color: _currentBanner == entry.key ? Colors.red : Colors.grey,
//                   ),
//                 );
//               }).toList(),
//             ),
//
//             // Upcoming Events Title
//             const Padding(
//               padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 12),
//               child: Text(
//                 "Upcoming Events",
//                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
//               ),
//             ),
//
//             // Horizontal Upcoming Events
//             SizedBox(
//               height: 280,
//               child: _loadingEvents
//                   ? const Center(child: CircularProgressIndicator())
//                   : ListView.builder(
//                 scrollDirection: Axis.horizontal,
//                 padding: const EdgeInsets.symmetric(horizontal: 12),
//                 itemCount: _events.length,
//                 itemBuilder: (context, index) {
//                   final event = _events[index];
//                   return GestureDetector(
//                     onTap: () {
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                           builder: (_) => EventDetailsPage(event: event),
//                         ),
//                       );
//                     },
//                     child: Container(
//                       width: 180,
//                       margin: const EdgeInsets.only(right: 12),
//                       decoration: BoxDecoration(
//                         borderRadius: BorderRadius.circular(12),
//                         color: Colors.white,
//                         boxShadow: [
//                           BoxShadow(
//                             color: Colors.grey.shade200,
//                             spreadRadius: 1,
//                             blurRadius: 5,
//                           )
//                         ],
//                       ),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           ClipRRect(
//                             borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
//                             child: Image.network(
//                               event.image,
//                               height: 190,
//                               width: 180,
//                               fit: BoxFit.cover,
//                             ),
//                           ),
//                           Expanded(
//                             child : Padding(
//                               padding: const EdgeInsets.all(8.0),
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   Text(
//                                     event.title,
//                                     style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
//                                     maxLines: 2,
//                                     overflow: TextOverflow.ellipsis,
//                                   ),
//                                   const SizedBox(height: 4),
//                                   Text(
//                                     event.location,
//                                     style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
//                                   ),
//                                   const SizedBox(height: 4),
//                                   // Text(
//                                   //   event.date,
//                                   //   style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
//                                   // ),
//                                 ],
//                               ),
//                             ),
//                           )
//                         ],
//                       ),
//                     ),
//                   );
//                 },
//               ),
//             ),
//
//             /// 🔹 Recommended Section (Vertical List)
//       /// 🔹 Recommended Section (Vertical List)
//       Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12),
//         child: const Text(
//           "Recommended for You",
//           style: TextStyle(
//             fontSize: 18,
//             fontWeight: FontWeight.bold,
//             color: Colors.black,
//           ),
//         ),
//       ),
//       ListView.builder(
//         shrinkWrap: true,
//         physics: const NeverScrollableScrollPhysics(),
//         itemCount: events.length,
//         itemBuilder: (context, index) {
//           final event = events[index];
//           return InkWell(
//             borderRadius: BorderRadius.circular(12),
//             onTap: () {
//               if (event["title"] == "Cricket Coaching") {
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (_) => BatchScreen(
//                       sportId: "40", // ✅ cricket sportId from API
//                       sportName: "Cricket",
//                     ),
//                   ),
//                 );
//               } else if (event["title"] == "Badminton") {
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (context) => SlotBookingScreen(
//                       location: "Singhgad Road", // pass actual location
//                       game: "Badminton",         // pass actual game
//                     ),
//                   ),
//                 );
//
//               } else {
//                 // Navigator.push(
//                 //   context,
//                 //   MaterialPageRoute(builder: (_) => GenericEventScreen(event: event)),
//                 // );
//               }
//             },
//             child: Container(
//               margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//               decoration: BoxDecoration(
//                 borderRadius: BorderRadius.circular(12),
//                 color: Colors.white,
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.grey.shade200,
//                     spreadRadius: 1,
//                     blurRadius: 5,
//                   )
//                 ],
//               ),
//               child: Row(
//                 children: [
//                   ClipRRect(
//                     borderRadius:
//                     const BorderRadius.horizontal(left: Radius.circular(12)),
//                     child: Image.asset(
//                       event["image"]!,
//                       height: 100,
//                       width: 120,
//                       fit: BoxFit.cover,
//                     ),
//                   ),
//                   Expanded(
//                     child: Padding(
//                       padding: const EdgeInsets.all(8.0),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             event["title"]!,
//                             style: const TextStyle(
//                               fontSize: 14,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                           const SizedBox(height: 2),
//                           if (event["subtitle"] != null)
//                             Text(
//                               event["subtitle"]!,
//                               style: const TextStyle(
//                                 fontSize: 10,
//                                 color: Colors.orange,
//                                 fontWeight: FontWeight.w500,
//                               ),
//                             ),
//                           const SizedBox(height: 4),
//                           Text(
//                             event["location"]!,
//                             style: TextStyle(
//                               fontSize: 12,
//                               color: Colors.grey.shade600,
//                             ),
//                           ),
//                           const SizedBox(height: 4),
//                         ],
//                       ),
//                     ),
//                   )
//                 ],
//               ),
//             ),
//           );
//         },
//       )
//
//       ],
//         ),
//       ),
//     );
//   }
// }
//
//////////////////////////////////////////////////////////////////////////////////////////////////////






// class EventModel {
//   final String id;
//   final String title;
//   final String image;
//   final String location;
//   final String date;
//
//   EventModel({
//     required this.id,
//     required this.title,
//     required this.image,
//     required this.location,
//     required this.date,
//   });
//
//   factory EventModel.fromJson(Map<String, dynamic> json) {
//     return EventModel(
//       id: json['id'].toString(),
//       // id: json['id'] is int
//       //     ? json['id']
//       //     : int.tryParse(json['id'].toString()) ?? 0,
//       title: json['title'] ?? '',
//       image: "https://nahatasports.com/${json['image'] ?? ''}",
//       location: json['location'] ?? '',
//       date: json['date'] ?? '',
//     );
//   }
//
// }

class LocationInfoPage extends StatefulWidget {
  final int initialTab; // 0 = Sinhagad Road, 1 = Gangadham Chowk

  const LocationInfoPage({Key? key, this.initialTab = 0}) : super(key: key);

  @override
  _LocationInfoPageState createState() => _LocationInfoPageState();
}

class _LocationInfoPageState extends State<LocationInfoPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
  }

  Widget _buildDescription(String location) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(location,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          SizedBox(height: 10),
          Text(
            "Transforming Future Champions, One Game at a Time\n\n"
                "At Nahata Sports, we're on a mission to inspire, train, and empower the next generation of athletes across Maharashtra. With facilities at Sinhagad Road and Gangadham Chowk, our multi-center complexes offer world-class training and seamless booking experiences that make sports easily accessible for all.",
          ),
          SizedBox(height: 15),
          Text(
            "Expert Coaching Across Multiple Disciplines",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 5),
          Text(
            "Our comprehensive programs cater to every skill level—from beginner to advanced. Athletes can choose from:\n\n"
                "- Cricket (in partnership with Rajasthan Royals Academy, Pune)\n"
                "- Badminton\n"
                "- Basketball\n"
                "- Skating\n"
                "- Karate\n"
                "- Dance & Zumba\n"
                "- Fun Fitness programs for motor skill development in children aged 3+",
          ),
          SizedBox(height: 15),
          Text(
            "Book Your Game Anytime, Anywhere",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 5),
          Text(
            "Need a space to play or train? Our Book & Play feature lets you reserve courts and grounds in real time—with hassle-free QR code payments offering fast, secure, and convenient access. Available for sports such as Badminton, Football, Pickleball, and Cricket.",
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF1A237E),
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.orange,
          labelColor: Colors.orange,
          unselectedLabelColor: Colors.orange,
          tabs: [
            Tab(text: "Sinhagad Road"),
            Tab(text: "Gangadham Chowk"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDescription("Sinhagad Road"),
          _buildDescription("Gangadham Chowk"),
        ],
      ),
    );
  }
}



























class Screen extends StatefulWidget {
  final String studentId;
  const Screen({Key? key, required this.studentId}) : super(key: key);

  @override
  State<Screen> createState() => _ScreenState();
}

class _ScreenState extends State<Screen> {
  static const brandBlue = Color(0xFF1A237E);
  int _selectedIndex = 0;
  bool isLoading = true;
  StudentData? studentData;
  late final String studentId;
  late Future<List<StudentData>> studentsFuture;
  String userInitial = '';
  @override
  void initState() {
    super.initState();
    studentsFuture = _initAndFetch();
    fetchUserInitial();
  }
  void fetchUserInitial() async {
    final user = await AuthService.getUser();

    if (user != null && user['name'] != null && user['name'].toString().isNotEmpty) {
      userInitial = user['name'].toString().substring(0, 1).toUpperCase();
    } else {
      userInitial = 'U'; // fallback
    }

    setState(() {});
  }

  /// First load user, then fetch API
  Future<List<StudentData>> _initAndFetch() async {
    await ApiService.loadUserFromPrefs();

    final id = widget.studentId.isNotEmpty
        ? widget.studentId
        : (ApiService.currentUser?['student_id']?.toString() ?? '');

    if (id.isEmpty) {
      throw Exception("Student ID is not available");
    }

    return fetchStudents(int.parse(id));
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

        return [
          StudentData.fromJson(data)

          // StudentData.fromJson({
          //   "student": data['student'],
          //   "fee": data['fee'],
          //   "gatePass": data['pass'],
          //   "coachName": data['coach_name'],
          // })
        ];
      } else {
        throw Exception("API returned false status");
      }
    } else {
      throw Exception("Failed to fetch data");
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Profile',
          style: TextStyle(
            color: brandBlue,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
        actions: [
          // IconButton(
          //   onPressed: () {},
          //   icon: Stack(
          //     children: [
          //       const Icon(
          //         Icons.notifications_outlined,
          //         color: brandBlue,
          //         size: 26,
          //       ),
          //       Positioned(
          //         right: 0,
          //         top: 0,
          //         child: Container(
          //           padding: const EdgeInsets.all(2),
          //           decoration: BoxDecoration(
          //             color: Colors.red,
          //             borderRadius: BorderRadius.circular(6),
          //           ),
          //           constraints: const BoxConstraints(
          //             minWidth: 12,
          //             minHeight: 12,
          //           ),
          //           child: const Text(
          //             '3',
          //             style: TextStyle(
          //               color: Colors.white,
          //               fontSize: 8,
          //               fontWeight: FontWeight.bold,
          //             ),
          //             textAlign: TextAlign.center,
          //           ),
          //         ),
          //       ),
          //     ],
          //   ),
          // ),
          // const SizedBox(width: 8),
          // GestureDetector(
          //   onTap: () {
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(builder: (context) => UserOptionsPage()),
          //     );
          //   },
          //   child: Container(
          //     margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
          //     child: CircleAvatar(
          //       radius: 18,
          //       backgroundColor: brandBlue,
          //       child: Text(
          //         userInitial.isNotEmpty ? userInitial : '?',
          //         style: const TextStyle(
          //           color: Colors.white,
          //           fontWeight: FontWeight.bold,
          //           fontSize: 16,
          //         ),
          //       ),
          //     ),
          //   ),
          // ),
        ],
      ),
      body: FutureBuilder<List<StudentData>>(
          future: studentsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: brandBlue));
            } else if (snapshot.hasError) {
              return Center(child: Text("❌ Error: ${snapshot.error}"));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text("No data available"));
            }

            final studentData = snapshot.data!.first;
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero Section
                  // Container(
                  //   margin: const EdgeInsets.all(16),
                  //   height: 120,
                  //   decoration: BoxDecoration(
                  //     borderRadius: BorderRadius.circular(16),
                  //     gradient: LinearGradient(
                  //       colors: [brandBlue, brandBlue.withOpacity(0.8)],
                  //       begin: Alignment.topLeft,
                  //       end: Alignment.bottomRight,
                  //     ),
                  //     boxShadow: [
                  //       BoxShadow(
                  //         color: brandBlue.withOpacity(0.3),
                  //         blurRadius: 12,
                  //         offset: const Offset(0, 4),
                  //       ),
                  //     ],
                  //   ),
                  //   child: Stack(
                  //     children: [
                  //       Positioned(
                  //         right: -20,
                  //         top: -20,
                  //         child: Container(
                  //           width: 100,
                  //           height: 100,
                  //           decoration: BoxDecoration(
                  //             color: Colors.white.withOpacity(0.1),
                  //             shape: BoxShape.circle,
                  //           ),
                  //         ),
                  //       ),
                  //       // Padding(
                  //       //   padding: const EdgeInsets.all(20),
                  //       //   child: Row(
                  //       //     children: [
                  //       //       Expanded(
                  //       //         child: Column(
                  //       //           crossAxisAlignment: CrossAxisAlignment.start,
                  //       //           mainAxisAlignment: MainAxisAlignment.center,
                  //       //           children: [
                  //       //             const Text(
                  //       //               'Welcome Back!',
                  //       //               style: TextStyle(
                  //       //                 color: Colors.white,
                  //       //                 fontSize: 18,
                  //       //                 fontWeight: FontWeight.w600,
                  //       //               ),
                  //       //             ),
                  //       //             const SizedBox(height: 4),
                  //       //             Text(
                  //       //               'Ready for your next game?',
                  //       //               style: TextStyle(
                  //       //                 color: Colors.white.withOpacity(0.9),
                  //       //                 fontSize: 14,
                  //       //               ),
                  //       //             ),
                  //       //           ],
                  //       //         ),
                  //       //       ),
                  //       //       Container(
                  //       //         width: 60,
                  //       //         height: 60,
                  //       //         decoration: BoxDecoration(
                  //       //           color: Colors.white.withOpacity(0.2),
                  //       //           borderRadius: BorderRadius.circular(12),
                  //       //         ),
                  //       //         child: const Icon(
                  //       //           Icons.sports_soccer,
                  //       //           color: Colors.white,
                  //       //           size: 32,
                  //       //         ),
                  //       //       ),
                  //       //     ],
                  //       //   ),
                  //       // ),
                  //     ],
                  //   ),
                  // ),

                  // Recommended Section
                  // Padding(
                  //   padding: const EdgeInsets.symmetric(horizontal: 16),
                  //   child: Column(
                  //     crossAxisAlignment: CrossAxisAlignment.start,
                  //     children: [
                  //       const Text(
                  //         'Recommended',
                  //         style: TextStyle(
                  //           fontSize: 20,
                  //           fontWeight: FontWeight.w600,
                  //           color: Color(0xFF2D3748),
                  //         ),
                  //       ),
                  //       const SizedBox(height: 16),
                  //       Row(
                  //         children: [
                  //           Expanded(
                  //             child: _buildRecommendedCard(
                  //               'Let\'s figure out what live events look like now',
                  //               'assets/sports1.jpg',
                  //               Colors.orange[100]!,
                  //             ),
                  //           ),
                  //           const SizedBox(width: 12),
                  //           Expanded(
                  //             child: _buildRecommendedCard(
                  //               'Explore game happening now!',
                  //               'assets/sports2.jpg',
                  //               Colors.blue[100]!,
                  //             ),
                  //           ),
                  //         ],
                  //       ),
                  //     ],
                  //   ),
                  // ),
                  //
                  // const SizedBox(height: 24),

                  // User Profile Card
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Name: ${studentData.student['name'] ?? "-"}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'ID: ${studentData.student['id'] ?? "-"}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Fee Details:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildFeeDetailRow('Monthly fee',
                            '₹${studentData.fee?['monthly_fee'] ?? "0.00"}'),
                        _buildFeeDetailRow('Last Payment',
                            studentData.fee?['last_payment_date'] ?? "-"),
                        _buildFeeDetailRow('Next Due',
                            studentData.fee?['next_due_date'] ?? "-"),
                        const SizedBox(height: 20),

                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Gate Pass Section
                  // Gate Pass Section
                  Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(20),
                      width: double.infinity,
                      // or a fixed width if you like
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'GATE PASS',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Container(
                          //   width: 80,
                          //   height: 80,
                          //   decoration: BoxDecoration(
                          //     color: Colors.grey[100],
                          //     borderRadius: BorderRadius.circular(12),
                          //   ),
                          //   child: Icon(
                          //     Icons.qr_code,
                          //     size: 40,
                          //     color: Colors.grey[400],
                          //   ),
                          // ),
                          // const SizedBox(height: 16),
                          // Text(
                          //   'Gate pass not issued yet',
                          //   style: TextStyle(
                          //     color: Colors.grey[600],
                          //     fontSize: 14,
                          //   ),
                          // ),
                          const SizedBox(height: 16),
                          if (studentData.gatePass != null &&
                              studentData.gatePass!['qr_code'] != null)
                            Image.memory(
                              base64Decode(
                                  studentData.gatePass!['qr_code'].split(',')[1]),
                              width: 150,
                              height: 150,
                            )
                          else
                            const Text(
                              "Gate pass not issued yet",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 20,)

                  // Space for bottom navigation
                ],
              ),
            );
          }
      ),
    );


  }

  Widget _buildRecommendedCard(String text, String imagePath, Color bgColor) {
    return Container(
      height: 120,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.sports_basketball,
              color: brandBlue,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF2D3748),
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeeDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }}





//
// class StudentData {
//   final Map<String, dynamic> student;
//   final Map<String, dynamic>? fee;
//   final Map<String, dynamic>? gatePass;
//   final String? coachName;
//
//   StudentData({
//     required this.student,
//     this.fee,
//     this.gatePass,
//     this.coachName,
//   });
//
//   factory StudentData.fromJson(Map<String, dynamic> json) {
//     return StudentData(
//       student: json['student'],
//       fee: json['fee'],
//       gatePass: json['pass'],
//       coachName: json['coach_name'],
//     );
//   }
// }
//
class StudentData {
  final Map<String, dynamic> student;
  final Map<String, dynamic>? fee;
  final Map<String, dynamic>? gatePass;
  final String? coachName;

  StudentData({
    required this.student,
    this.fee,
    this.gatePass,
    this.coachName,
  });

  factory StudentData.fromJson(Map<String, dynamic> json) {
    return StudentData(
      student: json['student'] ?? {},
      fee: json['fee'] is Map ? json['fee'] : null,
      gatePass: json['pass'] is Map ? json['pass'] : null,
      coachName: json['coach_name']?.toString(),
    );
  }
}