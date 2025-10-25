import 'package:flutter/material.dart';
import 'package:nahata_app/bottombar/profile.dart';

import '../auth/login.dart';
import 'BookPlay.dart';
import 'Viewpass.dart';
import 'event.dart';
import 'home.dart';

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
    EventsScreen(),
    Viewpass(),
    Bookplay(),
    SportsScreen()
    // CoachScreen()
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
          BottomNavigationBarItem(icon: Icon(Icons.event), label: 'Events'),
          BottomNavigationBarItem(
              icon: Icon(Icons.grid_view), label: 'View Pass'),
          BottomNavigationBarItem(icon: Icon(Icons.sports), label: 'Book a Play'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_2_outlined), label: 'Coach'),
        ],
      ),
    );
  }}