import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:nahata_app/bottombar/slotbook.dart';

import 'Custombottombar.dart';



class Viewgame extends StatefulWidget {
  const Viewgame({super.key});

  @override
  State<Viewgame> createState() => _ViewgameState();
}

class _ViewgameState extends State<Viewgame>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  // @override
  // void initState() {
  //   super.initState();
  //   _fadeController = AnimationController(
  //     duration: const Duration(milliseconds: 800),
  //     vsync: this,
  //   );
  //   _scaleController = AnimationController(
  //     duration: const Duration(milliseconds: 600),
  //     vsync: this,
  //   );
  //
  //   _fadeAnimation = Tween<double>(
  //     begin: 0.0,
  //     end: 1.0,
  //   ).animate(CurvedAnimation(
  //     parent: _fadeController,
  //     curve: Curves.easeInOut,
  //   ));
  //
  //   _scaleAnimation = Tween<double>(
  //     begin: 0.8,
  //     end: 1.0,
  //   ).animate(CurvedAnimation(
  //     parent: _scaleController,
  //     curve: Curves.elasticOut,
  //   ));
  //
  //   _fadeController.forward();
  //   _scaleController.forward();
  // }
  late Future<List<Sport>> _sportsFuture;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _fadeController.forward();
    _scaleController.forward();

    // 🔥 Fetch games by location (example: "Sinhgad Rd")
    _sportsFuture = Api_loc_Service.fetchSportsByLocation("Sinhgad Rd");
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
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
          'Book and Play',
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
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                Text(
                  'Games at Sinhgad Rd',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 25),
                // GridView.count(
                //   crossAxisCount: 2,
                //   shrinkWrap: true,
                //   physics: const NeverScrollableScrollPhysics(),
                //   mainAxisSpacing: 20,
                //   crossAxisSpacing: 20,
                //   childAspectRatio: 1.1,
                //   children: [
                //     _buildGameCard(
                //       'Basketball',
                //       '🏀',
                //       const LinearGradient(
                //         begin: Alignment.topLeft,
                //         end: Alignment.bottomRight,
                //         colors: [Color(0xFF64B5F6), Color(0xFF42A5F5)],
                //       ),
                //       0,
                //     ),
                //     _buildGameCard(
                //       'Cricket',
                //       '🏏',
                //       const LinearGradient(
                //         begin: Alignment.topLeft,
                //         end: Alignment.bottomRight,
                //         colors: [Color(0xFFFFB74D), Color(0xFFFF9800)],
                //       ),
                //       1,
                //     ),
                //     _buildGameCard(
                //       'Badminton',
                //       '🏸',
                //       const LinearGradient(
                //         begin: Alignment.topLeft,
                //         end: Alignment.bottomRight,
                //         colors: [Color(0xFF9575CD), Color(0xFF7E57C2)],
                //       ),
                //       2,
                //     ),
                //     _buildGameCard(
                //       'Pickleball',
                //       '🎾',
                //       const LinearGradient(
                //         begin: Alignment.topLeft,
                //         end: Alignment.bottomRight,
                //         colors: [Color(0xFFE57373), Color(0xFFEF5350)],
                //       ),
                //       3,
                //     ),
                //   ],
                // ),
                FutureBuilder<List<Sport>>(
                  future: _sportsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          "Error: ${snapshot.error}",
                          style: const TextStyle(color: Colors.red),
                        ),
                      );
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text("No sports found"));
                    }

                    final sports = snapshot.data!;

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 20,
                        mainAxisSpacing: 20,
                        childAspectRatio: 1.1,
                      ),
                      itemCount: sports.length,
                      itemBuilder: (context, index) {
                        final sport = sports[index];
                        return _buildGameCard(sport.name, sport.imageUrl, index);
                      },
                    );
                  },
                ),

                const SizedBox(height: 30),
                // _buildFeaturedSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }
  Widget _buildGameCard(String title, String imageUrl, int index) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 600 + (index * 100)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: Color(0xFF1A237E), // fallback color
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SlotBookingScreen(game: title,location:'Sinhgad Road' ,),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: imageUrl.isNotEmpty
                              ? Image.network(imageUrl, fit: BoxFit.cover)
                              : const Icon(Icons.sports, color: Colors.white, size: 30),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Widget _buildGameCard(String title, String emoji, Gradient gradient, int index) {
  //   return TweenAnimationBuilder<double>(
  //     duration: Duration(milliseconds: 600 + (index * 100)),
  //     tween: Tween(begin: 0.0, end: 1.0),
  //     curve: Curves.elasticOut,
  //     builder: (context, value, child) {
  //       return Transform.scale(
  //         scale: value,
  //         child: GestureDetector(
  //           onTap: () {
  //             Navigator.push(
  //               context,
  //               MaterialPageRoute(
  //                 builder: (_) => slotbook(gameName: title), // pass game name
  //               ),
  //             );
  //           },
  //
  //           child: AnimatedContainer(
  //             duration: const Duration(milliseconds: 200),
  //             decoration: BoxDecoration(
  //               gradient: gradient,
  //               borderRadius: BorderRadius.circular(20),
  //               boxShadow: [
  //                 BoxShadow(
  //                   color: gradient.colors.first.withOpacity(0.3),
  //                   blurRadius: 15,
  //                   offset: const Offset(0, 8),
  //                 ),
  //               ],
  //             ),
  //             child: Material(
  //               color: Colors.transparent,
  //               child: InkWell(
  //                 borderRadius: BorderRadius.circular(20),
  //                 onTap: () {
  //                   Navigator.push(
  //                     context,
  //                     MaterialPageRoute(
  //                       builder: (_) => slotbook(gameName: title), // pass game name
  //                     ),
  //                   );
  //                 },
  //                 child: Container(
  //                   padding: const EdgeInsets.all(20),
  //                   child: Column(
  //                     mainAxisAlignment: MainAxisAlignment.center,
  //                     children: [
  //                       Container(
  //                         width: 60,
  //                         height: 60,
  //                         decoration: BoxDecoration(
  //                           color: Colors.white.withOpacity(0.2),
  //                           borderRadius: BorderRadius.circular(30),
  //                         ),
  //                         child: Center(
  //                           child: Text(
  //                             emoji,
  //                             style: const TextStyle(fontSize: 28),
  //                           ),
  //                         ),
  //                       ),
  //                       const SizedBox(height: 12),
  //                       Text(
  //                         title,
  //                         style: const TextStyle(
  //                           color: Colors.white,
  //                           fontSize: 16,
  //                           fontWeight: FontWeight.w600,
  //                         ),
  //                         textAlign: TextAlign.center,
  //                       ),
  //                     ],
  //                   ),
  //                 ),
  //               ),
  //             ),
  //           ),
  //         ),
  //       );
  //     },
  //   );
  // }

  Widget _buildFeaturedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Featured Activities',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 15),
        Container(
          height: 120,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF667eea).withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {},
              child: const Padding(
                padding: EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Tournament Week',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Join exciting tournaments and win prizes!',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.emoji_events,
                      color: Colors.white,
                      size: 40,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showGameDetails(String gameName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    gameName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Available time slots and booking details for $gameName',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 15,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Book Now',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
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
}




class Api_loc_Service {
  static Future<List<Sport>> fetchSportsByLocation(String location) async {
    final uri = Uri.parse('https://nahatasports.com/sports_list');
    final response = await http.get(uri);

    print("API response: ${response.body}");

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonMap = json.decode(response.body);

      if (!jsonMap.containsKey('data')) {
        throw Exception('No data found in API response');
      }

      final availableKeys = jsonMap['data'].keys;
      print('Requested location: "$location"');
      print('Available keys: $availableKeys');

      final matchedKey = availableKeys.firstWhere(
            (k) => k.toLowerCase().trim() == location.toLowerCase().trim(),
        orElse: () => throw Exception('No data for "$location"'),
      );

      final List<dynamic> sportsList = jsonMap['data'][matchedKey];

      return sportsList.map((e) => Sport.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load sports');
    }
  }




}
class Sport {
  final String name;
  final String imageUrl;

  Sport({required this.name, required this.imageUrl});

  factory Sport.fromJson(Map<String, dynamic> json) {
    return Sport(
      name: json['sport_name'] ?? 'Unknown',
      imageUrl: json['image'] ?? '',
    );
  }
}
