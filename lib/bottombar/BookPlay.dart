import 'package:carousel_slider/carousel_options.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';

import 'package:flutter/material.dart';
import 'dart:math' as math;


import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:nahata_app/bottombar/Custombottombar.dart';
import 'package:nahata_app/bottombar/viewgame.dart';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
// /////////////////////////////////////////////////////////////
// class Bookplay extends StatefulWidget {
//   @override
//   _BookplayState createState() => _BookplayState();
// }
//
// class _BookplayState extends State<Bookplay>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _animationController;
//   late Animation<double> _fadeAnimation;
//   late Animation<Offset> _slideAnimation;
//   double _distanceInKm = 0.0;
//
//   // Coordinates of Nahata Sports Complex
//   final double _complexLatitude = 18.4570;
//   final double _complexLongitude = 73.8069;
//
//   @override
//   void initState() {
//     super.initState();
//     _animationController = AnimationController(
//       duration: Duration(milliseconds: 800),
//       vsync: this,
//     );
//
//     _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
//       CurvedAnimation(
//         parent: _animationController,
//         curve: Curves.easeInOut,
//       ),
//     );
//
//     _slideAnimation = Tween<Offset>(begin: Offset(0.0, 0.3), end: Offset.zero)
//         .animate(
//       CurvedAnimation(
//         parent: _animationController,
//         curve: Curves.easeOutCubic,
//       ),
//     );
//
//     _animationController.forward();
//     _calculateDistance();
//   }
//
//   Future<void> _calculateDistance() async {
//     bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
//     if (!serviceEnabled) {
//       print('Location services are disabled.');
//       return;
//     }
//
//     LocationPermission permission = await Geolocator.checkPermission();
//     if (permission == LocationPermission.denied) {
//       permission = await Geolocator.requestPermission();
//     }
//
//     if (permission == LocationPermission.denied ||
//         permission == LocationPermission.deniedForever) {
//       print('Location permissions are denied.');
//       return;
//     }
//
//     Position position = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high);
//
//     double distance = Geolocator.distanceBetween(
//       position.latitude,
//       position.longitude,
//       _complexLatitude,
//       _complexLongitude,
//     );
//
//     setState(() {
//       _distanceInKm = distance / 1000;
//     });
//   }
//
//   @override
//   void dispose() {
//     _animationController.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return WillPopScope(
//       onWillPop: () async {
//         Navigator.pushAndRemoveUntil(
//           context,
//           MaterialPageRoute(builder: (context) => const CustomBottomNav()),
//               (route) => false, // clears all old routes
//         );
//
//         return false; // prevent default back behavior
//       },
//
//       child: Scaffold(
//         body: Stack(
//           children: [
//             FlutterMap(
//               options: MapOptions(
//                 initialCenter: LatLng(18.5204, 73.8567), // Pune Location
//                 initialZoom: 10,
//                 maxZoom: 19,
//               ),
//               children: [
//                 TileLayer(
//                   urlTemplate:
//                   "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
//                   userAgentPackageName: 'com.sports_nahata.app',  // Replace this with your actual package name
//                 ),
//                 Container(
//                   decoration: BoxDecoration(
//                     gradient: LinearGradient(
//                       colors: [
//                         Colors.black.withOpacity(0.1),
//                         Colors.black.withOpacity(0.3),
//                       ],
//                       begin: Alignment.topCenter,
//                       end: Alignment.bottomCenter,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//
//             SafeArea(
//               child: FadeTransition(
//                 opacity: _fadeAnimation,
//                 child: Padding(
//                   padding: EdgeInsets.all(16.0),
//                   child: Row(
//                     children: [
//                       Text(
//                         'Book and Play',
//                         style: TextStyle(
//                           fontSize: 20,
//                           fontWeight: FontWeight.w600,
//                           color: Colors.black87,
//                         ),
//                         textAlign: TextAlign.center,
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//
//             Positioned(
//               bottom: 100,
//               left: 20,
//               right: 20,
//               child: SlideTransition(
//                 position: _slideAnimation,
//                 child: FadeTransition(
//                   opacity: _fadeAnimation,
//                   child: Container(
//                     padding: EdgeInsets.all(16),
//                     decoration: BoxDecoration(
//                       color: Colors.white,
//                       borderRadius: BorderRadius.circular(12),
//                       boxShadow: [
//                         BoxShadow(
//                           color: Colors.black.withOpacity(0.15),
//                           blurRadius: 12,
//                           offset: Offset(0, 4),
//                         ),
//                       ],
//                     ),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         Row(
//                           children: [
//                             Icon(
//                               Icons.favorite_border,
//                               color: Colors.grey[600],
//                               size: 20,
//                             ),
//                             SizedBox(width: 8),
//                             Text(
//                               'Sinhgad Rd',
//                               style: TextStyle(
//                                 fontSize: 18,
//                                 fontWeight: FontWeight.bold,
//                                 color: Colors.black87,
//                               ),
//                             ),
//                           ],
//                         ),
//                         SizedBox(height: 4),
//                         Row(
//                           children: [
//                             Icon(
//                               Icons.location_on,
//                               color: Colors.grey[500],
//                               size: 16,
//                             ),
//                             SizedBox(width: 4),
//                             Expanded(
//                               child: Text(
//                                 'Nahata Sports Complex, Near Veer Baji Pasalkar Chowk, Near Wadgaon Highway Bridge, Wadgaon Bk, Pune-411030',
//                                 style: TextStyle(
//                                   fontSize: 12,
//                                   color: Colors.grey[600],
//                                   height: 1.3,
//                                 ),
//                                 maxLines: 3,
//                                 overflow: TextOverflow.ellipsis,
//                               ),
//                             ),
//                           ],
//                         ),
//                         SizedBox(height: 12),
//                         Row(
//                           children: [
//                             Text(
//                               '${_distanceInKm.toStringAsFixed(1)} km away',
//                               style: TextStyle(
//                                 fontSize: 12,
//                                 color: Colors.blue[600],
//                                 fontWeight: FontWeight.w500,
//                               ),
//                             ),
//                             Spacer(),
//                             GestureDetector(
//                               onTap: () {
//                                 Navigator.pushReplacement(
//                                   context,
//                                   MaterialPageRoute(
//                                       builder: (context) => Viewgame()),
//                                 );
//                               },
//                               child: Container(
//                                 padding: EdgeInsets.symmetric(
//                                     horizontal: 16, vertical: 8),
//                                 decoration: BoxDecoration(
//                                   color: Color(0xFF1a237e),
//                                   borderRadius: BorderRadius.circular(20),
//                                 ),
//                                 child: Text(
//                                   'View Games',
//                                   style: TextStyle(
//                                     color: Colors.white,
//                                     fontSize: 12,
//                                     fontWeight: FontWeight.w500,
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
//
//////////////////////////////////////////////////////////////////////////////////////////////////


