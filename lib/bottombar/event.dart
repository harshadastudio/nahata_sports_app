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
import 'package:nahata_app/core/network/http_logged.dart' as http;
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
import '../core/network/api_exception.dart';
import '../core/services/selected_ground.dart';
import '../models/coupon_model.dart';
import '../models/event_booking_model.dart';
import '../models/event_pass_model.dart';
import '../models/sports_complex_model.dart';
import '../repositories/coupon_repository.dart';
import '../repositories/event_booking_repository.dart';
import '../repositories/event_repository.dart';
import '../repositories/payment_repository.dart';

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

  /// Slots come embedded in `/event-passes`, so the details page no longer
  /// needs a second request. Shape matches what the booking UI reads.
  final List<Map<String, dynamic>> slots;

  /// Question/answer pairs from the API.
  final List<EventFaq> faqs;

  /// Venue id, needed by venue-scoped coupons.
  final int? sportComplexId;

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
    this.slots = const <Map<String, dynamic>>[],
    this.faqs = const <EventFaq>[],
    this.sportComplexId,
  });

  /// Builds the view model from an `/event-passes` record.
  factory EventModel.fromEventPass(EventPassModel pass) {
    return EventModel(
      id: pass.id?.toString() ?? '',
      title: pass.title ?? '',
      // The API returns absolute URLs already.
      image: pass.image ?? '',
      location: pass.venueName ?? 'Nahata Sports Complex',
      description: pass.description ?? '',
      slots: pass.activeSlots
          .map((s) => s.toBookingMap())
          .toList(growable: false),
      faqs: pass.faqs,
      sportComplexId: pass.sportComplexId,
    );
  }
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

    final formatted = buffer.toString().trim();

    // Descriptions that use none of the labelled sections (the new API sends
    // plain prose) would otherwise render as an empty block.
    return formatted.isEmpty ? content.trim() : formatted;
  }



}

/* -------------------------------------------
   API Service
   ------------------------------------------- */
// Future<List<EventModel>> fetchEvents() async {
//   final res = await http.get(Uri.parse("https://nahatasports.com/api/tournaments"));
//   if (res.statusCode != 200) throw Exception("Failed to load events");
//
//   final body = jsonDecode(res.body);
//   final List data = body['data'] ?? [];
//   return data.map((e) => EventModel.fromJson(e)).toList();
// }
/// Loads events from `GET /event-passes`.
///
/// [status] keeps the screen's two tabs working:
/// * `"active"`   — every active event pass,
/// * `"upcoming"` — active passes that still have a slot dated today or later,
///   ordered by their earliest slot. The API exposes only an Active/Inactive
///   status, so "upcoming" is derived from the embedded slot dates.
///
/// Results are limited to the venue the user selected, when there is one.
Future<List<EventModel>> fetchEvents({
  required String status,
  int? sportComplexId,
  bool filterBySelectedVenue = true,
}) async {
  final repository = EventRepository.instance;

  final complexId = sportComplexId ??
      (filterBySelectedVenue ? await repository.resolveSelectedComplexId() : null);

  final passes = await repository.fetchEventPasses(
    status: 'Active',
    sportComplexId: complexId,
  );

  final upcomingOnly = status.toLowerCase() == 'upcoming';

  final selected =
      upcomingOnly ? passes.where((p) => p.hasUpcomingSlot).toList() : passes;

  if (upcomingOnly) {
    selected.sort((a, b) {
      final left = a.earliestSlotDate;
      final right = b.earliestSlotDate;
      if (left == null && right == null) return 0;
      if (left == null) return 1;
      if (right == null) return -1;
      return left.compareTo(right);
    });
  }

  return selected.map(EventModel.fromEventPass).toList(growable: false);
}

/* -------------------------------------------

 */
