// import 'package:flutter/material.dart';
// import 'package:flutter/material.dart';
// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:razorpay_flutter/razorpay_flutter.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:url_launcher/url_launcher.dart';
//
// import '../services/api_service.dart';
// // class TournamentsPage extends StatefulWidget {
// //   const TournamentsPage({super.key});
// //
// //   @override
// //   State<TournamentsPage> createState() => _TournamentsPageState();
// // }
// //
// // class _TournamentsPageState extends State<TournamentsPage> {
// //   bool isLoading = true;
// //   List<dynamic> tournaments = [];
// //
// //   @override
// //   void initState() {
// //     super.initState();
// //     fetchTournaments();
// //   }
// //
// //   Future<void> fetchTournaments() async {
// //     try {
// //       final response =
// //       await http.get(Uri.parse('https://nahatasports.com/api/tournaments'));
// //       if (response.statusCode == 200) {
// //         final data = json.decode(response.body);
// //         setState(() {
// //           tournaments = data['data'];
// //           isLoading = false;
// //         });
// //       }
// //     } catch (e) {
// //       setState(() => isLoading = false);
// //       print(e);
// //     }
// //   }
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     if (isLoading) {
// //       return const Scaffold(
// //         body: Center(child: CircularProgressIndicator()),
// //       );
// //     }
// //
// //     return Scaffold(
// //       appBar: AppBar(title: const Text("Tournaments")),
// //       body: ListView.builder(
// //         itemCount: tournaments.length,
// //         itemBuilder: (context, index) {
// //           final event = tournaments[index];
// //           return ListTile(
// //             leading: Image.network(
// //               'https://nahatasports.com/${event['image']}',
// //               width: 60,
// //               height: 60,
// //               fit: BoxFit.cover,
// //             ),
// //             title: Text(event['title']),
// //             subtitle: Text('Valid Till: ${event['valid_till']}'),
// //             onTap: () {
// //               // Navigate dynamically using the selected event id
// //               Navigator.push(
// //                 context,
// //                 MaterialPageRoute(
// //                   builder: (_) => EventBookingPageFull(eventId: event['id']),
// //                 ),
// //               );
// //             },
// //           );
// //         },
// //       ),
// //     );
// //   }
// // }
// // class EventBookingPageFull extends StatefulWidget {
// //   final String eventId;
// //
// //   const EventBookingPageFull({super.key, required this.eventId});
// //
// //   @override
// //   State<EventBookingPageFull> createState() => _EventBookingPageFullState();
// // }
// //
// // class _EventBookingPageFullState extends State<EventBookingPageFull> {
// //   String? selectedDate;
// //   String? selectedTime;
// //   int numberOfPasses = 1;
// //
// //   String eventName = '';
// //   String eventImage = '';
// //   double pricePerPass = 100;
// //   List<String> eventDates = [];
// //   Map<String, List<Map<String, dynamic>>> timeSlots = {}; // date -> list of slots with id & time
// //
// //   bool isLoading = true;
// //
// //   @override
// //   void initState() {
// //     super.initState();
// //     fetchEventDetails();
// //   }
// //
// //   Future<void> fetchEventDetails() async {
// //     try {
// //       final response = await http.get(Uri.parse('https://nahatasports.com/api/tournaments'));
// //       if (response.statusCode == 200) {
// //         final data = json.decode(response.body);
// //         final tournaments = data['data'] as List<dynamic>;
// //         final eventData = tournaments.firstWhere(
// //               (t) => t['id'] == widget.eventId,
// //           orElse: () => null,
// //         );
// //
// //         if (eventData != null) {
// //           // Parse slots: [{'id':1,'time':'6 PM'}, ...]
// //           List<Map<String, dynamic>> slots = [];
// //           if (eventData.containsKey('slots')) {
// //             slots = List<Map<String, dynamic>>.from(eventData['slots']);
// //           }
// //
// //           setState(() {
// //             eventName = eventData['title'];
// //             eventImage = 'https://nahatasports.com/${eventData['image']}';
// //             pricePerPass = 100;
// //             selectedDate = eventData['valid_till'];
// //             eventDates = [eventData['valid_till']];
// //
// //             timeSlots = {
// //               eventData['valid_till']: slots.isNotEmpty
// //                   ? slots
// //                   : [
// //                 {'id': 1, 'time': '6 PM'},
// //                 {'id': 2, 'time': '8 PM'}
// //               ],
// //             };
// //
// //             selectedTime = timeSlots[selectedDate!]!.isNotEmpty
// //                 ? timeSlots[selectedDate!]![0]['time']
// //                 : null;
// //
// //             isLoading = false;
// //           });
// //         } else {
// //           setState(() => isLoading = false);
// //         }
// //       } else {
// //         setState(() => isLoading = false);
// //         throw Exception('Failed to fetch tournaments');
// //       }
// //     } catch (e) {
// //       setState(() => isLoading = false);
// //       print(e);
// //     }
// //   }
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     if (isLoading) {
// //       return const Scaffold(
// //         body: Center(child: CircularProgressIndicator()),
// //       );
// //     }
// //
// //     final slotsForDate = selectedDate != null ? timeSlots[selectedDate!] ?? [] : [];
// //
// //     return SafeArea(
// //       child: Scaffold(
// //         appBar: AppBar(
// //           title: Text(eventName),
// //           backgroundColor: const Color(0xFF0A198D),
// //         ),
// //         body: SingleChildScrollView(
// //           child: Column(
// //             crossAxisAlignment: CrossAxisAlignment.start,
// //             children: [
// //               // Event Banner
// //               ClipRRect(
// //                 borderRadius: const BorderRadius.only(
// //                     bottomLeft: Radius.circular(20),
// //                     bottomRight: Radius.circular(20)),
// //                 child: Image.network(
// //                   eventImage,
// //                   fit: BoxFit.cover,
// //                   width: double.infinity,
// //                   height: 220,
// //                 ),
// //               ),
// //               const SizedBox(height: 20),
// //               Padding(
// //                 padding: const EdgeInsets.symmetric(horizontal: 16),
// //                 child: Column(
// //                   crossAxisAlignment: CrossAxisAlignment.start,
// //                   children: [
// //                     Text(eventName,
// //                         style: const TextStyle(
// //                             fontSize: 26, fontWeight: FontWeight.bold)),
// //                     const SizedBox(height: 8),
// //                     Text('Price per Pass: ₹$pricePerPass',
// //                         style:
// //                         const TextStyle(fontSize: 18, color: Colors.grey)),
// //                     const SizedBox(height: 20),
// //
// //                     // Date Picker
// //                     Text('Select Date',
// //                         style: const TextStyle(
// //                             fontSize: 20, fontWeight: FontWeight.bold)),
// //                     const SizedBox(height: 10),
// //                     SizedBox(
// //                       height: 70,
// //                       child: ListView.builder(
// //                         scrollDirection: Axis.horizontal,
// //                         itemCount: eventDates.length,
// //                         itemBuilder: (context, index) {
// //                           final date = eventDates[index];
// //                           final isSelected = date == selectedDate;
// //                           return GestureDetector(
// //                             onTap: () {
// //                               setState(() {
// //                                 selectedDate = date;
// //                                 selectedTime = timeSlots[date]!.isNotEmpty
// //                                     ? timeSlots[date]![0]['time']
// //                                     : null;
// //                               });
// //                             },
// //                             child: AnimatedContainer(
// //                               duration: const Duration(milliseconds: 300),
// //                               margin: const EdgeInsets.only(right: 12),
// //                               padding: const EdgeInsets.symmetric(
// //                                   horizontal: 20, vertical: 15),
// //                               decoration: BoxDecoration(
// //                                 gradient: isSelected
// //                                     ? const LinearGradient(
// //                                     colors: [
// //                                       Colors.deepPurple,
// //                                       Colors.purpleAccent
// //                                     ])
// //                                     : null,
// //                                 color: isSelected ? null : Colors.grey[200],
// //                                 borderRadius: BorderRadius.circular(20),
// //                               ),
// //                               child: Center(
// //                                 child: Text(
// //                                   date,
// //                                   style: TextStyle(
// //                                       color: isSelected
// //                                           ? Colors.white
// //                                           : Colors.black87,
// //                                       fontWeight: FontWeight.bold,
// //                                       fontSize: 16),
// //                                 ),
// //                               ),
// //                             ),
// //                           );
// //                         },
// //                       ),
// //                     ),
// //                     const SizedBox(height: 20),
// //
// //                     // Time Slots
// //                     Text('Select Time',
// //                         style: const TextStyle(
// //                             fontSize: 20, fontWeight: FontWeight.bold)),
// //                     const SizedBox(height: 10),
// //                     Wrap(
// //                       spacing: 12,
// //                       runSpacing: 12,
// //                       children: slotsForDate.map((slot) {
// //                         final isSelected = slot['time'] == selectedTime;
// //                         return GestureDetector(
// //                           onTap: () {
// //                             setState(() {
// //                               selectedTime = slot['time'];
// //                             });
// //                           },
// //                           child: AnimatedContainer(
// //                             duration: const Duration(milliseconds: 300),
// //                             padding: const EdgeInsets.symmetric(
// //                                 horizontal: 20, vertical: 12),
// //                             decoration: BoxDecoration(
// //                               gradient: isSelected
// //                                   ? const LinearGradient(
// //                                   colors: [
// //                                     Colors.deepPurple,
// //                                     Colors.purpleAccent
// //                                   ])
// //                                   : null,
// //                               color: isSelected ? null : Colors.grey[200],
// //                               borderRadius: BorderRadius.circular(20),
// //                             ),
// //                             child: Text(
// //                               slot['time'],
// //                               style: TextStyle(
// //                                 color: isSelected ? Colors.white : Colors.black87,
// //                                 fontWeight: FontWeight.bold,
// //                                 fontSize: 16,
// //                               ),
// //                             ),
// //                           ),
// //                         );
// //                       }).toList(),
// //                     ),
// //                     const SizedBox(height: 20),
// //
// //                     // Pass Selector
// //                     Text('Number of Passes',
// //                         style: const TextStyle(
// //                             fontSize: 20, fontWeight: FontWeight.bold)),
// //                     const SizedBox(height: 10),
// //                     Row(
// //                       children: [
// //                         IconButton(
// //                           icon:
// //                           const Icon(Icons.remove_circle_outline, size: 28),
// //                           onPressed: () {
// //                             if (numberOfPasses > 1) setState(() => numberOfPasses--);
// //                           },
// //                         ),
// //                         Text(numberOfPasses.toString(),
// //                             style: const TextStyle(
// //                                 fontSize: 20, fontWeight: FontWeight.bold)),
// //                         IconButton(
// //                           icon:
// //                           const Icon(Icons.add_circle_outline, size: 28),
// //                           onPressed: () {
// //                             setState(() => numberOfPasses++);
// //                           },
// //                         ),
// //                         const SizedBox(width: 20),
// //                         Text('Total: ₹${(pricePerPass * numberOfPasses).toStringAsFixed(0)}',
// //                             style: const TextStyle(
// //                                 fontSize: 18, fontWeight: FontWeight.bold)),
// //                       ],
// //                     ),
// //                     const SizedBox(height: 30),
// //
// //                     // Book Passes Button
// //                     Center(
// //                       child: ElevatedButton(
// //                         onPressed: () async {
// //                           if (selectedDate == null || selectedTime == null) {
// //                             ScaffoldMessenger.of(context).showSnackBar(
// //                                 const SnackBar(content: Text('Please select date and time')));
// //                             return;
// //                           }
// //
// //                           if (ApiService.currentUser == null) {
// //                             ScaffoldMessenger.of(context).showSnackBar(
// //                                 const SnackBar(content: Text('User not logged in')));
// //                             return;
// //                           }
// //
// //                           final user = ApiService.currentUser!;
// //                           final int userId = user['id'];
// //                           final String userName = user['name'] ?? '';
// //                           final String userEmail = user['email'] ?? '';
// //
// //                           // Dynamic slotId mapping
// //                           int slotId = 0;
// //                           final slotList = timeSlots[selectedDate!];
// //                           if (slotList != null && slotList.isNotEmpty) {
// //                             final slot = slotList.firstWhere(
// //                                     (s) => s['time'] == selectedTime,
// //                                 orElse: () => {});
// //                             if (slot.isNotEmpty) {
// //                               slotId = slot['id'] is int
// //                                   ? slot['id']
// //                                   : int.parse(slot['id'].toString());
// //                             }
// //                           }
// //
// //                           final bookingData = {
// //                             "user_id": userId,
// //                             "tournament_id": int.parse(widget.eventId),
// //                             "slot_id": slotId,
// //                             "name": userName,
// //                             "email": userEmail,
// //                             "members_count": numberOfPasses
// //                           };
// //
// //                           showDialog(
// //                             context: context,
// //                             barrierDismissible: false,
// //                             builder: (_) =>
// //                             const Center(child: CircularProgressIndicator()),
// //                           );
// //
// //                           try {
// //                             final response = await http.post(
// //                               Uri.parse('https://nahatasports.com/api/booking/confirm'),
// //                               headers: {"Content-Type": "application/json"},
// //                               body: jsonEncode(bookingData),
// //                             );
// //
// //                             Navigator.pop(context);
// //
// //                             if (response.statusCode == 200) {
// //                               final res = json.decode(response.body);
// //                               if (res['status'] == 'success') {
// //                                 final qrUrl = res['data']['qr_code'];
// //                                 showDialog(
// //                                   context: context,
// //                                   builder: (_) => AlertDialog(
// //                                     title: const Text('Booking Confirmed!'),
// //                                     content: Column(
// //                                       mainAxisSize: MainAxisSize.min,
// //                                       children: [
// //                                         Text('Name: ${res['data']['name']}'),
// //                                         Text('Members: ${res['data']['members_count']}'),
// //                                         Text('Tournament: ${res['data']['tournament']}'),
// //                                         Text(
// //                                             'Slot: ${res['data']['slot']['slot_name']} (${res['data']['slot']['start_time']} - ${res['data']['slot']['end_time']})'),
// //                                         const SizedBox(height: 10),
// //                                         Image.network(qrUrl),
// //                                       ],
// //                                     ),
// //                                     actions: [
// //                                       TextButton(
// //                                           onPressed: () =>
// //                                               Navigator.pop(context),
// //                                           child: const Text('OK')),
// //                                     ],
// //                                   ),
// //                                 );
// //                               } else {
// //                                 ScaffoldMessenger.of(context).showSnackBar(
// //                                     SnackBar(content: Text(res['message'] ?? 'Booking failed')));
// //                               }
// //                             } else {
// //                               ScaffoldMessenger.of(context).showSnackBar(
// //                                   const SnackBar(content: Text('Server error. Try again later')));
// //                             }
// //                           } catch (e) {
// //                             Navigator.pop(context);
// //                             ScaffoldMessenger.of(context)
// //                                 .showSnackBar(SnackBar(content: Text('Error: $e')));
// //                           }
// //                         },
// //                         style: ElevatedButton.styleFrom(
// //                           padding: const EdgeInsets.symmetric(
// //                               horizontal: 60, vertical: 16),
// //                           backgroundColor: const Color(0xFF0A198D),
// //                           shape: RoundedRectangleBorder(
// //                               borderRadius: BorderRadius.circular(12)),
// //                         ),
// //                         child: const Text('Book Passes',
// //                             style: TextStyle(fontSize: 20, color: Colors.white)),
// //                       ),
// //                     ),
// //                     const SizedBox(height: 30),
// //                   ],
// //                 ),
// //               ),
// //             ],
// //           ),
// //         ),
// //       ),
// //     );
// //   }
// // }
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
// class TournamentListPage extends StatefulWidget {
//   @override
//   State<TournamentListPage> createState() => _TournamentListPageState();
// }
//
// class _TournamentListPageState extends State<TournamentListPage> {
//   late Future<List<dynamic>> futureEvents;
//
//   @override
//   void initState() {
//     super.initState();
//     futureEvents = fetchTournaments();
//   }
//
//   Future<List<dynamic>> fetchTournaments() async {
//     final res = await http.get(Uri.parse("https://nahatasports.com/api/tournaments"));
//     if (res.statusCode == 200) {
//       final data = jsonDecode(res.body);
//       return data["data"];
//     } else {
//       throw Exception("Failed to fetch tournaments");
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text("Tournaments")),
//       body: FutureBuilder<List<dynamic>>(
//         future: futureEvents,
//         builder: (ctx, snapshot) {
//           if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator());
//           if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
//
//           final events = snapshot.data!;
//           return ListView.builder(
//             itemCount: events.length,
//             itemBuilder: (ctx, i) {
//               final e = events[i];
//               final isFull = e['booked_slots'] == e['allowed_members'];
//
//               return Card(
//                 margin: EdgeInsets.all(12),
//                 child: ListTile(
//                   leading: Image.network("https://nahatasports.com/${e['image']}", width: 60, fit: BoxFit.cover),
//                   title: Text(e['title']),
//                   subtitle: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text("Date: ${e['valid_till']}"),
//                       Text("Slots: ${e['booked_slots']}/${e['allowed_members']}"),
//                       Text("Price: ₹500"), // replace with API field when available
//                     ],
//                   ),
//                   trailing: Chip(
//                     label: Text(isFull ? "Full" : "Available",
//                         style: TextStyle(color: Colors.white)),
//                     backgroundColor: isFull ? Colors.red : Colors.green,
//                   ),
//                   onTap: () {
//                     if (!isFull) {
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(builder: (_) => EventDetailPage(event: e)),
//                       );
//                     }
//                   },
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }
// }
//
//
// class EventDetailPage extends StatefulWidget {
//   final Map<String, dynamic> event;
//   const EventDetailPage({super.key, required this.event});
//
//   @override
//   State<EventDetailPage> createState() => _EventDetailPageState();
// }
//
// class _EventDetailPageState extends State<EventDetailPage> {
//   final membersCtrl = TextEditingController(text: "1");
//   int members = 1;
//
//   // Replace with API field if available
//   int pricePerMember = 500;
//
//   late Razorpay _razorpay;
//
//   @override
//   void initState() {
//     super.initState();
//     _razorpay = Razorpay();
//     _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
//     _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
//   }
//
//   @override
//   void dispose() {
//     _razorpay.clear();
//     membersCtrl.dispose();
//     super.dispose();
//   }
//
//   void startPayment() {
//     var options = {
//       'key': 'rzp_test_YwYUHvAMatnKBY', // your Razorpay key
//       'amount': members * pricePerMember * 100, // in paise
//       'name': widget.event['title'],
//       'description': 'Tournament Booking',
//       'prefill': {
//         'contact': '9999999999',
//         'email': 'test@gmail.com',
//       }
//     };
//     _razorpay.open(options);
//   }
//
//   void _handlePaymentSuccess(PaymentSuccessResponse response) {
//     confirmBooking();
//   }
//
//   void _handlePaymentError(PaymentFailureResponse response) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text("Payment Failed")),
//     );
//   }
//
//   Future<int?> getUserId() async {
//     final prefs = await SharedPreferences.getInstance();
//     return prefs.getInt("user_id");
//   }
//
//   Future<void> confirmBooking() async {
//     final body = {
//       "user_id": await getUserId(),
//       "tournament_id": widget.event['id'],
//       "slot_id": 8, // replace with real slot from API
//       "members_count": members.toString(),
//     };
//
//     final res = await http.post(
//       Uri.parse("https://nahatasports.com/api/booking/confirm"),
//       headers: {"Content-Type": "application/json"},
//       body: jsonEncode(body),
//     );
//
//     final data = jsonDecode(res.body);
//     if (data["status"] == "success") {
//       Navigator.push(
//         context,
//         MaterialPageRoute(builder: (_) => BookingConfirmationPage(data: data["data"])),
//       );
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text("Booking failed")),
//       );
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final e = widget.event;
//
//     return Scaffold(
//       appBar: AppBar(title: Text(e['title'])),
//       body: Padding(
//         padding: EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Event Image
//             ClipRRect(
//               borderRadius: BorderRadius.circular(12),
//               child: Image.network(
//                 "https://nahatasports.com/${e['image']}",
//                 height: 200,
//                 width: double.infinity,
//                 fit: BoxFit.cover,
//               ),
//             ),
//             SizedBox(height: 16),
//
//             // Event Info
//             Text(e['title'], style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
//             SizedBox(height: 8),
//             Text("Date: ${e['valid_till']}"),
//             SizedBox(height: 8),
//             Text("Time Slot: 2:00 PM - 4:00 PM"), // replace with slot API
//             SizedBox(height: 8),
//             Text("Price per Member: ₹$pricePerMember"),
//
//             Divider(height: 30),
//
//             // Members Count
//             TextField(
//               controller: membersCtrl,
//               keyboardType: TextInputType.number,
//               decoration: InputDecoration(labelText: "Members Count"),
//               onChanged: (val) => setState(() => members = int.tryParse(val) ?? 1),
//             ),
//             SizedBox(height: 20),
//
//             // Total Price
//             Text("Total Price: ₹${members * pricePerMember}",
//                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//
//             Spacer(),
//
//             // Pay Button
//             SizedBox(
//               width: double.infinity,
//               child: ElevatedButton(
//                 onPressed: startPayment,
//                 child: Text("Proceed to Pay"),
//               ),
//             )
//           ],
//         ),
//       ),
//     );
//   }
// }
//
//
//
//
//
//
// class BookingConfirmationPage extends StatelessWidget {
//   final Map<String, dynamic> data;
//   const BookingConfirmationPage({super.key, required this.data});
//
//   void shareOnWhatsApp() async {
//     final msg = "Booking Confirmed ✅\n"
//         "Tournament: ${data['tournament']}\n"
//         "Members: ${data['members_count']}\n"
//         "Slot: ${data['slot']['slot_name']} (${data['slot']['start_time']} - ${data['slot']['end_time']})\n"
//         "QR: ${data['qr_code']}";
//
//     final url = "https://wa.me/?text=${Uri.encodeComponent(msg)}";
//     if (await canLaunch(url)) {
//       await launch(url);
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text("Booking Confirmed")),
//       body: Padding(
//         padding: EdgeInsets.all(16),
//         child: Column(
//           children: [
//             Text("Booking ID: ${data['booking_id']}", style: TextStyle(fontSize: 20)),
//             SizedBox(height: 10),
//             Image.network(data['qr_code']),
//             SizedBox(height: 20),
//             ElevatedButton.icon(
//               onPressed: shareOnWhatsApp,
//               icon: Icon(Icons.share),
//               label: Text("Share on WhatsApp"),
//             )
//           ],
//         ),
//       ),
//     );
//   }
// }
//
//
//
//
//
//
//
//
//
//
// // class EventBookingPageFull extends StatefulWidget {
// //   final String eventName;
// //   final String eventImage;
// //   final double pricePerPass;
// //   final List<String> eventDates; // Example: ['01 Sep', '02 Sep']
// //   final Map<String, List<String>> timeSlots; // Example: { '01 Sep': ['6 PM', '8 PM'] }
// //
// //   const EventBookingPageFull({
// //     super.key,
// //     required this.eventName,
// //     required this.eventImage,
// //     required this.pricePerPass,
// //     required this.eventDates,
// //     required this.timeSlots,
// //   });
// //
// //   @override
// //   State<EventBookingPageFull> createState() => _EventBookingPageFullState();
// // }
// //
// // class _EventBookingPageFullState extends State<EventBookingPageFull> {
// //   String? selectedDate;
// //   String? selectedTime;
// //   int numberOfPasses = 1;
// //
// //   @override
// //   void initState() {
// //     super.initState();
// //     selectedDate = widget.eventDates.isNotEmpty ? widget.eventDates[0] : null;
// //     selectedTime = selectedDate != null && widget.timeSlots[selectedDate!]!.isNotEmpty
// //         ? widget.timeSlots[selectedDate!]![0]
// //         : null;
// //   }
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     final times = selectedDate != null ? widget.timeSlots[selectedDate!] ?? [] : [];
// //
// //     return SafeArea(
// //       child: Scaffold(
// //         appBar: AppBar(
// //           title: Text(widget.eventName),
// //           backgroundColor: Color(0xFF0A198D),
// //         ),
// //         body: SingleChildScrollView(
// //           child: Column(
// //             crossAxisAlignment: CrossAxisAlignment.start,
// //             children: [
// //               // Event Banner
// //               ClipRRect(
// //                 borderRadius: const BorderRadius.only(
// //                     bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
// //                 child: Image.network(
// //                   widget.eventImage,
// //                   fit: BoxFit.cover,
// //                   width: double.infinity,
// //                   height: 220,
// //                 ),
// //               ),
// //               const SizedBox(height: 20),
// //
// //               Padding(
// //                 padding: const EdgeInsets.symmetric(horizontal: 16),
// //                 child: Column(
// //                   crossAxisAlignment: CrossAxisAlignment.start,
// //                   children: [
// //                     // Event Name
// //                     Text(widget.eventName,
// //                         style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
// //                     const SizedBox(height: 8),
// //
// //                     // Price
// //                     Text('Price per Pass: ₹${widget.pricePerPass}',
// //                         style: const TextStyle(fontSize: 18, color: Colors.grey)),
// //                     const SizedBox(height: 20),
// //
// //                     // Date Picker
// //                     Text('Select Date',
// //                         style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
// //                     const SizedBox(height: 10),
// //                     SizedBox(
// //                       height: 70,
// //                       child: ListView.builder(
// //                         scrollDirection: Axis.horizontal,
// //                         itemCount: widget.eventDates.length,
// //                         itemBuilder: (context, index) {
// //                           final date = widget.eventDates[index];
// //                           final isSelected = date == selectedDate;
// //                           return GestureDetector(
// //                             onTap: () {
// //                               setState(() {
// //                                 selectedDate = date;
// //                                 selectedTime = widget.timeSlots[date]!.isNotEmpty
// //                                     ? widget.timeSlots[date]![0]
// //                                     : null;
// //                               });
// //                             },
// //                             child: AnimatedContainer(
// //                               duration: const Duration(milliseconds: 300),
// //                               margin: const EdgeInsets.only(right: 12),
// //                               padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
// //                               decoration: BoxDecoration(
// //                                 gradient: isSelected
// //                                     ? const LinearGradient(
// //                                     colors: [Colors.deepPurple, Colors.purpleAccent])
// //                                     : null,
// //                                 color: isSelected ? null : Colors.grey[200],
// //                                 borderRadius: BorderRadius.circular(20),
// //                                 boxShadow: isSelected
// //                                     ? [
// //                                   BoxShadow(
// //                                     color: Colors.deepPurple.withOpacity(0.4),
// //                                     blurRadius: 5,
// //                                     offset: const Offset(0, 3),
// //                                   )
// //                                 ]
// //                                     : [],
// //                               ),
// //                               child: Center(
// //                                 child: Text(
// //                                   date,
// //                                   style: TextStyle(
// //                                       color: isSelected ? Colors.white : Colors.black87,
// //                                       fontWeight: FontWeight.bold,
// //                                       fontSize: 16),
// //                                 ),
// //                               ),
// //                             ),
// //                           );
// //                         },
// //                       ),
// //                     ),
// //                     const SizedBox(height: 20),
// //
// //                     // Time Slots (wrap for multiple rows)
// //                     Text('Select Time',
// //                         style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
// //                     const SizedBox(height: 10),
// //                     Wrap(
// //                       spacing: 12,
// //                       runSpacing: 12,
// //                       children: times.map((time) {
// //                         final isSelected = time == selectedTime;
// //                         return GestureDetector(
// //                           onTap: () {
// //                             setState(() {
// //                               selectedTime = time;
// //                             });
// //                           },
// //                           child: AnimatedContainer(
// //                             duration: const Duration(milliseconds: 300),
// //                             padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
// //                             decoration: BoxDecoration(
// //                               gradient: isSelected
// //                                   ? const LinearGradient(
// //                                   colors: [Colors.deepPurple, Colors.purpleAccent])
// //                                   : null,
// //                               color: isSelected ? null : Colors.grey[200],
// //                               borderRadius: BorderRadius.circular(20),
// //                               boxShadow: isSelected
// //                                   ? [
// //                                 BoxShadow(
// //                                   color: Colors.deepPurple.withOpacity(0.4),
// //                                   blurRadius: 5,
// //                                   offset: const Offset(0, 3),
// //                                 )
// //                               ]
// //                                   : [],
// //                             ),
// //                             child: Text(
// //                               time,
// //                               style: TextStyle(
// //                                 color: isSelected ? Colors.white : Colors.black87,
// //                                 fontWeight: FontWeight.bold,
// //                                 fontSize: 16,
// //                               ),
// //                             ),
// //                           ),
// //                         );
// //                       }).toList(),
// //                     ),
// //
// //                     const SizedBox(height: 20),
// //
// //                     // Pass Selector
// //                     Text('Number of Passes',
// //                         style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
// //                     const SizedBox(height: 10),
// //                     Row(
// //                       children: [
// //                         IconButton(
// //                           icon: const Icon(Icons.remove_circle_outline, size: 28),
// //                           onPressed: () {
// //                             if (numberOfPasses > 1) setState(() => numberOfPasses--);
// //                           },
// //                         ),
// //                         Text(numberOfPasses.toString(),
// //                             style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
// //                         IconButton(
// //                           icon: const Icon(Icons.add_circle_outline, size: 28),
// //                           onPressed: () {
// //                             setState(() => numberOfPasses++);
// //                           },
// //                         ),
// //                         const SizedBox(width: 20),
// //                         Text('Total: ₹${(widget.pricePerPass * numberOfPasses).toStringAsFixed(0)}',
// //                             style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
// //                       ],
// //                     ),
// //
// //                     const SizedBox(height: 30),
// //
// //                     // Book Button
// //                     Center(
// //                       child: ElevatedButton(
// //                         onPressed: () {
// //                           // Navigate to payment with selectedDate, selectedTime, numberOfPasses
// //                         },
// //                         style: ElevatedButton.styleFrom(
// //                           padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 16),
// //                           backgroundColor:  Color(0xFF0A198D),
// //                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
// //                         ),
// //                         child: const Text('Book Passes', style: TextStyle(fontSize: 20,color: Colors.white)),
// //                       ),
// //                     ),
// //                     const SizedBox(height: 30),
// //                   ],
// //                 ),
// //               ),
// //             ],
// //           ),
// //         ),
// //       ),
// //     );
// //   }
// // }
//
//
//
//