class VenueListScreen extends StatefulWidget {
  const VenueListScreen({Key? key}) : super(key: key);

  @override
  State<VenueListScreen> createState() => _VenueListScreenState();
}

class _VenueListScreenState extends State<VenueListScreen> {

  String selectedSport = 'All Sports';
  late String selectedDate;

  int _currentIndex = 0;

  final List<String> sliderImages = [
    'https://images.unsplash.com/photo-1546519638-68e109498ffc?w=800',
    // 'https://images.unsplash.com/photo-1519766030446-ae88ffa134c0?w=800',
    'https://images.unsplash.com/photo-1521412644187-c49fa049e84d?w=800',
  ];
  @override
  void initState() {
    super.initState();
    // Format date like "27 Oct" or "27th Oct"
    DateTime now = DateTime.now();
    String day = now.day.toString();
    String month = DateFormat('MMM').format(now);
    selectedDate = '$day $month'; // or '$day${getDaySuffix(now.day)} $month';
  }

  // Optional: if you want to show "27th Oct" instead of "27 Oct"
  String getDaySuffix(int day) {
    if (day >= 11 && day <= 13) {
      return 'th';
    }
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Play',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Image with carousel dots
            Stack(
              alignment: Alignment.bottomCenter,
              children: [
                CarouselSlider(
                  options: CarouselOptions(
                    height: 200,
                    autoPlay: true,
                    autoPlayInterval: const Duration(seconds: 3),
                    autoPlayAnimationDuration: const Duration(milliseconds: 500),
                    enlargeCenterPage: true,
                    viewportFraction: 1,
                    onPageChanged: (index, reason) {
                      setState(() {
                        _currentIndex = index;
                      });
                    },
                  ),
                  items: sliderImages.map((imageUrl) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        image: DecorationImage(
                          image: NetworkImage(imageUrl),
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  }).toList(),
                ),

                // ✅ Dots Indicator
                Positioned(
                  bottom: 12,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: sliderImages.asMap().entries.map((entry) {
                      return Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentIndex == entry.key
                              ? Colors.white
                              : Colors.white.withOpacity(0.5),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
            SizedBox(height: 5,),
            // Available Venues and Filters
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Available Venues (2)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Filter Chips Row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,

                    child: Row(
                      children: [
                        // Date Dropdown
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF5B4FC7),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                selectedDate,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 4),
                              // const Icon(
                              //   Icons.keyboard_arrow_down,
                              //   color: Colors.white,
                              //   size: 18,
                              // ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // All Sports Chip
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'All Sports',
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Football Chip
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Cricket',
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Basketball',
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Badminton',
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        // Container(
                        //   padding: const EdgeInsets.symmetric(
                        //     horizontal: 16,
                        //     vertical: 8,
                        //   ),
                        //   decoration: BoxDecoration(
                        //     color: Colors.white,
                        //     border: Border.all(color: Colors.grey.shade300),
                        //     borderRadius: BorderRadius.circular(20),
                        //   ),
                        //   child: const Text(
                        //     'Football',
                        //     style: TextStyle(
                        //       color: Colors.black87,
                        //       fontSize: 13,
                        //       fontWeight: FontWeight.w500,
                        //     ),
                        //   ),
                        // ),
                        // Container(
                        //   padding: const EdgeInsets.symmetric(
                        //     horizontal: 16,
                        //     vertical: 8,
                        //   ),
                        //   decoration: BoxDecoration(
                        //     color: Colors.white,
                        //     border: Border.all(color: Colors.grey.shade300),
                        //     borderRadius: BorderRadius.circular(20),
                        //   ),
                        //   child: const Text(
                        //     'Football',
                        //     style: TextStyle(
                        //       color: Colors.black87,
                        //       fontSize: 13,
                        //       fontWeight: FontWeight.w500,
                        //     ),
                        //   ),
                        // ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),

            // Venue Cards
            VenueCard(
              name: 'Sinhgad Rd',
              address: 'Nahata Sports Complex , Near Veer Baji Pasalkar Chowk, Near Wadgaon Highway Bridge, Wadgaon Bk , Pune-411030',
              rating: '5.0(2)',
              imageUrl: 'assets/56.jpg',
              // sport: 'Pickle ball',
            ),

            VenueCard(
              name: 'Gangadham Chowk',
              address: 'Aai Mata Mandir, Najushree Hall -on the way of, to, Chowk, Ganga Dham, Pune, Maharashtra 411037',
              rating: '5.0(2)',
              imageUrl: 'assets/23.webp',
              // sport: 'Pickle ball',
            ),
          ],
        ),
      ),
    );
  }
}


class VenueCard extends StatelessWidget {
  final String name;
  final String address;
  final String rating;
  final String imageUrl;
  // final String sport;

