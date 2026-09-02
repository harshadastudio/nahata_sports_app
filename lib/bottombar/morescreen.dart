// SCREEN 3: MORE SCREEN
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http_parser/http_parser.dart';
import 'package:nahata_app/core/network/http_logged.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:nahata_app/bottombar/Custombottombar.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:provider/provider.dart';

import '../auth/login.dart';
import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../core/utils/app_logger.dart';
import 'account_screens.dart';
import '../models/court_booking_model.dart';
import '../models/enrollment_model.dart';
import '../models/profile_model.dart';
import '../models/student_profile_model.dart';
import '../providers/profile_provider.dart';
import '../repositories/auth_repository.dart';
import '../repositories/court_booking_repository.dart';
import '../repositories/event_booking_repository.dart';
import '../repositories/user_repository.dart';
import 'home.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String? _profileImageVersion;

  /// Live profile from `/auth/profile`, shared with Home and the dashboard.
  ProfileModel? _profile;
  ProfileProvider? _profileProvider;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _getUserData();
    fetchDashboard();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_profileProvider != null) return;

    final provider = context.read<ProfileProvider>();
    _profileProvider = provider;
    provider.addListener(_onProfileChanged);
    _onProfileChanged();
  }

  void _onProfileChanged() {
    final provider = _profileProvider;
    if (provider == null || !mounted) return;
    if (provider.profile == _profile) return;
    setState(() => _profile = provider.profile);
  }

  @override
  void dispose() {
    _profileProvider?.removeListener(_onProfileChanged);
    super.dispose();
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final userId = await AuthService.getUserId();
    if (userId == null) return;

    try {
      final deleted = await UserRepository.instance.deleteAccount(userId);
      if (!deleted) {
        if (mounted)
          _showError("Could not delete your account. Please try again.");
        return;
      }

      // Clear the session locally too.
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
    } on ApiException catch (e) {
      if (mounted) _showError(e.message);
    } catch (e) {
      debugPrint("Delete Error: $e");
      if (mounted) _showError("Something went wrong. Please try again.");
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
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
    // De-registers push, then clears tokens, cached profile and permissions
    // and notifies every screen listening to the profile.
    await AuthService.logout();
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

  /// Detail record from the legacy `/{id}/edit` endpoint (dob, gender, …).
  Future<void> _getUserData() async {
    final userId = await AuthService.getUserId();
    if (userId == null) return;

    try {
      final data = await UserRepository.instance.fetchUserDetails(userId);
      if (!mounted || data == null) return;
      setState(() => _userData = data);
    } on ApiException catch (e) {
      debugPrint('_getUserData failed: ${e.message}');
    }
  }

  /// Cached profile first (instant), then `/auth/profile` in the background.
  Future<void> _fetchUserData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final provider = _profileProvider ?? context.read<ProfileProvider>();
      await provider.loadFromCache();

      if (mounted) {
        setState(() {
          _profile = provider.profile;
          _userData = provider.profile?.toLegacyUserMap();
          _isLoading = false;
        });
      }

      await provider.refresh();
      if (mounted) {
        setState(() {
          _profile = provider.profile;
          _userData = provider.profile?.toLegacyUserMap() ?? _userData;
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic>? _student;
  Map<String, dynamic>? _pass;
  Uint8List _getQrImageBytes(String base64String) {
    final cleanedBase64 = base64String.split(',').last;
    return base64Decode(cleanedBase64);
  }

  /// Name from the live profile, falling back to the student record while the
  /// profile call is still in flight. Never null.
  String get _displayName {
    final fromProfile = _profile?.name;
    if (fromProfile != null && fromProfile.isNotEmpty) return fromProfile;
    return _student?['name']?.toString() ?? '';
  }

  String get _displayEmail {
    final fromProfile = _profile?.email;
    if (fromProfile != null && fromProfile.isNotEmpty) return fromProfile;
    return _student?['email']?.toString() ?? '';
  }

  String? get profileImageUrl {
    // 1️⃣ Live profile picture / avatar from /auth/profile
    final fromProfile = _profile?.imageUrl;
    if (fromProfile != null && fromProfile.isNotEmpty) return fromProfile;

    // 2️⃣ Photo stored on the cached user record
    final photo = _userData?['photo'];
    if (photo != null && photo.toString().isNotEmpty) {
      return photo.toString();
    }

    // 3️⃣ Student photo from the dashboard API
    return _dashboard?.photoUrl(version: _profileImageVersion);
  }

  StudentDashboard? _dashboard;

  /// `GET /student_dashboard` — student record + entry pass.
  Future<void> fetchDashboard() async {
    final studentId = await AuthService.getUserId();

    if (studentId == null) {
      debugPrint("Student ID is null");
      return;
    }

    try {
      final dashboard = await UserRepository.instance.fetchDashboard(studentId);
      if (!mounted) return;

      setState(() {
        _dashboard = dashboard;
        _student = dashboard.student;
        _pass = dashboard.pass;
        // Cache-buster so a freshly uploaded photo shows immediately.
        _profileImageVersion = DateTime.now().millisecondsSinceEpoch.toString();
      });
    } on ApiException catch (e) {
      debugPrint('fetchDashboard failed: ${e.message}');
    }
  }

  bool _isPassValid(Map<String, dynamic> pass) {
    if (pass['status'] != 'active') return false;

    final validUntil = DateTime.tryParse(pass['valid_until'] ?? '');
    if (validUntil == null) return false;

    return validUntil.isAfter(DateTime.now());
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
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            /// PROFILE CARD
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : (_profile == null && _student == null)
                  ? _buildProfileShimmer()
                  : Column(
                      children: [
                        /// HEADER
                        Row(
                          children: [
                            /// AVATAR
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 40,
                                backgroundColor: Colors.grey.shade200,
                                child: ClipOval(
                                  child: profileImageUrl == null
                                      ? Icon(
                                          Icons.person,
                                          size: 40,
                                          color: Colors.blue.shade600,
                                        )
                                      : Image.network(
                                          profileImageUrl!,
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Icon(
                                            Icons.person,
                                            size: 40,
                                            color: Colors.blue.shade600,
                                          ),
                                        ),
                                ),
                              ),

                              // child: CircleAvatar(
                              //   radius: 40,
                              //   backgroundColor: Colors.white,
                              //   // backgroundImage:
                              //   // _student!['student_photo'] != null &&
                              //   //     _student!['student_photo']
                              //   //         .toString()
                              //   //         .isNotEmpty
                              //   //     ? NetworkImage(
                              //   //     "https://nahatasports.com/public/uploads/students/${_student!['student_photo']}?v=${DateTime.now().millisecondsSinceEpoch}",
                              //   //
                              //   //   // "https://nahatasports.com/public/uploads/students/${_student!['student_photo']}",
                              //   // )
                              //   //     : null,
                              //   backgroundImage: _student!['student_photo'] != null &&
                              //       _student!['student_photo'].toString().isNotEmpty
                              //       ? NetworkImage(
                              //     "https://nahatasports.com/public/uploads/students/"
                              //         "${_student!['student_photo']}?v=$_profileImageVersion",
                              //   )
                              //       : null,
                              //
                              //   child: _student!['student_photo'] == null ||
                              //       _student!['student_photo']
                              //           .toString()
                              //           .isEmpty
                              //       ? Icon(Icons.person,
                              //       color: Colors.blue.shade600, size: 40)
                              //       : null,
                              // ),
                            ),

                            const SizedBox(width: 16),

                            /// NAME & EMAIL
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _displayName,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.email_outlined,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          _displayEmail,
                                          style: const TextStyle(fontSize: 13),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            /// EDIT
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () async {
                                final updated = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const EditProfileScreen(),
                                  ),
                                );
                                if (updated == true) {
                                  // Global sync: refreshes Home, More, Profile and
                                  // the dashboard from one /auth/profile call.
                                  await context
                                      .read<ProfileProvider>()
                                      .profileUpdated();
                                  await fetchDashboard(); // refresh student + photo
                                  await _getUserData(); // refresh user data if needed
                                  if (mounted) setState(() {});
                                }
                              },
                            ),
                          ],
                        ),

                        /// QR SECTION
                        if (_pass != null &&
                            _pass!['qr_code'] != null &&
                            _pass!['qr_code'].toString().isNotEmpty &&
                            _isPassValid(_pass!))
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Image.memory(
                                    _getQrImageBytes(_pass!['qr_code']),
                                    width: 80,
                                    height: 80,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.green.shade200,
                                    ),
                                  ),
                                  child: Text(
                                    'Valid until ${DateFormat('dd-MM-yyyy').format(DateTime.parse(_pass!['valid_until']))}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),

            const SizedBox(height: 16),

            /// MENU ITEMS (NO ListView, just Column)
            _buildMenuItem(
              Icons.receipt,
              'Your Bookings',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyBookingsScreen()),
                );
              },
            ),
            _buildMenuItem(
              Icons.qr_code,
              'Your Pass',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const YourPassScreen()),
                );
              },
            ),
            _buildMenuItem(
              Icons.school_outlined,
              'My Enrollments',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MyEnrollmentsScreen(),
                  ),
                );
              },
            ),
            _buildMenuItem(
              Icons.help_outline,
              'My Enquiries',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyEnquiriesScreen()),
                );
              },
            ),
            _buildMenuItem(
              Icons.forum_outlined,
              'Feedback',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FeedbackScreen()),
                );
              },
            ),
            _buildMenuItem(
              Icons.lock_outline,
              'Change Password',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ChangePasswordScreen(),
                  ),
                );
              },
            ),
            _buildMenuItem(
              Icons.article,
              'Blogs and Articles',
              onTap: () async {
                const url = 'https://nahatasports.com/blogs';
                if (await canLaunchUrl(Uri.parse(url))) {
                  await launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  );
                }
              },
            ),
            _buildMenuItem(
              Icons.description,
              'Terms and Conditions',
              onTap: () async {
                const url = 'https://nahatasports.com/terms-and-conditions';
                if (await canLaunchUrl(Uri.parse(url))) {
                  await launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  );
                }
              },
            ),
            _buildMenuItem(
              Icons.privacy_tip_outlined,
              'Privacy Policy',
              onTap: () async {
                const url = 'https://nahatasports.com/privacy-policy';
                if (await canLaunchUrl(Uri.parse(url))) {
                  await launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  );
                }
              },
            ),
            _buildMenuItem(
              Icons.delete_forever,
              'Delete Account',
              onTap: () => _confirmDeleteAccount(context),
            ),

            const SizedBox(height: 24),

            /// LOGOUT
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
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // const SizedBox(height: 24),

  // Profile Card
  // Profile Section
  //           Container(
  //             margin: const EdgeInsets.symmetric(horizontal: 16),
  //             padding: const EdgeInsets.all(16),
  //             decoration: BoxDecoration(
  //               color: Colors.white,
  //               borderRadius: BorderRadius.circular(12),
  //               boxShadow: [
  //                 BoxShadow(
  //                   color: Colors.grey.withOpacity(0.2),
  //                   blurRadius: 8,
  //                   offset: const Offset(0, 2),
  //                 ),
  //               ],
  //             ),
  //             child: _isLoading
  //                 ? const Center(child: CircularProgressIndicator())
  //                 : Row(
  //               crossAxisAlignment: CrossAxisAlignment.start,
  //               children: [
  //                 // Profile Image + Name
  //                 Column(
  //                   children: [
  //
  //             _student == null
  //             ?  _buildProfileShimmer()
  //                 : Column(
  //           children: [
  //           CircleAvatar(
  //           radius: 35,
  //             backgroundColor: Colors.blue,
  //             backgroundImage: _student!['student_photo'] != null &&
  //                 _student!['student_photo'].toString().isNotEmpty
  //                 ? NetworkImage(
  //               "https://nahatasports.com/public/uploads/students/${_student!['student_photo']}",
  //             )
  //                 : null,
  //             child: _student!['student_photo'] == null ||
  //                 _student!['student_photo'].toString().isEmpty
  //                 ? const Icon(Icons.person, color: Colors.white)
  //                 : null,
  //           ),
  //
  //           const SizedBox(height: 8),
  //
  //           Text(
  //             _student!['name'] ?? '',
  //             style: const TextStyle(
  //               fontSize: 15,
  //               fontWeight: FontWeight.bold,
  //             ),
  //           ),
  //         ],
  //       )
  //
  //                   ],
  //                 ),
  //                 const SizedBox(width: 24),
  //                 // Edit + Stats
  //                 Expanded(
  //                   child: Column(
  //                     crossAxisAlignment: CrossAxisAlignment.end,
  //                     children: [
  //
  //                       IconButton(
  //                         icon: const Icon(Icons.edit, size: 20),
  //                         onPressed: () async {
  //                           // 🔹 Get current logged-in user's ID from SharedPreferences
  //                           final userId = await AuthService.getUserId();
  //
  //                           if (userId == null) {
  //                             // 🚪 Redirect to LoginScreen if not logged in
  //                             Navigator.pushAndRemoveUntil(
  //                               context,
  //                               MaterialPageRoute(builder: (_) => const LoginScreen()),
  //                                   (route) => false,
  //                             );
  //                             return;
  //                           }
  //
  //                           // 🔹 Navigate to Edit Profile screen with that ID
  //                           final updated = await Navigator.push(
  //                             context,
  //                             MaterialPageRoute(builder: (_) => const EditProfileScreen()),
  //                           );
  //
  //                           // 🔹 Refresh data if user saved updates
  //                           if (updated == true) {
  //                             await _getUserData(); // ✅ Make sure _getUserData is async
  //                             setState(() {}); // refresh UI
  //                           }
  //                         },
  //                       ),
  //
  //
  //
  //                       SizedBox(height: 20,),
  //
  //                     ],
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ),
  Widget _buildMenuItem(IconData icon, String title, {VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.grey[700]),
        title: Text(title, style: const TextStyle(fontSize: 15)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap ?? () {},
      ),
    );
  }
}

