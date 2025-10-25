import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'dart:ui' as ui;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:qr/qr.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:http/http.dart' as http;
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:nahata_app/bottombar/Custombottombar.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/login.dart';

class EventModel {
  final String id;
  final String title;
  final String image;
  // final String date;
  // final int price;
  // final int totalSlots;
  // final int bookedSlots;
  final String location;
  final String description;

  EventModel({
    required this.id,
    required this.title,
    required this.image,
    // required this.date,
    // required this.price,
    // required this.totalSlots,
    // required this.bookedSlots,
    required this.location,
    required this.description,
  });
  //
  // bool get isFull => bookedSlots >= totalSlots;
  // int get availableSlots => (totalSlots - bookedSlots).clamp(0, totalSlots);

  factory EventModel.fromJson(Map<String, dynamic> json) {
    final unescape = HtmlUnescape();
    final rawContent = json['content'] ?? '';
    final cleanHtml = unescape
        .convert(rawContent.replaceAll(RegExp(r'<[^>]*>'), ''))
        .replaceAll(RegExp(r'\s+\n'), '\n') // normalize whitespace
        .trim();

    return EventModel(
      id: json['id'].toString(),
      title: json['title'] ?? '',
      image: "https://nahatasports.com/${json['image'] ?? ''}",
      // date: json['tournament_date'] ?? '',
      // price: int.tryParse(json['price'] ?? '0') ?? 0,
      // totalSlots: int.tryParse(json['allowed_members'] ?? '0') ?? 0,
      // bookedSlots: int.tryParse(json['booked_slots'] ?? '0') ?? 0,
      location: 'Nahata Sports Complex',
      description: cleanHtml,
    );
  }

