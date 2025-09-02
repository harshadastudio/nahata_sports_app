import 'package:flutter/material.dart';
import 'package:nahata_app/dashboard/admin_screen.dart';
import 'package:nahata_app/dashboard/security_screen.dart';
import 'package:nahata_app/dashboard/students_parents.dart';
import 'package:nahata_app/screens/login_screen.dart';

import '../events2.dart';
import '../screens/Events.dart';
import '../services/api_service.dart';
import 'coach_screen.dart';

// class DashboardScreen extends StatefulWidget {
//   const DashboardScreen({super.key});
//   @override
//   State<DashboardScreen> createState() => _DashboardScreenState();
// }
//
// class _DashboardScreenState extends State<DashboardScreen> {
//   int _selectedIndex = 0;
//   Widget _buildNavItem(IconData icon, String label, Widget targetScreen, int index) {
//     final isSelected = _selectedIndex == index;
//     final color = isSelected ? Colors.blue : Colors.grey;
//
//     return GestureDetector(
//       onTap: () {
//         setState(() {
//           _selectedIndex = index; // update selected index
//         });
//         Navigator.push(
//           context,
//           MaterialPageRoute(builder: (_) => targetScreen),
//         );
//       },
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Text(label, style: TextStyle(color: color, fontSize: 14, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
//           const SizedBox(height: 4),
//           Icon(icon, color: color, size: 24),
//         ],
//       ),
//     );
//   }
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("Nahata Sports Dashboard"),
//         centerTitle: true,
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Fees & Receipts
//             Card(
//               child: ListTile(
//                 leading: const Icon(Icons.sports_bar),
//                 title: const Text("Sports"),
//                 subtitle: const Text("View Sports"),
//                 onTap: () {
//                   // Navigate to fees details
//                 },
//               ),
//             ),
//
//             // Attendance
//             Card(
//               child: ListTile(
//                 leading: const Icon(Icons.check_circle_outline),
//                 title: const Text("Booked Court Response"),
//                 subtitle: const Text("Court Responses"),
//                 onTap: () {
//                   // Navigate to attendance screen
//                 },
//               ),
//             ),
//
//             // Coach Feedback
//             Card(
//               child: ListTile(
//                 leading: const Icon(Icons.feedback_outlined),
//                 title: const Text("Feedback"),
//                 subtitle: const Text("See feedback"),
//                 onTap: () {
//                   // Navigate to feedback screen
//                 },
//               ),
//             ),
//
//             // Book & Play — Upcoming Bookings
//             Card(
//               child: ListTile(
//                 leading: const Icon(Icons.sports_baseball),
//                 title: const Text("Book & Play"),
//                 subtitle: const Text("Reserve courts or sessions"),
//                 onTap: () {
//                   Navigator.pushNamed(context, '/location');
//                 },
//               ),
//             ),
//             Card(
//               child: ListTile(
//                 leading: const Icon(Icons.people_alt_outlined),
//                 title: const Text("Students & Parents"),
//                 subtitle: const Text("View details"),
//                 onTap: () {
//                   final studentId = ApiService.currentUser?['student_id']?.toString() ?? '';
//
//                   if (studentId.isEmpty) {
//                     ScaffoldMessenger.of(context).showSnackBar(
//                       const SnackBar(content: Text("Student ID is not available")),
//                     );
//                     return; // stop navigation
//                   }
//
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(
//                       builder: (_) => StudentsParentsScreen(studentId: studentId),
//                     ),
//                   );
//                 },
//               ),
//             ),
//
//
//             // Card(
//             //   child: ListTile(
//             //     leading: const Icon(Icons.people_alt_outlined),
//             //     title: const Text("Students & Parents"),
//             //     subtitle: const Text("View details"),
//             //     onTap: () {
//             //       // Navigate to dashboard after login
//             //       Navigator.push(
//             //         context,
//             //         MaterialPageRoute(
//             //           builder: (_) => StudentsParentsScreen(studentId: ApiService.currentUser?['student_id']?.toString() ?? '',),
//             //         ),
//             //       );
//             //
//             //     },
//             //   ),
//             // ),
//             const SizedBox(height: 20),
//             // Upcoming Events & Announcements
//             const Text(
//               "Announcements & Events",
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 8),
//             // Example announcement items
//             ...[
//               "Free Training Camps",
//               "Holiday Notices",
//               "Upcoming Tournaments"
//             ].map((item) =>
//                 Card(
//                   child: ListTile(
//                     title: Text(item),
//                     trailing: const Icon(Icons.arrow_forward_ios, size: 16),
//                     onTap: () {
//                       // Navigate to announcement detail
//                     },
//                   ),
//                 )),
//           ],
//         ),
//       ),
//
//       // bottomNavigationBar: BottomNavigationBar(
//       //   items: const [
//       //     BottomNavigationBarItem(icon: Icon(Icons.people,color: Colors.black,), label: "Students"),
//       //     BottomNavigationBarItem(icon: Icon(Icons.perm_contact_cal,color: Colors.black,), label: "Coach"),
//       //     BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings,color: Colors.black,), label: "Admin"),
//       //     BottomNavigationBarItem(icon: Icon(Icons.security,color: Colors.black,), label: "Security"),
//       //   ],
//       //   onTap: (index) {
//       //     // Handle bottom nav tap
//       //   },
//       // ),
//
//       // bottomNavigationBar: BottomAppBar(
//       //   color: Colors.white,
//       //   elevation: 10,
//       //   child: Row(
//       //     mainAxisAlignment: MainAxisAlignment.spaceAround,
//       //     children: [
//       //       _buildNavItem(Icons.people, "Students", DashboardScreen(), 0),
//       //       _buildNavItem(Icons.perm_contact_cal, "Coach", CoachDashboardScreen(), 1),
//       //       _buildNavItem(Icons.admin_panel_settings, "Admin", AdminDashboardScreen(), 2),
//       //       _buildNavItem(Icons.security, "Security", security_screen(), 3),
//       //     ],
//       //   ),
//       // ),
//
//
//     );
//   }
//   //
//   // Widget _buildNavItem(IconData icon, String label, Widget targetScreen,
//   //     BuildContext context) {
//   //   return GestureDetector(
//   //     onTap: () {
//   //       Navigator.push(
//   //         context,
//   //         MaterialPageRoute(builder: (_) => targetScreen),
//   //       );
//   //     },
//   //     child: Column(
//   //       mainAxisSize: MainAxisSize.min,
//   //       children: [
//   //         Text(
//   //             label, style: const TextStyle(color: Colors.black, fontSize: 14)),
//   //         const SizedBox(height: 4),
//   //         Icon(icon, color: Colors.black, size: 24),
//   //       ],
//   //     ),
//   //   );
//   // }
//
// }










class BookPlayScreen extends StatefulWidget {
  const BookPlayScreen({super.key});

  @override
  State<BookPlayScreen> createState() => _BookPlayScreenState();
}

class _BookPlayScreenState extends State<BookPlayScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: Duration(milliseconds: 600));
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildCard(String title, IconData icon, VoidCallback onTap) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(20),
          margin: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: Color(0xFF0A198D),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              SizedBox(width: 20),
              Text(
                title,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Color(0xFF0A198D),
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
           onPressed: (){
             Navigator.pushReplacement(
               context,
               MaterialPageRoute(builder: (_) => LoginScreen()), // or any other screen
             );
           },
          ),
          title: Text(
            "Students & Parents",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          centerTitle: true,
        ),

        backgroundColor: Color(0xFFF5F5F5),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 20),
            _buildCard("Book and Play", Icons.sports_basketball, () {
              Navigator.pushNamed(context, '/location');
            }),

            _buildCard("Students and Parents", Icons.people, () {
                                Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StudentsParentsScreen(studentId: ApiService.currentUser?['student_id']?.toString() ?? '',),
                      ),
                    );

            }),
            _buildCard("Events", Icons.event, (){
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>EventsListPage(),
                ),
              );

            })
          ],
        ),
      ),
    );
  }
}
