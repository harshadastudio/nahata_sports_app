// SCREEN 3: MORE SCREEN
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http_parser/http_parser.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:nahata_app/bottombar/Custombottombar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/login.dart';
import 'home.dart';

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


  Future<void> _deleteAccount(BuildContext context) async {
    final userId = await AuthService.getUserId();
    if (userId == null) return;

    final url = "https://nahatasports.com/api/students/$userId";

    try {
      final response = await http.delete(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data["status"] == true) {
          // Clear user session
          await AuthService.logout();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Account deleted successfully"),
                backgroundColor: Colors.red,
              ),
            );

            // Navigate to Login screen
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
            );
          }
        }
      } else {
        print("❌ Failed to delete user. Status: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Delete Error: $e");
    }
  }
  void _confirmDeleteAccount(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Delete Account"),
          content: const Text(
            "Are you sure you want to permanently delete your account? "
                "This action cannot be undone.",
          ),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: const Text("Delete", style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.pop(context);
                _deleteAccount(context);
              },
            ),
          ],
        );
      },
    );
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
                    // CircleAvatar(
                    //   radius: 35,
                    //   backgroundColor: Colors.blue,
                    //   backgroundImage: _userData?['image'] != null
                    //       ? NetworkImage(_userData!['image'])
                    //       : null,
                    //   child: _userData?['image'] == null
                    //       ? const Icon(Icons.person, size: 35, color: Colors.white)
                    //       : null,
                    // ),
            CircleAvatar(
            radius: 35,
              backgroundColor: Colors.blue,
              child: ClipOval(
                child: Image.network(
                  "https://nahatasports.com/uploads/student_photo/${_userData?['student_photo']}",
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.person, size: 35, color: Colors.white);
                  },
                ),
              ),
            ),

                    const SizedBox(height: 8),
                    Text(
                      _userData?['name'] ?? 'Guest User',
                      style: const TextStyle(
                        fontSize: 15,
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
                            // 🚪 Redirect to LoginScreen if not logged in
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                                  (route) => false,
                            );
                            return;
                          }

                          // 🔹 Navigate to Edit Profile screen with that ID
                          final updated = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                          );

                          // 🔹 Refresh data if user saved updates
                          if (updated == true) {
                            await _getUserData(); // ✅ Make sure _getUserData is async
                            setState(() {}); // refresh UI
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
                // _buildMenuItem(
                //   Icons.event,
                //   'My Events',
                //   onTap: () {
                //     Navigator.push(
                //       context,
                //       MaterialPageRoute(builder: (_) => const MyEventsScreen()),
                //     );
                //   },
                // ),
                _buildMenuItem(Icons.qr_code, 'Your Pass', onTap: () {
                  Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const YourPassScreen()),
                  );
                }),
                _buildMenuItem(Icons.book, 'My Enrollments', onTap: () {
                  Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const Enrollments()),
                  );
                }),
                _buildMenuItem(Icons.feedback_outlined, 'Feedback from Coaches', onTap: () {
                  Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const StudentFeedbackScreen()),
                  );
                }),
                // _buildMenuItem(Icons.favorite_border, 'Favourite Venues', onTap: () {
                //   Navigator.push(context,
                //     MaterialPageRoute(builder: (_) => const FavouriteVenuesScreen()),
                //   );
                // }),

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
                _buildMenuItem(
                  Icons.delete_forever,
                  'Delete Account',

                  onTap: () => _confirmDeleteAccount(context),
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

class Enrollment {
  static const baseUrl = "https://nahatasports.com/api";

  static Future<List<dynamic>> getMyEnrollments(String userId) async {
    final url = Uri.parse("$baseUrl/my-enrollments?user_id=$userId");

    final response = await http.get(url);

    print("STATUS: ${response.statusCode}");
    print("BODY: ${response.body}");

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == true) {
        return data['data'];
      } else {
        return [];
      }
    } else {
      throw Exception("Failed to load enrollments");
    }
  }
}

class Enrollments extends StatefulWidget {
  const Enrollments({super.key});

  @override
  State<Enrollments> createState() => _EnrollmentsState();
}

