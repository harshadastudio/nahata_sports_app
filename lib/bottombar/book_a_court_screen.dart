// BOOK A COURT
// ─────────────────────────────────────────────────────────────────────────────
// A single-card booking screen: venue, sport, date, start time and duration are
// chosen in one place, the offers panel previews a coupon, and the footer shows
// what will actually be charged.
//
// Every value on this screen comes from the API — there is no seeded venue,
// sport, time or price anywhere in this file. The endpoints and the request
// bodies are exactly the ones the previous slot-picker + payment screens used:
//
//   GET  /sports-complexes                      → venues (name, address, city)
//   GET  /courts?sportComplexId=…               → courts, and the sports they serve
//   GET  /courts/{courtId}/available-slots?date → start times, prices, availability
//   GET  /coupons/active                        → the OFFERS & COUPONS list
//   POST /coupons/validate                      → discount preview
//   POST /courts/bookings/create                → reserve (coupon redeemed here)
//   POST /payments/create-order                 → Razorpay order
//   POST /payments/verify                       → confirm
//   POST /courts/bookings/{id}/release          → give a refused hold back
//
// A ₹0 booking never touches the payment gateway: it reserves and stops.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:nahata_app/core/network/http_logged.dart' as http;
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/api_config.dart';
import '../core/storage/token_storage.dart';
import '../core/utils/app_logger.dart';
import '../main.dart';
import '../models/coupon_model.dart';
import '../repositories/coupon_repository.dart';
import 'Custombottombar.dart';
import 'bkpayment.dart' show orderCoversBasket, orderHonoursCoupon;

/// The palette the screen is drawn from. Kept in one place so the card, the
/// strip, the stepper and the CTA cannot drift apart.
class _Ui {
  static const page = Color(0xFFF6F7FB);
  static const card = Colors.white;
  static const border = Color(0xFFE9EBF3);
  static const divider = Color(0xFFF0F1F7);
  static const field = Color(0xFFFAFBFD);

  static const ink = Color(0xFF141726);
  static const label = Color(0xFF454A67);
  static const muted = Color(0xFF7C8199);
  static const faint = Color(0xFFA3A8BF);

  /// The existing brand indigo — the CTA, the strip and the stepper all use it,
  /// so the screen stays inside the app's theme.
  static const primary = Color(0xFF2B2A8C);
  static const primaryBright = Color(0xFF4F46E5);
  static const danger = Color(0xFFDC2626);
  static const success = Color(0xFF16A34A);

  static const radiusCard = 24.0;
  static const radiusBox = 16.0;
  static const radiusField = 14.0;
}

/// A venue, as `/sports-complexes` returns it.
class _Venue {
  const _Venue({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
  });

  final int id;
  final String name;
  final String address;
  final String city;

  /// "Sinhagad Road — Pune". The city is dropped when the API did not send one.
  String get label => city.isEmpty ? name : '$name — $city';

  /// The line under the venue title. Address and city, never duplicated.
  String get fullAddress {
    if (address.isEmpty) return city;
    if (city.isEmpty || address.toLowerCase().contains(city.toLowerCase())) {
      return address;
    }
    return '$address, $city';
  }
}

/// A sport, as it appears on a court record (`court['Sport']`).
class _Sport {
  const _Sport({required this.id, required this.name});

  final int id;
  final String name;
}

/// One bookable slot on one court, as `/courts/{id}/available-slots` returns it.
class _Slot {
  const _Slot({
    required this.id,
    required this.courtId,
    required this.courtName,
    required this.sportId,
    required this.startTime,
    required this.endTime,
    required this.price,
    required this.booked,
  });

  final dynamic id;
  final dynamic courtId;
  final String courtName;
  final int? sportId;

  /// "07:00:00" — the API's own wire format, sent back untouched on booking.
  final String startTime;
  final String endTime;
  final int price;
  final bool booked;
}

class BookACourtScreen extends StatefulWidget {
  const BookACourtScreen({
    super.key,
    required this.location,
    required this.game,
    this.sportId,
    this.sportComplexId,
  });

  /// The venue name the user arrived from. Used to preselect, not to display —
  /// the displayed venue is always the one the API returned.
  final String location;

  /// The sport name the user arrived from, used the same way.
  final String game;

  final int? sportId;
  final int? sportComplexId;

  @override
  State<BookACourtScreen> createState() => _BookACourtScreenState();
}

class _BookACourtScreenState extends State<BookACourtScreen> {
  static const String _apiBase = ApiConfig.baseUrl;
  static const String _bookingType = "facility";

  // ── Selection ─────────────────────────────────────────────────────────────
  List<_Venue> _venues = const [];
  _Venue? _venue;

  List<_Sport> _sports = const [];
  _Sport? _sport;

  DateTime _date = DateTime.now();

  /// Slots for the selected venue/sport/date, grouped by court and each list
  /// sorted by start time. Court order is the order `/courts` returned.
  final Map<String, List<_Slot>> _slotsByCourt = {};
  List<String> _courtOrder = const [];

  String? _startTime;

  /// How many consecutive slots the booking spans. The reference's "1 Hr" is
  /// this many slots wide — the API decides how long a slot actually is.
  int _units = 1;

  // ── Async state ───────────────────────────────────────────────────────────
  bool _loadingVenues = true;
  bool _loadingSports = false;
  bool _loadingSlots = false;
  String? _error;

  // ── Coupons ───────────────────────────────────────────────────────────────
  final TextEditingController _couponController = TextEditingController();
  List<CouponModel> _coupons = const [];
  CouponModel? _appliedCoupon;
  CouponValidation? _validation;
  String? _couponError;
  bool _applyingCoupon = false;
  bool _loadingCoupons = false;
  int _couponRequest = 0;
  bool _offersExpanded = true;