  String get formattedDescription {
    final content = description;

    // Generic extractor for labeled sections
    String extractSection(String label) {
      final regex = RegExp(
        '$label\\s*:?\\s*(.*?)(?=(Dates & Timings:|Pass Prices:|Age Group:|Language:|Venue:|\$))',
        dotAll: true,
        caseSensitive: false,
      );
      return regex.firstMatch(content)?.group(1)?.trim() ?? '';
    }

    final aboutText = extractSection('About The Event');
    final timingsRaw = extractSection('Dates & Timings');
    final passRaw = extractSection('Pass Prices');
    final ageGroup = extractSection('Age Group');
    final language = extractSection('Language');
    final venue = extractSection('Venue');

    final timings = timingsRaw
        .split(RegExp(r'[\n•]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final passes = passRaw
        .split(RegExp(r'[\n•]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final buffer = StringBuffer();

    if (aboutText.isNotEmpty) {
      buffer.writeln(aboutText);
      buffer.writeln();
    }

    if (timings.isNotEmpty) {
      buffer.writeln("📅 Dates & Timings:");
      timings.forEach((t) => buffer.writeln(" • $t"));
      buffer.writeln();
    }

    if (passes.isNotEmpty) {
      buffer.writeln("🎟️ Pass Prices:");
      passes.forEach((p) => buffer.writeln(" • $p"));
      buffer.writeln();
    }

    if (ageGroup.isNotEmpty) buffer.writeln("👨‍👩‍👧‍👦 Age Group: $ageGroup\n");
    if (language.isNotEmpty) buffer.writeln("🗣️ Language: $language\n");
    if (venue.isNotEmpty) buffer.writeln("📍 Venue: $venue");

    return buffer.toString().trim();
  }



}

/* -------------------------------------------
   API Service
   ------------------------------------------- */
Future<List<EventModel>> fetchEvents() async {
  final res = await http.get(Uri.parse("https://nahatasports.com/api/tournaments"));
  if (res.statusCode != 200) throw Exception("Failed to load events");

  final body = jsonDecode(res.body);
  final List data = body['data'] ?? [];
  return data.map((e) => EventModel.fromJson(e)).toList();
}

/* -------------------------------------------

 */
class EventsScreen extends StatefulWidget {
  @override
  _EventsScreenState createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  int selectedTab = 0;

  late Future<List<EventModel>> _futureEvents;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _animationController.forward();

    _futureEvents = fetchEvents();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              _buildHeader(),
              _buildCinemaBanner(),
              _buildTabSection(),
              Expanded(child: _buildEventGrid()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Events',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCinemaBanner() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      height: 120,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1a237e), Color(0xFF3949ab)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: 16,
            top: 16,
            child: Icon(
              Icons.local_movies,
              size: 60,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          Positioned(
            right: 20,
            top: 20,
            child: Container(
              width: 50,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: Icon(
                  Icons.movie,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Nahata',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Sports',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 2,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Discover amazing events',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => selectedTab = 0),
              child: AnimatedContainer(
                duration: Duration(milliseconds: 300),
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                decoration: BoxDecoration(
                  color:
                  selectedTab == 0 ? Color(0xFF1a237e) : Colors.grey[200],
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Text(
                  'Coming soon',
                  style: TextStyle(
                    color: selectedTab == 0
                        ? Colors.white
                        : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          GestureDetector(
            onTap: () => setState(() => selectedTab = 1),
            child: AnimatedContainer(
              duration: Duration(milliseconds: 300),
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              decoration: BoxDecoration(
                color:
                selectedTab == 1 ? Color(0xFF1a237e) : Colors.grey[200],
                borderRadius: BorderRadius.circular(25),
              ),
              child: Text(
                'Explore Upcoming Shows',
                style: TextStyle(
                  color: selectedTab == 1
                      ? Colors.white
                      : Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildEventGrid() {
    return FutureBuilder<List<EventModel>>(
      future: _futureEvents,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error loading events'));
        } else {
          final events = snapshot.data ?? [];
          if (events.isEmpty) {
            return Center(child: Text('No events available'));
          }
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: GridView.builder(
              physics: BouncingScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 16,
                childAspectRatio: 0.7,
              ),
              itemCount: events.length,
              itemBuilder: (context, index) {
                final event = events[index];
                return _buildEventCard(event);
              },
            ),
          );
        }
      },
    );
  }

  Widget _buildEventCard(EventModel event) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EventDetailsPage(event: event),
          ),
        );
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              Image.network(
                event.image,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    event.title,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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





/* -------------------------------------------
   Enhanced Event Details Page
   ------------------------------------------- */


class EventDetailsPage extends StatefulWidget {
  final EventModel event;
  const EventDetailsPage({required this.event, Key? key}) : super(key: key);

  @override
  State<EventDetailsPage> createState() => _EventDetailsPageState();
}

class _EventDetailsPageState extends State<EventDetailsPage>
    with SingleTickerProviderStateMixin {
  String? _selectedSlot;
  bool _bookingInProgress = false;
  List<Map<String, dynamic>> _slots = [];
  int _membersCount = 1;
  double _totalPrice = 0.0;
  Razorpay? _razorpay;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: const Interval(0.3, 1.0, curve: Curves.elasticOut)),
    );

    _animationController.forward();

    _fetchSlots();

    _razorpay = Razorpay();
    _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
    _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _razorpay?.clear();
    super.dispose();
  }

  /// Fetch slots from API
  Future<void> _fetchSlots() async {
    final url = Uri.parse("https://nahatasports.com/api/tournaments/${widget.event.id}/slots");
    try {
      final response = await http.get(url, headers: {"Content-Type": "application/json"});
      if (!mounted) return;

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['slots'] is List) {
          final List slots = decoded['slots'];
          setState(() {
            _slots = slots.map((s) {
              return {
                "id": s['id'],
                "name": s['slot_name'] ?? '',
                "date": s['pass_date'] ?? '',
                "price": s['pass_price'] ?? '0',
                "pass_type": s['pass_type'] ?? '',
                "start": s['start_time'] ?? '',
                "end": s['end_time'] ?? '',
              };
            }).toList();

            if (_slots.isNotEmpty) {
              _selectedSlot = _slots.first['id'];
              _calculatePrice();
            }
          });
        } else {
          if (mounted) _showSnack("No slots available");
        }
      } else {
        if (mounted) _showSnack("Failed to fetch slots");
      }
    } catch (e, st) {
      debugPrint("Error fetching slots: $e\n$st");
      if (mounted) _showSnack("Error loading slots");
    }
  }

  /// Razorpay payment start
  void _startPaymentFlow() {
    if (ApiService.currentUser == null) {
      // Navigator.pushAndRemoveUntil(
      //   context,
      //   MaterialPageRoute(builder: (_) => LoginScreen()),
      //       (route) => false,
      // );
      _showNotLoggedInPopup();

      return;
    }
    if (_selectedSlot == null) {
      _showSnack('Please select a slot');
      return;
    }
    if (_totalPrice <= 0) {
      _showSnack('Invalid amount');
      return;
    }

    final options = {
      // replace with your key (test/live) appropriately
      'key': 'rzp_live_R7b5MMCgg9AlWn',
      //  'key': 'rzp_test_YwYUHvAMatnKBY',
      // 'key': 'rzp_live_R7b5MMCgg9AlWn',
      'amount': (_totalPrice * 100).toInt(), // amount in paise
      'name': widget.event.title,
      'description': 'Tournament Booking',
      'prefill': {
        'contact': ApiService.currentUser?['phone'] ?? '',
        'email': ApiService.currentUser?['email'] ?? '',
      }
    };

    try {
      _razorpay!.open(options);
    } catch (e) {
      debugPrint("Error opening Razorpay: $e");
      _showSnack("Payment initialization failed");
    }
  }
  void _showNotLoggedInPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon with background
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_outline,
                    size: 48, color: Colors.orange),
              ),
              const SizedBox(height: 20),

              // Title
              const Text(
                "Login Required",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              // Description
              const Text(
                "You need to log in to continue.\nRedirecting you shortly...",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.black87),
              ),

              const SizedBox(height: 24),

              // Loading Indicator
              const CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
              ),

              const SizedBox(height: 12),

              const Text(
                "Please wait...",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );

    // Auto-redirect after delay
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      Navigator.pop(context); // Close popup
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
      );
    });
  }

  void _onPaymentSuccess(PaymentSuccessResponse response) {
    // response contains paymentId, orderId, signature
    _confirmBooking(response.paymentId);
  }

  void _onPaymentError(PaymentFailureResponse response) {
    _showSnack("Payment failed. Please try again.");
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    _showSnack("External wallet selected: ${response.walletName}");
  }

  /// Confirm booking after successful payment
  Future<void> _confirmBooking(String? razorpayPaymentId) async {
    if (_selectedSlot == null) {
      _showSnack("Please select a slot");
      return;
    }

    setState(() => _bookingInProgress = true);

    try {
      final user = ApiService.currentUser;
      if (user == null) {
        if (mounted) _showSnack("User not logged in");
        return;
      }

      // 1) Verify payment (optional, depends on your backend)
      try {
        final verifyUrl = Uri.parse("https://nahatasports.com/api/tournaments/verify-payment");
        final verifyRes = await http.post(
          verifyUrl,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"razorpay_payment_id": razorpayPaymentId ?? ""}),
        );
        debugPrint("Verify API response: ${verifyRes.body}");
      } catch (ve) {
        debugPrint("Payment verify call failed: $ve");
        // Don't block booking confirm if verify endpoint fails — up to your server logic.
      }

      // 2) Confirm booking
      final confirmUrl = Uri.parse("https://nahatasports.com/api/booking/confirm");
      final selected = _slots.firstWhere(
            (s) => s['id'] == _selectedSlot,
        orElse: () => {},
      );
      final confirmRes = await http.post(
        confirmUrl,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": user['id'],
          "tournament_id": widget.event.id,
          "slot_id": _selectedSlot,
          "name": user['name'] ?? "",
          "email": user['email'] ?? "",
          "members_count": _membersCount,
          'pass_type': selected['pass_type'] ?? '',
          'pass_date': selected['date'] ?? '',
          'start_time': selected['start'] ?? '',
          'end_time': selected['end'] ?? '',
          "razorpay_payment_id": razorpayPaymentId ?? "",
          // you could optionally send razorpay_payment_id here
        }),
      );

      debugPrint("Confirm API response: ${confirmRes.body}");

      if (!mounted) return;

      Map<String, dynamic>? data;
      try {
        data = jsonDecode(confirmRes.body);
      } catch (e) {
        debugPrint("Failed to parse confirm response JSON: $e");
        if (mounted) _showSnack("Unexpected server response");
        return;
      }

      if (data?['status'] == 'success' && data?['data'] != null) {
        final bookingData = BookingData.fromJson(data?['data']);
        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => EventPassPage(
              booking: bookingData,
              eventImage: widget.event.image,
            ),
          ),
        );
      } else {
        final msg = data?['message'] ?? 'Booking failed';
        if (mounted) _showSnack(msg);
      }
    } catch (e, st) {
      debugPrint("Booking error: $e\n$st");
      if (mounted) _showSnack("Payment or booking failed. Try again.");
    } finally {
      if (mounted) setState(() => _bookingInProgress = false);
    }
  }

  /// Calculate total price
  void _calculatePrice() {
    if (!mounted) return;
    final selected = _slots.firstWhere(
          (s) => s['id'] == _selectedSlot,
      orElse: () => {"price": "0"},
    );
    final slotPrice = double.tryParse(selected['price'].toString()) ?? 0.0;
    setState(() => _totalPrice = slotPrice * _membersCount);
  }

  /// Format time from "HH:mm[:ss]" → "h:mm a" (safe)
  String _formatTime(String? time) {
    if (time == null || time.isEmpty) return '';
    final parts = time.split(":");
    try {
      final hour = int.parse(parts[0]);
      final minute = parts.length > 1 ? int.parse(parts[1]) : 0;
      final now = DateTime.now();
      final dt = DateTime(now.year, now.month, now.day, hour, minute);
      return TimeOfDay.fromDateTime(dt).format(context);
    } catch (e) {
      return time; // fallback: return raw string
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFF0A198D),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Enhanced App Bar with Hero Image
          SliverAppBar(
            expandedHeight: 300,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF0A198D),
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            // actions: [
            //   Container(
            //     margin: const EdgeInsets.all(8),
            //     decoration: BoxDecoration(
            //       color: Colors.black.withOpacity(0.3),
            //       borderRadius: BorderRadius.circular(12),
            //     ),
            //     child: IconButton(
            //       icon: const Icon(Icons.favorite_border, color: Colors.white),
            //       onPressed: () {},
            //     ),
            //   ),
            // ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'event-image-${e.id}',
                    child: Image.network(
                      e.image,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey[200]),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                        stops: const [0.6, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    left: 16,
                    right: 16,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Container(
                          //   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          //   decoration: BoxDecoration(
                          //     color: const Color(0xFF0A198D).withOpacity(0.9),
                          //     borderRadius: BorderRadius.circular(20),
                          //   ),
                          //   child: const Text(
                          //     'LIVE EVENT',
                          //     style: TextStyle(
                          //       color: Colors.white,
                          //       fontSize: 12,
                          //       fontWeight: FontWeight.bold,
                          //       letterSpacing: 1,
                          //     ),
                          //   ),
                          // ),
                          const SizedBox(height: 8),
                          Text(
                            e.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content Section
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 30, 20, 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildQuickInfoCard(),
                        const SizedBox(height: 24),
                        _buildSlotSelectionCard(),
                        const SizedBox(height: 24),
                        _buildMembersCard(),
                        const SizedBox(height: 24),
                        _buildDescriptionCard(),
                        const SizedBox(height: 24),
                        _buildPriceSummaryCard(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),

      floatingActionButton: _buildPaymentFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildQuickInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF8FAFF), Color(0xFFEEF4FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF0A198D).withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0A198D),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.location_on, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'VENUE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0A198D),
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.event.location,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotSelectionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.access_time, color: Color(0xFF0A198D), size: 24),
              SizedBox(width: 12),
              Text(
                'Select Time Slot',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_slots.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Column(
                  children: const [
                    CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Color(0xFF0A198D))),
                    SizedBox(height: 12),
                    Text('Loading slots...'),
                  ],
                ),
              ),
            )
          else
            Column(
              children: _slots.map((s) {
                final selected = s['id'] == _selectedSlot;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () {
                      setState(() => _selectedSlot = s['id']);
                      _calculatePrice();
                    },
                    borderRadius: BorderRadius.circular(15),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: selected ? const Color(0xFF0A198D).withOpacity(0.1) : Colors.grey[50],
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: selected ? const Color(0xFF0A198D) : Colors.grey.withOpacity(0.2), width: 2),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: selected ? const Color(0xFF0A198D) : Colors.transparent,
                              border: Border.all(color: selected ? const Color(0xFF0A198D) : Colors.grey, width: 2),
                            ),
                            child: selected ? const Icon(Icons.check, color: Colors.white, size: 14) : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s['name'] ?? '',
                                  style: TextStyle(fontWeight: FontWeight.w600, color: selected ? const Color(0xFF0A198D) : Colors.black87),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${s['pass_type']} • ${_formatTime(s['start'])} - ${_formatTime(s['end'])}',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: selected ? const Color(0xFF0A198D) : Colors.grey[200], borderRadius: BorderRadius.circular(20)),
                            child: Text(
                              '₹${s['price']}',
                              style: TextStyle(color: selected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildMembersCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 8))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.group, color: Color(0xFF0A198D), size: 24),
              SizedBox(width: 12),
              Text('Number of Passes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                decoration: BoxDecoration(color: const Color(0xFF0A198D), borderRadius: BorderRadius.circular(15)),
                child: IconButton(
                  icon: const Icon(Icons.remove, color: Colors.white),
                  onPressed: _membersCount > 1
                      ? () {
                    setState(() {
                      _membersCount--;
                      _calculatePrice();
                    });
                  }
                      : null,
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 30),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(15)),
                child: Text(
                  '$_membersCount',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0A198D)),
                ),
              ),
              Container(
                decoration: BoxDecoration(color: const Color(0xFF0A198D), borderRadius: BorderRadius.circular(15)),
                child: IconButton(
                  icon: const Icon(Icons.add, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _membersCount++;
                      _calculatePrice();
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 8))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.description, color: Color(0xFF0A198D), size: 24),
              SizedBox(width: 12),
              Text('Event Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            widget.event.formattedDescription,
            style: const TextStyle(fontSize: 14, height: 1.6, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF0A198D), Color(0xFF1E40AF)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Total Amount', style: TextStyle(color: Colors.white70, fontSize: 16)),
            Text('₹${_totalPrice.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
          ]),
          if (_selectedSlot != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('₹${_slots.firstWhere((s) => s['id'] == _selectedSlot)['price']} × $_membersCount members', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentFAB() {
    return InkWell(
      onTap: _startPaymentFlow,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        child: FloatingActionButton.extended(
          onPressed: _startPaymentFlow,
          backgroundColor: const Color(0xFF0A198D),
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.payment, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                'Pay ₹${_totalPrice.toStringAsFixed(0)} & Book Now',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


/* -------------------------------------------
   Enhanced Event Pass Page
   ------------------------------------------- */
class EventPassPage extends StatefulWidget {
  final BookingData booking;
  final String eventImage;

  const EventPassPage({
    required this.booking,
    required this.eventImage,
    super.key,
  });

  @override
  State<EventPassPage> createState() => _EventPassPageState();
}

class _EventPassPageState extends State<EventPassPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  final GlobalKey _passCardKey = GlobalKey();
  final GlobalKey _qrKey = GlobalKey();

  // Future<void> _downloadQR() async {
  //   try {
  //     // Android 11+ requires MANAGE_EXTERNAL_STORAGE
  //     var status = await Permission.manageExternalStorage.request();
  //     if (!status.isGranted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text("Storage permission required ❌")),
  //       );
  //       return;
  //     }
  //
  //     // Capture widget
  //     RenderRepaintBoundary boundary =
  //     _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
  //     ui.Image image = await boundary.toImage(pixelRatio: 3.0);
  //
  //     ByteData? byteData =
  //     await image.toByteData(format: ui.ImageByteFormat.png);
  //     Uint8List pngBytes = byteData!.buffer.asUint8List();
  //
  //     // Save to /Pictures/Passes
  //     final directory = Directory("/storage/emulated/0/Pictures/Passes");
  //     if (!await directory.exists()) {
  //       await directory.create(recursive: true);
  //     }
  //
  //     final filePath =
  //         "${directory.path}/event_pass_${widget.booking.bookingId}.png";
  //     final file = File(filePath);
  //     await file.writeAsBytes(pngBytes);
  //
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text("✅ QR saved to Gallery → Passes")),
  //     );
  //   } catch (e) {
  //     debugPrint("Error saving QR: $e");
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text("Failed to save QR ❌")),
  //     );
  //   }
  // }

  Future<void> savePassToGallery(GlobalKey passKey, String fileName, BuildContext context) async {
    try {
      // Request storage permissions
      var status = await Permission.manageExternalStorage.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Storage permission required ❌")),
        );
        return;
      }

      // Capture widget as image
      RenderRepaintBoundary? boundary =
      passKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Pass not ready yet ❌")),
        );
        return;
      }

      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception("Failed to convert pass to bytes");

      Uint8List pngBytes = byteData.buffer.asUint8List();

      // Save to gallery (Recent)
      final result = await ImageGallerySaverPlus.saveImage(
        pngBytes,
        quality: 100,
        name: fileName,
      );

      if ((result['isSuccess'] ?? false) || (result['filePath'] != null && result['filePath'] != "")) {
        showCustomPopup(context, "Pass saved to Gallery ✅");

        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text("✅ Pass saved to Gallery")),
        // );
      } else {
        throw Exception("Failed to save image");
      }
    } catch (e, s) {
      debugPrint("Error saving pass: $e\n$s");
      showCustomPopup(context, "Failed to save pass ❌");
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text("Failed to save pass ❌")),
      // );
    }
  }
  Future<void> _downloadQR() async {
    try {
      // Request storage permission
      var status = await Permission.manageExternalStorage.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Storage permission required ❌")),
        );
        return;
      }

      // Capture widget
      RenderRepaintBoundary? boundary =
      _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("QR not ready yet ❌")),
        );
        return;
      }

      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData =
      await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception("Failed to convert QR to bytes");
      }

      Uint8List pngBytes = byteData.buffer.asUint8List();

      // Save to /Pictures/Passes
      final directory = Directory("/storage/emulated/0/Pictures/Passes");
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final filePath =
          "${directory.path}/event_pass_${widget.booking.bookingId}.png";
      final file = File(filePath);
      await file.writeAsBytes(pngBytes);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ QR saved to Gallery → Passes")),
      );
    } catch (e, s) {
      debugPrint("Error saving QR: $e\n$s");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to save QR ❌")),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Interval(0.0, 0.6, curve: Curves.elasticOut)),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Interval(0.2, 0.8, curve: Curves.easeOut)),
    );

    _slideAnimation = Tween<Offset>(begin: Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Interval(0.4, 1.0, curve: Curves.easeOutBack)),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0A198D),
              Color(0xFF1E40AF),
              Color(0xFFF8FAFF),
            ],
            stops: [0.0, 0.3, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom App Bar
              _buildCustomAppBar(),

              // Success Animation & Content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      SizedBox(height: 20),

                      // Success Animation
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.check_circle,
                              color: Color(0xFF10B981),
                              size: 60,
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: 20),

                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Text(
                          'Booking Confirmed!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      SizedBox(height: 8),

                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Text(
                          'Your event pass is ready',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                      ),

                      SizedBox(height: 40),
                      SlideTransition(
                        position: _slideAnimation,
                        child: RepaintBoundary(
                          key: _passCardKey,
                          child: Column(
                            children: [
                              _buildDigitalPassCard(),
                              SizedBox(height: 30),
                              _buildQRCodeSection(),
                            ],
                          ),
                        ),
                      ),
                      // // Digital Pass Card
                      // SlideTransition(
                      //   position: _slideAnimation,
                      //   child: _buildDigitalPassCard(),
                      // ),
                      //
                      // SizedBox(height: 30),
                      //
                      // // QR Code Section
                      // SlideTransition(
                      //   position: _slideAnimation,
                      //   child: _buildQRCodeSection(),
                      // ),
                      //
                      // SizedBox(height: 30),

                      // Action Buttons
                      SlideTransition(
                        position: _slideAnimation,
                        child: _buildActionButtons(),
                      ),

                      SizedBox(height: 20),
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

  Widget _buildCustomAppBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Spacer(),
          FadeTransition(
            opacity: _fadeAnimation,
            child: Text(
              'Event Pass',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Spacer(),
          // Container(
          //   decoration: BoxDecoration(
          //     color: Colors.white.withOpacity(0.2),
          //     borderRadius: BorderRadius.circular(12),
          //   ),
          //   child: IconButton(
          //     icon: Icon(Icons.download, color: Colors.white),
          //     onPressed: () => savePassToGallery(_passCardKey, "event_pass_${widget.booking.bookingId}", context),
          //
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget _buildDigitalPassCard() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 25,
            offset: Offset(0, 10),
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Color(0xFFF8FAFF),
              ],
            ),
          ),
          child: Column(
            children: [
              // Header with event image
              Container(
                height: 140,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage(widget.eventImage),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.4),
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                      stops: [0.0, 0.5, 1.0],
                    ),
                  ),
                  padding: EdgeInsets.all(20),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min, // <-- prevents forcing full height
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Color(0xFF10B981),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'CONFIRMED',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '#${widget.booking.bookingId}',
                                style: TextStyle(
                                  color: Color(0xFF0A198D),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 5),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            widget.booking.tournament.toUpperCase(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Pass details
              Container(
                padding: EdgeInsets.all(25),
                child: Column(
                  children: [
                    // Attendee info
                    _buildPassDetailRow(
                      Icons.person_outline,
                      'Attendee',
                      widget.booking.name,
                      isHighlight: true,
                    ),
                    _buildDivider(),

                    // Time slot
                    _buildPassDetailRow(
                      Icons.access_time,
                      'Time Slot',
                      '${widget.booking.startTime} - ${widget.booking.endTime}',
                    ),
                    _buildDivider(),
                    // _buildPassDetailRow(
                    //   Icons.date_range,
                    //   'Date',
                    //   // '${widget.booking.date} - ${widget.booking.endTime}',
                    // ),
                    // _buildDivider(),
                    // Slot name
                    _buildPassDetailRow(
                      Icons.event_seat,
                      'Slot Type',
                      '${widget.booking.slotName} • ${widget.booking.passType}',
                    ),




                    _buildDivider(),

                    // Members count
                    _buildPassDetailRow(
                      Icons.group,
                      'Members',
                      '${widget.booking.membersCount} ${widget.booking.membersCount == 1 ? 'Person' : 'People'}',
                    ),
                    _buildDivider(),

                    // Email
                    _buildPassDetailRow(
                      Icons.email_outlined,
                      'Contact Email',
                      widget.booking.email,
                    ),
                  ],
                ),
              ),

              // Decorative bottom border
              Container(
                height: 8,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0A198D), Color(0xFF1E40AF)],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQRCodeSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 10),
      padding: EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: Offset(0, 8),
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'SCAN AT ENTRANCE',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0A198D),
              letterSpacing: 2,
            ),
          ),

          SizedBox(height: 20),

          // QR Code with animated border
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [
                  Color(0xFF0A198D).withOpacity(0.1),
                  Color(0xFF1E40AF).withOpacity(0.05),
                ],
              ),
              border: Border.all(
                color: Color(0xFF0A198D).withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.network(
                  widget.booking.qrCode,
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 200,
                      height: 200,
                      color: Colors.grey[100],
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.qr_code, color: Colors.grey, size: 60),
                          SizedBox(height: 10),
                          Text(
                            'QR Code\nUnavailable',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      width: 200,
                      height: 200,
                      color: Colors.grey[50],
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0A198D)),
                          strokeWidth: 3,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          SizedBox(height: 20),

          Container(
            padding: EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Color(0xFF0A198D).withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFF0A198D), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Present this QR code at the venue entrance for quick check-in',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF0A198D),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Share button
        Container(
          width: double.infinity,
          margin: EdgeInsets.symmetric(horizontal: 10),
          child: ElevatedButton.icon(
            onPressed: () => _shareEventPass(context),
            icon: Icon(Icons.share, size: 22),
            label: Text(
              "SHARE EVENT PASS",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                fontSize: 16,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF0A198D),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              elevation: 5,
            ),
          ),
        ),

        SizedBox(height: 15),

        // Secondary action button
        Container(
          width: double.infinity,
          margin: EdgeInsets.symmetric(horizontal: 10),
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const CustomBottomNav()),
              );
            },
            icon: Icon(Icons.home, size: 22),
            label: Text(
              "BACK TO HOME",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                fontSize: 16,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Color(0xFF0A198D),
              side: BorderSide(color: Color(0xFF0A198D), width: 2),
              padding: EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPassDetailRow(IconData icon, String title, String value, {bool isHighlight = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isHighlight ? Color(0xFF0A198D) : Color(0xFF0A198D).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 18,
              color: isHighlight ? Colors.white : Color(0xFF0A198D),
            ),
          ),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
                    color: isHighlight ? Color(0xFF0A198D) : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 5),
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            Colors.grey.withOpacity(0.3),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
//   Future<void> _shareEventPass(BuildContext context) async {
//     final appLink = "https://play.google.com/store/apps/details?id=com.nahata_sports_app&pcampaignid=web_share";
//
//     // Helper function to format time (already in your state)
//     String formatTime(String? time) {
//       if (time == null || time.isEmpty) return '';
//       final parts = time.split(":");
//       try {
//         final hour = int.parse(parts[0]);
//         final minute = parts.length > 1 ? int.parse(parts[1]) : 0;
//         final now = DateTime.now();
//         final dt = DateTime(now.year, now.month, now.day, hour, minute);
//         return TimeOfDay.fromDateTime(dt).format(context);
//       } catch (e) {
//         return time; // fallback: return raw string
//       }
//     }
//
//     // Build passes details (replace 'slots' with your list name)
// // Make sure slots list exists
//     final slots = widget.booking.tournament as List<dynamic>? ?? [];
//
//     String passesDetails = slots.map((s) {
//       final start = formatTime(s['start']);
//       final end = formatTime(s['end']);
//       final passType = s['pass_type'] ?? '';
//       final members = s['members_count'] ?? 0;
//       return '$start - $end • $passType • Members: $members';
//     }).join('\n');
//
//     final message = '''
// 🎟️ Your Event Pass for ${widget.booking.tournament}
//
// $passesDetails
//
// Download the app to view your pass securely:
// $appLink
//
// Your referral code: ${widget.booking.userid ?? "N/A"}
// ''';
//
//     try {
//       final response = await http.get(Uri.parse(widget.eventImage));
//       if (response.statusCode == 200) {
//         final tempDir = await getTemporaryDirectory();
//         final file = File('${tempDir.path}/event_image.png');
//         await file.writeAsBytes(response.bodyBytes);
//
//         await Share.shareXFiles([XFile(file.path)], text: message);
//       } else {
//         debugPrint("Failed to download event image, sharing text only");
//         await Share.share(message);
//       }
//     } catch (err) {
//       debugPrint("Error sharing event image: $err");
//       await Share.share(message);
//     }
//
//     if (context.mounted) {
//       showDialog(
//         context: context,
//         barrierDismissible: false,
//         builder: (_) => AlertDialog(
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//           contentPadding: EdgeInsets.all(30),
//           content: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Container(
//                 width: 80,
//                 height: 80,
//                 decoration: BoxDecoration(
//                   color: Color(0xFF10B981),
//                   shape: BoxShape.circle,
//                 ),
//                 child: Icon(Icons.check, color: Colors.white, size: 40),
//               ),
//               SizedBox(height: 20),
//               Text(
//                 "Booking Confirmed",
//                 style: TextStyle(
//                   fontSize: 22,
//                   fontWeight: FontWeight.bold,
//                   color: Color(0xFF0A198D),
//                 ),
//                 textAlign: TextAlign.center,
//               ),
//               SizedBox(height: 10),
//               Text(
//                 "Your event pass has been shared successfully.\n\nSee you at the event!",
//                 style: TextStyle(
//                   fontSize: 16,
//                   color: Colors.grey[600],
//                   height: 1.5,
//                 ),
//                 textAlign: TextAlign.center,
//               ),
//               SizedBox(height: 25),
//               SizedBox(
//                 width: double.infinity,
//                 child: ElevatedButton(
//                   onPressed: () {
//                     Navigator.pop(context);
//                     Navigator.pushReplacement(
//                       context,
//                       MaterialPageRoute(builder: (_) => const CustomBottomNav()),
//                     );
//                   },
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Color(0xFF0A198D),
//                     foregroundColor: Colors.white,
//                     padding: EdgeInsets.symmetric(vertical: 15),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                   ),
//                   child: Text(
//                     "OK",
//                     style: TextStyle(
//                       fontSize: 16,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       );
//     }
//   }
  Future<void> _shareEventPass1(BuildContext context) async {
    final appSchemeLink = "nahatasports://pass/${widget.booking.bookingId}";
    // final playStoreLink = "https://play.google.com/store/apps/details?id=com.nahata_sports_app";
    final playStoreLink = "http://bit.ly/4pEcL3e";
    final message = '''
🎟️ Your Event Pass for ${widget.booking.tournament}
Date & Slot: ${widget.booking.startTime} - ${widget.booking.endTime} (${widget.booking.passType})
Number of Passes: ${widget.booking.membersCount} ${widget.booking.membersCount == 1 ? 'Person' : 'People'}
Download the app to view your pass securely:

$playStoreLink

Your referral code: ${widget.booking.userid ?? "N/A"}
''';

    try {
      final response = await http.get(Uri.parse(widget.eventImage));
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/event_image.png');
        await file.writeAsBytes(response.bodyBytes);

        await Share.shareXFiles([XFile(file.path)], text: message);
      } else {
        await Share.share(message);
      }
    } catch (err) {
      await Share.share(message);
    }

    // Attempt to open app scheme
    if (await canLaunchUrl(Uri.parse(appSchemeLink))) {
      await launchUrl(Uri.parse(appSchemeLink), mode: LaunchMode.externalApplication);
    } else {
      // Fallback to Play Store
      await launchUrl(Uri.parse(playStoreLink), mode: LaunchMode.externalApplication);
    }
  }



  Future<void> _shareEventPass34(BuildContext context) async {
    final playStoreLink =
        "https://play.google.com/store/apps/details?id=com.nahata_sports_app";
    // final appStoreLink =
    //     "https://apps.apple.com/app/idXXXXXXXX"; // Replace with real app store ID

    final message = '''
Your Event Pass for ${widget.booking.tournament}
Date & Slot: ${widget.booking.startTime} - ${widget.booking.endTime} (${widget.booking.passType})
Number of Passes: ${widget.booking.membersCount} ${widget.booking.membersCount == 1 ? 'Pass' : 'Pass'}
QR: Click Here → ${widget.booking.qrCode}

Download the app to view your pass securely:

Play Store - Download Here → $playStoreLink


Your referral code: ${widget.booking.userid ?? "N/A"}
''';

    try {
      final response = await http.get(Uri.parse(widget.booking.qrCode));
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/event_image.png');
        await file.writeAsBytes(response.bodyBytes);

        await Share.shareXFiles([XFile(file.path)], text: message);
      } else {
        debugPrint("Failed to download event image, sharing text only");
        await Share.share(message);
      }
    } catch (err) {
      debugPrint("Error sharing event image: $err");
      await Share.share(message);
    }

    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          contentPadding: EdgeInsets.all(30),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF10B981).withOpacity(0.3),
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(Icons.check, color: Colors.white, size: 40),
              ),
              SizedBox(height: 24),
              Text(
                "Booking Confirmed",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0A198D),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12),
              Text(
                "Your event pass has been shared successfully.\n\nSee you at the event!",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const CustomBottomNav()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF0A198D),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 8,
                    shadowColor: Color(0xFF0A198D).withOpacity(0.3),
                  ),
                  child: Text(
                    "OK",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }





// //////////////////////////////////////////////////////////
  Future<void> _shareEventPass(BuildContext context) async {
 final appLink = "https://play.google.com/store/apps/details?id=com.nahata_sports_app&pcampaignid=web_share";

//
//     final message = '''
//  Your Event Pass for ${widget.booking.tournament}
//  Date & Slot: ${widget.booking.startTime} - ${widget.booking.endTime} (${widget
//         .booking.passType})
//  Number of Passes: ${widget.booking.membersCount} ${widget.booking.membersCount == 1 ? 'Pass' : 'Pass'}
//  QR:${widget.booking.qrCode}
// Download the app to view your pass securely:
//
// $appLink
//
// Your referral code: ${widget.booking.userid ?? "N/A"}
// ''';
//     final qrShortLink = "http://bit.ly/42bMO14"; // shorten QR link if needed
//   final qrShortLink ="https://tinyurl.com/4kmsfe94";
//     final playStoreLink = "https://tinyurl.com/2zrt4h2m";
    // final appStoreLink = "https://apps.apple.com/app/idYOUR_APP_ID"; // replace with your App Store short link if available

// Parse the string into DateTime first
//     final DateTime startTime = DateTime.parse(widget.booking.startTime);
//     final DateTime endTime = DateTime.parse(widget.booking.endTime);

// Then format them in the message
    final message = '''
🎟️ Your Event Pass for ${widget.booking.tournament}
📅 Date & Slot: ${widget.booking.startTime} to ${widget.booking.endTime} (${widget.booking.passType})
👥 Number of Passes: ${widget.booking.membersCount} Pass${widget.booking.membersCount > 1 ? 'es' : ''}
🔗 QR: Click Here (${widget.booking.qrCode})

Download the app to view your pass securely:

📲 Play Store - Download Here ($appLink)

''';


    try {
      final response = await http.get(Uri.parse(widget.booking.qrCode));
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/event_image.png');
        await file.writeAsBytes(response.bodyBytes);

        await Share.shareXFiles([XFile(file.path)], text: message);
      } else {
        debugPrint("Failed to download event image, sharing text only");
        await Share.share(message);
      }
    } catch (err) {
      debugPrint("Error sharing event image: $err");
      await Share.share(message);
    }

    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              contentPadding: EdgeInsets.all(30),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Success animation
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF10B981).withOpacity(0.3),
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(Icons.check, color: Colors.white, size: 40),
                  ),

                  SizedBox(height: 24),

                  Text(
                    "Booking Confirmed",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0A198D),
                    ),
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(height: 12),

                  Text(
                    "Your event pass has been shared successfully.\n\nSee you at the event!",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const CustomBottomNav()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF0A198D),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 8,
                        shadowColor: Color(0xFF0A198D).withOpacity(0.3),
                      ),
                      child: Text(
                        "OK",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
      );
    }
  }