class EventsScreen    extends StatefulWidget {
  @override
  _EventsScreenState createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen>
    with SingleTickerProviderStateMixin {



  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  int selectedTab = 0;

  late Future<List<EventModel>> _futureEvents;

  /// Sentinel for the "All complexes" entry — PopupMenuButton needs a non-null
  /// value, while "no filter" is a null venue everywhere else.
  static const int _allVenues = -1;

  List<SportsComplex> _venues = const [];
  bool _loadingVenues = true;

  /// Sports-complex id the list is currently scoped to; null means all.
  int? _venueId;

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

    _futureEvents = fetchEvents(status: "active");
    _loadVenues();
  }

  /// Venue list for the picker, plus the venue the app is already scoped to.
  Future<void> _loadVenues() async {
    final repository = EventRepository.instance;
    final venues = await repository.fetchVenues();
    final selectedId = await repository.resolveSelectedComplexId();
    if (!mounted) return;

    setState(() {
      _venues = venues;
      _venueId = selectedId;
      _loadingVenues = false;
    });
  }

  /// Events for [status], scoped to the venue the picker is showing.
  Future<List<EventModel>> _loadEvents(String status) {
    if (_loadingVenues) return fetchEvents(status: status);
    return fetchEvents(
      status: status,
      sportComplexId: _venueId,
      filterBySelectedVenue: false,
    );
  }