class _EnrollmentsState extends State<Enrollments> {
  late Future<List<dynamic>> _enrollments;

  @override
  void initState() {
    super.initState();
    loadEnrollments();
  }

  Future<void> loadEnrollments() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user');

    if (userJson == null) {
      print("❌ No user found in SharedPreferences");
      return;
    }

    final user = jsonDecode(userJson);
    final userId = user['id'].toString();

    print("🔵 Loaded user_id = $userId");

    setState(() {
      _enrollments = Enrollment.getMyEnrollments(userId);
    });
  }

  Color _statusColor(String status) {
    switch (status) {
      case "approved":
        return Colors.green;
      case "pending":
        return Colors.orange;
      case "rejected":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Enrollments")),
      body: FutureBuilder<List<dynamic>>(
        future: _enrollments,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.data!.isEmpty) {
            return const Center(child: Text("No enrollments found"));
          }

          final enrollments = snapshot.data!;

          return ListView.builder(
            itemCount: enrollments.length,
            itemBuilder: (context, index) {
              final item = enrollments[index];

              return Card(
                margin: const EdgeInsets.all(10),
                child: ListTile(
                  title: Text(item['sport_name']),
                  subtitle: Text("Coach: ${item['coach_name']}\nPrice: ₹${item['price']}"),
                  trailing: Text(
                    item['status'],
                    style: TextStyle(
                      color: _statusColor(item['status']),
                      fontWeight: FontWeight.bold,
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

    // Default to Upcoming
    _selectedTimeIndex = 0;
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
            'No ${_selectedTimeIndex == 0 ? ''
                'upcoming' : 'previous'} bookings',
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
// edit_profile_screen.dart

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // controllers
  final nameController = TextEditingController();
  final idCardController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final parentController = TextEditingController();
  final dobController = TextEditingController();
  final coachIdController = TextEditingController();
  final statusController = TextEditingController();
  final createdController = TextEditingController();
  final updatedController = TextEditingController();

  String? selectedGender;
  String? selectedBloodGroup;

  File? studentPhotoFile;
  final ImagePicker _picker = ImagePicker();

  String? userId;
  bool isLoading = false;

  // Simple validation regexes
  final _emailReg = RegExp(r'^[^@]+@[^@]+\.[^@]+');
  final _phoneReg = RegExp(r'^\d{10}$');

  @override
  void initState() {
    super.initState();
    _loadUserAndData();
  }

  Future<void> _loadUserAndData() async {
    setState(() => isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final u = prefs.getString('user');
    if (u == null) {
      // No user — navigate back or show error
      setState(() => isLoading = false);
      return;
    }

    final user = jsonDecode(u);
    userId = user['id']?.toString();

    if (userId == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      final res =
      await http.get(Uri.parse("https://nahatasports.com/api/$userId/edit"));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['status'] == true && body['data'] != null) {
          final data = body['data'];

          nameController.text = data['name']?.toString() ?? '';
          idCardController.text = data['id_card']?.toString() ?? '';
          emailController.text = data['email']?.toString() ?? '';
          phoneController.text = data['phone']?.toString() ?? '';
          parentController.text = data['parent_contact']?.toString() ?? '';
          dobController.text = data['dob']?.toString() ?? '';
          selectedGender = data['gender']?.toString();
          selectedBloodGroup = data['blood_group']?.toString();
          coachIdController.text = data['coach_id']?.toString() ?? '';
          statusController.text = data['status']?.toString() ?? '';
          createdController.text = data['created_at']?.toString() ?? '';
          updatedController.text = data['updated_at']?.toString() ?? '';
        } else {
          _showSnack("Failed to load profile");
        }
      } else {
        _showSnack("Server error: ${res.statusCode}");
      }
    } catch (e) {
      _showSnack("Error fetching profile: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _pickStudentPhoto() async {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Choose from gallery'),
            onTap: () async {
              Navigator.pop(context);
              final XFile? f =
              await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
              if (f != null) setState(() => studentPhotoFile = File(f.path));
            },
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Take a photo'),
            onTap: () async {
              Navigator.pop(context);
              final XFile? f =
              await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
              if (f != null) setState(() => studentPhotoFile = File(f.path));
            },
          ),
          ListTile(
            leading: const Icon(Icons.close),
            title: const Text('Cancel'),
            onTap: () => Navigator.pop(context),
          )
        ]),
      ),
    );
  }

  Future<void> _pickDob() async {
    DateTime initial = DateTime.tryParse(dobController.text) ?? DateTime(2005, 1, 1);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      dobController.text = DateFormat('yyyy-MM-dd').format(picked);
      setState(() {});
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (userId == null) {
      _showSnack("User not found");
      return;
    }

    setState(() => isLoading = true);

    try {
      final uri = Uri.parse("https://nahatasports.com/api/$userId/update");
      final request = http.MultipartRequest('POST', uri);

      // Basic fields
      request.fields['name'] = nameController.text.trim();
      request.fields['email'] = emailController.text.trim();
      request.fields['phone'] = phoneController.text.trim();
      request.fields['parent_contact'] = parentController.text.trim();
      request.fields['dob'] = dobController.text.trim();
      request.fields['gender'] = selectedGender ?? '';
      request.fields['blood_group'] = selectedBloodGroup ?? '';
      request.fields['coach_id'] = coachIdController.text.trim();
      request.fields['status'] = statusController.text.trim();

      // passcode required by backend earlier — keep or remove if not needed
      request.fields['passcode'] = '123';

      // Attach image if picked
      if (studentPhotoFile != null) {
        final mime = lookupMime(studentPhotoFile!.path) ?? 'image/jpeg';
        request.files.add(await http.MultipartFile.fromPath(
          'student_photo',
          studentPhotoFile!.path,
          contentType: MediaType.parse(mime),
        ));
      }

      final streamed = await request.send();
      final responseString = await streamed.stream.bytesToString();

      final resJson = jsonDecode(responseString);
      if (resJson['status'] == true && resJson['data'] != null) {
        // Save returned user locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', jsonEncode(resJson['data']));

        _showDialogAndBack("Profile updated successfully");
      } else {
        _showSnack("Update failed: ${resJson['message'] ?? 'Unknown error'}");
      }
    } catch (e) {
      _showSnack("Error updating profile: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  // tiny helper to show snack
  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showDialogAndBack(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        content: Text(message, textAlign: TextAlign.center),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.pop(context); // close dialog
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (context) => const CustomBottomNav()));
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    idCardController.dispose();
    emailController.dispose();
    phoneController.dispose();
    parentController.dispose();
    dobController.dispose();
    coachIdController.dispose();
    statusController.dispose();
    createdController.dispose();
    updatedController.dispose();
    super.dispose();
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FB),
      appBar: AppBar(
        elevation: 0,
        // backgroundColor: const Color(0xFF2E3192),
        title: const Text('Edit Profile'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // header card with avatar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _pickStudentPhoto,
                  child: CircleAvatar(
                    radius: 38,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: studentPhotoFile != null
                        ? FileImage(studentPhotoFile!)
                        : null,
                    child: studentPhotoFile == null
                        ? const Icon(Icons.camera_alt, size: 30, color: Colors.black54)
                        : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nameController.text.isEmpty ? 'Your Name' : nameController.text,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text('ID: ${idCardController.text.isEmpty ? "N/A" : idCardController.text}',
                          style: theme.textTheme.bodySmall),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _pickStudentPhoto,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E3192),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Change Photo',style: TextStyle(color: Colors.white),),
                      )
                    ],
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Form card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
            ),
            child: Form(
              key: _formKey,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Name (read-only)
                _label('Full Name'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: nameController,
                  readOnly: true,
                  decoration: _outlined('Full Name', enabled: false),
                ),
                const SizedBox(height: 12),

                // Email
                _label('Email'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: emailController,
                  decoration: _outlined('Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email required';
                    if (!_emailReg.hasMatch(v.trim())) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Phone
                _label('Phone'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: phoneController,
                  decoration: _outlined('Phone (10 digits)'),
                  keyboardType: TextInputType.phone,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Phone required';
                    if (!_phoneReg.hasMatch(v.trim())) return 'Enter 10 digit phone';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Parent contact
                _label('Parent / Guardian Contact'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: parentController,
                  decoration: _outlined('Parent / Guardian Contact'),
                  keyboardType: TextInputType.phone,
                  validator: (v) {
                    if (v != null && v.isNotEmpty && !_phoneReg.hasMatch(v)) {
                      return 'Enter 10 digit phone';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // DOB
                _label('Date of Birth'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: dobController,
                  readOnly: true,
                  onTap: _pickDob,
                  decoration: _outlined('YYYY-MM-DD', suffix: Icons.calendar_today),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'DOB required';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Gender & Blood group row
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _label('Gender'),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: selectedGender,
                        decoration: _outlined('Gender'),
                        items: ['Male', 'Female', 'Other']
                            .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                            .toList(),
                        onChanged: (v) => setState(() => selectedGender = v),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Select gender';
                          return null;
                        },
                      )
                    ]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _label('Blood Group'),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: selectedBloodGroup,
                        decoration: _outlined('Blood Group'),
                        items: ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-']
                            .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                            .toList(),
                        onChanged: (v) => setState(() => selectedBloodGroup = v),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Select blood group';
                          return null;
                        },
                      ),
                    ]),
                  )
                ]),
                // const SizedBox(height: 12),
                //
                // // Coach id & status row
                // Row(children: [
                //   Expanded(
                //     child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                //       _label('Coach ID'),
                //       const SizedBox(height: 6),
                //       TextFormField(
                //         controller: coachIdController,
                //         decoration: _outlined('Coach ID (optional)'),
                //       ),
                //     ]),
                //   ),
                //   const SizedBox(width: 12),
                //   Expanded(
                //     child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                //       _label('Status'),
                //       const SizedBox(height: 6),
                //       TextFormField(
                //         controller: statusController,
                //         decoration: _outlined('Status (0/1)'),
                //       ),
                //     ]),
                //   )
                // ]),
                // const SizedBox(height: 16),
                //
                // // Created & Updated (read only)
                // _label('Created At'),
                // const SizedBox(height: 6),
                // TextFormField(controller: createdController, readOnly: true, decoration: _outlined('Created At', enabled: false)),
                // const SizedBox(height: 12),
                // _label('Updated At'),
                // const SizedBox(height: 6),
                // TextFormField(controller: updatedController, readOnly: true, decoration: _outlined('Updated At', enabled: false)),
                 const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E3192),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Save Changes', style: TextStyle(fontSize: 16,color: Colors.white)),
                  ),
                )
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  // Small UI helpers
  Widget _label(String t) => Text(t, style: const TextStyle(fontWeight: FontWeight.w600));
  InputDecoration _outlined(String hint, {bool enabled = true, IconData? suffix}) => InputDecoration(
    hintText: hint,
    enabled: enabled,
    filled: true,
    fillColor: enabled ? Colors.white : Colors.grey.shade100,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    suffixIcon: suffix != null ? Icon(suffix) : null,
  );

  // MIME detection helper (very small fallback)
  String? lookupMime(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    return null;
  }
}