//////////////////////////////////////////////////////////////////
  Future<void> _shareEventPass12(BuildContext context) async {
    final appLink = "https://play.google.com/store/apps/details?id=com.nahata_sports_app&pcampaignid=web_share";

    // Create QR code data - you can customize this URL as needed
    final qrData = widget.booking.qrCode;

    final message = '''
🎟️ Your Event Pass for ${widget.booking.tournament}
📅 Date & Slot: ${widget.booking.startTime} - ${widget.booking.endTime} (${widget.booking.passType})
👥 Number of Passes: ${widget.booking.membersCount} ${widget.booking.membersCount == 1 ? 'Pass' : 'Pass'}
   QR: ${widget.booking.qrCode}
Scan the QR code or download the app to view your pass securely:
$appLink

🔗 Your referral code: ${widget.booking.userid ?? "N/A"}
''';

    try {
      // Generate QR code
      final qrPainter = QrPainter(
        data: qrData,
        version: QrVersions.auto,
        gapless: false,
        color: Color(0xFF0A198D), // Your app's primary color
        emptyColor: Colors.white,
      );

      // Create image from QR code
      const size = 300.0;
      final image = await qrPainter.toImage(size);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        // Save QR code to temporary file
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/event_qr_code.png');
        await file.writeAsBytes(byteData.buffer.asUint8List());

        // Share QR code with message
        await Share.shareXFiles([XFile(file.path)], text: message);
      } else {
        debugPrint("Failed to generate QR code, sharing text only");
        await Share.share(message);
      }
    } catch (err) {
      debugPrint("Error generating QR code: $err");
      await Share.share(message);
    }

    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)
          ),
          contentPadding: EdgeInsets.all(30),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success animation
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF10B981).withOpacity(0.3),
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(Icons.qr_code, color: Colors.white, size: 40),
              ),

              SizedBox(height: 24),

              Text(
                "Booking Confirmed",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0A198D),
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: 12),

              Text(
                "Your event pass with QR code has been shared successfully.\n\nSee you at the event!",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CustomBottomNav()
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF0A198D),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 8,
                    shadowColor: Color(0xFF0A198D).withOpacity(0.3),
                  ),
                  child: Text(
                    "OK",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
//   Future<void> _shareEventPass12(BuildContext context) async {
//     final appLink = "https://play.google.com/store/apps/details?id=com.nahata_sports_app&pcampaignid=web_share";
//
//     // Format date nicely
//     // String formattedDate = DateFormat("dd-MM-yyyy").format(widget.booking.startTime);
//
//     final message = '''
// 🎟️ Your Event Pass for ${widget.booking.tournament}
// 🎫 Pass Type: ${widget.booking.passType}
//    Time:${widget.booking.startTime} - ${widget.booking.endTime}
// 👥 Number of Passes: ${widget.booking.membersCount} ${widget.booking.membersCount == 1 ? 'Pass' : 'Pass'}
//   QR: ${widget.booking.qrCode}
// Download the app to view your pass securely:
// $appLink
//
// Your referral code: ${widget.booking.userid ?? "N/A"}
// ''';
//
//     try {
//       // ✅ Instead of event image, share QR
//      //  final qrValidationResult = QrValidator.validate(
//      // data: widget.booking.qrCode ?? "nahatasports://pass/${widget.booking.bookingId}",
//      //    // deep link or pass ID
//      //    version: QrVersions.auto,
//      //    errorCorrectionLevel: QrErrorCorrectLevel.H,
//      //  );
//      //
//      //  if (qrValidationResult.status == QrValidationStatus.valid) {
//      //    final qrCode = qrValidationResult.qrCode;
//      //    final painter = QrPainter.withQr(
//      //      qr: qrCode!,
//      //      gapless: true,
//      //      color: Colors.black,
//      //      emptyColor: Colors.white,
//      //    );
//      //
//      //    final tempDir = await getTemporaryDirectory();
//      //    final qrFile = File('${tempDir.path}/event_pass_qr.png');
//      //    final picData = await painter.toImageData(400); // QR image size
//      //    await qrFile.writeAsBytes(picData!.buffer.asUint8List());
//      //
//      //    // Share QR + text
//      //    await Share.shareXFiles([XFile(qrFile.path)], text: message);
//      //  } else {
//      //    // fallback to text only
//      //    await Share.share(message);
//      //  }
//
//       final qrValidationResult = QrValidator.validate(
//         data: widget.booking.qrCode ?? "nahatasports://pass/${widget.booking.bookingId}",
//         version: QrVersions.auto,
//         errorCorrectionLevel: QrErrorCorrectLevel.H,
//       );
//
//       if (qrValidationResult.status == QrValidationStatus.valid) {
//         final qrCode = qrValidationResult.qrCode;
//         final painter = QrPainter.withQr(
//           qr: qrCode!,
//           gapless: true,
//           color: Colors.black,
//           emptyColor: Colors.white,
//         );
//
//         // Convert QR to Image
//         final qrImageData = await painter.toImageData(400);
//         final qrImage = await decodeImageFromList(qrImageData!.buffer.asUint8List());
//
//         // ✅ Combine QR + text
//         final pictureRecorder = PictureRecorder();
//         final canvas = Canvas(pictureRecorder);
//         final paint = Paint();
//
//         // Draw white background
//         canvas.drawRect(
//           Rect.fromLTWH(0, 0, 400, 460), // little taller for text
//           paint..color = Colors.white,
//         );
//
//         // Draw QR image
//         canvas.drawImage(qrImage, Offset(0, 0), paint);
//
//         // Draw text (QR string value)
//         // final textPainter = TextPainter(
//         //   text: TextSpan(
//         //     text: widget.booking.qrCode ?? "No QR Data",
//         //     style: TextStyle(
//         //       color: Colors.black,
//         //       fontSize: 16,
//         //       fontWeight: FontWeight.bold,
//         //     ),
//         //   ),
//         //   textDirection: TextDirection.ltr,
//         //   textAlign: TextAlign.center,
//         // )..layout(maxWidth: 400);
//         final textPainter = TextPainter(
//           text: TextSpan(
//             text: widget.booking.qrCode ?? "No QR Data",
//             style: TextStyle(
//               color: Colors.black,
//               fontSize: 16,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           textDirection: TextDirection.ltr, // <-- FIXED
//           textAlign: TextAlign.center,
//         )..layout(maxWidth: 400);
//
//         textPainter.paint(canvas, Offset(200 - textPainter.width / 2, 410));
//
//         // Export to PNG
//         final finalImage = await pictureRecorder.endRecording().toImage(400, 460);
//         final byteData = await finalImage.toByteData(format: ImageByteFormat.png);
//         final pngBytes = byteData!.buffer.asUint8List();
//
//         // Save to temp file
//         final tempDir = await getTemporaryDirectory();
//         final qrFile = File('${tempDir.path}/event_pass_qr.png');
//         await qrFile.writeAsBytes(pngBytes);
//
//         // Share QR + text
//         await Share.shareXFiles([XFile(qrFile.path)], text: message);
//       } else {
//         await Share.share(message);
//       }
//
//     } catch (err) {
//       debugPrint("Error sharing event QR: $err");
//       await Share.share(message);
//     }
//
//     if (context.mounted) {
//       showDialog(
//         context: context,
//         barrierDismissible: false,
//         builder: (_) => AlertDialog(
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(20),
//           ),
//           contentPadding: EdgeInsets.all(30),
//           content: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Container(
//                 width: 80,
//                 height: 80,
//                 decoration: BoxDecoration(
//                   gradient: LinearGradient(
//                     colors: [Color(0xFF10B981), Color(0xFF059669)],
//                   ),
//                   shape: BoxShape.circle,
//                   boxShadow: [
//                     BoxShadow(
//                       color: Color(0xFF10B981).withOpacity(0.3),
//                       blurRadius: 20,
//                       offset: Offset(0, 8),
//                     ),
//                   ],
//                 ),
//                 child: Icon(Icons.check, color: Colors.white, size: 40),
//               ),
//               SizedBox(height: 24),
//               Text(
//                 "Booking Confirmed",
//                 style: TextStyle(
//                   fontSize: 24,
//                   fontWeight: FontWeight.bold,
//                   color: Color(0xFF0A198D),
//                 ),
//                 textAlign: TextAlign.center,
//               ),
//               SizedBox(height: 12),
//               Text(
//                 "Your event pass QR has been shared successfully.\n\nSee you at the event!",
//                 style: TextStyle(
//                   fontSize: 16,
//                   color: Colors.grey[600],
//                   height: 1.5,
//                 ),
//                 textAlign: TextAlign.center,
//               ),
//               SizedBox(height: 30),
//               SizedBox(
//                 width: double.infinity,
//                 child: ElevatedButton(
//                   onPressed: () {
//                     Navigator.pop(context);
//                     Navigator.pushReplacement(
//                       context,
//                       MaterialPageRoute(
//                           builder: (_) => const CustomBottomNav()),
//                     );
//                   },
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Color(0xFF0A198D),
//                     foregroundColor: Colors.white,
//                     padding: EdgeInsets.symmetric(vertical: 16),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     elevation: 8,
//                     shadowColor: Color(0xFF0A198D).withOpacity(0.3),
//                   ),
//                   child: Text(
//                     "OK",
//                     style: TextStyle(
//                       fontSize: 16,
//                       fontWeight: FontWeight.bold,
//                       letterSpacing: 0.5,
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       );
//     }
//   }

