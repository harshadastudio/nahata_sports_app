// SCREEN 3: MORE SCREEN
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../auth/login.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }
  Future<void> _logout(BuildContext context) async {
    await AuthService.logout();
    // await AuthService.logout(); // clears prefs
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
      );
    }
    // // Navigate to login page after logout
    // Navigator.pushReplacement(
    //     context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  Future<void> _fetchUserData() async {
    setState(() => _isLoading = true);
    try {
      final user = await AuthService.getUser();

      if (user != null) {
        print("✅ Loaded user from local storage: $user");
        setState(() {
          _userData = user;
          _isLoading = false;
        });
      } else {
        print("⚠️ No user found in local storage.");
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print("❌ Error loading user: $e");
      setState(() => _isLoading = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'More',
          style: TextStyle(color: Colors.black),
        ),

      ),
      body: Column(
        children: [
          const SizedBox(height: 24),

          // Profile Card
// Profile Section
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Image + Name
                Column(
                  children: [
                    CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.blue,
                      backgroundImage: _userData?['image'] != null
                          ? NetworkImage(_userData!['image'])
                          : null,
                      child: _userData?['image'] == null
                          ? const Icon(Icons.person, size: 35, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _userData?['name'] ?? 'Guest User',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 24),
                // Edit + Stats
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // IconButton(
                      //   icon: const Icon(Icons.edit, size: 20),
                      //   onPressed: () {
                      //     // Navigate to Edit Profile
                      //   },
                      //   padding: EdgeInsets.zero,
                      //   constraints: const BoxConstraints(),
                      // ),
                      SizedBox(height: 20,),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Column(
                            children: [
                              Text(
                                (_userData?['games'] ?? 0).toString(),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text('Games', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                          const SizedBox(width: 32),
                          Column(
                            children: [
                              Text(
                                (_userData?['coaches'] ?? 0).toString(),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text('Coach', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Menu Items
          Expanded(
            child: ListView(
              children: [
                // _buildMenuItem(Icons.receipt, 'Your Bookings'),
                _buildMenuItem(Icons.receipt, 'Your Bookings', onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MyBookingsScreen(),
                    ),
                  );
                }),
                _buildMenuItem(
                  Icons.event,
                  'My Events',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MyEventsScreen()),
                    );
                  },
                ),
                _buildMenuItem(Icons.qr_code, 'Your Pass', onTap: () {
                  Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const YourPassScreen()),
                  );
                }),

                _buildMenuItem(Icons.favorite_border, 'Favourite Venues', onTap: () {
                  Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const FavouriteVenuesScreen()),
                  );
                }),

                // _buildMenuItem(Icons.help_outline, 'Help and FAQs'),
                // _buildMenuItem(Icons.rate_review_outlined, 'Raise a Request'),
                // _buildMenuItem(Icons.payment, 'Payment & Refund'),
                _buildMenuItem(Icons.article, 'Blogs and Articles', onTap: () async {
                  const url = 'https://nahatasports.com/blogs';
                  if (await canLaunchUrl(Uri.parse(url))) {
                    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                  } else {
                    debugPrint('Could not launch $url');
                  }
                }),

                _buildMenuItem(
                  Icons.description,
                  'Terms and Conditions',
                  onTap: () async {
                    const url = 'https://nahatasports.com/termsandcondition';
                    if (await canLaunchUrl(Uri.parse(url))) {
                      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                    } else {
                      debugPrint('Could not launch $url');
                    }
                  },
                ),
                _buildMenuItem(
                  Icons.privacy_tip_outlined,
                  'Privacy Policy',
                  onTap: () async {
                    const url = 'https://nahatasports.com/privacy';
                    if (await canLaunchUrl(Uri.parse(url))) {
                      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                    } else {
                      debugPrint('Could not launch $url');
                    }
                  },
                ),

                const SizedBox(height: 24),

                // Logout Button
                GestureDetector(
                  onTap: () => _logout(context),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    alignment: Alignment.center,
                    child: const Text(
                      'LOGOUT',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildMenuItem(IconData icon, String title, {VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.grey[700]),
        title: Text(
          title,
          style: const TextStyle(fontSize: 15),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap ?? () {},
      ),
    );
  }
  // Widget _buildMenuItem(IconData icon, String title) {
  //
  //
  //
  //   return Container(
  //     margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
  //     decoration: BoxDecoration(
  //       border: Border(
  //         bottom: BorderSide(color: Colors.grey[200]!),
  //       ),
  //     ),
  //     child: ListTile(
  //       leading: Icon(icon, color: Colors.grey[700]),
  //       title: Text(
  //         title,
  //         style: const TextStyle(fontSize: 15),
  //       ),
  //       trailing: const Icon(Icons.chevron_right, color: Colors.grey),
  //       onTap: () {},
  //     ),
  //   );
  // }
}



class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTabIndex = 0; // 0 for Venue, 1 for Coaching
  int _selectedTimeIndex = 0; // 0 for Upcoming, 1 for Previous

  static const Color brandBlue = Color(0xFF1A237E);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'My Bookings',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),

          // Custom Tab Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: _buildTabButton('Venue Bookings', 0)),
                const SizedBox(width: 12),
                Expanded(child: _buildTabButton('Coaching Bookings', 1)),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Upcoming / Previous Toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTimeToggle('UPCOMING', 0),
                const SizedBox(width: 40),
                _buildTimeToggle('PREVIOUS', 1),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // Animated Underline Indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 100,
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: _selectedTimeIndex == 0
                        ? brandBlue
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 40),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 100,
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: _selectedTimeIndex == 1
                        ? brandBlue
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Content Area
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildTabButton(String title, int index) {
    final isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTabIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? brandBlue : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildTimeToggle(String title, int index) {
    final isSelected = _selectedTimeIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedTimeIndex = index);
      },
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 200),
        style: TextStyle(
          color: isSelected ? brandBlue : Colors.grey,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          fontSize: 15,
          letterSpacing: 0.5,
        ),
        child: Text(title),
      ),
    );
  }

  Widget _buildContent() {
    // Empty state - placeholder
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No ${_selectedTimeIndex == 0 ? 'upcoming' : 'previous'} bookings',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}



class MyEventsScreen extends StatefulWidget {
  const MyEventsScreen({super.key});

  @override
  State<MyEventsScreen> createState() => _MyEventsScreenState();
}

class _MyEventsScreenState extends State<MyEventsScreen> {
  int _selectedTimeIndex = 0; // 0 = Upcoming, 1 = Previous
  static const brandBlue = Color(0xFF1A237E);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'My Events',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 24),

          // Upcoming / Previous Toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTimeToggle('UPCOMING', 0),
                const SizedBox(width: 80),
                _buildTimeToggle('PREVIOUS', 1),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Underline Indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 90,
                  height: 2,
                  color: _selectedTimeIndex == 0 ? brandBlue : Colors.transparent,
                ),
                const SizedBox(width: 80),
                Container(
                  width: 90,
                  height: 2,
                  color: _selectedTimeIndex == 1 ? brandBlue : Colors.transparent,
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // Content (Empty state or Event list)
          Expanded(child: _buildEmptyState()),
        ],
      ),
    );
  }

  Widget _buildTimeToggle(String title, int index) {
    final isSelected = _selectedTimeIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTimeIndex = index;
        });
      },
      child: Text(
        title,
        style: TextStyle(
          color: isSelected ? brandBlue : Colors.grey,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_available_outlined, size: 70, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No ${_selectedTimeIndex == 0 ? 'upcoming' : 'previous'} events',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}



class FavouriteVenuesScreen extends StatelessWidget {
  const FavouriteVenuesScreen({super.key});

  static const brandBlue = Color(0xFF1A237E);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Favourite Venues',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 70, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No favourite venues yet',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class YourPassScreen extends StatefulWidget {
  const YourPassScreen({super.key});

  @override
  State<YourPassScreen> createState() => _YourPassScreenState();
}

class _YourPassScreenState extends State<YourPassScreen> {
  int _selectedTimeIndex = 0; // 0 = Active, 1 = Expired
  static const brandBlue = Color(0xFF1A237E);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Your Pass',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 24),

          // Active / Expired Toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTimeToggle('ACTIVE', 0),
                const SizedBox(width: 80),
                _buildTimeToggle('EXPIRED', 1),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Underline Indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 90,
                  height: 2,
                  color: _selectedTimeIndex == 0 ? brandBlue : Colors.transparent,
                ),
                const SizedBox(width: 80),
                Container(
                  width: 90,
                  height: 2,
                  color: _selectedTimeIndex == 1 ? brandBlue : Colors.transparent,
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // Empty State
          Expanded(
            child: _buildEmptyState(),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeToggle(String title, int index) {
    final isSelected = _selectedTimeIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTimeIndex = index;
        });
      },
      child: Text(
        title,
        style: TextStyle(
          color: isSelected ? brandBlue : Colors.grey,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.qr_code_2_outlined, size: 70, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No ${_selectedTimeIndex == 0 ? 'active' : 'expired'} passes found',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
