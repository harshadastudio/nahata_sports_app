// import 'dart:convert';
//
// import 'package:flutter/material.dart';
//
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
//
//
// class CoachScreen extends StatefulWidget {
//   @override
//   _CoachScreenState createState() => _CoachScreenState();
// }
//
// class _CoachScreenState extends State<CoachScreen>
//     with TickerProviderStateMixin {
//   late AnimationController _animationController;
//   late List<AnimationController> _cardControllers;
//   late List<Animation<double>> _cardAnimations;
//   late List<Animation<Offset>> _slideAnimations;
//
//   final List<SportCategory> sportsCategories = [
//     SportCategory(
//       name: 'Basket Ball',
//       color: Color(0xFF4FC3F7),
//       icon: '🏀',
//       description: 'Professional basketball coaching',
//       availableCoaches: 12,
//     ),
//     SportCategory(
//       name: 'Cricket',
//       color: Color(0xFFFFB74D),
//       icon: '🏏',
//       description: 'Expert cricket training',
//       availableCoaches: 15,
//     ),
//     SportCategory(
//       name: 'Badminton',
//       color: Color(0xFF9C27B0),
//       icon: '🏸',
//       description: 'Professional badminton coaching',
//       availableCoaches: 8,
//     ),
//     SportCategory(
//       name: 'Pickel Ball',
//       color: Color(0xFFEF5350),
//       icon: '🎾',
//       description: 'Fun pickleball sessions',
//       availableCoaches: 6,
//     ),
//     SportCategory(
//       name: 'Badminton',
//       color: Color(0xFFFF7043),
//       icon: '🏸',
//       description: 'Advanced badminton training',
//       availableCoaches: 10,
//     ),
//     SportCategory(
//       name: 'Dance & Zumba',
//       color: Color(0xFF26A69A),
//       icon: '💃',
//       description: 'Fun dance and fitness',
//       availableCoaches: 9,
//     ),
//   ];
//
//   @override
//   void initState() {
//     super.initState();
//
//     _animationController = AnimationController(
//       duration: Duration(milliseconds: 600),
//       vsync: this,
//     );
//
//     _cardControllers = List.generate(
//       sportsCategories.length,
//           (index) => AnimationController(
//         duration: Duration(milliseconds: 800),
//         vsync: this,
//       ),
//     );
//
//     _cardAnimations = _cardControllers.map((controller) {
//       return Tween<double>(
//         begin: 0.0,
//         end: 1.0,
//       ).animate(CurvedAnimation(
//         parent: controller,
//         curve: Curves.elasticOut,
//       ));
//     }).toList();
//
//     _slideAnimations = _cardControllers.map((controller) {
//       return Tween<Offset>(
//         begin: Offset(0.0, 0.5),
//         end: Offset.zero,
//       ).animate(CurvedAnimation(
//         parent: controller,
//         curve: Curves.easeOutCubic,
//       ));
//     }).toList();
//
//     // Staggered animation start
//     _animationController.forward();
//     for (int i = 0; i < _cardControllers.length; i++) {
//       Future.delayed(Duration(milliseconds: i * 150), () {
//         if (mounted) {
//           _cardControllers[i].forward();
//         }
//       });
//     }
//   }
//
//   @override
//   void dispose() {
//     _animationController.dispose();
//     for (var controller in _cardControllers) {
//       controller.dispose();
//     }
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.grey[50],
//       body: SafeArea(
//         child: Column(
//           children: [
//             _buildHeader(),
//             _buildSubTitle(),
//             Expanded(
//               child: _buildSportsGrid(),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildHeader() {
//     return FadeTransition(
//       opacity: _animationController,
//       child: Padding(
//         padding: EdgeInsets.all(16.0),
//         child: Row(
//           children: [
//             // Container(
//             //   decoration: BoxDecoration(
//             //     color: Colors.white,
//             //     borderRadius: BorderRadius.circular(12),
//             //     boxShadow: [
//             //       BoxShadow(
//             //         color: Colors.black.withOpacity(0.05),
//             //         blurRadius: 8,
//             //         offset: Offset(0, 2),
//             //       ),
//             //     ],
//             //   ),
//             //   child: IconButton(
//             //     icon: Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20),
//             //     onPressed: () {
//             //       Navigator.of(context).pop();
//             //     },
//             //   ),
//             // ),
//             Expanded(
//               child: Center(
//                 child: Text(
//                   'Coach',
//                   style: TextStyle(
//                     fontSize: 20,
//                     fontWeight: FontWeight.w600,
//                     color: Colors.black87,
//                   ),
//                 ),
//               ),
//             ),
//             // Container(
//             //   decoration: BoxDecoration(
//             //     color: Colors.white,
//             //     borderRadius: BorderRadius.circular(12),
//             //     boxShadow: [
//             //       BoxShadow(
//             //         color: Colors.black.withOpacity(0.05),
//             //         blurRadius: 8,
//             //         offset: Offset(0, 2),
//             //       ),
//             //     ],
//             //   ),
//             //   child: IconButton(
//             //     icon: Icon(Icons.search, color: Colors.black87, size: 20),
//             //     onPressed: () {
//             //       _showSearchDialog();
//             //     },
//             //   ),
//             // ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildSubTitle() {
//     return FadeTransition(
//       opacity: _animationController,
//       child: Padding(
//         padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
//         child: Align(
//           alignment: Alignment.centerLeft,
//           child: Text(
//             'Coach Available in Sinhagad Road',
//             style: TextStyle(
//               fontSize: 16,
//               color: Colors.grey[600],
//               fontWeight: FontWeight.w400,
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildSportsGrid() {
//     return Padding(
//       padding: EdgeInsets.symmetric(horizontal: 16.0),
//       child: GridView.builder(
//         physics: BouncingScrollPhysics(),
//         gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//           crossAxisCount: 2,
//           crossAxisSpacing: 16,
//           mainAxisSpacing: 16,
//           childAspectRatio: 1.0,
//         ),
//         itemCount: sportsCategories.length,
//         itemBuilder: (context, index) {
//           return _buildSportCard(sportsCategories[index], index);
//         },
//       ),
//     );
//   }
//
//   Widget _buildSportCard(SportCategory sport, int index) {
//     return AnimatedBuilder(
//       animation: _cardAnimations[index],
//       builder: (context, child) {
//         return SlideTransition(
//           position: _slideAnimations[index],
//           child: ScaleTransition(
//             scale: _cardAnimations[index],
//             child: GestureDetector(
//               onTap: () => _onSportCardTap(sport),
//               child: Container(
//                 decoration: BoxDecoration(
//                   color: sport.color,
//                   borderRadius: BorderRadius.circular(16),
//                   boxShadow: [
//                     BoxShadow(
//                       color: sport.color.withOpacity(0.3),
//                       blurRadius: 12,
//                       offset: Offset(0, 6),
//                     ),
//                   ],
//                 ),
//                 child: Stack(
//                   children: [
//                     // Background pattern
//                     Positioned(
//                       right: -20,
//                       top: -20,
//                       child: Container(
//                         width: 80,
//                         height: 80,
//                         decoration: BoxDecoration(
//                           color: Colors.white.withOpacity(0.1),
//                           shape: BoxShape.circle,
//                         ),
//                       ),
//                     ),
//                     Positioned(
//                       right: -10,
//                       bottom: -10,
//                       child: Container(
//                         width: 60,
//                         height: 60,
//                         decoration: BoxDecoration(
//                           color: Colors.white.withOpacity(0.1),
//                           shape: BoxShape.circle,
//                         ),
//                       ),
//                     ),
//
//                     // Content
//                     Padding(
//                       padding: EdgeInsets.all(20),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           // Sport icon/emoji
//                           Container(
//                             width: 50,
//                             height: 50,
//                             decoration: BoxDecoration(
//                               color: Colors.white.withOpacity(0.2),
//                               borderRadius: BorderRadius.circular(12),
//                             ),
//                             child: Center(
//                               child: Text(
//                                 sport.icon,
//                                 style: TextStyle(fontSize: 28),
//                               ),
//                             ),
//                           ),
//
//                           Spacer(),
//
//                           // Sport name
//                           Text(
//                             sport.name,
//                             style: TextStyle(
//                               color: Colors.white,
//                               fontSize: 18,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//
//                           SizedBox(height: 4),
//
//                           // Available coaches count
//                           Text(
//                             '${sport.availableCoaches} coaches',
//                             style: TextStyle(
//                               color: Colors.white.withOpacity(0.9),
//                               fontSize: 12,
//                               fontWeight: FontWeight.w500,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//
//                     // Favorite button
//                     Positioned(
//                       top: 16,
//                       right: 16,
//                       child: Container(
//                         width: 32,
//                         height: 32,
//                         decoration: BoxDecoration(
//                           color: Colors.white.withOpacity(0.2),
//                           borderRadius: BorderRadius.circular(8),
//                         ),
//                         child: Icon(
//                           Icons.favorite_border,
//                           color: Colors.white,
//                           size: 18,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         );
//       },
//     );
//   }
//
//   void _onSportCardTap(SportCategory sport) {
//     showModalBottomSheet(
//       context: context,
//       backgroundColor: Colors.transparent,
//       isScrollControlled: true,
//       builder: (context) => DraggableScrollableSheet(
//         initialChildSize: 0.6,
//         maxChildSize: 0.8,
//         minChildSize: 0.4,
//         builder: (context, scrollController) => Container(
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//           ),
//           child: Column(
//             children: [
//               // Handle bar
//               Container(
//                 width: 40,
//                 height: 4,
//                 margin: EdgeInsets.symmetric(vertical: 12),
//                 decoration: BoxDecoration(
//                   color: Colors.grey[300],
//                   borderRadius: BorderRadius.circular(2),
//                 ),
//               ),
//
//               // Header
//               Padding(
//                 padding: EdgeInsets.all(20),
//                 child: Row(
//                   children: [
//                     Container(
//                       width: 60,
//                       height: 60,
//                       decoration: BoxDecoration(
//                         color: sport.color.withOpacity(0.1),
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                       child: Center(
//                         child: Text(
//                           sport.icon,
//                           style: TextStyle(fontSize: 30),
//                         ),
//                       ),
//                     ),
//                     SizedBox(width: 16),
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             sport.name,
//                             style: TextStyle(
//                               fontSize: 24,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                           Text(
//                             sport.description,
//                             style: TextStyle(
//                               color: Colors.grey[600],
//                               fontSize: 14,
//                             ),
//                           ),
//                           SizedBox(height: 4),
//                           Text(
//                             '${sport.availableCoaches} coaches available',
//                             style: TextStyle(
//                               color: sport.color,
//                               fontSize: 12,
//                               fontWeight: FontWeight.w600,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//
//               // Coach list placeholder
//               Expanded(
//                 child: ListView.builder(
//                   controller: scrollController,
//                   padding: EdgeInsets.symmetric(horizontal: 20),
//                   itemCount: sport.availableCoaches > 5 ? 5 : sport.availableCoaches,
//                   itemBuilder: (context, index) {
//                     return Container(
//                       margin: EdgeInsets.only(bottom: 12),
//                       padding: EdgeInsets.all(16),
//                       decoration: BoxDecoration(
//                         color: Colors.grey[50],
//                         borderRadius: BorderRadius.circular(12),
//                         border: Border.all(color: Colors.grey[200]!),
//                       ),
//                       child: Row(
//                         children: [
//                           CircleAvatar(
//                             radius: 25,
//                             backgroundColor: sport.color.withOpacity(0.2),
//                             child: Icon(
//                               Icons.person,
//                               color: sport.color,
//                             ),
//                           ),
//                           SizedBox(width: 12),
//                           Expanded(
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Text(
//                                   'Coach ${index + 1}',
//                                   style: TextStyle(
//                                     fontWeight: FontWeight.w600,
//                                     fontSize: 16,
//                                   ),
//                                 ),
//                                 Text(
//                                   '${sport.name} Expert • 5+ years exp',
//                                   style: TextStyle(
//                                     color: Colors.grey[600],
//                                     fontSize: 12,
//                                   ),
//                                 ),
//                                 Row(
//                                   children: [
//                                     Icon(Icons.star, color: Colors.amber, size: 14),
//                                     SizedBox(width: 4),
//                                     Text(
//                                       '4.${8 + index}',
//                                       style: TextStyle(fontSize: 12),
//                                     ),
//                                     SizedBox(width: 12),
//                                     Text(
//                                       '₹${500 + (index * 100)}/hr',
//                                       style: TextStyle(
//                                         color: sport.color,
//                                         fontWeight: FontWeight.w600,
//                                         fontSize: 12,
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               ],
//                             ),
//                           ),
//                           Container(
//                             padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                             decoration: BoxDecoration(
//                               color: sport.color,
//                               borderRadius: BorderRadius.circular(16),
//                             ),
//                             child: Text(
//                               'Book',
//                               style: TextStyle(
//                                 color: Colors.white,
//                                 fontSize: 12,
//                                 fontWeight: FontWeight.w600,
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     );
//                   },
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   void _showSearchDialog() {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(16),
//           ),
//           title: Text('Search Coaches'),
//           content: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               TextField(
//                 decoration: InputDecoration(
//                   hintText: 'Search by sport or coach name...',
//                   prefixIcon: Icon(Icons.search),
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                 ),
//               ),
//               SizedBox(height: 16),
//               Text(
//                 'Popular searches: Basketball, Cricket, Badminton',
//                 style: TextStyle(
//                   color: Colors.grey[600],
//                   fontSize: 12,
//                 ),
//               ),
//             ],
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.of(context).pop(),
//               child: Text('Cancel'),
//             ),
//             ElevatedButton(
//               onPressed: () {
//                 Navigator.of(context).pop();
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   SnackBar(content: Text('Search functionality coming soon!')),
//                 );
//               },
//               child: Text('Search'),
//             ),
//           ],
//         );
//       },
//     );
//   }
// }
//
// class SportCategory {
//   final String name;
//   final Color color;
//   final String icon;
//   final String description;
//   final int availableCoaches;
//
//   SportCategory({
//     required this.name,
//     required this.color,
//     required this.icon,
//     required this.description,
//     required this.availableCoaches,
//   });
// }
//
// class Coach {
//   final String id;
//   final String name;
//   final String sport;
//   final String image;
//   final String price;
//   final String availability;
//   final String ground;  // Add this field
//
//   Coach({
//     required this.id,
//     required this.name,
//     required this.sport,
//     required this.image,
//     required this.price,
//     required this.availability,
//     required this.ground,
//   });
//
//   factory Coach.fromJson(Map<String, dynamic> json) {
//     return Coach(
//       id: json['id'] ?? '',
//       name: json['sport_name'] ?? 'Unknown Coach',
//       sport: json['sport_name'] ?? 'Unknown Sport',
//       image: json['image'] ?? '',
//       price: json['price'],  // Use default price if not provided
//       availability: 'Available',  // Default availability
//       ground: json['ground'] ?? 'Unknown Ground',
//     );
//   }
// }
//
// class CoachApp extends StatefulWidget {
//   @override
//   _CoachAppState createState() => _CoachAppState();
// }
//
// class _CoachAppState extends State<CoachApp> {
//   late Future<List<Coach>> futureCoaches;
//
//   @override
//   void initState() {
//     super.initState();
//     futureCoaches = fetchCoaches();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('Select Location')),
//       body: FutureBuilder<List<Coach>>(
//         future: futureCoaches,
//         builder: (context, snapshot) {
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return Center(child: CircularProgressIndicator());
//           } else if (snapshot.hasError) {
//             return Center(child: Text('Error: ${snapshot.error}'));
//           } else if (snapshot.hasData) {
//             return Center(
//               child: ElevatedButton(
//                 child: Text('View Coaches in Sinhgad Road'),
//                 onPressed: () {
//                   Navigator.push(context, MaterialPageRoute(
//                     builder: (_) => SportsScreen(
//                       coaches: snapshot.data!,
//                       location: 'Sinhgad Rd',
//                     ),
//                   ));
//                 },
//               ),
//             );
//           } else {
//             return Center(child: Text('No data available'));
//           }
//         },
//       ),
//     );
//   }
// }
//
// Future<List<Coach>> fetchCoaches() async {
//   final response = await http.get(Uri.parse('https://nahatasports.com/api/coach'));
//
//   print('Status Code: ${response.statusCode}');
//   print('Response Body: ${response.body}');
//
//   if (response.statusCode == 200) {
//     List jsonList = json.decode(response.body)['coaches'];
//     return jsonList.map((e) => Coach.fromJson(e)).toList();
//   } else {
//     throw Exception('Failed to load coaches');
//   }
// }
//
//
//
// class SportsScreen extends StatelessWidget {
//   final List<Coach> coaches;
//   final String location;
//
//   SportsScreen({required this.coaches, required this.location});
//
//   @override
//   Widget build(BuildContext context) {
//     final sports = coaches
//         .where((c) => c.ground == location)
//         .map((c) => c.sport)
//         .toSet()
//         .toList();
//
//     return Scaffold(
//       appBar: AppBar(title: Text('Sports in $location')),
//       body: ListView.builder(
//         itemCount: sports.length,
//         itemBuilder: (context, index) {
//           final sport = sports[index];
//           return ListTile(
//             title: Text(sport),
//             onTap: () {
//               Navigator.push(context, MaterialPageRoute(
//                 builder: (_) => CoachesListScreen(
//                   coaches: coaches,
//                   location: location,
//                   sport: sport,
//                 ),
//               ));
//             },
//           );
//         },
//       ),
//     );
//   }
// }
// class CoachDetailScreen extends StatelessWidget {
//   final Coach coach;
//
//   CoachDetailScreen({required this.coach});
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text(coach.name)),
//       body: Padding(
//         padding: EdgeInsets.all(16),
//         child: Column(
//           children: [
//             coach.image.isNotEmpty
//                 ? Image.network('https://nahatasports.com/uploads/coach/${coach.image}')
//                 : SizedBox.shrink(),
//             SizedBox(height: 10),
//             Text('Sport: ${coach.sport}', style: TextStyle(fontSize: 18)),
//             Text('Price: ₹${coach.price}', style: TextStyle(fontSize: 18)),
//             Text('Availability: ${coach.availability}', style: TextStyle(fontSize: 16)),
//             SizedBox(height: 20),
//             ElevatedButton(
//               onPressed: () {
//                 // Navigate to Inquiry Page
//                 Navigator.push(context, MaterialPageRoute(
//                   builder: (_) => InquiryScreen(coach: coach),
//                 ));
//               },
//               child: Text('Inquiry'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
// class InquiryScreen extends StatelessWidget {
//   final Coach coach;
//
//   InquiryScreen({required this.coach});
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('Inquiry')),
//       body: Padding(
//         padding: EdgeInsets.all(16),
//         child: Column(
//           children: [
//             Text('Send inquiry for ${coach.name}', style: TextStyle(fontSize: 18)),
//             SizedBox(height: 20),
//             TextField(
//               decoration: InputDecoration(
//                 labelText: 'Your Name',
//                 border: OutlineInputBorder(),
//               ),
//             ),
//             SizedBox(height: 12),
//             TextField(
//               decoration: InputDecoration(
//                 labelText: 'Message',
//                 border: OutlineInputBorder(),
//               ),
//               maxLines: 4,
//             ),
//             SizedBox(height: 20),
//             ElevatedButton(
//               onPressed: () {
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   SnackBar(content: Text('Inquiry sent successfully!')),
//                 );
//                 Navigator.pop(context);
//               },
//               child: Text('Submit Inquiry'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
// class CoachesListScreen extends StatelessWidget {
//   final List<Coach> coaches;
//   final String location;
//   final String sport;
//
//   CoachesListScreen({
//     required this.coaches,
//     required this.location,
//     required this.sport,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final filteredCoaches = coaches
//         .where((c) => c.ground == location && c.sport == sport)
//         .toList();
//
//     return Scaffold(
//       appBar: AppBar(title: Text('$sport Coaches in $location')),
//       body: ListView.builder(
//         itemCount: filteredCoaches.length,
//         itemBuilder: (context, index) {
//           final coach = filteredCoaches[index];
//           return ListTile(
//             leading: coach.image.isNotEmpty
//                 ? Image.network('https://nahatasports.com/api/coach/${coach.image}')
//                 : null,
//             title: Text(coach.name),
//             subtitle: Text('₹${coach.price} • ${coach.availability}'),
//             onTap: () {
//               Navigator.push(context, MaterialPageRoute(
//                 builder: (_) => CoachDetailScreen(coach: coach),
//               ));
//             },
//           );
//         },
//       ),
//     );
//   }
// }