//
// class EditProfileScreen extends StatefulWidget {
//   final int userId;
//
//   const EditProfileScreen({Key? key, required this.userId}) : super(key: key);
//
//   @override
//   State<EditProfileScreen> createState() => _EditProfileScreenState();
// }
//
// class _EditProfileScreenState extends State<EditProfileScreen> {
//   final _formKey = GlobalKey<FormState>();
//   bool _loading = false;
//
//   late int userId;
//
//   // Controllers
//   final nameController = TextEditingController();
//   final phoneController = TextEditingController();
//   final emailController = TextEditingController();
//   final dobController = TextEditingController();
//   final genderController = TextEditingController();
//   final bloodController = TextEditingController();
//   final parentController = TextEditingController();
//   final passcodeController = TextEditingController();
//   final passwordController = TextEditingController();
//   final confirmPasswordController = TextEditingController();
//
//   static const String baseUrl = 'https://nahatasports.com/api';
//
//   @override
//   void initState() {
//     super.initState();
//     userId = widget.userId;
//     fetchUserData();
//   }
//
//   // -------------------
//   // ✅ Fetch user details from API
//   Future<void> fetchUserData() async {
//     setState(() => _loading = true);
//
//     try {
//       final response = await http.get(Uri.parse('$baseUrl/$userId/edit'));
//
//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         print('📥 User Data: ${response.body}');
//
//         if (data['status'] == true && data['data'] != null) {
//           final user = data['data'];
//           nameController.text = user['name'] ?? '';
//           phoneController.text = user['phone'] ?? '';
//           emailController.text = user['email'] ?? '';
//           dobController.text = user['dob'] ?? '';
//           genderController.text = user['gender'] ?? '';
//           bloodController.text = user['blood_group'] ?? '';
//           parentController.text = user['parent_contact'] ?? '';
//           passcodeController.text = user['passcode'] ?? '';
//         } else {
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(content: Text('Failed to load user data')),
//           );
//         }
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Error: ${response.reasonPhrase}')),
//         );
//       }
//     } catch (e) {
//       print('❌ Error fetching user: $e');
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Something went wrong')),
//       );
//     }
//
//     setState(() => _loading = false);
//   }
//
//   // -------------------
//   // ✅ Update user details (POST)
//   Future<void> updateUserData() async {
//     if (!_formKey.currentState!.validate()) return;
//
//     setState(() => _loading = true);
//
//     final body = {
//       "name": nameController.text.trim(),
//       "phone": phoneController.text.trim(),
//       "email": emailController.text.trim(),
//       "dob": dobController.text.trim(),
//       "gender": genderController.text.trim(),
//       "blood_group": bloodController.text.trim(),
//       "parent_contact": parentController.text.trim(),
//       "passcode": passcodeController.text.trim(),
//     };
//
//     // Only include password fields if user filled them
//     if (passwordController.text.isNotEmpty &&
//         confirmPasswordController.text.isNotEmpty) {
//       body["password"] = passwordController.text.trim();
//       body["confirmPassword"] = confirmPasswordController.text.trim();
//     }
//
//     try {
//       final response = await http.post(
//         Uri.parse('$baseUrl/$userId/update'),
//         headers: {"Content-Type": "application/json"},
//         body: jsonEncode(body),
//       );
//
//       final data = jsonDecode(response.body);
//       print('📤 Update Response: ${response.body}');
//
//       if (response.statusCode == 200 && data['status'] == true) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Profile updated successfully!')),
//         );
//
//         // Optionally update local user data
//         SharedPreferences prefs = await SharedPreferences.getInstance();
//         Map<String, dynamic>? currentUser = await AuthService.getUser();
//         if (currentUser != null) {
//           currentUser.addAll(body);
//           await prefs.setString('user', jsonEncode(currentUser));
//         }
//
//         Navigator.pop(context);
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text(data['message'] ?? 'Update failed')),
//         );
//       }
//     } catch (e) {
//       print("❌ Error updating user: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Something went wrong')),
//       );
//     }
//
//     setState(() => _loading = false);
//   }
//
//   @override
//   void dispose() {
//     nameController.dispose();
//     phoneController.dispose();
//     emailController.dispose();
//     dobController.dispose();
//     genderController.dispose();
//     bloodController.dispose();
//     parentController.dispose();
//     passcodeController.dispose();
//     passwordController.dispose();
//     confirmPasswordController.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Edit Profile')),
//       body: Stack(
//         children: [
//           SingleChildScrollView(
//             padding: const EdgeInsets.all(16),
//             child: Form(
//               key: _formKey,
//               child: Column(
//                 children: [
//                   TextFormField(
//                     controller: nameController,
//                     decoration: const InputDecoration(labelText: 'Name'),
//                     validator: (v) => v!.isEmpty ? 'Enter name' : null,
//                   ),
//                   TextFormField(
//                     controller: phoneController,
//                     decoration: const InputDecoration(labelText: 'Phone'),
//                   ),
//                   TextFormField(
//                     controller: emailController,
//                     decoration: const InputDecoration(labelText: 'Email'),
//                   ),
//                   TextFormField(
//                     controller: dobController,
//                     decoration: const InputDecoration(labelText: 'Date of Birth'),
//                   ),
//                   TextFormField(
//                     controller: genderController,
//                     decoration: const InputDecoration(labelText: 'Gender'),
//                   ),
//                   TextFormField(
//                     controller: bloodController,
//                     decoration: const InputDecoration(labelText: 'Blood Group'),
//                   ),
//                   TextFormField(
//                     controller: parentController,
//                     decoration:
//                     const InputDecoration(labelText: 'Parent Contact'),
//                   ),
//                   TextFormField(
//                     controller: passcodeController,
//                     decoration: const InputDecoration(labelText: 'Passcode'),
//                   ),
//                   const SizedBox(height: 10),
//                   const Divider(),
//                   const Text(
//                     "Change Password (optional)",
//                     style:
//                     TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
//                   ),
//                   TextFormField(
//                     controller: passwordController,
//                     obscureText: true,
//                     decoration: const InputDecoration(labelText: 'Password'),
//                   ),
//                   TextFormField(
//                     controller: confirmPasswordController,
//                     obscureText: true,
//                     decoration:
//                     const InputDecoration(labelText: 'Confirm Password'),
//                   ),
//                   const SizedBox(height: 20),
//                   ElevatedButton(
//                     onPressed: _loading ? null : updateUserData,
//                     child: _loading
//                         ? const SizedBox(
//                       height: 20,
//                       width: 20,
//                       child: CircularProgressIndicator(strokeWidth: 2),
//                     )
//                         : const Text('Save Changes'),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }



class StudentFeedbackScreen extends StatefulWidget {
  const StudentFeedbackScreen({super.key});

  @override
  State<StudentFeedbackScreen> createState() => _StudentFeedbackScreenState();
}

class _StudentFeedbackScreenState extends State<StudentFeedbackScreen> {
  bool isLoading = true;
  List<dynamic> feedbackList = [];
  int? studentId;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadStudentId();
    if (studentId != null) {
      await fetchFeedback();
    } else {
      print("⚠️ No student ID found, cannot fetch feedback");
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadStudentId() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user');

    if (userJson != null) {
      final userData = jsonDecode(userJson);
      final rawId = userData['student_id'] ?? userData['id'];
      setState(() {
        studentId = (rawId is String) ? int.tryParse(rawId) : rawId as int?;
      });
      print("🎓 Loaded student ID: $studentId");
    } else {
      print("⚠️ No user data found in SharedPreferences");
    }
  }

  Future<void> fetchFeedback() async {
    final url = Uri.parse('https://nahatasports.com/api/student/details/$studentId');
    print("📡 Fetching feedback from: $url");

    try {
      final response = await http.get(url);
      print("📩 Response: ${response.statusCode}");
      print("📦 Body: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == true && data['feedbacks'] != null) {
          setState(() {
            feedbackList = data['feedbacks']; // <-- List directly
            isLoading = false;
          });

          print("✅ Feedback entries loaded: ${feedbackList.length}");
        } else {
          print("⚠️ No feedback data available");
          setState(() => isLoading = false);
        }
      } else {
        print("❌ Server error: ${response.statusCode}");
        setState(() => isLoading = false);
      }
    } catch (e) {
      print("❌ Exception fetching feedback: $e");
      setState(() => isLoading = false);
    }
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

          'Feedback from Coaches',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : feedbackList.isEmpty
          ? const Center(
        child: Text(
          "No feedback available yet",
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: feedbackList.length,
        itemBuilder: (context, index) {
          final feedback = feedbackList[index];
          final coachName = feedback['coach_name'] ?? 'Coach';
          final message = feedback['feedback'] ?? 'No message';
          final date = feedback['created_at'] ?? '';

          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Color(0xFF0A198D),
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          coachName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    style: const TextStyle(fontSize: 15, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    date,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
