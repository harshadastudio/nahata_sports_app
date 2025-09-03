// import 'dart:convert';
//
// import 'package:flutter/material.dart';
// import 'package:table_calendar/table_calendar.dart';
// import 'package:intl/intl.dart';
// import 'package:http/http.dart' as http;
// // class SlotBookingScreen extends StatefulWidget {
// //   final String location;
// //   final String game;
// //
// //   const SlotBookingScreen({
// //     super.key,
// //     required this.location,
// //     required this.game,
// //   });
// //
// //   @override
// //   State<SlotBookingScreen> createState() => _SlotBookingScreenState();
// // }
// //
// // class _SlotBookingScreenState extends State<SlotBookingScreen> {
// //   DateTime _selectedDay = DateTime.now();
// //
// //   /// ✅ Multi-select variables
// //   List<Map<String, dynamic>> selectedSlots = [];
// //   int totalPrice = 0;
// //
// //   List<Map<String, dynamic>> slots = [];
// //   bool isLoading = false;
// //
// //
// //
// //
// //   void proceedToPayment() {
// //     if (selectedSlots.isNotEmpty) {
// //       Navigator.pushNamed(
// //         context,
// //         '/payment',
// //         arguments: {
// //           'location': widget.location,
// //           'game': widget.game,
// //           'date': DateFormat('yyyy-MM-dd').format(_selectedDay),
// //           'slots': selectedSlots, // now includes court, type, time, price
// //           'price': totalPrice,
// //         },
// //       );
// //     } else {
// //       ScaffoldMessenger.of(context).showSnackBar(
// //         const SnackBar(content: Text("Please select at least one time slot")),
// //       );
// //     }
// //   }
// //
// //
// //
// //
// //
// //
// //
// //   // void proceedToPayment() {
// //   //   if (selectedSlots.isNotEmpty) {
// //   //     Navigator.pushNamed(
// //   //       context,
// //   //       '/payment',
// //   //       arguments: {
// //   //         'location': widget.location,
// //   //         'game': widget.game,
// //   //         'date': DateFormat('yyyy-MM-dd').format(_selectedDay),
// //   //         // 'slots': selectedSlots, // send all selected slots
// //   //         'slot': selectedSlots.map((s) => s['time']).join(', '),
// //   //         'price': totalPrice, // total amount
// //   //       },
// //   //     );
// //   //   } else {
// //   //     ScaffoldMessenger.of(context).showSnackBar(
// //   //       const SnackBar(content: Text("Please select at least one time slot")),
// //   //     );
// //   //   }
// //   // }
// //
// //   Future<void> fetchAvailableSlots() async {
// //     final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDay);
// //     final game = widget.game;
// //     final location = widget.location;
// //
// //     final url = Uri.parse(
// //       'https://nahatasports.com/api/courts_wise_price?date=$formattedDate&sport_name=$game&location=$location',
// //     );
// //
// //     try {
// //       setState(() => isLoading = true);
// //
// //       final response = await http.get(url);
// //
// //       if (response.statusCode == 200) {
// //         final responseData = json.decode(response.body);
// //         print('Court-wise price data: $responseData');
// //
// //         if (responseData['status'] == true) {
// //           final List courts = responseData['data'];
// //
// //           setState(() {
// //             slots.clear();
// //
// //             for (var court in courts) {
// //               final courtName = court['court_name'];
// //               final List<dynamic> courtSlots = court['slots'];
// //
// //               for (var slot in courtSlots) {
// //                 slots.add({
// //                   'court': courtName,
// //                   'time': slot['time'].toString(),
// //                   'price': int.tryParse(slot['price'].toString()) ?? 0,
// //                   'type': slot['type'].toString(), // happy_hour / prime_hour / normal
// //                 });
// //               }
// //             }
// //
// //             selectedSlots.clear();
// //             totalPrice = 0;
// //           });
// //         } else {
// //           print('No courts found or error in data.');
// //         }
// //       } else {
// //         print('Error: ${response.statusCode} ${response.reasonPhrase}');
// //       }
// //     } catch (e) {
// //       print('Failed to fetch slots: $e');
// //     } finally {
// //       setState(() => isLoading = false);
// //     }
// //   }
// //
// //
// //   // Future<void> fetchAvailableSlots() async {
// //   //   final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDay);
// //   //   final game = widget.game;
// //   //   final url = Uri.parse(
// //   //       'https://nahatasports.com/available-slots?date=$formattedDate&sport_name=$game');
// //   //
// //   //   try {
// //   //     final response = await http.get(url);
// //   //
// //   //     if (response.statusCode == 200) {
// //   //       final responseData = json.decode(response.body);
// //   //       print('Available slots: $responseData');
// //   //
// //   //       if (responseData['status'] == true) {
// //   //         final data = responseData['data'];
// //   //         final List<dynamic> available = data['available_slots'];
// //   //
// //   //         setState(() {
// //   //           slots.clear();
// //   //           for (var slotItem in available) {
// //   //             if (slotItem is Map) {
// //   //               slots.add({
// //   //                 'time': slotItem['time'].toString(),
// //   //                 'price': int.tryParse(slotItem['price'].toString()) ?? 0,
// //   //               });
// //   //             } else if (slotItem is String) {
// //   //               slots.add({
// //   //                 'time': slotItem,
// //   //                 'price': 100,
// //   //               });
// //   //             }
// //   //           }
// //   //           selectedSlots.clear();
// //   //           totalPrice = 0;
// //   //         });
// //   //       } else {
// //   //         print('No slots found or error in data.');
// //   //       }
// //   //     } else {
// //   //       print('Error: ${response.statusCode} ${response.reasonPhrase}');
// //   //     }
// //   //   } catch (e) {
// //   //     print('Failed to fetch slots: $e');
// //   //   }
// //   // }
// //
// //
// //   List<Widget> _buildCourtWiseUI() {
// //     Map<String, List<Map<String, dynamic>>> courtMap = {};
// //
// //     for (var slot in slots) {
// //       final courtName = slot['court'];
// //       courtMap.putIfAbsent(courtName, () => []);
// //       courtMap[courtName]!.add(slot);
// //     }
// //
// //     return courtMap.entries.map((entry) {
// //       final courtName = entry.key;
// //       final courtSlots = entry.value;
// //
// //       return Card(
// //         margin: const EdgeInsets.symmetric(vertical: 10),
// //         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
// //         color: Colors.white.withOpacity(0.9),
// //         elevation: 3,
// //         child: Padding(
// //           padding: const EdgeInsets.all(12),
// //           child: Column(
// //             crossAxisAlignment: CrossAxisAlignment.start,
// //             children: [
// //               Text(
// //                 courtName,
// //                 style: const TextStyle(
// //                     fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo),
// //               ),
// //               const Divider(),
// //               ...courtSlots.map((slot) => _buildSlotTile(slot)).toList(),
// //             ],
// //           ),
// //         ),
// //       );
// //     }).toList();
// //   }
// //
// //
// //
// //   @override
// //   void initState() {
// //     super.initState();
// //     fetchAvailableSlots();
// //   }
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       backgroundColor: const Color(0xFFF2F4F7),
// //       body: Container(
// //         decoration: const BoxDecoration(
// //           gradient: LinearGradient(
// //             colors: [Color(0xFF1D2B64), Color(0xFFf8cdda)],
// //             begin: Alignment.topCenter,
// //             end: Alignment.bottomCenter,
// //           ),
// //         ),
// //         child: SafeArea(
// //           child: SingleChildScrollView(
// //             padding: const EdgeInsets.all(16),
// //             child: Column(
// //               crossAxisAlignment: CrossAxisAlignment.start,
// //               children: [
// //                 Text(
// //                   '${widget.game} at ${widget.location}',
// //                   style: const TextStyle(
// //                     fontSize: 24,
// //                     fontWeight: FontWeight.bold,
// //                     color: Colors.white,
// //                   ),
// //                 ),
// //                 const SizedBox(height: 20),
// //                 _buildCalendarCard(),
// //                 const SizedBox(height: 20),
// //                 const Text(
// //                   "Available Time Slots",
// //                   style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
// //                 ),
// //                 const SizedBox(height: 12),
// //                  // ...slots.map(_buildSlotTile).toList(),
// //                 ..._buildCourtWiseUI(),
// //
// //                 const SizedBox(height: 20),
// //                 Text("Total: ₹$totalPrice",
// //                     style: const TextStyle(
// //                         fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
// //                 const SizedBox(height: 30),
// //                 SizedBox(
// //                   width: double.infinity,
// //                   child: ElevatedButton(
// //                     style: ElevatedButton.styleFrom(
// //                       padding: const EdgeInsets.symmetric(vertical: 16),
// //                       backgroundColor: const Color(0xFF0A198D),
// //                       shape: RoundedRectangleBorder(
// //                           borderRadius: BorderRadius.circular(12)),
// //                     ),
// //                     onPressed: proceedToPayment,
// //                     child: const Text(
// //                       "Proceed to Payment",
// //                       style: TextStyle(
// //                           fontSize: 16,
// //                           fontWeight: FontWeight.w500,
// //                           color: Colors.white),
// //                     ),
// //                   ),
// //                 ),
// //               ],
// //             ),
// //           ),
// //         ),
// //       ),
// //     );
// //
// //   }
// //
// //   Widget _buildCalendarCard() {
// //     return Card(
// //       color: Colors.white.withOpacity(0.9),
// //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
// //       elevation: 4,
// //       child: Padding(
// //         padding: const EdgeInsets.all(12),
// //         child: Column(
// //           children: [
// //             const Text("Select Date",
// //                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
// //             TableCalendar(
// //               firstDay: DateTime.now(),
// //               lastDay: DateTime.now().add(const Duration(days: 30)),
// //               focusedDay: _selectedDay,
// //               selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
// //               onDaySelected: (selected, _) {
// //                 setState(() {
// //                   _selectedDay = selected;
// //                 });
// //               },
// //               headerStyle: const HeaderStyle(
// //                   formatButtonVisible: false, titleCentered: true),
// //               calendarStyle: CalendarStyle(
// //                 todayDecoration: BoxDecoration(
// //                   color: Colors.indigo.shade100,
// //                   shape: BoxShape.circle,
// //                 ),
// //                 selectedDecoration: BoxDecoration(
// //                   color: Colors.indigo,
// //                   shape: BoxShape.circle,
// //                 ),
// //                 selectedTextStyle: const TextStyle(color: Colors.white),
// //               ),
// //             ),
// //           ],
// //         ),
// //       ),
// //     );
// //   }
// //
// //
// //   Widget _buildSlotTile(Map<String, dynamic> slot) {
// //     final isSelected = selectedSlots.any((s) =>
// //     s['time'] == slot['time'] && s['court'] == slot['court']);
// //
// //     Color priceColor;
// //     String label;
// //     switch (slot['type']) {
// //       case 'happy_hour':
// //         priceColor = Colors.green;
// //         label = "Happy Hour";
// //         break;
// //       case 'prime_hour':
// //         priceColor = Colors.red;
// //         label = "Prime Hour";
// //         break;
// //       default:
// //         priceColor = Colors.black87;
// //         label = "Normal";
// //     }
// //
// //     return InkWell(
// //       onTap: () {
// //         setState(() {
// //           if (isSelected) {
// //             selectedSlots.removeWhere(
// //                     (s) => s['time'] == slot['time'] && s['court'] == slot['court']);
// //           } else {
// //             selectedSlots.add(slot);
// //           }
// //           totalPrice =
// //               selectedSlots.fold(0, (sum, s) => sum + (s['price'] as int));
// //         });
// //       },
// //       child: Container(
// //         margin: const EdgeInsets.symmetric(vertical: 6),
// //         padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
// //         decoration: BoxDecoration(
// //           color: isSelected ? Colors.indigo.shade50 : Colors.white,
// //           borderRadius: BorderRadius.circular(12),
// //           border: Border.all(
// //             color: isSelected ? Colors.indigo : Colors.grey.shade300,
// //             width: 1.2,
// //           ),
// //         ),
// //         child: Row(
// //           mainAxisAlignment: MainAxisAlignment.spaceBetween,
// //           children: [
// //             Column(
// //                 crossAxisAlignment: CrossAxisAlignment.start,
// //                 children: [
// //                   Text(slot['time'], style: const TextStyle(fontSize: 16)),
// //                   Text(label,
// //                       style: TextStyle(
// //                           fontSize: 12,
// //                           fontWeight: FontWeight.w500,
// //                           color: priceColor)),
// //                 ]),
// //             Row(
// //               children: [
// //                 Text('₹${slot['price']}',
// //                     style: TextStyle(
// //                         fontWeight: FontWeight.w600, color: priceColor)),
// //                 const SizedBox(width: 10),
// //                 if (isSelected)
// //                   const Icon(Icons.check_circle, color: Colors.indigo, size: 20),
// //               ],
// //             ),
// //           ],
// //         ),
// //       ),
// //     );
// //   }
// //
// //
// //
// //
// //
// //
// //
// //
// //
// //
// //
// //
// //
// //
// //
// //
// //   // Widget _buildSlotTile(Map<String, dynamic> slot) {
// //   //   final isSelected = selectedSlots.any((s) => s['time'] == slot['time'] && s['court'] == slot['court']);
// //   //
// //   //   Color priceColor;
// //   //   switch (slot['type']) {
// //   //     case 'happy_hour':
// //   //       priceColor = Colors.green;
// //   //       break;
// //   //     case 'prime_hour':
// //   //       priceColor = Colors.red;
// //   //       break;
// //   //     default:
// //   //       priceColor = Colors.black;
// //   //   }
// //   //
// //   //   return InkWell(
// //   //     onTap: () {
// //   //       setState(() {
// //   //         if (isSelected) {
// //   //           selectedSlots.removeWhere((s) => s['time'] == slot['time'] && s['court'] == slot['court']);
// //   //         } else {
// //   //           selectedSlots.add(slot);
// //   //         }
// //   //         totalPrice = selectedSlots.fold(0, (sum, s) => sum + (s['price'] as int));
// //   //       });
// //   //     },
// //   //     child: Container(
// //   //       margin: const EdgeInsets.symmetric(vertical: 6),
// //   //       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
// //   //       decoration: BoxDecoration(
// //   //         color: isSelected ? Colors.white70 : Colors.white.withOpacity(0.9),
// //   //         borderRadius: BorderRadius.circular(12),
// //   //         border: Border.all(
// //   //           color: isSelected ? Colors.indigo : Colors.grey.shade300,
// //   //           width: 1.2,
// //   //         ),
// //   //       ),
// //   //       child: Row(
// //   //         mainAxisAlignment: MainAxisAlignment.spaceBetween,
// //   //         children: [
// //   //           Column(
// //   //             crossAxisAlignment: CrossAxisAlignment.start,
// //   //             children: [
// //   //               Text("${slot['court']} - ${slot['time']}", style: const TextStyle(fontSize: 16)),
// //   //               Text(slot['type'], style: TextStyle(fontSize: 12, color: priceColor)),
// //   //             ],
// //   //           ),
// //   //           Row(
// //   //             children: [
// //   //               Text('₹${slot['price']}', style: TextStyle(fontWeight: FontWeight.w600, color: priceColor)),
// //   //               const SizedBox(width: 10),
// //   //               if (isSelected) const Icon(Icons.check_circle, color: Colors.indigo, size: 20),
// //   //             ],
// //   //           ),
// //   //         ],
// //   //       ),
// //   //     ),
// //   //   );
// //   // }
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
//
//
//
//
//
//
//
// // Future<void> fetchAvailableSlots() async {
// //   final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDay);
// //   final game = widget.game;
// //   final url = Uri.parse('https://nahatasports.com/available-slots?date=$formattedDate&sport_name=$game');
// //
// //   try {
// //     final response = await http.get(url);
// //
// //     if (response.statusCode == 200) {
// //       final responseData = json.decode(response.body);
// //       print('Available slots: $responseData');
// //
// //       if (responseData['status'] == true) {
// //         final data = responseData['data'];
// //         final List<dynamic> available = data['available_slots'];
// //
// //         setState(() {
// //           slots.clear();
// //           for (var time in available) {
// //             slots.add({
// //               'time': time,
// //               'price': 100,
// //             });
// //           }
// //         });
// //       } else {
// //         print('No slots found or error in data.');
// //       }
// //     } else {
// //       print('Error: ${response.statusCode} ${response.reasonPhrase}');
// //     }
// //   } catch (e) {
// //     print('Failed to fetch slots: $e');
// //   }
// // }
//
//
//
//
//
//
// //
// // void toggleSlot(Map<String, dynamic> slot) {
// //   setState(() {
// //     final exists = selectedSlots.any(
// //             (s) => s['court'] == slot['court'] && s['time'] == slot['time']);
// //     if (exists) {
// //       selectedSlots
// //           .removeWhere((s) => s['court'] == slot['court'] && s['time'] == slot['time']);
// //     } else {
// //       selectedSlots.add(slot);
// //     }
// //     totalPrice = selectedSlots.fold(0, (sum, s) => sum + (s['price'] as int));
// //   });
// // }
//
//
//
// // Widget _buildCalendarCard() {
// //   return Card(
// //     color: Colors.white.withOpacity(0.9),
// //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
// //     elevation: 4,
// //     child: Padding(
// //       padding: const EdgeInsets.all(12),
// //       child: Column(
// //         children: [
// //           const Text("Select Date",
// //               style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
// //           TableCalendar(
// //             firstDay: DateTime.now(),
// //             lastDay: DateTime.now().add(const Duration(days: 30)),
// //             focusedDay: _selectedDay,
// //             selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
// //             onDaySelected: (selected, _) {
// //               setState(() => _selectedDay = selected);
// //               fetchCourtsWisePrice();
// //             },
// //             headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
// //             calendarStyle: CalendarStyle(
// //               todayDecoration: BoxDecoration(
// //                 color: Colors.indigo.shade100,
// //                 shape: BoxShape.circle,
// //               ),
// //               selectedDecoration: BoxDecoration(
// //                 color: Colors.indigo,
// //                 shape: BoxShape.circle,
// //               ),
// //               selectedTextStyle: const TextStyle(color: Colors.white),
// //             ),
// //           ),
// //         ],
// //       ),
// //     ),
// //   );
// // }
//
// // List<Widget> _buildCourtCards() {
// //   // Group slots by court
// //   final courtGroups = <String, List<Map<String, dynamic>>>{};
// //   for (var slot in courts) {
// //     courtGroups.putIfAbsent(slot['court'], () => []).add(slot);
// //   }
// //
// //   return courtGroups.entries.map((entry) {
// //     final courtName = entry.key;
// //     final slots = entry.value;
// //
// //     // Group slots by hourType
// //     final hourGroups = <String, List<Map<String, dynamic>>>{};
// //     for (var slot in slots) {
// //       hourGroups.putIfAbsent(slot['hourType'], () => []).add(slot);
// //     }
// //
// //     return Card(
// //       margin: const EdgeInsets.only(bottom: 16),
// //       color: Colors.white,
// //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
// //       elevation: 4,
// //       child: Padding(
// //         padding: const EdgeInsets.all(16),
// //         child: Column(
// //           crossAxisAlignment: CrossAxisAlignment.start,
// //           children: [
// //             Text(courtName,
// //                 style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
// //             const SizedBox(height: 12),
// //             ...hourGroups.entries.map((hourEntry) {
// //               return Column(
// //                 crossAxisAlignment: CrossAxisAlignment.start,
// //                 children: [
// //                   Text(hourEntry.key,
// //                       style: const TextStyle(
// //                           fontSize: 16,
// //                           fontWeight: FontWeight.w600,
// //                           color: Colors.indigo)),
// //                   const SizedBox(height: 8),
// //                   Wrap(
// //                     spacing: 8,
// //                     runSpacing: 8,
// //                     children: hourEntry.value.map((slot) {
// //                       final isSelected = selectedSlots.any((s) =>
// //                       s['court'] == slot['court'] && s['time'] == slot['time']);
// //
// //                       // Determine if slot is weekend
// //                       final isWeekend = slot['dayType'].toLowerCase().contains('sat') ||
// //                           slot['dayType'].toLowerCase().contains('sun');
// //
// //                       return InkWell(
// //                         onTap: () => toggleSlot(slot),
// //                         child: Container(
// //                           padding: const EdgeInsets.symmetric(
// //                               horizontal: 12, vertical: 10),
// //                           decoration: BoxDecoration(
// //                             color: isSelected
// //                                 ? Colors.indigo.shade50
// //                                 : isWeekend
// //                                 ? Colors.orange.shade50
// //                                 : Colors.grey.shade100,
// //                             borderRadius: BorderRadius.circular(12),
// //                             border: Border.all(
// //                               color: isSelected
// //                                   ? Colors.indigo
// //                                   : isWeekend
// //                                   ? Colors.orange
// //                                   : Colors.grey.shade300,
// //                               width: 1.2,
// //                             ),
// //                           ),
// //                           child: Column(
// //                             mainAxisSize: MainAxisSize.min,
// //                             children: [
// //                               Text(slot['time'],
// //                                   style: TextStyle(
// //                                     fontSize: 14,
// //                                     fontWeight: FontWeight.w500,
// //                                     color: isWeekend
// //                                         ? Colors.orange.shade800
// //                                         : Colors.black,
// //                                   )),
// //                               const SizedBox(height: 4),
// //                               Text("₹${slot['price']}",
// //                                   style: const TextStyle(
// //                                       fontSize: 14, fontWeight: FontWeight.w600)),
// //                             ],
// //                           ),
// //                         ),
// //                       );
// //                     }).toList(),
// //                   ),
// //                   const SizedBox(height: 12),
// //                 ],
// //               );
// //             }).toList(),
// //           ],
// //         ),
// //       ),
// //     );
// //   }).toList();
// // }
//
//
//
//
// // Widget _buildCourtSelector() {
// //   final courtNames = courts.map((s) => s['court'].toString()).toSet().toList();
// //   return SizedBox(
// //     height: 100,
// //     child: ListView.builder(
// //       scrollDirection: Axis.vertical,
// //       padding: const EdgeInsets.symmetric(vertical: 12),
// //       itemCount: courtNames.length,
// //       itemBuilder: (context, index) {
// //         final court = courtNames[index];
// //         final isSelected = selectedCourt == court;
// //         return Padding(
// //           padding: const EdgeInsets.only(right: 8),
// //           child: ChoiceChip(
// //             label: Text(court),
// //             selected: isSelected,
// //             onSelected: (_) {
// //               setState(() {
// //                 selectedCourt = court;
// //                 selectedHourType = null;
// //               });
// //             },
// //             selectedColor: Colors.indigo.shade100,
// //             backgroundColor: Colors.grey.shade200,
// //             labelStyle: TextStyle(
// //                 color: isSelected ? Colors.indigo.shade900 : Colors.black),
// //           ),
// //         );
// //       },
// //     ),
// //   );
// // }
//
//
//
//
//
// //
// //
// // import 'package:flutter/material.dart';
// // import 'package:table_calendar/table_calendar.dart';
// // import 'package:intl/intl.dart';
// // import 'dart:convert';
// // import 'package:http/http.dart' as http;
// //
// // class SlotBookingScreen extends StatefulWidget {
// //   final String location;
// //   final String game;
// //
// //   const SlotBookingScreen({super.key, required this.location, required this.game});
// //
// //   @override
// //   State<SlotBookingScreen> createState() => _SlotBookingScreenState();
// // }
// //
// // class _SlotBookingScreenState extends State<SlotBookingScreen> {
// //   DateTime _selectedDay = DateTime.now();
// //   List<Map<String, dynamic>> selectedSlots = [];
// //   List<Map<String, dynamic>> courts = [];
// //   bool isLoading = false;
// //
// //   String? selectedCourt;
// //   String? selectedHourType;
// //
// //   @override
// //   void initState() {
// //     super.initState();
// //     fetchCourtsWisePrice();
// //   }
// //
// //   Future<void> fetchCourtsWisePrice() async {
// //     setState(() => isLoading = true);
// //     final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDay);
// //     final url = Uri.https("nahatasports.com", "/api/courts_wise_price", {
// //       "date": formattedDate,
// //       "sport_name": widget.game,
// //       "location": widget.location,
// //     });
// //
// //     try {
// //       final response = await http.get(url);
// //       if (response.statusCode == 200) {
// //         final data = json.decode(response.body)["data"] as Map<String, dynamic>;
// //         List<Map<String, dynamic>> parsedSlots = [];
// //
// //         data.forEach((courtName, courtData) {
// //           (courtData as Map<String, dynamic>).forEach((hourType, daysMap) {
// //             if (daysMap is Map<String, dynamic>) {
// //               daysMap.forEach((dayType, slotList) {
// //                 if (slotList is List) {
// //                   for (var slot in slotList) {
// //                     parsedSlots.add({
// //                       "court": courtName,
// //                       "hourType": hourType,
// //                       "dayType": dayType,
// //                       "time": slot["time"].toString(),
// //                       "price": int.tryParse(slot["price"].toString()) ?? 0,
// //                     });
// //                   }
// //                 }
// //               });
// //             }
// //           });
// //         });
// //
// //         setState(() {
// //           courts = parsedSlots;
// //           selectedSlots.clear();
// //           selectedCourt = null;
// //           selectedHourType = null;
// //         });
// //       }
// //     } catch (e) {
// //       print("Error fetching courts price: $e");
// //     }
// //     setState(() => isLoading = false);
// //   }
// //
// //   void toggleSlot(Map<String, dynamic> slot) {
// //     setState(() {
// //       final exists = selectedSlots.any(
// //               (s) => s['court'] == slot['court'] && s['time'] == slot['time']);
// //       if (exists) {
// //         selectedSlots.removeWhere(
// //                 (s) => s['court'] == slot['court'] && s['time'] == slot['time']);
// //       } else {
// //         selectedSlots.add(slot);
// //       }
// //     });
// //   }
// //
// //   List<String> getHourTypesForCourt(String court) {
// //     final courtSlots = courts.where((s) => s['court'] == court);
// //     return courtSlots.map((s) => s['hourType'].toString()).toSet().toList();
// //   }
// //
// //   List<Map<String, dynamic>> getSlotsForCourtAndHour(String court, String hourType) {
// //     return courts
// //         .where((s) => s['court'] == court && s['hourType'] == hourType)
// //         .toList();
// //   }
// //
// //   int get totalPrice => selectedSlots.fold(0, (sum, s) => sum + (s['price'] as int));
// //
// //   void goToReview() {
// //     if (selectedSlots.isEmpty) {
// //       ScaffoldMessenger.of(context).showSnackBar(
// //           const SnackBar(content: Text("Please select at least one slot")));
// //       return;
// //     }
// //
// //     Navigator.push(
// //         context,
// //         MaterialPageRoute(
// //             builder: (_) => ReviewScreen(
// //                 slots: List.from(selectedSlots),
// //                 location: widget.location,
// //                 game: widget.game,
// //                 date: _selectedDay)));
// //   }
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       backgroundColor: const Color(0xFFF2F4F7),
// //       appBar: AppBar(
// //         title: Text("${widget.game} - ${widget.location}"),
// //         backgroundColor: Colors.white,
// //         foregroundColor: Colors.black87,
// //         elevation: 1,
// //       ),
// //       body: isLoading
// //           ? const Center(child: CircularProgressIndicator())
// //           : SingleChildScrollView(
// //         child: Column(
// //           children: [
// //             // Calendar
// //             _buildCalendar(),
// //
// //             // Courts & slots
// //             Padding(
// //               padding: const EdgeInsets.symmetric(vertical: 8),
// //               child: Column(
// //                 children: courts
// //                     .map((court) => _buildCourtCard(court['court']))
// //                     .toSet()
// //                     .toList(),
// //               ),
// //             ),
// //             const SizedBox(height: 100), // space for bottom button
// //           ],
// //         ),
// //       ),
// //       bottomSheet: Container(
// //         padding: const EdgeInsets.all(12),
// //         color: Colors.white,
// //         child: Row(
// //           mainAxisAlignment: MainAxisAlignment.spaceBetween,
// //           children: [
// //             Text("Total: ₹$totalPrice",
// //                 style:
// //                 const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
// //             ElevatedButton(
// //               onPressed: goToReview,
// //               style: ElevatedButton.styleFrom(
// //                 padding:
// //                 const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
// //                 shape: RoundedRectangleBorder(
// //                     borderRadius: BorderRadius.circular(12)),
// //               ),
// //               child: const Text("Review & Proceed"),
// //             )
// //           ],
// //         ),
// //       ),
// //     );
// //   }
// //
// // // Single court card
// //   Widget _buildCourtCard(String court) {
// //     final hourTypes = getHourTypesForCourt(court);
// //     return Card(
// //       margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
// //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
// //       elevation: selectedCourt == court ? 4 : 1,
// //       child: Padding(
// //         padding: const EdgeInsets.all(12),
// //         child: Column(
// //           crossAxisAlignment: CrossAxisAlignment.start,
// //           children: [
// //             // Court name
// //             ListTile(
// //               title: Text(court,
// //                   style: TextStyle(
// //                       fontWeight: FontWeight.bold,
// //                       fontSize: 16,
// //                       color: selectedCourt == court ? Colors.blue : Colors.black87)),
// //               trailing: selectedCourt == court
// //                   ? const Icon(Icons.check_circle, color: Colors.blue)
// //                   : null,
// //               onTap: () {
// //                 setState(() {
// //                   selectedCourt = court;
// //                   selectedHourType = null;
// //                 });
// //               },
// //             ),
// //             const SizedBox(height: 8),
// //
// //             // Hour-type chips
// //             if (selectedCourt == court)
// //               Wrap(
// //                 spacing: 8,
// //                 children: hourTypes.map((hour) {
// //                   final isSelectedHour = selectedHourType == hour;
// //                   final isHappy = hour.toLowerCase().contains("happy");
// //                   return ChoiceChip(
// //                     label: Text(hour),
// //                     selected: isSelectedHour,
// //                     selectedColor: isHappy
// //                         ? Colors.orange.shade100
// //                         : Colors.blue.shade100,
// //                     backgroundColor: Colors.grey.shade200,
// //                     labelStyle: TextStyle(
// //                         color: isSelectedHour
// //                             ? (isHappy ? Colors.orange.shade800 : Colors.blue)
// //                             : Colors.black87),
// //                     onSelected: (_) {
// //                       setState(() => selectedHourType = hour);
// //                     },
// //                   );
// //                 }).toList(),
// //               ),
// //
// //             const SizedBox(height: 12),
// //
// //             // Slots grouped by day
// //             if (selectedCourt == court && selectedHourType != null)
// //               ..._buildSlotGroups(court, selectedHourType!)
// //           ],
// //         ),
// //       ),
// //     );
// //   }
// // // Slots grouped by day
// //   List<Widget> _buildSlotGroups(String court, String hourType) {
// //     final slots = getSlotsForCourtAndHour(court, hourType);
// //     final dayGroups = {
// //       "Mon-Fri": slots
// //           .where((s) =>
// //       !s['dayType'].toLowerCase().contains('sat') &&
// //           !s['dayType'].toLowerCase().contains('sun'))
// //           .toList(),
// //       "Sat": slots.where((s) => s['dayType'].toLowerCase().contains('sat')).toList(),
// //       "Sun": slots.where((s) => s['dayType'].toLowerCase().contains('sun')).toList(),
// //     };
// //
// //     return dayGroups.entries.map((entry) {
// //       if (entry.value.isEmpty) return const SizedBox.shrink();
// //       return Column(
// //         crossAxisAlignment: CrossAxisAlignment.start,
// //         children: [
// //           Padding(
// //             padding: const EdgeInsets.symmetric(vertical: 8),
// //             child: Text(entry.key,
// //                 style:
// //                 const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
// //           ),
// //           SingleChildScrollView(
// //             scrollDirection: Axis.horizontal,
// //             padding: const EdgeInsets.only(bottom: 12),
// //             child: Row(
// //               children: entry.value.map((slot) {
// //                 final isSelected = selectedSlots.any(
// //                         (s) => s['court'] == slot['court'] && s['time'] == slot['time']);
// //                 final isWeekend = entry.key != "Mon-Fri";
// //                 return Padding(
// //                   padding: const EdgeInsets.only(right: 8),
// //                   child: InkWell(
// //                     onTap: () => toggleSlot(slot),
// //                     child: Container(
// //                       padding:
// //                       const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
// //                       decoration: BoxDecoration(
// //                         color: isSelected
// //                             ? (isWeekend
// //                             ? Colors.orange.shade100
// //                             : Colors.blue.shade100)
// //                             : Colors.grey.shade50,
// //                         borderRadius: BorderRadius.circular(24),
// //                         border: Border.all(
// //                             color: isSelected
// //                                 ? (isWeekend ? Colors.orange : Colors.blue)
// //                                 : Colors.grey.shade300,
// //                             width: 1.2),
// //                       ),
// //                       child: Column(
// //                         mainAxisSize: MainAxisSize.min,
// //                         children: [
// //                           Text(slot['time'],
// //                               style: const TextStyle(fontSize: 14)),
// //                           const SizedBox(height: 4),
// //                           Text("₹${slot['price']}",
// //                               style: const TextStyle(fontWeight: FontWeight.bold)),
// //                         ],
// //                       ),
// //                     ),
// //                   ),
// //                 );
// //               }).toList(),
// //             ),
// //           ),
// //         ],
// //       );
// //     }).toList();
// //   }
// //
// //
// //
// //
// //
// //   Widget _buildCalendar() {
// //     return Card(
// //       margin: const EdgeInsets.all(12),
// //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
// //       child: TableCalendar(
// //         firstDay: DateTime.now(),
// //         lastDay: DateTime.now().add(const Duration(days: 30)),
// //         focusedDay: _selectedDay,
// //         selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
// //         onDaySelected: (selected, _) {
// //           setState(() => _selectedDay = selected);
// //           fetchCourtsWisePrice();
// //         },
// //         headerStyle:
// //         const HeaderStyle(formatButtonVisible: false, titleCentered: true),
// //       ),
// //     );
// //   }
// //
// //   Widget _buildCourtSelector() {
// //     final courtNames = courts.map((s) => s['court'].toString()).toSet().toList();
// //     return Column(
// //       children: courtNames.map((court) {
// //         final isSelected = selectedCourt == court;
// //         final hourTypes = getHourTypesForCourt(court);
// //         return Card(
// //           margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
// //           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
// //           elevation: isSelected ? 4 : 1,
// //           child: Padding(
// //             padding: const EdgeInsets.all(12),
// //             child: Column(
// //               crossAxisAlignment: CrossAxisAlignment.start,
// //               children: [
// //                 ListTile(
// //                   title: Text(court,
// //                       style: TextStyle(
// //                           fontWeight: FontWeight.bold,
// //                           fontSize: 16,
// //                           color: isSelected ? Colors.blue : Colors.black87)),
// //                   trailing: isSelected
// //                       ? const Icon(Icons.check_circle, color: Colors.blue)
// //                       : null,
// //                   onTap: () {
// //                     setState(() {
// //                       selectedCourt = court;
// //                       selectedHourType = null;
// //                     });
// //                   },
// //                 ),
// //                 if (isSelected)
// //                   Wrap(
// //                     spacing: 8,
// //                     children: hourTypes.map((hour) {
// //                       final isSelectedHour = selectedHourType == hour;
// //                       final isHappy = hour.toLowerCase().contains("happy");
// //                       return ChoiceChip(
// //                         label: Text(hour),
// //                         selected: isSelectedHour,
// //                         selectedColor: isHappy
// //                             ? Colors.orange.shade100
// //                             : Colors.blue.shade100,
// //                         backgroundColor: Colors.grey.shade200,
// //                         labelStyle: TextStyle(
// //                             color: isSelectedHour
// //                                 ? (isHappy ? Colors.orange.shade800 : Colors.blue)
// //                                 : Colors.black87),
// //                         onSelected: (_) {
// //                           setState(() => selectedHourType = hour);
// //                         },
// //                       );
// //                     }).toList(),
// //                   ),
// //               ],
// //             ),
// //           ),
// //         );
// //       }).toList(),
// //     );
// //   }
// //
// //   Widget _buildSlotSelector() {
// //     if (selectedHourType == null) return const SizedBox.shrink();
// //     final slots = getSlotsForCourtAndHour(selectedCourt!, selectedHourType!);
// //     final dayGroups = {
// //       "Mon-Fri": slots.where((s) => !s['dayType'].toLowerCase().contains('sat') && !s['dayType'].toLowerCase().contains('sun')).toList(),
// //       "Sat": slots.where((s) => s['dayType'].toLowerCase().contains('sat')).toList(),
// //       "Sun": slots.where((s) => s['dayType'].toLowerCase().contains('sun')).toList(),
// //     };
// //
// //     return Column(
// //       crossAxisAlignment: CrossAxisAlignment.start,
// //       children: dayGroups.entries.map((entry) {
// //         if (entry.value.isEmpty) return const SizedBox.shrink();
// //         return Column(
// //           crossAxisAlignment: CrossAxisAlignment.start,
// //           children: [
// //             Padding(
// //               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
// //               child: Text(entry.key,
// //                   style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
// //             ),
// //             SingleChildScrollView(
// //               scrollDirection: Axis.horizontal,
// //               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
// //               child: Row(
// //                 children: entry.value.map((slot) {
// //                   final isSelected = selectedSlots.any(
// //                           (s) => s['court'] == slot['court'] && s['time'] == slot['time']);
// //                   final isWeekend = entry.key != "Mon-Fri";
// //                   return Padding(
// //                     padding: const EdgeInsets.only(right: 8),
// //                     child: InkWell(
// //                       onTap: () => toggleSlot(slot),
// //                       child: Container(
// //                         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
// //                         decoration: BoxDecoration(
// //                           color: isSelected
// //                               ? (isWeekend ? Colors.orange.shade100 : Colors.blue.shade100)
// //                               : Colors.white,
// //                           borderRadius: BorderRadius.circular(24),
// //                           border: Border.all(
// //                               color: isSelected
// //                                   ? (isWeekend ? Colors.orange : Colors.blue)
// //                                   : Colors.grey.shade300,
// //                               width: 1.2),
// //                         ),
// //                         child: Column(
// //                           mainAxisSize: MainAxisSize.min,
// //                           children: [
// //                             Text(slot['time'], style: const TextStyle(fontSize: 14)),
// //                             const SizedBox(height: 4),
// //                             Text("₹${slot['price']}",
// //                                 style: const TextStyle(fontWeight: FontWeight.bold)),
// //                           ],
// //                         ),
// //                       ),
// //                     ),
// //                   );
// //                 }).toList(),
// //               ),
// //             ),
// //           ],
// //         );
// //       }).toList(),
// //     );
// //   }
// // }
// //
// // class ReviewScreen extends StatefulWidget {
// //   final List<Map<String, dynamic>> slots;
// //   final String location;
// //   final String game;
// //   final DateTime date;
// //
// //   const ReviewScreen(
// //       {super.key,
// //         required this.slots,
// //         required this.location,
// //         required this.game,
// //         required this.date});
// //
// //   @override
// //   State<ReviewScreen> createState() => _ReviewScreenState();
// // }
// //
// // class _ReviewScreenState extends State<ReviewScreen> {
// //   late List<Map<String, dynamic>> slots;
// //
// //   @override
// //   void initState() {
// //     super.initState();
// //     slots = List.from(widget.slots);
// //   }
// //
// //   int get totalPrice => slots.fold(0, (sum, s) => sum + (s['price'] as int));
// //
// //   void removeSlot(Map<String, dynamic> slot) {
// //     setState(() {
// //       slots.remove(slot);
// //     });
// //   }
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       appBar: AppBar(title: const Text("Review Selection")),
// //       body: ListView(
// //         padding: const EdgeInsets.all(12),
// //         children: [
// //           ...slots.map((slot) {
// //             return Card(
// //               margin: const EdgeInsets.symmetric(vertical: 6),
// //               child: ListTile(
// //                 title: Text("${slot['court']} - ${slot['time']}"),
// //                 subtitle: Text("${slot['hourType']} | ₹${slot['price']}"),
// //                 trailing: IconButton(
// //                     icon: const Icon(Icons.remove_circle, color: Colors.red),
// //                     onPressed: () => removeSlot(slot)),
// //               ),
// //             );
// //           }),
// //           const SizedBox(height: 20),
// //           Text("Total: ₹$totalPrice",
// //               style:
// //               const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
// //               textAlign: TextAlign.center),
// //           const SizedBox(height: 20),
// //           ElevatedButton(
// //               onPressed: slots.isEmpty ? null : () {},
// //               style: ElevatedButton.styleFrom(
// //                   padding: const EdgeInsets.symmetric(vertical: 14)),
// //               child: const Text("Proceed to Payment"))
// //         ],
// //       ),
// //     );
// //   }
// // }
// //
// //
// //
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
// //
// //
// //
// //
// // class SlotBookingScreen extends StatefulWidget {
// //   final String location;
// //   final String game;
// //
// //   const SlotBookingScreen({
// //     super.key,
// //     required this.location,
// //     required this.game,
// //   });
// //
// //   @override
// //   State<SlotBookingScreen> createState() => _SlotBookingScreenState();
// // }
// //
// // class _SlotBookingScreenState extends State<SlotBookingScreen> {
// //   DateTime _selectedDay = DateTime.now();
// //   List<Map<String, dynamic>> selectedSlots = [];
// //   int totalPrice = 0;
// //   List<Map<String, dynamic>> courts = [];
// //   bool isLoading = false;
// //
// //
// //   String? selectedCourt;
// //   String? selectedHourType;
// //
// //   @override
// //   void initState() {
// //     super.initState();
// //     fetchCourtsWisePrice();
// //   }
// //
// //   Future<void> fetchCourtsWisePrice() async {
// //     setState(() => isLoading = true);
// //     final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDay);
// //
// //     final url = Uri.https(
// //       "nahatasports.com",
// //       "/api/courts_wise_price",
// //       {
// //         "date": formattedDate,
// //         "sport_name": widget.game,
// //         "location": widget.location,
// //       },
// //     );
// //
// //     try {
// //       final response = await http.get(url);
// //       print("API URL: $url");
// //       print("Response: ${response.body}");
// //
// //       if (response.statusCode == 200) {
// //         final responseData = json.decode(response.body);
// //         if (responseData["status"] == "success") {
// //           final data = responseData["data"] as Map<String, dynamic>;
// //           List<Map<String, dynamic>> parsedSlots = [];
// //
// //           data.forEach((courtName, courtData) {
// //             final courtMap = courtData as Map<String, dynamic>;
// //             courtMap.forEach((hourType, daysMap) {
// //               if (daysMap is Map<String, dynamic>) {
// //                 daysMap.forEach((dayType, slotList) {
// //                   if (slotList is List) {
// //                     for (var slot in slotList) {
// //                       parsedSlots.add({
// //                         "court": courtName,
// //                         "hourType": hourType,
// //                         "dayType": dayType,
// //                         "time": slot["time"].toString(),
// //                         "price": int.tryParse(slot["price"].toString()) ?? 0,
// //                       });
// //                     }
// //                   }
// //                 });
// //               }
// //             });
// //           });
// //
// //           setState(() {
// //             courts = parsedSlots;
// //             selectedSlots.clear();
// //             totalPrice = 0;
// //           });
// //         }
// //       }
// //     } catch (e) {
// //       print("Error fetching courts price: $e");
// //     }
// //     setState(() => isLoading = false);
// //   }
// //
// //
// //   void proceedToPayment() {
// //     if (selectedSlots.isNotEmpty) {
// //       Navigator.pushNamed(
// //         context,
// //         '/payment',
// //         arguments: {
// //           'location': widget.location,
// //           'game': widget.game,
// //           'date': DateFormat('yyyy-MM-dd').format(_selectedDay),
// //           'slots': selectedSlots,
// //           'price': totalPrice,
// //         },
// //       );
// //     } else {
// //       ScaffoldMessenger.of(context)
// //           .showSnackBar(const SnackBar(content: Text("Please select at least one slot")));
// //     }
// //   }
// //
// //
// //
// //
// //
// //   void toggleSlot(Map<String, dynamic> slot) {
// //     setState(() {
// //       final exists = selectedSlots.any(
// //               (s) => s['court'] == slot['court'] && s['time'] == slot['time']);
// //       if (exists) {
// //         selectedSlots.removeWhere(
// //                 (s) => s['court'] == slot['court'] && s['time'] == slot['time']);
// //       } else {
// //         selectedSlots.add(slot);
// //       }
// //       totalPrice = selectedSlots.fold(0, (sum, s) => sum + (s['price'] as int));
// //     });
// //   }
// //
// //   List<String> getHourTypesForCourt(String court) {
// //     final courtSlots = courts.where((s) => s['court'] == court);
// //     return courtSlots.map((s) => s['hourType'].toString()).toSet().toList();
// //   }
// //
// //   List<Map<String, dynamic>> getSlotsForCourtAndHour(String court, String hourType) {
// //     return courts
// //         .where((s) => s['court'] == court && s['hourType'] == hourType)
// //         .toList();
// //   }
// //
// //
// //
// //
// //
// //
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       backgroundColor: const Color(0xFFF2F4F7),
// //       body: Container(
// //         decoration: const BoxDecoration(
// //           gradient: LinearGradient(
// //             colors: [Color(0xFF1D2B64), Color(0xFFf8cdda)],
// //             begin: Alignment.topCenter,
// //             end: Alignment.bottomCenter,
// //           ),
// //         ),
// //         child: SafeArea(
// //           child: isLoading
// //               ? const Center(child: CircularProgressIndicator(color: Colors.white))
// //               : SingleChildScrollView(
// //                 child: Column(
// //                             children: [
// //                 _buildCalendarCard(),
// //                 const SizedBox(height: 12),
// //                 _buildCourtSelector(),
// //                 if (selectedCourt != null) _buildHourTypeSelector(),
// //                 if (selectedCourt != null && selectedHourType != null)
// //                   _buildSlotSelector(),
// //                 if (selectedSlots.isNotEmpty) _buildReviewSummary(),
// //                 const SizedBox(height: 10),
// //                 _buildBottomBar(),
// //                             ],
// //                           ),
// //               ),
// //         ),
// //       ),
// //     );
// //   }
// //
// //
// //
// //
// //
// //
// //
// //
// //
// //
// //
// //
// //
// //
// //
// //
// //
// //
// //
// //
// //
// //
// //
// //
// //   Widget _buildCalendarCard() {
// //     return Card(
// //       color: Colors.white.withOpacity(0.9),
// //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
// //       elevation: 4,
// //       margin: const EdgeInsets.all(12),
// //       child: Padding(
// //         padding: const EdgeInsets.all(12),
// //         child: Column(
// //           children: [
// //             const Text("Select Date",
// //                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
// //             TableCalendar(
// //               firstDay: DateTime.now(),
// //               lastDay: DateTime.now().add(const Duration(days: 30)),
// //               focusedDay: _selectedDay,
// //               selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
// //               onDaySelected: (selected, _) {
// //                 setState(() => _selectedDay = selected);
// //                 fetchCourtsWisePrice();
// //               },
// //               headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
// //               calendarStyle: CalendarStyle(
// //                 todayDecoration: BoxDecoration(
// //                   color: Colors.indigo.shade100,
// //                   shape: BoxShape.circle,
// //                 ),
// //                 selectedDecoration: BoxDecoration(
// //                   color: Colors.indigo,
// //                   shape: BoxShape.circle,
// //                 ),
// //                 selectedTextStyle: const TextStyle(color: Colors.white),
// //               ),
// //             ),
// //           ],
// //         ),
// //       ),
// //     );
// //   }
// //
// //   Widget _buildCourtSelector() {
// //     final courtNames = courts.map((s) => s['court'].toString()).toSet().toList();
// //
// //     return ListView.builder(
// //       shrinkWrap: true, // allows it to work inside Column/ScrollView
// //       physics: const NeverScrollableScrollPhysics(), // optional, if inside outer scroll
// //       itemCount: courtNames.length,
// //       padding: const EdgeInsets.symmetric(vertical: 8),
// //       itemBuilder: (context, index) {
// //         final court = courtNames[index];
// //         final isSelected = selectedCourt == court;
// //
// //         return Card(
// //           margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
// //           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
// //           elevation: isSelected ? 4 : 1,
// //           child: ListTile(
// //             tileColor: isSelected ? Colors.indigo.shade50 : Colors.white,
// //             title: Text(
// //               court,
// //               style: TextStyle(
// //                   fontWeight: FontWeight.bold,
// //                   color: isSelected ? Colors.indigo.shade900 : Colors.black87),
// //             ),
// //             trailing: isSelected
// //                 ? const Icon(Icons.check_circle, color: Colors.indigo)
// //                 : null,
// //             onTap: () {
// //               setState(() {
// //                 selectedCourt = court;
// //                 selectedHourType = null;
// //               });
// //             },
// //           ),
// //         );
// //       },
// //     );
// //   }
// //
// //
// //   Widget _buildHourTypeSelector() {
// //     final hourTypes = getHourTypesForCourt(selectedCourt!);
// //     return SizedBox(
// //       height: 40,
// //       child: ListView.builder(
// //         scrollDirection: Axis.horizontal,
// //         padding: const EdgeInsets.symmetric(horizontal: 12),
// //         itemCount: hourTypes.length,
// //         itemBuilder: (context, index) {
// //           final hour = hourTypes[index];
// //           final isSelected = selectedHourType == hour;
// //           final isHappy = hour.toLowerCase().contains("happy");
// //           return Padding(
// //             padding: const EdgeInsets.only(right: 8),
// //             child: ChoiceChip(
// //               label: Text(hour),
// //               selected: isSelected,
// //               onSelected: (_) {
// //                 setState(() {
// //                   selectedHourType = hour;
// //                 });
// //               },
// //               selectedColor: isHappy ? Colors.orange.shade100 : Colors.indigo.shade100,
// //               backgroundColor: Colors.grey.shade200,
// //               labelStyle: TextStyle(
// //                   color: isSelected
// //                       ? (isHappy ? Colors.orange.shade800 : Colors.indigo.shade900)
// //                       : Colors.black),
// //             ),
// //           );
// //         },
// //       ),
// //     );
// //   }
// //
// //   Widget _buildSlotSelector() {
// //     final slots = getSlotsForCourtAndHour(selectedCourt!, selectedHourType!);
// //     if (slots.isEmpty) {
// //       return const Padding(
// //         padding: EdgeInsets.all(16),
// //         child: Text("No slots available", style: TextStyle(color: Colors.white)),
// //       );
// //     }
// //     return SizedBox(
// //       height: 70,
// //       child: ListView.builder(
// //         scrollDirection: Axis.horizontal,
// //         padding: const EdgeInsets.symmetric(horizontal: 12),
// //         itemCount: slots.length,
// //         itemBuilder: (context, index) {
// //           final slot = slots[index];
// //           final isSelected = selectedSlots.any(
// //                   (s) => s['court'] == slot['court'] && s['time'] == slot['time']);
// //           final isWeekend = slot['dayType'].toLowerCase().contains('sat') ||
// //               slot['dayType'].toLowerCase().contains('sun');
// //           return Padding(
// //             padding: const EdgeInsets.only(right: 8),
// //             child: InkWell(
// //               onTap: () => toggleSlot(slot),
// //               child: Container(
// //                 padding:
// //                 const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
// //                 decoration: BoxDecoration(
// //                   color: isSelected
// //                       ? Colors.indigo.shade50
// //                       : isWeekend
// //                       ? Colors.orange.shade50
// //                       : Colors.white,
// //                   borderRadius: BorderRadius.circular(12),
// //                   border: Border.all(
// //                     color: isSelected
// //                         ? Colors.indigo
// //                         : isWeekend
// //                         ? Colors.orange
// //                         : Colors.grey.shade300,
// //                     width: 1.2,
// //                   ),
// //                 ),
// //                 child: Column(
// //                   mainAxisSize: MainAxisSize.min,
// //                   children: [
// //                     Text(slot['time'],
// //                         style: TextStyle(
// //                           fontSize: 14,
// //                           fontWeight: FontWeight.w500,
// //                           color: isWeekend ? Colors.orange.shade800 : Colors.black,
// //                         )),
// //                     const SizedBox(height: 4),
// //                     Text("₹${slot['price']}",
// //                         style: const TextStyle(
// //                             fontSize: 14, fontWeight: FontWeight.w600)),
// //                   ],
// //                 ),
// //               ),
// //             ),
// //           );
// //         },
// //       ),
// //     );
// //   }
// //
// //   // Add this method inside your _SlotBookingScreenState class
// //   Widget _buildReviewSummary() {
// //     if (selectedSlots.isEmpty) return const SizedBox.shrink();
// //
// //     // Group slots by court and hour type
// //     final grouped = <String, Map<String, List<String>>>{};
// //     for (var slot in selectedSlots) {
// //       final court = slot['court'];
// //       final hour = slot['hourType'];
// //       final time = slot['time'];
// //
// //       grouped.putIfAbsent(court, () => {});
// //       grouped[court]!.putIfAbsent(hour, () => []);
// //       grouped[court]![hour]!.add(time);
// //     }
// //
// //     return Card(
// //       margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
// //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
// //       color: Colors.white.withOpacity(0.9),
// //       elevation: 4,
// //       child: Padding(
// //         padding: const EdgeInsets.all(12),
// //         child: Column(
// //           crossAxisAlignment: CrossAxisAlignment.start,
// //           children: [
// //             const Text("Review Selection",
// //                 style: TextStyle(
// //                     fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
// //             const SizedBox(height: 8),
// //             ...grouped.entries.map((courtEntry) {
// //               final court = courtEntry.key;
// //               return Column(
// //                 crossAxisAlignment: CrossAxisAlignment.start,
// //                 children: [
// //                   Text(court,
// //                       style: const TextStyle(
// //                           fontSize: 14, fontWeight: FontWeight.w600)),
// //                   const SizedBox(height: 4),
// //                   ...courtEntry.value.entries.map((hourEntry) {
// //                     final hour = hourEntry.key;
// //                     final times = hourEntry.value.join(", ");
// //                     return Padding(
// //                       padding: const EdgeInsets.only(left: 12, bottom: 4),
// //                       child: Text(
// //                         "$hour: $times",
// //                         style: const TextStyle(fontSize: 14),
// //                       ),
// //                     );
// //                   })
// //                 ],
// //               );
// //             }).toList(),
// //             const Divider(height: 12, color: Colors.black26),
// //             Text("Total: ₹$totalPrice",
// //                 style: const TextStyle(
// //                     fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
// //           ],
// //         ),
// //       ),
// //     );
// //   }
// //
// //
// //
// //
// //
// //
// //
// //
// //
// //
// //
// //
// //
// //   Widget _buildBottomBar() {
// //     return Container(
// //       padding: const EdgeInsets.all(12),
// //       color: Colors.white.withOpacity(0.1),
// //       child: Row(
// //         mainAxisAlignment: MainAxisAlignment.spaceBetween,
// //         children: [
// //           Text("Total: ₹$totalPrice",
// //               style: const TextStyle(
// //                   fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
// //           ElevatedButton(
// //             style: ElevatedButton.styleFrom(
// //               backgroundColor: const Color(0xFF0A198D),
// //               padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
// //               shape: RoundedRectangleBorder(
// //                   borderRadius: BorderRadius.circular(12)),
// //             ),
// //             onPressed: selectedSlots.isEmpty
// //                 ? null
// //                 : () {
// //               Navigator.pushNamed(
// //                 context,
// //                 '/payment',
// //                 arguments: {
// //                   'location': widget.location,
// //                   'game': widget.game,
// //                   'date': DateFormat('yyyy-MM-dd').format(_selectedDay),
// //                   'slots': selectedSlots,
// //                   'price': totalPrice,
// //                 },
// //               );
// //             },
// //             child: const Text("Proceed to Payment",
// //                 style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
// //           )
// //         ],
// //       ),
// //     );
// //   }
// // }
// //
// //
// //
// //
// //
// //
// //
// //
// //
// //
// //
// //
// //
// //
// //
// //
// //
// //
// //
// //
// //
// //
// //
// //
// //
// //
// //
// //
// //
// //
// //
// //
// //
// //
// //
// //
// //
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
// class SlotBookingScreen extends StatefulWidget {
//   final String location;
//   final String game;
//
//   const SlotBookingScreen({
//     super.key,
//     required this.location,
//     required this.game,
//   });
//
//   @override
//   State<SlotBookingScreen> createState() => _SlotBookingScreenState();
// }
//
// class _SlotBookingScreenState extends State<SlotBookingScreen> {
//   DateTime _selectedDay = DateTime.now();
//
//   List<Map<String, dynamic>> selectedSlots = [];
//   int totalPrice = 0;
//   List courts = [];
//   bool isLoading = false;
//
//   /// ✅ Fetch new API
//   // Future<void> fetchCourtsWisePrice() async {
//   //   setState(() => isLoading = true);
//   //   final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDay);
//   //   final url = Uri.parse(
//   //       "https://nahatasports.com/api/courts_wise_price?date=$formattedDate&sport_name=${widget.game}&location=${widget.location}");
//   //
//   //   try {
//   //     final response = await http.get(url);
//   //     if (response.statusCode == 200) {
//   //       final responseData = json.decode(response.body);
//   //       if (responseData["status"] == true) {
//   //         setState(() {
//   //           courts = responseData["data"];
//   //           selectedSlots.clear();
//   //           totalPrice = 0;
//   //         });
//   //       }
//   //     }
//   //   } catch (e) {
//   //     print("Error fetching courts price: $e");
//   //   }
//   //   setState(() => isLoading = false);
//   // }
//
//
//
//
//   Future<void> fetchCourtsWisePrice() async {
//     setState(() => isLoading = true);
//     final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDay);
//
//     final url = Uri.https(
//       "nahatasports.com",
//       "/api/courts_wise_price",
//       {
//         "date": formattedDate,
//         "sport_name": widget.game,
//         "location": widget.location,
//       },
//     );
//
//     try {
//       final response = await http.get(url);
//       print("API URL: $url");
//       print("Response: ${response.body}");
//
//       if (response.statusCode == 200) {
//         final responseData = json.decode(response.body);
//
//         if (responseData["status"] == "success") {
//           final data = responseData["data"] as Map<String, dynamic>;
//           List<Map<String, dynamic>> parsedSlots = [];
//
//           data.forEach((courtName, courtData) {
//             final courtMap = courtData as Map<String, dynamic>;
//             courtMap.forEach((hourType, daysMap) {
//               if (daysMap is Map<String, dynamic>) {
//                 daysMap.forEach((dayType, slotList) {
//                   if (slotList is List) {
//                     for (var slot in slotList) {
//                       parsedSlots.add({
//                         "court": courtName.toString(),
//                         "hourType": hourType.toString(),
//                         "dayType": dayType.toString(),
//                         "time": slot["time"].toString(),
//                         "price": int.tryParse(slot["price"].toString()) ?? 0,
//                       });
//                     }
//                   }
//                 });
//               }
//             });
//           });
//
//           setState(() {
//             courts = parsedSlots;
//             selectedSlots.clear();
//             totalPrice = 0;
//           });
//
//           print("Parsed courts: $courts");
//         }
//       }
//     } catch (e) {
//       print("Error fetching courts price: $e");
//     }
//
//     setState(() => isLoading = false);
//   }
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
//   void toggleSlot(Map<String, dynamic> slot) {
//     setState(() {
//       final exists = selectedSlots.any((s) =>
//       s['court'] == slot['court'] && s['time'] == slot['time']);
//       if (exists) {
//         selectedSlots.removeWhere(
//                 (s) => s['court'] == slot['court'] && s['time'] == slot['time']);
//       } else {
//         selectedSlots.add(slot);
//       }
//       totalPrice = selectedSlots.fold(
//           0, (sum, s) => sum + (s['price'] as int));
//     });
//   }
//
//   void proceedToPayment() {
//     if (selectedSlots.isNotEmpty) {
//       Navigator.pushNamed(
//         context,
//         '/payment',
//         arguments: {
//           'location': widget.location,
//           'game': widget.game,
//           'date': DateFormat('yyyy-MM-dd').format(_selectedDay),
//           'slots': selectedSlots,
//           'price': totalPrice,
//         },
//       );
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("Please select at least one slot")),
//       );
//     }
//   }
//
//   @override
//   void initState() {
//     super.initState();
//     fetchCourtsWisePrice();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFF2F4F7),
//       body: Container(
//         decoration: const BoxDecoration(
//           gradient: LinearGradient(
//             colors: [Color(0xFF1D2B64), Color(0xFFf8cdda)],
//             begin: Alignment.topCenter,
//             end: Alignment.bottomCenter,
//           ),
//         ),
//         child: SafeArea(
//           child: isLoading
//               ? const Center(child: CircularProgressIndicator(color: Colors.white))
//               : SingleChildScrollView(
//             padding: const EdgeInsets.all(16),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   '${widget.game} at ${widget.location}',
//                   style: const TextStyle(
//                     fontSize: 24,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.white,
//                   ),
//                 ),
//                 const SizedBox(height: 20),
//                 _buildCalendarCard(),
//                 const SizedBox(height: 20),
//                 ...courts.map((slot) => _buildSlotTile(slot as Map<String, dynamic>)).toList(),
//                 const SizedBox(height: 20),
//                 Text("Total: ₹$totalPrice",
//                     style: const TextStyle(
//                         fontSize: 18,
//                         fontWeight: FontWeight.bold,
//                         color: Colors.white)),
//                 const SizedBox(height: 30),
//                 SizedBox(
//                   width: double.infinity,
//                   child: ElevatedButton(
//                     style: ElevatedButton.styleFrom(
//                       padding: const EdgeInsets.symmetric(vertical: 16),
//                       backgroundColor: const Color(0xFF0A198D),
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                     ),
//                     onPressed: proceedToPayment,
//                     child: const Text("Proceed to Payment",
//                         style: TextStyle(
//                             fontSize: 16,
//                             fontWeight: FontWeight.w500,
//                             color: Colors.white)),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildCalendarCard() {
//     return Card(
//       color: Colors.white.withOpacity(0.9),
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       elevation: 4,
//       child: Padding(
//         padding: const EdgeInsets.all(12),
//         child: Column(
//           children: [
//             const Text("Select Date",
//                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
//             TableCalendar(
//               firstDay: DateTime.now(),
//               lastDay: DateTime.now().add(const Duration(days: 30)),
//               focusedDay: _selectedDay,
//               selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
//               onDaySelected: (selected, _) {
//                 setState(() => _selectedDay = selected);
//                 fetchCourtsWisePrice();
//               },
//               headerStyle:
//               const HeaderStyle(formatButtonVisible: false, titleCentered: true),
//               calendarStyle: CalendarStyle(
//                 todayDecoration: BoxDecoration(
//                   color: Colors.indigo.shade100,
//                   shape: BoxShape.circle,
//                 ),
//                 selectedDecoration: BoxDecoration(
//                   color: Colors.indigo,
//                   shape: BoxShape.circle,
//                 ),
//                 selectedTextStyle: const TextStyle(color: Colors.white),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildCourtCard(Map court) {
//     return Card(
//       margin: const EdgeInsets.only(bottom: 16),
//       color: Colors.white,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       elevation: 4,
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(court['court_name'] ?? "",
//                 style: const TextStyle(
//                     fontSize: 18, fontWeight: FontWeight.bold)),
//             const SizedBox(height: 12),
//             if (court['slots'] != null)
//               Column(
//                 children: (court['slots'] as List).map<Widget>((slot) {
//                   final slotMap = {
//                     "court": court['court_name'],
//                     "time": slot['time'],
//                     "price": int.tryParse(slot['price'].toString()) ?? 0,
//                     "hourType": slot['hour_type'],
//                   };
//                   final isSelected = selectedSlots.any((s) =>
//                   s['court'] == slotMap['court'] &&
//                       s['time'] == slotMap['time']);
//                   return InkWell(
//                     onTap: () => toggleSlot(slotMap),
//                     child: Container(
//                       margin: const EdgeInsets.symmetric(vertical: 6),
//                       padding: const EdgeInsets.symmetric(
//                           horizontal: 16, vertical: 14),
//                       decoration: BoxDecoration(
//                         color: isSelected
//                             ? Colors.indigo.shade50
//                             : Colors.grey.shade100,
//                         borderRadius: BorderRadius.circular(12),
//                         border: Border.all(
//                           color: isSelected ? Colors.indigo : Colors.grey.shade300,
//                           width: 1.2,
//                         ),
//                       ),
//                       child: Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           Text("${slot['time']} (${slot['hour_type']})",
//                               style: const TextStyle(fontSize: 15)),
//                           Row(
//                             children: [
//                               Text("₹${slot['price']}",
//                                   style: const TextStyle(
//                                       fontWeight: FontWeight.w600)),
//                               const SizedBox(width: 10),
//                               if (isSelected)
//                                 const Icon(Icons.check_circle,
//                                     color: Colors.indigo, size: 20),
//                             ],
//                           )
//                         ],
//                       ),
//                     ),
//                   );
//                 }).toList(),
//               )
//           ],
//         ),
//       ),
//     );
//   }
//
//
//
//
//
//
//
//   Widget _buildSlotTile(Map slot) {
//     // ✅ Cast the slot to Map<String, dynamic>
//     final Map<String, dynamic> slotMap = Map<String, dynamic>.from(slot);
//
//     final isSelected = selectedSlots.any(
//           (s) => s['court'] == slotMap['court'] && s['time'] == slotMap['time'],
//     );
//
//     return InkWell(
//       onTap: () => toggleSlot(slotMap),
//       child: Container(
//         margin: const EdgeInsets.symmetric(vertical: 6),
//         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
//         decoration: BoxDecoration(
//           color: isSelected ? Colors.indigo.shade50 : Colors.white,
//           borderRadius: BorderRadius.circular(12),
//           border: Border.all(
//             color: isSelected ? Colors.indigo : Colors.grey.shade300,
//             width: 1.2,
//           ),
//         ),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             Expanded(
//               child: Text(
//                 "${slotMap['court']} • ${slotMap['hourType']} (${slotMap['dayType']})\n${slotMap['time']}",
//                 style: const TextStyle(fontSize: 14),
//               ),
//             ),
//             Row(
//               children: [
//                 Text(
//                   "₹${slotMap['price']}",
//                   style: const TextStyle(fontWeight: FontWeight.w600),
//                 ),
//                 const SizedBox(width: 10),
//                 if (isSelected)
//                   const Icon(Icons.check_circle, color: Colors.indigo, size: 20),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//
//
//
//
//
// }



















































































//
//
// import 'dart:convert';
//
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:intl/intl.dart';
// import 'package:table_calendar/table_calendar.dart';
//
// class SlotBookingScreen extends StatefulWidget {
//   final String location;
//   final String game;
//
//   const SlotBookingScreen({
//     super.key,
//     required this.location,
//     required this.game,
//   });
//
//   @override
//   State<SlotBookingScreen> createState() => _SlotBookingScreenState();
// }
//
// class _SlotBookingScreenState extends State<SlotBookingScreen> {
//   DateTime _selectedDay = DateTime.now();
//   List<Map<String, dynamic>> selectedSlots = [];
//   int totalPrice = 0;
//   List<Map<String, dynamic>> courts = [];
//   bool isLoading = false;
//
//
//   String? selectedCourt;
//   String? selectedHourType;
//
//   @override
//   void initState() {
//     super.initState();
//     fetchCourtsWisePrice();
//   }
//
//   Future<void> fetchCourtsWisePrice() async {
//     setState(() => isLoading = true);
//     final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDay);
//
//     final url = Uri.https(
//       "nahatasports.com",
//       "/api/courts_wise_price",
//       {
//         "date": formattedDate,
//         "sport_name": widget.game,
//         "location": widget.location,
//       },
//     );
//
//     try {
//       final response = await http.get(url);
//       print("API URL: $url");
//       print("Response: ${response.body}");
//
//       if (response.statusCode == 200) {
//         final responseData = json.decode(response.body);
//         if (responseData["status"] == "success") {
//           final data = responseData["data"] as Map<String, dynamic>;
//           List<Map<String, dynamic>> parsedSlots = [];
//
//           data.forEach((courtName, courtData) {
//             final courtMap = courtData as Map<String, dynamic>;
//             courtMap.forEach((hourType, daysMap) {
//               if (daysMap is Map<String, dynamic>) {
//                 daysMap.forEach((dayType, slotList) {
//                   if (slotList is List) {
//                     for (var slot in slotList) {
//                       parsedSlots.add({
//                         "court": courtName,
//                         "hourType": hourType,
//                         "dayType": dayType,
//                         "time": slot["time"].toString(),
//                         "price": int.tryParse(slot["price"].toString()) ?? 0,
//                       });
//                     }
//                   }
//                 });
//               }
//             });
//           });
//
//           setState(() {
//             courts = parsedSlots;
//             selectedSlots.clear();
//             totalPrice = 0;
//           });
//         }
//       }
//     } catch (e) {
//       print("Error fetching courts price: $e");
//     }
//     setState(() => isLoading = false);
//   }
//
//
//   void proceedToPayment() {
//     if (selectedSlots.isNotEmpty) {
//       Navigator.pushNamed(
//         context,
//         '/payment',
//         arguments: {
//           'location': widget.location,
//           'game': widget.game,
//           'date': DateFormat('yyyy-MM-dd').format(_selectedDay),
//           'slots': selectedSlots,
//           'price': totalPrice,
//         },
//       );
//     } else {
//       ScaffoldMessenger.of(context)
//           .showSnackBar(const SnackBar(content: Text("Please select at least one slot")));
//     }
//   }
//
//
//
//
//
//   void toggleSlot(Map<String, dynamic> slot) {
//     setState(() {
//       final exists = selectedSlots.any(
//               (s) => s['court'] == slot['court'] && s['time'] == slot['time']);
//       if (exists) {
//         selectedSlots.removeWhere(
//                 (s) => s['court'] == slot['court'] && s['time'] == slot['time']);
//       } else {
//         selectedSlots.add(slot);
//       }
//       totalPrice = selectedSlots.fold(0, (sum, s) => sum + (s['price'] as int));
//     });
//   }
//
//   List<String> getHourTypesForCourt(String court) {
//     final courtSlots = courts.where((s) => s['court'] == court);
//     return courtSlots.map((s) => s['hourType'].toString()).toSet().toList();
//   }
//
//   List<Map<String, dynamic>> getSlotsForCourtAndHour(String court, String hourType) {
//     return courts
//         .where((s) => s['court'] == court && s['hourType'] == hourType)
//         .toList();
//   }
//
//
//
//
//
//
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFF2F4F7),
//       body: Container(
//         decoration: const BoxDecoration(
//           gradient: LinearGradient(
//             colors: [Color(0xFF1D2B64), Color(0xFFf8cdda)],
//             begin: Alignment.topCenter,
//             end: Alignment.bottomCenter,
//           ),
//         ),
//         child: SafeArea(
//           child: isLoading
//               ? const Center(child: CircularProgressIndicator(color: Colors.white))
//               : SingleChildScrollView(
//             child: Column(
//               children: [
//                 _buildCalendarCard(),
//                 const SizedBox(height: 12),
//                 _buildCourtCards(),
//                 // const SizedBox(height: 12),
//
//                 // _buildCourtSelector(),
//                 // if (selectedCourt != null) _buildHourTypeSelector(),
//                 // if (selectedCourt != null && selectedHourType != null)
//                 //   _buildSlotSelector(),
//                 if (selectedSlots.isNotEmpty) _buildReviewSummary(),
//                 const SizedBox(height: 10),
//                 _buildBottomBar(),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//
//
//
//
//
//
//
//   Widget _buildCourtCards() {
//     final courtNames = courts.map((s) => s['court'].toString()).toSet().toList();
//
//     return ListView.builder(
//       shrinkWrap: true,
//       physics: const NeverScrollableScrollPhysics(),
//       itemCount: courtNames.length,
//       padding: const EdgeInsets.all(12),
//       itemBuilder: (context, index) {
//         final court = courtNames[index];
//         final hourTypes = getHourTypesForCourt(court);
//
//         return Card(
//           margin: const EdgeInsets.only(bottom: 12),
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//           color: Colors.white.withOpacity(0.95),
//           elevation: 3,
//           child: Padding(
//             padding: const EdgeInsets.all(12),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   court,
//                   style: const TextStyle(
//                     fontSize: 16,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.black87,
//                   ),
//                 ),
//                 const SizedBox(height: 8),
//
//                 // Hour types inside this court
//                 ...hourTypes.map((hourType) {
//                   final slots = getSlotsForCourtAndHour(court, hourType);
//                   final isHappy = hourType.toLowerCase().contains("happy");
//
//                   return Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         hourType,
//                         style: TextStyle(
//                           fontSize: 14,
//                           fontWeight: FontWeight.w600,
//                           color: isHappy ? Colors.orange.shade800 : Colors.indigo.shade800,
//                         ),
//                       ),
//                       const SizedBox(height: 6),
//
//                       // Slots row
//                       Wrap(
//                         spacing: 8,
//                         runSpacing: 8,
//                         children: slots.map((slot) {
//                           final isSelected = selectedSlots.any(
//                                 (s) => s['court'] == slot['court'] && s['time'] == slot['time'],
//                           );
//                           final isWeekend = slot['dayType']
//                               .toString()
//                               .toLowerCase()
//                               .contains("sat") ||
//                               slot['dayType']
//                                   .toString()
//                                   .toLowerCase()
//                                   .contains("sun");
//
//                           return GestureDetector(
//                             onTap: () => toggleSlot(slot),
//                             child: Container(
//                               padding: const EdgeInsets.symmetric(
//                                   horizontal: 12, vertical: 8),
//                               decoration: BoxDecoration(
//                                 color: isSelected
//                                     ? Colors.indigo.shade50
//                                     : isWeekend
//                                     ? Colors.orange.shade50
//                                     : Colors.white,
//                                 borderRadius: BorderRadius.circular(10),
//                                 border: Border.all(
//                                   color: isSelected
//                                       ? Colors.indigo
//                                       : isWeekend
//                                       ? Colors.orange
//                                       : Colors.grey.shade300,
//                                   width: 1.2,
//                                 ),
//                               ),
//                               child: Column(
//                                 mainAxisSize: MainAxisSize.min,
//                                 children: [
//                                   Text(
//                                     slot['time'],
//                                     style: TextStyle(
//                                       fontSize: 13,
//                                       fontWeight: FontWeight.w500,
//                                       color: isWeekend
//                                           ? Colors.orange.shade800
//                                           : Colors.black,
//                                     ),
//                                   ),
//                                   const SizedBox(height: 2),
//                                   Text(
//                                     "₹${slot['price']}",
//                                     style: const TextStyle(
//                                       fontSize: 13,
//                                       fontWeight: FontWeight.w600,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           );
//                         }).toList(),
//                       ),
//                       const SizedBox(height: 12),
//                     ],
//                   );
//                 }).toList(),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }
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
//   Widget _buildCalendarCard() {
//     return Card(
//       color: Colors.white.withOpacity(0.9),
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       elevation: 4,
//       margin: const EdgeInsets.all(12),
//       child: Padding(
//         padding: const EdgeInsets.all(12),
//         child: Column(
//           children: [
//             const Text("Select Date",
//                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
//             TableCalendar(
//               firstDay: DateTime.now(),
//               lastDay: DateTime.now().add(const Duration(days: 30)),
//               focusedDay: _selectedDay,
//               selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
//               onDaySelected: (selected, _) {
//                 setState(() => _selectedDay = selected);
//                 fetchCourtsWisePrice();
//               },
//               headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
//               calendarStyle: CalendarStyle(
//                 todayDecoration: BoxDecoration(
//                   color: Colors.indigo.shade100,
//                   shape: BoxShape.circle,
//                 ),
//                 selectedDecoration: BoxDecoration(
//                   color: Colors.indigo,
//                   shape: BoxShape.circle,
//                 ),
//                 selectedTextStyle: const TextStyle(color: Colors.white),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildCourtSelector() {
//     final courtNames = courts.map((s) => s['court'].toString()).toSet().toList();
//
//     return ListView.builder(
//       shrinkWrap: true, // allows it to work inside Column/ScrollView
//       physics: const NeverScrollableScrollPhysics(), // optional, if inside outer scroll
//       itemCount: courtNames.length,
//       padding: const EdgeInsets.symmetric(vertical: 8),
//       itemBuilder: (context, index) {
//         final court = courtNames[index];
//         final isSelected = selectedCourt == court;
//
//         return Card(
//           margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//           elevation: isSelected ? 4 : 1,
//           child: ListTile(
//             tileColor: isSelected ? Colors.indigo.shade50 : Colors.white,
//             title: Text(
//               court,
//               style: TextStyle(
//                   fontWeight: FontWeight.bold,
//                   color: isSelected ? Colors.indigo.shade900 : Colors.black87),
//             ),
//             trailing: isSelected
//                 ? const Icon(Icons.check_circle, color: Colors.indigo)
//                 : null,
//             onTap: () {
//               setState(() {
//                 selectedCourt = court;
//                 selectedHourType = null;
//               });
//             },
//           ),
//         );
//       },
//     );
//   }
//
//
//   Widget _buildHourTypeSelector() {
//     final hourTypes = getHourTypesForCourt(selectedCourt!);
//     return SizedBox(
//       height: 40,
//       child: ListView.builder(
//         scrollDirection: Axis.horizontal,
//         padding: const EdgeInsets.symmetric(horizontal: 12),
//         itemCount: hourTypes.length,
//         itemBuilder: (context, index) {
//           final hour = hourTypes[index];
//           final isSelected = selectedHourType == hour;
//           final isHappy = hour.toLowerCase().contains("happy");
//           return Padding(
//             padding: const EdgeInsets.only(right: 8),
//             child: ChoiceChip(
//               label: Text(hour),
//               selected: isSelected,
//               onSelected: (_) {
//                 setState(() {
//                   selectedHourType = hour;
//                 });
//               },
//               selectedColor: isHappy ? Colors.orange.shade100 : Colors.indigo.shade100,
//               backgroundColor: Colors.grey.shade200,
//               labelStyle: TextStyle(
//                   color: isSelected
//                       ? (isHappy ? Colors.orange.shade800 : Colors.indigo.shade900)
//                       : Colors.black),
//             ),
//           );
//         },
//       ),
//     );
//   }
//
//   Widget _buildSlotSelector() {
//     final slots = getSlotsForCourtAndHour(selectedCourt!, selectedHourType!);
//     if (slots.isEmpty) {
//       return const Padding(
//         padding: EdgeInsets.all(16),
//         child: Text("No slots available", style: TextStyle(color: Colors.white)),
//       );
//     }
//     return SizedBox(
//       height: 70,
//       child: ListView.builder(
//         scrollDirection: Axis.horizontal,
//         padding: const EdgeInsets.symmetric(horizontal: 12),
//         itemCount: slots.length,
//         itemBuilder: (context, index) {
//           final slot = slots[index];
//           final isSelected = selectedSlots.any(
//                   (s) => s['court'] == slot['court'] && s['time'] == slot['time']);
//           final isWeekend = slot['dayType'].toLowerCase().contains('sat') ||
//               slot['dayType'].toLowerCase().contains('sun');
//           return Padding(
//             padding: const EdgeInsets.only(right: 8),
//             child: InkWell(
//               onTap: () => toggleSlot(slot),
//               child: Container(
//                 padding:
//                 const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//                 decoration: BoxDecoration(
//                   color: isSelected
//                       ? Colors.indigo.shade50
//                       : isWeekend
//                       ? Colors.orange.shade50
//                       : Colors.white,
//                   borderRadius: BorderRadius.circular(12),
//                   border: Border.all(
//                     color: isSelected
//                         ? Colors.indigo
//                         : isWeekend
//                         ? Colors.orange
//                         : Colors.grey.shade300,
//                     width: 1.2,
//                   ),
//                 ),
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     Text(slot['time'],
//                         style: TextStyle(
//                           fontSize: 14,
//                           fontWeight: FontWeight.w500,
//                           color: isWeekend ? Colors.orange.shade800 : Colors.black,
//                         )),
//                     const SizedBox(height: 4),
//                     Text("₹${slot['price']}",
//                         style: const TextStyle(
//                             fontSize: 14, fontWeight: FontWeight.w600)),
//                   ],
//                 ),
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }
//
//   // Add this method inside your _SlotBookingScreenState class
//   Widget _buildReviewSummary() {
//     if (selectedSlots.isEmpty) return const SizedBox.shrink();
//
//     // Group slots by court and hour type
//     final grouped = <String, Map<String, List<String>>>{};
//     for (var slot in selectedSlots) {
//       final court = slot['court'];
//       final hour = slot['hourType'];
//       final time = slot['time'];
//
//       grouped.putIfAbsent(court, () => {});
//       grouped[court]!.putIfAbsent(hour, () => []);
//       grouped[court]![hour]!.add(time);
//     }
//
//     return Card(
//       margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       color: Colors.white.withOpacity(0.9),
//       elevation: 4,
//       child: Padding(
//         padding: const EdgeInsets.all(12),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text("Review Selection",
//                 style: TextStyle(
//                     fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
//             const SizedBox(height: 8),
//             ...grouped.entries.map((courtEntry) {
//               final court = courtEntry.key;
//               return Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(court,
//                       style: const TextStyle(
//                           fontSize: 14, fontWeight: FontWeight.w600)),
//                   const SizedBox(height: 4),
//                   ...courtEntry.value.entries.map((hourEntry) {
//                     final hour = hourEntry.key;
//                     final times = hourEntry.value.join(", ");
//                     return Padding(
//                       padding: const EdgeInsets.only(left: 12, bottom: 4),
//                       child: Text(
//                         "$hour: $times",
//                         style: const TextStyle(fontSize: 14),
//                       ),
//                     );
//                   })
//                 ],
//               );
//             }).toList(),
//             const Divider(height: 12, color: Colors.black26),
//             Text("Total: ₹$totalPrice",
//                 style: const TextStyle(
//                     fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
//           ],
//         ),
//       ),
//     );
//   }
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
//   Widget _buildBottomBar() {
//     return Container(
//       padding: const EdgeInsets.all(12),
//       color: Colors.white.withOpacity(0.1),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Text("Total: ₹$totalPrice",
//               style: const TextStyle(
//                   fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
//           ElevatedButton(
//             style: ElevatedButton.styleFrom(
//               backgroundColor: const Color(0xFF0A198D),
//               padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
//               shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(12)),
//             ),
//             onPressed: selectedSlots.isEmpty
//                 ? null
//                 : () {
//               Navigator.pushNamed(
//                 context,
//                 '/payment',
//                 arguments: {
//                   'location': widget.location,
//                   'game': widget.game,
//                   'date': DateFormat('yyyy-MM-dd').format(_selectedDay),
//                   'slots': selectedSlots,
//                   'price': totalPrice,
//                 },
//               );
//             },
//             child: const Text("Proceed to Payment",
//                 style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
//           )
//         ],
//       ),
//     );
//   }
// }