// Networking for this screen goes through the centralised API layer
// (CoachingRepository), so no direct http / json / prefs usage remains here.
import 'package:flutter/material.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:nahata_app/auth/login.dart';
import '../core/network/api_exception.dart';
import '../core/services/selected_ground.dart';
import '../core/widgets/app_shimmer.dart';
import '../core/widgets/media_image.dart';
import '../models/batch_model.dart';
import '../repositories/auth_repository.dart';
import '../repositories/coaching_repository.dart';
import 'coaching_enquiry_form.dart';
// class Sport {
//   final String id;
//   final String sportName;
//   final String ground;
//   final String image;
//
//   Sport({
//     required this.id,
//     required this.sportName,
//     required this.ground,
//     required this.image,
//   });
//
//
//   String buildImageUrl(String filename) {
//     if (filename.isEmpty) return "https://via.placeholder.com/150";
//     return "https://nahatasports.com/storage/$filename";
//     // if still 404, try /public/upload/, /images/, etc
//   }
//   factory Sport.fromJson(Map<String, dynamic> json) {
//     final String rawImage = json['image'] ?? '';
//     return Sport(
//       id: json['id'] ?? '',
//       sportName: json['sport_name'] ?? '',
//       ground: json['ground'] ?? '',
//       image: buildImageUrl(rawImage),
//     );
//   }
//
//
//
// // factory Sport.fromJson(Map<String, dynamic> json) {
//   //   return Sport(
//   //     id: json['id'] ?? '',
//   //     sportName: json['sport_name'] ?? '',
//   //     ground: json['ground'] ?? '',
//   //     image: "https://nahatasports.com/upload/${json['image'] ?? ''}", // adjust path if needed
//   //   );
//   // }
// }