// Helper to format time
  String _formatTime(DateTime time) {
    return DateFormat("HH:mm").format(time);
  }

  void showCustomPopup(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false, // prevent closing by tap
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: Colors.greenAccent),
              SizedBox(width: 10),
              Flexible(
                child: Text(
                  message,
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Close the popup after 2 seconds
    Future.delayed(Duration(seconds: 2), () {
      if (Navigator.canPop(context)) Navigator.pop(context);
    });
  }
//   }

//   Future<void> _shareEventPass(BuildContext context) async {
//     final appLink = "https://play.google.com/store/apps/details?id=com.nahata_sports_app&pcampaignid=web_share";
//
//     String membersDetails = widget.booking.members.isNotEmpty
//         ? widget.booking.members.map((m) => '${m['name']} • ${m['passType']}').join('\n')
//         : '${widget.booking.membersCount} ${widget.booking.membersCount == 1 ? 'Person' : 'People'}';
//
//     final message = '''
// 🎟️ Your Event Pass for ${widget.booking.tournament}
//
// Number of passes:
// $membersDetails
//
// Date & Slot: ${widget.booking.startTime} - ${widget.booking.endTime} (${widget.booking.passType})
//
// Download the app to view your pass securely:
// $appLink
// ''';
//
//     try {
//       debugPrint("Event Image URL: ${widget.booking.eventImage}");
//
//       final response = await http.get(Uri.parse(widget.booking.eventImage));
//       if (response.statusCode == 200) {
//         final tempDir = await getTemporaryDirectory();
//         final file = File('${tempDir.path}/event_image.jpg');
//         await file.writeAsBytes(response.bodyBytes, flush: true);
//
//         debugPrint("Event image saved at: ${file.path}");
//
//         await Share.shareXFiles(
//           [XFile(file.path, mimeType: "image/jpeg")],
//           text: message,
//         );
//       } else {
//         debugPrint("❌ Failed to download event image. Status: ${response.statusCode}");
//         await Share.share(message);
//       }
//     } catch (err) {
//       debugPrint("❌ Error sharing event image: $err");
//       await Share.share(message);
//     }
//   }
}