import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

class SlotBookingScreen extends StatefulWidget {
  final String location;
  final String game;

  const SlotBookingScreen({
    super.key,
    required this.location,
    required this.game,
  });

  @override
  State<SlotBookingScreen> createState() => _SlotBookingScreenState();
}

class _SlotBookingScreenState extends State<SlotBookingScreen> {
  // --- state ---
  DateTime _selectedDay = DateTime.now();
  bool isLoading = false;
  String? error;

  /// flat list of available slots after day filtering
  List<Map<String, dynamic>> courts = [];

  /// UI selections
  String? selectedCourt;
  String? selectedHourType;

  /// chosen slots by user
  List<Map<String, dynamic>> selectedSlots = [];
  int totalPrice = 0;

  @override
  void initState() {
    super.initState();
    fetchCourtsWisePrice();
  }

  // ---------------------- Day matching helper (handles Mon–Fri etc) ----------------------
  bool isSlotForSelectedDay(String dayKey, String selectedDayName) {
    dayKey = dayKey.toLowerCase().trim();
    selectedDayName = selectedDayName.toLowerCase();

    final dayMap = {
      'mon': 'monday',
      'tue': 'tuesday',
      'wed': 'wednesday',
      'thu': 'thursday',
      'fri': 'friday',
      'sat': 'saturday',
      'sun': 'sunday'
    };

    // direct abbreviation e.g., "Mon"
    if (dayMap.containsKey(dayKey)) {
      return dayMap[dayKey] == selectedDayName;
    }

    // ranges like "Mon–Fri"
    if (dayKey.contains('–')) {
      final parts = dayKey.split('–').map((d) => d.trim()).toList();
      if (parts.length == 2) {
        final daysOrder = [
          'monday',
          'tuesday',
          'wednesday',
          'thursday',
          'friday',
          'saturday',
          'sunday'
        ];
        final left = parts[0].toLowerCase();
        final right = parts[1].toLowerCase();
        final start = dayMap[left] ?? left;
        final end = dayMap[right] ?? right;

        int startIndex = daysOrder.indexOf(start);
        int endIndex = daysOrder.indexOf(end);

        if (startIndex != -1 && endIndex != -1) {
          if (startIndex <= endIndex) {
            return daysOrder
                .sublist(startIndex, endIndex + 1)
                .contains(selectedDayName);
          } else {
            // wrap-around e.g., Fri–Mon
            return (daysOrder.sublist(startIndex) +
                daysOrder.sublist(0, endIndex + 1))
                .contains(selectedDayName);
          }
        }
      }
    }

    // common words
    if (dayKey.contains('all') || dayKey.contains('every')) return true;

    // final fallback: exact name
    return dayKey == selectedDayName;
  }