//
// class CoachApiService {
//   static const String baseUrl = "https://nahatasports.com/api/coach";
//
//   static Future<List<Sport>> fetchSports() async {
//     final response = await http.get(Uri.parse(baseUrl));
//
//     if (response.statusCode == 200) {
//       final data = json.decode(response.body);
//       if (data['success'] == true && data['sports'] != null) {
//         List sportsList = data['sports'];
//         return sportsList.map((s) => Sport.fromJson(s)).toList();
//       } else {
//         throw Exception("No sports data found");
//       }
//     } else {
//       throw Exception("Failed to load sports");
//     }
//   }
// }

//
//
//
//
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
//
// void main() {
//   runApp(const MyApp());
// }
//
// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Nahata Sports',
//       theme: ThemeData(
//         primarySwatch: Colors.indigo,
//         fontFamily: 'Roboto',
//       ),
//       home: const SportsScreen(),
//       debugShowCheckedModeBanner: false,
//     );
//   }
// }

// Models
// class Sport {
//   final String id;
//   final String sportName;
//   final String ground;
//   final String image;
//
//   Sport({
//     required this.id,
//     required this.sportName,
//     required this.ground,
//     required this.image,
//   });
//
//   static String buildImageUrl(String filename) {
//     if (filename.isEmpty) return "https://via.placeholder.com/150";
//     return "https://nahatasports.com/storage/$filename";
//   }
//
//   factory Sport.fromJson(Map<String, dynamic> json) {
//     final String rawImage = json['image'] ?? '';
//     return Sport(
//       id: json['id']?.toString() ?? '',
//       sportName: json['sport_name'] ?? '',
//       ground: json['ground'] ?? '',
//       image: Sport.buildImageUrl(rawImage),
//     );
//   }
// }
class Coach {
  final String id;
  final String sportId;
  final String name;
  final String sport;
  final String ground;
  final String image;
  final String availability;
  final String price;
  final String coachBio;
  final String days;
  final String ageGroup;
  final List<String> achievements;
  final String developmentPath;
  final String startTime;
  final String endTime;

  /// From the coach's own record, e.g. "ALL India Basketball Cert".
  final String certification;

  /// The coach's own weekly availability, e.g. "Monday,Tuesday,Sunday" —
  /// distinct from [availability], which is the tapped batch's schedule.
  final String weeklyAvailability;

  Coach? coach;

  Coach({
    required this.id,
    required this.sportId,
    required this.name,
    required this.sport,
    required this.ground,
    required this.image,
    required this.availability,
    required this.price,
    required this.coachBio,
    required this.days,
    required this.ageGroup,
    required this.achievements,
    required this.developmentPath,
    required this.startTime,
    required this.endTime,
    this.certification = '',
    this.weeklyAvailability = '',
  });

  factory Coach.fromJson(Map<String, dynamic> json) {
    // Example: if API returns a list of batches, pick the first batch for display
    String startTime = '';
    String endTime = '';

    if (json['batches'] != null && (json['batches'] as List).isNotEmpty) {
      final batch = json['batches'][0];
      startTime = batch['start_time'] ?? '';
      endTime = batch['end_time'] ?? '';
    }
    // Parse image safely
    String imageUrl = '';
    if (json['image'] != null && json['image'].toString().isNotEmpty) {
      imageUrl = "https://nahatasports.com/upload/${json['image']}";
    }

    // Parse achievements from HTML or empty list
    List<String> parsedAchievements = [];
    if (json['coachbio'] != null) {
      final bio = json['coachbio'] as String;
      final regex = RegExp(r'✅\s*(.*?)<br>', multiLine: true);
      parsedAchievements = regex
          .allMatches(bio)
          .map((m) => m.group(1) ?? '')
          .toList();
    }

    return Coach(
      id: json['id']?.toString() ?? '',
      sportId: json['sport_id']?.toString() ?? '',
      name: json['name'] ?? json['coach_name'] ?? '',
      sport: json['sport'] ?? json['sport_name'] ?? '',
      ground: json['ground'] ?? '-',
      image: imageUrl,
      availability: json['availability'] ?? '-',
      price: json['price'] ?? '0',
      coachBio: json['coachbio'] ?? '',
      days: json['days'] ?? '-',
      ageGroup: json['age_group'] ?? '-',
      achievements: parsedAchievements,
      developmentPath: '', // Can parse from coachbio if needed
      startTime: startTime,
      endTime: endTime,
    );
  }
}

class Sport {
  final String id;
  final String sportName;
  final String ground;
  final String image;
  List<Coach> coaches = [];
  List<Batch> batches = [];
  Sport({
    required this.id,
    required this.sportName,
    required this.ground,
    required this.image,
  });

  factory Sport.fromJson(Map<String, dynamic> json) {
    return Sport(
      id: json['id'] ?? '',
      sportName: json['sport_name'] ?? '',
      ground: json['ground'] ?? '',
      image: json['image'] != null
          ? "https://nahatasports.com/uploads/sports/${json['image']}"
          : "",
    );
  }
}

class Batch {
  final String id;
  final String sportId;
  final String coachId;
  final String name;
  final String month;
  final String ageGroup;
  final String days;
  final String startTime;
  final String endTime;
  final String price;

  /// Shown in the enquiry form's "Program Details" panel. Carried on the view
  /// model because the enquiry is raised from the coach page, which has the
  /// batch but not the [BatchModel] it came from.
  final String duration;
  final String status;
  final int? availableSpots;

  Batch({
    required this.id,
    required this.sportId,
    required this.coachId,
    required this.name,
    required this.month,
    required this.ageGroup,
    required this.days,
    required this.startTime,
    required this.endTime,
    required this.price,
    this.duration = '',
    this.status = '',
    this.availableSpots,
  });

  /// Session window as one line, e.g. `"7:00 AM to 8:00 AM"`. Empty when the
  /// batch has no times, so the row can be dropped rather than shown as "to".
  String get timingLabel {
    if (startTime.isEmpty && endTime.isEmpty) return '';
    if (endTime.isEmpty) return startTime;
    if (startTime.isEmpty) return endTime;
    return '$startTime to $endTime';
  }

  factory Batch.fromJson(Map<String, dynamic> json) {
    final max = int.tryParse(json['max_students']?.toString() ?? '');
    final current = int.tryParse(json['current_students']?.toString() ?? '');

    return Batch(
      id: json['id']?.toString() ?? '',
      sportId: json['sport_id']?.toString() ?? '',
      coachId: json['coach_id']?.toString() ?? '',
      name: json['name'] ?? '',
      month: json['month'] ?? '',
      ageGroup: json['age_group'] ?? '',
      days: json['days'] ?? '',
      startTime: json['start_time'] ?? '',
      endTime: json['end_time'] ?? '',
      price: json['price'] ?? '',
      duration: json['duration']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      availableSpots: max == null
          ? null
          : ((max - (current ?? 0)) < 0 ? 0 : max - (current ?? 0)),
    );
  }
}

/// The sport photo behind a grid tile.
///
/// Two jobs beyond drawing the image: it fades in so the tile does not flash,
/// and it lays a dark scrim over the picture. Without the scrim the white
/// sport name is unreadable on a light photo — which is the reason the tile
/// used to draw a flat colour instead of the picture.
class _SportPhoto extends StatelessWidget {
  const _SportPhoto({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          url,
          fit: BoxFit.cover,
          // A broken or missing image leaves the gradient underneath showing,
          // which is the pre-existing look rather than a grey error box.
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded) return child;
            return AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              child: child,
            );
          },
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.15),
                Colors.black.withOpacity(0.55),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Adapter between the coaching API and the view models this screen already
/// uses ([Sport], [Batch], [Coach]).
///
/// The method names and return types are unchanged, so `SportsScreen`,
/// `BatchScreen` and `CoachDetailsScreen` keep working exactly as before —
/// only the data source moved to `api.nahatasports.com/api/batches`.
class CoachApiService {
  static final CoachingRepository _repository = CoachingRepository.instance;

  /// Active sports, optionally limited to one ground/venue.
  ///
  /// An empty result is a legitimate answer ("this venue offers no sports"),
  /// so it is returned as an empty list. Only a genuine failure throws.
  static Future<List<Sport>> fetchSports({String? ground}) async {
    try {
      final sports = await _repository.fetchSports(ground: ground);
      return sports.map(_toSport).toList(growable: false);
    } on ApiException catch (e) {
      debugPrint("Error fetching sports: ${e.message}");
      throw Exception(e.message);
    }
  }

  /// Every active batch for a sport, optionally narrowed to one ground.
  static Future<List<Batch>> fetchBatches(
    String sportId, {
    String? ground,
  }) async {
    final id = int.tryParse(sportId);
    if (id == null) return const [];

    try {
      final batches = await _repository.fetchBatchesBySport(id, ground: ground);
      return batches
          .where((b) => b.isActive)
          .map(_toBatch)
          .toList(growable: false);
    } on ApiException catch (e) {
      debugPrint("Error fetching batches: ${e.message}");
      return const [];
    }
  }