  const VenueCard({
    Key? key,
    required this.name,
    required this.address,
    required this.rating,
    required this.imageUrl,
    // required this.sport,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Viewgame(locationName: name), // dynamic location
          ),
        );
      },
      child : Container(
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Venue Image
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              child: Image.asset(
                imageUrl,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),

            // Sport Badge
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.sports_tennis,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      // const SizedBox(width: 4),
                      // Text(
                      //   sport,
                      //   style: TextStyle(
                      //     fontSize: 12,
                      //     color: Colors.grey.shade600,
                      //     fontWeight: FontWeight.w500,
                      //   ),
                      // ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Venue Name and Rating
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.star,
                            size: 16,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            rating,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Address
                  Text(
                    address,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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



// class Bookplay extends StatefulWidget {
//   @override
//   _BookplayState createState() => _BookplayState();
// }
//
// class _BookplayState extends State<Bookplay>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _animationController;
//   late Animation<double> _fadeAnimation;
//   late Animation<Offset> _slideAnimation;
//
//   @override
//   void initState() {
//     super.initState();
//     _animationController = AnimationController(
//       duration: Duration(milliseconds: 800),
//       vsync: this,
//     );
//
//     _fadeAnimation = Tween<double>(
//       begin: 0.0,
//       end: 1.0,
//     ).animate(CurvedAnimation(
//       parent: _animationController,
//       curve: Curves.easeInOut,
//     ));
//
//     _slideAnimation = Tween<Offset>(
//       begin: Offset(0.0, 0.3),
//       end: Offset.zero,
//     ).animate(CurvedAnimation(
//       parent: _animationController,
//       curve: Curves.easeOutCubic,
//     ));
//
//     _animationController.forward();
//   }
//
//   @override
//   void dispose() {
//     _animationController.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Stack(
//         children: [
//           // Map background
//           Container(
//             width: double.infinity,
//             height: double.infinity,
//             decoration: BoxDecoration(
//               image: DecorationImage(
//                 image: NetworkImage(
//                   'https://images.unsplash.com/photo-1524661135-423995f22d0b?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=2074&q=80',
//                 ),
//                 fit: BoxFit.cover,
//               ),
//             ),
//             child: Container(
//               decoration: BoxDecoration(
//                 gradient: LinearGradient(
//                   colors: [
//                     Colors.black.withOpacity(0.1),
//                     Colors.black.withOpacity(0.3),
//                   ],
//                   begin: Alignment.topCenter,
//                   end: Alignment.bottomCenter,
//                 ),
//               ),
//             ),
//           ),
//
//           // Header
//           SafeArea(
//             child: FadeTransition(
//               opacity: _fadeAnimation,
//               child: Padding(
//                 padding: EdgeInsets.all(16.0),
//                 child: Expanded(
//                   child: Row(
//
//                     children: [
//                       // Container(
//                       //   decoration: BoxDecoration(
//                       //     color: Colors.white,
//                       //     borderRadius: BorderRadius.circular(12),
//                       //     boxShadow: [
//                       //       BoxShadow(
//                       //         color: Colors.black.withOpacity(0.1),
//                       //         blurRadius: 8,
//                       //         offset: Offset(0, 2),
//                       //       ),
//                       //     ],
//                       //   ),
//                       //   child: IconButton(
//                       //     icon: Icon(Icons.arrow_back_ios, color: Colors.black87),
//                       //     onPressed: () {
//                       //       Navigator.of(context).pop();
//                       //     },
//                       //   ),
//                       // ),
//                       // SizedBox(width: 16),
//                       Text(
//                         'Book and Play',
//                         style: TextStyle(
//                           fontSize: 20,
//                           fontWeight: FontWeight.w600,
//                           color: Colors.black87,
//                           // shadows: [
//                           //   Shadow(
//                           //     color: Colors.black.withOpacity(0.5),
//                           //     offset: Offset(0, 1),
//                           //     blurRadius: 3,
//                           //   ),
//                           // ],
//                         ),
//                         textAlign: TextAlign.center,
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ),
//
//           // Location info card (matching your design)
//           Positioned(
//             bottom: 100,
//             left: 20,
//             right: 20,
//             child: SlideTransition(
//               position: _slideAnimation,
//               child: FadeTransition(
//                 opacity: _fadeAnimation,
//                 child: Container(
//                   padding: EdgeInsets.all(16),
//                   decoration: BoxDecoration(
//                     color: Colors.white,
//                     borderRadius: BorderRadius.circular(12),
//                     boxShadow: [
//                       BoxShadow(
//                         color: Colors.black.withOpacity(0.15),
//                         blurRadius: 12,
//                         offset: Offset(0, 4),
//                       ),
//                     ],
//                   ),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Row(
//                         children: [
//                           Icon(
//                             Icons.favorite_border,
//                             color: Colors.grey[600],
//                             size: 20,
//                           ),
//                           SizedBox(width: 8),
//                           Text(
//                             'Sinhgad Rd',
//                             style: TextStyle(
//                               fontSize: 18,
//                               fontWeight: FontWeight.bold,
//                               color: Colors.black87,
//                             ),
//                           ),
//                         ],
//                       ),
//                       SizedBox(height: 4),
//                       Row(
//                         children: [
//                           Icon(
//                             Icons.location_on,
//                             color: Colors.grey[500],
//                             size: 16,
//                           ),
//                           SizedBox(width: 4),
//                           Expanded(
//                             child: Text(
//                               'PR89+H6G, Sinhgad Rd, Kirti Nagar, Vadgaon Budruk, Pune, Maharashtra 411041, India',
//                               style: TextStyle(
//                                 fontSize: 12,
//                                 color: Colors.grey[600],
//                                 height: 1.3,
//                               ),
//                               maxLines: 2,
//                               overflow: TextOverflow.ellipsis,
//                             ),
//                           ),
//                         ],
//                       ),
//                       SizedBox(height: 12),
//                       Row(
//                         children: [
//                           Text(
//                             '2.1 km away',
//                             style: TextStyle(
//                               fontSize: 12,
//                               color: Colors.blue[600],
//                               fontWeight: FontWeight.w500,
//                             ),
//                           ),
//                           Spacer(),
//                           GestureDetector(
//                             onTap: (){
//                               Navigator.pushReplacement(
//                                 context,
//                                 MaterialPageRoute(builder: (context) => Viewgame()),
//                               );
//                             },
//                             child: Container(
//                               padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                               decoration: BoxDecoration(
//                                 color: Color(0xFF1a237e),
//                                 borderRadius: BorderRadius.circular(20),
//                               ),
//                               child: Text(
//                                 'View Games',
//                                 style: TextStyle(
//                                   color: Colors.white,
//                                   fontSize: 12,
//                                   fontWeight: FontWeight.w500,
//                                 ),
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }