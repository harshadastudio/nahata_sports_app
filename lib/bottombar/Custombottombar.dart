import 'package:flutter/material.dart';
import 'package:nahata_app/bottombar/profile.dart';

import '../auth/login.dart';
import 'BookPlay.dart';
import 'Viewpass.dart';
import 'event.dart';
import 'home.dart';
import 'morescreen.dart';

class CustomBottomNav extends StatefulWidget {
  const CustomBottomNav({super.key});

  @override
  State<CustomBottomNav> createState() => _CustomBottomNavState();
}

class _CustomBottomNavState extends State<CustomBottomNav> {
  static const brandBlue = Color(0xFF1A237E);
  int _selectedIndex = 0;
  final List<Widget> _screens = [
    // HomeScreen(studentId: ApiService.currentUser?['student_id']?.toString() ?? '',),
    HomeScreen(),
    VenueListScreen(),
    // Bookplay(),
    SportsScreen(),
    EventsScreen(),
    // Viewpass(),
    MoreScreen()
  ];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
    body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
        type: BottomNavigationBarType.fixed,
        // 👈 Important for equal spacing
        backgroundColor: Colors.white,
        selectedItemColor: brandBlue,
        unselectedItemColor: Colors.grey,
        selectedFontSize: 12,
        // 👈 keep sizes small & consistent
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.book_online), label: 'Book'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_2_outlined), label: 'Coaching'),
          BottomNavigationBarItem(icon: Icon(Icons.event), label: 'Events'),
          BottomNavigationBarItem(
              icon: Icon(Icons.menu), label: 'More'),
        ],
      ),
    );
  }}