  /// Switches venue: remembers the choice, then reloads the list.
  Future<void> _onVenueSelected(int value) async {
    final id = value == _allVenues ? null : value;
    if (id == _venueId) return;

    final venue = _venues.where((v) => v.id == id).firstOrNull;
    await SelectedGround.instance.save(venue?.name, id: venue?.id);
    if (!mounted) return;

    setState(() {
      _venueId = id;
      _futureEvents = fetchEvents(
        status: selectedTab == 0 ? "active" : "upcoming",
        sportComplexId: id,
        filterBySelectedVenue: false,
      );
    });
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
          _buildVenuePicker(),
        ],
      ),
    );
  }

  /// Venue filter — `/event-passes` is scoped by `sportComplexId`, so the
  /// choice decides whether the screen shows every complex or just one.
  Widget _buildVenuePicker() {
    const brandBlue = Color(0xFF1A237E);

    if (_loadingVenues) {
      return const SizedBox(
        height: 16,
        width: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    // Nothing to choose between — leave the header exactly as it was.
    if (_venues.isEmpty) return const SizedBox.shrink();

    final label = _venues
            .where((v) => v.id == _venueId)
            .firstOrNull
            ?.name ??
        'All complexes';

    return PopupMenuButton<int>(
      key: const Key('event_venue_picker'),
      tooltip: 'Select venue',
      offset: const Offset(0, 36),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: _onVenueSelected,
      itemBuilder: (context) => [
        _venueMenuItem(_allVenues, 'All complexes', _venueId == null),
        ..._venues.map(
          (venue) => _venueMenuItem(venue.id, venue.name, _venueId == venue.id),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_on_outlined, size: 16, color: brandBlue),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 130),
              child: Text(
                label,
                key: const Key('event_venue_picker_label'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<int> _venueMenuItem(int value, String label, bool selected) {
    const brandBlue = Color(0xFF1A237E);

    return PopupMenuItem<int>(
      key: ValueKey('event_venue_option_$value'),
      value: value,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: selected ? brandBlue : Colors.black87,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          if (selected) const Icon(Icons.check, size: 18, color: brandBlue),
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
              onTap: () {
                setState(() {
                  selectedTab = 0;
                  _futureEvents = _loadEvents("active");
                });
              },
              child: AnimatedContainer(
                duration: Duration(milliseconds: 300),
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                decoration: BoxDecoration(
                  color:
                  selectedTab == 0 ? Color(0xFF1a237e) : Colors.grey[200],
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Text(
                  'Active Events',
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
            onTap: () {
              setState(() {
                selectedTab = 1;
                _futureEvents = _loadEvents("upcoming");
              });
            },
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
  /// Id of the chosen slot. `/event-passes` returns numeric slot ids (the old
  /// API sent them as strings), so ids are normalised through [_slotIdOf].
  int? _selectedSlot;
  bool _bookingInProgress = false;
  List<Map<String, dynamic>> _slots = [];
  int _membersCount = 1;

  /// Slot price × passes, before any coupon.
  double _subtotal = 0.0;
  double _discount = 0.0;

  /// What the user actually pays: [_subtotal] less [_discount].
  double _totalPrice = 0.0;
  Razorpay? _razorpay;

  /// Pending booking created before checkout, and the order raised for it.
  int? _bookingId;
  Map<String, dynamic>? _bookingPayload;
  PaymentOrder? _order;

  /// `GET /coupons/active?appliesTo=Event`.
  List<CouponModel> _coupons = const [];
  bool _loadingCoupons = true;
  CouponModel? _appliedCoupon;

  /// Server's verdict for [_appliedCoupon] — it carries the authoritative
  /// discount and final amount.
  CouponValidation? _validation;
  bool _applyingCoupon = false;

  /// Guards against a stale `/coupons/validate` response overwriting a newer
  /// one.
  int _couponRequest = 0;

  String? _couponError;
  final TextEditingController _couponController = TextEditingController();

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
    _loadCoupons();

    _razorpay = Razorpay();
    _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
    _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _couponController.dispose();
    _razorpay?.clear();
    super.dispose();
  }

  /// Offers for event bookings. A failure here just means no offers strip.
  Future<void> _loadCoupons() async {
    final coupons =
        await CouponRepository.instance.fetchActiveCoupons(appliesTo: 'Event');
    if (!mounted) return;
    setState(() {
      _coupons = coupons;
      _loadingCoupons = false;
    });
  }

  /// Applies [code] by asking the server: `POST /coupons/validate` decides
  /// whether it is usable for this amount and returns the exact discount.
  Future<void> _applyCouponCode(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) {
      setState(() => _couponError = 'Enter a coupon code');
      return;
    }
    if (_subtotal <= 0) {
      setState(() => _couponError = 'Select a pass first');
      return;
    }

    // Only the newest request may write back — the amount can change while a
    // validation is in flight.
    final request = ++_couponRequest;
    setState(() {
      _applyingCoupon = true;
      _couponError = null;
    });

    final result = await CouponRepository.instance.validateCoupon(
      code: trimmed,
      amount: _subtotal,
      appliesTo: 'Event',
      sportComplexId: widget.event.sportComplexId,
      // A coupon issued for one event can only be checked against the event
      // being booked, so the id goes with the request.
      eventPassId: int.tryParse(widget.event.id),
    );

    if (!mounted || request != _couponRequest) return;

    setState(() {
      _applyingCoupon = false;
      if (result.isValid) {
        _appliedCoupon = result.coupon;
        _validation = result;
        _couponError = null;
        _couponController.text = result.coupon?.code ?? trimmed;
      } else {
        _appliedCoupon = null;
        _validation = null;
        _couponError = result.message ?? 'Invalid coupon code';
      }
    });

    _calculatePrice();
  }

  /// Re-prices the applied coupon after the amount changes.
  void _revalidateCoupon() {
    final code = _appliedCoupon?.code;
    if (code == null) return;
    _applyCouponCode(code);
  }

  void _removeCoupon() {
    _couponRequest++; // discard any validation still in flight
    setState(() {
      _appliedCoupon = null;
      _validation = null;
      _applyingCoupon = false;
      _couponError = null;
      _couponController.clear();
    });
    _calculatePrice();
  }

  /// Slot ids off the wire, whichever shape they arrive in.
  static int? _slotIdOf(Object? raw) =>
      raw is int ? raw : int.tryParse(raw?.toString() ?? '');

  /// Fetch slots from API
  /// Slots arrive embedded in `/event-passes`, so they are already in hand.
  /// Only re-read them from the API when the list did not come through.
  Future<void> _fetchSlots() async {
    if (widget.event.slots.isNotEmpty) {
      setState(() {
        _slots = List<Map<String, dynamic>>.from(widget.event.slots);
        _selectedSlot = _slotIdOf(_slots.first['id']);
      });
      _calculatePrice();
      return;
    }

    final eventId = int.tryParse(widget.event.id);
    if (eventId == null) {
      if (mounted) _showSnack("No slots available");
      return;
    }

    try {
      final passes = await EventRepository.instance.fetchEventPasses();
      if (!mounted) return;

      final pass = passes.where((p) => p.id == eventId).firstOrNull;
      final slots = pass?.activeSlots ?? const <EventPassSlot>[];

      if (slots.isEmpty) {
        _showSnack("No slots available");
        return;
      }

      setState(() {
        _slots = slots.map((s) => s.toBookingMap()).toList();
        _selectedSlot = _slotIdOf(_slots.first['id']);
      });
      _calculatePrice();
    } on ApiException catch (e) {
      debugPrint("Error fetching slots: ${e.message}");
      if (mounted) _showSnack(e.message);
    } catch (e, st) {
      debugPrint("Error fetching slots: $e\n$st");
      if (mounted) _showSnack("Error loading slots");
    }
  }

  /// Razorpay payment start
  ///
  /// New API chain: reserve the booking → `POST /payments/create-order` →
  /// Razorpay, opened with the `keyId` and `orderId` the server returned. No
  /// Razorpay key lives in the app.
  Future<void> _startPaymentFlow() async {
    if (ApiService.currentUser == null) {
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
    if (_bookingInProgress) return;

    final eventPassId = int.tryParse(widget.event.id);
    if (eventPassId == null) {
      _showSnack('This event cannot be booked right now');
      return;
    }

    setState(() => _bookingInProgress = true);

    try {
      final user = ApiService.currentUser;

      // 1) Reserve the booking — its id is what the payment is raised against.
      final booking = await EventBookingRepository.instance.createBooking(
        eventPassId: eventPassId,
        slotId: _selectedSlot!,
        passes: _membersCount,
        amount: _totalPrice,
        name: user?['name']?.toString(),
        email: user?['email']?.toString(),
        couponCode: _appliedCoupon?.code,
        sportComplexId: widget.event.sportComplexId,
      );

      if (!mounted) return;
      if (!booking.isOk) {
        _showSnack(booking.message ?? 'Could not create the booking');
        return;
      }

      _bookingId = booking.bookingId;
      _bookingPayload = booking.data;

      // 2) Razorpay order for that booking.
      final order = await PaymentRepository.instance.createOrder(
        bookingType: BookingType.event,
        bookingId: _bookingId!,
        amount: _totalPrice,
      );

      if (!mounted) return;
      if (order == null) {
        _showSnack('Could not start the payment. Please try again.');
        return;
      }

      _order = order;

      // 3) Checkout, with the key and order the server issued.
      _razorpay!.open({
        'key': order.keyId,
        'order_id': order.orderId,
        'amount': order.amountPaise,
        'currency': order.currency,
        'name': widget.event.title,
        'description': 'Event pass booking',
        'prefill': {
          'contact': user?['phone'] ?? '',
          'email': user?['email'] ?? '',
        },
      });
    } catch (e, st) {
      debugPrint("Error starting payment: $e\n$st");
      if (mounted) _showSnack("Payment initialization failed");
    } finally {
      if (mounted) setState(() => _bookingInProgress = false);
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
    _confirmBooking(response);
  }

  void _onPaymentError(PaymentFailureResponse response) {
    _showSnack("Payment failed. Please try again.");
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    _showSnack("External wallet selected: ${response.walletName}");
  }

  /// Confirm the booking once Razorpay reports success.
  ///
  /// `POST /payments/verify` is what actually confirms it — the legacy
  /// `tournaments/verify-payment` + `booking/confirm` pair is gone.
  Future<void> _confirmBooking(PaymentSuccessResponse response) async {
    final bookingId = _bookingId;
    if (bookingId == null) {
      _showSnack("Payment received, but the booking reference is missing");
      return;
    }

    setState(() => _bookingInProgress = true);

    try {
      final verified = await PaymentRepository.instance.verifyPayment(
        bookingType: BookingType.event,
        bookingId: bookingId,
        orderId: response.orderId ?? _order?.orderId ?? '',
        paymentId: response.paymentId ?? '',
        signature: response.signature ?? '',
      );

      if (!mounted) return;

      if (!verified) {
        _showSnack("We could not confirm the payment. Please contact support.");
        return;
      }

      // Read the confirmed booking back so the pass shows the real QR code and
      // pass code; fall back to what is on screen if it cannot be fetched.
      final confirmed =
          await EventBookingRepository.instance.fetchMyBooking(bookingId);
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => EventPassPage(
            booking: _passFor(bookingId, confirmed),
            eventImage: confirmed?.event?.image ?? widget.event.image,
          ),
        ),
      );
    } catch (e, st) {
      debugPrint("Booking error: $e\n$st");
      if (mounted) _showSnack("Payment or booking failed. Try again.");
    } finally {
      if (mounted) setState(() => _bookingInProgress = false);
    }
  }

  /// The pass to show after a verified payment.
  ///
  /// Prefers the confirmed booking from `/event-passes/bookings/my` — it is
  /// the only source of the QR code and pass code — and falls back to the
  /// details already on screen.
  BookingData _passFor(int bookingId, EventPassBooking? booking) {
    final user = ApiService.currentUser;
    final payload = _bookingPayload ?? const <String, dynamic>{};
    final selected = _slots.firstWhere(
          (s) => _slotIdOf(s['id']) == _selectedSlot,
      orElse: () => const <String, dynamic>{},
    );

    String pick(String? preferred, Object? fromCreate, String fallback) {
      if (preferred != null && preferred.isNotEmpty) return preferred;
      final created = fromCreate?.toString() ?? '';
      return created.isEmpty ? fallback : created;
    }

    return BookingData(
      userid: user?['id']?.toString(),
      bookingId: pick(booking?.passCode, payload['bookingReference'],
          '$bookingId'),
      name: pick(booking?.name, payload['name'],
          user?['name']?.toString() ?? ''),
      email: pick(booking?.email, payload['email'],
          user?['email']?.toString() ?? ''),
      membersCount: booking?.numberOfPasses ?? _membersCount,
      tournament: pick(booking?.event?.title, null, widget.event.title),
      slotName: pick(booking?.slot?.name, payload['slotName'],
          selected['name']?.toString() ?? ''),
      startTime: pick(booking?.slot?.startTime, payload['startTime'],
          selected['start']?.toString() ?? ''),
      endTime: pick(booking?.slot?.endTime, payload['endTime'],
          selected['end']?.toString() ?? ''),
      qrCode: pick(booking?.displayQrCode, payload['qrCode'], ''),
      passType: pick(booking?.slot?.passType, payload['passType'],
          selected['pass_type']?.toString() ?? ''),
      eventImage: widget.event.image,
      members: const <Map<String, String>>[],
    );
  }

  /// Calculate total price
  ///
  /// Any applied coupon is re-evaluated here, because changing the slot or the
  /// number of passes can move the amount past (or below) its minimum.
  void _calculatePrice() {
    if (!mounted) return;
    final selected = _slots.firstWhere(
          (s) => _slotIdOf(s['id']) == _selectedSlot,
      orElse: () => {"price": "0"},
    );
    final slotPrice = double.tryParse(selected['price'].toString()) ?? 0.0;
    final subtotal = slotPrice * _membersCount;

    setState(() {
      _subtotal = subtotal;
      _discount = _discountFor(subtotal);
      _totalPrice = subtotal - _discount;
    });
  }

  /// The server's discount when it priced this exact amount, otherwise the
  /// coupon's own rule as a provisional figure until [_revalidateCoupon]
  /// comes back.
  double _discountFor(double subtotal) {
    final validation = _validation;
    if (validation == null || !validation.isValid) return 0;

    final priced = validation.originalAmount;
    final discount = validation.discountAmount;
    if (priced != null && discount != null && (priced - subtotal).abs() < 0.01) {
      return discount;
    }

    return _appliedCoupon?.discountFor(subtotal) ?? 0;
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
                        _buildCouponsCard(),
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
                final selected = _slotIdOf(s['id']) == _selectedSlot;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () {
                      setState(() => _selectedSlot = _slotIdOf(s['id']));
                      _calculatePrice();
                      _revalidateCoupon();
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
                    _revalidateCoupon();
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
                    _revalidateCoupon();
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

  /// Offers & Coupons — active event coupons, plus a code field.
  Widget _buildCouponsCard() {
    const brand = Color(0xFF0A198D);
    final applied = _appliedCoupon;

    return Container(
      key: const Key('event_coupons_card'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 8))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.local_offer_outlined, color: brand, size: 24),
              SizedBox(width: 12),
              Text('Offers & Coupons', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
            ],
          ),
          const SizedBox(height: 16),

          if (_loadingCoupons)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            )
          else if (_coupons.isEmpty)
            const Text(
              'No active offers right now',
              key: Key('no_active_offers'),
              style: TextStyle(fontSize: 14, color: Colors.grey),
            )
          else
            Column(children: _coupons.map(_buildCouponTile).toList()),

          const SizedBox(height: 16),
          const Text('or enter code', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('coupon_code_field'),
                  controller: _couponController,
                  enabled: applied == null,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'COUPON CODE',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13, letterSpacing: 1),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.withOpacity(0.2))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.withOpacity(0.2))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: brand)),
                    disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.withOpacity(0.2))),
                  ),
                  onSubmitted: _applyCouponCode,
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                key: const Key('coupon_apply_button'),
                onPressed: _applyingCoupon
                    ? null
                    : (applied == null
                        ? () => _applyCouponCode(_couponController.text)
                        : _removeCoupon),
                style: ElevatedButton.styleFrom(
                  backgroundColor: applied == null ? brand : Colors.grey[200],
                  foregroundColor: applied == null ? Colors.white : Colors.black87,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _applyingCoupon
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(applied == null ? 'Apply' : 'Remove', style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),

          if (_couponError != null) ...[
            const SizedBox(height: 8),
            Text(
              _couponError!,
              key: const Key('coupon_error'),
              style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
            ),
          ],

          if (applied != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFF16A34A).withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _discount > 0
                          ? '${applied.code ?? 'Coupon'} applied — ₹${_discount.toStringAsFixed(0)} off'
                          : '${applied.code ?? 'Coupon'} applied',
                      key: const Key('coupon_applied_note'),
                      style: const TextStyle(fontSize: 13, color: Color(0xFF166534), fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCouponTile(CouponModel coupon) {
    const brand = Color(0xFF0A198D);
    final isApplied = _appliedCoupon?.code == coupon.code && coupon.code != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isApplied ? brand.withOpacity(0.05) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isApplied ? brand : Colors.grey.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      coupon.code ?? coupon.title ?? 'Offer',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: 0.5),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: brand.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                      child: Text(coupon.shortLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: brand)),
                    ),
                  ],
                ),
                if ((coupon.description ?? coupon.title) != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    coupon.description ?? coupon.title!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ],
            ),
          ),
          TextButton(
            key: ValueKey('coupon_tile_${coupon.code ?? coupon.id}'),
            onPressed: _applyingCoupon
                ? null
                : (isApplied
                    ? _removeCoupon
                    : () => _applyCouponCode(coupon.code ?? '')),
            child: Text(
              isApplied ? 'Remove' : 'Apply',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: brand),
            ),
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
          if (_discount > 0) ...[
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(
                _appliedCoupon?.code == null
                    ? 'Coupon discount'
                    : 'Coupon ${_appliedCoupon!.code}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                '− ₹${_discount.toStringAsFixed(0)}',
                key: const Key('price_summary_discount'),
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ]),
          ],
          if (_selectedSlot != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('₹${_slots.firstWhere((s) => _slotIdOf(s['id']) == _selectedSlot, orElse: () => const {'price': '0'})['price']} × $_membersCount members', style: const TextStyle(color: Colors.white70, fontSize: 12)),
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