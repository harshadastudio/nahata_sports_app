// import 'package:flutter/material.dart';
// import 'package:nahata_app/dashboard/security_screen.dart';
//
// import 'admin_screen.dart';
// import 'coach_screen.dart';
// import 'dashboard_screen.dart';
//
// class DashboardScreen1 extends StatefulWidget {
//   const DashboardScreen1({super.key});
//
//   @override
//   State<DashboardScreen1> createState() => _DashboardScreen1State();
// }
//
// class _DashboardScreen1State extends State<DashboardScreen1> {
//   int _selectedIndex = 0;
//
//   // List of all screens for tabs
//   final List<Widget> _screens = [
//     BookPlayScreen(),
//    // DashboardScreen(),      // index 0
//     CoachDashboardScreen(),// index 1
//     AdminDashboardScreen(),// index 2
//     SecurityGateScannerScreen(),      // index 3
//   ];
//
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: _screens[_selectedIndex], // show screen based on selected index
//       bottomNavigationBar: BottomAppBar(
//         color: Colors.white,
//         elevation: 10,
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.spaceAround,
//           children: [
//             _buildNavItem(Icons.people, "Students", 0),
//             _buildNavItem(Icons.perm_contact_cal, "Coach", 1),
//             _buildNavItem(Icons.admin_panel_settings, "Admin", 2),
//             _buildNavItem(Icons.security, "Security", 3),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildNavItem(IconData icon, String label, int index) {
//     final isSelected = _selectedIndex == index;
//     final color = isSelected ? Colors.blue : Colors.grey;
//
//     return GestureDetector(
//       onTap: () {
//         setState(() {
//           _selectedIndex = index; // switch screen
//         });
//       },
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Text(
//             label,
//             style: TextStyle(
//               color: color,
//               fontSize: 14,
//               fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
//             ),
//           ),
//           const SizedBox(height: 4),
//           Icon(icon, color: color, size: 24),
//         ],
//       ),
//     );
//   }
// }
