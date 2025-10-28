// SCREEN 3: MORE SCREEN
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    _getUserData();
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

  Future<void> _getUserData() async {
    final userId = await AuthService.getUserId();
    if (userId == null) return;

    final response = await http.get(
      Uri.parse('https://nahatasports.com/api/$userId/edit'),
    );
print(response);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == true) {
        setState(() {
          _userData = data['data'];
        });
      }
    }
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
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () async {
                          // 🔹 Get current logged-in user's ID from SharedPreferences
                          final userId = await AuthService.getUserId();

                          if (userId == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('User not logged in')),
                            );
                            return;
                          }

                          // 🔹 Navigate to Edit Profile screen with that ID
                          final updated = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EditProfileScreen(userId: int.parse(userId)),
                            ),
                          );

                          // 🔹 Refresh data if user saved updates
                          if (updated == true) {
                            setState(() {
                              _getUserData(); // Replace with your actual reload method
                            });
                          }
                        },
                      ),


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
  int _selectedTabIndex = 0; // 0 = Venue, 1 = Coaching
  int _selectedTimeIndex = 0; // 0 = Upcoming, 1 = Previous
  static const Color brandBlue = Color(0xFF1A237E);

  List<Map<String, dynamic>> allBookings = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> bookingStrings = prefs.getStringList('bookings') ?? [];
    final List<Map<String, dynamic>> loadedBookings = bookingStrings
        .map((b) => jsonDecode(b) as Map<String, dynamic>)
        .toList();

    setState(() => allBookings = loadedBookings);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _getFilteredBookings() {
    final now = DateTime.now();
    final upcoming = <Map<String, dynamic>>[];
    final previous = <Map<String, dynamic>>[];

    for (var booking in allBookings) {
      try {
        final date = DateFormat('yyyy-MM-dd').parse(booking['date']);
        if (date.isBefore(now)) {
          previous.add(booking);
        } else {
          upcoming.add(booking);
        }
      } catch (_) {}
    }

    return _selectedTimeIndex == 0 ? upcoming : previous;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _getFilteredBookings();

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

          // --- Top Tabs (Venue / Coaching)
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

          // --- Upcoming / Previous Toggle
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

          // --- Animated Indicator
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

          // --- Bookings list
          Expanded(
            child: filtered.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final booking = filtered[index];
                return _buildBookingCard(booking);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String title, int index) {
    final isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTabIndex = index),
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
      onTap: () => setState(() => _selectedTimeIndex = index),
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

  Widget _buildEmptyState() {
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

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius:
            const BorderRadius.horizontal(left: Radius.circular(12)),
            child: Image.network(
              booking['imageUrl'] ?? '',
              width: 100,
              height: 100,
              fit: BoxFit.cover,
            ),
          ),
          Expanded(
            child: Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    booking['venueName'] ?? '',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    booking['sport'] ?? '',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${booking['date']} • ${booking['time']}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
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



class EditProfileScreen extends StatefulWidget {
  final int userId;
  const EditProfileScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  String? userId;

  // Controllers
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final dobController = TextEditingController();
  final genderController = TextEditingController();
  final bloodController = TextEditingController();
  final parentController = TextEditingController();
  final passcodeController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  // -------------------
  // ✅ 1. Load user ID from local storage
  Future<void> loadUser() async {
    final id = await AuthService.getUserId();
    setState(() {
      userId = id;
    });

    if (userId != null) {
      await fetchUserData();
    }
  }

  // -------------------
  // ✅ 2. Fetch user details from API
  Future<void> fetchUserData() async {
    setState(() => _loading = true);

    try {
      final response = await http.get(
        Uri.parse('https://nahatasports.com/api/$userId/edit'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print(response.body);
        if (data['status'] == true) {
          final user = data['data'];
          nameController.text = user['name'] ?? '';
          phoneController.text = user['phone'] ?? '';
          emailController.text = user['email'] ?? '';
          dobController.text = user['dob'] ?? '';
          genderController.text = user['gender'] ?? '';
          bloodController.text = user['blood_group'] ?? '';
          parentController.text = user['parent_contact'] ?? '';
          passcodeController.text = user['passcode'] ?? '';
        }
      }

      else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to fetch user info')),
        );
      }
    } catch (e) {
      print('❌ Error fetching user: $e');
    }

    setState(() => _loading = false);
  }

  // -------------------
  // ✅ 3. Update user details (POST)
  Future<void> updateUserData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    final body = {
      "name": nameController.text.trim(),
      "phone": phoneController.text.trim(),
      "email": emailController.text.trim(),
      "password": passwordController.text.trim(),
      "confirmPassword": confirmPasswordController.text.trim(),
      "dob": dobController.text.trim(),
      "gender": genderController.text.trim(),
      "blood_group": bloodController.text.trim(),
      "parent_contact": parentController.text.trim(),
      "passcode": passcodeController.text.trim(),
    };

    try {
      final response = await http.post(
        Uri.parse('https://nahatasports.com/api/$userId/update'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        print(response.body);
        // Optionally update saved user info in SharedPreferences
        SharedPreferences prefs = await SharedPreferences.getInstance();
        Map<String, dynamic>? currentUser = await AuthService.getUser();
        if (currentUser != null) {
          currentUser.addAll(body); // merge updated data
          await prefs.setString('user', jsonEncode(currentUser));
        }

        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Update failed')),
        );
      }
    } catch (e) {
      print("❌ Error updating user: $e");
    }

    setState(() => _loading = false);
  }

  @override
  void initState() {
    super.initState();
    loadUser();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => v!.isEmpty ? 'Enter name' : null,
              ),
              TextFormField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextFormField(
                controller: dobController,
                decoration: const InputDecoration(labelText: 'DOB'),
              ),
              TextFormField(
                controller: genderController,
                decoration: const InputDecoration(labelText: 'Gender'),
              ),
              TextFormField(
                controller: bloodController,
                decoration: const InputDecoration(labelText: 'Blood Group'),
              ),
              TextFormField(
                controller: parentController,
                decoration: const InputDecoration(labelText: 'Parent Contact'),
              ),
              TextFormField(
                controller: passcodeController,
                decoration: const InputDecoration(labelText: 'Passcode'),
              ),
              TextFormField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              TextFormField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm Password'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : updateUserData,
                child: const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
