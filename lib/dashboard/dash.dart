// import 'package:flutter/material.dart';
//
// class StudentDashboardScreen extends StatelessWidget {
//   const StudentDashboardScreen({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Student Dashboard'),
//         centerTitle: true,
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Student ID Card
//             Card(
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(16),
//               ),
//               elevation: 4,
//               child: Padding(
//                 padding: const EdgeInsets.all(16.0),
//                 child: Row(
//                   children: [
//                     const CircleAvatar(
//                       radius: 35,
//                       backgroundImage: AssetImage('assets/profile.png'), // replace with NetworkImage
//                     ),
//                     const SizedBox(width: 16),
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: const [
//                           Text("Harshada Shinde", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//                           SizedBox(height: 4),
//                           Text("ID: NS12345", style: TextStyle(color: Colors.grey)),
//                           SizedBox(height: 4),
//                           Text("Badminton", style: TextStyle(color: Colors.black87)),
//                           SizedBox(height: 4),
//                           Text("Valid till: Dec 2025", style: TextStyle(color: Colors.black54)),
//                         ],
//                       ),
//                     ),
//                     IconButton(
//                       onPressed: () {},
//                       icon: const Icon(Icons.download),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//             const SizedBox(height: 20),
//
//             // Quick Actions
//             const Text("Quick Actions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//             const SizedBox(height: 10),
//             GridView.count(
//               shrinkWrap: true,
//               physics: const NeverScrollableScrollPhysics(),
//               crossAxisCount: 2,
//               crossAxisSpacing: 12,
//               mainAxisSpacing: 12,
//               childAspectRatio: 1.2,
//               children: [
//                 _buildQuickAction(Icons.sports_tennis, "Book Court"),
//                 _buildQuickAction(Icons.calendar_month, "Check Availability"),
//                 _buildQuickAction(Icons.bookmark_added, "My Bookings"),
//                 _buildQuickAction(Icons.school, "Coaching"),
//               ],
//             ),
//             const SizedBox(height: 20),
//
//             // Progress & Fees
//             const Text("My Progress", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//             const SizedBox(height: 10),
//             Row(
//               children: [
//                 Expanded(
//                   child: Card(
//                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                     child: const Padding(
//                       padding: EdgeInsets.all(16.0),
//                       child: Column(
//                         children: [
//                           Text("Attendance", style: TextStyle(fontWeight: FontWeight.bold)),
//                           SizedBox(height: 8),
//                           Text("85%", style: TextStyle(fontSize: 20, color: Colors.deepPurple)),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),
//                 Expanded(
//                   child: Card(
//                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                     child: const Padding(
//                       padding: EdgeInsets.all(16.0),
//                       child: Column(
//                         children: [
//                           Text("Fees", style: TextStyle(fontWeight: FontWeight.bold)),
//                           SizedBox(height: 8),
//                           Text("Paid", style: TextStyle(fontSize: 20, color: Colors.green)),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//
//             const SizedBox(height: 20),
//
//             // Upcoming Events
//             const Text("Upcoming Events", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//             const SizedBox(height: 10),
//             Card(
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//               elevation: 2,
//               child: ListTile(
//                 leading: const Icon(Icons.emoji_events, color: Colors.deepPurple),
//                 title: const Text("Inter-School Badminton Tournament"),
//                 subtitle: const Text("12th Sep 2025"),
//                 trailing: ElevatedButton(
//                   onPressed: () {
//                     // Navigator.of(context).push(
//                     //   MaterialPageRoute<void>(
//                     //     builder: (context) => const EventsListPage(),
//                     //   ),
//                     // );
//                   },
//                   child: const Text("Register"),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//       bottomNavigationBar: NavigationBar(
//         destinations: const [
//           NavigationDestination(icon: Icon(Icons.home), label: "Home"),
//           NavigationDestination(icon: Icon(Icons.sports_tennis), label: "Book & Play"),
//           NavigationDestination(icon: Icon(Icons.event), label: "Events"),
//           NavigationDestination(icon: Icon(Icons.person), label: "Profile"),
//         ],
//         selectedIndex: 0,
//           onDestinationSelected: (index) {
//             switch (index) {
//               // case 0:
//               //   Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
//               //   break;
//               // case 1:
//               //   Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const BookPlayScreen()));
//               //   break;
//               // case 2:
//               //   Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const EventsScreen()));
//               //   break;
//               // case 3:
//               //   Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
//               //   break;
//             }
//           }
//
//       ),
//     );
//   }
//
//   Widget _buildQuickAction(IconData icon, String label) {
//     return Card(
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       elevation: 3,
//       child: InkWell(
//         borderRadius: BorderRadius.circular(12),
//         onTap: () {},
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(icon, size: 40, color: Colors.deepPurple),
//             const SizedBox(height: 8),
//             Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
//           ],
//         ),
//       ),
//     );
//   }
// }