  /// Coaches teaching a sport, de-duplicated by coach id.
  ///
  /// Prefer [fetchCoachesByBatch] when you need the coach *for a specific
  /// batch*: a coach usually runs several batches at different times and
  /// prices, and this list can only carry one of them.
  static Future<List<Coach>> fetchCoaches(
    String sportId, {
    String? ground,
  }) async {
    final byBatch = await fetchCoachesByBatch(sportId, ground: ground);

    final byCoachId = <String, Coach>{};
    for (final coach in byBatch.values) {
      if (coach.id.isEmpty) continue;
      byCoachId.putIfAbsent(coach.id, () => coach);
    }
    return byCoachId.values.toList(growable: false);
  }

  /// Coach for each batch, keyed by **batch id**.
  ///
  /// A coach's batch-dependent fields (timing, price, days, age group) only
  /// make sense relative to one batch, so the details screen must look the
  /// coach up by the batch the user tapped — not by coach id.
  static Future<Map<String, Coach>> fetchCoachesByBatch(
    String sportId, {
    String? ground,
  }) async {
    final id = int.tryParse(sportId);
    if (id == null) return const {};

    try {
      // Two calls in parallel: the batches carry the schedule and price, the
      // coach records carry the photo and biography. Neither payload has both,
      // which is why the details screen used to render an empty description
      // under a placeholder avatar.
      //
      // Shares one round trip with fetchBatches — the repository de-duplicates
      // concurrent requests for the same sport+ground.
      final results = await Future.wait([
        _repository.fetchBatchesBySport(id, ground: ground),
        _repository.fetchCoachProfiles(id),
      ]);

      final batches = results[0] as List<BatchModel>;
      final profiles = results[1] as List<CoachProfile>;

      final profileById = <String, CoachProfile>{
        for (final profile in profiles)
          if (profile.id != null) profile.id.toString(): profile,
      };

      final byBatchId = <String, Coach>{};
      for (final batch in batches) {
        final batchId = batch.id?.toString();
        if (batchId == null || batchId.isEmpty) continue;

        final coachId =
            batch.coach?.id?.toString() ?? batch.coachId?.toString();
        if (coachId == null || coachId.isEmpty) continue;

        byBatchId[batchId] = _toCoach(batch, profileById[coachId]);
      }
      return byBatchId;
    } on ApiException catch (e) {
      debugPrint("Error fetching coaches: ${e.message}");
      return const {};
    }
  }

  /// Distinct grounds offering a sport.
  static Future<List<String>> fetchGrounds(String sportId) async {
    final id = int.tryParse(sportId);
    if (id == null) return const [];
    try {
      return await _repository.fetchGroundsForSport(id);
    } on ApiException catch (e) {
      debugPrint("Error fetching grounds: ${e.message}");
      return const [];
    }
  }

  /// Every venue the user can filter by, for the venue picker.
  static Future<List<String>> fetchVenues() async {
    try {
      return await _repository.fetchGrounds();
    } on ApiException catch (e) {
      debugPrint("Error fetching venues: ${e.message}");
      return const [];
    }
  }

  // ---------------------------------------------------------------------------
  // Mappers
  // ---------------------------------------------------------------------------

  /// Bullet points the CMS writes into the biography as `✅ ... <br>`.
  /// Returns empty for a plain-prose bio, which simply renders no bullets.
  static List<String> _achievementsFrom(String bio) {
    if (bio.isEmpty) return const <String>[];
    // The tick has to be the literal character: in a raw string `\u2705`
    // stays six characters and matches nothing.
    final regex = RegExp(r'✅\s*(.*?)<br>', multiLine: true);
    return regex
        .allMatches(bio)
        .map((m) => (m.group(1) ?? '').trim())
        .where((a) => a.isNotEmpty)
        .toList(growable: false);
  }

  static Sport _toSport(SportRef sport) => Sport(
    id: sport.id?.toString() ?? '',
    sportName: sport.displayName,
    // The grid's subtitle. Shows the venue when the list is filtered to
    // one ground, otherwise the sport's category ("Indoor"/"Outdoor").
    ground: (sport.ground?.trim().isNotEmpty ?? false)
        ? sport.ground!.trim()
        : (sport.category ?? ''),
    // `/sports` returns a full URL today, but other routes send a bare
    // filename; resolving here means either shape renders.
    image: resolveMediaUrl(sport.image) ?? '',
  );

  static Batch _toBatch(BatchModel batch) => Batch(
    id: batch.id?.toString() ?? '',
    sportId: batch.sportId?.toString() ?? '',
    coachId: batch.coach?.id?.toString() ?? batch.coachId?.toString() ?? '',
    name: batch.displayName,
    month: batch.startMonthLabel,
    ageGroup: batch.ageGroup ?? '',
    days: batch.daysLabel,
    startTime: batch.sessionStart,
    endTime: batch.sessionEnd,
    price: batch.feesLabel,
    duration: batch.duration ?? '',
    status: batch.status ?? '',
    // Null when the batch has no cap, which reads as "unlimited" rather
    // than as "0 spots left".
    availableSpots: batch.maxStudents == null ? null : batch.availableSlots,
  );

  /// Builds the screen's coach from the batch it teaches, enriched with the
  /// coach's own record when `/coaches/sport/{id}` returned one.
  ///
  /// The batch supplies everything schedule-shaped (timing, price, days, age
  /// group); [profile] supplies the photo, the biography and the credential
  /// line. A missing profile degrades to what the batch alone knows rather
  /// than failing — the same behaviour as before, but now it is the fallback
  /// instead of the only path.
  static Coach _toCoach(BatchModel batch, [CoachProfile? profile]) {
    final coach = batch.coach;
    final bio = profile?.bio ?? '';

    return Coach(
      id: coach?.id?.toString() ?? batch.coachId?.toString() ?? '',
      sportId: batch.sportId?.toString() ?? '',
      name: coach?.displayName ?? profile?.name ?? '',
      sport: batch.sport?.displayName ?? '',
      ground: coach?.ground ?? profile?.ground ?? '',
      image: profile?.image ?? '',
      availability: batch.schedule ?? '',
      price: batch.feesLabel,
      coachBio: bio,
      days: batch.daysLabel,
      ageGroup: batch.ageGroup ?? '',
      achievements: _achievementsFrom(bio),
      // Doubles as the credential line under the coach's name.
      developmentPath: profile?.credentials ?? '',
      startTime: batch.sessionStart,
      endTime: batch.sessionEnd,
      certification: profile?.certification ?? '',
      weeklyAvailability: profile?.availability ?? '',
    );
  }
}

// API Service
// class CoachApiService {
//   static const String baseUrl = "https://nahatasports.com/api/coach";
//
//   static Future<List<Sport>> fetchSports() async {
//     try {
//       final response = await http.get(Uri.parse(baseUrl));
//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
//         if (data['success'] == true && data['sports'] != null) {
//           return (data['sports'] as List)
//               .map((s) => Sport.fromJson(s))
//               .toList();
//         }
//       }
//       throw Exception("Failed to load sports");
//     } catch (e) {
//       print("Error fetching sports: $e");
//       throw Exception("Failed to load sports");
//     }
//   }
//
//   static Future<List<Coach>> fetchCoaches(String sportId) async {
//     try {
//       final response = await http.get(Uri.parse(baseUrl));
//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
//         if (data['success'] == true && data['coaches'] != null) {
//           return (data['coaches'] as List)
//               .where((c) => c['sport_id'].toString() == sportId)
//               .map((c) => Coach.fromJson(c))
//               .toList();
//         }
//       }
//       return [];
//     } catch (e) {
//       print("Error fetching coaches: $e");
//       return [];
//     }
//   }
//
//   static Future<List<Batch>> fetchBatches(String sportId) async {
//     try {
//       final response = await http.get(Uri.parse(baseUrl));
//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
//         if (data['success'] == true && data['batches'] != null) {
//           return (data['batches'] as List)
//               .where((b) => b['sport_id'].toString() == sportId)
//               .map((b) => Batch.fromJson(b))
//               .toList();
//         }
//       }
//       return [];
//     } catch (e) {
//       print("Error fetching batches: $e");
//       return [];
//     }
//   }
// }
//8888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888
// Sports Screen
class SportsScreen extends StatefulWidget {
  /// Venue to show sports for. When null the screen uses the ground the user
  /// last opened ([SelectedGround]); if that is unset too, every ground is
  /// listed.
  final String? ground;

  const SportsScreen({super.key, this.ground});

  @override
  State<SportsScreen> createState() => _SportsScreenState();
}

/// Type metrics for a sports grid tile.
///
/// Shared by the tile and by the delegate that sizes it — if they drifted
/// apart the height would stop matching the text again, which is the bug this
/// pair exists to prevent.
const double _sportTileNameSize = 16;
const double _sportTileGroundSize = 12;
const double _sportTileLineHeight = 1.25;

/// "Multipurpose AC Studio" needs three lines in a half-width tile; nothing in
/// the catalogue needs more.
const int _sportTileNameMaxLines = 3;

/// Geometry for the sports grid, worked out once per build from the names the
/// API actually returned. See [_SportsScreenState._sportsGridMetrics].
class _SportsGridMetrics {
  const _SportsGridMetrics({required this.delegate, required this.nameSize});

  final SliverGridDelegate delegate;

  /// Logical font size for the sport name before the user's text scale is
  /// applied — reduced from [_sportTileNameSize] only when a name genuinely
  /// cannot fit the device at full size.
  final double nameSize;
}

class _SportsScreenState extends State<SportsScreen> {
  late Future<List<Sport>> futureSports;

  /// The venue list, fetched once and shared by the picker and the ground
  /// fallback below — both need it on first load, and neither should pay for
  /// its own round trip.
  Future<List<String>>? _venuesFuture;

  /// Ground actually used for the current request — passed on to BatchScreen
  /// so the batch list stays scoped to the same venue.
  String? _ground;
  bool _groundResolved = false;

  List<String> _venues = const [];
  bool _loadingVenues = true;

  @override
  void initState() {
    super.initState();
    futureSports = _loadSports();
    _loadVenues();
  }

  /// Resolves the ground once, then fetches that venue's sports.
  Future<List<Sport>> _loadSports() async {
    if (!_groundResolved) {
      _ground = widget.ground ?? await SelectedGround.instance.read();

      // The picker offers only the real venues now, so there is no "all
      // venues" state left for the screen to sit in. With nothing remembered,
      // open on the first venue the API lists rather than every ground at
      // once — otherwise the grid would show a selection the filter cannot
      // express or undo.
      if (_ground == null) {
        final venues = await _loadVenuesOnce();
        if (venues.isNotEmpty) {
          _ground = venues.first;
          await SelectedGround.instance.save(_ground);
        }
      }

      _groundResolved = true;
    }
    return CoachApiService.fetchSports(ground: _ground);
  }

