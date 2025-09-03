// import 'dart:convert';
// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:nahata_app/screens/regi.dart';
// import 'package:nahata_app/services/api_service.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:razorpay_flutter/razorpay_flutter.dart';
// import 'package:share_plus/share_plus.dart';
// import 'package:html_unescape/html_unescape.dart';
//
// import 'dashboard/dashboard_screen.dart';
//
// /* -------------------------------------------
//    Event Model
//    ------------------------------------------- */
// // class EventModel {
// //   final String id;
// //   final String title;
// //   final String image;
// //   final String date;
// //   final int price;
// //   final int totalSlots;
// //   final int bookedSlots;
// //   final String location;
// //   final String description;
// //
// //   EventModel({
// //     required this.id,
// //     required this.title,
// //     required this.image,
// //     required this.date,
// //     required this.price,
// //     required this.totalSlots,
// //     required this.bookedSlots,
// //     required this.location,
// //     required this.description,
// //   });
// //   List<Map<String, dynamic>> get availablePasses {
// //     final passRaw = description.contains("Pass Prices")
// //         ? description.split("Pass Prices:").last
// //         : "";
// //
// //     final passes = passRaw
// //         .split(RegExp(r'[\n•]'))
// //         .map((s) => s.trim())
// //         .where((s) => s.isNotEmpty)
// //         .toList();
// //
// //     return passes.map((p) {
// //       // Example: "2 Day Pass - ₹15 00"
// //       final parts = p.split(RegExp(r'[-–:]'));
// //       final name = parts.first.trim();
// //       final price = int.tryParse(
// //           RegExp(r'(\d+)').firstMatch(p)?.group(1) ?? "0") ??
// //           0;
// //       return {"name": name, "price": price, "raw": p};
// //     }).toList();
// //   }
// //
// //   bool get isFull => bookedSlots >= totalSlots;
// //   int get availableSlots => (totalSlots - bookedSlots).clamp(0, totalSlots);
// //
// //   factory EventModel.fromJson(Map<String, dynamic> json) {
// //     final unescape = HtmlUnescape();
// //     final rawContent = json['content'] ?? '';
// //     final cleanHtml = unescape
// //         .convert(rawContent.replaceAll(RegExp(r'<[^>]*>'), ''))
// //         .replaceAll(RegExp(r'\s+\n'), '\n') // normalize whitespace
// //         .trim();
// //
// //     return EventModel(
// //       id: json['id'].toString(),
// //       title: json['title'] ?? '',
// //       image: "https://nahatasports.com/${json['image'] ?? ''}",
// //       date: json['tournament_date'] ?? '',
// //       price: int.tryParse(json['price'] ?? '0') ?? 0,
// //       totalSlots: int.tryParse(json['allowed_members'] ?? '0') ?? 0,
// //       bookedSlots: int.tryParse(json['booked_slots'] ?? '0') ?? 0,
// //       location: 'Nahata Sports Complex',
// //       description: cleanHtml,
// //     );
// //   }
// //
// //   String get formattedDescription {
// //     final content = description;
// //
// //     // Generic extractor for labeled sections
// //     String extractSection(String label) {
// //       final regex = RegExp(
// //         '$label\\s*:?\\s*(.*?)(?=(Dates & Timings:|Pass Prices:|Age Group:|Language:|Venue:|\$))',
// //         dotAll: true,
// //         caseSensitive: false,
// //       );
// //       return regex.firstMatch(content)?.group(1)?.trim() ?? '';
// //     }
// //
// //     final aboutText = extractSection('About The Event');
// //     final timingsRaw = extractSection('Dates & Timings');
// //     final passRaw = extractSection('Pass Prices');
// //     final ageGroup = extractSection('Age Group');
// //     final language = extractSection('Language');
// //     final venue = extractSection('Venue');
// //
// //     final timings = timingsRaw
// //         .split(RegExp(r'[\n•]'))
// //         .map((s) => s.trim())
// //         .where((s) => s.isNotEmpty)
// //         .toList();
// //
// //     final passes = passRaw
// //         .split(RegExp(r'[\n•]'))
// //         .map((s) => s.trim())
// //         .where((s) => s.isNotEmpty)
// //         .toList();
// //
// //     final buffer = StringBuffer();
// //
// //     if (aboutText.isNotEmpty) {
// //       buffer.writeln(aboutText);
// //       buffer.writeln();
// //     }
// //
// //     if (timings.isNotEmpty) {
// //       buffer.writeln("📅 Dates & Timings:");
// //       timings.forEach((t) => buffer.writeln(" • $t"));
// //       buffer.writeln();
// //     }
// //
// //     if (passes.isNotEmpty) {
// //       buffer.writeln("🎟️ Pass Prices:");
// //       passes.forEach((p) => buffer.writeln(" • $p"));
// //       buffer.writeln();
// //     }
// //
// //     if (ageGroup.isNotEmpty) buffer.writeln("👨‍👩‍👧‍👦 Age Group: $ageGroup\n");
// //     if (language.isNotEmpty) buffer.writeln("🗣️ Language: $language\n");
// //     if (venue.isNotEmpty) buffer.writeln("📍 Venue: $venue");
// //
// //     return buffer.toString().trim();
// //   }
// //
// //
// //
// // }
// //
// class EventPass {
//   final String id;
//   final String name;
//   final int price;
//   final int totalSlots;
//   final int bookedSlots;
//
//   EventPass({
//     required this.id,
//     required this.name,
//     required this.price,
//     required this.totalSlots,
//     required this.bookedSlots,
//   });
//
//   factory EventPass.fromJson(Map<String, dynamic> json) {
//     return EventPass(
//       id: json['id'].toString(),
//       name: json['name'] ?? '',
//       price: int.tryParse(json['price'].toString()) ?? 0,
//       totalSlots: int.tryParse(json['total_slots'].toString()) ?? 0,
//       bookedSlots: int.tryParse(json['booked_slots'].toString()) ?? 0,
//     );
//   }
// }
//
//
//
//
//
// class EventModel {
//   final String id;
//   final String title;
//   final String image;
//   final String date;
//   final int price;
//   final int totalSlots;
//   final int bookedSlots;
//   final String location;
//   final String description;
//   List<EventPass> passes;
//
//   EventModel({
//     required this.id,
//     required this.title,
//     required this.image,
//     required this.date,
//     required this.price,
//     required this.totalSlots,
//     required this.bookedSlots,
//     required this.location,
//     required this.description,
//     this.passes = const [],
//   });
//
//   List<Map<String, dynamic>> get availablePasses {
//     final passRaw = description.contains("Pass Prices")
//         ? description.split("Pass Prices:").last
//         : "";
//
//     final passes = passRaw
//         .split(RegExp(r'[\n•]'))
//         .map((s) => s.trim())
//         .where((s) => s.isNotEmpty)
//         .toList();
//
//     return passes.map((p) {
//       // Example: "2 Day Pass - ₹1500"
//       final parts = p.split(RegExp(r'[-–:]'));
//       final name = parts.first.trim();
//       final price = int.tryParse(
//           RegExp(r'(\d+)').firstMatch(p)?.group(1) ?? "0") ??
//           0;
//       return {"name": name, "price": price, "raw": p};
//     }).toList();
//   }
//
//   bool get isFull => bookedSlots >= totalSlots;
//   int get availableSlots => (totalSlots - bookedSlots).clamp(0, totalSlots);
//
//   factory EventModel.fromJson(Map<String, dynamic> json) {
//     final unescape = HtmlUnescape();
//     final rawContent = json['content'] ?? '';
//     final cleanHtml = unescape
//         .convert(rawContent.replaceAll(RegExp(r'<[^>]*>'), ''))
//         .replaceAll(RegExp(r'\s+\n'), '\n') // normalize whitespace
//         .trim();
//
//     return EventModel(
//       id: json['id'].toString(),
//       title: json['title'] ?? '',
//       image: "https://nahatasports.com/${json['image'] ?? ''}",
//       date: json['tournament_date'] ?? '',
//       price: int.tryParse(json['price'] ?? '0') ?? 0,
//       totalSlots: int.tryParse(json['allowed_members'] ?? '0') ?? 0,
//       bookedSlots: int.tryParse(json['booked_slots'] ?? '0') ?? 0,
//       location: 'Nahata Sports Complex',
//       description: cleanHtml,
//     );
//   }
//
//   /// 🔹 Default formatted description (all passes shown)
//   String get formattedDescription {
//     final content = description;
//
//     String extractSection(String label) {
//       final regex = RegExp(
//         '$label\\s*:?\\s*(.*?)(?=(Dates & Timings:|Pass Prices:|Age Group:|Language:|Venue:|\$))',
//         dotAll: true,
//         caseSensitive: false,
//       );
//       return regex.firstMatch(content)?.group(1)?.trim() ?? '';
//     }
//
//     final aboutText = extractSection('About The Event');
//     final timingsRaw = extractSection('Dates & Timings');
//     final passRaw = extractSection('Pass Prices');
//     final ageGroup = extractSection('Age Group');
//     final language = extractSection('Language');
//     final venue = extractSection('Venue');
//
//     final timings = timingsRaw
//         .split(RegExp(r'[\n•]'))
//         .map((s) => s.trim())
//         .where((s) => s.isNotEmpty)
//         .toList();
//
//     final passes = passRaw
//         .split(RegExp(r'[\n•]'))
//         .map((s) => s.trim())
//         .where((s) => s.isNotEmpty)
//         .toList();
//
//     final buffer = StringBuffer();
//
//     if (aboutText.isNotEmpty) {
//       buffer.writeln(aboutText);
//       buffer.writeln();
//     }
//
//     if (timings.isNotEmpty) {
//       buffer.writeln("📅 Dates & Timings:");
//       timings.forEach((t) => buffer.writeln(" • $t"));
//       buffer.writeln();
//     }
//
//     if (passes.isNotEmpty) {
//       buffer.writeln("🎟️ Pass Prices:");
//       passes.forEach((p) => buffer.writeln(" • $p"));
//       buffer.writeln();
//     }
//
//     if (ageGroup.isNotEmpty) buffer.writeln("👨‍👩‍👧‍👦 Age Group: $ageGroup\n");
//     if (language.isNotEmpty) buffer.writeln("🗣️ Language: $language\n");
//     if (venue.isNotEmpty) buffer.writeln("📍 Venue: $venue");
//
//     return buffer.toString().trim();
//   }
//
//   /// 🔹 New method: formatted description for a selected pass
//   String getDescriptionForPass(String? selectedPassName) {
//     final content = description;
//
//     String extractSection(String label) {
//       final regex = RegExp(
//         '$label\\s*:?\\s*(.*?)(?=(Dates & Timings:|Pass Prices:|Age Group:|Language:|Venue:|\$))',
//         dotAll: true,
//         caseSensitive: false,
//       );
//       return regex.firstMatch(content)?.group(1)?.trim() ?? '';
//     }
//
//     final aboutText = extractSection('About The Event');
//     final timingsRaw = extractSection('Dates & Timings');
//     final passRaw = extractSection('Pass Prices');
//     final ageGroup = extractSection('Age Group');
//     final language = extractSection('Language');
//     final venue = extractSection('Venue');
//
//     final timings = timingsRaw
//         .split(RegExp(r'[\n•]'))
//         .map((s) => s.trim())
//         .where((s) => s.isNotEmpty)
//         .toList();
//
//     final passes = passRaw
//         .split(RegExp(r'[\n•]'))
//         .map((s) => s.trim())
//         .where((s) => s.isNotEmpty)
//         .toList();
//
//     final buffer = StringBuffer();
//
//     if (aboutText.isNotEmpty) {
//       buffer.writeln(aboutText);
//       buffer.writeln();
//     }
//
//     if (timings.isNotEmpty) {
//       buffer.writeln("📅 Dates & Timings:");
//       timings.forEach((t) => buffer.writeln(" • $t"));
//       buffer.writeln();
//     }
//
//     if (passes.isNotEmpty) {
//       buffer.writeln("🎟️ Pass Prices:");
//       if (selectedPassName == null) {
//         passes.forEach((p) => buffer.writeln(" • $p"));
//       } else {
//         final match = passes.firstWhere(
//               (p) => p.toLowerCase().contains(selectedPassName.toLowerCase()),
//           orElse: () => "",
//         );
//         if (match.isNotEmpty) buffer.writeln(" • $match");
//       }
//       buffer.writeln();
//     }
//
//     if (ageGroup.isNotEmpty) buffer.writeln("👨‍👩‍👧‍👦 Age Group: $ageGroup\n");
//     if (language.isNotEmpty) buffer.writeln("🗣️ Language: $language\n");
//     if (venue.isNotEmpty) buffer.writeln("📍 Venue: $venue");
//
//     return buffer.toString().trim();
//   }
// }
//
//
//
// /* -------------------------------------------
//    API Service
//    ------------------------------------------- */
// Future<List<EventModel>> fetchEvents() async {
//   final res = await http.get(Uri.parse("https://nahatasports.com/api/tournaments"));
//   if (res.statusCode != 200) throw Exception("Failed to load events");
//
//   final body = jsonDecode(res.body);
//   final List data = body['data'] ?? [];
//   return data.map((e) => EventModel.fromJson(e)).toList();
// }
//
// /* -------------------------------------------
//    Events List Page
//    ------------------------------------------- */
// class EventsListPage extends StatefulWidget {
//   const EventsListPage({super.key});
//   @override
//   State<EventsListPage> createState() => _EventsListPageState();
// }
//
// class _EventsListPageState extends State<EventsListPage> {
//   late Future<List<EventModel>> _future;
//   @override
//   void initState() {
//     super.initState();
//     _future = fetchEvents();
//   }
//
//   Future<void> _refresh() async {
//     setState(() => _future = fetchEvents());
//     await _future;
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: const Color(0xFF0A198D),
//         elevation: 0,
//           title: const Text('Events & Camps',style: TextStyle(color: Colors.white,
//             fontWeight: FontWeight.bold,
//             fontSize: 20,),),
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back, color: Colors.white),
//           onPressed: () {
//             Navigator.pushReplacement(
//               context,
//               MaterialPageRoute(
//                 builder: (_) => BookPlayScreen(),
//               ),
//             );
//           },
//         ),),
//       body: RefreshIndicator(
//         onRefresh: _refresh,
//         child: FutureBuilder<List<EventModel>>(
//           future: _future,
//           builder: (context, snap) {
//             if (snap.connectionState == ConnectionState.waiting) {
//               return _EventsShimmerList();
//             } else if (snap.hasError) {
//               return Center(child: Text('Failed to load events\n${snap.error}'));
//             } else {
//               final events = snap.data ?? [];
//               if (events.isEmpty) {
//                 return const Center(child: Text('No events available'));
//               }
//               return ListView.separated(
//                 padding: const EdgeInsets.all(12),
//                 itemCount: events.length,
//                 separatorBuilder: (_, __) => const SizedBox(height: 12),
//                 itemBuilder: (context, i) {
//                   final e = events[i];
//                   return EventCard(
//                     event: e,
//                     onTap: () => Navigator.push(
//                       context,
//                       MaterialPageRoute(builder: (_) => EventDetailsPage(event: e)),
//                     ),
//                   );
//                 },
//               );
//             }
//           },
//         ),
//       ),
//     );
//   }
// }
//
// /* -------------------------------------------
//    Event Card
//    ------------------------------------------- */
// class EventCard extends StatelessWidget {
//   final EventModel event;
//   final VoidCallback onTap;
//   const EventCard({required this.event, required this.onTap, super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     final tagText = event.isFull ? 'Full' : '${event.availableSlots} slots';
//     final tagColor = event.isFull ? Colors.redAccent : Colors.greenAccent;
//
//     return GestureDetector(
//       onTap: onTap,
//       child: SizedBox(
//         height: 160,
//         child: Stack(
//           children: [
//             Hero(
//               tag: 'event-image-${event.id}',
//               child: ClipRRect(
//                 borderRadius: BorderRadius.circular(14),
//                 child: Image.network(event.image, width: double.infinity, height: double.infinity, fit: BoxFit.cover),
//               ),
//             ),
//             Container(
//               decoration: BoxDecoration(
//                 borderRadius: BorderRadius.circular(14),
//                 gradient: LinearGradient(
//                   colors: [Colors.black.withOpacity(0.45), Colors.black.withOpacity(0.12)],
//                   begin: Alignment.bottomCenter,
//                   end: Alignment.topCenter,
//                 ),
//               ),
//             ),
//             Positioned(
//               left: 14,
//               bottom: 14,
//               right: 14,
//               child: Row(
//                 crossAxisAlignment: CrossAxisAlignment.end,
//                 children: [
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         Text(event.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
//                         const SizedBox(height: 4),
//                         Row(children: [
//                           Icon(Icons.calendar_today, size: 13, color: Colors.white70),
//                           const SizedBox(width: 6),
//                           Text(event.date, style: const TextStyle(color: Colors.white70, fontSize: 12)),
//                         ]),
//                       ],
//                     ),
//                   ),
//                   Column(
//                     crossAxisAlignment: CrossAxisAlignment.end,
//                     children: [
//                       Container(
//                         padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//                         decoration: BoxDecoration(color: tagColor.withOpacity(0.95), borderRadius: BorderRadius.circular(8)),
//                         child: Text(tagText, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
//                       ),
//                       const SizedBox(height: 10),
//                       Container(
//                         padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//                         decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), borderRadius: BorderRadius.circular(8)),
//                         child: Text(event.price == 0 ? 'FREE' : '₹${event.price}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
//
// /* -------------------------------------------
//    Event Details Page
//    ------------------------------------------- */
// class EventDetailsPage extends StatefulWidget {
//   final EventModel event;
//   const EventDetailsPage({required this.event, super.key});
//
//   @override
//   State<EventDetailsPage> createState() => _EventDetailsPageState();
// }
//
// class _EventDetailsPageState extends State<EventDetailsPage> {
//   String? _selectedSlot;
//   bool _bookingInProgress = false;
//   List<Map<String, dynamic>> _slots = [];
//   int _membersCount = 1;
//   double _totalPrice = 0.0;
//   Razorpay? _razorpay;
//   Map<String, dynamic>? _selectedPass;
//
//
//   @override
//   void initState() {
//     super.initState();
//     _fetchSlots();
//
//     _selectedPass = widget.event.availablePasses.isNotEmpty
//         ? widget.event.availablePasses.first
//         : null;
//     _calculatePrice();
//     _razorpay = Razorpay();
//     _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS,
//             (PaymentSuccessResponse r) => _confirmBooking(r.paymentId));
//     _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
//     _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
//   }
//
//   @override
//   void dispose() {
//     _razorpay?.clear();
//     super.dispose();
//   }
//
//   /// Start Razorpay Checkout
//   void _startPaymentFlow() {
//     if (_selectedSlot == null) {
//       _showSnack('Please select a slot');
//       return;
//     }
//
//     var options = {
//       'key': 'rzp_live_R7b5MMCgg9AlWn', // Replace with real Razorpay key
//        // 'key': 'rzp_test_YwYUHvAMatnKBY',
//       'amount': (_totalPrice * 100).toInt(), // Razorpay expects paise
//       'name': widget.event.title,
//       'description': 'Tournament Booking',
//       'prefill': {
//         'contact': ApiService.currentUser?['phone'] ?? '',
//         'email': ApiService.currentUser?['email'] ?? '',
//       }
//     };
//
//     try {
//       _razorpay!.open(options);
//     } catch (e) {
//       debugPrint("Error: $e");
//       _showSnack("Payment initialization failed");
//     }
//   }
//
//   /// Confirm booking after payment success
//   /// Fetch slots
//   Future<void> _fetchSlots() async {
//     final url = Uri.parse(
//         "https://nahatasports.com/api/tournaments/${widget.event.id}/slots");
//     try {
//       final response = await http.get(
//         url,
//         headers: {"Content-Type": "application/json"},
//       );
//
//       if (response.statusCode == 200) {
//         final decoded = jsonDecode(response.body);
//         if (decoded is Map && decoded['slots'] is List) {
//           final List slots = decoded['slots'];
//           setState(() {
//             _slots = slots
//                 .map((s) => {
//               "id": s['id'],
//               "name": s['slot_name'],
//               "start": s['start_time'],
//               "end": s['end_time'],
//             })
//                 .toList();
//             if (_slots.isNotEmpty) {
//               _selectedSlot = _slots.first['id'];
//             }
//           });
//         } else {
//           _showSnack("No slots available");
//         }
//       } else {
//         _showSnack("Failed to fetch slots");
//       }
//     } catch (e) {
//       debugPrint("Error fetching slots: $e");
//       _showSnack("Error loading slots");
//     }
//   }
//   Future<void> _fetchPasses() async {
//     final url = Uri.parse("https://nahatasports.com/api/tournaments/${widget.event.id}/passes");
//     try {
//       final response = await http.get(url);
//       if (response.statusCode == 200) {
//         final decoded = jsonDecode(response.body);
//         if (decoded is Map && decoded['passes'] is List) {
//           final List data = decoded['passes'];
//           setState(() {
//             widget.event.passes = data.map((e) => EventPass.fromJson(e)).toList();
//             if (widget.event.passes.isNotEmpty) {
//               _selectedPass = {
//                 "name": widget.event.passes.first.name,
//                 "price": widget.event.passes.first.price,
//                 "id": widget.event.passes.first.id,
//               };
//               _calculatePrice();
//             }
//           });
//         }
//       }
//     } catch (e) {
//       debugPrint("Error fetching passes: $e");
//     }
//   }
//
//   /// Confirm booking after payment success
//   Future<void> _confirmBooking(String? razorpayPaymentId) async {
//     if (_selectedSlot == null) {
//       _showSnack("Please select a slot");
//       return;
//     }
//
//     setState(() => _bookingInProgress = true);
//
//     try {
//       final user = ApiService.currentUser;
//       if (user == null) {
//         _showSnack("User not logged in");
//         return;
//       }
//
//       // 1️⃣ Verify payment
//       final verifyUrl = Uri.parse("https://nahatasports.com/api/tournaments/verify-payment");
//       final verifyRes = await http.post(
//         verifyUrl,
//         headers: {"Content-Type": "application/json"},
//         body: jsonEncode({
//           "razorpay_payment_id": razorpayPaymentId ?? "",
//         }),
//       );
//       debugPrint("Verify API response: ${verifyRes.body}");
//
//       // 2️⃣ Confirm booking
//       final confirmUrl = Uri.parse("https://nahatasports.com/api/booking/confirm");
//       final confirmRes = await http.post(
//         confirmUrl,
//         headers: {"Content-Type": "application/json"},
//         body: jsonEncode({
//           "user_id": user['id'].toString(),
//           "tournament_id": widget.event.id.toString(),
//           "slot_id": _selectedSlot.toString(),
//           "name": user['name'] ?? "",
//           "email": user['email'] ?? "",
//           "members_count": _membersCount.toString(),
//         }),
//       );
//
//       debugPrint("Confirm API response: ${confirmRes.body}");
//
//       Map<String, dynamic>? data;
//       try {
//         data = jsonDecode(confirmRes.body);
//       } catch (e) {
//         debugPrint("Failed to parse JSON: $e");
//         _showSnack("Unexpected server response");
//         return;
//       }
//
//       if (data?['status'] == 'success') {
//         final bookingData = BookingData.fromJson(data?['data']);
//         if (!context.mounted) return;
//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(builder: (_) => EventPassPage(booking: bookingData)),
//         );
//       } else {
//         _showSnack(data?['message'] ?? 'Booking failed');
//       }
//     } catch (e) {
//       debugPrint("Booking error: $e");
//       _showSnack("Payment or booking failed. Try again.");
//     } finally {
//       if (mounted) setState(() => _bookingInProgress = false);
//     }
//   }
//
//   // Future<void> _confirmBooking(String? razorpayPaymentId) async {
//   //   if (_selectedSlot == null) {
//   //     _showSnack("Please select a slot");
//   //     return;
//   //   }
//   //
//   //   setState(() => _bookingInProgress = true);
//   //
//   //   try {
//   //     final user = ApiService.currentUser;
//   //     if (user == null) {
//   //       _showSnack("User not logged in");
//   //       return;
//   //     }
//   //
//   //     // 1️⃣ Verify payment
//   //     final verifyUrl =
//   //     Uri.parse("https://nahatasports.com/api/tournaments/verify-payment");
//   //     final verifyRes =
//   //     await http.post(verifyUrl, body: {"razorpay_payment_id": razorpayPaymentId ?? ""});
//   //     debugPrint("Verify API response: ${verifyRes.body}");
//   //
//   //     // 2️⃣ Confirm booking
//   //     final confirmUrl =
//   //     Uri.parse("https://nahatasports.com/api/booking/confirm");
//   //     final confirmRes = await http.post(confirmUrl, body: {
//   //       "user_id": user['id'].toString(),
//   //       "tournament_id": widget.event.id.toString(),
//   //       "slot_id": _selectedSlot.toString(),
//   //       "name": user['name'] ?? "",
//   //       "email": user['email'] ?? "",
//   //       "members_count": _membersCount.toString(),
//   //     });
//   //
//   //     debugPrint("Confirm API response: ${confirmRes.body}");
//   //
//   //     Map<String, dynamic>? data;
//   //     try {
//   //       data = jsonDecode(confirmRes.body);
//   //     } catch (e) {
//   //       debugPrint("Failed to parse JSON: $e");
//   //       _showSnack("Unexpected server response");
//   //       return;
//   //     }
//   //
//   //     if (data?['status'] == 'success') {
//   //       final bookingData = BookingData.fromJson(data?['data']);
//   //       if (!context.mounted) return;
//   //       Navigator.pushReplacement(
//   //         context,
//   //         MaterialPageRoute(builder: (_) => EventPassPage(booking: bookingData)),
//   //       );
//   //     } else {
//   //       _showSnack(data?['message'] ?? 'Booking failed');
//   //     }
//   //   } catch (e) {
//   //     debugPrint("Booking error: $e");
//   //     _showSnack("Payment or booking failed. Try again.");
//   //   } finally {
//   //     if (mounted) setState(() => _bookingInProgress = false);
//   //   }
//   // }
//
//   void _handlePaymentError(PaymentFailureResponse response) {
//     _showSnack("Payment failed: ${response.message}");
//   }
//
//   void _handleExternalWallet(ExternalWalletResponse response) {
//     _showSnack("External Wallet selected: ${response.walletName}");
//   }
//
//   /// Fetch slots
//   // Future<void> _fetchSlots() async {
//   //   final url = Uri.parse(
//   //       "https://nahatasports.com/api/tournaments/${widget.event.id}/slots");
//   //   try {
//   //     final response = await http.get(url);
//   //     if (response.statusCode == 200) {
//   //       final decoded = jsonDecode(response.body);
//   //       if (decoded is Map && decoded['slots'] is List) {
//   //         final List slots = decoded['slots'];
//   //         setState(() {
//   //           _slots = slots
//   //               .map((s) => {
//   //             "id": s['id'],
//   //             "name": s['slot_name'],
//   //             "start": s['start_time'],
//   //             "end": s['end_time'],
//   //           })
//   //               .toList();
//   //           if (_slots.isNotEmpty) {
//   //             _selectedSlot = _slots.first['id'];
//   //           }
//   //         });
//   //       } else {
//   //         _showSnack("No slots available");
//   //       }
//   //     } else {
//   //       _showSnack("Failed to fetch slots");
//   //     }
//   //   } catch (e) {
//   //     debugPrint("Error fetching slots: $e");
//   //     _showSnack("Error loading slots");
//   //   }
//   // }
//
//   void _calculatePrice() {
//     setState(() {
//       final price = (_selectedPass?['price'] ?? widget.event.price).toDouble();
//       _totalPrice = price * _membersCount;
//     });
//     // setState(() {
//     //   final price = widget.event.price.toDouble();
//     //   _totalPrice = price * _membersCount;
//     // });
//   }
//
//   void _showSnack(String msg) =>
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
//
//   @override
//   Widget build(BuildContext context) {
//     final e = widget.event;
//     return Scaffold(
//       appBar: AppBar(
//           backgroundColor: const Color(0xFF0A198D),
//           elevation: 0,
//           leading: IconButton(
//             icon: const Icon(Icons.arrow_back, color: Colors.white),
//             onPressed: () {
//               // Navigator.pushReplacement(
//               //   context,
//               //   MaterialPageRoute(
//               //     builder: (_) => LoginScreen(),
//               //   ),
//               // );
//             },
//           ),
//           title: Text(e.title,style: TextStyle(color: Colors.white,
//             fontWeight: FontWeight.bold,
//             fontSize: 20,),)),
//       body: Padding(
//         padding: const EdgeInsets.fromLTRB(16, 18, 16, 90),
//         child: SingleChildScrollView(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Image.network(
//                 e.image,
//                 height: 200,
//                 width: double.infinity,
//                 fit: BoxFit.cover,
//               ),
//               const SizedBox(height: 16),
//
//               Text(e.title,
//                   style: const TextStyle(
//                       fontSize: 22, fontWeight: FontWeight.bold)),
//               const SizedBox(height: 6),
//               Row(
//                 children: [
//                   const Icon(Icons.calendar_today,
//                       size: 16, color: Colors.grey),
//                   const SizedBox(width: 6),
//                   Text("Date: ${e.date}"),
//                 ],
//               ),
//               const SizedBox(height: 6),
//               Row(
//                 children: [
//                   const Icon(Icons.event_seat,
//                       size: 16, color: Colors.grey),
//                   const SizedBox(width: 6),
//                   Text("Available slots: ${e.availableSlots}"),
//                 ],
//               ),
//               const SizedBox(height: 12),
//               if (widget.event.passes.isNotEmpty) ...[
//                 Text("Select Pass", style: Theme.of(context).textTheme.titleSmall),
//                 const SizedBox(height: 8),
//                 Wrap(
//                   spacing: 10,
//                   runSpacing: 10,
//                   children: widget.event.passes.map((p) {
//                     final selected = _selectedPass?['id'] == p.id;
//                     return ChoiceChip(
//                       label: Text("${p.name} (₹${p.price})"),
//                       selected: selected,
//                       onSelected: (v) {
//                         if (v) {
//                           setState(() {
//                             _selectedPass = {"id": p.id, "name": p.name, "price": p.price};
//                             _calculatePrice();
//                           });
//                         }
//                       },
//                     );
//                   }).toList(),
//                 ),
//               ],
//
//               // Text("Select Slot",
//               //     style: Theme.of(context).textTheme.titleSmall),
//               // const SizedBox(height: 8),
//               // if (_slots.isEmpty)
//               //   const Text("Loading slots...")
//               // else
//               //   Wrap(
//               //     spacing: 10,
//               //     runSpacing: 10,
//               //     children: _slots.map((s) {
//               //       final selected = s['id'] == _selectedSlot;
//               //       return ChoiceChip(
//               //         label: Text("${s['name']} (${s['start']} - ${s['end']})"),
//               //         selected: selected,
//               //         onSelected: (v) =>
//               //             setState(() => _selectedSlot = v ? s['id'] : null),
//               //       );
//               //     }).toList(),
//               //   ),
//
//               const SizedBox(height: 12),
//               Row(
//                 children: [
//                   const Icon(Icons.currency_rupee,
//                       size: 16, color: Colors.grey),
//                   const SizedBox(width: 6),
//                   // Text("Price per member: ₹${e.price}"),
//                   Text("Price per member: ₹${_selectedPass?['price'] ?? e.price}"),
//
//                 ],
//               ),
//               const SizedBox(height: 12),
//               Text(
//                 widget.event.getDescriptionForPass(_selectedPass?['name']),
//               ),
//
//               // Text(e.formattedDescription),
//               const SizedBox(height: 18),
//
//               Row(
//                 children: [
//                   const Text("Members: "),
//                   IconButton(
//                     icon: const Icon(Icons.remove_circle),
//                     onPressed: _membersCount > 1
//                         ? () {
//                       setState(() {
//                         _membersCount--;
//                         _calculatePrice();
//                       });
//                     }
//                         : null,
//                   ),
//                   Text("$_membersCount"),
//                   IconButton(
//                     icon: const Icon(Icons.add_circle),
//                     onPressed: () {
//                       setState(() {
//                         _membersCount++;
//                         _calculatePrice();
//                       });
//                     },
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 12),
//               Text("Total Price: ₹$_totalPrice",
//                   style: Theme.of(context).textTheme.titleMedium),
//               const SizedBox(height: 20),
//               AnimatedButton(
//                 onPressed: _startPaymentFlow,
//                 text: 'Pay Now & Confirm Event',
//                 isPrimary: true,
//                 isLoading: _bookingInProgress,
//               )
//
//
//               // ElevatedButton(
//               //   onPressed: _bookingInProgress ? null : _startPaymentFlow,
//               //   style: ElevatedButton.styleFrom(
//               //     minimumSize: const Size(double.infinity, 48),
//               //     shape: RoundedRectangleBorder(
//               //         borderRadius: BorderRadius.circular(8)),
//               //   ),
//               //   child: _bookingInProgress
//               //       ? const SizedBox(
//               //     height: 24,
//               //     width: 24,
//               //     child: CircularProgressIndicator(
//               //         color: Colors.white, strokeWidth: 2),
//               //   )
//               //       : const Text('Pay Now & Confirm Event',
//               //       style: TextStyle(
//               //           fontSize: 16, fontWeight: FontWeight.w600)),
//               // ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
//
//
// /* -------------------------------------------
//    Event Pass Page
//    ------------------------------------------- */
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
//   });
//
//   factory BookingData.fromJson(Map<String, dynamic> json) {
//     final slot = json['slot'] ?? {};
//     return BookingData(
//       bookingId: json['booking_id'].toString(),
//       name: json['name'] ?? '',
//       email: json['email'] ?? '',
//       membersCount: int.tryParse(json['members_count'].toString()) ?? 0,
//       tournament: json['tournament'] ?? '',
//       slotName: slot['slot_name'] ?? '',
//       startTime: slot['start_time'] ?? '',
//       endTime: slot['end_time'] ?? '',
//       qrCode: json['qr_code'] ?? '',
//     );
//   }
// }
//
// class EventPassPage extends StatelessWidget {
//   final BookingData booking;
//   const EventPassPage({required this.booking, super.key});
//
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//           backgroundColor: const Color(0xFF0A198D),
//           elevation: 0,
//           leading: IconButton(
//             icon: const Icon(Icons.arrow_back, color: Colors.white),
//             onPressed: () {
//               // Navigator.pushReplacement(
//               //   context,
//               //   MaterialPageRoute(
//               //     builder: (_) => LoginScreen(),
//               //   ),
//               // );
//             },
//           ),
//           title: const Text('Your Event Pass')),
//       body: Center(
//         child: Padding(
//           padding: const EdgeInsets.all(18),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Text(
//                 booking.tournament,
//                 style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
//               ),
//               const SizedBox(height: 12),
//               Text('Date & Slot: ${booking.startTime} - ${booking.endTime} (${booking.slotName})'),
//               const SizedBox(height: 12),
//               Text('Name: ${booking.name}'),
//               Text('Email: ${booking.email}'),
//               Text('Members: ${booking.membersCount}'),
//               const SizedBox(height: 12),
//               Text('Booking ID: ${booking.bookingId}'),
//               const SizedBox(height: 20),
//               Image.network(booking.qrCode, width: 180, height: 180),
//               const SizedBox(height: 12),
//               const Text('Show this pass at the venue entrance.'),
//               const SizedBox(height: 20),
//
// //               // Share button
// //               ElevatedButton.icon(
// //                 onPressed: () {
// //                   final message = '''
// // 🎟️ Event Pass
// //
// // Tournament: ${booking.tournament}
// // Date & Slot: ${booking.startTime} - ${booking.endTime} (${booking.slotName})
// // Name: ${booking.name}
// // Members: ${booking.membersCount}
// // Booking ID: ${booking.bookingId}
// // QR Code: ${booking.qrCode}
// // ''';
// //                   Share.share(message, subject: "My Event Pass");
// //                 },
// //                 icon: const Icon(Icons.share),
// //                 label: const Text("Share Pass"),
// //                 style: ElevatedButton.styleFrom(
// //                   padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
// //                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
// //                 ),
// //               ),
//
//
//               ElevatedButton.icon(
//                 onPressed: () async {
//                   try {
//                     final message = '''
// 🎟️ Event Pass
//
// Tournament: ${booking.tournament}
// Date & Slot: ${booking.startTime} - ${booking.endTime} (${booking.slotName})
// Name: ${booking.name}
// Members: ${booking.membersCount}
// Booking ID: ${booking.bookingId}
// ''';
//
//                     // Download QR image from network
//                     final response = await http.get(Uri.parse(booking.qrCode));
//                     if (response.statusCode == 200) {
//                       final tempDir = await getTemporaryDirectory();
//                       final file = File('${tempDir.path}/qrcode.png');
//                       await file.writeAsBytes(response.bodyBytes);
//
//                       // Share text + image
//                       await Share.shareXFiles(
//                         [XFile(file.path)],
//                         text: message,
//                         subject: "My Event Pass",
//                       );
//                     } else {
//                       debugPrint("Failed to download QR code");
//                     }
//                   } catch (e) {
//                     debugPrint("Error sharing pass: $e");
//                   }
//                 },
//                 icon: const Icon(Icons.share),
//                 label: const Text("Share Pass"),
//                 style: ElevatedButton.styleFrom(
//                   padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
//
// /* -------------------------------------------
//    Shimmer / Loading
//    ------------------------------------------- */
// class _EventsShimmerList extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return ListView.separated(
//       padding: const EdgeInsets.all(12),
//       itemCount: 3,
//       separatorBuilder: (_, __) => const SizedBox(height: 12),
//       itemBuilder: (context, i) {
//         return Container(
//           height: 160,
//           decoration: BoxDecoration(color: Colors.grey.shade900, borderRadius: BorderRadius.circular(14)),
//         );
//       },
//     );
//   }
// }
