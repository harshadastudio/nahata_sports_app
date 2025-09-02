import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nahata_app/dashboard/dashboard_screen.dart';
import 'dart:ui';
import '../services/api_service.dart';
import 'game_selection_screen.dart';

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  final List<String> locations = [ 'Sinhgad Rd'];
  int? tappedIndex;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child   : Scaffold(
        appBar: AppBar(
          backgroundColor: Color(0xFF0A198D),
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => BookPlayScreen(),
                ), // or any other screen
              );
            },
          ),
          title: Text(
            "Locations",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          centerTitle: true,
        ),
        backgroundColor: const Color(0xFFF2F4F7),
        body: SafeArea(
          child: Stack(
            children: [
              // 🔵 Gradient background
              // Container(
              //   decoration: const BoxDecoration(
              //     gradient: LinearGradient(
              //       colors: [Color(0xFF1D2B64), Color(0xFFf8cdda)],
              //       begin: Alignment.topCenter,
              //       end: Alignment.bottomCenter,
              //     ),
              //   ),
              // ),

              // Positioned(
              //   top: 15,
              //   right: 15,
              //   child: GestureDetector(
              //     onTap: () async {
              //       await ApiService.logout();
              //       Navigator.pushNamedAndRemoveUntil(
              //         context,
              //         '/dashboard',
              //             (route) => true,
              //       );
              //     },
              //     child: Container(
              //       padding: const EdgeInsets.all(5),
              //       decoration: BoxDecoration(
              //         color: Colors.white.withOpacity(0.9),
              //         shape: BoxShape.circle,
              //         boxShadow: [
              //           BoxShadow(
              //             color: Colors.black.withOpacity(0.1),
              //             blurRadius: 8,
              //             offset: const Offset(0, 2),
              //           ),
              //         ],
              //       ),
              //       child: Image.asset(
              //         'assets/images/logout1.webp',
              //         width: 30,
              //         height: 30,
              //       ),
              //     ),
              //   ),
              // ),

              // 🧾 Foreground card-style layout
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/nahata_a.webp',
                        width: 120,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Choose Your Location',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0A198D),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Select a venue to continue',
                        style: TextStyle(fontSize: 16, color: Colors.black54),
                      ),
                      const SizedBox(height: 30),

                      // 📍 Location Buttons
                      for (int index = 0; index < locations.length; index++) ...[
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GameSelectionScreen(location: locations[index]),
                              ),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0A198D),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  locations[index],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),



      ),
    );
  }
}



























































































//1600 × 2560