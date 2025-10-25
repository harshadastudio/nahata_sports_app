// import 'package:flutter/material.dart';
// import 'dart:convert';
// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:http/http.dart' as http;
// import 'package:nahata_app/screens/regi.dart';
// import 'package:nahata_app/services/api_service.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:razorpay_flutter/razorpay_flutter.dart';
// import 'package:share_plus/share_plus.dart';
// import 'package:html_unescape/html_unescape.dart';
//
// import '../dashboard/dashboard_screen.dart';
// import '../screens/login_screen.dart';
//
//
// class EventModel {
//   final String id;
//   final String title;
//   final String image;
//   // final String date;
//   // final int price;
//   // final int totalSlots;
//   // final int bookedSlots;
//   final String location;
//   final String description;
//
//   EventModel({
//     required this.id,
//     required this.title,
//     required this.image,
//     // required this.date,
//     // required this.price,
//     // required this.totalSlots,
//     // required this.bookedSlots,
//     required this.location,
//     required this.description,
//   });
//   //
//   // bool get isFull => bookedSlots >= totalSlots;
//   // int get availableSlots => (totalSlots - bookedSlots).clamp(0, totalSlots);
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
//       // date: json['tournament_date'] ?? '',
//       // price: int.tryParse(json['price'] ?? '0') ?? 0,
//       // totalSlots: int.tryParse(json['allowed_members'] ?? '0') ?? 0,
//       // bookedSlots: int.tryParse(json['booked_slots'] ?? '0') ?? 0,
//       location: 'Nahata Sports Complex',
//       description: cleanHtml,
//     );
//   }
//
//   String get formattedDescription {
//     final content = description;
//
//     // Generic extractor for labeled sections
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
//
//
// }
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
//         title: const Text('Events & Camps',style: TextStyle(color: Colors.white,
//           fontWeight: FontWeight.bold,
//           fontSize: 20,),),
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
//     // final tagText = event.isFull ? 'Full' : '${event.availableSlots} slots';
//     // final tagColor = event.isFull ? Colors.redAccent : Colors.greenAccent;
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
//                         // Row(children: [
//                         //   Icon(Icons.calendar_today, size: 13, color: Colors.white70),
//                         //   const SizedBox(width: 6),
//                         //   Text(event.date, style: const TextStyle(color: Colors.white70, fontSize: 12)),
//                         // ]),
//                       ],
//                     ),
//                   ),
//                   Column(
//                     crossAxisAlignment: CrossAxisAlignment.end,
//                     children: [
//                       // Container(
//                       //   padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//                       //   decoration: BoxDecoration(color: tagColor.withOpacity(0.95), borderRadius: BorderRadius.circular(8)),
//                       //   child: Text(tagText, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
//                       // ),
//                       // const SizedBox(height: 10),
//                       // Container(
//                       //   padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//                       //   decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), borderRadius: BorderRadius.circular(8)),
//                       //   // child: Text(event.price == 0 ? 'FREE' : '₹${event.price}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
//                       // ),
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
// class _EventDetailsPageState extends State<EventDetailsPage> {
//   String? _selectedSlot;
//   bool _bookingInProgress = false;
//   List<Map<String, dynamic>> _slots = [];
//   int _membersCount = 1;
//   double _totalPrice = 0.0;
//   Razorpay? _razorpay;
//
//   @override
//   void initState() {
//     super.initState();
//     _fetchSlots();
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
//   /// Fetch slots from API
//   Future<void> _fetchSlots() async {
//     final url = Uri.parse(
//         "https://nahatasports.com/api/tournaments/${widget.event.id}/slots");
//     try {
//       final response = await http.get(url, headers: {"Content-Type": "application/json"});
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
//               "date": s['pass_date'],
//               "price": s['pass_price'],
//               "pass_type":s['pass_type'],
//               "start": s['start_time'],
//               "end": s['end_time'],
//             })
//                 .toList();
//
//             if (_slots.isNotEmpty) {
//               _selectedSlot = _slots.first['id'];
//               _calculatePrice();
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
//
//   /// Razorpay payment start
//   void _startPaymentFlow() {
//     if (ApiService.currentUser == null) {
//       Navigator.pushAndRemoveUntil(
//         context,
//         MaterialPageRoute(builder: (_) => LoginScreen()),
//             (route) => false, // this removes all previous routes
//       );
//
//       return;
//     }
//     if (_selectedSlot == null) {
//       _showSnack('Please select a slot');
//       return;
//     }
//
//     var options = {
//       // 'key': 'rzp_test_YwYUHvAMatnKBY', // Replace with live key in production
//       'key': 'rzp_live_R7b5MMCgg9AlWn',
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
//   /// Confirm booking after successful payment
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
//       // Verify payment
//       final verifyUrl =
//       Uri.parse("https://nahatasports.com/api/tournaments/verify-payment");
//       final verifyRes = await http.post(
//         verifyUrl,
//         headers: {"Content-Type": "application/json"},
//         body: jsonEncode({
//           "razorpay_payment_id": razorpayPaymentId ?? "",
//         }),
//       );
//       debugPrint("Verify API response: ${verifyRes.body}");
//
//       // Confirm booking
//       final confirmUrl =
//       Uri.parse("https://nahatasports.com/api/booking/confirm");
//       final confirmRes = await http.post(
//         confirmUrl,
//         headers: {"Content-Type": "application/json"},
//         body:
//         jsonEncode({
//           "user_id": user['id'],
//           "tournament_id": widget.event.id,
//           "slot_id": _selectedSlot,
//           "name": user['name'] ?? "",
//           "email": user['email'] ?? "",
//           "members_count": _membersCount,
//         }),
//         // jsonEncode({
//         //   "user_id": user['id'].toString(),
//         //   "tournament_id": widget.event.id.toString(),
//         //   "slot_id": _selectedSlot.toString(),
//         //   "name": user['name'] ?? "",
//         //   "email": user['email'] ?? "",
//         //   "members_count": _membersCount.toString(),
//         // }),
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
//           MaterialPageRoute(
//             builder: (_) => EventPassPage(
//               booking: bookingData,
//               eventImage: widget.event.image,
//             ),
//           ),
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
//   void _handlePaymentError(PaymentFailureResponse response) {
//     _showSnack("Payment failed");
//   }
//
//   void _handleExternalWallet(ExternalWalletResponse response) {
//     _showSnack("External Wallet selected: ${response.walletName}");
//   }
//
//   /// Calculate total price
//   void _calculatePrice() {
//     final selected = _slots.firstWhere(
//           (s) => s['id'] == _selectedSlot,
//       orElse: () => {"price": "0"},
//     );
//     final slotPrice = double.tryParse(selected['price'].toString()) ?? 0.0;
//     setState(() => _totalPrice = slotPrice * _membersCount);
//   }
//
//   /// Format time from "HH:mm:ss" → "h:mm a"
//   String _formatTime(String time) {
//     final parts = time.split(":");
//     final now = DateTime.now();
//     final dt = DateTime(
//         now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
//     return TimeOfDay.fromDateTime(dt).format(context);
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
//         backgroundColor: const Color(0xFF0A198D),
//         elevation: 0,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back, color: Colors.white),
//           onPressed: () {
//             Navigator.pushReplacement(
//               context,
//               MaterialPageRoute(builder: (_) => EventsListPage()),
//             );
//           },
//         ),
//         title: Text(
//           e.title,
//           style: const TextStyle(
//             color: Colors.white,
//             fontWeight: FontWeight.bold,
//             fontSize: 20,
//           ),
//         ),
//       ),
//       body: Stack(
//         children: [
//           Padding(
//             padding: const EdgeInsets.fromLTRB(16, 18, 16, 90),
//             child: SingleChildScrollView(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Image.network(
//                     e.image,
//                     height: 200,
//                     width: double.infinity,
//                     fit: BoxFit.cover,
//                   ),
//                   const SizedBox(height: 16),
//
//                   Text(e.title,
//                       style: const TextStyle(
//                           fontSize: 22, fontWeight: FontWeight.bold)),
//                   const SizedBox(height: 6),
//
//                   // Row(
//                   //   children: [
//                   //     const Icon(Icons.calendar_today,
//                   //         size: 16, color: Colors.grey),
//                   //     const SizedBox(width: 6),
//                   //     Text("Date: ${e.date}"),
//                   //   ],
//                   // ),
//                   // const SizedBox(height: 6),
//                   //
//                   // Row(
//                   //   children: [
//                   //     const Icon(Icons.event_seat,
//                   //         size: 16, color: Colors.grey),
//                   //     const SizedBox(width: 6),
//                   //     Text("Available slots: ${e.availableSlots}"),
//                   //   ],
//                   // ),
//                   // const SizedBox(height: 12),
//
//                   Text("Select Slot",
//                       style: Theme.of(context).textTheme.titleSmall),
//                   const SizedBox(height: 8),
//                   if (_slots.isEmpty)
//                     const Text("Loading slots...")
//                   else
//                     Wrap(
//                       spacing: 10,
//                       runSpacing: 10,
//                       children: _slots.map((s) {
//                         final selected = s['id'] == _selectedSlot;
//                         return ChoiceChip(
//                           label: Text(
//                               "${s['name']} (${_formatTime(s['start'])} - ${_formatTime(s['end'])}) ${s['pass_type']}"),
//                           selected: selected,
//                           onSelected: (v) {
//                             if (v) {
//                               setState(() => _selectedSlot = s['id']);
//                               _calculatePrice();
//                             }
//                           },
//                         );
//                       }).toList(),
//                     ),
//
//                   const SizedBox(height: 12),
//                   Row(
//                     children: [
//                       const Icon(Icons.currency_rupee,
//                           size: 16, color: Colors.grey),
//                       const SizedBox(width: 6),
//                       if (_selectedSlot != null)
//                         Text(
//                           "Price per member: ₹${_slots.firstWhere(
//                                 (s) => s['id'] == _selectedSlot,
//                             orElse: () => _slots.first,
//                           )['price']}",
//                         ),
//                     ],
//                   ),
//
//                   const SizedBox(height: 12),
//                   Text(e.formattedDescription),
//                   const SizedBox(height: 18),
//
//                   Row(
//                     children: [
//                       const Text("Members: "),
//                       IconButton(
//                         icon: const Icon(Icons.remove_circle),
//                         onPressed: _membersCount > 1
//                             ? () {
//                           setState(() {
//                             _membersCount--;
//                             _calculatePrice();
//                           });
//                         }
//                             : null,
//                       ),
//                       Text("$_membersCount"),
//                       IconButton(
//                         icon: const Icon(Icons.add_circle),
//                         onPressed: () {
//                           setState(() {
//                             _membersCount++;
//                             _calculatePrice();
//                           });
//                         },
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 12),
//
//                   Text("Total Price: ₹$_totalPrice",
//                       style: Theme.of(context).textTheme.titleMedium),
//                   const SizedBox(height: 20),
//
//                   AnimatedButton(
//                     onPressed: _startPaymentFlow,
//                     text: 'Pay Now & Confirm Event',
//                     isPrimary: true,
//                     isLoading: _bookingInProgress,
//                   ),
//                 ],
//               ),
//             ),
//           ),
//
//           // 🔄 Loading overlay
//           if (_bookingInProgress)
//             Container(
//               color: Colors.black54,
//               child: const Center(child: CircularProgressIndicator()),
//             ),
//         ],
//       ),
//     );
//   }
// }
//
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
// class EventPassPage extends StatelessWidget {
//   final BookingData booking;
//   final String eventImage;
//
//   const EventPassPage(
//       {required this.booking, super.key, required this.eventImage});
// // After successful payment
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFF5F7FA),
//       appBar: AppBar(
//         backgroundColor: const Color(0xFF0A198D),
//         elevation: 0,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back, color: Colors.white),
//           onPressed: () => Navigator.pop(context),
//         ),
//         title: const Text(
//           'Your Event Pass',
//           style: TextStyle(
//             fontWeight: FontWeight.w600,
//             fontSize: 18,
//             color: Colors.white
//           ),
//         ),
//         centerTitle: true,
//       ),
//       body: SafeArea(
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.all(16),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.stretch,
//             children: [
//               // Event Pass Card
//               Container(
//                 width: double.infinity,
//                 decoration: BoxDecoration(
//                   borderRadius: BorderRadius.circular(16),
//                   color: Colors.white,
//                   boxShadow: [
//                     BoxShadow(
//                       color: Colors.black.withOpacity(0.1),
//                       blurRadius: 20,
//                       offset: const Offset(0, 4),
//                     ),
//                   ],
//                 ),
//                 child: Column(
//                   children: [
//                     // Header with event image
//                     Container(
//                       height: 120,
//                       decoration: BoxDecoration(
//                         borderRadius: const BorderRadius.only(
//                           topLeft: Radius.circular(16),
//                           topRight: Radius.circular(16),
//                         ),
//                         image: DecorationImage(
//                           image: NetworkImage(eventImage),
//                           fit: BoxFit.cover,
//                         ),
//                       ),
//                       child: Container(
//                         decoration: BoxDecoration(
//                           borderRadius: const BorderRadius.only(
//                             topLeft: Radius.circular(16),
//                             topRight: Radius.circular(16),
//                           ),
//                           gradient: LinearGradient(
//                             begin: Alignment.topCenter,
//                             end: Alignment.bottomCenter,
//                             colors: [
//                               Colors.black.withOpacity(0.6),
//                               Colors.transparent,
//                             ],
//                           ),
//                         ),
//                         child: Center(
//                           child: Padding(
//                             padding: const EdgeInsets.symmetric(horizontal: 16),
//                             child: Text(
//                               booking.tournament.toUpperCase(),
//                               style: const TextStyle(
//                                 color: Colors.white,
//                                 fontSize: 20,
//                                 fontWeight: FontWeight.bold,
//                                 letterSpacing: 1.2,
//                               ),
//                               textAlign: TextAlign.center,
//                               maxLines: 2,
//                               overflow: TextOverflow.ellipsis,
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),
//
//                     // Event details
//                     Padding(
//                       padding: const EdgeInsets.all(20),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           _buildDetailRow(
//                             Icons.calendar_today,
//                             'Date & Time',
//                             '${booking.startTime} - ${booking.endTime}',
//                           ),
//                           const SizedBox(height: 12),
//
//                           _buildDetailRow(
//                             Icons.access_time,
//                             'Slot',
//                             booking.slotName,
//                           ),
//                           const SizedBox(height: 16),
//
//                           const Divider(height: 1),
//                           const SizedBox(height: 16),
//
//                           const Text(
//                             'ATTENDEE INFORMATION',
//                             style: TextStyle(
//                               fontSize: 14,
//                               fontWeight: FontWeight.w600,
//                               color: Color(0xFF6B7280),
//                             ),
//                           ),
//                           const SizedBox(height: 12),
//
//                           _buildDetailRow(
//                             Icons.person,
//                             'Name',
//                             booking.name,
//                           ),
//                           const SizedBox(height: 8),
//
//                           _buildDetailRow(
//                             Icons.email,
//                             'Email',
//                             booking.email,
//                           ),
//                           const SizedBox(height: 8),
//
//                           _buildDetailRow(
//                             Icons.group,
//                             'Members',
//                             booking.membersCount.toString(),
//                           ),
//                           const SizedBox(height: 16),
//
//                           const Divider(height: 1),
//                           const SizedBox(height: 16),
//
//                           _buildDetailRow(
//                             Icons.confirmation_number,
//                             'Booking ID',
//                             booking.bookingId,
//                             isBold: true,
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//
//               const SizedBox(height: 24),
//
//               // QR Code Card
//               Container(
//                 width: double.infinity,
//                 padding: const EdgeInsets.all(20),
//                 decoration: BoxDecoration(
//                   borderRadius: BorderRadius.circular(16),
//                   color: Colors.white,
//                   boxShadow: [
//                     BoxShadow(
//                       color: Colors.black.withOpacity(0.1),
//                       blurRadius: 20,
//                       offset: const Offset(0, 4),
//                     ),
//                   ],
//                 ),
//                 child: Column(
//                   children: [
//                     const Text(
//                       'SCAN AT ENTRANCE',
//                       style: TextStyle(
//                         fontSize: 14,
//                         fontWeight: FontWeight.w600,
//                         color: Color(0xFF6B7280),
//                         letterSpacing: 1.0,
//                       ),
//                     ),
//                     const SizedBox(height: 16),
//
//                     // QR Code
//                     Container(
//                       padding: const EdgeInsets.all(16),
//                       decoration: BoxDecoration(
//                         borderRadius: BorderRadius.circular(12),
//                         border: Border.all(
//                           color: const Color(0xFF0A198D).withOpacity(0.2),
//                           width: 1,
//                         ),
//                       ),
//                       child: Image.network(
//                         booking.qrCode,
//                         width: 180,
//                         height: 180,
//                         fit: BoxFit.contain,
//                         errorBuilder: (context, error, stackTrace) {
//                           return Container(
//                             width: 180,
//                             height: 180,
//                             color: Colors.grey[200],
//                             child: const Icon(
//                               Icons.error_outline,
//                               color: Colors.grey,
//                               size: 40,
//                             ),
//                           );
//                         },
//                         loadingBuilder: (context, child, loadingProgress) {
//                           if (loadingProgress == null) return child;
//                           return Container(
//                             width: 180,
//                             height: 180,
//                             color: Colors.grey[200],
//                             child: const Center(
//                               child: CircularProgressIndicator(
//                                 valueColor: AlwaysStoppedAnimation<Color>(
//                                     Color(0xFF0A198D)),
//                               ),
//                             ),
//                           );
//                         },
//                       ),
//                     ),
//                     const SizedBox(height: 16),
//
//                     const Text(
//                       'Show this pass at the venue entrance',
//                       style: TextStyle(
//                         fontSize: 14,
//                         color: Color(0xFF6B7280),
//                       ),
//                       textAlign: TextAlign.center,
//                     ),
//                   ],
//                 ),
//               ),
//
//               const SizedBox(height: 24),
//
//               // Share button (scrollable, not fixed)
//               SizedBox(
//                 width: double.infinity,
//                 child: ElevatedButton.icon(
//                   onPressed: () => _shareEventPass(context),
//                   icon: const Icon(Icons.share, size: 20),
//                   label: const Text(
//                     "SHARE EVENT PASS",
//                     style: TextStyle(
//                       fontWeight: FontWeight.w600,
//                       letterSpacing: 0.5,
//                     ),
//                   ),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: const Color(0xFF0A198D),
//                     foregroundColor: Colors.white,
//                     padding: const EdgeInsets.symmetric(vertical: 16),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     elevation: 0,
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 16),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildDetailRow(IconData icon, String title, String value,
//       {bool isBold = false}) {
//     return Row(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Icon(
//           icon,
//           size: 20,
//           color: const Color(0xFF6B7280),
//         ),
//         const SizedBox(width: 12),
//         Expanded(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 title,
//                 style: const TextStyle(
//                   fontSize: 12,
//                   color: Color(0xFF6B7280),
//                 ),
//               ),
//               const SizedBox(height: 4),
//               Text(
//                 value,
//                 style: TextStyle(
//                   fontSize: 14,
//                   fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
//                   color: Colors.black,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }
//   Future<void> _shareEventPass(BuildContext context) async {
//     final appLink =
//         "https://play.google.com/store/apps/details?id=com.nahata_sports_app&pcampaignid=web_share";
//
//     final message = '''
// 🎟️ Your Event Pass for ${booking.tournament}
//  Date & Slot: ${booking.startTime} - ${booking.endTime} (${booking.slotName})
// Download the app to view your pass securely:
//
// $appLink
//
// Your referral code: ${booking.userid ?? "N/A"}
// ''';
//
//     try {
//       final response = await http.get(Uri.parse(eventImage));
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
//     // ✅ After sharing, show confirmation popup
//     if (context.mounted) {
//       showDialog(
//         context: context,
//         builder: (_) => AlertDialog(
//           title: const Text("Booking Confirmed"),
//           content: const Text(
//             "Your event pass has been shared successfully.\n\nSee you at the event!",
//           ),
//           actions: [
//             TextButton(
//               onPressed: () {
//                 Navigator.pop(context); // close dialog
//                 // Navigate to Book & Play screen
//                 Navigator.pushReplacement(
//                   context,
//                   MaterialPageRoute(builder: (_) => const BookPlayScreen()),
//                 );
//               },
//               child: const Text("OK"),
//             ),
//           ],
//         ),
//       );
//     }
//   }
//
// //   Future<void> _shareEventPass(BuildContext context) async {
// //     final appLink = "https://play.google.com/store/apps/details?id=com.nahata_sports_app&pcampaignid=web_share";
// //
// //     final message = '''
// // 🎟️ Your Event Pass for ${booking.tournament}
// //  Date & Slot: ${booking.startTime} - ${booking.endTime} (${booking.slotName})
// // Download the app to view your pass securely:
// //
// // $appLink
// //
// // Your referral code: ${booking.userid ?? "N/A"}
// // ''';
// //
// //     try {
// //       final response = await http.get(Uri.parse(eventImage));
// //       if (response.statusCode == 200) {
// //         final tempDir = await getTemporaryDirectory();
// //         final file = File('${tempDir.path}/event_image.png');
// //         await file.writeAsBytes(response.bodyBytes);
// //
// //         await Share.shareXFiles([XFile(file.path)], text: message);
// //       } else {
// //         debugPrint("Failed to download event image, sharing text only");
// //         await Share.share(message);
// //       }
// //     } catch (err) {
// //       debugPrint("Error sharing event image: $err");
// //       await Share.share(message);
// //     }
// //   }
// }
//
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
//
// //
// // class _EventDetailsPageState extends State<EventDetailsPage> {
// //   String? _selectedSlot;
// //   bool _bookingInProgress = false;
// //   List<Map<String, dynamic>> _slots = [];
// //   int _membersCount = 1;
// //   double _totalPrice = 0.0;
// //   Razorpay? _razorpay;
// //
// //   @override
// //   void initState() {
// //     super.initState();
// //     _fetchSlots();
// //     _calculatePrice();
// //
// //     _razorpay = Razorpay();
// //     _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS,
// //             (PaymentSuccessResponse r) => _confirmBooking(r.paymentId));
// //     _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
// //     _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
// //   }
// //
// //   @override
// //   void dispose() {
// //     _razorpay?.clear();
// //     super.dispose();
// //   }
// //
// //   /// Start Razorpay Checkout
// //   void _startPaymentFlow() {
// //     if (ApiService.currentUser == null) {
// //       // 🔑 User not logged in → redirect to Login page
// //       Navigator.push(
// //         context,
// //         MaterialPageRoute(builder: (_) => LoginScreen()),
// //       );
// //       return;
// //     }
// //     if (_selectedSlot == null) {
// //       _showSnack('Please select a slot');
// //       return;
// //     }
// //
// //     var options = {
// //       // 'key': 'rzp_live_R7b5MMCgg9AlWn', // Replace with real Razorpay key
// //        'key': 'rzp_test_YwYUHvAMatnKBY',
// //       'amount': (_totalPrice * 100).toInt(), // Razorpay expects paise
// //       'name': widget.event.title,
// //       'description': 'Tournament Booking',
// //       'prefill': {
// //         'contact': ApiService.currentUser?['phone'] ?? '',
// //         'email': ApiService.currentUser?['email'] ?? '',
// //       }
// //     };
// //
// //     try {
// //       _razorpay!.open(options);
// //     } catch (e) {
// //       debugPrint("Error: $e");
// //       _showSnack("Payment initialization failed");
// //     }
// //   }
// //
// //   /// Confirm booking after payment success
// //   /// Fetch slots
// //   // Future<void> _fetchSlots() async {
// //   //   final url = Uri.parse(
// //   //       "https://nahatasports.com/api/tournaments/${widget.event.id}/slots");
// //   //   try {
// //   //     final response = await http.get(
// //   //       url,
// //   //       headers: {"Content-Type": "application/json"},
// //   //     );
// //   //
// //   //     if (response.statusCode == 200) {
// //   //       final decoded = jsonDecode(response.body);
// //   //       if (decoded is Map && decoded['slots'] is List) {
// //   //         final List slots = decoded['slots'];
// //   //         setState(() {
// //   //           _slots = slots
// //   //               .map((s) => {
// //   //             "id": s['id'],
// //   //             "name": s['slot_name'],
// //   //             "start": s['start_time'],
// //   //             "end": s['end_time'],
// //   //           })
// //   //               .toList();
// //   //           if (_slots.isNotEmpty) {
// //   //             _selectedSlot = _slots.first['id'];
// //   //           }
// //   //         });
// //   //       } else {
// //   //         _showSnack("No slots available");
// //   //       }
// //   //     } else {
// //   //       _showSnack("Failed to fetch slots");
// //   //     }
// //   //   } catch (e) {
// //   //     debugPrint("Error fetching slots: $e");
// //   //     _showSnack("Error loading slots");
// //   //   }
// //   // }
// //   Future<void> _fetchSlots() async {
// //     final url = Uri.parse(
// //         "https://nahatasports.com/api/tournaments/${widget.event.id}/slots");
// //     try {
// //       final response = await http.get(
// //         url,
// //         headers: {"Content-Type": "application/json"},
// //       );
// //
// //       if (response.statusCode == 200) {
// //         final decoded = jsonDecode(response.body);
// //         if (decoded is Map && decoded['slots'] is List) {
// //           final List slots = decoded['slots'];
// //           setState(() {
// //             _slots = slots
// //                 .map((s) => {
// //               "id": s['id'],
// //               "name": s['slot_name'],
// //               "date": s['pass_date'],
// //               "price": s['pass_price'],
// //               "start": s['start_time'],
// //               "end": s['end_time'],
// //             })
// //                 .toList();
// //
// //             if (_slots.isNotEmpty) {
// //               _selectedSlot = _slots.first['id'];
// //             }
// //             _calculatePrice();
// //           });
// //         } else {
// //           _showSnack("No slots available");
// //         }
// //       } else {
// //         _showSnack("Failed to fetch slots");
// //       }
// //     } catch (e) {
// //       debugPrint("Error fetching slots: $e");
// //       _showSnack("Error loading slots");
// //     }
// //   }
// //
// //   /// Confirm booking after payment success
// //   Future<void> _confirmBooking(String? razorpayPaymentId) async {
// //     if (_selectedSlot == null) {
// //       _showSnack("Please select a slot");
// //       return;
// //     }
// //
// //     setState(() => _bookingInProgress = true);
// //
// //     try {
// //       final user = ApiService.currentUser;
// //       if (user == null) {
// //         _showSnack("User not logged in");
// //         return;
// //       }
// //
// //       // 1️⃣ Verify payment
// //       final verifyUrl = Uri.parse("https://nahatasports.com/api/tournaments/verify-payment");
// //       final verifyRes = await http.post(
// //         verifyUrl,
// //         headers: {"Content-Type": "application/json"},
// //         body: jsonEncode({
// //           "razorpay_payment_id": razorpayPaymentId ?? "",
// //         }),
// //       );
// //       debugPrint("Verify API response: ${verifyRes.body}");
// //
// //       // 2️⃣ Confirm booking
// //       final confirmUrl = Uri.parse("https://nahatasports.com/api/booking/confirm");
// //       final confirmRes = await http.post(
// //         confirmUrl,
// //         headers: {"Content-Type": "application/json"},
// //         body: jsonEncode({
// //           "user_id": user['id'].toString(),
// //           "tournament_id": widget.event.id.toString(),
// //           "slot_id": _selectedSlot.toString(),
// //           "name": user['name'] ?? "",
// //           "email": user['email'] ?? "",
// //           "members_count": _membersCount.toString(),
// //         }),
// //       );
// //
// //       debugPrint("Confirm API response: ${confirmRes.body}");
// //
// //       Map<String, dynamic>? data;
// //       try {
// //         data = jsonDecode(confirmRes.body);
// //       } catch (e) {
// //         debugPrint("Failed to parse JSON: $e");
// //         _showSnack("Unexpected server response");
// //         return;
// //       }
// //
// //       if (data?['status'] == 'success') {
// //         final bookingData = BookingData.fromJson(data?['data']);
// //         if (!context.mounted) return;
// //         Navigator.pushReplacement(
// //           context,
// //           MaterialPageRoute(builder: (_) => EventPassPage(
// //               booking: bookingData,  eventImage: widget.event.image,)),
// //
// //         );
// //       } else {
// //         _showSnack(data?['message'] ?? 'Booking failed');
// //       }
// //     } catch (e) {
// //       debugPrint("Booking error: $e");
// //       _showSnack("Payment or booking failed. Try again.");
// //     } finally {
// //       if (mounted) setState(() => _bookingInProgress = false);
// //     }
// //   }
// //
// //
// //
// //   void _handlePaymentError(PaymentFailureResponse response) {
// //     _showSnack("Payment failed");
// //   }
// //
// //   void _handleExternalWallet(ExternalWalletResponse response) {
// //     _showSnack("External Wallet selected: ${response.walletName}");
// //   }
// //
// //   // void _calculatePrice() {
// //   //   setState(() {
// //   //     final selected = _slots.firstWhereOrNull(
// //   //           (s) => s['id'] == _selectedSlot,
// //   //     );
// //   //     if (selected != null) {
// //   //       final slotPrice = double.tryParse(selected['price'].toString()) ?? 0.0;
// //   //       _totalPrice = slotPrice * _membersCount;
// //   //     } else {
// //   //       _totalPrice = 0.0;
// //   //     }
// //   //   });
// //   // }
// //   void _calculatePrice() {
// //     setState(() {
// //       Map<String, dynamic>? selected;
// //
// //       if (_selectedSlot != null) {
// //         // Get the selected slot
// //         selected = _slots.firstWhere(
// //               (s) => s['id'] == _selectedSlot,
// //           orElse: () => _slots.isNotEmpty ? _slots.first : {"price": "0"},
// //         );
// //       } else if (_slots.isNotEmpty) {
// //         // Default to first slot if none selected
// //         selected = _slots.first;
// //         _selectedSlot = selected['id']; // set first slot as selected
// //       }
// //
// //       // Calculate total price
// //       final slotPrice = double.tryParse(selected?['price'].toString() ?? "0") ?? 0.0;
// //       _totalPrice = slotPrice * _membersCount;
// //     });
// //   }
// //
// //   //
// //   // void _calculatePrice() {
// //   //   setState(() {
// //   //     final price = widget.event.price.toDouble();
// //   //     _totalPrice = price * _membersCount;
// //   //   });
// //   // }
// //
// //   void _showSnack(String msg) =>
// //       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     final e = widget.event;
// //     return Scaffold(
// //       appBar: AppBar(
// //           backgroundColor: const Color(0xFF0A198D),
// //           elevation: 0,
// //           leading: IconButton(
// //             icon: const Icon(Icons.arrow_back, color: Colors.white),
// //             onPressed: () {
// //               Navigator.pushReplacement(
// //                 context,
// //                 MaterialPageRoute(
// //                   builder: (_) => EventsListPage(),
// //                 ),
// //               );
// //             },
// //           ),
// //           title: Text(e.title,style: TextStyle(color: Colors.white,
// //             fontWeight: FontWeight.bold,
// //             fontSize: 20,),)),
// //       body: Padding(
// //         padding: const EdgeInsets.fromLTRB(16, 18, 16, 90),
// //         child: SingleChildScrollView(
// //           child: Column(
// //             crossAxisAlignment: CrossAxisAlignment.start,
// //             children: [
// //               Image.network(
// //                 e.image,
// //                 height: 200,
// //                 width: double.infinity,
// //                 fit: BoxFit.cover,
// //               ),
// //               const SizedBox(height: 16),
// //
// //               Text(e.title,
// //                   style: const TextStyle(
// //                       fontSize: 22, fontWeight: FontWeight.bold)),
// //               const SizedBox(height: 6),
// //               Row(
// //                 children: [
// //                   const Icon(Icons.calendar_today,
// //                       size: 16, color: Colors.grey),
// //                   const SizedBox(width: 6),
// //                   Text("Date: ${e.date}"),
// //                 ],
// //               ),
// //               const SizedBox(height: 6),
// //               Row(
// //                 children: [
// //                   const Icon(Icons.event_seat,
// //                       size: 16, color: Colors.grey),
// //                   const SizedBox(width: 6),
// //                   Text("Available slots: ${e.availableSlots}"),
// //                 ],
// //               ),
// //               const SizedBox(height: 12),
// //
// //               Text("Select Slot",
// //                   style: Theme.of(context).textTheme.titleSmall),
// //               const SizedBox(height: 8),
// //               if (_slots.isEmpty)
// //                 const Text("Loading slots...")
// //               else
// //                 Wrap(
// //                   spacing: 10,
// //                   runSpacing: 10,
// //                   children: _slots.map((s) {
// //                     final selected = s['id'] == _selectedSlot;
// //                     return ChoiceChip(
// //                       label: Text("${s['name']} (${s['start']} - ${s['end']})"),
// //                       selected: selected,
// //                       // onSelected: (v) =>
// //                       //     setState(() => _selectedSlot = v ? s['id'] : null),
// //                       onSelected: (v) {
// //                         setState(() => _selectedSlot = v ? s['id'] : null);
// //                         _calculatePrice();
// //                       },
// //
// //                     );
// //                   }).toList(),
// //                 ),
// //
// //               const SizedBox(height: 12),
// //               Row(
// //                 children: [
// //                   const Icon(Icons.currency_rupee,
// //                       size: 16, color: Colors.grey),
// //                   const SizedBox(width: 6),
// //                   if (_selectedSlot != null) ...[
// //                     Row(
// //                       children: [
// //                         // const Icon(Icons.currency_rupee, size: 16, color: Colors.grey),
// //                         // const SizedBox(width: 6),
// //                         Text(
// //                           "Price per member: ₹${_slots.firstWhere(
// //                                 (s) => s['id'] == _selectedSlot,
// //                             orElse: () => _slots.first,
// //                           )['price']}",
// //                         ),
// //
// //
// //                       ],
// //                     ),
// //                   ]
// //
// //                   // Text("Price per member: ₹${e.price}"),
// //                 ],
// //               ),
// //               const SizedBox(height: 12),
// //
// //               Text(e.formattedDescription),
// //               const SizedBox(height: 18),
// //
// //               Row(
// //                 children: [
// //                   const Text("Members: "),
// //                   IconButton(
// //                     icon: const Icon(Icons.remove_circle),
// //                     onPressed: _membersCount > 1
// //                         ? () {
// //                       setState(() {
// //                         _membersCount--;
// //                         _calculatePrice();
// //                       });
// //                     }
// //                         : null,
// //                   ),
// //                   Text("$_membersCount"),
// //                   IconButton(
// //                     icon: const Icon(Icons.add_circle),
// //                     onPressed: () {
// //                       setState(() {
// //                         _membersCount++;
// //                         _calculatePrice();
// //                       });
// //                     },
// //                   ),
// //                 ],
// //               ),
// //               const SizedBox(height: 12),
// //               Text("Total Price: ₹$_totalPrice",
// //                   style: Theme.of(context).textTheme.titleMedium),
// //               const SizedBox(height: 20),
// //               AnimatedButton(
// //                 onPressed: _startPaymentFlow,
// //                 text: 'Pay Now & Confirm Event',
// //                 isPrimary: true,
// //                 isLoading: _bookingInProgress,
// //               )
// //
// //
// //
// //             ],
// //           ),
// //         ),
// //       ),
// //     );
// //   }
// // }
//
// // class EventPassPage extends StatelessWidget {
// //   final BookingData booking;
// //   final String eventImage;
// //   const EventPassPage({required this.booking, super.key, required this.eventImage});
// //
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       appBar: AppBar(
// //           backgroundColor: const Color(0xFF0A198D),
// //           elevation: 0,
// //           leading: IconButton(
// //             icon: const Icon(Icons.arrow_back, color: Colors.white),
// //             onPressed: () {
// //               // Navigator.pushReplacement(
// //               //   context,
// //               //   MaterialPageRoute(
// //               //     builder: (_) => LoginScreen(),
// //               //   ),
// //               // );
// //             },
// //           ),
// //           title: const Text('Your Event Pass')),
// //       body: Center(
// //         child: Padding(
// //           padding: const EdgeInsets.all(18),
// //           child: Column(
// //             mainAxisSize: MainAxisSize.min,
// //             children: [
// //               Text(
// //                 booking.tournament,
// //                 style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
// //               ),
// //               const SizedBox(height: 12),
// //               Text('Date & Slot: ${booking.startTime} - ${booking.endTime} (${booking.slotName})'),
// //               const SizedBox(height: 12),
// //               Text('Name: ${booking.name}'),
// //               Text('Email: ${booking.email}'),
// //               Text('Members: ${booking.membersCount}'),
// //               const SizedBox(height: 12),
// //               Text('Booking ID: ${booking.bookingId}'),
// //               const SizedBox(height: 20),
// //               Image.network(booking.qrCode, width: 180, height: 180),
// //               const SizedBox(height: 12),
// //               const Text('Show this pass at the venue entrance.'),
// //               const SizedBox(height: 20),
// //               ElevatedButton.icon(
// //                 onPressed: () async {
// //                   final appLink = "https://play.google.com/store/apps/details?id=com.nahata_sports_app&pcampaignid=web_share";
// //
// //                   final message = '''
// // 🎟️ Your Event Pass for ${booking.tournament}
// //  Date & Slot: ${booking.startTime} - ${booking.endTime} (${booking.slotName})
// // Download the app to view your pass securely:
// //
// // $appLink
// //
// // Your referral code: ${booking.userid ?? "N/A"}
// // ''';
// //
// //                   try {
// //                     final response = await http.get(Uri.parse(eventImage));
// //                     if (response.statusCode == 200) {
// //                       final tempDir = await getTemporaryDirectory();
// //                       final file = File('${tempDir.path}/event_image.png');
// //                       await file.writeAsBytes(response.bodyBytes);
// //
// //                       await Share.shareXFiles([XFile(file.path)], text: message);
// //                     } else {
// //                       debugPrint("Failed to download event image, sharing text only");
// //                       await Share.share(message);
// //                     }
// //                   } catch (err) {
// //                     debugPrint("Error sharing event image: $err");
// //                     await Share.share(message);
// //                   }
// //                 },
// //                 icon: const Icon(Icons.share),
// //                 label: const Text("Share Pass"),
// //               ),
// //
// //
// //
// // //               ElevatedButton.icon(
// // //                 onPressed: () async {
// // //                   final appLink = "https://play.google.com/store/apps/details?id=com.nahata_sports_app&pcampaignid=web_share";
// // //
// // //                   try {
// // // //                     final message = '''
// // // // 🎟️ Event Pass
// // // //
// // // // Tournament: ${booking.tournament}
// // // // Date & Slot: ${booking.startTime} - ${booking.endTime} (${booking.slotName})
// // // // Name: ${booking.name}
// // // // Members: ${booking.membersCount}
// // // // Booking ID: ${booking.bookingId}
// // // // Used Referral code: ${booking.userid}
// // // //
// // // // ''';
// // //                     final message = '''
// // // 🎟️ Your Event Pass for ${booking.tournament}
// // //
// // // Download the app to view your QR code and access your pass securely:
// // //
// // // $appLink
// // //
// // // Your referral code: ${booking.userid ?? "N/A"}
// // // ''';
// // //
// // //                     print(message);
// // //                     // Download QR image from network
// // //                     final response = await http.get(Uri.parse(booking.qrCode));
// // //                     if (response.statusCode == 200) {
// // //                       final tempDir = await getTemporaryDirectory();
// // //                       final file = File('${tempDir.path}/qrcode.png');
// // //                       await file.writeAsBytes(response.bodyBytes);
// // //
// // //                       // Share text + image
// // //                       await Share.shareXFiles(
// // //                         [XFile(file.path)],
// // //                         text: message,
// // //                         subject: "My Event Pass",
// // //                       );
// // //                     } else {
// // //                       debugPrint("Failed to download QR code");
// // //                     }
// // //                   } catch (e) {
// // //                     debugPrint("Error sharing pass: $e");
// // //                   }
// // //                 },
// // //                 icon: const Icon(Icons.share),
// // //                 label: const Text("Share Pass"),
// // //                 style: ElevatedButton.styleFrom(
// // //                   padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
// // //                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
// // //                 ),
// // //               ),
// //             ],
// //           ),
// //         ),
// //       ),
// //     );
// //   }
// // }