  /// `GET /sports-complexes`, fetched at most once per screen.
  Future<List<String>> _loadVenuesOnce() =>
      _venuesFuture ??= CoachApiService.fetchVenues();

  Future<void> _loadVenues() async {
    final venues = await _loadVenuesOnce();
    if (!mounted) return;
    setState(() {
      _venues = venues;
      _loadingVenues = false;
    });
  }

  /// Switches venue: remembers the choice, then reloads the grid.
  Future<void> _onVenueSelected(String ground) async {
    if (ground == _ground) return;

    await SelectedGround.instance.save(ground);
    if (!mounted) return;

    setState(() {
      _ground = ground;
      _groundResolved = true;
      futureSports = CoachApiService.fetchSports(ground: ground);
    });
  }

  Color getSportColor(String sportName) {
    switch (sportName.toLowerCase()) {
      case 'basketball':
      case 'basket ball':
        return const Color(0xFF60A5FA);
      case 'cricket':
        return const Color(0xFFfb923c);
      case 'badminton':
        return const Color(0xFFa78bfa);
      case 'pickel ball':
      case 'pickleball':
        return const Color(0xFFf87171);
      case 'dance & zumba':
      case 'dance':
        return const Color(0xFF34d399);
      default:
        return const Color(0xFF6b7280);
    }
  }