  // ── Payment ───────────────────────────────────────────────────────────────
  late Razorpay _razorpay;
  bool _busy = false;
  List<int> _bookingIds = [];
  String? _rzpOrderId;
  String? _rzpKeyId;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    _loadVenues();
  }

  @override
  void dispose() {
    _razorpay.clear();
    _couponController.dispose();
    super.dispose();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Derived values
  // ───────────────────────────────────────────────────────────────────────────

  /// Start times that at least one court is free for, sorted.
  List<String> get _startOptions {
    final times = <String>{};
    for (final slots in _slotsByCourt.values) {
      for (final s in slots) {
        if (!s.booked) times.add(s.startTime);
      }
    }
    final list = times.toList()..sort();
    return list;
  }

  /// The run of consecutive free slots on [slots] that begins exactly at
  /// [start] and is [units] long, or null when that court cannot serve it.
  List<_Slot>? _runOn(List<_Slot> slots, String start, int units) {
    var i = slots.indexWhere((s) => s.startTime == start);
    if (i < 0) return null;

    final run = <_Slot>[];
    while (run.length < units) {
      if (i >= slots.length) return null;
      final s = slots[i];
      if (s.booked) return null;
      if (run.isNotEmpty && run.last.endTime != s.startTime) return null;
      run.add(s);
      i++;
    }
    return run;
  }

  /// The slots that will actually be booked: the first court, in the order the
  /// API listed them, that can serve the whole duration from the chosen start.
  List<_Slot> get _selectedSlots {
    final start = _startTime;
    if (start == null) return const [];
    for (final courtKey in _courtOrder) {
      final run = _runOn(_slotsByCourt[courtKey] ?? const [], start, _units);
      if (run != null) return run;
    }
    return const [];
  }

  /// The longest booking any single court can serve from the chosen start.
  int get _maxUnits {
    final start = _startTime;
    if (start == null) return 1;
    var best = 0;
    for (final courtKey in _courtOrder) {
      var n = 1;
      while (_runOn(_slotsByCourt[courtKey] ?? const [], start, n + 1) != null) {
        n++;
      }
      if (_runOn(_slotsByCourt[courtKey] ?? const [], start, 1) != null &&
          n > best) {
        best = n;
      }
    }
    return best == 0 ? 1 : best;
  }

  bool get _isAvailable => _selectedSlots.isNotEmpty;

  /// Coupon redemption happens once per created booking and this screen creates
  /// one booking per slot, so a code on a multi-slot booking would burn one use
  /// per slot. Offered only where it behaves correctly — the same rule the
  /// payment screen already applies.
  bool get _couponSupported => _selectedSlots.length == 1;

  int get _baseTotal =>
      _selectedSlots.fold<int>(0, (sum, s) => sum + s.price);

  int get _discount =>
      (_validation?.discountAmount ?? 0).round().clamp(0, _baseTotal);

  int get _payable => (_baseTotal - _discount).clamp(0, _baseTotal);

  /// A booking that costs nothing must not open a payment gateway.
  bool get _isFree => _isAvailable && _payable <= 0;

  String get _ctaLabel {
    if (!_isAvailable) return 'Select an available slot';
    if (_isFree) return 'Get Free Pass';
    return 'Pay & Reserve · ₹$_payable';
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Formatting
  // ───────────────────────────────────────────────────────────────────────────

  /// "06:00:00" -> "6:00 AM". Same helper the slot picker used.
  String _fmtTime(String hhmmss) {
    try {
      final parts = hhmmss.split(':');
      final h = int.parse(parts[0]);
      final m = parts.length > 1 ? parts[1] : '00';
      final period = h >= 12 ? 'PM' : 'AM';
      var h12 = h % 12;
      if (h12 == 0) h12 = 12;
      return '$h12:$m $period';
    } catch (_) {
      return hhmmss;
    }
  }

  int _minutesOf(String hhmmss) {
    try {
      final p = hhmmss.split(':');
      return int.parse(p[0]) * 60 + (p.length > 1 ? int.parse(p[1]) : 0);
    } catch (_) {
      return 0;
    }
  }

  /// "1 Hr", "1 Hr 30 Min", "2 Hrs" — measured off the slots themselves, so a
  /// venue running 30-minute slots reads correctly without any client rule.
  String get _durationLabel {
    final slots = _selectedSlots;
    if (slots.isEmpty) return '$_units ${_units == 1 ? 'Slot' : 'Slots'}';

    var mins = _minutesOf(slots.last.endTime) - _minutesOf(slots.first.startTime);
    if (mins <= 0) mins += 24 * 60; // a run that crosses midnight
    final h = mins ~/ 60;
    final m = mins % 60;

    if (h == 0) return '$m Min';
    final hours = '$h ${h == 1 ? 'Hr' : 'Hrs'}';
    return m == 0 ? hours : '$hours $m Min';
  }

  /// "7:00 AM–8:00 AM" for the availability line.
  String get _rangeLabel {
    final slots = _selectedSlots;
    if (slots.isEmpty) return '';
    return '${_fmtTime(slots.first.startTime)}–${_fmtTime(slots.last.endTime)}';
  }

  /// A small glyph for the sport row. Falls back to a generic one, so a sport
  /// the app has never seen still renders.
  String _sportEmoji(String name) {
    final n = name.toLowerCase();
    if (n.contains('cricket')) return '🏏';
    if (n.contains('foot') || n.contains('soccer') || n.contains('turf')) return '⚽';
    if (n.contains('badminton')) return '🏸';
    if (n.contains('tennis')) return '🎾';
    if (n.contains('basket')) return '🏀';
    if (n.contains('volley')) return '🏐';
    if (n.contains('table')) return '🏓';
    if (n.contains('swim')) return '🏊';
    if (n.contains('hockey')) return '🏑';
    if (n.contains('gym') || n.contains('fitness')) return '🏋️';
    if (n.contains('skat')) return '🛼';
    if (n.contains('box')) return '🥊';
    return '🎯';
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Loading — the same endpoints the previous screens called
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _loadVenues() async {
    setState(() {
      _loadingVenues = true;
      _error = null;
    });

    try {
      final url = Uri.parse(
        '$_apiBase/sports-complexes?status=Active&showOnFrontend=true&limit=50',
      );
      final res = await http.get(url, headers: const {'Accept': 'application/json'});
      if (res.statusCode != 200) {
        throw Exception('Could not load venues (${res.statusCode})');
      }

      final body = jsonDecode(res.body);
      final List raw = body['data']?['sportsComplexes'] ?? const [];
      final venues = <_Venue>[];
      for (final c in raw) {
        final id = c['id'] is int ? c['id'] as int : int.tryParse('${c['id']}');
        if (id == null) continue;
        venues.add(_Venue(
          id: id,
          name: (c['name'] ?? '').toString(),
          address: (c['address'] ?? '').toString(),
          city: (c['city'] ?? '').toString(),
        ));
      }

      // Preselect what the user arrived with: the resolved id when it was
      // forwarded, otherwise the venue whose name matches.
      _Venue? chosen;
      if (widget.sportComplexId != null) {
        for (final v in venues) {
          if (v.id == widget.sportComplexId) chosen = v;
        }
      }
      chosen ??= venues.cast<_Venue?>().firstWhere(
            (v) =>
                v!.name.toLowerCase().trim() ==
                widget.location.toLowerCase().trim(),
            orElse: () => venues.isEmpty ? null : venues.first,
          );

      if (!mounted) return;
      setState(() {
        _venues = venues;
        _venue = chosen;
        _loadingVenues = false;
        _error = venues.isEmpty ? 'No venues are open for booking right now' : null;
      });

      if (chosen != null) await _loadSports();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingVenues = false;
        _error = 'Could not load venues. Please try again.';
      });
      AppLogger.debug('venues failed: $e', name: 'book_a_court');
    }
  }

  /// `GET /courts` for the venue, paginated. The sports list is whatever the
  /// courts say they are — nothing is assumed about which sports exist.
  Future<void> _loadSports() async {
    final venue = _venue;
    if (venue == null) return;

    setState(() {
      _loadingSports = true;
      _error = null;
    });

    try {
      final courts = <dynamic>[];
      var page = 1;
      while (true) {
        final url = Uri.parse(
          '$_apiBase/courts?sportComplexId=${venue.id}&status=Active&limit=100&page=$page',
        );
        final res = await http.get(url, headers: const {'Accept': 'application/json'});
        if (res.statusCode != 200) break;
        final body = jsonDecode(res.body);
        courts.addAll((body['data'] ?? const []) as List);
        final totalPages = body['pagination']?['totalPages'] ?? 1;
        if (page >= (totalPages is int ? totalPages : 1)) break;
        page++;
      }

      final byId = <int, _Sport>{};
      for (final c in courts) {
        final s = c['Sport'];
        if (s == null) continue;
        final id = s['id'] is int ? s['id'] as int : int.tryParse('${s['id']}');
        final name = (s['name'] ?? '').toString();
        if (id == null || name.isEmpty) continue;
        byId.putIfAbsent(id, () => _Sport(id: id, name: name));
      }
      final sports = byId.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      _Sport? chosen;
      if (widget.sportId != null) {
        for (final s in sports) {
          if (s.id == widget.sportId) chosen = s;
        }
      }
      chosen ??= sports.cast<_Sport?>().firstWhere(
            (s) =>
                s!.name.toLowerCase().trim() == widget.game.toLowerCase().trim(),
            orElse: () => sports.isEmpty ? null : sports.first,
          );

      // Keep the current sport when the new venue also offers it, so switching
      // venue does not silently change what is being booked.
      final current = _sport;
      if (current != null) {
        for (final s in sports) {
          if (s.name.toLowerCase() == current.name.toLowerCase()) chosen = s;
        }
      }

      if (!mounted) return;
      setState(() {
        _courts = courts;
        _sports = sports;
        _sport = chosen;
        _loadingSports = false;
        if (sports.isEmpty) _error = 'This venue has no courts open for booking';
      });

      _resetCoupon();
      await Future.wait([_loadSlots(), _loadCoupons()]);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingSports = false;
        _error = 'Could not load sports for this venue.';
      });
      AppLogger.debug('sports failed: $e', name: 'book_a_court');
    }
  }

  /// Every court at the venue, kept so the slot load can filter by sport
  /// without asking `/courts` again on each date change.
  List<dynamic> _courts = const [];

  /// `GET /courts/{id}/available-slots?date=…` for each court of the sport.
  Future<void> _loadSlots() async {
    final venue = _venue;
    final sport = _sport;
    if (venue == null || sport == null) return;

    setState(() {
      _loadingSlots = true;
      _slotsByCourt.clear();
      _courtOrder = const [];
    });

    final date = DateFormat('yyyy-MM-dd').format(_date);

    try {
      final order = <String>[];
      final map = <String, List<_Slot>>{};

      for (final court in _courts) {
        final courtSportId = court['Sport']?['id'];
        final matches = courtSportId == sport.id ||
            (court['Sport']?['name'] ?? '').toString().toLowerCase().trim() ==
                sport.name.toLowerCase().trim();
        if (!matches) continue;

        final courtId = court['id'];
        final courtName = (court['name'] ?? '').toString();
        final key = '$courtId';

        final url = Uri.parse('$_apiBase/courts/$courtId/available-slots?date=$date');
        final res = await http.get(url, headers: const {'Accept': 'application/json'});
        if (res.statusCode != 200) continue;

        final List raw = jsonDecode(res.body)['data'] ?? const [];
        final slots = <_Slot>[];
        for (final s in raw) {
          slots.add(_Slot(
            id: s['id'],
            courtId: courtId,
            courtName: courtName,
            sportId: courtSportId is int
                ? courtSportId
                : int.tryParse('${courtSportId ?? sport.id}') ?? sport.id,
            startTime: (s['startTime'] ?? '').toString(),
            endTime: (s['endTime'] ?? '').toString(),
            price: (s['price'] is num)
                ? (s['price'] as num).toInt()
                : int.tryParse('${s['price']}') ?? 0,
            booked: s['isBooked'] == true,
          ));
        }
        slots.sort((a, b) => a.startTime.compareTo(b.startTime));
        if (slots.isEmpty) continue;

        order.add(key);
        map[key] = slots;
      }

      if (!mounted) return;
      setState(() {
        _courtOrder = order;
        _slotsByCourt
          ..clear()
          ..addAll(map);
        _loadingSlots = false;

        // Keep the chosen time when the new date still offers it, otherwise
        // fall back to the first one that is free.
        final options = _startOptions;
        if (_startTime == null || !options.contains(_startTime)) {
          _startTime = options.isEmpty ? null : options.first;
        }
        _units = _units.clamp(1, _maxUnits);
      });

      _revalidateCoupon();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingSlots = false);
      AppLogger.debug('slots failed: $e', name: 'book_a_court');
    }
  }

  /// `GET /coupons/active`. A failure here only means no offers strip, so it
  /// never blocks the screen.
  Future<void> _loadCoupons() async {
    setState(() => _loadingCoupons = true);
    final coupons = await CouponRepository.instance.fetchActiveCoupons(
      appliesTo: 'Court',
      sportComplexId: _venue?.id,
      sportId: _sport?.id,
    );
    if (!mounted) return;
    setState(() {
      _coupons = coupons;
      _loadingCoupons = false;
    });
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Coupons
  // ───────────────────────────────────────────────────────────────────────────

  /// `POST /coupons/validate` — the server decides whether the code applies and
  /// how much comes off. Preview only; `/courts/bookings/create` sends the code
  /// again and the backend re-checks it where it actually counts.
  Future<void> _applyCouponCode(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) {
      setState(() => _couponError = 'Enter a coupon code');
      return;
    }
    if (!_couponSupported) {
      setState(() => _couponError =
          'Coupons apply to a single-slot booking. Reduce the duration to use one.');
      return;
    }

    final request = ++_couponRequest;
    setState(() {
      _applyingCoupon = true;
      _couponError = null;
    });

    final result = await CouponRepository.instance.validateCoupon(
      code: trimmed,
      amount: _baseTotal,
      appliesTo: 'Court',
      sportComplexId: _venue?.id,
      // A coupon issued for one sport must not come off another's booking.
      sportId: _sport?.id,
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
  }

  void _removeCoupon() {
    setState(() {
      _appliedCoupon = null;
      _validation = null;
      _couponError = null;
      _couponController.clear();
    });
  }

  void _resetCoupon() {
    _couponRequest++;
    _removeCoupon();
  }

  /// The price moved, so the discount the server quoted for the old amount is
  /// stale. Re-price it rather than showing a figure that no longer holds.
  void _revalidateCoupon() {
    final code = _appliedCoupon?.code;
    if (code == null) return;
    if (!_couponSupported || !_isAvailable) {
      _resetCoupon();
      return;
    }
    _applyCouponCode(code);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Booking + payment — identical calls to the existing payment screen
  // ───────────────────────────────────────────────────────────────────────────

  Future<String?> _getAuthToken() => TokenStorage.instance.accessToken;

  Future<String?> _getUserEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('user');
      if (userJson == null) return null;
      return jsonDecode(userJson)['email']?.toString();
    } catch (e) {
      AppLogger.debug('prefs error: $e', name: 'book_a_court');
      return null;
    }
  }

  Future<bool> _isLoggedIn() async => (await _getUserEmail()) != null;

  /// `POST /courts/bookings/create`, one call per selected slot. Returns the
  /// created booking ids (paymentStatus = Pending).
  Future<List<int>> _createBookings({
    required String? token,
    required List<_Slot> slots,
  }) async {
    final ids = <int>[];
    for (final s in slots) {
      final body = {
        "sportComplexId": _venue?.id,
        "sportId": s.sportId ?? _sport?.id,
        "date": DateFormat('yyyy-MM-dd').format(_date),
        "startTime": s.startTime,
        "endTime": s.endTime,
        "totalAmount": s.price,
        // The server re-validates the code, applies the discount to the stored
        // booking and charges the order off that — so this is the only place
        // the coupon actually takes effect.
        if (_appliedCoupon?.code != null) "couponCode": _appliedCoupon!.code,
      };

      final res = await http.post(
        Uri.parse("$_apiBase/courts/bookings/create"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          if (token != null) "Authorization": "Bearer $token",
          // Redemption is platform-gated just like validation is.
          ...ApiConfig.platformHeader,
        },
        body: jsonEncode(body),
      );

      AppLogger.debug(
        "📦 create booking (${res.statusCode}): ${res.body}",
        name: 'book_a_court',
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        final List bookings = data['data']?['bookings'] ?? const [];
        for (final b in bookings) {
          final id = b['id'];
          if (id is int) {
            ids.add(id);
          } else {
            final parsed = int.tryParse('$id');
            if (parsed != null) ids.add(parsed);
          }
        }
      }
    }
    return ids;
  }

  /// `POST /payments/create-order` for the whole basket.
  Future<Map<String, dynamic>?> _createOrder({
    required String? token,
    required List<int> bookingIds,
    required int amount, // rupees
  }) async {
    final res = await http.post(
      Uri.parse("$_apiBase/payments/create-order"),
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "bookingType": _bookingType,
        "bookingId": bookingIds.first,
        "bookingIds": bookingIds,
        "amount": amount,
      }),
    );

    AppLogger.debug(
      "📦 create-order (${res.statusCode}): ${res.body}",
      name: 'book_a_court',
    );

    if (res.statusCode == 200 || res.statusCode == 201) {
      return jsonDecode(res.body)['data'] as Map<String, dynamic>?;
    }
    return null;
  }

  /// `POST /payments/verify`.
  Future<bool> _verifyPayment({
    required String? token,
    required int bookingId,
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    try {
      final res = await http.post(
        Uri.parse("$_apiBase/payments/verify"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "bookingType": _bookingType,
          "bookingId": bookingId,
          "razorpay_order_id": orderId,
          "razorpay_payment_id": paymentId,
          "razorpay_signature": signature,
        }),
      );
      AppLogger.debug("📥 verify (${res.statusCode}): ${res.body}", name: 'book_a_court');
      return jsonDecode(res.body)["success"] == true;
    } catch (e) {
      AppLogger.debug("❌ verify error: $e", name: 'book_a_court');
      return false;
    }
  }

  /// `POST /courts/bookings/{id}/release` — gives a hold back after a checkout
  /// we refuse to open. A failed release is logged, never surfaced; the hold
  /// expires on its own and the user already has an error to read.
  Future<void> _releaseHeldBookings(String? token) async {
    for (final bookingId in _bookingIds) {
      try {
        await http.post(
          Uri.parse("$_apiBase/courts/bookings/$bookingId/release"),
          headers: {
            "Content-Type": "application/json",
            "Accept": "application/json",
            if (token != null) "Authorization": "Bearer $token",
          },
        );
      } catch (e) {
        AppLogger.debug('Could not release #$bookingId: $e', name: 'book_a_court');
      }
    }
    _bookingIds = [];
  }

  /// The CTA. A free booking reserves and stops; a paid one goes on to
  /// create-order and Razorpay.
  Future<void> _onReserve() async {
    if (_busy || !_isAvailable) return;

    if (!await _isLoggedIn()) {
      _showErrorDialog("Please log in to make a booking.");
      return;
    }

    final slots = _selectedSlots;
    if (slots.isEmpty) {
      _showErrorDialog("That time is no longer available. Please pick another.");
      return;
    }

    setState(() => _busy = true);
    final token = await _getAuthToken();

    try {
      // ✅ STEP 1: RESERVE BOOKING(S)
      _bookingIds = await _createBookings(token: token, slots: slots);
      if (_bookingIds.isEmpty) {
        if (!mounted) return;
        setState(() => _busy = false);
        _showErrorDialog("Unable to reserve the slot(s). Please try again.");
        return;
      }

      // A ₹0 booking is complete the moment it is reserved. No order is raised
      // and the gateway is never opened.
      if (_payable <= 0) {
        if (!mounted) return;
        setState(() => _busy = false);
        await _notifyConfirmed(0);
        _showSuccessDialog(free: true);
        return;
      }

      // ✅ STEP 2: CREATE PAYMENT ORDER
      final orderData = await _createOrder(
        token: token,
        bookingIds: _bookingIds,
        amount: _payable,
      );

      if (orderData == null || orderData['orderId'] == null) {
        if (!mounted) return;
        setState(() => _busy = false);
        _showErrorDialog("Unable to create order. Please try again.");
        return;
      }

      // Never open a checkout for less than the basket is worth — a short order
      // means the server did not price every slot.
      if (!orderCoversBasket(orderData['amount'], _payable)) {
        AppLogger.error(
          'Order undercharges the basket: order=${orderData['amount']} paise, '
          'expected=₹$_payable over ${_bookingIds.length} slot(s)',
          name: 'book_a_court',
        );
        await _releaseHeldBookings(token);
        if (!mounted) return;
        setState(() => _busy = false);
        _showErrorDialog(
          "We could not price this booking correctly. "
          "Please try again, or book a shorter duration.",
        );
        return;
      }

      // The other direction: an order above the discounted total means the
      // coupon was not applied to the stored booking, so paying it would cost
      // the full price the customer was told they would not pay.
      if (_appliedCoupon != null &&
          !orderHonoursCoupon(orderData['amount'], _payable)) {
        AppLogger.error(
          'Order ignores coupon ${_appliedCoupon?.code}: '
          'order=${orderData['amount']} paise, expected=₹$_payable',
          name: 'book_a_court',
        );
        await _releaseHeldBookings(token);
        if (!mounted) return;
        setState(() {
          _busy = false;
          _appliedCoupon = null;
          _validation = null;
          _couponError =
              "This coupon could not be applied to your booking. "
              "Please remove it or try a different code.";
        });
        _showErrorDialog(
          "Your coupon could not be applied to this booking, so we stopped "
          "the payment rather than charge you the full amount. "
          "Please try again.",
        );
        return;
      }

      // Everything (key, order, amount, currency) comes from the backend
      // create-order response — nothing hardcoded on the client.
      _rzpOrderId = orderData['orderId']?.toString();
      _rzpKeyId = orderData['keyId']?.toString();

      final email = (await _getUserEmail()) ?? '';

      final options = {
        'key': _rzpKeyId,
        'order_id': _rzpOrderId,
        if (orderData['amount'] != null) 'amount': orderData['amount'],
        'currency': (orderData['currency'] ?? 'INR').toString(),
        'name': 'Nahata Sports',
        'description': '${_sport?.name ?? 'Court'} booking',
        'prefill': {if (email.isNotEmpty) 'email': email},
        // Do NOT add 'prefill.method' or a 'config.display' block: both make the
        // iOS checkout webview navigate straight at a UPI app scheme and it dies
        // with "Webview error Frame load interrupted".
        'method': const {
          'upi': true,
          'card': true,
          'netbanking': true,
          'wallet': true,
        },
        'timeout': 300,
        'remember_customer': true,
        'retry': const {'enabled': true, 'max_count': 2},
        'theme': const {'color': '#1A237E'},
      };

      // ✅ Small delay prevents ANR
      await Future.delayed(const Duration(milliseconds: 200));
      _razorpay.open(options);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showErrorDialog('Payment gateway error: $e');
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final token = await _getAuthToken();

    var allVerified = _bookingIds.isNotEmpty;
    String? failMessage;

    for (final bookingId in _bookingIds) {
      final ok = await _verifyPayment(
        token: token,
        bookingId: bookingId,
        orderId: response.orderId ?? _rzpOrderId ?? '',
        paymentId: response.paymentId ?? '',
        signature: response.signature ?? '',
      );
      if (!ok) {
        allVerified = false;
        failMessage = "Payment verification failed for booking #$bookingId";
      }
    }

    if (!mounted) return;
    setState(() => _busy = false);

    if (allVerified) {
      await _notifyConfirmed(_payable);
      _showSuccessDialog();
    } else {
      _showErrorDialog(failMessage ?? "Payment verification failed");
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (!mounted) return;
    setState(() => _busy = false);
    AppLogger.debug(
      "❌ Payment Error: ${response.code} - ${response.message}",
      name: 'book_a_court',
    );
    if (response.code == 2) {
      _showErrorDialog("Payment was cancelled or not completed.\nPlease try again.");
    } else {
      _showErrorDialog(response.message ?? "Payment failed");
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (!mounted) return;
    setState(() => _busy = false);
    _showErrorDialog(
      "Payment via ${response.walletName} is not supported currently.",
    );
  }

  /// The customer's receipt for this booking — what was actually charged.
  Future<void> _notifyConfirmed(int amount) async {
    const androidDetails = AndroidNotificationDetails(
      'booking_channel',
      'Booking Notifications',
      channelDescription: 'Booking confirmation notifications',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    try {
      await flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        '✅ Booking Confirmed',
        '📅 Date: ${DateFormat('EEE, MMM d, yyyy').format(_date)}\n'
            '⏰ Slot: $_rangeLabel\n'
            '💰 Amount: ₹$amount',
        details,
        payload: 'booking',
      );
    } catch (e) {
      AppLogger.debug('notification failed: $e', name: 'book_a_court');
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Dialogs
  // ───────────────────────────────────────────────────────────────────────────

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFFEF2F2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline, color: _Ui.danger, size: 44),
            ),
            const SizedBox(height: 16),
            const Text(
              "Something went wrong",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _Ui.ink,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: _Ui.muted, height: 1.5),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: _Ui.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                "OK",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog({bool free = false}) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFECFDF3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: _Ui.success, size: 46),
              ),
              const SizedBox(height: 16),
              Text(
                free ? "Free Pass Confirmed!" : "Booking Confirmed!",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _Ui.ink,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                free
                    ? "Your free court has been reserved."
                    : "Your booking has been confirmed successfully!",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: _Ui.muted, height: 1.5),
              ),
              const SizedBox(height: 8),
              const Text(
                "You will receive a confirmation mail shortly.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: _Ui.muted, height: 1.5),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => CustomBottomNav()),
                  (route) => false,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _Ui.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  "Continue",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Pickers
  // ───────────────────────────────────────────────────────────────────────────

  Future<T?> _showPickerSheet<T>({
    required String title,
    required List<T> items,
    required String Function(T) labelOf,
    String? Function(T)? leadingOf,
    required bool Function(T) isSelected,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        final maxHeight = MediaQuery.of(sheetContext).size.height * 0.7;
        return Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: const BoxDecoration(
            color: _Ui.card,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _Ui.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                  child: Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _Ui.ink,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: _Ui.divider),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(
                      height: 1,
                      indent: 20,
                      endIndent: 20,
                      color: _Ui.divider,
                    ),
                    itemBuilder: (_, i) {
                      final item = items[i];
                      final selected = isSelected(item);
                      final leading = leadingOf?.call(item);
                      return ListTile(
                        onTap: () => Navigator.pop(sheetContext, item),
                        leading: leading == null
                            ? null
                            : Text(leading, style: const TextStyle(fontSize: 20)),
                        title: Text(
                          labelOf(item),
                          style: TextStyle(
                            fontSize: 16,
                            color: selected ? _Ui.primary : _Ui.ink,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                        trailing: selected
                            ? const Icon(Icons.check_rounded,
                                color: _Ui.primary, size: 20)
                            : null,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickVenue() async {
    if (_venues.isEmpty || _busy) return;
    final picked = await _showPickerSheet<_Venue>(
      title: 'SELECT VENUE',
      items: _venues,
      labelOf: (v) => v.label,
      isSelected: (v) => v.id == _venue?.id,
    );
    if (picked == null || picked.id == _venue?.id) return;
    setState(() {
      _venue = picked;
      _startTime = null;
      _units = 1;
    });
    _resetCoupon();
    await _loadSports();
  }

  Future<void> _pickSport() async {
    if (_sports.isEmpty || _busy) return;
    final picked = await _showPickerSheet<_Sport>(
      title: 'SELECT SPORT',
      items: _sports,
      labelOf: (s) => s.name,
      leadingOf: (s) => _sportEmoji(s.name),
      isSelected: (s) => s.id == _sport?.id,
    );
    if (picked == null || picked.id == _sport?.id) return;
    setState(() {
      _sport = picked;
      _startTime = null;
      _units = 1;
    });
    _resetCoupon();
    await Future.wait([_loadSlots(), _loadCoupons()]);
  }

  Future<void> _pickDate() async {
    if (_busy) return;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 60)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _Ui.primary,
            onPrimary: Colors.white,
            onSurface: _Ui.ink,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      _date = picked;
      _startTime = null;
      _units = 1;
    });
    _resetCoupon();
    await _loadSlots();
  }

  Future<void> _pickStartTime() async {
    final options = _startOptions;
    if (options.isEmpty || _busy) return;
    final picked = await _showPickerSheet<String>(
      title: 'SELECT START TIME',
      items: options,
      labelOf: _fmtTime,
      isSelected: (t) => t == _startTime,
    );
    if (picked == null || picked == _startTime) return;
    setState(() {
      _startTime = picked;
      _units = _units.clamp(1, _maxUnits);
    });
    _revalidateCoupon();
  }

  void _changeDuration(int delta) {
    final next = (_units + delta).clamp(1, _maxUnits);
    if (next == _units) return;
    HapticFeedback.selectionClick();
    setState(() => _units = next);
    _revalidateCoupon();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Build
  // ───────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    // One padding value for the whole screen, widened a little on large phones
    // and tablets so the card never runs edge to edge.
    final hPad = width < 360 ? 12.0 : (width > 600 ? 24.0 : 16.0);

    return Scaffold(
      backgroundColor: _Ui.page,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(),
            Expanded(
              child: RefreshIndicator(
                color: _Ui.primary,
                onRefresh: _loadVenues,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    hPad,
                    hPad,
                    hPad,
                    hPad + MediaQuery.paddingOf(context).bottom,
                  ),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 620),
                        child: _loadingVenues
                            ? _loadingCard()
                            : (_venue == null ? _errorCard() : _mainCard()),
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

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _header() {
    return Container(
      color: _Ui.card,
      padding: const EdgeInsets.fromLTRB(12, 10, 16, 14),
      child: Row(
        children: [
          Material(
            color: const Color(0xFFF1F2F7),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _busy ? null : () => Navigator.maybePop(context),
              child: const SizedBox(
                width: 42,
                height: 42,
                child: Icon(Icons.chevron_left_rounded, color: _Ui.ink, size: 26),
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'BOOK A COURT',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w600,
                color: _Ui.ink,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Cards ─────────────────────────────────────────────────────────────────

  BoxDecoration get _cardDecoration => BoxDecoration(
        color: _Ui.card,
        borderRadius: BorderRadius.circular(_Ui.radiusCard),
        border: Border.all(color: _Ui.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A101828),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      );

  Widget _loadingCard() {
    return Container(
      decoration: _cardDecoration,
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: const Center(
        child: CircularProgressIndicator(color: _Ui.primary, strokeWidth: 2.5),
      ),
    );
  }

  Widget _errorCard() {
    return Container(
      decoration: _cardDecoration,
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const Icon(Icons.wifi_off_rounded, size: 44, color: _Ui.faint),
          const SizedBox(height: 14),
          Text(
            _error ?? 'Could not load this screen.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: _Ui.muted, height: 1.5),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loadVenues,
            style: ElevatedButton.styleFrom(
              backgroundColor: _Ui.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _mainCard() {
    final venue = _venue!;

    return Container(
      decoration: _cardDecoration,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Venue title + address
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  venue.name,
                  style: const TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w700,
                    color: _Ui.ink,
                    height: 1.2,
                    letterSpacing: -0.3,
                  ),
                ),
                if (venue.fullAddress.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.location_on_outlined,
                            size: 15, color: _Ui.faint),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          venue.fullAddress,
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: _Ui.muted,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Trust strip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_Ui.primary, _Ui.primaryBright],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: const Text(
              '✓ Instant confirmation · Secure online payment',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.1,
              ),
            ),
          ),

          // Selection fields
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _fieldRow(
                  label: 'Venue',
                  child: _fieldBox(
                    text: venue.label,
                    onTap: _pickVenue,
                    trailing: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: _Ui.faint, size: 22),
                  ),
                ),
                const _RowDivider(),
                _fieldRow(
                  label: 'Sport',
                  child: _fieldBox(
                    text: _sport?.name ?? '—',
                    leading: _sport == null ? null : _sportEmoji(_sport!.name),
                    onTap: _pickSport,
                    busy: _loadingSports,
                    trailing: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: _Ui.faint, size: 22),
                  ),
                ),
                const _RowDivider(),
                _fieldRow(
                  label: 'Date',
                  child: _fieldBox(
                    text: DateFormat('EEE, MMM d, yyyy').format(_date),
                    onTap: _pickDate,
                    trailing: const Icon(Icons.calendar_today_outlined,
                        color: _Ui.faint, size: 17),
                  ),
                ),
                const _RowDivider(),
                _fieldRow(
                  label: 'Start Time',
                  child: _fieldBox(
                    text: _startTime == null
                        ? (_loadingSlots ? 'Loading…' : 'No slots')
                        : _fmtTime(_startTime!),
                    muted: _startTime == null,
                    onTap: _pickStartTime,
                    busy: _loadingSlots,
                    trailing: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time_rounded, color: _Ui.faint, size: 17),
                        SizedBox(width: 2),
                        Icon(Icons.keyboard_arrow_down_rounded,
                            color: _Ui.faint, size: 22),
                      ],
                    ),
                  ),
                ),
                const _RowDivider(),
                _durationRow(),
                const _RowDivider(),
                const SizedBox(height: 4),
                _availabilityRow(),
                const SizedBox(height: 16),
                _offersCard(),
                const SizedBox(height: 16),
                _totalCard(),
                const SizedBox(height: 18),
                _cta(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Field rows ────────────────────────────────────────────────────────────

  /// Label on the left, control on the right — collapsing to a stacked layout
  /// on very narrow screens and at large text scales, where a side-by-side row
  /// would squeeze the value to nothing.
  Widget _fieldRow({required String label, required Widget child}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final stacked = constraints.maxWidth < 320 || scale > 1.3;

        final labelWidget = Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            color: _Ui.label,
            fontWeight: FontWeight.w400,
          ),
        );

        if (stacked) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                labelWidget,
                const SizedBox(height: 8),
                child,
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              SizedBox(width: constraints.maxWidth * 0.30, child: labelWidget),
              Expanded(child: child),
            ],
          ),
        );
      },
    );
  }

  Widget _fieldBox({
    required String text,
    required VoidCallback onTap,
    Widget? trailing,
    String? leading,
    bool muted = false,
    bool busy = false,
  }) {
    return Material(
      color: _Ui.card,
      borderRadius: BorderRadius.circular(_Ui.radiusField),
      child: InkWell(
        borderRadius: BorderRadius.circular(_Ui.radiusField),
        onTap: busy ? null : onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_Ui.radiusField),
            border: Border.all(color: _Ui.border),
          ),
          child: Row(
            children: [
              if (leading != null) ...[
                Text(leading, style: const TextStyle(fontSize: 17)),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    color: muted ? _Ui.faint : _Ui.ink,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (busy)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: _Ui.faint),
                )
              else if (trailing != null)
                trailing,
            ],
          ),
        ),
      ),
    );
  }

  Widget _durationRow() {
    final canMinus = _units > 1;
    final canPlus = _units < _maxUnits;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          const Expanded(
            flex: 3,
            child: Text(
              'Duration',
              style: TextStyle(
                fontSize: 15,
                color: _Ui.label,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          _stepperButton(
            icon: Icons.remove_rounded,
            enabled: canMinus,
            onTap: () => _changeDuration(-1),
          ),
          Expanded(
            flex: 3,
            child: Text(
              _durationLabel,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _Ui.ink,
              ),
            ),
          ),
          _stepperButton(
            icon: Icons.add_rounded,
            enabled: canPlus,
            onTap: () => _changeDuration(1),
          ),
        ],
      ),
    );
  }

  Widget _stepperButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Material(
      color: enabled ? _Ui.primaryBright : const Color(0xFFF1F2F7),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            size: 22,
            color: enabled ? Colors.white : _Ui.faint,
          ),
        ),
      ),
    );
  }

  Widget _availabilityRow() {
    if (_loadingSlots) {
      return const Row(
        children: [
          SizedBox(
            width: 15,
            height: 15,
            child: CircularProgressIndicator(strokeWidth: 2, color: _Ui.faint),
          ),
          SizedBox(width: 10),
          Text(
            'Checking availability…',
            style: TextStyle(fontSize: 14.5, color: _Ui.muted),
          ),
        ],
      );
    }

    final available = _isAvailable;
    final color = available ? _Ui.primary : _Ui.danger;
    final text = available
        ? 'Available · $_rangeLabel'
        : (_startOptions.isEmpty
            ? 'No slots open on this date'
            : 'Not available for this duration');

    return Row(
      children: [
        Icon(
          available ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded,
          size: 18,
          color: color,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14.5,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  // ── Offers & coupons ──────────────────────────────────────────────────────

  Widget _offersCard() {
    return Container(
      decoration: BoxDecoration(
        color: _Ui.card,
        borderRadius: BorderRadius.circular(_Ui.radiusBox),
        border: Border.all(color: _Ui.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _offersExpanded = !_offersExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded,
                      size: 18, color: _Ui.primaryBright),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'OFFERS & COUPONS',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: _Ui.ink,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  Icon(
                    _offersExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: _Ui.faint,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: _offersExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Divider(height: 1, color: _Ui.divider),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _offersBody(),
                      const SizedBox(height: 18),
                      const _OrEnterCode(),
                      const SizedBox(height: 16),
                      _couponInput(),
                      if (!_couponSupported && _isAvailable) ...[
                        const SizedBox(height: 10),
                        const Text(
                          'A code applies to a single-slot booking — shorten '
                          'the duration to use one.',
                          style: TextStyle(fontSize: 12.5, color: _Ui.muted),
                        ),
                      ],
                      if (_couponError != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _couponError!,
                          key: const Key('coupon_error'),
                          style: const TextStyle(fontSize: 12.5, color: _Ui.danger),
                        ),
                      ],
                      if (_appliedCoupon != null) ...[
                        const SizedBox(height: 12),
                        _appliedNote(),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _offersBody() {
    if (_loadingCoupons) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: _Ui.faint),
          ),
        ),
      );
    }

    if (_coupons.isEmpty) {
      return const Center(
        child: Text(
          'No active offers right now',
          key: Key('no_active_offers'),
          style: TextStyle(fontSize: 14, color: _Ui.muted),
        ),
      );
    }

    return Column(children: _coupons.map(_couponTile).toList());
  }

  Widget _couponTile(CouponModel coupon) {
    final isApplied = coupon.code != null && _appliedCoupon?.code == coupon.code;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isApplied ? _Ui.primary.withOpacity(0.05) : _Ui.field,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isApplied ? _Ui.primary : _Ui.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        coupon.code ?? coupon.title ?? 'Offer',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _Ui.ink,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _Ui.primaryBright.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        coupon.shortLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _Ui.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                if ((coupon.description ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    coupon.description!,
                    style: const TextStyle(fontSize: 12.5, color: _Ui.muted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: (_applyingCoupon || coupon.code == null)
                ? null
                : (isApplied ? _removeCoupon : () => _applyCouponCode(coupon.code!)),
            style: TextButton.styleFrom(
              foregroundColor: isApplied ? _Ui.muted : _Ui.primary,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              isApplied ? 'REMOVE' : 'APPLY',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _couponInput() {
    final applied = _appliedCoupon;
    final enabled = applied == null && _couponSupported && _isAvailable;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: TextField(
            key: const Key('coupon_code_field'),
            controller: _couponController,
            enabled: enabled,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(
              fontSize: 14,
              color: _Ui.ink,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
            decoration: InputDecoration(
              hintText: 'COUPON CODE',
              hintStyle: const TextStyle(
                color: _Ui.faint,
                fontSize: 13,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: const Icon(Icons.local_offer_outlined,
                  size: 18, color: _Ui.faint),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 42, minHeight: 22),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
              filled: true,
              fillColor: _Ui.field,
              border: _couponBorder(_Ui.border),
              enabledBorder: _couponBorder(_Ui.border),
              disabledBorder: _couponBorder(_Ui.border),
              focusedBorder: _couponBorder(_Ui.primaryBright),
            ),
            onSubmitted: enabled ? _applyCouponCode : null,
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: 50,
          child: ElevatedButton(
            key: const Key('coupon_apply_button'),
            onPressed: _applyingCoupon
                ? null
                : (applied != null
                    ? _removeCoupon
                    : (enabled
                        ? () => _applyCouponCode(_couponController.text)
                        : null)),
            style: ElevatedButton.styleFrom(
              backgroundColor: applied != null ? const Color(0xFFEEF0F6) : _Ui.primary,
              foregroundColor: applied != null ? _Ui.label : Colors.white,
              disabledBackgroundColor: const Color(0xFFA9A5D4),
              disabledForegroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _applyingCoupon
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    applied != null ? 'REMOVE' : 'APPLY',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  OutlineInputBorder _couponBorder(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color),
      );

  Widget _appliedNote() {
    final applied = _appliedCoupon!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _Ui.success.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: _Ui.success, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _discount > 0
                  ? '${applied.code ?? 'Coupon'} applied — ₹$_discount off'
                  : '${applied.code ?? 'Coupon'} applied',
              key: const Key('coupon_applied_note'),
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF166534),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Total + CTA ───────────────────────────────────────────────────────────

  Widget _totalCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: _Ui.page,
        borderRadius: BorderRadius.circular(_Ui.radiusBox),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Expanded(
            child: Text(
              'TOTAL',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _Ui.label,
                letterSpacing: 1.4,
              ),
            ),
          ),
          if (_discount > 0) ...[
            Text(
              '₹$_baseTotal',
              style: const TextStyle(
                fontSize: 16,
                color: _Ui.faint,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.lineThrough,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Text(
            '₹$_payable',
            key: const Key('booking_total'),
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: _Ui.ink,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cta() {
    final enabled = _isAvailable && !_busy;

    return SizedBox(
      width: double.infinity,
      height: 60,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_Ui.radiusBox),
          boxShadow: enabled
              ? const [
                  BoxShadow(
                    color: Color(0x332B2A8C),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ]
              : const [],
        ),
        child: ElevatedButton(
          key: const Key('book_a_court_cta'),
          onPressed: enabled ? _onReserve : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: _Ui.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFFC7C9DC),
            disabledForegroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_Ui.radiusBox),
            ),
          ),
          child: _busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.4, color: Colors.white),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isFree
                          ? Icons.confirmation_number_outlined
                          : Icons.credit_card_rounded,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        _ctaLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
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

/// The hairline between two selection rows.
class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, thickness: 1, color: _Ui.divider);
}

/// "─── OR ENTER CODE ───"
class _OrEnterCode extends StatelessWidget {
  const _OrEnterCode();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: _Ui.divider, thickness: 1)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OR ENTER CODE',
            style: TextStyle(
              fontSize: 11,
              color: _Ui.faint,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Expanded(child: Divider(color: _Ui.divider, thickness: 1)),
      ],
    );
  }
}