  // ---------------------- API fetch & parse ----------------------
  Future<void> fetchCourtsWisePrice() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDay);
    final selectedDayName = DateFormat('EEEE').format(_selectedDay);

    final url = Uri.https(
      "nahatasports.com",
      "/api/courts_wise_price",
      {
        "date": formattedDate,
        "sport_name": widget.game,
        "location": widget.location,
      },
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData["status"] == "success") {
          final data = responseData["data"] as Map<String, dynamic>;
          final List<Map<String, dynamic>> parsedSlots = [];

          // flatten & filter by day using helper
          data.forEach((courtName, courtData) {
            final courtMap = courtData as Map<String, dynamic>;
            courtMap.forEach((hourType, daysMap) {
              if (daysMap is Map<String, dynamic>) {
                daysMap.forEach((dayType, slotList) {
                  if (slotList is List &&
                      isSlotForSelectedDay(dayType, selectedDayName)) {
                    for (var slot in slotList) {
                      parsedSlots.add({
                        "court": courtName,
                        "hourType": hourType,
                        "dayType": dayType,
                        "time": slot["time"].toString(),
                        "price": int.tryParse(slot["price"].toString()) ?? 0,
                      });
                    }
                  }
                });
              }
            });
          });

          // retain only currently valid user selections
          final currentSelected = selectedSlots.where((sel) {
            return parsedSlots.any((p) =>
            p['court'] == sel['court'] &&
                p['hourType'] == sel['hourType'] &&
                p['time'] == sel['time']);
          }).toList();

          setState(() {
            courts = parsedSlots;
            selectedSlots = currentSelected;
            totalPrice =
                selectedSlots.fold(0, (sum, s) => sum + (s['price'] as int));

            // choose defaults for court/hour if not set
            final courtNames = _getCourtNames();
            if (courtNames.isNotEmpty &&
                (selectedCourt == null || !courtNames.contains(selectedCourt))) {
              selectedCourt = courtNames.first;
            }
            final hourTypes = _getHourTypesForCourt(selectedCourt);
            if (hourTypes.isNotEmpty &&
                (selectedHourType == null ||
                    !hourTypes.contains(selectedHourType))) {
              selectedHourType = hourTypes.first;
            }
          });
        } else {
          setState(() {
            courts = [];
            selectedSlots.clear();
            totalPrice = 0;
            error = responseData["message"]?.toString() ?? "No data";
          });
        }
      } else {
        setState(() => error = "Server error ${response.statusCode}");
      }
    } catch (e) {
      setState(() => error = "Error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  // ---------------------- helpers to derive lists ----------------------
  List<String> _getCourtNames() {
    final names = courts.map((s) => s['court'].toString()).toSet().toList();
    names.sort();
    return names;
  }

  List<String> _getHourTypesForCourt(String? court) {
    if (court == null) return [];
    final hourTypes =
    courts.where((s) => s['court'] == court).map((s) => s['hourType'].toString()).toSet().toList();
    hourTypes.sort();
    return hourTypes;
  }

  List<Map<String, dynamic>> _getSlotsForCourtAndHour(
      String? court, String? hourType) {
    if (court == null || hourType == null) return [];
    final list = courts.where((s) => s['court'] == court && s['hourType'] == hourType).toList();
    list.sort((a, b) => a['time'].toString().compareTo(b['time'].toString()));
    return list;
  }

  void toggleSlot(Map<String, dynamic> slot) {
    setState(() {
      final exists = selectedSlots.any((s) =>
      s['court'] == slot['court'] &&
          s['hourType'] == slot['hourType'] &&
          s['time'] == slot['time']);
      if (exists) {
        selectedSlots.removeWhere((s) =>
        s['court'] == slot['court'] &&
            s['hourType'] == slot['hourType'] &&
            s['time'] == slot['time']);
      } else {
        selectedSlots.add(slot);
      }
      totalPrice =
          selectedSlots.fold(0, (sum, s) => sum + (s['price'] as int));
    });
  }

  // ---------------------- UI ----------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(child: _buildBody()),
            _buildProceedBar(),
          ],
        ),
      ),
    );
  }

  // Top header with back arrow, title and progress indicators
  Widget _buildTopBar() {
    return Column(
      children: [
        // App bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Text(widget.game,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),

        // Steps row
        // Container(
        //   color: Colors.white,
        //   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        //   child: Row(
        //     children: [
        //       _stepCircle(1, "Date & Time", completed: true),
        //       const SizedBox(width: 8),
        //       _stepDivider(),
        //       const SizedBox(width: 8),
        //       _stepCircle(2, "Ticket", completed: false),
        //       const SizedBox(width: 8),
        //       _stepDivider(),
        //       const SizedBox(width: 8),
        //       _stepCircle(3, "Review & Pay", completed: false),
        //     ],
        //   ),
        // ),

        // Location bar and legend
        // Container(
        //   color: Colors.white,
        //   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        //   child: Column(
        //     crossAxisAlignment: CrossAxisAlignment.start,
        //     children: [
        //       Text(widget.location,
        //           style: const TextStyle(
        //               fontSize: 14, fontWeight: FontWeight.w600)),
        //       // const SizedBox(height: 8),
        //       // Row(
        //       //   children: [
        //       //     _legendDot(Colors.green, "Available"),
        //       //     const SizedBox(width: 12),
        //       //     _legendDot(Colors.orange, "Fast Filling"),
        //       //     const SizedBox(width: 12),
        //       //     _legendDot(Colors.grey, "Sold out"),
        //       //   ],
        //       // )
        //     ],
        //   ),
        // ),

        const SizedBox(height: 8),
      ],
    );
  }

  Widget _stepCircle(int n, String title, {required bool completed}) {
    return Row(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: completed ? const Color(0xFF0A198D) : Colors.grey.shade300,
          child: Text(
            "$n",
            style: TextStyle(
              color: completed ? Colors.white : Colors.black54,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(color: Colors.black54)),
      ],
    );
  }

  Widget _stepDivider() {
    return Expanded(
      child: Container(
        height: 1,
        color: Colors.grey.shade300,
      ),
    );
  }

  Widget _legendDot(Color c, String label) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  // Body contains date chips, court tabs, hour chips and slots
  Widget _buildBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF0A198D)));
    }
    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: fetchCourtsWisePrice, child: const Text("Retry")),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDateCard(),
          const SizedBox(height: 8),
          _buildCourtTabs(),
          const SizedBox(height: 8),
          if (selectedCourt != null) ...[
            _buildHourTypeChips(),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          if (selectedCourt != null && selectedHourType != null) ...[
            _buildSlotsArea(),
            if (selectedSlots.isNotEmpty) const SizedBox(height: 12),
            if (selectedSlots.isNotEmpty) _buildSelectedStrip(),
          ],
          // if (selectedSlots.isNotEmpty) const SizedBox(height: 12),
          // if (selectedSlots.isNotEmpty) _buildSelectedStrip(),
        ],
      ),
    );
  }

  // Date card showing next 7 days as big rounded buttons (selected green)
  Widget _buildDateCard() {
    final firstDayOfMonth = DateTime(_selectedDay.year, _selectedDay.month, 1);
    final lastDayOfMonth = DateTime(_selectedDay.year, _selectedDay.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;

    final days = List<DateTime>.generate(daysInMonth, (i) => firstDayOfMonth.add(Duration(days: i)));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Select Date", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              SizedBox(
                height: 60,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (context, i) {
                    final d = days[i];
                    final isSelected = isSameDate(d, _selectedDay);
                    final label = DateFormat('EEE dd').format(d); // e.g., Fri 26
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedDay = d);
                        fetchCourtsWisePrice();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 80,
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.green.shade400 : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isSelected ? Colors.green.shade400 : Colors.green.shade200),
                          boxShadow: isSelected
                              ? [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2))]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: isSelected ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.w600)),
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemCount: days.length,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Horizontal court selector (like BMS location selector)
  Widget _buildCourtTabs() {
    final courtNames = _getCourtNames();
    if (courtNames.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text("No courts available for this date."),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Select Court",
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 60,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: courtNames.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final court = courtNames[i];
                final isSelected = court == selectedCourt;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedCourt = court;
                      final hours = _getHourTypesForCourt(selectedCourt);
                      selectedHourType = hours.isNotEmpty ? hours.first : null;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 80, // same as date cards
                    alignment: Alignment.center,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.green.shade400 : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Colors.green.shade400 : Colors.green.shade200,
                      ),
                      boxShadow: isSelected
                          ? [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2))]
                          : null,
                    ),
                    child: Text(
                      court,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Hour type chips (Happy Hours / Prime / etc.)
  Widget _buildHourTypeChips() {
    final hourTypes = _getHourTypesForCourt(selectedCourt);
    if (hourTypes.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Wrap(
        spacing: 8,
        children: hourTypes.map((hour) {
          final isSelected = hour == selectedHourType;
          final isHappy = hour.toLowerCase().contains("happy");
          return ChoiceChip(
            label: Text(hour, style: TextStyle(fontWeight: FontWeight.w700, color: isSelected ? Colors.white : Colors.black87)),
            selected: isSelected,
            onSelected: (_) {
              setState(() => selectedHourType = hour);
            },
            selectedColor: isHappy ? Colors.orange.shade600 : Colors.green.shade600,
            backgroundColor: Colors.grey.shade200,
            shape: StadiumBorder(side: BorderSide(color: isSelected ? Colors.transparent : Colors.grey.shade300)),
          );
        }).toList(),
      ),
    );
  }

  // Slots area: big ticket-style pills laid out in a Wrap
  Widget _buildSlotsArea() {
    final slots = _getSlotsForCourtAndHour(selectedCourt, selectedHourType);
    if (slots.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text("No slots available for this selection."),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: slots.map((slot) {
          final isSelected = selectedSlots.any((s) =>
          s['court'] == slot['court'] &&
              s['hourType'] == slot['hourType'] &&
              s['time'] == slot['time']);
          // Demo status detection: if price == 0 (or some condition) we treat as sold out (customize as needed)
          final isSoldOut = (slot['price'] == 0);

          Color bg;
          Color textCol;
          if (isSoldOut) {
            bg = Colors.grey.shade300;
            textCol = Colors.black45;
          } else if (isSelected) {
            bg = Colors.green.shade400;
            textCol = Colors.white;
          } else {
            bg = Colors.white;
            textCol = Colors.black87;
          }

          return GestureDetector(
            onTap: isSoldOut ? null : () => toggleSlot(slot),
            child: Container(
              width: 120,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSelected ? Colors.green.shade600 : Colors.grey.shade300, width: isSelected ? 1.6 : 1),
                boxShadow: isSelected ? [BoxShadow(color: Colors.black12, blurRadius: 6, offset: const Offset(0,3))] : null,
              ),
              child: Column(
                children: [
                  Text(slot['time'], style: TextStyle(fontWeight: FontWeight.w800, color: textCol)),
                  const SizedBox(height: 6),
                  Text("₹${slot['price']}", style: TextStyle(fontSize: 12, color: textCol.withOpacity(0.9))),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Selected slots strip (horizontal chips)
  Widget _buildSelectedStrip() {
    return Column(
      children: [
        const Divider(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Selected", style: TextStyle(fontWeight: FontWeight.w700)),
              Text("${selectedSlots.length} ${selectedSlots.length > 1 ? "slots" : "slot"}", style: const TextStyle(color: Colors.black54)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 46,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            itemBuilder: (context, i) {
              final s = selectedSlots[i];
              return InputChip(
                label: Text("${s['court']} • ${s['time']} • ₹${s['price']}", style: const TextStyle(fontSize: 13)),
                onDeleted: () => toggleSlot(s),
                deleteIcon: const Icon(Icons.close, size: 18),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(side: BorderSide(color: Colors.grey.shade300)),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemCount: selectedSlots.length,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // Sticky bottom proceed bar (full width red rounded)
  Widget _buildProceedBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Total", style: TextStyle(fontSize: 12, color: Colors.black54)),
                Text("₹$totalPrice", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.red)),
              ],
            ),
            const Spacer(),
            Expanded(
              flex: 0,
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.68,
                child: ElevatedButton(
                  onPressed: selectedSlots.isEmpty
                      ? null
                      : () {
                    Navigator.pushNamed(
                      context,
                      '/payment',
                      arguments: {
                        'location': widget.location,
                        'game': widget.game,
                        'date': DateFormat('yyyy-MM-dd').format(_selectedDay),
                        'slots': selectedSlots,
                        'price': totalPrice,
                      },
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 10,
                    shadowColor: Colors.black26,
                  ),
                  child: const Text("Proceed", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // simple date equality
  bool isSameDate(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}












//
// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:intl/intl.dart';
// import 'package:table_calendar/table_calendar.dart';
//
// class SlotBookingScreen extends StatefulWidget {
//   final String location;
//   final String game;
//
//   const SlotBookingScreen({
//     super.key,
//     required this.location,
//     required this.game,
//   });
//
//   @override
//   State<SlotBookingScreen> createState() => _SlotBookingScreenState();
// }
//
// class _SlotBookingScreenState extends State<SlotBookingScreen> {
//   DateTime _selectedDay = DateTime.now();
//   List<Map<String, dynamic>> selectedSlots = [];
//   int totalPrice = 0;
//   List<Map<String, dynamic>> courts = [];
//   bool isLoading = false;
//
//   String? selectedCourt;
//   String? selectedHourType;
//
//   @override
//   void initState() {
//     super.initState();
//     fetchCourtsWisePrice();
//   }
//   bool isSlotForSelectedDay(String dayKey, String selectedDayName) {
//     dayKey = dayKey.toLowerCase().trim();
//     selectedDayName = selectedDayName.toLowerCase();
//
//     final dayMap = {
//       'mon': 'monday',
//       'tue': 'tuesday',
//       'wed': 'wednesday',
//       'thu': 'thursday',
//       'fri': 'friday',
//       'sat': 'saturday',
//       'sun': 'sunday'
//     };
//
//     // handle abbreviations
//     if (dayMap.containsKey(dayKey)) {
//       return dayMap[dayKey] == selectedDayName;
//     }
//
//     // handle ranges like "Mon–Fri"
//     if (dayKey.contains('–')) {
//       final parts = dayKey.split('–').map((d) => d.trim()).toList();
//       if (parts.length == 2) {
//         final daysOrder = [
//           'monday',
//           'tuesday',
//           'wednesday',
//           'thursday',
//           'friday',
//           'saturday',
//           'sunday'
//         ];
//
//         int startIndex = daysOrder.indexOf(dayMap[parts[0].toLowerCase()] ?? parts[0].toLowerCase());
//         int endIndex = daysOrder.indexOf(dayMap[parts[1].toLowerCase()] ?? parts[1].toLowerCase());
//
//         if (startIndex != -1 && endIndex != -1) {
//           if (startIndex <= endIndex) {
//             return daysOrder.sublist(startIndex, endIndex + 1).contains(selectedDayName);
//           } else {
//             // wrap-around like Fri–Mon
//             return (daysOrder.sublist(startIndex) + daysOrder.sublist(0, endIndex + 1))
//                 .contains(selectedDayName);
//           }
//         }
//       }
//     }
//
//     // handle full names
//     return dayKey == selectedDayName;
//   }
//
//   Future<void> fetchCourtsWisePrice() async {
//     setState(() => isLoading = true);
//     final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDay);
//     final selectedDayName = DateFormat('EEEE').format(_selectedDay);
//     final url = Uri.https(
//       "nahatasports.com",
//       "/api/courts_wise_price",
//       {
//         "date": formattedDate,
//         "sport_name": widget.game,
//         "location": widget.location,
//       },
//     );
//
//     try {
//       final response = await http.get(url);
//       if (response.statusCode == 200) {
//         final responseData = json.decode(response.body);
//         if (responseData["status"] == "success") {
//           final data = responseData["data"] as Map<String, dynamic>;
//           List<Map<String, dynamic>> parsedSlots = [];
//
//           data.forEach((courtName, courtData) {
//             final courtMap = courtData as Map<String, dynamic>;
//             courtMap.forEach((hourType, daysMap) {
//               if (daysMap is Map<String, dynamic>) {
//                 daysMap.forEach((dayType, slotList) {
//                   if (slotList is List &&
//                       isSlotForSelectedDay(dayType, selectedDayName)) {
//                     for (var slot in slotList) {
//                       parsedSlots.add({
//                         "court": courtName,
//                         "hourType": hourType,
//                         "dayType": dayType,
//                         "time": slot["time"].toString(),
//                         "price": int.tryParse(slot["price"].toString()) ?? 0,
//                       });
//                     }
//                   }
//                 }
//                 );
//               }
//             });
//           });
//                 print("Parsed Slots: $parsedSlots");
//           setState(() {
//             courts = parsedSlots;
//             selectedSlots.clear();
//             totalPrice = 0;
//           });
//         }
//       }
//     } catch (e) {
//       print("Error fetching courts price: $e");
//     }
//     setState(() => isLoading = false);
//   }
//
//   void toggleSlot(Map<String, dynamic> slot) {
//     setState(() {
//       final exists = selectedSlots.any(
//               (s) => s['court'] == slot['court'] && s['time'] == slot['time']);
//       if (exists) {
//         selectedSlots.removeWhere(
//                 (s) => s['court'] == slot['court'] && s['time'] == slot['time']);
//       } else {
//         selectedSlots.add(slot);
//       }
//       totalPrice = selectedSlots.fold(0, (sum, s) => sum + (s['price'] as int));
//     });
//   }
//
//   List<String> getHourTypesForCourt(String court) {
//     final courtSlots = courts.where((s) => s['court'] == court);
//     return courtSlots.map((s) => s['hourType'].toString()).toSet().toList();
//   }
//
//   List<Map<String, dynamic>> getSlotsForCourtAndHour(
//       String court, String hourType) {
//     return courts
//         .where((s) => s['court'] == court && s['hourType'] == hourType)
//         .toList();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return SafeArea(
//       child : Scaffold(
//
//         backgroundColor: const Color(0xFFF2F4F7),
//         body: SafeArea(
//           child: isLoading
//               ? const Center(
//               child: CircularProgressIndicator(color: Color(0xFF0A198D)))
//               : SingleChildScrollView(
//             child: Column(
//               children: [
//                 _buildCalendarCard(),
//                 const SizedBox(height: 12),
//                 _buildStepByStepUI(),
//                 if (selectedSlots.isNotEmpty) _buildReviewSummary(),
//                 const SizedBox(height: 80), // leave space for bottom bar
//               ],
//             ),
//           ),
//         ),
//         bottomNavigationBar: _buildBottomBar(),
//       ),
//     );
//   }
//
//   // Step-by-step UI
//   Widget _buildStepByStepUI() {
//     if (selectedCourt == null) {
//       return _buildCourtSelector();
//     } else if (selectedHourType == null) {
//       return Column(
//         children: [
//           _buildSelectedCourtHeader(),
//           _buildHourTypeSelector(),
//         ],
//       );
//     } else {
//       return Column(
//         children: [
//           _buildSelectedCourtHeader(),
//           _buildHourTypeSelector(),
//           _buildSlotSelector(),
//         ],
//       );
//     }
//   }
//
//   Widget _buildSelectedCourtHeader() {
//     return Card(
//       margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       child: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             Text(
//               selectedCourt ?? "",
//               style: const TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.black87),
//             ),
//             TextButton(
//               onPressed: () {
//                 setState(() {
//                   selectedCourt = null;
//                   selectedHourType = null;
//                 });
//               },
//               child: const Text("Change Court",
//                   style: TextStyle(color: Color(0xFF0A198D))),
//             )
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildCourtSelector() {
//     final courtNames = courts.map((s) => s['court'].toString()).toSet().toList();
//
//     return ListView.builder(
//       shrinkWrap: true,
//       physics: const NeverScrollableScrollPhysics(),
//       itemCount: courtNames.length,
//       padding: const EdgeInsets.all(12),
//       itemBuilder: (context, index) {
//         final court = courtNames[index];
//         return Card(
//           margin: const EdgeInsets.only(bottom: 12),
//           shape:
//           RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//           elevation: 3,
//           child: ListTile(
//             title: Text(court,
//                 style: const TextStyle(fontWeight: FontWeight.bold)),
//             trailing: const Icon(Icons.arrow_forward_ios, size: 16),
//             onTap: () {
//               setState(() {
//                 selectedCourt = court;
//                 selectedHourType = null;
//               });
//             },
//           ),
//         );
//       },
//     );
//   }
//
//   Widget _buildHourTypeSelector() {
//     if (selectedCourt == null) return const SizedBox.shrink();
//     final hourTypes = getHourTypesForCourt(selectedCourt!);
//
//     return Padding(
//       padding: const EdgeInsets.all(12),
//       child: Wrap(
//         spacing: 8,
//         children: hourTypes.map((hour) {
//           final isSelected = selectedHourType == hour;
//           final isHappy = hour.toLowerCase().contains("happy");
//           return ChoiceChip(
//             label: Text(hour),
//             selected: isSelected,
//             onSelected: (_) {
//               setState(() {
//                 selectedHourType = hour;
//               });
//             },
//             selectedColor:
//             isHappy ? Colors.orange.shade100 : Colors.indigo.shade100,
//             backgroundColor: Colors.grey.shade200,
//             labelStyle: TextStyle(
//                 color: isSelected
//                     ? (isHappy ? Colors.orange.shade800 : Colors.indigo.shade900)
//                     : Colors.black),
//           );
//         }).toList(),
//       ),
//     );
//   }
//
//   Widget _buildSlotSelector() {
//     if (selectedCourt == null || selectedHourType == null) {
//       return const SizedBox.shrink();
//     }
//     final slots = getSlotsForCourtAndHour(selectedCourt!, selectedHourType!);
//
//     return Padding(
//       padding: const EdgeInsets.all(12.0),
//       child: Wrap(
//         spacing: 8,
//         runSpacing: 8,
//         children: slots.map((slot) {
//           final isSelected = selectedSlots.any(
//                   (s) => s['court'] == slot['court'] && s['time'] == slot['time']);
//           return GestureDetector(
//             onTap: () => toggleSlot(slot),
//             child: Container(
//               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//               decoration: BoxDecoration(
//                 color: isSelected ? Colors.indigo.shade50 : Colors.white,
//                 borderRadius: BorderRadius.circular(10),
//                 border: Border.all(
//                   color: isSelected ? Colors.indigo : Colors.grey.shade300,
//                   width: 1.2,
//                 ),
//               ),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Text(slot['time']),
//                   Text("₹${slot['price']}"),
//                 ],
//               ),
//             ),
//           );
//         }).toList(),
//       ),
//     );
//   }
//
//   Widget _buildCalendarCard() {
//     return Card(
//       color: Colors.white,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       elevation: 4,
//       margin: const EdgeInsets.all(12),
//       child: Padding(
//         padding: const EdgeInsets.all(12),
//         child: Column(
//           children: [
//             const Text("Select Date",
//                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
//             TableCalendar(
//               firstDay: DateTime.now(),
//               lastDay: DateTime.now().add(const Duration(days: 30)),
//               focusedDay: _selectedDay,
//               selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
//               onDaySelected: (selected, _) {
//                 setState(() => _selectedDay = selected);
//                 fetchCourtsWisePrice();
//               },
//               headerStyle:
//               const HeaderStyle(formatButtonVisible: false, titleCentered: true),
//               calendarStyle: CalendarStyle(
//                 todayDecoration: BoxDecoration(
//                   color: Colors.indigo.shade100,
//                   shape: BoxShape.circle,
//                 ),
//                 selectedDecoration: BoxDecoration(
//                   color: Colors.indigo,
//                   shape: BoxShape.circle,
//                 ),
//                 selectedTextStyle: const TextStyle(color: Colors.white),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildReviewSummary() {
//     if (selectedSlots.isEmpty) return const SizedBox.shrink();
//
//     final grouped = <String, Map<String, List<Map<String, dynamic>>>>{};
//     for (var slot in selectedSlots) {
//       final court = slot['court'];
//       final hour = slot['hourType'];
//       grouped.putIfAbsent(court, () => {});
//       grouped[court]!.putIfAbsent(hour, () => []);
//       grouped[court]![hour]!.add(slot);
//     }
//
//     return Card(
//       margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       elevation: 4,
//       child: Padding(
//         padding: const EdgeInsets.all(12),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text("Review Selection",
//                 style: TextStyle(
//                     fontSize: 16,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.black87)),
//             const SizedBox(height: 8),
//             ...grouped.entries.map((courtEntry) {
//               final court = courtEntry.key;
//               return Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(court,
//                       style: const TextStyle(
//                           fontSize: 14, fontWeight: FontWeight.w600)),
//                   const SizedBox(height: 4),
//                   ...courtEntry.value.entries.map((hourEntry) {
//                     return Wrap(
//                       spacing: 8,
//                       children: hourEntry.value.map((slot) {
//                         return Chip(
//                           label: Text("${slot['time']} ₹${slot['price']}"),
//                           deleteIcon: const Icon(Icons.remove_circle, size: 18),
//                           onDeleted: () {
//                             toggleSlot(slot);
//                           },
//                         );
//                       }).toList(),
//                     );
//                   })
//                 ],
//               );
//             }).toList(),
//             const Divider(height: 12, color: Colors.black26),
//             Text("Total: ₹$totalPrice",
//                 style: const TextStyle(
//                     fontSize: 16,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.black)),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildBottomBar() {
//     return Container(
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         boxShadow: [
//           BoxShadow(
//               color: Colors.black12, offset: Offset(0, -2), blurRadius: 6),
//         ],
//       ),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Text("Total: ₹$totalPrice",
//               style: const TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.red)),
//           ElevatedButton(
//             style: ElevatedButton.styleFrom(
//               backgroundColor: const Color(0xFF0A198D),
//               padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
//               shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(12)),
//             ),
//             onPressed: selectedSlots.isEmpty
//                 ? null
//                 : () {
//               Navigator.pushNamed(
//                 context,
//                 '/payment',
//                 arguments: {
//                   'location': widget.location,
//                   'game': widget.game,
//                   'date': DateFormat('yyyy-MM-dd').format(_selectedDay),
//                   'slots': selectedSlots,
//                   'price': totalPrice,
//                 },
//               );
//             },
//             child: const Text("Proceed to Payment",
//                 style: TextStyle(
//                     fontSize: 16,
//                     fontWeight: FontWeight.w500,
//                     color: Colors.white)),
//           )
//         ],
//       ),
//     );
//   }
// }





























//
// import 'dart:convert';
//
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:intl/intl.dart';
// import 'package:table_calendar/table_calendar.dart';
//
// class SlotBookingScreen extends StatefulWidget {
//   final String location;
//   final String game;
//
//   const SlotBookingScreen({
//     super.key,
//     required this.location,
//     required this.game,
//   });
//
//   @override
//   State<SlotBookingScreen> createState() => _SlotBookingScreenState();
// }
//
// class _SlotBookingScreenState extends State<SlotBookingScreen> {
//   DateTime _selectedDay = DateTime.now();
//   List<Map<String, dynamic>> selectedSlots = [];
//   int totalPrice = 0;
//   List<Map<String, dynamic>> courts = [];
//   bool isLoading = false;
//
//   String? selectedCourt;
//   String? selectedHourType;
//
//   @override
//   void initState() {
//     super.initState();
//     fetchCourtsWisePrice();
//   }
//
//   Future<void> fetchCourtsWisePrice() async {
//     setState(() => isLoading = true);
//     final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDay);
//
//     final url = Uri.https(
//       "nahatasports.com",
//       "/api/courts_wise_price",
//       {
//         "date": formattedDate,
//         "sport_name": widget.game,
//         "location": widget.location,
//       },
//     );
//
//     try {
//       final response = await http.get(url);
//       if (response.statusCode == 200) {
//         final responseData = json.decode(response.body);
//         if (responseData["status"] == "success") {
//           final data = responseData["data"] as Map<String, dynamic>;
//           List<Map<String, dynamic>> parsedSlots = [];
//
//           data.forEach((courtName, courtData) {
//             final courtMap = courtData as Map<String, dynamic>;
//             courtMap.forEach((hourType, daysMap) {
//               if (daysMap is Map<String, dynamic>) {
//                 daysMap.forEach((dayType, slotList) {
//                   if (slotList is List) {
//                     for (var slot in slotList) {
//                       parsedSlots.add({
//                         "court": courtName,
//                         "hourType": hourType,
//                         "dayType": dayType,
//                         "time": slot["time"].toString(),
//                         "price": int.tryParse(slot["price"].toString()) ?? 0,
//                       });
//                     }
//                   }
//                 });
//               }
//             });
//           });
//
//           setState(() {
//             courts = parsedSlots;
//             selectedSlots.clear();
//             totalPrice = 0;
//           });
//         }
//       }
//     } catch (e) {
//       print("Error fetching courts price: $e");
//     }
//     setState(() => isLoading = false);
//   }
//
//   void toggleSlot(Map<String, dynamic> slot) {
//     setState(() {
//       final exists = selectedSlots.any(
//               (s) => s['court'] == slot['court'] && s['time'] == slot['time']);
//       if (exists) {
//         selectedSlots.removeWhere(
//                 (s) => s['court'] == slot['court'] && s['time'] == slot['time']);
//       } else {
//         selectedSlots.add(slot);
//       }
//       totalPrice = selectedSlots.fold(0, (sum, s) => sum + (s['price'] as int));
//     });
//   }
//
//   List<String> getHourTypesForCourt(String court) {
//     final courtSlots = courts.where((s) => s['court'] == court);
//     return courtSlots.map((s) => s['hourType'].toString()).toSet().toList();
//   }
//
//   List<Map<String, dynamic>> getSlotsForCourtAndHour(String court, String hourType) {
//     return courts
//         .where((s) => s['court'] == court && s['hourType'] == hourType)
//         .toList();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFF2F4F7),
//       body: SafeArea(
//         child: isLoading
//             ? const Center(child: CircularProgressIndicator(color: Colors.white))
//             : SingleChildScrollView(
//           child: Column(
//             children: [
//               _buildCalendarCard(),
//               const SizedBox(height: 12),
//               _buildStepByStepUI(),
//               if (selectedSlots.isNotEmpty) _buildReviewSummary(),
//               const SizedBox(height: 10),
//               _buildBottomBar(),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   // Step-by-step UI
//   Widget _buildStepByStepUI() {
//     if (selectedCourt == null) {
//       return _buildCourtSelector();
//     } else if (selectedHourType == null) {
//       return Column(
//         children: [
//           _buildSelectedCourtHeader(),
//           _buildHourTypeSelector(),
//         ],
//       );
//     } else {
//       return Column(
//         children: [
//           _buildSelectedCourtHeader(),
//           _buildHourTypeSelector(),
//           _buildSlotSelector(),
//         ],
//       );
//     }
//   }
//
//   Widget _buildSelectedCourtHeader() {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Text(
//             selectedCourt ?? "",
//             style: const TextStyle(
//                 fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
//           ),
//           TextButton(
//             onPressed: () {
//               setState(() {
//                 selectedCourt = null;
//                 selectedHourType = null;
//               });
//             },
//             child: const Text("Change Court",style: TextStyle(color: Colors.white),),
//           )
//         ],
//       ),
//     );
//   }
//
//   Widget _buildCourtSelector() {
//     final courtNames = courts.map((s) => s['court'].toString()).toSet().toList();
//
//     return ListView.builder(
//       shrinkWrap: true,
//       physics: const NeverScrollableScrollPhysics(),
//       itemCount: courtNames.length,
//       padding: const EdgeInsets.all(12),
//       itemBuilder: (context, index) {
//         final court = courtNames[index];
//         return Card(
//           margin: const EdgeInsets.only(bottom: 12),
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//           color: Colors.white.withOpacity(0.95),
//           elevation: 3,
//           child: ListTile(
//             title: Text(court, style: const TextStyle(fontWeight: FontWeight.bold)),
//             trailing: const Icon(Icons.arrow_forward_ios, size: 16),
//             onTap: () {
//               setState(() {
//                 selectedCourt = court;
//                 selectedHourType = null;
//               });
//             },
//           ),
//         );
//       },
//     );
//   }
//
//   Widget _buildHourTypeSelector() {
//     if (selectedCourt == null) return const SizedBox.shrink();
//     final hourTypes = getHourTypesForCourt(selectedCourt!);
//
//     return SizedBox(
//       height: 50,
//       child: ListView.builder(
//         scrollDirection: Axis.horizontal,
//         padding: const EdgeInsets.symmetric(horizontal: 12),
//         itemCount: hourTypes.length,
//         itemBuilder: (context, index) {
//           final hour = hourTypes[index];
//           final isSelected = selectedHourType == hour;
//           final isHappy = hour.toLowerCase().contains("happy");
//           return Padding(
//             padding: const EdgeInsets.only(right: 8),
//             child: ChoiceChip(
//               label: Text(hour),
//               selected: isSelected,
//               onSelected: (_) {
//                 setState(() {
//                   selectedHourType = hour;
//                 });
//               },
//               selectedColor: isHappy ? Colors.orange.shade100 : Colors.indigo.shade100,
//               backgroundColor: Colors.grey.shade200,
//               labelStyle: TextStyle(
//                   color: isSelected
//                       ? (isHappy ? Colors.orange.shade800 : Colors.indigo.shade900)
//                       : Colors.black),
//             ),
//           );
//         },
//       ),
//     );
//   }
//
//   Widget _buildSlotSelector() {
//     if (selectedCourt == null || selectedHourType == null) return const SizedBox.shrink();
//     final slots = getSlotsForCourtAndHour(selectedCourt!, selectedHourType!);
//
//     return Padding(
//       padding: const EdgeInsets.all(12.0),
//       child: Wrap(
//         spacing: 8,
//         runSpacing: 8,
//         children: slots.map((slot) {
//           final isSelected = selectedSlots.any(
//                   (s) => s['court'] == slot['court'] && s['time'] == slot['time']);
//           return GestureDetector(
//             onTap: () => toggleSlot(slot),
//             child: Container(
//               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//               decoration: BoxDecoration(
//                 color: isSelected ? Colors.indigo.shade50 : Colors.white,
//                 borderRadius: BorderRadius.circular(10),
//                 border: Border.all(
//                   color: isSelected ? Colors.indigo : Colors.grey.shade300,
//                   width: 1.2,
//                 ),
//               ),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Text(slot['time']),
//                   Text("₹${slot['price']}"),
//                 ],
//               ),
//             ),
//           );
//         }).toList(),
//       ),
//     );
//   }
//
//   Widget _buildCalendarCard() {
//     return Card(
//       color: Colors.white.withOpacity(0.9),
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       elevation: 4,
//       margin: const EdgeInsets.all(12),
//       child: Padding(
//         padding: const EdgeInsets.all(12),
//         child: Column(
//           children: [
//             const Text("Select Date",
//                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
//             TableCalendar(
//               firstDay: DateTime.now(),
//               lastDay: DateTime.now().add(const Duration(days: 30)),
//               focusedDay: _selectedDay,
//               selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
//               onDaySelected: (selected, _) {
//                 setState(() => _selectedDay = selected);
//                 fetchCourtsWisePrice();
//               },
//               headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
//               calendarStyle: CalendarStyle(
//                 todayDecoration: BoxDecoration(
//                   color: Colors.indigo.shade100,
//                   shape: BoxShape.circle,
//                 ),
//                 selectedDecoration: BoxDecoration(
//                   color: Colors.indigo,
//                   shape: BoxShape.circle,
//                 ),
//                 selectedTextStyle: const TextStyle(color: Colors.white),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildReviewSummary() {
//     if (selectedSlots.isEmpty) return const SizedBox.shrink();
//
//     final grouped = <String, Map<String, List<Map<String, dynamic>>>>{};
//     for (var slot in selectedSlots) {
//       final court = slot['court'];
//       final hour = slot['hourType'];
//       grouped.putIfAbsent(court, () => {});
//       grouped[court]!.putIfAbsent(hour, () => []);
//       grouped[court]![hour]!.add(slot);
//     }
//
//     return Card(
//       margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       color: Colors.white.withOpacity(0.9),
//       elevation: 4,
//       child: Padding(
//         padding: const EdgeInsets.all(12),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text("Review Selection",
//                 style: TextStyle(
//                     fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
//             const SizedBox(height: 8),
//             ...grouped.entries.map((courtEntry) {
//               final court = courtEntry.key;
//               return Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(court,
//                       style: const TextStyle(
//                           fontSize: 14, fontWeight: FontWeight.w600)),
//                   const SizedBox(height: 4),
//                   ...courtEntry.value.entries.map((hourEntry) {
//                     final hour = hourEntry.key;
//                     return Wrap(
//                       spacing: 8,
//                       children: hourEntry.value.map((slot) {
//                         return Chip(
//                           label: Text("${slot['time']} ₹${slot['price']}"),
//                           deleteIcon: const Icon(Icons.remove_circle, size: 18),
//                           onDeleted: () {
//                             toggleSlot(slot);
//                           },
//                         );
//                       }).toList(),
//                     );
//                   })
//                 ],
//               );
//             }).toList(),
//             const Divider(height: 12, color: Colors.black26),
//             Text("Total: ₹$totalPrice",
//                 style: const TextStyle(
//                     fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildBottomBar() {
//     return Container(
//       padding: const EdgeInsets.all(12),
//       color: Colors.white.withOpacity(0.1),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Text("Total: ₹$totalPrice",
//               style: const TextStyle(
//                   fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
//           ElevatedButton(
//             style: ElevatedButton.styleFrom(
//               backgroundColor: const Color(0xFF0A198D),
//               padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
//               shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(12)),
//             ),
//             onPressed: selectedSlots.isEmpty
//                 ? null
//                 : () {
//               Navigator.pushNamed(
//                 context,
//                 '/payment',
//                 arguments: {
//                   'location': widget.location,
//                   'game': widget.game,
//                   'date': DateFormat('yyyy-MM-dd').format(_selectedDay),
//                   'slots': selectedSlots,
//                   'price': totalPrice,
//                 },
//               );
//             },
//             child: const Text("Proceed to Payment",
//                 style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500,color: Colors.white)),
//           )
//         ],
//       ),
//     );
//   }
// }