Widget _buildProfileShimmer() {
  return Column(
    children: [
      Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: CircleAvatar(radius: 35, backgroundColor: Colors.white),
      ),

      const SizedBox(height: 8),

      Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Container(width: 100, height: 15, color: Colors.white),
      ),
    ],
  );
}

/// `GET /students/me/enrollments` — the signed-in student's batches.
///
/// The old version called `nahatasports.com/api/my-enrollments?user_id=` with
/// no token, identifying the student by a number in the query string, and read
/// `sport_name`/`coach_name`/`price` — none of which the current endpoint
/// returns. It now goes through [UserRepository], which sends the bearer token
/// and parses the documented camelCase payload.
class Enrollments extends StatefulWidget {
  const Enrollments({super.key});

  @override
  State<Enrollments> createState() => _EnrollmentsState();
}

class _EnrollmentsState extends State<Enrollments> {
  List<EnrollmentModel> _enrollments = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final rows = await UserRepository.instance.fetchMyEnrollments();
      if (!mounted) return;
      setState(() {
        _enrollments = rows;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      AppLogger.error('My enrollments failed', name: 'Profile', error: e);
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load your enrollments. Please try again.';
        _loading = false;
      });
    }
  }

  Color _statusColor(EnrollmentModel item) {
    if (item.isApproved) return Colors.green;
    if (item.isPending) return Colors.orange;
    final status = (item.approvalStatus ?? item.status ?? '').toLowerCase();
    if (status == 'rejected') return Colors.red;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Enrollments")),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 44, color: Colors.black26),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: const Text("Try again")),
            ],
          ),
        ),
      );
    }

    if (_enrollments.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: const [
            SizedBox(height: 160),
            Center(child: Text("No enrollments found")),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        itemCount: _enrollments.length,
        itemBuilder: (context, index) {
          final item = _enrollments[index];

          // Every field is optional on this endpoint, so each line is dropped
          // rather than rendered as "null".
          final subtitle = [
            if (item.batchName != null) 'Batch: ${item.batchName}',
            if (item.coachName != null) 'Coach: ${item.coachName}',
            if (item.complexName != null) 'Venue: ${item.complexName}',
            if (item.validTill != null) 'Valid till: ${item.validTill}',
          ].join('\n');

          return Card(
            margin: const EdgeInsets.all(10),
            child: ListTile(
              isThreeLine: subtitle.contains('\n'),
              title: Text(item.sportName ?? item.batchName ?? 'Enrollment'),
              subtitle: subtitle.isEmpty ? null : Text(subtitle),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    item.approvalStatus ?? item.status ?? '—',
                    style: TextStyle(
                      color: _statusColor(item),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (item.paymentStatus != null)
                    Text(
                      item.paymentStatus!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                      ),
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
  final ScrollController _scrollController = ScrollController();

  static const int _pageSize = 10;
  int _currentPage = 1;

  List<Map<String, dynamic>> _visibleBookings = [];
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _scrollController.addListener(_onScroll);
    // Default to Upcoming
    _selectedTimeIndex = 0;
    _loadBookings();
  }

  /// `GET /courts/bookings/my` returns every booking in one list, so the
  /// Upcoming / Previous split is done here: a slot counts as upcoming until
  /// its **end time** passes, so a court booked for later today stays under
  /// Upcoming and one that finished this morning drops to Previous.
  ///
  /// Upcoming is sorted soonest-first, Previous most-recent-first.
  ///
  /// Old API (commented out below): `POST court-bookings` with the user's
  /// email, which split the two lists server-side.
  Future<void> _loadBookings() async {
    try {
      final bookings = await CourtBookingRepository.instance.fetchMyBookings();

      final sorted = _selectedTimeIndex == 0
          ? CourtBooking.upcomingFrom(bookings)
          : CourtBooking.previousFrom(bookings);

      final fetchedBookings = sorted.map((b) => b.toBookingMap()).toList();

      AppLogger.debug(
        '${_selectedTimeIndex == 0 ? 'Upcoming' : 'Previous'} bookings: '
        '${fetchedBookings.length} of ${bookings.length}',
        name: 'MyBookings',
      );

      if (!mounted) return;
      setState(() {
        allBookings = fetchedBookings;
        _currentPage = 1;
        _visibleBookings = allBookings.take(_pageSize).toList();
        _isLoadingMore = false;
      });
    } catch (e) {
      AppLogger.error('Could not load bookings', name: 'MyBookings', error: e);
      if (!mounted) return;
      setState(() {
        allBookings = [];
        _visibleBookings = [];
        _isLoadingMore = false;
      });
    }
  }

  // ---------------------- OLD API (commented out) ----------------------
  // Future<void> _loadBookings() async {
  //   final email = await AuthService.getUserEmail();
  //   if (email == null) return;
  //
  //   final response = await http.post(
  //     Uri.parse("https://nahatasports.com/api/court-bookings"),
  //     headers: {"Content-Type": "application/json"},
  //     body: jsonEncode({"email": email}),
  //   );
  //
  //   final jsonData = jsonDecode(response.body);
  //   final data = jsonData['data'];
  //
  //   List<Map<String, dynamic>> fetchedBookings = [];
  //
  //   if (_selectedTimeIndex == 0) {
  //     fetchedBookings =
  //     List<Map<String, dynamic>>.from(data['upcoming_bookings'] ?? []);
  //   } else {
  //     fetchedBookings =
  //     List<Map<String, dynamic>>.from(data['previous_bookings'] ?? []);
  //   }
  //
  //   setState(() {
  //     allBookings = fetchedBookings;
  //     _currentPage = 1;
  //     _visibleBookings = allBookings.take(_pageSize).toList();
  //     _isLoadingMore = false;
  //   });
  // }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 100 &&
        !_isLoadingMore) {
      _loadMore();
    }
  }

  void _loadMore() {
    if (_visibleBookings.length >= allBookings.length) return;

    setState(() => _isLoadingMore = true);

    Future.delayed(const Duration(milliseconds: 300), () {
      final nextItems = allBookings
          .skip(_visibleBookings.length)
          .take(_pageSize);

      setState(() {
        _visibleBookings.addAll(nextItems);
        _isLoadingMore = false;
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();

    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _visibleBookings;

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
            child: RefreshIndicator(
              onRefresh: _loadBookings,
              child: filtered.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filtered.length + (_isLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == filtered.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        final booking = filtered[index];
                        return _buildBookingCard(booking);
                      },
                    ),
            ),
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
        _loadBookings(); // reload API
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
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ],
      ),
    );
  }

  void _showQrDialog(Map<String, dynamic> booking) {
    final String qrUrl = booking['qr_code'];
    final String court = booking['court_name'] ?? '';
    final String date = booking['selected_date'] ?? '';
    final String amount = booking['amount'] ?? '';

    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Booking QR Code",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 12),

                Text(
                  court,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(date),
                Text("₹ $amount"),

                const SizedBox(height: 16),

                Image.network(
                  qrUrl,
                  height: 220,
                  width: 220,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Text("Failed to load QR"),
                ),

                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => _shareQrImage(
                        qrUrl,
                        court: court,
                        date: date,
                        amount: amount,
                      ),
                      child: const Text("SHARE"),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("CLOSE"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _shareQrImage(
    String qrUrl, {
    required String court,
    required String date,
    required String amount,
  }) async {
    final response = await http.get(Uri.parse(qrUrl));

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/booking_qr.png');

    await file.writeAsBytes(response.bodyBytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      text:
          '''
Booking Details
Court: $court
Date: $date
Amount: ₹$amount
''',
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    List<dynamic> slots = [];
    final String? qrCodeUrl = booking['qr_code'];

    /// 🔹 SAFELY PARSE SLOTS (string / list / map)

    final rawSlots = booking['slots'];

    if (rawSlots == null) {
      slots = [];
    } else if (rawSlots is List) {
      slots = rawSlots;
    } else if (rawSlots is Map) {
      slots = [rawSlots];
    } else if (rawSlots is String && rawSlots.isNotEmpty) {
      try {
        final safeJson = rawSlots
            .replaceAll('–', '-') // en dash
            .replaceAll('—', '-'); // em dash

        final decoded = jsonDecode(safeJson);

        if (decoded is List) {
          slots = decoded;
        } else if (decoded is Map) {
          slots = [decoded];
        }
      } catch (e) {
        debugPrint('Slot parse error: $e');
        slots = [];
      }
    }
    String slotTime = '';

    if (slots.isNotEmpty) {
      final slot = slots.first;

      if (slot is Map && slot['time'] != null) {
        slotTime = slot['time'].toString();
      } else if (slot is String) {
        slotTime = slot;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// COURT NAME
          Text(
            booking['court_name']?.toString() ?? '',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 6),

          /// DATE
          Text(
            booking['selected_date']?.toString() ?? '',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 6),

          /// SLOT TIME (ONLY IF AVAILABLE)
          if (slotTime.isNotEmpty)
            Text(slotTime, style: TextStyle(color: Colors.grey.shade700)),

          const SizedBox(height: 8),

          /// AMOUNT
          Text(
            "₹ ${booking['amount'] ?? ''}",
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.green,
            ),
          ),

          /// QR CODE LINK
          if (qrCodeUrl != null && qrCodeUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: GestureDetector(
                onTap: () => _showQrDialog(booking),
                child: Row(
                  children: [
                    const Icon(Icons.qr_code, size: 20),
                    const SizedBox(width: 6),
                    const Text(
                      "Show Booking Pass",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    // const Spacer(),
                    // IconButton(
                    //   icon: const Icon(Icons.share, size: 20),
                    //   onPressed: () => _shareQrImage(qrCodeUrl),
                    // ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Future<void> _shareQrImage(String qrUrl) async {
  final response = await http.get(Uri.parse(qrUrl));

  final tempDir = await getTemporaryDirectory();
  final file = File('${tempDir.path}/booking_qr.png');

  await file.writeAsBytes(response.bodyBytes);

  await Share.shareXFiles([XFile(file.path)], text: 'My Booking QR Code');
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
                  color: _selectedTimeIndex == 0
                      ? brandBlue
                      : Colors.transparent,
                ),
                const SizedBox(width: 80),
                Container(
                  width: 90,
                  height: 2,
                  color: _selectedTimeIndex == 1
                      ? brandBlue
                      : Colors.transparent,
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
          Icon(
            Icons.event_available_outlined,
            size: 70,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No ${_selectedTimeIndex == 0 ? 'upcoming' : 'previous'} events',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
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
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
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
  /// Which tab is showing. The two are genuinely different passes, not one
  /// list filtered two ways: an entry pass is a term, an event pass is a
  /// ticket.
  ///
  /// Court bookings used to sit in a third tab here. They are reachable from
  /// My Bookings, which shows the same QR, so this screen is now only about
  /// the passes a member holds rather than the slots they booked.
  static const int _tabEntry = 0;
  static const int _tabEvent = 1;

  int _selectedTimeIndex = _tabEntry;
  static const brandBlue = Color(0xFF1A237E);

  List<dynamic> _passes = [];
  bool _isLoading = true;
  @override
  void initState() {
    super.initState();
    _fetchPasses();
  }

  Future<void> _fetchPasses() async {
    if (_selectedTimeIndex == _tabEvent) {
      await _fetchEventPass();
    } else {
      await _fetchEntryPass();
    }
  }

  /// Entry passes come from `GET /fees/my` — a student's approved
  /// enrollments, each a term pass tied to a batch and coach with the QR
  /// already built by the backend. This is the pass shown at the gate.
  ///
  /// Old API (commented out below): `GET student_getpass/{studentId}`.
  Future<void> _fetchEntryPass() async {
    setState(() => _isLoading = true);

    try {
      final entryPasses = await UserRepository.instance.fetchMyGatePasses();
      final passes = entryPasses.map((p) => p.toPassMap()).toList();

      AppLogger.debug(
        'Entry passes: ${passes.length} — '
        '${passes.map((p) => p['pass_code']).toList()}',
        name: 'EntryPass',
      );

      if (!mounted) return;
      setState(() {
        _passes = passes;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error(
        'Could not load entry passes',
        name: 'EntryPass',
        error: e,
      );
      if (!mounted) return;
      setState(() {
        _passes = [];
        _isLoading = false;
      });
    }
  }

  // ---------------------- OLD API (commented out) ----------------------
  // Future<void> _fetchGatePass() async {
  //   setState(() => _isLoading = true);
  //
  //   final studentId = await AuthService.getUserId();
  //   if (studentId == null) return;
  //
  //   final response = await http.get(
  //     Uri.parse("https://nahatasports.com/api/student_getpass/$studentId"),
  //   );
  //
  //   final jsonData = jsonDecode(response.body);
  //
  //   if (response.statusCode == 200 && jsonData['status'] == true) {
  //     final pass = jsonData['pass'];
  //     final student = jsonData['student'];
  //
  //     if (pass != null && student != null) {
  //       // ✅ MERGE student info into pass
  //       pass['name'] = student['name'];
  //       pass['phone'] = student['phone'];
  //       pass['id_card'] = student['id_card'];
  //     }
  //
  //     setState(() {
  //       _passes = pass != null ? [pass] : [];
  //       _isLoading = false;
  //     });
  //   } else {
  //     setState(() {
  //       _passes = [];
  //       _isLoading = false;
  //     });
  //   }
  // }

  /// Event passes now come from `GET /event-passes/bookings/my`, which carries
  /// the QR code for each booking.
  ///
  /// Old API (commented out): `GET nahatasports.com/api/booking-pass/{id}`.
  Future<void> _fetchEventPass() async {
    setState(() => _isLoading = true);

    try {
      final bookings = await EventBookingRepository.instance.fetchMyBookings();
      final passes = bookings.map((b) => b.toViewPassMap()).toList();

      AppLogger.debug(
        'Event passes: ${passes.length} — ${passes.map((p) => p['pass_code']).toList()}',
        name: 'EventPass',
      );

      if (!mounted) return;
      setState(() {
        _passes = passes;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error(
        'Could not load event passes',
        name: 'EventPass',
        error: e,
      );
      if (!mounted) return;
      setState(() {
        _passes = [];
        _isLoading = false;
      });
    }
  }

  // ---------------------- OLD API (commented out) ----------------------
  // Future<void> _fetchEventPass() async {
  //   setState(() => _isLoading = true);
  //
  //   final studentId = await AuthService.getUserId();
  //   if (studentId == null) return;
  //
  //   final response = await http.get(
  //     Uri.parse(
  //       "https://nahatasports.com/api/booking-pass/$studentId?status=active",
  //     ),
  //   );
  //
  //   final jsonData = jsonDecode(response.body);
  //
  //   if (response.statusCode == 200 && jsonData['status'] == true) {
  //     setState(() {
  //       _passes = jsonData['data'];
  //       _isLoading = false;
  //     });
  //   } else {
  //     setState(() {
  //       _passes = [];
  //       _isLoading = false;
  //     });
  //   }
  // }
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

          // Entry / Event tabs. Each owns an equal share of the width and
          // carries its own underline, so the labels stay aligned whatever
          // their length.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildTimeToggle('Entry Pass', _tabEntry),
                _buildTimeToggle('Event Pass', _tabEvent),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Empty State
          // Expanded(
          //   child: _isLoading
          //       ? const Center(child: CircularProgressIndicator())
          //       : _passes.isEmpty
          //       ? _buildEmptyState()
          //       : ListView.builder(
          //     padding: const EdgeInsets.symmetric(horizontal: 16),
          //     itemCount: _passes.length,
          //     itemBuilder: (context, index) {
          //       final pass = _passes[index];
          //
          //       String qrUrl = pass['qr_code'] ?? '';
          //
          //       if (qrUrl.isNotEmpty) {
          //         // Step 1: Remove wrong prefix
          //         qrUrl = qrUrl.replaceFirst(
          //           "https://nahatasports.com/",
          //           "",
          //         );
          //
          //         // Step 2: Fix single slash issue
          //         if (qrUrl.startsWith("https:/") &&
          //             !qrUrl.startsWith("https://")) {
          //           qrUrl = qrUrl.replaceFirst("https:/", "https://");
          //         }
          //       }
          //
          //       debugPrint("FINAL QR URL: $qrUrl");
          //
          //       return _buildPassCard(pass, qrUrl,GlobalKey());
          //     },
          //   )
          //
          // )
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _passes.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _passes.length,
                    itemBuilder: (context, index) {
                      final pass = _passes[index];
                      return _buildPassCard(pass);
                    },
                  ),
          ),
        ],
      ),
    );
  }
  // ================= PASS CARD =================

  /// A booking counts as confirmed once the backend says so — court bookings
  /// report `Confirmed`/`Paid`, event bookings sit at `Pending` until payment.
  /// An entry pass from `/fees/my`, as opposed to an event ticket. The card
  /// renders both and they describe themselves with different fields.
  bool _isEntryPass(Map<String, dynamic> pass) =>
      pass['pass_kind'] == 'coaching';

  bool _isConfirmed(Map<String, dynamic> pass) {
    // An entry pass has already worked out whether it is usable: approved,
    // paid and unexpired. Re-deriving it from `status` here would read "Active"
    // off an enrollment the gate would still turn away.
    if (_isEntryPass(pass)) return pass['is_usable'] == true;

    final status = (pass['status'] ?? '').toString().toLowerCase();
    final payment = (pass['payment_status'] ?? '').toString().toLowerCase();
    if (status.isEmpty && payment.isEmpty) return true; // legacy passes
    return status == 'confirmed' || payment == 'paid';
  }

  String _statusLabel(Map<String, dynamic> pass) {
    if (_isEntryPass(pass)) {
      return (pass['status_label'] ?? 'PENDING').toString();
    }
    if (_isConfirmed(pass)) return "ACTIVE PASS";
    final status = (pass['status'] ?? '').toString();
    return status.isEmpty ? "PENDING" : status.toUpperCase();
  }

  /// Pass QRs are absolute URLs (api.qrserver.com); only the legacy gate
  /// pass sent a path that needs the host stripped.
  String _qrUrl(String raw) {
    final url = raw.trim();
    if (url.isEmpty) return url;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return url
        .replaceFirst("https://nahatasports.com/", "")
        .replaceFirst("https:/", "https://");
  }

  Widget _buildPassCard(Map<String, dynamic> pass) {
    final qr = pass['qr_code'] ?? '';
    final repaintKey = GlobalKey();

    return RepaintBoundary(
      key: repaintKey,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================= HEADER =================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: brandBlue,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
              ),
              child: Text(
                _isEntryPass(pass)
                    ? (pass['title']?.toString().isNotEmpty == true
                          ? pass['title']
                          : "Entry Pass")
                    : pass['tournament_title'] ?? '',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ============= ENTRY PASS DETAILS (`/fees/my`) =============
            // A term pass, so it is described by who teaches it and how long it
            // lasts rather than by a single date and court.
            if (_isEntryPass(pass)) ...[
              _infoRow("Student", pass['student_name'] ?? ""),
              _infoRow("Coach", pass['coach_name'] ?? ""),
              _infoRow("Days", pass['days_label'] ?? ""),
              _infoRow("Time", pass['session_label'] ?? ""),
              _infoRow("Valid till", pass['valid_till'] ?? ""),
              _infoRow("Pass Code", pass['pass_code'] ?? ""),
            ]
            // ================= EVENT PASS DETAILS =================
            else ...[
              _infoRow("Date", pass['pass_date'] ?? ""),
              _infoRow("Slot", pass['slot_name'] ?? ""),
              _infoRow("Time", "${pass['start_time']} - ${pass['end_time']}"),
              _infoRow("Pass Code", pass['pass_code'] ?? ""),
            ],

            const SizedBox(height: 20),

            // ================= QR =================
            Center(
              child: qr.toString().startsWith('data:image')
                  ? Image.memory(
                      base64Decode(qr.split(',').last),
                      height: 200,
                      width: 200,
                    )
                  : Image.network(
                      _qrUrl(qr.toString()),
                      height: 200,
                      width: 200,
                      errorBuilder: (_, __, ___) => const SizedBox(
                        height: 200,
                        width: 200,
                        child: Center(child: Text("QR not available")),
                      ),
                    ),
            ),

            const SizedBox(height: 16),

            // ================= STATUS BADGE =================
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _isConfirmed(pass)
                      ? Colors.green.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  _statusLabel(pass),
                  style: TextStyle(
                    color: _isConfirmed(pass) ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ================= SHARE =================
            Center(
              child: TextButton.icon(
                onPressed: () => _sharePass(repaintKey),
                icon: const Icon(Icons.share),
                label: const Text("Share Pass"),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    // Each tab says what is missing and how one would appear, rather than the
    // same "not found" three times over.
    final message = _selectedTimeIndex == _tabEvent
        ? 'No event passes yet.\n'
            'Book an event and your pass will show up here.'
        : 'No entry passes yet.\n'
            'A pass appears here once your enrollment is approved.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[600], fontSize: 16, height: 1.5),
        ),
      ),
    );
  }

  Future<void> _sharePass(GlobalKey repaintKey) async {
    try {
      // wait for UI to finish painting
      await Future.delayed(const Duration(milliseconds: 300));
      await WidgetsBinding.instance.endOfFrame;

      final boundary =
          repaintKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;

      final image = await boundary.toImage(pixelRatio: 3.0);

      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) return;

      final pngBytes = byteData.buffer.asUint8List();

      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}/pass_${DateTime.now().millisecondsSinceEpoch}.png',
      );

      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles([
        XFile(file.path),
      ], text: "Here is your tournament pass 🎟️");
    } catch (e) {
      debugPrint("Share failed: $e");
    }
  }

  Widget _buildTimeToggle(String title, int index) {
    final isSelected = _selectedTimeIndex == index;

    return Expanded(
      child: GestureDetector(
        // Opaque so the whole third of the bar is tappable, not just the
        // glyphs — "Coaching" is a much narrower target than "Event Pass".
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_selectedTimeIndex == index) return; // already here
          setState(() {
            _selectedTimeIndex = index;
            // Clear immediately: the previous tab's passes must not sit under
            // the new tab's heading while its request is in flight.
            _passes = [];
            _isLoading = true;
          });
          _fetchPasses();
        },
        child: Column(
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? brandBlue : Colors.grey,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              color: isSelected ? brandBlue : Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }
}

// edit_profile_screen.dart

/// The one-line explanation under a field this screen cannot write.
///
/// `PUT /auth/profile` accepts name, phone number, gender and blood group and
/// nothing else, so the rest is shown disabled with the reason next to it —
/// a field that looks editable and quietly discards the edit is the worse
/// failure.
class _ReadOnlyNote extends StatelessWidget {
  const _ReadOnlyNote(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline_rounded, size: 12, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }
}

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
  // final parentController = TextEditingController();
  final dobController = TextEditingController();
  final coachIdController = TextEditingController();
  final statusController = TextEditingController();
  final createdController = TextEditingController();
  final updatedController = TextEditingController();

  String? selectedGender;
  String? selectedBloodGroup;

  /// The dropdowns' options, named once so the form and the value it loads
  /// from the API can never disagree about the spelling.
  static const List<String> _genderOptions = ['Male', 'Female', 'Other'];
  static const List<String> _bloodGroupOptions = [
    'A+',
    'A-',
    'B+',
    'B-',
    'O+',
    'O-',
    'AB+',
    'AB-',
  ];

  String? userId;
  bool isLoading = false;

  /// From `GET /students/me` — the student record id and current avatar.
  int? studentRecordId;
  String? avatarUrl;

  /// What the server last told us, so Save can send only what changed.
  ///
  /// `PUT /auth/profile` runs a uniqueness check on the phone number and
  /// answers 400 when it is taken — and it counts the number already on this
  /// account as taken, so re-sending an untouched one fails a save that
  /// changed nothing but the blood group. A field the user did not edit must
  /// not be in the body at all.
  String? _savedName;
  String? _savedPhone;
  String? _savedGender;
  String? _savedBloodGroup;

  /// The picked file, shown immediately so the new photo appears while the
  /// upload is still in flight.
  File? pickedAvatar;
  bool isUploadingAvatar = false;
  final ImagePicker _picker = ImagePicker();

  // The email field is read-only now, so only the phone needs validating.
  final _phoneReg = RegExp(r'^\d{10}$');

  @override
  void initState() {
    super.initState();
    _loadUserAndData();
  }

  Future<void> _loadUserAndData() async {
    setState(() => isLoading = true);

    // Cached first so the form is never blank while the network call runs.
    final cached = await AuthRepository.instance.cachedProfile();
    userId = cached?.id?.toString() ?? await AuthService.getUserId();
    if (cached != null) _applyProfile(cached);

    try {
      // `GET /auth/profile` is the source of truth for this form: it owns
      // every field the Save button writes back through `PUT /auth/profile`.
      final profile = await AuthRepository.instance.fetchProfile();
      userId ??= profile.id?.toString();
      _applyProfile(profile);

      // `GET /students/me` only fills in what the account profile has no
      // concept of — the student record id and the coaching status.
      final student = await UserRepository.instance.fetchMyStudentProfile();
      if (student != null) _applyStudentProfile(student);
    } on ApiException catch (e) {
      // The cached profile is already on screen, so this is a warning rather
      // than an empty form.
      _showSnack(e.message);
    } catch (e) {
      debugPrint("Error fetching profile: $e");
      _showSnack("Could not load your profile. Please try again.");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  /// Seeds the form from `GET /auth/profile`.
  void _applyProfile(ProfileModel profile) {
    nameController.text = profile.name ?? nameController.text;
    emailController.text = profile.email ?? emailController.text;
    phoneController.text = profile.phoneNumber ?? phoneController.text;
    dobController.text = profile.dob ?? dobController.text;
    statusController.text = profile.status ?? statusController.text;
    createdController.text = profile.joinDate ?? createdController.text;
    updatedController.text =
        _clean(profile.extras['updatedAt']) ?? updatedController.text;

    // The dropdowns match on the exact option text, so a value the list does
    // not contain is dropped rather than left selected-but-invisible.
    selectedGender = _matchOption(profile.gender, _genderOptions);
    selectedBloodGroup = _matchOption(profile.bloodGroup, _bloodGroupOptions);

    avatarUrl = profile.imageUrl ?? avatarUrl;

    _rememberSavedState();
  }

  /// Snapshots the form as the server has it, for [_changed] to diff against.
  ///
  /// Taken after the values have been through [_matchOption], so a blood group
  /// the API spells `"o"` and the form shows as `"O+"` does not read as an
  /// edit the user never made.
  void _rememberSavedState() {
    _savedName = nameController.text.trim();
    _savedPhone = phoneController.text.trim();
    _savedGender = selectedGender;
    _savedBloodGroup = selectedBloodGroup;
  }

  /// [current] when it differs from [saved], otherwise null — which is how
  /// [AuthRepository.updateProfile] is told to leave a field alone.
  static String? _changed(String? current, String? saved) {
    final now = current?.trim() ?? '';
    final before = saved?.trim() ?? '';
    return now == before ? null : now;
  }

  /// Case-insensitive match against a dropdown's options.
  ///
  /// The API returns whatever was last written — `"o"` for a blood group the
  /// form offers as `"O+"` — so an unrecognised value leaves the dropdown
  /// empty instead of throwing on a value that is not in `items`.
  static String? _matchOption(String? value, List<String> options) {
    final text = _clean(value);
    if (text == null) return null;
    for (final option in options) {
      if (option.toLowerCase() == text.toLowerCase()) return option;
    }
    return null;
  }

  /// Seeds the form from `GET /students/me`.
  void _applyStudentProfile(StudentProfile student) {
    final user = student.user;

    if (user != null) {
      nameController.text = user.name ?? nameController.text;
      emailController.text = user.email ?? emailController.text;
      phoneController.text = user.phoneNumber ?? phoneController.text;
      dobController.text = user.dob ?? dobController.text;
      // Through [_matchOption] like every other write: this endpoint returns
      // the same free-text values as the profile ("o" for a blood group the
      // form offers as "O+"), and a value the dropdown has no item for is an
      // assertion failure, not a blank field.
      selectedGender =
          _matchOption(user.gender, _genderOptions) ?? selectedGender;
      selectedBloodGroup =
          _matchOption(user.bloodGroup, _bloodGroupOptions) ??
          selectedBloodGroup;
      avatarUrl = user.avatar ?? avatarUrl;
    }

    statusController.text = student.effectiveStatus ?? statusController.text;
    createdController.text = student.createdAt ?? createdController.text;
    updatedController.text = student.updatedAt ?? updatedController.text;

    studentRecordId = student.id;

    // This call can overwrite the name, phone, gender and blood group the
    // profile seeded, so the baseline moves with it.
    _rememberSavedState();
  }

  static String? _clean(Object? value) {
    final text = value?.toString().trim();
    return (text == null || text.isEmpty || text == 'null') ? null : text;
  }

  /// Picks a photo and uploads it to `POST /auth/profile/picture`.
  ///
  /// Camera or gallery, then straight to the server: the picture has its own
  /// route, so making the user press Save afterwards would only invite them to
  /// leave the screen with the photo unsent.
  Future<void> _changePhoto() async {
    final source = await _askPhotoSource();
    if (source == null) return;

    final XFile? picked;
    try {
      picked = await _picker.pickImage(
        source: source,
        // The route caps the upload at 1 MB. Downscaling here is what keeps a
        // 4 MB phone photo inside it, rather than letting the server refuse a
        // picture the user has already chosen.
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
    } on PlatformException catch (e) {
      // A denied camera/photos permission arrives here, not as a null file.
      _showSnack(
        e.code == 'camera_access_denied' || e.code == 'photo_access_denied'
            ? 'Please allow access to your ${source == ImageSource.camera ? "camera" : "photos"} in Settings.'
            : 'Could not open your ${source == ImageSource.camera ? "camera" : "photos"}.',
      );
      return;
    }

    if (picked == null) return; // Cancelled.

    final file = File(picked.path);
    setState(() {
      pickedAvatar = file;
      isUploadingAvatar = true;
    });

    try {
      final profile = await AuthRepository.instance.uploadProfilePicture(
        picked.path,
      );

      if (!mounted) return;

      final url = profile.imageUrl;

      // A backend that reuses the filename hands back the URL that is already
      // in the image cache, and the old photo would stay on screen everywhere.
      // Evicting both spellings costs nothing and rules that out.
      if (url != null && url.isNotEmpty) {
        await CachedNetworkImage.evictFromCache(url);
        await NetworkImage(url).evict();
      }
      if (avatarUrl != null && avatarUrl != url && avatarUrl!.isNotEmpty) {
        await CachedNetworkImage.evictFromCache(avatarUrl!);
        await NetworkImage(avatarUrl!).evict();
      }

      if (!mounted) return;

      // The repository already cached the updated profile, so the provider is
      // handed that copy — Home and More repaint from the same object.
      context.read<ProfileProvider>().adopt(profile);

      setState(() {
        avatarUrl = url ?? avatarUrl;
        // The picked file stays on screen: it is exactly what was uploaded, so
        // it is right even in the moment before the new URL finishes loading.
        pickedAvatar = file;
      });

      _showSnack('Profile picture updated.');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => pickedAvatar = null); // Put the old photo back.
      _showSnack(e.message);
    } catch (e) {
      debugPrint('Profile picture upload failed: $e');
      if (!mounted) return;
      setState(() => pickedAvatar = null);
      _showSnack('Could not upload your picture. Please try again.');
    } finally {
      if (mounted) setState(() => isUploadingAvatar = false);
    }
  }

  /// Camera or gallery. Returns null when the sheet is dismissed.
  Future<ImageSource?> _askPhotoSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// `PUT /auth/profile`
  ///
  /// Sends exactly the four fields the endpoint owns — name, phone number,
  /// gender and blood group. Email, date of birth and the photo are shown
  /// read-only in the form because this endpoint cannot write them; sending
  /// them anyway would look like an edit that silently never took.
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Only what the user actually edited. Sending an untouched phone number
    // trips the endpoint's uniqueness check against this very account, which
    // is what made "This WhatsApp number is already registered" reject a save
    // that never touched the phone.
    final name = _changed(nameController.text, _savedName);
    final phone = _changed(phoneController.text, _savedPhone);
    final gender = _changed(selectedGender, _savedGender);
    final bloodGroup = _changed(selectedBloodGroup, _savedBloodGroup);

    if (name == null && phone == null && gender == null && bloodGroup == null) {
      _showSnack('No changes to save.');
      return;
    }

    setState(() => isLoading = true);

    try {
      final profile = await AuthRepository.instance.updateProfile(
        name: name,
        phoneNumber: phone,
        gender: gender,
        bloodGroup: bloodGroup,
      );

      // The call already returned the updated user and cached it, so the
      // provider is handed that copy rather than made to re-fetch it. Home,
      // More and the dashboards repaint from this.
      if (mounted) {
        context.read<ProfileProvider>().adopt(profile);
        _applyProfile(profile);
      }

      _showDialogAndBack("Profile updated successfully");
    } on ApiException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      debugPrint("Error updating profile: $e");
      _showSnack("Could not update your profile. Please try again.");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // tiny helper to show snack
  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showDialogAndBack(String message) {
    showDialog(
      context: context,
      builder: (_) =>
          AlertDialog(content: Text(message, textAlign: TextAlign.center)),
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.pop(context); // close dialog
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const CustomBottomNav()),
      );
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    idCardController.dispose();
    emailController.dispose();
    phoneController.dispose();
    // parentController.dispose();
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
              child: Column(
                children: [
                  // header card with avatar
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 18,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: Colors.black12, blurRadius: 8),
                      ],
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: isUploadingAvatar ? null : _changePhoto,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CircleAvatar(
                                radius: 38,
                                backgroundColor: Colors.grey[200],
                                // The picked file wins while it uploads, so the new
                                // photo is on screen before the server confirms it.
                                backgroundImage: pickedAvatar != null
                                    ? FileImage(pickedAvatar!)
                                    : (avatarUrl != null &&
                                          avatarUrl!.isNotEmpty)
                                    ? NetworkImage(avatarUrl!) as ImageProvider
                                    : null,
                                child:
                                    (pickedAvatar == null &&
                                        (avatarUrl == null ||
                                            avatarUrl!.isEmpty))
                                    ? const Icon(
                                        Icons.person_outline,
                                        size: 30,
                                        color: Colors.black54,
                                      )
                                    : null,
                              ),

                              // A spinner over the picture itself: the upload belongs
                              // to this photo, not to the Save button below it.
                              if (isUploadingAvatar)
                                Positioned.fill(
                                  child: DecoratedBox(
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.black45,
                                    ),
                                    child: const Center(
                                      child: SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                              Positioned(
                                right: -2,
                                bottom: -2,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.blueAccent,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nameController.text.isEmpty
                                    ? 'Your Name'
                                    : nameController.text,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'ID: ${idCardController.text.isEmpty ? "N/A" : idCardController.text}',
                                style: theme.textTheme.bodySmall,
                              ),
                              const SizedBox(height: 8),
                              // `POST /auth/profile/picture` is a route of its own, so
                              // the photo is saved the moment it is picked rather than
                              // waiting on the Save button, which writes text fields.
                              TextButton.icon(
                                onPressed: isUploadingAvatar
                                    ? null
                                    : _changePhoto,
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 32),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                icon: const Icon(
                                  Icons.photo_camera_outlined,
                                  size: 18,
                                ),
                                label: Text(
                                  isUploadingAvatar
                                      ? 'Uploading…'
                                      : 'Change Photo',
                                ),
                              ),
                            ],
                          ),
                        ),
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
                      boxShadow: [
                        BoxShadow(color: Colors.black12, blurRadius: 8),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Name — editable: `PUT /auth/profile` accepts it.
                          _label('Full Name'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: nameController,
                            decoration: _outlined('Full Name'),
                            textCapitalization: TextCapitalization.words,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty)
                                return 'Name required';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),

                          // Email — read-only: this endpoint cannot change it, and an
                          // editable box that silently discards the edit is worse than
                          // a disabled one.
                          _label('Email'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: emailController,
                            readOnly: true,
                            enabled: false,
                            decoration: _outlined('Email', enabled: false),
                          ),
                          const _ReadOnlyNote(
                            'Contact support to change your email.',
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
                              if (v == null || v.trim().isEmpty)
                                return 'Phone required';
                              if (!_phoneReg.hasMatch(v.trim()))
                                return 'Enter 10 digit phone';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),

                          // Parent contact
                          // _label('Parent / Guardian Contact'),
                          // const SizedBox(height: 6),
                          // TextFormField(
                          //   controller: parentController,
                          //   decoration: _outlined('Parent / Guardian Contact'),
                          //   keyboardType: TextInputType.phone,
                          //   validator: (v) {
                          //     if (v != null && v.isNotEmpty && !_phoneReg.hasMatch(v)) {
                          //       return 'Enter 10 digit phone';
                          //     }
                          //     return null;
                          //   },
                          // ),
                          // const SizedBox(height: 12),

                          // DOB — read-only for the same reason as the email, and with
                          // no validator: the profile returns it null for most accounts,
                          // and a required field nobody can fill would block Save
                          // outright.
                          _label('Date of Birth'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: dobController,
                            readOnly: true,
                            enabled: false,
                            decoration: _outlined('Not set', enabled: false),
                          ),
                          const _ReadOnlyNote(
                            'Contact support to change your date of birth.',
                          ),
                          const SizedBox(height: 12),

                          // Gender & Blood group row
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _label('Gender'),
                                    const SizedBox(height: 6),
                                    DropdownButtonFormField<String>(
                                      // Normalised here as well as at every write: a value
                                      // with no matching item is an assertion failure that
                                      // takes the whole screen down, so the render path
                                      // refuses to pass one through.
                                      value: _matchOption(
                                        selectedGender,
                                        _genderOptions,
                                      ),
                                      decoration: _outlined('Gender'),
                                      items: _genderOptions
                                          .map(
                                            (g) => DropdownMenuItem(
                                              value: g,
                                              child: Text(g),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (v) =>
                                          setState(() => selectedGender = v),
                                      validator: (v) {
                                        if (v == null || v.isEmpty)
                                          return 'Select gender';
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _label('Blood Group'),
                                    const SizedBox(height: 6),
                                    DropdownButtonFormField<String>(
                                      value: _matchOption(
                                        selectedBloodGroup,
                                        _bloodGroupOptions,
                                      ),
                                      decoration: _outlined('Blood Group'),
                                      items: _bloodGroupOptions
                                          .map(
                                            (g) => DropdownMenuItem(
                                              value: g,
                                              child: Text(g),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (v) => setState(
                                        () => selectedBloodGroup = v,
                                      ),
                                      validator: (v) {
                                        if (v == null || v.isEmpty)
                                          return 'Select blood group';
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
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
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: isLoading
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  : const Text(
                                      'Save Changes',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // Small UI helpers
  Widget _label(String t) =>
      Text(t, style: const TextStyle(fontWeight: FontWeight.w600));
  InputDecoration _outlined(
    String hint, {
    bool enabled = true,
    IconData? suffix,
  }) => InputDecoration(
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
      AppLogger.debug("⚠️ No student ID found, cannot fetch feedback", name: 'morescreen');
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
      AppLogger.debug("🎓 Loaded student ID: $studentId", name: 'morescreen');
    } else {
      AppLogger.debug("⚠️ No user data found in SharedPreferences", name: 'morescreen');
    }
  }

  Future<void> fetchFeedback() async {
    final url = Uri.parse(
      'https://nahatasports.com/api/student/details/$studentId',
    );
    AppLogger.debug("📡 Fetching feedback from: $url", name: 'morescreen');

    try {
      final response = await http.get(url);
      AppLogger.debug("📩 Response: ${response.statusCode}", name: 'morescreen');
      AppLogger.debug("📦 Body: ${response.body}", name: 'morescreen');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == true && data['feedbacks'] != null) {
          setState(() {
            feedbackList = data['feedbacks']; // <-- List directly
            isLoading = false;
          });

          AppLogger.debug("✅ Feedback entries loaded: ${feedbackList.length}", name: 'morescreen');
        } else {
          AppLogger.debug("⚠️ No feedback data available", name: 'morescreen');
          setState(() => isLoading = false);
        }
      } else {
        AppLogger.debug("❌ Server error: ${response.statusCode}", name: 'morescreen');
        setState(() => isLoading = false);
      }
    } catch (e) {
      AppLogger.debug("❌ Exception fetching feedback: $e", name: 'morescreen');
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
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          date,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
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

// Future<void> _loadBookings() async {
//   final email = await AuthService.getUserEmail();
//   if (email == null) return;
//
//   final filter = _selectedTimeIndex == 0 ? "upcoming" : "previous";
//
//   final response = await http.post(
//     Uri.parse("https://nahatasports.com/api/court-bookings?filter=$filter"),
//     headers: {"Content-Type": "application/json"},
//     body: jsonEncode({
//       "email": email,
//     }),
//   );
//
//   final jsonData = jsonDecode(response.body);
//
//   if (jsonData['status'] == true) {
//     setState(() {
//       allBookings = List<Map<String, dynamic>>.from(jsonData['data']);
//     });
//   } else {
//     setState(() {
//       allBookings = [];
//     });
//   }
// }

// Future<void> _fetchPasses() async {
//   setState(() => _isLoading = true);
//
//   final studentId = await AuthService.getUserId();
//   if (studentId == null) return;
//
//   final status = _selectedTimeIndex == 0 ? ""
//       "active" : "expired";
//
//   final response = await http.get(
//     Uri.parse(
//       "https://nahatasports.com/api/booking-pass/$studentId?status=$status",
//     ),
//   );
//
//   final jsonData = jsonDecode(response.body);
//   print("Status: ${response.statusCode}");
//   print("Body: ${response.body}");
//   print(response);
//   if (jsonData['status'] == true) {
//     setState(() {
//       _passes = jsonData['data'];
//       _isLoading = false;
//     });
//   } else {
//     setState(() {
//       _passes = [];
//       _isLoading = false;
//     });
//   }
// }
// Future<void> _fetchGatePass() async {
//   setState(() => _isLoading = true);
//
//   final studentId = await AuthService.getUserId();
//   if (studentId == null) return;
//
//   final response = await http.get(
//     Uri.parse(
//       "https://nahatasports.com/api/student_getpass/$studentId",
//     ),
//   );
//
//   final jsonData = jsonDecode(response.body);
//
//   if (response.statusCode == 200 && jsonData['status'] == true) {
//     final pass = jsonData['pass'];
//
//     setState(() {
//       _passes = pass != null ? [pass] : [];
//       _isLoading = false;
//     });
//   } else {
//     setState(() {
//       _passes = [];
//       _isLoading = false;
//     });
//   }
// }
