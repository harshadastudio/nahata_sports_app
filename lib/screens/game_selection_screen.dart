import 'package:flutter/material.dart';
import '../services/location_service.dart';
import 'slot_booking_screen.dart';

class GameSelectionScreen extends StatefulWidget {
  final String location;

  const GameSelectionScreen({super.key, required this.location});

  @override
  State<GameSelectionScreen> createState() => _GameSelectionScreenState();
}

class _GameSelectionScreenState extends State<GameSelectionScreen> {
  @override
  Widget build(BuildContext context) {
    final location = widget.location;

    return SafeArea(
      child: Scaffold(
        body: Stack(
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

            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🧾 Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Games at ${widget.location}',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0A198D),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Tap a game to book your slot',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF0A198D),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // 🟡 Game Cards
                  Expanded(
                    child: FutureBuilder<List<Sport>>(
                      future: ApiService.fetchSportsByLocation(widget.location),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: Colors.white));
                        } else if (snapshot.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Text(
                                'Error: ${snapshot.error}',
                                style: const TextStyle(fontSize: 16, color: Colors.white),
                              ),
                            ),
                          );
                        } else if (snapshot.hasData && snapshot.data!.isEmpty) {
                          return const Center(
                            child: Text(
                              'No games available',
                              style: TextStyle(fontSize: 18, color: Colors.white),
                            ),
                          );
                        }

                        final sports = snapshot.data!;
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          itemCount: sports.length,
                          itemBuilder: (context, index) {
                            final sport = sports[index];
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    sport.imageUrl,
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported),
                                  ),
                                ),
                                title: Text(
                                  sport.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0A198D),
                                  ),
                                ),
                                trailing: const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 20,
                                  color: Colors.grey,
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => SlotBookingScreen(
                                        location: widget.location,
                                        game: sport.name,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        );
                      },
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