// class BookingData {
//   final String bookingId;
//   final String name;
//   final String email;
//   final int membersCount;
//   final String tournament;
//   final String slotName;
//   final String startTime;
//   final String endTime;
//   final String qrCode;
//   final String? userid;
//   final String eventImage;
//   final String passType; // 👈 NEW FIELD
//
//   BookingData({
//     required this.bookingId,
//     required this.name,
//     required this.email,
//     required this.membersCount,
//     required this.tournament,
//     required this.slotName,
//     required this.startTime,
//     required this.endTime,
//     required this.qrCode,
//     this.userid,
//     required this.eventImage,
//     required this.passType, // 👈 required
//   });
//
//   factory BookingData.fromJson(Map<String, dynamic> json) {
//     final slot = json['slot'] ?? {};
//     return BookingData(
//       userid: json['user_id']?.toString(),
//       bookingId: json['booking_id'].toString(),
//       name: json['name'] ?? '',
//       email: json['email'] ?? '',
//       membersCount: int.tryParse(json['members_count'].toString()) ?? 0,
//       tournament: json['tournament'] ?? '',
//       slotName: slot['slot_name'] ?? '',
//       startTime: slot['start_time'] ?? '',
//       endTime: slot['end_time'] ?? '',
//       qrCode: json['qr_code'] ?? '',
//       eventImage: json['event_image'] ?? '',
//       passType: slot['pass_type'] ?? '', // 👈 map pass_type
//     );
//   }
// }

class BookingData {
  final String bookingId;
  final String name;
  final String email;
  final int membersCount;
  final String tournament;
  final String slotName;
  final String startTime;
  final String endTime;
  final String qrCode;
  final String? userid;
  final String eventImage;
  final String passType;

  // New: list of members with name & passType
  final List<Map<String, String>> members;

  BookingData({
    required this.bookingId,
    required this.name,
    required this.email,
    required this.membersCount,
    required this.tournament,
    required this.slotName,
    required this.startTime,
    required this.endTime,
    required this.qrCode,
    this.userid,
    required this.passType,
    required this.eventImage,
    required this.members,
  });

  factory BookingData.fromJson(Map<String, dynamic> json) {
    final slot = json['slot'] ?? {};

    // Parse members list from JSON
    List<Map<String, String>> parsedMembers = [];
    if (json['members'] != null && json['members'] is List) {
      parsedMembers = List<Map<String, String>>.from(
        (json['members'] as List).map((m) => {
          'name': m['name']?.toString() ?? '',
          'passType': m['pass_type']?.toString() ?? '',
        }),
      );
    }

    return BookingData(
      userid: json['user_id']?.toString() ?? ApiService.currentUser?['id'].toString(),
      bookingId: json['booking_id'].toString(),
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      membersCount: int.tryParse(json['members_count'].toString()) ?? 0,
      tournament: json['tournament'] ?? '',
      slotName: slot['slot_name'] ?? '',
      startTime: slot['start_time'] ?? '',
      endTime: slot['end_time'] ?? '',
      qrCode: json['qr_code'] ?? '',
      eventImage: json['event_image'] ?? '',
      members: parsedMembers,
      passType: slot['pass_type'] ?? '',
    );
  }
}

// class BookingData {
//   final String bookingId;
//   final String name;
//   final String email;
//   final int membersCount;
//   final String tournament;
//   final String slotName;
//   final String startTime;
//   final String endTime;
//   final String qrCode;
//   final String? userid;
//   final String eventImage; // <-- add this
//
//
//   BookingData({
//     required this.bookingId,
//     required this.name,
//     required this.email,
//     required this.membersCount,
//     required this.tournament,
//     required this.slotName,
//     required this.startTime,
//     required this.endTime,
//     required this.qrCode,
//     this.userid,
//     required this.eventImage,
//   });
//
//   factory BookingData.fromJson(Map<String, dynamic> json) {
//     final slot = json['slot'] ?? {};
//     return BookingData(
//       userid: json['user_id']?.toString() ?? ApiService.currentUser?['id'].toString(), // fallback to logged-in user id
//
//       bookingId: json['booking_id'].toString(),
//       name: json['name'] ?? '',
//       email: json['email'] ?? '',
//       membersCount: int.tryParse(json['members_count'].toString()) ?? 0,
//       tournament: json['tournament'] ?? '',
//       slotName: slot['slot_name'] ?? '',
//       startTime: slot['start_time'] ?? '',
//       endTime: slot['end_time'] ?? '',
//       qrCode: json['qr_code'] ?? '',
//       eventImage: json['event_image'] ?? '',
//     );
//   }
// }