  String getSportEmoji(String sportName) {
    switch (sportName.toLowerCase()) {
      case 'basketball':
      case 'basket ball':
        return '🏀';
      case 'cricket':
        return '🏏';
      case 'badminton':
        return '🏸';
      case 'pickel ball':
      case 'pickleball':
        return '🎾';
      case 'dance & zumba':
      case 'dance':
        return '💃';
      default:
        return '⚽';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        // leading: IconButton(
        //   icon: const Icon(Icons.arrow_back, color: Colors.black87),
        //   onPressed: () => Navigator.pop(context),
        // ),
        title: Center(
          child: const Text(
            "Coach",
            style: TextStyle(
              color: Colors.black87,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Available coaches',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ),
                _buildVenuePicker(),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Sport>>(
              future: futureSports,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  // Same columns, spacing and aspect ratio as the sports grid
                  // below, so the tiles land where the placeholders were.
                  return AppShimmer.coachingSports();
                } else if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("No available coaches"),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              futureSports = _loadSports();
                            });
                          },
                          child: const Text("Retry"),
                        ),
                      ],
                    ),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("No sports found"));
                }

                final sports = snapshot.data!;
                final metrics = _sportsGridMetrics(context, sports);
                return GridView.builder(
                  padding: const EdgeInsets.all(20),
                  gridDelegate: metrics.delegate,
                  itemCount: sports.length,
                  itemBuilder: (context, index) {
                    final sport = sports[index];
                    return GestureDetector(
                      onTap: () {
                        // Navigator.push(
                        //   context,
                        //   MaterialPageRoute(
                        //     builder: (context) => BatchScreen(
                        //       sportId: sport.id,
                        //       sportName: sport.sportName,
                        //     ),
                        //   ),
                        // );

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BatchScreen(
                              sportId: sport.id,
                              sportName: sport.sportName,
                              // Keep the venue context: sport ids are scoped
                              // to a ground.
                              ground: _ground,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              getSportColor(sport.sportName),
                              getSportColor(sport.sportName).withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: getSportColor(
                                sport.sportName,
                              ).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        // `clipBehavior` keeps the photo inside the tile's
                        // rounded corners; without it the image squares them off.
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // The sport's own photo from `/sports`. The gradient
                            // above stays visible while it loads and is what the
                            // tile falls back to if the URL is missing or broken,
                            // so a tile is never blank.
                            if (sport.image.isNotEmpty)
                              _SportPhoto(url: sport.image),
                            Positioned(
                              right: -10,
                              bottom: -10,
                              child: Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: Center(
                                  child: Text(
                                    getSportEmoji(sport.sportName),
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // Flexible, so that if a name is longer than
                                  // even the measured height allows it shrinks
                                  // the box rather than overrunning it. The
                                  // ellipsis is the last resort after the tile
                                  // has already grown to fit — not a way of
                                  // hiding the problem.
                                  Flexible(
                                    child: Text(
                                      sport.sportName, // from API
                                      maxLines: _sportTileNameMaxLines,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: metrics.nameSize,
                                        height: _sportTileLineHeight,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    sport.ground, // from API
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: _sportTileGroundSize,
                                      height: _sportTileLineHeight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      // bottomNavigationBar: _buildBottomNav(),
    );
  }

  /// Grid geometry for the sports tiles, measured against the names they hold.
  ///
  /// A fixed `childAspectRatio: 1.2` set the tile height from its width alone,
  /// so a long sport name ran past the bottom. The tile clips its children to
  /// get rounded corners, which turned that overflow into a silently cropped
  /// name instead of the usual overflow stripes, so nothing ever flagged it.
  ///
  /// Nothing is assumed here. Every name is laid out with a [TextPainter] at
  /// the user's own text scale, and the result drives three decisions in turn:
  ///
  ///  1. a name's longest **word** cannot be wrapped, so if it is wider than a
  ///     half-width tile the grid drops to one column rather than ellipsing it,
  ///  2. if the word still will not fit one full-width tile — a 22-character
  ///     name at double system text size on a small phone is simply wider than
  ///     the device — the type shrinks by exactly the shortfall, because a
  ///     whole name a little smaller beats "Multipurpo…",
  ///  3. the tallest measured name then sets the row height.
  ///
  /// The cost is a few text layouts over a list that holds a dozen sports.
  _SportsGridMetrics _sportsGridMetrics(
    BuildContext context,
    List<Sport> sports,
  ) {
    const spacing = 16.0;
    const gridPadding = 20.0;
    const tilePadding = 16.0;

    // Below this the name stops being readable; an ellipsis is better.
    const minNameSize = 11.0;

    final media = MediaQuery.of(context);
    final available = media.size.width - gridPadding * 2;

    TextPainter paint(String text, double size, FontWeight weight,
        {int? maxLines, double? maxWidth}) {
      return TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: size,
            fontWeight: weight,
            height: _sportTileLineHeight,
          ),
        ),
        maxLines: maxLines,
        textScaler: media.textScaler,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxWidth ?? double.infinity);
    }

    double widestWordAt(double size) {
      var widest = 0.0;
      for (final sport in sports) {
        for (final word in sport.sportName.split(RegExp(r'\s+'))) {
          if (word.isEmpty) continue;
          final width = paint(word, size, FontWeight.w600).width;
          if (width > widest) widest = width;
        }
      }
      return widest;
    }

    final widest = widestWordAt(_sportTileNameSize);

    // 1. Two columns unless the longest unbreakable word will not fit in one.
    final twoColumnContent = (available - spacing) / 2 - tilePadding * 2;
    final columns = widest > twoColumnContent ? 1 : 2;

    final tileWidth = (available - spacing * (columns - 1)) / columns;
    final contentWidth = tileWidth - tilePadding * 2;

    // 2. Shrink only by what is actually missing, and never below legibility.
    var nameSize = _sportTileNameSize;
    if (widest > contentWidth && widest > 0) {
      final fitted = _sportTileNameSize * (contentWidth / widest);
      nameSize = fitted < minNameSize ? minNameSize : fitted;
    }

    // 3. Height comes from the tallest name at whatever size it ended up.
    var tallestName = 0.0;
    for (final sport in sports) {
      final height = paint(
        sport.sportName.isEmpty ? ' ' : sport.sportName,
        nameSize,
        FontWeight.w600,
        maxLines: _sportTileNameMaxLines,
        maxWidth: contentWidth,
      ).height;
      if (height > tallestName) tallestName = height;
    }

    final groundHeight =
        paint(' ', _sportTileGroundSize, FontWeight.w400, maxLines: 1).height;

    final needed = tallestName + 4 + groundHeight + tilePadding * 2;

    // A single-column tile would otherwise become absurdly tall; two-column
    // tiles keep at least the proportions they had for short names.
    final floor = columns == 1 ? 0.0 : tileWidth / 1.2;
    final tileHeight = needed < floor ? floor : needed;

    return _SportsGridMetrics(
      nameSize: nameSize,
      delegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        childAspectRatio: tileWidth / tileHeight,
      ),
    );
  }

  /// Venue filter shown beside the "Available coaches" label.
  ///
  /// Sport ids are scoped to a ground, so switching venue reloads the grid and
  /// the choice is remembered for the batch screens.
  Widget _buildVenuePicker() {
    const brandBlue = Color(0xFF1A237E);

    if (_loadingVenues) {
      return const SizedBox(
        height: 16,
        width: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    // Nothing to choose between — keep the row exactly as it was.
    if (_venues.isEmpty) return const SizedBox.shrink();

    // Null only for the moment between the venues arriving and the ground
    // fallback in [_loadSports] settling on the first of them.
    final label = _ground ?? 'Select venue';

    return PopupMenuButton<String>(
      key: const Key('venue_picker'),
      tooltip: 'Select venue',
      offset: const Offset(0, 36),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: _onVenueSelected,
      // Only the real venues — coaching is always scoped to one ground.
      itemBuilder: (context) => [
        ..._venues.map(
          (venue) => _venueMenuItem(venue, venue, _ground == venue),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_on_outlined, size: 16, color: brandBlue),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 130),
              child: Text(
                label,
                key: const Key('venue_picker_label'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _venueMenuItem(
    String value,
    String label,
    bool selected,
  ) {
    const brandBlue = Color(0xFF1A237E);

    return PopupMenuItem<String>(
      key: ValueKey('venue_option_$value'),
      value: value,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: selected ? brandBlue : Colors.black87,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          if (selected) const Icon(Icons.check, size: 18, color: brandBlue),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(Icons.home, "Home", false),
          _buildNavItem(Icons.calendar_today, "Book a Slot", false),
          _buildNavItem(Icons.view_list, "View Batch", true),
          _buildNavItem(Icons.person, "Book & Pay", false),
          _buildNavItem(Icons.settings, "Settings", false),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: isActive ? const Color(0xFF6366F1) : Colors.grey,
          size: 24,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isActive ? const Color(0xFF6366F1) : Colors.grey,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

//888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888

class BatchScreen extends StatefulWidget {
  final String sportId;
  final String sportName;

  /// Optional ground/venue filter, passed to
  /// `GET /batches/sport/{sportId}?ground=`. Null shows every ground.
  final String? ground;

  const BatchScreen({
    super.key,
    required this.sportId,
    required this.sportName,
    this.ground,
  });

  @override
  State<BatchScreen> createState() => _BatchScreenState();
}

class _BatchScreenState extends State<BatchScreen> {
  late Future<List<Batch>> futureBatches;
  List<Coach> allCoaches = [];

  /// Coach for each batch, keyed by batch id. A coach can run several batches
  /// at different times and prices, so "View Details" must resolve the coach
  /// through the batch that was tapped.
  Map<String, Coach> coachByBatchId = const {};

  @override
  void initState() {
    super.initState();
    fetchBatchesAndCoaches();
  }

  void fetchBatchesAndCoaches() {
    setState(() {
      futureBatches = _loadBatchesAndCoaches();
    });
  }

  /// Loads the batches and their coaches together, so the list is never on
  /// screen before the coach lookup is ready.
  Future<List<Batch>> _loadBatchesAndCoaches() async {
    // Both calls hit the same cached request — one round trip.
    final coaches = await CoachApiService.fetchCoachesByBatch(
      widget.sportId,
      ground: widget.ground,
    );
    final batches = await CoachApiService.fetchBatches(
      widget.sportId,
      ground: widget.ground,
    );

    coachByBatchId = coaches;
    allCoaches = coaches.values.toList(growable: false);

    return batches;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.sportName,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: FutureBuilder<List<Batch>>(
        future: futureBatches,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // Card-shaped, like the batch list it stands in for.
            return AppShimmer.batchList();
          } else if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Error: ${snapshot.error}"),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: fetchBatchesAndCoaches,
                    child: const Text("Retry"),
                  ),
                ],
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No batches found"));
          }

          final batches = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: batches.length,
            itemBuilder: (context, index) {
              final batch = batches[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    // Look the coach up by THIS batch, so the timing, price
                    // and age group on the details page belong to the batch
                    // that was tapped rather than to another of the coach's
                    // batches.
                    final coach =
                        coachByBatchId[batch.id] ??
                        allCoaches.firstWhere(
                          (c) => c.id == batch.coachId,
                          orElse: () => Coach(
                            id: '',
                            sportId: '',
                            name: 'Unknown',
                            sport: '',
                            ground: '',
                            image: '',
                            availability: '',
                            price: '',
                            coachBio: '',
                            days: '',
                            ageGroup: '',
                            achievements: [],
                            developmentPath: '',
                            startTime: '',
                            endTime: '',
                          ),
                        );

                    if (coach.id.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              CoachDetailsScreen(coach: coach, batch: batch),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("No coach assigned to this batch"),
                        ),
                      );
                    }
                  },

                  // onTap: () {
                  //   final exists = allCoaches.any((c) => c.id == batch.coachId);
                  //
                  //   if (exists) {
                  //     final coach = allCoaches.firstWhere((c) => c.id == batch.coachId);
                  //     Navigator.push(
                  //       context,
                  //       MaterialPageRoute(
                  //         builder: (context) => CoachDetailsScreen(coach: coach, batch: batch),
                  //       ),
                  //     );
                  //   } else {
                  //     ScaffoldMessenger.of(context).showSnackBar(
                  //       const SnackBar(
                  //         content: Text("No coach assigned to this batch"),
                  //       ),
                  //     );
                  //   }
                  // },

                  // onTap: () {
                  //   final coach = allCoaches.firstWhere(
                  //         (c) => c.id == batch.coachId,
                  //     orElse: () => Coach(id: '', name: '', photo: '', email: '', phone: ''),
                  //   );
                  //
                  //   if (coach.id.isNotEmpty) {
                  //     Navigator.push(
                  //       context,
                  //       MaterialPageRoute(
                  //         builder: (context) => CoachDetailsScreen(coach: coach,batch: batch,),
                  //       ),
                  //     );
                  //   } else {
                  //     ScaffoldMessenger.of(context).showSnackBar(
                  //       const SnackBar(
                  //         content: Text("No coach assigned to this batch"),
                  //       ),
                  //     );
                  //   }
                  // },
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    batch.name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (batch.ageGroup.isNotEmpty)
                                    Text(
                                      "Age Group: ${batch.ageGroup}",
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  if (batch.month.isNotEmpty)
                                    Text(
                                      "Starting from: ${batch.month}",
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  if (batch.days.isNotEmpty)
                                    Text(
                                      "Days: ${batch.days}",
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  if (batch.startTime.isNotEmpty &&
                                      batch.endTime.isNotEmpty)
                                    Text(
                                      "Time: ${batch.startTime} - ${batch.endTime}",
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A237E),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                "View Details",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Text(
                              "Price: ₹${batch.price}",
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// Batch Screen
// class BatchScreen extends StatefulWidget {
//   final String sportId;
//   final String sportName;
//
//   const BatchScreen({super.key, required this.sportId, required this.sportName});
//
//   @override
//   State<BatchScreen> createState() => _BatchScreenState();
// }
//
// class _BatchScreenState extends State<BatchScreen> {
//   late Future<List<Batch>> futureBatches;
//   late Future<List<Coach>> futureCoaches;
//   List<Coach> allCoaches = [];
//
//   @override
//   void initState() {
//     super.initState();
//     futureBatches = CoachApiService.fetchBatches(widget.sportId);
//     futureCoaches = CoachApiService.fetchCoaches(widget.sportId);
//     futureCoaches.then((coaches) {
//       allCoaches = coaches;
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFF8FAFC),
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         elevation: 0,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back, color: Colors.black87),
//           onPressed: () => Navigator.pop(context),
//         ),
//         title: Text(
//           widget.sportName,
//           style: const TextStyle(
//             color: Colors.black87,
//             fontSize: 18,
//             fontWeight: FontWeight.w600,
//           ),
//         ),
//       ),
//       body: FutureBuilder<List<Batch>>(
//         future: futureBatches,
//         builder: (context, snapshot) {
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return const Center(child: CircularProgressIndicator());
//           } else if (snapshot.hasError) {
//             return Center(
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Text("Error: ${snapshot.error}"),
//                   const SizedBox(height: 20),
//                   ElevatedButton(
//                     onPressed: () {
//                       setState(() {
//                         futureBatches = CoachApiService.fetchBatches(widget.sportId);
//                       });
//                     },
//                     child: const Text("Retry"),
//                   ),
//                 ],
//               ),
//             );
//           } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
//             return const Center(child: Text("No batches found"));
//           }
//
//           final batches = snapshot.data!;
//           return ListView.builder(
//             padding: const EdgeInsets.all(20),
//             itemCount: batches.length,
//             itemBuilder: (context, index) {
//               final batch = batches[index];
//               return Container(
//                 margin: const EdgeInsets.only(bottom: 16),
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   borderRadius: BorderRadius.circular(16),
//                   boxShadow: [
//                     BoxShadow(
//                       color: Colors.black.withOpacity(0.05),
//                       blurRadius: 10,
//                       offset: const Offset(0, 2),
//                     ),
//                   ],
//                 ),
//                 child: InkWell(
//                   borderRadius: BorderRadius.circular(16),
//                   onTap: () {
//                     final coach = allCoaches.firstWhere(
//                           (c) => c.id == batch.coachId,
//                       // orElse: () => Coach.empty(),
//                     );
//
//                     if (coach.id.isNotEmpty) {
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                           builder: (context) => CoachDetailsScreen(coach: coach),
//                         ),
//                       );
//                     } else {
//                       ScaffoldMessenger.of(context).showSnackBar(
//                         const SnackBar(
//                           content: Text("No coach assigned to this batch"),
//                         ),
//                       );
//                     }
//                   },
//                   child: Padding(
//                     padding: const EdgeInsets.all(20),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Row(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Expanded(
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   Text(
//                                     batch.name,
//                                     style: const TextStyle(
//                                       fontSize: 18,
//                                       fontWeight: FontWeight.w600,
//                                       color: Colors.black87,
//                                     ),
//                                   ),
//                                   const SizedBox(height: 4),
//                                   Text(
//                                     "Beginner (Below 10 yrs)",
//                                     style: TextStyle(
//                                       fontSize: 14,
//                                       color: Colors.grey[600],
//                                     ),
//                                   ),
//                                   Text(
//                                     "Starting from (${batch.month})",
//                                     style: TextStyle(
//                                       fontSize: 14,
//                                       color: Colors.grey[600],
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                             Container(
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: 12,
//                                 vertical: 6,
//                               ),
//                               decoration: BoxDecoration(
//                                 color: const Color(0xFF4338CA),
//                                 borderRadius: BorderRadius.circular(6),
//                               ),
//                               child: const Text(
//                                 "View Details",
//                                 style: TextStyle(
//                                   color: Colors.white,
//                                   fontSize: 12,
//                                   fontWeight: FontWeight.w500,
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                         const SizedBox(height: 16),
//                         Row(
//                           children: [
//                             Text(
//                               "Price: ₹${batch.price}",
//                               style: const TextStyle(
//                                 fontSize: 14,
//                                 fontWeight: FontWeight.w500,
//                                 color: Colors.black87,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }
// }

// Coach Details Screen

class CoachDetailsScreen extends StatefulWidget {
  final Coach coach;
  final Batch batch;
  const CoachDetailsScreen({
    super.key,
    required this.batch, // Add batch here
    required this.coach,
  });

  @override
  State<CoachDetailsScreen> createState() => _CoachDetailsScreenState();
}

class _CoachDetailsScreenState extends State<CoachDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Coach",
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                // Ground comes from the coach on /batches/sport/{id}.
                widget.coach.ground.trim().isNotEmpty
                    ? "Coach Available in ${widget.coach.ground.trim()}"
                    : "Coach Availability",
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ),
            Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Coach Image — tapping it opens the coach's full profile.
                  Semantics(
                    button: true,
                    label: 'View ${widget.coach.name}’s profile',
                    child: InkWell(
                      key: const Key('coach_photo'),
                      borderRadius: BorderRadius.circular(60),
                      onTap: () => _showCoachProfile(context, widget.coach),
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(60),
                            // A coach photo arrives either as a URL or, for
                            // some records, as an inline base64 `data:` URI —
                            // MediaImage handles both and falls back to the
                            // placeholder when the bytes are in a format
                            // Flutter cannot decode.
                            child: widget.coach.image.isNotEmpty
                                ? MediaImage(
                                    source: widget.coach.image,
                                    height: 120,
                                    width: 120,
                                    fit: BoxFit.cover,
                                    // Shown at 120px; the source runs to well
                                    // over a thousand pixels square.
                                    decodeSize: 360,
                                    errorBuilder: (context, error, stackTrace) =>
                                        _placeholderImage(),
                                  )
                                : _placeholderImage(),
                          ),
                          // Without this the photo looks like decoration
                          // rather than something you can open.
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: const BoxDecoration(
                              color: Color(0xFF1A237E),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.person_outline,
                              size: 15,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Coach Name and Sport Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A237E),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ClipRRect(
                        //   borderRadius: BorderRadius.circular(12),
                        //   child: coach.image.isNotEmpty
                        //       ? Image.network(
                        //     coach.image,
                        //     height: 24,
                        //     width: 24,
                        //     fit: BoxFit.cover,
                        //     errorBuilder: (context, error, stackTrace) =>
                        //         _smallPlaceholderImage(),
                        //   )
                        //       : _smallPlaceholderImage(),
                        // ),
                        // const SizedBox(width: 8),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.coach.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                "${widget.coach.sport} Coach",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Experience / qualifications, when the coach record has
                  // them. Hidden entirely rather than shown as a blank line.
                  if (widget.coach.developmentPath.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        widget.coach.developmentPath,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Timing and Days
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Timing",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              "${widget.batch.startTime} - ${widget.batch.endTime}",
                              // coach.availability.isNotEmpty
                              //     ? coach.availability
                              //     : "6-8 PM",
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Days",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              widget.batch.days.isNotEmpty
                                  ? widget.batch.days
                                  : "-",
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Price and Age Group
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Price per member",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              // Fee of the batch the user tapped — a coach can
                              // run several batches at different prices.
                              "₹${widget.batch.price.isNotEmpty ? widget.batch.price : widget.coach.price}",
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Age Group",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              widget.batch.ageGroup.isNotEmpty
                                  ? widget.batch.ageGroup
                                  : "-",
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Ground
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Ground",
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                        Text(
                          widget.coach.ground,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Description
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Description",
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.coach.coachBio.isNotEmpty
                              ? parseHtmlString(widget.coach.coachBio)
                              : "No description available",
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: Colors.black87,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Achievements List
                        ...widget.coach.achievements
                            .map((a) => _buildAchievementItem(a))
                            .toList(),

                        const SizedBox(height: 16),
                        // Inquiry Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              await _sendInquiry(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1A237E),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              "Inquiry",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementItem(String achievement) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "✅ ",
            style: TextStyle(color: Color(0xFF10B981), fontSize: 14),
          ),
          Expanded(
            child: Text(
              achievement,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  /// The coach's profile, opened by tapping their photo.
  ///
  /// A sheet rather than a route: the details screen underneath is already
  /// about this coach, so this is a closer look at the same subject, not a
  /// place to navigate to and come back from.
  ///
  /// Only what the API actually sent is shown — a coach with no biography or
  /// no certification gets a shorter card, never an empty labelled row.
  void _showCoachProfile(BuildContext context, Coach coach) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.62,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          expand: false,
          builder: (_, scrollController) => Container(
            key: const Key('coach_profile_sheet'),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(70),
                    child: coach.image.isNotEmpty
                        ? MediaImage(
                            source: coach.image,
                            height: 140,
                            width: 140,
                            fit: BoxFit.cover,
                            decodeSize: 420,
                            errorBuilder: (_, __, ___) => _placeholderImage(),
                          )
                        : _placeholderImage(),
                  ),
                ),
                const SizedBox(height: 18),
                Center(
                  child: Text(
                    coach.name.isEmpty ? 'Coach' : coach.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                if (coach.developmentPath.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      coach.developmentPath,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                _coachProfileRow(
                    Icons.sports_outlined, 'Sport', coach.sport),
                _coachProfileRow(
                    Icons.location_on_outlined, 'Venue', coach.ground),
                _coachProfileRow(Icons.event_available_outlined,
                    'Available on', coach.weeklyAvailability),
                _coachProfileRow(Icons.workspace_premium_outlined,
                    'Certification', coach.certification),
                _coachProfileRow(
                    Icons.schedule_outlined, 'Batch timing', coach.availability),
                if (coach.coachBio.trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text(
                    'About',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    coach.coachBio,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.5,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
                const SizedBox(height: 26),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A237E),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// One labelled line of the profile sheet. Renders nothing when the API sent
  /// no value, so the card never shows an empty field.
  Widget _coachProfileRow(IconData icon, String label, String value) {
    final text = value.trim();
    if (text.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF1A237E)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11.5, color: Colors.grey[500]),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderImage() {
    return Container(
      height: 120,
      width: 120,
      decoration: BoxDecoration(
        color: const Color(0xFF1A237E),
        borderRadius: BorderRadius.circular(60),
      ),
      child: const Icon(Icons.person, size: 60, color: Colors.white),
    );
  }

  Widget _smallPlaceholderImage() {
    return Container(
      height: 24,
      width: 24,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.person, size: 12, color: Colors.white),
    );
  }

  /// Opens the enrollment enquiry form, then reports what the server said.
  ///
  /// The form owns `POST /coaching-enquiries` and keeps itself open on a
  /// failure, so the only outcomes that reach here are "cancelled" and "sent".
  Future<void> _sendInquiry(BuildContext context) async {
    // The route is login-gated: the enquiry is filed against the bearer
    // token's user, so there is nothing to submit without a session.
    final profile = await AuthRepository.instance.cachedProfile();
    if (!mounted) return;

    if (profile?.id == null) {
      _showNotLoggedInPopup();
      return;
    }

    final result = await CoachingEnquiryForm.show(
      context,
      batch: widget.batch,
      coach: widget.coach,
      profile: profile!,
    );

    if (!mounted || result == null) return; // Cancelled.

    _showPopup(
      context,
      title: "Success",
      message: result.referenceNumber != null
          ? "${result.message}\nReference: ${result.referenceNumber}"
          : result.message,
      isSuccess: true,
    );
  }

  /// Reusable popup function
  void _showPopup(
    BuildContext context, {
    required String title,
    required String message,
    bool isSuccess = true,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                isSuccess ? Icons.check_circle : Icons.error,
                color: isSuccess ? Colors.green : Colors.red,
              ),
              SizedBox(width: 8),
              Text(title),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  // Future<void> _sendInquiry(BuildContext context) async {
  //   final userId = await AuthService.getUserId();
  //
  //   if (userId == null) {
  //     _showNotLoggedInPopup();
  //     return;
  //   }
  //
  //   final url = Uri.parse("https://nahatasports.com/api/instant-enquiry");
  //   try {
  //     final response = await http.post(
  //       url,
  //       headers: {"Content-Type": "application/json"},
  //       body: json.encode({
  //         "user_id": int.parse(userId),
  //         "coach_id": int.parse(widget.coach.id),
  //       }),
  //     );
  //
  //     final data = json.decode(response.body);
  //
  //     if (data['success'] == true) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text(data['message'] ?? "Your enquiry has been sent!"),
  //           backgroundColor: Colors.green,
  //         ),
  //       );
  //       print(data);
  //     } else {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(
  //           content: Text("Failed to send enquiry"),
  //           backgroundColor: Colors.red,
  //         ),
  //       );
  //     }
  //   } catch (e) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text("Error: $e"),
  //         backgroundColor: Colors.red,
  //       ),
  //     );
  //   }
  // }
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
                child: const Icon(
                  Icons.lock_outline,
                  size: 48,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              const Text(
                "Login Required",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
    Future.delayed(const Duration(seconds: 3), () {
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
  //     Navigator.pop(context);  // Close the dialog
  //     Navigator.pushAndRemoveUntil(
  //       context,
  //       MaterialPageRoute(builder: (_) => LoginScreen()),
  //           (route) => false,
  //     );
  //   });
  // }

  String parseHtmlString(String htmlString) {
    final document = html_parser.parse(htmlString);
    return document.body?.text ?? "";
  }
}

//
// class Sport {
//   final String id;
//   final String sportName;
//   final String ground;
//   final String image;
//
//   Sport({
//     required this.id,
//     required this.sportName,
//     required this.ground,
//     required this.image,
//   });
//
//   // 🔹 Helper function made static so factory can call it
//   static String buildImageUrl(String filename) {
//     if (filename.isEmpty) return "https://via.placeholder.com/150";
//     return "https://nahatasports.com/storage/$filename";
//     // try /public/upload/ or /images/ if /storage/ still gives 404
//   }
//
//   factory Sport.fromJson(Map<String, dynamic> json) {
//     final String rawImage = json['image'] ?? '';
//     return Sport(
//       id: json['id'] ?? '',
//       sportName: json['sport_name'] ?? '',
//       ground: json['ground'] ?? '',
//       image: Sport.buildImageUrl(rawImage), // ✅ call static method
//     );
//   }
// }
//
// class CoachApiService {
//   static const String baseUrl = "https://nahatasports.com/api/coach";
//
//   static Future<List<Sport>> fetchSports() async {
//     final response = await http.get(Uri.parse(baseUrl));
//     if (response.statusCode == 200) {
//       final data = json.decode(response.body);
//       if (data['success'] == true && data['sports'] != null) {
//         return (data['sports'] as List)
//             .map((s) => Sport.fromJson(s))
//             .toList();
//       }
//     }
//     print(response);
//     throw Exception("Failed to load sports");
//   }
//   static Future<List<Coach>> fetchCoaches(String sportId) async {
//     final response = await http.get(Uri.parse(baseUrl));
//     if (response.statusCode == 200) {
//       final data = json.decode(response.body);
//       if (data['success'] == true && data['coaches'] != null) {
//         return (data['coaches'] as List)
//             .where((c) => c['sport_id'].toString() == sportId)
//             .map((c) => Coach.fromJson(c))
//             .toList();
//       }
//     }
//     print(response);
//     throw Exception("Failed to load coaches");
//   }
//
//   static Future<List<Batch>> fetchBatches(String sportId) async {
//     final response = await http.get(Uri.parse(baseUrl));
//     if (response.statusCode == 200) {
//       final data = json.decode(response.body);
//       if (data['success'] == true && data['batches'] != null) {
//         return (data['batches'] as List)
//             .where((b) => b['sport_id'].toString() == sportId)
//             .map((b) => Batch.fromJson(b))
//             .toList();
//       }
//     }
//     print(response);
//     throw Exception("Failed to load batches");
//   }
// }
//
//
//
// class SportsScreen extends StatefulWidget {
//   const SportsScreen({super.key});
//
//   @override
//   State<SportsScreen> createState() => _SportsScreenState();
// }
//
// class _SportsScreenState extends State<SportsScreen> {
//   late Future<List<Sport>> futureSports;
//
//   @override
//   void initState() {
//     super.initState();
//     futureSports = CoachApiService.fetchSports();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("Sports")),
//       body: FutureBuilder<List<Sport>>(
//         future: futureSports,
//         builder: (context, snapshot) {
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return const Center(child: CircularProgressIndicator());
//           } else if (snapshot.hasError) {
//             return Center(child: Text("Error: ${snapshot.error}"));
//           } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
//             return const Center(child: Text("No sports found"));
//           }
//
//           final sports = snapshot.data!;
//           return ListView.builder(
//             itemCount: sports.length,
//             itemBuilder: (context, index) {
//               final sport = sports[index];
//               return Card(
//                 margin: const EdgeInsets.all(8),
//                 child: ListTile(
//                   onTap: () {
//                     Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                         builder: (context) => BatchScreen(
//                           sportId: sport.id,
//                           sportName: sport.sportName,
//                         ),
//                       ),
//                     );
//                   },
//
//                   leading:Image.network(
//                     sport.image,
//                     width: 60,
//                     height: 60,
//                     fit: BoxFit.cover,
//                     errorBuilder: (context, error, stackTrace) {
//                       return const Icon(Icons.sports, size: 40, color: Colors.grey);
//                     },
//                   ),
//
//                   title: Text(sport.sportName),
//                   subtitle: Text(sport.ground),
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }
// }
//
//
// class Batch {
//   final String id;
//   final String sportId;
//   final String coachId;
//   final String name;
//   final String month;
//   final String ageGroup;
//   final String days;
//   final String startTime;
//   final String endTime;
//   final String price;
//
//   Batch({
//     required this.id,
//     required this.sportId,
//     required this.coachId,
//     required this.name,
//     required this.month,
//     required this.ageGroup,
//     required this.days,
//     required this.startTime,
//     required this.endTime,
//     required this.price,
//   });
//
//   factory Batch.fromJson(Map<String, dynamic> json) {
//     return Batch(
//       id: json['id'] ?? '',
//       sportId: json['sport_id'] ?? '',
//       coachId: json['coach_id'] ?? '',
//       name: json['name'] ?? '',
//       month: json['month'] ?? '',
//       ageGroup: json['age_group'] ?? '',
//       days: json['days'] ?? '',
//       startTime: json['start_time'] ?? '',
//       endTime: json['end_time'] ?? '',
//       price: json['price'] ?? '',
//     );
//   }
// }
//
//
// class BatchScreen extends StatefulWidget {
//   final String sportId;
//   final String sportName;
//
//   const BatchScreen({super.key, required this.sportId, required this.sportName});
//
//   @override
//   State<BatchScreen> createState() => _BatchScreenState();
// }
// class _BatchScreenState extends State<BatchScreen> {
//   late Future<List<Batch>> futureBatches;
//   late Future<List<Coach>> futureCoaches;
//
//   List<Coach> allCoaches = [];
//
//   @override
//   void initState() {
//     super.initState();
//     futureBatches = CoachApiService.fetchBatches(widget.sportId);
//     futureCoaches = CoachApiService.fetchCoaches(widget.sportId);
//     futureCoaches.then((coaches) {
//       allCoaches = coaches; // keep in memory for batch taps
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text("${widget.sportName} Batches & Coaches")),
//       body: SingleChildScrollView(
//         child: Column(
//           children: [
//             // 🔹 Batches section
//             FutureBuilder<List<Batch>>(
//               future: futureBatches,
//               builder: (context, snapshot) {
//                 if (snapshot.connectionState == ConnectionState.waiting) {
//                   return const Center(child: CircularProgressIndicator());
//                 } else if (snapshot.hasError) {
//                   return Center(child: Text("Error: ${snapshot.error}"));
//                 } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
//                   return const Center(child: Text("No batches found"));
//                 }
//
//                 final batches = snapshot.data!;
//                 return Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     const Padding(
//                       padding: EdgeInsets.all(8),
//                       child: Text("Batches",
//                           style: TextStyle(
//                               fontSize: 18, fontWeight: FontWeight.bold)),
//                     ),
//                     ...batches.map((batch) => Card(
//                       margin: const EdgeInsets.all(8),
//                       child: InkWell(
//                         onTap: () {
//                           // 🔎 find coach by batch.coachId
//                           final coach = allCoaches.firstWhere(
//                                 (c) => c.id == batch.coachId,
//                             // orElse: () => Coach.empty(),
//                           );
//
//                           if (coach.id.isNotEmpty) {
//                             Navigator.push(
//                               context,
//                               MaterialPageRoute(
//                                 builder: (context) =>
//                                     CoachDetailsScreen(coach: coach),
//                               ),
//                             );
//                           } else {
//                             ScaffoldMessenger.of(context).showSnackBar(
//                               const SnackBar(
//                                   content: Text(
//                                       "No coach assigned to this batch")),
//                             );
//                           }
//                         },
//                         child: ListTile(
//                           title: Text(batch.name),
//                           subtitle: Text(
//                               "${batch.days}\n${batch.startTime} - ${batch.endTime}\nAge: ${batch.ageGroup}"),
//                           trailing: Text("₹${batch.price}"),
//                         ),
//                       ),
//                     )),
//                   ],
//                 );
//               },
//             ),
//
//
//           ],
//         ),
//       ),
//     );
//   }
// }
//
//
//
// class Coach {
//   final String id;
//   final String sportId;
//   final String name;
//   final String sport;
//   final String price;
//   final String availability;
//   final String coachBio;
//   final String ground;
//   final String image;
//   final String certificationFile;
//   final String awards;
//
//   Coach({
//     required this.id,
//     required this.sportId,
//     required this.name,
//     required this.sport,
//     required this.price,
//     required this.availability,
//     required this.coachBio,
//     required this.ground,
//     required this.image,
//     required this.certificationFile,
//     required this.awards,
//   });
//
//   factory Coach.fromJson(Map<String, dynamic> json) {
//     final rawImage = json['image'] ?? '';
//     final rawCert = json['certificationfile'] ?? '';
//
//     return Coach(
//       id: json['id'] ?? '',
//       sportId: json['sport_id'] ?? '',
//       name: json['name'] ?? '',
//       sport: json['sport'] ?? '',
//       price: json['price'] ?? '',
//       availability: json['availability'] ?? '',
//       coachBio: json['coachbio'] ?? '',
//       ground: json['ground'] ?? '',
//       image: Sport.buildImageUrl(rawImage),
//       certificationFile: rawCert.isNotEmpty ? Sport.buildImageUrl(rawCert) : '',
//       awards: json['awards'] ?? '',
//     );
//   }
// }
//
//
// class CoachDetailsScreen extends StatelessWidget {
//   final Coach coach;
//
//   const CoachDetailsScreen({super.key, required this.coach});
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text(coach.name)),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // 🔹 Coach image
//             Center(
//               child: ClipRRect(
//                 borderRadius: BorderRadius.circular(10),
//                 child: Image.network(
//                   coach.image,
//                   height: 180,
//                   width: 180,
//                   fit: BoxFit.cover,
//                   errorBuilder: (context, error, stackTrace) =>
//                   const Icon(Icons.person, size: 100, color: Colors.grey),
//                 ),
//               ),
//             ),
//             const SizedBox(height: 20),
//
//             // 🔹 Name & Sport
//             Text(coach.name,
//                 style: const TextStyle(
//                     fontSize: 22, fontWeight: FontWeight.bold)),
//             Text("Sport: ${coach.sport}",
//                 style: const TextStyle(fontSize: 16, color: Colors.grey)),
//
//             const SizedBox(height: 10),
//
//             // 🔹 Price & Availability
//             // Row(
//             //   mainAxisAlignment: MainAxisAlignment.start,
//             //   crossAxisAlignment: CrossAxisAlignment.start,
//             //   children: [
//             //     Text("Price: ₹${coach.price}",
//             //         style: const TextStyle(fontSize: 16)),
//             //     Text("\nAvailability: ${coach.availability}",
//             //         style: const TextStyle(fontSize: 16)),
//             //   ],
//             // ),
//             Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text("Price: ₹${coach.price}", style: const TextStyle(fontSize: 16)),
//                 Text("Availability: ${coach.availability}", style: const TextStyle(fontSize: 16)),
//               ],
//             ),
//
//             const Divider(height: 30),
//
//             // 🔹 Ground
//             Text("Ground: ${coach.ground}",
//                 style:
//                 const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
//
//             const SizedBox(height: 10),
//
//             // 🔹 Bio
//             Text("Bio:",
//                 style:
//                 const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//             const SizedBox(height: 5),
//             Text(coach.coachBio.isNotEmpty ? coach.coachBio : "No bio available",
//                 style: const TextStyle(fontSize: 16)),
//
//             const SizedBox(height: 20),
//
//             // 🔹 Certification file (if exists)
//             if (coach.certificationFile.isNotEmpty) ...[
//               Text("Certification:",
//                   style: const TextStyle(
//                       fontSize: 18, fontWeight: FontWeight.bold)),
//               const SizedBox(height: 5),
//               Image.network(
//                 coach.certificationFile,
//                 height: 150,
//                 fit: BoxFit.contain,
//                 errorBuilder: (context, error, stackTrace) => const Text(
//                   "Certification file not available",
//                   style: TextStyle(color: Colors.grey),
//                 ),
//               ),
//               const SizedBox(height: 20),
//             ],
//
//             // 🔹 Awards
//             if (coach.awards.isNotEmpty) ...[
//               Text("Awards:",
//                   style: const TextStyle(
//                       fontSize: 18, fontWeight: FontWeight.bold)),
//               const SizedBox(height: 5),
//               Text(coach.awards, style: const TextStyle(fontSize: 16)),
//             ],
//           ],
//         ),
//       ),
//     );
//   }
// }
//
//
// class BatchDetailsScreen extends StatelessWidget {
//   final Batch batch;
//
//   const BatchDetailsScreen({super.key, required this.batch});
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text(batch.name)),
//       body: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(batch.name,
//                 style: const TextStyle(
//                     fontSize: 22, fontWeight: FontWeight.bold)),
//             const SizedBox(height: 10),
//             Text("Days: ${batch.days}"),
//             Text("Time: ${batch.startTime} - ${batch.endTime}"),
//             Text("Age Group: ${batch.ageGroup}"),
//             Text("Price: ₹${batch.price}"),
//           ],
//         ),
//       ),
//     );
//   }
// }
//
//
