import 'package:flutter/material.dart';
import 'package:nahata_app/dashboard/admin_screen.dart';
import 'package:nahata_app/dashboard/security_screen.dart';

import 'coach_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  Widget _buildNavItem(IconData icon, String label, Widget targetScreen, int index) {
    final isSelected = _selectedIndex == index;
    final color = isSelected ? Colors.blue : Colors.grey;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index; // update selected index
        });
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => targetScreen),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 14, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
          const SizedBox(height: 4),
          Icon(icon, color: color, size: 24),
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Nahata Sports Dashboard"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fees & Receipts
            Card(
              child: ListTile(
                leading: const Icon(Icons.sports_bar),
                title: const Text("Sports"),
                subtitle: const Text("View Sports"),
                onTap: () {
                  // Navigate to fees details
                },
              ),
            ),

            // Attendance
            Card(
              child: ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: const Text("Booked Court Response"),
                subtitle: const Text("Court Responses"),
                onTap: () {
                  // Navigate to attendance screen
                },
              ),
            ),

            // Coach Feedback
            Card(
              child: ListTile(
                leading: const Icon(Icons.feedback_outlined),
                title: const Text("Feedback"),
                subtitle: const Text("See feedback"),
                onTap: () {
                  // Navigate to feedback screen
                },
              ),
            ),

            // Book & Play — Upcoming Bookings
            Card(
              child: ListTile(
                leading: const Icon(Icons.sports_baseball),
                title: const Text("Book & Play"),
                subtitle: const Text("Reserve courts or sessions"),
                onTap: () {
                  Navigator.pushNamed(context, '/location');
                },
              ),
            ),


            Card(
              child: ListTile(
                leading: const Icon(Icons.people_alt_outlined),
                title: const Text("Students & Parents"),
                subtitle: const Text("View details"),
                onTap: () {
                  Navigator.pushNamed(context, '/students_parents');
                },
              ),
            ),
            const SizedBox(height: 20),
            // Upcoming Events & Announcements
            const Text(
              "Announcements & Events",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            // Example announcement items
            ...[
              "Free Training Camps",
              "Holiday Notices",
              "Upcoming Tournaments"
            ].map((item) =>
                Card(
                  child: ListTile(
                    title: Text(item),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      // Navigate to announcement detail
                    },
                  ),
                )),
          ],
        ),
      ),

      // bottomNavigationBar: BottomNavigationBar(
      //   items: const [
      //     BottomNavigationBarItem(icon: Icon(Icons.people,color: Colors.black,), label: "Students"),
      //     BottomNavigationBarItem(icon: Icon(Icons.perm_contact_cal,color: Colors.black,), label: "Coach"),
      //     BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings,color: Colors.black,), label: "Admin"),
      //     BottomNavigationBarItem(icon: Icon(Icons.security,color: Colors.black,), label: "Security"),
      //   ],
      //   onTap: (index) {
      //     // Handle bottom nav tap
      //   },
      // ),

      // bottomNavigationBar: BottomAppBar(
      //   color: Colors.white,
      //   elevation: 10,
      //   child: Row(
      //     mainAxisAlignment: MainAxisAlignment.spaceAround,
      //     children: [
      //       _buildNavItem(Icons.people, "Students", DashboardScreen(), 0),
      //       _buildNavItem(Icons.perm_contact_cal, "Coach", CoachDashboardScreen(), 1),
      //       _buildNavItem(Icons.admin_panel_settings, "Admin", AdminDashboardScreen(), 2),
      //       _buildNavItem(Icons.security, "Security", security_screen(), 3),
      //     ],
      //   ),
      // ),


    );
  }
  //
  // Widget _buildNavItem(IconData icon, String label, Widget targetScreen,
  //     BuildContext context) {
  //   return GestureDetector(
  //     onTap: () {
  //       Navigator.push(
  //         context,
  //         MaterialPageRoute(builder: (_) => targetScreen),
  //       );
  //     },
  //     child: Column(
  //       mainAxisSize: MainAxisSize.min,
  //       children: [
  //         Text(
  //             label, style: const TextStyle(color: Colors.black, fontSize: 14)),
  //         const SizedBox(height: 4),
  //         Icon(icon, color: Colors.black, size: 24),
  //       ],
  //     ),
  //   );
  // }

}