// class EventPassPage extends StatefulWidget {
//   final BookingData booking;
//   final String eventImage;
//
//   const EventPassPage({
//     required this.booking,
//     required this.eventImage,
//     super.key,
//   });
//
//   @override
//   State<EventPassPage> createState() => _EventPassPageState();
// }
//
// class _EventPassPageState extends State<EventPassPage>
//     with TickerProviderStateMixin {
//   late AnimationController _mainController;
//   late AnimationController _pulseController;
//   late Animation<double> _fadeAnimation;
//   late Animation<Offset> _slideAnimation;
//   late Animation<double> _scaleAnimation;
//   late Animation<double> _pulseAnimation;
//
//   @override
//   void initState() {
//     super.initState();
//
//     // Main animation controller
//     _mainController = AnimationController(
//       duration: Duration(milliseconds: 1500),
//       vsync: this,
//     );
//
//     // Pulse animation for QR code
//     _pulseController = AnimationController(
//       duration: Duration(milliseconds: 2000),
//       vsync: this,
//     );
//
//     _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
//       CurvedAnimation(
//         parent: _mainController,
//         curve: Interval(0.0, 0.6, curve: Curves.easeOut),
//       ),
//     );
//
//     _slideAnimation = Tween<Offset>(
//       begin: Offset(0, 0.3),
//       end: Offset.zero,
//     ).animate(
//       CurvedAnimation(
//         parent: _mainController,
//         curve: Interval(0.3, 1.0, curve: Curves.elasticOut),
//       ),
//     );
//
//     _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
//       CurvedAnimation(
//         parent: _mainController,
//         curve: Interval(0.0, 0.8, curve: Curves.elasticOut),
//       ),
//     );
//
//     _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
//       CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
//     );
//
//     _mainController.forward();
//     _pulseController.repeat(reverse: true);
//   }
//
//   @override
//   void dispose() {
//     _mainController.dispose();
//     _pulseController.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Container(
//         decoration: BoxDecoration(
//           gradient: LinearGradient(
//             begin: Alignment.topCenter,
//             end: Alignment.bottomCenter,
//             colors: [
//               Color(0xFF0A198D),
//               Color(0xFF1E40AF),
//               Colors.white,
//             ],
//             stops: [0.0, 0.4, 1.0],
//           ),
//         ),
//         child: SafeArea(
//           child: Column(
//             children: [
//               // Enhanced App Bar
//               _buildEnhancedAppBar(),
//
//               // Main Content
//               Expanded(
//                 child: FadeTransition(
//                   opacity: _fadeAnimation,
//                   child: SlideTransition(
//                     position: _slideAnimation,
//                     child: SingleChildScrollView(
//                       padding: EdgeInsets.fromLTRB(16, 20, 16, 20),
//                       child: Column(
//                         children: [
//                           // Success Badge
//                           _buildSuccessBadge(),
//                           SizedBox(height: 30),
//
//                           // Digital Pass Card
//                           ScaleTransition(
//                             scale: _scaleAnimation,
//                             child: _buildDigitalPassCard(),
//                           ),
//                           SizedBox(height: 30),
//
//                           // QR Code Section
//                           _buildEnhancedQRSection(),
//                           SizedBox(height: 30),
//
//                           // Action Buttons
//                           _buildActionButtons(),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildEnhancedAppBar() {
//     return Container(
//       padding: EdgeInsets.all(16),
//       child: Row(
//         children: [
//           Container(
//             decoration: BoxDecoration(
//               color: Colors.white.withOpacity(0.15),
//               borderRadius: BorderRadius.circular(12),
//               border: Border.all(color: Colors.white.withOpacity(0.2)),
//             ),
//             child: IconButton(
//               icon: Icon(Icons.arrow_back, color: Colors.white),
//               onPressed: () => Navigator.pop(context),
//             ),
//           ),
//           Spacer(),
//           FadeTransition(
//             opacity: _fadeAnimation,
//             child: Column(
//               children: [
//                 Text(
//                   'Event Pass',
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontSize: 20,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 Container(
//                   margin: EdgeInsets.only(top: 4),
//                   height: 2,
//                   width: 40,
//                   decoration: BoxDecoration(
//                     color: Colors.white,
//                     borderRadius: BorderRadius.circular(1),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           Spacer(),
//           Container(
//             decoration: BoxDecoration(
//               color: Colors.white.withOpacity(0.15),
//               borderRadius: BorderRadius.circular(12),
//               border: Border.all(color: Colors.white.withOpacity(0.2)),
//             ),
//             child: IconButton(
//               icon: Icon(Icons.share, color: Colors.white),
//               onPressed: () => _shareEventPass(context),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildSuccessBadge() {
//     return Container(
//       padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(30),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.1),
//             blurRadius: 20,
//             offset: Offset(0, 8),
//           ),
//         ],
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Container(
//             width: 24,
//             height: 24,
//             decoration: BoxDecoration(
//               color: Color(0xFF10B981),
//               shape: BoxShape.circle,
//             ),
//             child: Icon(Icons.check, color: Colors.white, size: 16),
//           ),
//           SizedBox(width: 12),
//           Text(
//             'Booking Confirmed!',
//             style: TextStyle(
//               color: Color(0xFF10B981),
//               fontWeight: FontWeight.bold,
//               fontSize: 16,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildDigitalPassCard() {
//     return Container(
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(24),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.15),
//             blurRadius: 30,
//             offset: Offset(0, 15),
//             spreadRadius: 0,
//           ),
//         ],
//       ),
//       child: ClipRRect(
//         borderRadius: BorderRadius.circular(24),
//         child: Container(
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(24),
//           ),
//           child: Column(
//             children: [
//               // Header with event image
//               _buildPassHeader(),
//
//               // Pass content
//               _buildPassContent(),
//
//               // Decorative footer
//               Container(
//                 height: 6,
//                 decoration: BoxDecoration(
//                   gradient: LinearGradient(
//                     colors: [
//                       Color(0xFF0A198D),
//                       Color(0xFF1E40AF),
//                       Color(0xFF3B82F6),
//                     ],
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildPassHeader() {
//     return Container(
//       height: 160,
//       child: Stack(
//         children: [
//           // Background image
//           Container(
//             decoration: BoxDecoration(
//               image: DecorationImage(
//                 image: NetworkImage(widget.eventImage),
//                 fit: BoxFit.cover,
//               ),
//             ),
//           ),
//
//           // Gradient overlay
//           Container(
//             decoration: BoxDecoration(
//               gradient: LinearGradient(
//                 begin: Alignment.topCenter,
//                 end: Alignment.bottomCenter,
//                 colors: [
//                   Colors.black.withOpacity(0.4),
//                   Colors.transparent,
//                   Colors.black.withOpacity(0.8),
//                 ],
//                 stops: [0.0, 0.5, 1.0],
//               ),
//             ),
//           ),
//
//           // Content
//           Padding(
//             padding: EdgeInsets.all(20),
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Container(
//                       padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                       decoration: BoxDecoration(
//                         color: Color(0xFF10B981),
//                         borderRadius: BorderRadius.circular(20),
//                       ),
//                       child: Text(
//                         'CONFIRMED',
//                         style: TextStyle(
//                           color: Colors.white,
//                           fontSize: 11,
//                           fontWeight: FontWeight.bold,
//                           letterSpacing: 1.5,
//                         ),
//                       ),
//                     ),
//                     Container(
//                       padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                       decoration: BoxDecoration(
//                         color: Colors.white.withOpacity(0.9),
//                         borderRadius: BorderRadius.circular(20),
//                       ),
//                       child: Text(
//                         '#${widget.booking.bookingId}',
//                         style: TextStyle(
//                           color: Color(0xFF0A198D),
//                           fontSize: 11,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//
//                 Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       widget.booking.tournament.toUpperCase(),
//                       style: TextStyle(
//                         color: Colors.white,
//                         fontSize: 22,
//                         fontWeight: FontWeight.bold,
//                         letterSpacing: 1.2,
//                         shadows: [
//                           Shadow(
//                             color: Colors.black.withOpacity(0.5),
//                             blurRadius: 10,
//                           ),
//                         ],
//                       ),
//                     ),
//                     SizedBox(height: 4),
//                     Text(
//                       'Digital Event Pass',
//                       style: TextStyle(
//                         color: Colors.white70,
//                         fontSize: 14,
//                         letterSpacing: 0.5,
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildPassContent() {
//     return Padding(
//       padding: EdgeInsets.all(24),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Primary info
//           _buildEnhancedDetailRow(
//             Icons.person_outline,
//             'Attendee Name',
//             widget.booking.name,
//             isPrimary: true,
//           ),
//
//           SizedBox(height: 20),
//
//           // Time details
//           Row(
//             children: [
//               Expanded(
//                 child: _buildInfoCard(
//                   Icons.access_time_outlined,
//                   'Time Slot',
//                   '${widget.booking.startTime} - ${widget.booking.endTime}',
//                   Color(0xFF3B82F6),
//                 ),
//               ),
//               SizedBox(width: 12),
//               Expanded(
//                 child: _buildInfoCard(
//                   Icons.event_seat_outlined,
//                   'Slot Type',
//                   widget.booking.slotName,
//                   Color(0xFF8B5CF6),
//                 ),
//               ),
//             ],
//           ),
//
//           SizedBox(height: 16),
//
//           // Additional info
//           Row(
//             children: [
//               Expanded(
//                 child: _buildInfoCard(
//                   Icons.group_outlined,
//                   'Members',
//                   '${widget.booking.membersCount} ${widget.booking.membersCount == 1 ? 'Person' : 'People'}',
//                   Color(0xFF10B981),
//                 ),
//               ),
//               SizedBox(width: 12),
//               Expanded(
//                 child: _buildInfoCard(
//                   Icons.email_outlined,
//                   'Contact',
//                   widget.booking.email.length > 20
//                       ? '${widget.booking.email.substring(0, 20)}...'
//                       : widget.booking.email,
//                   Color(0xFFF59E0B),
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildInfoCard(IconData icon, String title, String value, Color color) {
//     return Container(
//       padding: EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: color.withOpacity(0.08),
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: color.withOpacity(0.2)),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Icon(icon, color: color, size: 18),
//               SizedBox(width: 6),
//               Expanded(
//                 child: Text(
//                   title,
//                   style: TextStyle(
//                     color: color,
//                     fontSize: 12,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           SizedBox(height: 8),
//           Text(
//             value,
//             style: TextStyle(
//               color: Colors.black87,
//               fontSize: 14,
//               fontWeight: FontWeight.w600,
//             ),
//             maxLines: 2,
//             overflow: TextOverflow.ellipsis,
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildEnhancedDetailRow(IconData icon, String title, String value, {bool isPrimary = false}) {
//     return Container(
//       padding: EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         gradient: isPrimary
//             ? LinearGradient(
//           colors: [
//             Color(0xFF0A198D).withOpacity(0.1),
//             Color(0xFF1E40AF).withOpacity(0.05),
//           ],
//         )
//             : null,
//         color: isPrimary ? null : Colors.grey[50],
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(
//           color: isPrimary ? Color(0xFF0A198D).withOpacity(0.2) : Colors.grey.withOpacity(0.2),
//         ),
//       ),
//       child: Row(
//         children: [
//           Container(
//             padding: EdgeInsets.all(10),
//             decoration: BoxDecoration(
//               color: isPrimary ? Color(0xFF0A198D) : Colors.grey[400],
//               borderRadius: BorderRadius.circular(12),
//             ),
//             child: Icon(
//               icon,
//               color: Colors.white,
//               size: 20,
//             ),
//           ),
//           SizedBox(width: 16),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   title,
//                   style: TextStyle(
//                     fontSize: 12,
//                     color: Colors.grey[600],
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//                 SizedBox(height: 4),
//                 Text(
//                   value,
//                   style: TextStyle(
//                     fontSize: 16,
//                     fontWeight: FontWeight.bold,
//                     color: isPrimary ? Color(0xFF0A198D) : Colors.black87,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildEnhancedQRSection() {
//     return Container(
//       padding: EdgeInsets.all(24),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(24),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.1),
//             blurRadius: 30,
//             offset: Offset(0, 15),
//           ),
//         ],
//       ),
//       child: Column(
//         children: [
//           // Header
//           Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Icon(Icons.qr_code_scanner, color: Color(0xFF0A198D), size: 24),
//               SizedBox(width: 12),
//               Text(
//                 'SCAN AT ENTRANCE',
//                 style: TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.bold,
//                   color: Color(0xFF0A198D),
//                   letterSpacing: 1.5,
//                 ),
//               ),
//             ],
//           ),
//
//           SizedBox(height: 24),
//
//           // QR Code with animated border
//           AnimatedBuilder(
//             animation: _pulseAnimation,
//             builder: (context, child) {
//               return Transform.scale(
//                 scale: _pulseAnimation.value,
//                 child: Container(
//                   padding: EdgeInsets.all(20),
//                   decoration: BoxDecoration(
//                     gradient: LinearGradient(
//                       colors: [
//                         Color(0xFF0A198D).withOpacity(0.1),
//                         Color(0xFF1E40AF).withOpacity(0.05),
//                       ],
//                     ),
//                     borderRadius: BorderRadius.circular(20),
//                     border: Border.all(
//                       color: Color(0xFF0A198D).withOpacity(0.3),
//                       width: 2,
//                     ),
//                   ),
//                   child: Container(
//                     padding: EdgeInsets.all(16),
//                     decoration: BoxDecoration(
//                       color: Colors.white,
//                       borderRadius: BorderRadius.circular(16),
//                       boxShadow: [
//                         BoxShadow(
//                           color: Colors.black.withOpacity(0.08),
//                           blurRadius: 15,
//                           spreadRadius: 2,
//                         ),
//                       ],
//                     ),
//                     child: Image.network(
//                       widget.booking.qrCode,
//                       width: 200,
//                       height: 200,
//                       fit: BoxFit.contain,
//                       errorBuilder: (context, error, stackTrace) {
//                         return Container(
//                           width: 200,
//                           height: 200,
//                           decoration: BoxDecoration(
//                             color: Colors.grey[100],
//                             borderRadius: BorderRadius.circular(12),
//                           ),
//                           child: Column(
//                             mainAxisAlignment: MainAxisAlignment.center,
//                             children: [
//                               Icon(Icons.qr_code, color: Colors.grey[400], size: 60),
//                               SizedBox(height: 12),
//                               Text(
//                                 'QR Code\nUnavailable',
//                                 textAlign: TextAlign.center,
//                                 style: TextStyle(
//                                   color: Colors.grey[600],
//                                   fontSize: 14,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         );
//                       },
//                       loadingBuilder: (context, child, loadingProgress) {
//                         if (loadingProgress == null) return child;
//                         return Container(
//                           width: 200,
//                           height: 200,
//                           decoration: BoxDecoration(
//                             color: Colors.grey[50],
//                             borderRadius: BorderRadius.circular(12),
//                           ),
//                           child: Center(
//                             child: Column(
//                               mainAxisAlignment: MainAxisAlignment.center,
//                               children: [
//                                 CircularProgressIndicator(
//                                   valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0A198D)),
//                                   strokeWidth: 3,
//                                 ),
//                                 SizedBox(height: 12),
//                                 Text(
//                                   'Loading QR Code...',
//                                   style: TextStyle(
//                                     color: Colors.grey[600],
//                                     fontSize: 12,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         );
//                       },
//                     ),
//                   ),
//                 ),
//               );
//             },
//           ),
//
//           SizedBox(height: 24),
//
//           // Instructions
//           Container(
//             padding: EdgeInsets.all(16),
//             decoration: BoxDecoration(
//               color: Color(0xFFF0F9FF),
//               borderRadius: BorderRadius.circular(16),
//               border: Border.all(color: Color(0xFF0A198D).withOpacity(0.1)),
//             ),
//             child: Row(
//               children: [
//                 Icon(Icons.info_outline, color: Color(0xFF0A198D), size: 20),
//                 SizedBox(width: 12),
//                 Expanded(
//                   child: Text(
//                     'Present this QR code at the venue entrance for quick and secure check-in',
//                     style: TextStyle(
//                       fontSize: 14,
//                       color: Color(0xFF0A198D),
//                       height: 1.4,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildActionButtons() {
//     return Column(
//       children: [
//         // Primary action - Share
//         Container(
//           width: double.infinity,
//           child: ElevatedButton.icon(
//             onPressed: () => _shareEventPass(context),
//             icon: Icon(Icons.share, size: 22),
//             label: Text(
//               "SHARE EVENT PASS",
//               style: TextStyle(
//                 fontWeight: FontWeight.bold,
//                 letterSpacing: 1.2,
//                 fontSize: 16,
//               ),
//             ),
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Color(0xFF0A198D),
//               foregroundColor: Colors.white,
//               padding: EdgeInsets.symmetric(vertical: 18),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(16),
//               ),
//               elevation: 8,
//               shadowColor: Color(0xFF0A198D).withOpacity(0.3),
//             ),
//           ),
//         ),
//
//         SizedBox(height: 16),
//
//         // Secondary action - Home
//         Container(
//           width: double.infinity,
//           child: OutlinedButton.icon(
//             onPressed: () {
//               // Navigator.pushReplacement(
//               //   context,
//               //   MaterialPageRoute(builder: (_) => const BookPlayScreen()),
//               // );
//             },
//             icon: Icon(Icons.home_outlined, size: 22),
//             label: Text(
//               "BACK TO HOME",
//               style: TextStyle(
//                 fontWeight: FontWeight.bold,
//                 letterSpacing: 1.2,
//                 fontSize: 16,
//               ),
//             ),
//             style: OutlinedButton.styleFrom(
//               foregroundColor: Color(0xFF0A198D),
//               side: BorderSide(color: Color(0xFF0A198D), width: 2),
//               padding: EdgeInsets.symmetric(vertical: 18),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(16),
//               ),
//               backgroundColor: Colors.white,
//             ),
//           ),
//         ),
//       ],
//     );
//   }
//
//   Future<void> _shareEventPass(BuildContext context) async {
//     final appLink = "https://play.google.com/store/apps/details?id=com.nahata_sports_app&pcampaignid=web_share";
//
//     final message = '''
// 🎟️ Your Event Pass for ${widget.booking.tournament}
//  Date & Slot: ${widget.booking.startTime} - ${widget.booking.endTime} (${widget.booking.slotName})
// Download the app to view your pass securely:
//
// $appLink
//
// Your referral code: ${widget.booking.userid ?? "N/A"}
// ''';
//
//     try {
//       final response = await http.get(Uri.parse(widget.eventImage));
//       if (response.statusCode == 200) {
//         final tempDir = await getTemporaryDirectory();
//         final file = File('${tempDir.path}/event_image.png');
//         await file.writeAsBytes(response.bodyBytes);
//
//         await Share.shareXFiles([XFile(file.path)], text: message);
//       } else {
//         debugPrint("Failed to download event image, sharing text only");
//         await Share.share(message);
//       }
//     } catch (err) {
//       debugPrint("Error sharing event image: $err");
//       await Share.share(message);
//     }
//
//     if (context.mounted) {
//       showDialog(
//         context: context,
//         barrierDismissible: false,
//         builder: (_) => AlertDialog(
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//           contentPadding: EdgeInsets.all(30),
//           content: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               // Success animation
//               Container(
//                 width: 80,
//                 height: 80,
//                 decoration: BoxDecoration(
//                   gradient: LinearGradient(
//                     colors: [Color(0xFF10B981), Color(0xFF059669)],
//                   ),
//                   shape: BoxShape.circle,
//                   boxShadow: [
//                     BoxShadow(
//                       color: Color(0xFF10B981).withOpacity(0.3),
//                       blurRadius: 20,
//                       offset: Offset(0, 8),
//                     ),
//                   ],
//                 ),
//                 child: Icon(Icons.check, color: Colors.white, size: 40),
//               ),
//
//               SizedBox(height: 24),
//
//               Text(
//                 "Booking Confirmed",
//                 style: TextStyle(
//                   fontSize: 24,
//                   fontWeight: FontWeight.bold,
//                   color: Color(0xFF0A198D),
//                 ),
//                 textAlign: TextAlign.center,
//               ),
//
//               SizedBox(height: 12),
//
//               Text(
//                 "Your event pass has been shared successfully.\n\nSee you at the event!",
//                 style: TextStyle(
//                   fontSize: 16,
//                   color: Colors.grey[600],
//                   height: 1.5,
//                 ),
//                 textAlign: TextAlign.center,
//               ),
//
//               SizedBox(height: 30),
//
//               SizedBox(
//                 width: double.infinity,
//                 child: ElevatedButton(
//                   onPressed: () {
//                     Navigator.pop(context);
//                     Navigator.pushReplacement(
//                       context,
//                       MaterialPageRoute(builder: (_) => const BookPlayScreen()),
//                     );
//                   },
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Color(0xFF0A198D),
//                     foregroundColor: Colors.white,
//                     padding: EdgeInsets.symmetric(vertical: 16),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     elevation: 8,
//                     shadowColor: Color(0xFF0A198D).withOpacity(0.3),
//                   ),
//                   child: Text(
//                     "OK",
//                     style: TextStyle(
//                       fontSize: 16,
//                       fontWeight: FontWeight.bold,
//                       letterSpacing: 0.5,
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       );
//     }
//   }
// }





























// Future<void> _shareEventPass(BuildContext context) async {
//   final appLink = "https://play.google.com/store/apps/details?id=com.nahata_sports_app&pcampaignid=web_share";
//
//   // Build members details
//   String membersDetails = '';
//   if (widget.booking.members.isNotEmpty) {
//     membersDetails = widget.booking.members.map((m) {
//       return '${m['name']} • ${m['passType']}';
//     }).join('\n');
//   } else {
//     // fallback if members list is empty
//     membersDetails = '${widget.booking.membersCount} ${widget.booking.membersCount == 1 ? 'Person' : 'People'}';
//   }
//
//   final message = '''
// 🎟️ Your Event Pass for ${widget.booking.tournament}
//
// Members:
// $membersDetails
//
// Date & Slot: ${widget.booking.startTime} - ${widget.booking.endTime} (${widget.booking.slotName})
//
// Download the app to view your pass securely:
// $appLink
//
// Your referral code: ${widget.booking.userid ?? "N/A"}
// ''';
//
//   try {
//     final response = await http.get(Uri.parse(widget.booking.eventImage));
//     if (response.statusCode == 200) {
//       final tempDir = await getTemporaryDirectory();
//       final file = File('${tempDir.path}/event_image.png');
//       await file.writeAsBytes(response.bodyBytes);
//
//       await Share.shareXFiles([XFile(file.path)], text: message);
//     } else {
//       debugPrint("Failed to download event image, sharing text only");
//       await Share.share(message);
//     }
//   } catch (err) {
//     debugPrint("Error sharing event image: $err");
//     await Share.share(message);
//   }
//
//   if (context.mounted) {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (_) => AlertDialog(
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//         contentPadding: EdgeInsets.all(30),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Container(
//               width: 80,
//               height: 80,
//               decoration: BoxDecoration(
//                 color: Color(0xFF10B981),
//                 shape: BoxShape.circle,
//               ),
//               child: Icon(Icons.check, color: Colors.white, size: 40),
//             ),
//             SizedBox(height: 20),
//             Text(
//               "Booking Confirmed",
//               style: TextStyle(
//                 fontSize: 22,
//                 fontWeight: FontWeight.bold,
//                 color: Color(0xFF0A198D),
//               ),
//               textAlign: TextAlign.center,
//             ),
//             SizedBox(height: 10),
//             Text(
//               "Your event pass has been shared successfully.\n\nSee you at the event!",
//               style: TextStyle(
//                 fontSize: 16,
//                 color: Colors.grey[600],
//                 height: 1.5,
//               ),
//               textAlign: TextAlign.center,
//             ),
//             SizedBox(height: 25),
//             SizedBox(
//               width: double.infinity,
//               child: ElevatedButton(
//                 onPressed: () {
//                   Navigator.pop(context);
//                   Navigator.pushReplacement(
//                     context,
//                     MaterialPageRoute(builder: (_) => const CustomBottomNav()),
//                   );
//                 },
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Color(0xFF0A198D),
//                   foregroundColor: Colors.white,
//                   padding: EdgeInsets.symmetric(vertical: 15),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                 ),
//                 child: Text(
//                   "OK",
//                   style: TextStyle(
//                     fontSize: 16,
//                     fontWeight: FontWeight.bold,
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