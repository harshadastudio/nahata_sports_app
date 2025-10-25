// import 'package:flutter/material.dart';
// import '../services/location_service.dart';
// import 'slot_booking_screen.dart';
//
// class GameSelectionScreen extends StatelessWidget {
//   final String location;
//
//   const GameSelectionScreen({super.key, required this.location});
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFF2F4F7),
//       body: SafeArea(
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // 🔵 Custom Header
//             Padding(
//               padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     'Games at $location',
//                     style: const TextStyle(
//                       fontSize: 26,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.indigo,
//                     ),
//                   ),
//                   const SizedBox(height: 4),
//                   const Text(
//                     'Tap a game to view and book slots',
//                     style: TextStyle(fontSize: 15, color: Colors.black54),
//                   ),
//                 ],
//               ),
//             ),
//
//             // 🟡 FutureBuilder for Games
//             Expanded(
//               child: FutureBuilder<List<Sport>>(
//                 future: ApiService.fetchSportsByLocation(location),
//                 builder: (context, snapshot) {
//                   if (snapshot.connectionState == ConnectionState.waiting) {
//                     return const Center(child: CircularProgressIndicator());
//                   } else if (snapshot.hasError) {
//                     return Center(
//                       child: Padding(
//                         padding: const EdgeInsets.symmetric(horizontal: 20),
//                         child: Text(
//                           'Error: ${snapshot.error}',
//                           style: const TextStyle(fontSize: 16, color: Colors.red),
//                         ),
//                       ),
//                     );
//                   } else if (snapshot.hasData && snapshot.data!.isEmpty) {
//                     return const Center(
//                       child: Text('No games available',
//                           style: TextStyle(fontSize: 18)),
//                     );
//                   }
//
//                   final sports = snapshot.data!;
//                   return ListView.builder(
//                     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//                     itemCount: sports.length,
//                     itemBuilder: (context, index) {
//                       final sport = sports[index];
//                       return Card(
//                         elevation: 3,
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(16),
//                         ),
//                         margin: const EdgeInsets.only(bottom: 16),
//                         child: ListTile(
//                           contentPadding: const EdgeInsets.all(14),
//                           leading: ClipRRect(
//                             borderRadius: BorderRadius.circular(12),
//                             child: Image.network(
//                               sport.imageUrl,
//                               width: 60,
//                               height: 60,
//                               fit: BoxFit.cover,
//                               errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported),
//                             ),
//                           ),
//                           title: Text(
//                             sport.name,
//                             style: const TextStyle(
//                               fontSize: 18,
//                               fontWeight: FontWeight.w600,
//                             ),
//                           ),
//                           trailing: const Icon(
//                             Icons.arrow_forward_ios_rounded,
//                             size: 18,
//                             color: Colors.grey,
//                           ),
//                           onTap: () {
//                             Navigator.push(
//                               context,
//                               MaterialPageRoute(
//                                 builder: (context) => SlotBookingScreen(
//                                   location: location,
//                                   game: sport.name,
//                                 ),
//                               ),
//                             );
//                           },
//                         ),
//                       );
//                     },
//                   );
//                 },
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }