import 'package:flutter/material.dart';
import '../core/utils/app_logger.dart';


import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nahata_app/core/network/http_logged.dart' as http;
import 'package:nahata_app/auth/login.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nahata_app/core/network/http_logged.dart' as http;
import 'package:nahata_app/auth/login.dart';

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:nahata_app/core/network/http_logged.dart' as http;
import 'package:nahata_app/auth/login.dart';
import 'package:nahata_app/bottombar/Viewgame.dart' hide ApiService;
import 'package:nahata_app/bottombar/bkpayment.dart';
import 'package:nahata_app/core/widgets/app_shimmer.dart';
import '../models/coupon_model.dart';
import '../repositories/coupon_repository.dart';





///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
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
//   bool isLoading = false;
//   String? error;
//
//   List<Map<String, dynamic>> courts = [];
// //   String? selectedHourType;
//
//   List<Map<String, dynamic>> selectedSlots = [];
//   int totalPrice = 0;
//
//   @override
//   void initState() {
//     super.initState();
//     fetchCourtsWisePrice();
//   }
//
//   // ---------------------- Day matcher ----------------------
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
//     if (dayMap.containsKey(dayKey)) {
//       return dayMap[dayKey] == selectedDayName;
//     }
//
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
//         final start = dayMap[parts[0]] ?? parts[0];
//         final end = dayMap[parts[1]] ?? parts[1];
//
//         final startIndex = daysOrder.indexOf(start);
//         final endIndex = daysOrder.indexOf(end);
//
//         if (startIndex != -1 && endIndex != -1) {
//           if (startIndex <= endIndex) {
//             return daysOrder.sublist(startIndex, endIndex + 1).contains(selectedDayName);
//           } else {
//             return (daysOrder.sublist(startIndex) + daysOrder.sublist(0, endIndex + 1))
//                 .contains(selectedDayName);
//           }
//         }
//       }
//     }
//
//     if (dayKey.contains('all') || dayKey.contains('every')) return true;
//     return dayKey == selectedDayName;
//   }
//
//   // ---------------------- API fetch ----------------------
//   Future<void> fetchCourtsWisePrice() async {
//     setState(() {
//       isLoading = true;
//       error = null;
//     });
//
//     final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDay);
//     final selectedDayName = DateFormat('EEEE').format(_selectedDay);
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
//           final List<Map<String, dynamic>> parsedSlots = [];
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
//                 });
//               }
//             });
//           });
//         print(data);
//         print(responseData);
//         print(response);
//           final currentSelected = selectedSlots.where((sel) {
//             return parsedSlots.any((p) =>
//             p['court'] == sel['court'] &&
//                 p['hourType'] == sel['hourType'] &&
//                 p['time'] == sel['time']);
//           }).toList();
//
//           setState(() {
//             courts = parsedSlots;
//             selectedSlots = currentSelected;
//             totalPrice = selectedSlots.fold(0, (sum, s) => sum + (s['price'] as int));
//
//             final courtNames = _getCourtNames();
//             if (courtNames.isNotEmpty &&
//                 (selectedCourt == null || !courtNames.contains(selectedCourt))) {
//               selectedCourt = courtNames.first;
//             }
//             final hourTypes = _getHourTypesForCourt(selectedCourt);
//             if (hourTypes.isNotEmpty &&
//                 (selectedHourType == null ||
//                     !hourTypes.contains(selectedHourType))) {
//               selectedHourType = hourTypes.first;
//             }
//           });
//         } else {
//           setState(() {
//             courts = [];
//             selectedSlots.clear();
//             totalPrice = 0;
//             error = responseData["message"]?.toString() ?? "No data";
//           });
//         }
//       } else {
//         setState(() => error = "Server error ${response.statusCode}");
//       }
//     } catch (e) {
//       setState(() => error = "Error: $e");
//     } finally {
//       setState(() => isLoading = false);
//     }
//   }
//
//   // ---------------------- Helpers ----------------------
// //
// //
// //
//   void toggleSlot(Map<String, dynamic> slot) {
//     setState(() {
//       final exists = selectedSlots.any((s) =>
//       s['court'] == slot['court'] &&
//           s['hourType'] == slot['hourType'] &&
//           s['time'] == slot['time']);
//       if (exists) {
//         selectedSlots.removeWhere((s) =>
//         s['court'] == slot['court'] &&
//             s['hourType'] == slot['hourType'] &&
//             s['time'] == slot['time']);
//       } else {
//         selectedSlots.add(slot);
//       }
//       totalPrice = selectedSlots.fold(0, (sum, s) => sum + (s['price'] as int));
//     });
//   }
//
//   void removeAllSlots() {
//     setState(() {
//       selectedSlots.clear();
//       totalPrice = 0;
//     });
//   }
//
//   // ---------------------- UI ----------------------
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: _buildAppBar(),
//       body: Column(
//         children: [
//           Expanded(child: _buildBody()),
//           _buildBottomBar(),
//         ],
//       ),
//     );
//   }
//
//   PreferredSizeWidget _buildAppBar() {
//     return AppBar(
//       backgroundColor: Colors.white,
//       elevation: 0,
//       leading: InkWell(
//         onTap: (){
//           Navigator.pushReplacement(
//             context,
//             MaterialPageRoute(builder: (context) => Viewgame(locationName: widget.location,)),
//           );
//         },
//         child: const Icon(
//           Icons.arrow_back_ios_new,
//           color: Colors.black87,
//           size: 18,
//         ),
//       ),
//       title: const Text(
//         "Book and Play",
//         style: TextStyle(
//           color: Colors.black,
//           fontSize: 18,
//           fontWeight: FontWeight.w600,
//         ),
//         textAlign: TextAlign.center
//       ),
//       centerTitle: false,
//       actions: [
//         if (selectedSlots.isNotEmpty)
//           TextButton(
//             onPressed: removeAllSlots,
//             child: const Text(
//               "Clear All",
//               style: TextStyle(
//                 color: Colors.red,
//                 fontWeight: FontWeight.w600,
//               ),
//             ),
//           ),
//       ],
//     );
//   }
//
//   Widget _buildBody() {
//     if (isLoading) {
//       return const Center(
//         child: CircularProgressIndicator(
//           color: Color(0xFF6366F1),
//         ),
//       );
//     }
//     if (error != null) {
//       return Center(
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Icon(
//               Icons.error_outline,
//               size: 64,
//               color: Colors.red.shade300,
//             ),
//             const SizedBox(height: 16),
//             Text(
//               error!,
//               style: const TextStyle(
//                 color: Colors.red,
//                 fontSize: 16,
//               ),
//               textAlign: TextAlign.center,
//             ),
//             const SizedBox(height: 20),
//             ElevatedButton(
//               onPressed: fetchCourtsWisePrice,
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: const Color(0xFF6366F1),
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 24,
//                   vertical: 12,
//                 ),
//               ),
//               child: const Text(
//                 "Retry",
//                 style: TextStyle(color: Colors.white),
//               ),
//             ),
//           ],
//         ),
//       );
//     }
//
//     return SingleChildScrollView(
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const SizedBox(height: 20),
//           _buildGameTitle(),
//           const SizedBox(height: 24),
//           _buildCalendar(),
//           const SizedBox(height: 24),
//           _buildCourtsList(),
//           const SizedBox(height: 100), // Extra space for bottom bar
//         ],
//       ),
//     );
//   }
//
//   Widget _buildGameTitle() {
//     return Center(
//       child: Column(
//         children: [
//           Text(
//             widget.game,
//             style: const TextStyle(
//               fontSize: 20,
//               fontWeight: FontWeight.w600,
//               color: Colors.black87,
//             ),
//           ),
//           const SizedBox(height: 8),
//           Text(
//             widget.location,
//             style: TextStyle(
//               fontSize: 14,
//               color: Colors.grey.shade600,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildCalendar() {
//     return Container(
//       margin: const EdgeInsets.symmetric(horizontal: 20),
//       padding: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         color: const Color(0xFF1A237E),
//         borderRadius: BorderRadius.circular(16),
//         boxShadow: [
//           BoxShadow(
//             color: const Color(0xFF1A237E).withOpacity(0.3),
//             blurRadius: 10,
//             offset: const Offset(0, 4),
//           ),
//         ],
//       ),
//       child: Column(
//         children: [
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Text(
//                 DateFormat('MMMM yyyy').format(_selectedDay),
//                 style: const TextStyle(
//                   color: Colors.white,
//                   fontSize: 18,
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//               Row(
//                 children: [
//                   GestureDetector(
//                     onTap: () {
//                       setState(() {
//                         _selectedDay = DateTime(
//                           _selectedDay.year,
//                           _selectedDay.month - 1,
//                           1,
//                         );
//                       });
//                       fetchCourtsWisePrice();
//                     },
//                     child: const Icon(
//                       Icons.keyboard_arrow_left,
//                       color: Colors.white,
//                     ),
//                   ),
//                   const SizedBox(width: 8),
//                   GestureDetector(
//                     onTap: () {
//                       setState(() {
//                         _selectedDay = DateTime(
//                           _selectedDay.year,
//                           _selectedDay.month + 1,
//                           1,
//                         );
//                       });
//                       fetchCourtsWisePrice();
//                     },
//                     child: const Icon(
//                       Icons.keyboard_arrow_right,
//                       color: Colors.white,
//                     ),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//           const SizedBox(height: 16),
//           _buildWeekDaysHeader(),
//           const SizedBox(height: 12),
//           _buildCalendarGrid(),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildWeekDaysHeader() {
//     const days = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
//     return Row(
//       children: days.map((day) => Expanded(
//         child: Center(
//           child: Text(
//             day,
//             style: const TextStyle(
//               color: Colors.white70,
//               fontSize: 12,
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//         ),
//       )).toList(),
//     );
//   }
//
//   Widget _buildCalendarGrid() {
//     final firstDayOfMonth = DateTime(_selectedDay.year, _selectedDay.month, 1);
//     final lastDayOfMonth = DateTime(_selectedDay.year, _selectedDay.month + 1, 0);
//     final startDate = firstDayOfMonth.subtract(Duration(days: firstDayOfMonth.weekday % 7));
//     final today = DateTime.now();
//
//     return Column(
//       children: List.generate(6, (weekIndex) {
//         return Row(
//           children: List.generate(7, (dayIndex) {
//             final date = startDate.add(Duration(days: weekIndex * 7 + dayIndex));
//             final isCurrentMonth = date.month == _selectedDay.month;
//             final isSelected = isSameDate(date, _selectedDay);
//             final isToday = isSameDate(date, today);
//             final isPast = date.isBefore(today) && !isToday;
//
//             if (!isCurrentMonth) {
//               return const Expanded(child: SizedBox(height: 40));
//             }
//
//             return Expanded(
//               child: GestureDetector(
//                 onTap: isPast ? null : () {
//                   setState(() => _selectedDay = date);
//                   fetchCourtsWisePrice();
//                 },
//                 child: Container(
//                   height: 40,
//                   margin: const EdgeInsets.all(2),
//                   decoration: BoxDecoration(
//                     color: isSelected
//                         ? Colors.white
//                         : Colors.transparent,
//                     borderRadius: BorderRadius.circular(8),
//                     border: isToday && !isSelected
//                         ? Border.all(color: Colors.white70, width: 1)
//                         : null,
//                   ),
//                   child: Center(
//                     child: Text(
//                       date.day.toString(),
//                       style: TextStyle(
//                         color: isPast
//                             ? Colors.white38
//                             : (isSelected
//                             ? const Color(0xFF1A237E)
//                             : Colors.white),
//                         fontWeight: FontWeight.w600,
//                         fontSize: 16,
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             );
//           }),
//         );
//       }).where((widget) => widget != null).take(5).toList(),
//     );
//   }
//
//   Widget _buildCourtsList() {
//     final courtNames = _getCourtNames();
//     if (courtNames.isEmpty) {
//       return Padding(
//         padding: const EdgeInsets.all(20),
//         child: Center(
//           child: Column(
//             children: [
//               Icon(
//                 Icons.sports_tennis,
//                 size: 64,
//                 color: Colors.grey.shade400,
//               ),
//               const SizedBox(height: 16),
//               const Text(
//                 "No courts available for this date.",
//                 style: TextStyle(
//                   color: Colors.grey,
//                   fontSize: 16,
//                 ),
//                 textAlign: TextAlign.center,
//               ),
//             ],
//           ),
//         ),
//       );
//     }
//
//     return Column(
//       children: [
//         ...courtNames.map((court) => _buildCourtCard(court)).toList(),
//         if (selectedSlots.isNotEmpty) ...[
//           const SizedBox(height: 24),
//           _buildSelectedSlotsList(),
//         ],
//       ],
//     );
//   }
//
//   Widget _buildCourtCard(String court) {
//     final hourTypes = _getHourTypesForCourt(court);
//
//     return Container(
//       margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
//       decoration: BoxDecoration(
//         color: Colors.grey.shade50,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: Colors.grey.shade200),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.05),
//             blurRadius: 5,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: Theme(
//         data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
//         child: ExpansionTile(
//           title: Row(
//             children: [
//               Icon(
//                 Icons.sports_tennis,
//                 color: const Color(0xFF1A237E),
//                 size: 20,
//               ),
//               const SizedBox(width: 12),
//               Text(
//                 court,
//                 style: const TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.w600,
//                   color: Colors.black87,
//                 ),
//               ),
//               const Spacer(),
//             ],
//           ),
//           trailing: const Icon(
//             Icons.keyboard_arrow_down,
//             color: Color(0xFF1A237E),
//           ),
//           children: [
//             if (hourTypes.isNotEmpty)
//               Padding(
//                 padding: const EdgeInsets.all(16),
//                 child: Column(
//                   children: hourTypes.map((hourType) {
//                     final slots = _getSlotsForCourtAndHour(court, hourType);
//                     if (slots.isEmpty) return const SizedBox.shrink();
//
//                     return Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Container(
//                           padding: const EdgeInsets.symmetric(
//                             horizontal: 12,
//                             vertical: 6,
//                           ),
//                           decoration: BoxDecoration(
//                             color: hourType.toLowerCase().contains('happy')
//                                 ? Colors.orange.shade100
//                                 : const Color(0xFF1A237E).withOpacity(0.1),
//                             borderRadius: BorderRadius.circular(6),
//                           ),
//                           child: Text(
//                             hourType,
//                             style: TextStyle(
//                               fontSize: 14,
//                               fontWeight: FontWeight.w600,
//                               color: hourType.toLowerCase().contains('happy')
//                                   ? Colors.orange.shade700
//                                   : const Color(0xFF1A237E),
//                             ),
//                           ),
//                         ),
//                         const SizedBox(height: 12),
//                         Wrap(
//                           spacing: 8,
//                           runSpacing: 8,
//                           children: slots.map((slot) => _buildSlotChip(slot)).toList(),
//                         ),
//                         const SizedBox(height: 16),
//                       ],
//                     );
//                   }).toList(),
//                 ),
//               ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildSlotChip(Map<String, dynamic> slot) {
//     final isSelected = selectedSlots.any((s) =>
//     s['court'] == slot['court'] &&
//         s['hourType'] == slot['hourType'] &&
//         s['time'] == slot['time']);
//     final isSoldOut = (slot['price'] == 0);
//
//     return GestureDetector(
//       onTap: isSoldOut ? null : () => toggleSlot(slot),
//       child: AnimatedContainer(
//         duration: const Duration(milliseconds: 200),
//         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//         decoration: BoxDecoration(
//           color: isSelected
//               ? const Color(0xFF1A237E)
//               : (isSoldOut ? Colors.grey.shade300 : Colors.white),
//           borderRadius: BorderRadius.circular(8),
//           border: Border.all(
//             color: isSelected
//                 ? const Color(0xFF1A237E)
//                 : (isSoldOut ? Colors.grey.shade300 : Colors.grey.shade300),
//             width: isSelected ? 2 : 1,
//           ),
//           boxShadow: isSelected ? [
//             BoxShadow(
//               color: const Color(0xFF1A237E).withOpacity(0.3),
//               blurRadius: 8,
//               offset: const Offset(0, 2),
//             ),
//           ] : null,
//         ),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Row(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Icon(
//                   Icons.access_time,
//                   size: 14,
//                   color: isSelected
//                       ? Colors.white
//                       : (isSoldOut ? Colors.grey : Colors.grey.shade600),
//                 ),
//                 const SizedBox(width: 4),
//                 Text(
//                   slot['time'],
//                   style: TextStyle(
//                     color: isSelected
//                         ? Colors.white
//                         : (isSoldOut ? Colors.grey : Colors.black87),
//                     fontWeight: FontWeight.w600,
//                     fontSize: 14,
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 4),
//             Text(
//               isSoldOut ? "Sold Out" : "₹${slot['price']}",
//               style: TextStyle(
//                 color: isSelected
//                     ? Colors.white70
//                     : (isSoldOut ? Colors.grey : Colors.grey.shade600),
//                 fontSize: 12,
//                 fontWeight: FontWeight.w500,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildSelectedSlotsList() {
//     return Container(
//       margin: const EdgeInsets.symmetric(horizontal: 20),
//       padding: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         color: Colors.green.shade50,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: Colors.green.shade200),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.green.shade100,
//             blurRadius: 10,
//             offset: const Offset(0, 4),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Icon(
//                 Icons.check_circle,
//                 color: Colors.green.shade600,
//                 size: 20,
//               ),
//               const SizedBox(width: 8),
//               Text(
//                 "Selected Slots",
//                 style: TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.w600,
//                   color: Colors.green.shade700,
//                 ),
//               ),
//               const Spacer(),
//               Text(
//                 "${selectedSlots.length} slot${selectedSlots.length > 1 ? 's' : ''}",
//                 style: TextStyle(
//                   fontSize: 14,
//                   color: Colors.green.shade600,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 16),
//           Column(
//             children: selectedSlots.map((slot) => _buildSelectedSlotItem(slot)).toList(),
//           ),
//           const SizedBox(height: 16),
//           Container(
//             padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
//             decoration: BoxDecoration(
//               color: Colors.green.shade100,
//               borderRadius: BorderRadius.circular(8),
//             ),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Text(
//                   "Total Amount",
//                   style: TextStyle(
//                     fontSize: 16,
//                     fontWeight: FontWeight.w600,
//                     color: Colors.green.shade700,
//                   ),
//                 ),
//                 Text(
//                   "₹$totalPrice",
//                   style: TextStyle(
//                     fontSize: 18,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.green.shade700,
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
//   // Widget _buildSelectedSlotItem(Map<String, dynamic> slot) {
//   //   return Container(
//   //     margin: const EdgeInsets.only(bottom: 8),
//   //     padding: const EdgeInsets.all(12),
//   //     decoration: BoxDecoration(
//   //       color: Colors.white,
//   //       borderRadius: BorderRadius.circular(8),
//   //       border: Border.all(color: Colors.green.shade200),
//   //     ),
//   //     child: Row(
//   //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//   //       children: [
//   //         Expanded(
//   //           child: Column(
//   //             crossAxisAlignment: CrossAxisAlignment.start,
//   //             children: [
//   //               Text(
//   //                 slot['court'],
//   //                 style: const TextStyle(
//   //                   fontSize: 14,
//   //                   fontWeight: FontWeight.w600,
//   //                   color: Colors.black87,
//   //                 ),
//   //               ),
//   //               const SizedBox(height: 4),
//   //               Row(
//   //                 children: [
//   //                   Icon(
//   //                     Icons.access_time,
//   //                     size: 16,
//   //                     color: Colors.grey.shade600,
//   //                   ),
//   //                   const SizedBox(width: 4),
//   //                   Text(
//   //                     slot['time'],
//   //                     style: TextStyle(
//   //                       fontSize: 13,
//   //                       color: Colors.grey.shade600,
//   //                     ),
//   //                   ),
//   //                   const SizedBox(width: 16),
//   //                   Icon(
//   //                     Icons.category,
//   //                     size: 16,
//   //                     color: Colors.grey.shade600,
//   //                   ),
//   //                   const SizedBox(width: 4),
//   //                   Text(
//   //                     slot['hourType'],
//   //                     style: TextStyle(
//   //                       fontSize: 13,
//   //                       color: Colors.grey.shade600,
//   //                     ),
//   //                   ),
//   //                 ],
//   //               ),
//   //             ],
//   //           ),
//   //         ),
//   //         Text(
//   //           "₹${slot['price']}",
//   //           style: const TextStyle(
//   //             fontSize: 16,
//   //             fontWeight: FontWeight.w600,
//   //             color: Colors.black87,
//   //           ),
//   //         ),
//   //         const SizedBox(width: 12),
//   //         GestureDetector(
//   //           onTap: () => toggleSlot(slot),
//   //           child: Container(
//   //             padding: const EdgeInsets.all(6),
//   //             decoration: BoxDecoration(
//   //               color: Colors.red.shade100,
//   //               borderRadius: BorderRadius.circular(6),
//   //             ),
//   //             child: Icon(
//   //               Icons.close,
//   //               size: 16,
//   //               color: Colors.red.shade600,
//   //             ),
//   //           ),
//   //         ),
//   //       ],
//   //     ),
//   //   );
//   // }
//   Widget _buildSelectedSlotItem(Map<String, dynamic> slot) {
//     return Container(
//       margin: const EdgeInsets.only(bottom: 8),
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(color: Colors.green.shade200),
//       ),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         crossAxisAlignment: CrossAxisAlignment.center,
//         children: [
//           // Left side - details
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   slot['court'] ?? '',
//                   style: const TextStyle(
//                     fontSize: 14,
//                     fontWeight: FontWeight.w600,
//                     color: Colors.black87,
//                   ),
//                   overflow: TextOverflow.ellipsis,
//                 ),
//                 const SizedBox(height: 4),
//                 Row(
//                   children: [
//                     Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
//                     const SizedBox(width: 4),
//                     Flexible(
//                       child: Text(
//                         slot['time'] ?? '',
//                         style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                     ),
//                     const SizedBox(width: 16),
//                     Icon(Icons.category, size: 16, color: Colors.grey.shade600),
//                     const SizedBox(width: 4),
//                     Flexible(
//                       child: Text(
//                         slot['hourType'] ?? '',
//                         style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//
//           // Right side - Price + Close button
//           Row(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Text(
//                 "₹${slot['price'] ?? ''}",
//                 style: const TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.w600,
//                   color: Colors.black87,
//                 ),
//               ),
//               const SizedBox(width: 12),
//               GestureDetector(
//                 onTap: () => toggleSlot(slot),
//                 child: Container(
//                   padding: const EdgeInsets.all(6),
//                   decoration: BoxDecoration(
//                     color: Colors.red.shade100,
//                     borderRadius: BorderRadius.circular(6),
//                   ),
//                   child: Icon(Icons.close, size: 16, color: Colors.red.shade600),
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
//
//
//   Widget _buildBottomBar() {
//     return Container(
//       padding: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         boxShadow: [
//           BoxShadow(
//             color: Colors.grey.shade300,
//             blurRadius: 10,
//             offset: const Offset(0, -2),
//           ),
//         ],
//       ),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           SizedBox(
//             width: double.infinity,
//             child: ElevatedButton(
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: selectedSlots.isEmpty
//                     ? Colors.grey.shade400
//                     : const Color(0xFF1A237E),
//                 padding: const EdgeInsets.symmetric(vertical: 16),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 elevation: selectedSlots.isEmpty ? 0 : 2,
//               ),
//                 onPressed: selectedSlots.isEmpty
//                     ? null
//                     : () async {
//                   try {
//                     final loggedIn = await ApiService.isLoggedIn();
//                     if (loggedIn) {
//                       // Get user details for payment
//                       final userDetails = ApiService.currentUser;
//
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                           builder: (context) => PaymentScreen(
//                             bookingDetails: {
//                               "location": widget.location,
//                               "game": widget.game,
//                               "slots": selectedSlots,
//                               "price": totalPrice, // Changed from totalPrice to price
//                               "date": DateFormat('yyyy-MM-dd').format(_selectedDay),
//                               "phone": userDetails?['phone'] ?? '', // Add phone for Razorpay
//                               "cash": 0, // Initialize cash amount
//                             },
//                           ),
//                         ),
//                       );
//                     } else {
//                       // Show login dialog or navigate to login
//                       _showNotLoggedInPopup();
//                     }
//                   } catch (e) {
//                     ScaffoldMessenger.of(context).showSnackBar(
//                       SnackBar(
//                         content: Text("Error: $e"),
//                         backgroundColor: Colors.red,
//                         behavior: SnackBarBehavior.floating,
//                         margin: EdgeInsets.all(16),
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(8),
//                         ),
//                       ),
//                     );
//                   }
//                 },
//
//
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   if (selectedSlots.isNotEmpty) ...[
//                     Text(
//                       "₹$totalPrice • ",
//                       style: const TextStyle(
//                         fontSize: 16,
//                         fontWeight: FontWeight.bold,
//                         color: Colors.white,
//                       ),
//                     ),
//                   ],
//                   Text(
//                     selectedSlots.isEmpty
//                         ? "Select slots to proceed"
//                         : "Proceed to Payment",
//                     style: const TextStyle(
//                       fontSize: 16,
//                       fontWeight: FontWeight.w600,
//                       color: Colors.white,
//                     ),
//                   ),
//                   if (selectedSlots.isNotEmpty) ...[
//                     const SizedBox(width: 8),
//                     const Icon(
//                       Icons.arrow_forward,
//                       color: Colors.white,
//                       size: 20,
//                     ),
//                   ],
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   bool isSameDate(DateTime a, DateTime b) =>
//       a.year == b.year && a.month == b.month && a.day == b.day;
//
// // Add this helper method to your class
// //   void _showLoginRequiredDialog() {
// //     showDialog(
// //       context: context,
// //       builder: (context) => AlertDialog(
// //         shape: RoundedRectangleBorder(
// //           borderRadius: BorderRadius.circular(16),
// //         ),
// //         title: Row(
// //           children: [
// //             Icon(Icons.login, color: Colors.blue, size: 28),
// //             SizedBox(width: 12),
// //             Text(
// //               "Login Required",
// //               style: TextStyle(
// //                 fontSize: 18,
// //                 fontWeight: FontWeight.bold,
// //               ),
// //             ),
// //           ],
// //         ),
// //         content: Text(
// //           "Please log in to continue with your booking.",
// //           style: TextStyle(fontSize: 16),
// //         ),
// //         actions: [
// //           TextButton(
// //             onPressed: () => Navigator.pop(context),
// //             child: Text("Cancel"),
// //           ),
// //           ElevatedButton(
// //             onPressed: () {
// //               Navigator.pop(context);
// //               Navigator.push(
// //                 context,
// //                 MaterialPageRoute(
// //                   builder: (_) => const LoginScreen(),
// //                 ),
// //               );
// //             },
// //             style: ElevatedButton.styleFrom(
// //               backgroundColor: Colors.blue,
// //               foregroundColor: Colors.white,
// //               shape: RoundedRectangleBorder(
// //                 borderRadius: BorderRadius.circular(8),
// //               ),
// //             ),
// //             child: Text("Login"),
// //           ),
// //         ],
// //       ),
// //     );
// //   }
//   void _showNotLoggedInPopup() {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (_) => Dialog(
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//         child: Padding(
//           padding: const EdgeInsets.all(20),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               // Icon with background
//               Container(
//                 padding: const EdgeInsets.all(16),
//                 decoration: BoxDecoration(
//                   color: Colors.orange.withOpacity(0.15),
//                   shape: BoxShape.circle,
//                 ),
//                 child: const Icon(Icons.lock_outline,
//                     size: 48, color: Colors.orange),
//               ),
//               const SizedBox(height: 20),
//
//               // Title
//               const Text(
//                 "Login Required",
//                 style: TextStyle(
//                   fontSize: 20,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//
//               const SizedBox(height: 10),
//
//               // Description
//               const Text(
//                 "You need to log in to continue.\nRedirecting you shortly...",
//                 textAlign: TextAlign.center,
//                 style: TextStyle(fontSize: 14, color: Colors.black87),
//               ),
//
//               const SizedBox(height: 24),
//
//               // Loading Indicator
//               const CircularProgressIndicator(
//                 strokeWidth: 2,
//                 valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
//               ),
//
//               const SizedBox(height: 12),
//
//               const Text(
//                 "Please wait...",
//                 style: TextStyle(fontSize: 12, color: Colors.grey),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//
//     // Auto-redirect after delay
//     Future.delayed(const Duration(seconds: 2), () {
//       if (!mounted) return;
//       Navigator.pop(context); // Close popup
//       Navigator.pushAndRemoveUntil(
//         context,
//         MaterialPageRoute(builder: (context) => const LoginScreen()),
//             (route) => false,
//       );
//     });
//   }
//
//   // void _showNotLoggedInPopup() {
//   //   showDialog(
//   //     context: context,
//   //     barrierDismissible: false,
//   //     builder: (_) => AlertDialog(
//   //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//   //       title: const Text("Not Logged In"),
//   //       content: Column(
//   //         mainAxisSize: MainAxisSize.min,
//   //         children: const [
//   //           Icon(Icons.warning_amber_rounded, size: 50, color: Colors.orange),
//   //           SizedBox(height: 16),
//   //           Text(
//   //             "You are not logged in.\nRedirecting to Login Screen...",
//   //             textAlign: TextAlign.center,
//   //           ),
//   //         ],
//   //       ),
//   //     ),
//   //   );
//   //
//   //   Future.delayed(const Duration(seconds: 3), () {
//   //     if (!mounted) return;
//   //     Navigator.pop(context);  // Close the popup
//   //     Navigator.pushAndRemoveUntil(
//   //       context,
//   //       MaterialPageRoute(builder: (context) => LoginScreen()),
//   //           (route) => false,
//   //     );
//   //   });
//   // }
//
// }
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////





































































































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
//   bool isLoading = false;
//   String? error;
//
//   List<Map<String, dynamic>> courts = [];
// //   String? selectedHourType;
//
//   List<Map<String, dynamic>> selectedSlots = [];
//   int totalPrice = 0;
//
//   @override
//   void initState() {
//     super.initState();
//     fetchCourtsWisePrice();
//   }
//
//   // ---------------------- Day matcher ----------------------
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
//     if (dayMap.containsKey(dayKey)) {
//       return dayMap[dayKey] == selectedDayName;
//     }
//
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
//         final start = dayMap[parts[0]] ?? parts[0];
//         final end = dayMap[parts[1]] ?? parts[1];
//
//         final startIndex = daysOrder.indexOf(start);
//         final endIndex = daysOrder.indexOf(end);
//
//         if (startIndex != -1 && endIndex != -1) {
//           if (startIndex <= endIndex) {
//             return daysOrder.sublist(startIndex, endIndex + 1).contains(selectedDayName);
//           } else {
//             return (daysOrder.sublist(startIndex) + daysOrder.sublist(0, endIndex + 1))
//                 .contains(selectedDayName);
//           }
//         }
//       }
//     }
//
//     if (dayKey.contains('all') || dayKey.contains('every')) return true;
//     return dayKey == selectedDayName;
//   }
//
//   // ---------------------- API fetch ----------------------
//   Future<void> fetchCourtsWisePrice() async {
//     setState(() {
//       isLoading = true;
//       error = null;
//     });
//
//     final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDay);
//     final selectedDayName = DateFormat('EEEE').format(_selectedDay);
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
//           final List<Map<String, dynamic>> parsedSlots = [];
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
//                 });
//               }
//             });
//           });
//
//           final currentSelected = selectedSlots.where((sel) {
//             return parsedSlots.any((p) =>
//             p['court'] == sel['court'] &&
//                 p['hourType'] == sel['hourType'] &&
//                 p['time'] == sel['time']);
//           }).toList();
//
//           setState(() {
//             courts = parsedSlots;
//             selectedSlots = currentSelected;
//             totalPrice = selectedSlots.fold(0, (sum, s) => sum + (s['price'] as int));
//
//             final courtNames = _getCourtNames();
//             if (courtNames.isNotEmpty &&
//                 (selectedCourt == null || !courtNames.contains(selectedCourt))) {
//               selectedCourt = courtNames.first;
//             }
//             final hourTypes = _getHourTypesForCourt(selectedCourt);
//             if (hourTypes.isNotEmpty &&
//                 (selectedHourType == null ||
//                     !hourTypes.contains(selectedHourType))) {
//               selectedHourType = hourTypes.first;
//             }
//           });
//         } else {
//           setState(() {
//             courts = [];
//             selectedSlots.clear();
//             totalPrice = 0;
//             error = responseData["message"]?.toString() ?? "No data";
//           });
//         }
//       } else {
//         setState(() => error = "Server error ${response.statusCode}");
//       }
//     } catch (e) {
//       setState(() => error = "Error: $e");
//     } finally {
//       setState(() => isLoading = false);
//     }
//   }
//
//   // ---------------------- Helpers ----------------------
// //
// //
// //
//   void toggleSlot(Map<String, dynamic> slot) {
//     setState(() {
//       final exists = selectedSlots.any((s) =>
//       s['court'] == slot['court'] &&
//           s['hourType'] == slot['hourType'] &&
//           s['time'] == slot['time']);
//       if (exists) {
//         selectedSlots.removeWhere((s) =>
//         s['court'] == slot['court'] &&
//             s['hourType'] == slot['hourType'] &&
//             s['time'] == slot['time']);
//       } else {
//         selectedSlots.add(slot);
//       }
//       totalPrice = selectedSlots.fold(0, (sum, s) => sum + (s['price'] as int));
//     });
//   }
//
//   // ---------------------- UI ----------------------
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFF2F4F7),
//       body: SafeArea(
//         child: Column(
//           children: [
//             _buildTopBar(),
//             Expanded(child: _buildBody()),
//             _buildProceedBar(),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildTopBar() {
//     return Container(
//       color: Colors.white,
//       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
//       child: Row(
//         children: [
//           IconButton(
//             icon: const Icon(Icons.arrow_back),
//             onPressed: () => Navigator.pop(context),
//           ),
//           Expanded(
//             child: Text(widget.game,
//                 style: const TextStyle(
//                     fontSize: 16, fontWeight: FontWeight.w700)),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildBody() {
//     if (isLoading) {
//       return const Center(
//           child: CircularProgressIndicator(color: Color(0xFF0A198D)));
//     }
//     if (error != null) {
//       return Center(
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Text(error!, style: const TextStyle(color: Colors.red)),
//             const SizedBox(height: 12),
//             ElevatedButton(
//                 onPressed: fetchCourtsWisePrice, child: const Text("Retry")),
//           ],
//         ),
//       );
//     }
//
//     return SingleChildScrollView(
//       padding: const EdgeInsets.only(bottom: 12),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           _buildDateCard(),
//           const SizedBox(height: 8),
//           _buildCourtTabs(),
//           const SizedBox(height: 8),
//           if (selectedCourt != null) _buildHourTypeChips(),
//           if (selectedCourt != null && selectedHourType != null) ...[
//             const SizedBox(height: 8),
//             _buildSlotsArea(),
//             if (selectedSlots.isNotEmpty) const SizedBox(height: 12),
//             if (selectedSlots.isNotEmpty) _buildSelectedStrip(),
//           ],
//         ],
//       ),
//     );
//   }
//
//   Widget _buildDateCard() {
//     final firstDayOfMonth =
//     DateTime(_selectedDay.year, _selectedDay.month, 1);
//     final lastDayOfMonth =
//     DateTime(_selectedDay.year, _selectedDay.month + 1, 0);
//     final daysInMonth = lastDayOfMonth.day;
//
//     final days = List<DateTime>.generate(
//         daysInMonth, (i) => firstDayOfMonth.add(Duration(days: i)));
//
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 12),
//       child: Card(
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//         elevation: 2,
//         child: Padding(
//           padding: const EdgeInsets.all(14),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const Text("Select Date",
//                   style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
//               const SizedBox(height: 12),
//               SizedBox(
//                 height: 60,
//                 child: ListView.separated(
//                   scrollDirection: Axis.horizontal,
//                   itemBuilder: (context, i) {
//                     final d = days[i];
//                     final isSelected = isSameDate(d, _selectedDay);
//                     final label = DateFormat('EEE dd').format(d);
//                     return GestureDetector(
//                       onTap: () {
//                         setState(() => _selectedDay = d);
//                         fetchCourtsWisePrice();
//                       },
//                       child: AnimatedContainer(
//                         duration: const Duration(milliseconds: 250),
//                         width: 80,
//                         margin: const EdgeInsets.symmetric(vertical: 2),
//                         decoration: BoxDecoration(
//                           color: isSelected
//                               ? Colors.green.shade400
//                               : Colors.white,
//                           borderRadius: BorderRadius.circular(12),
//                           border: Border.all(
//                               color: isSelected
//                                   ? Colors.green.shade400
//                                   : Colors.green.shade200),
//                         ),
//                         alignment: Alignment.center,
//                         child: Text(label,
//                             textAlign: TextAlign.center,
//                             style: TextStyle(
//                                 color:
//                                 isSelected ? Colors.white : Colors.black87,
//                                 fontWeight: FontWeight.w600)),
//                       ),
//                     );
//                   },
//                   separatorBuilder: (_, __) => const SizedBox(width: 12),
//                   itemCount: days.length,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildCourtTabs() {
//     final courtNames = _getCourtNames();
//     if (courtNames.isEmpty) {
//       return const Padding(
//         padding: EdgeInsets.all(16),
//         child: Text("No courts available for this date."),
//       );
//     }
//
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 12),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text("Select Court",
//               style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
//           const SizedBox(height: 12),
//           SizedBox(
//             height: 60,
//             child: ListView.separated(
//               scrollDirection: Axis.horizontal,
//               itemCount: courtNames.length,
//               separatorBuilder: (_, __) => const SizedBox(width: 12),
//               itemBuilder: (context, i) {
//                 final court = courtNames[i];
//                 final isSelected = court == selectedCourt;
//
//                 return GestureDetector(
//                   onTap: () {
//                     setState(() {
//                       selectedCourt = court;
//                       final hours = _getHourTypesForCourt(selectedCourt);
//                       selectedHourType = hours.isNotEmpty ? hours.first : null;
//                     });
//                   },
//                   child: AnimatedContainer(
//                     duration: const Duration(milliseconds: 250),
//                     width: 80,
//                     alignment: Alignment.center,
//                     decoration: BoxDecoration(
//                       color:
//                       isSelected ? Colors.green.shade400 : Colors.white,
//                       borderRadius: BorderRadius.circular(12),
//                       border: Border.all(
//                         color: isSelected
//                             ? Colors.green.shade400
//                             : Colors.green.shade200,
//                       ),
//                     ),
//                     child: Text(
//                       court,
//                       textAlign: TextAlign.center,
//                       style: TextStyle(
//                         color: isSelected ? Colors.white : Colors.black87,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                   ),
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildHourTypeChips() {
//     final hourTypes = _getHourTypesForCourt(selectedCourt);
//     if (hourTypes.isEmpty) return const SizedBox.shrink();
//
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 12),
//       child: Wrap(
//         spacing: 8,
//         children: hourTypes.map((hour) {
//           final isSelected = hour == selectedHourType;
//           final isHappy = hour.toLowerCase().contains("happy");
//           return ChoiceChip(
//             label: Text(hour,
//                 style: TextStyle(
//                     fontWeight: FontWeight.w700,
//                     color: isSelected ? Colors.white : Colors.black87)),
//             selected: isSelected,
//             onSelected: (_) {
//               setState(() => selectedHourType = hour);
//             },
//             selectedColor:
//             isHappy ? Colors.orange.shade600 : Colors.green.shade600,
//             backgroundColor: Colors.grey.shade200,
//           );
//         }).toList(),
//       ),
//     );
//   }
//
//   Widget _buildSlotsArea() {
//     final slots = _getSlotsForCourtAndHour(selectedCourt, selectedHourType);
//     if (slots.isEmpty) {
//       return const Padding(
//         padding: EdgeInsets.all(16),
//         child: Text("No slots available for this selection."),
//       );
//     }
//
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//       child: Wrap(
//         spacing: 12,
//         runSpacing: 12,
//         children: slots.map((slot) {
//           final isSelected = selectedSlots.any((s) =>
//           s['court'] == slot['court'] &&
//               s['hourType'] == slot['hourType'] &&
//               s['time'] == slot['time']);
//           final isSoldOut = (slot['price'] == 0);
//
//           Color bg;
//           Color textCol;
//           if (isSoldOut) {
//             bg = Colors.grey.shade300;
//             textCol = Colors.black45;
//           } else if (isSelected) {
//             bg = Colors.green.shade400;
//             textCol = Colors.white;
//           } else {
//             bg = Colors.white;
//             textCol = Colors.black87;
//           }
//
//           return GestureDetector(
//             onTap: isSoldOut ? null : () => toggleSlot(slot),
//             child: Container(
//               width: 120,
//               padding:
//               const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
//               decoration: BoxDecoration(
//                 color: bg,
//                 borderRadius: BorderRadius.circular(12),
//                 border: Border.all(
//                     color: isSelected
//                         ? Colors.green.shade600
//                         : Colors.grey.shade300,
//                     width: isSelected ? 1.6 : 1),
//               ),
//               child: Column(
//                 children: [
//                   Text(slot['time'],
//                       style: TextStyle(
//                           fontWeight: FontWeight.w800, color: textCol)),
//                   const SizedBox(height: 6),
//                   Text("₹${slot['price']}",
//                       style: TextStyle(
//                           fontSize: 12, color: textCol.withOpacity(0.9))),
//                 ],
//               ),
//             ),
//           );
//         }).toList(),
//       ),
//     );
//   }
//
//   Widget _buildSelectedStrip() {
//     return Column(
//       children: [
//         const Divider(height: 18),
//         Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 12),
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               const Text("Selected",
//                   style: TextStyle(fontWeight: FontWeight.w700)),
//               Text(
//                   "${selectedSlots.length} ${selectedSlots.length > 1 ? "slots" : "slot"}",
//                   style: const TextStyle(color: Colors.black54)),
//             ],
//           ),
//         ),
//         const SizedBox(height: 8),
//         SizedBox(
//           height: 46,
//           child: ListView.separated(
//             padding: const EdgeInsets.symmetric(horizontal: 12),
//             scrollDirection: Axis.horizontal,
//             itemBuilder: (context, i) {
//               final s = selectedSlots[i];
//               return InputChip(
//                 label: Text(
//                     "${s['court']} • ${s['time']} • ₹${s['price']}",
//                     style: const TextStyle(fontSize: 13)),
//                 onDeleted: () => toggleSlot(s),
//                 deleteIcon: const Icon(Icons.close, size: 18),
//                 backgroundColor: Colors.green.shade50,
//               );
//             },
//             separatorBuilder: (_, __) => const SizedBox(width: 8),
//             itemCount: selectedSlots.length,
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildProceedBar() {
//     return Container(
//       padding: const EdgeInsets.all(14),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         border: Border(top: BorderSide(color: Colors.grey.shade300)),
//         boxShadow: [
//           BoxShadow(
//               blurRadius: 6,
//               color: Colors.black.withOpacity(0.05),
//               offset: const Offset(0, -2))
//         ],
//       ),
//       child: Row(
//         children: [
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 const Text("Total",
//                     style: TextStyle(fontSize: 13, color: Colors.black54)),
//                 Text("₹$totalPrice",
//                     style: const TextStyle(
//                         fontSize: 18, fontWeight: FontWeight.w700)),
//               ],
//             ),
//           ),
//           ElevatedButton(
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.green.shade600,
//               shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(12)),
//               padding:
//               const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
//             ),
//             onPressed: selectedSlots.isEmpty
//                 ? null
//                 : () async {
//               final loggedIn = await ApiService.isLoggedIn();
//               if (loggedIn) {
//                 Navigator.pushNamed(context, "/payment", arguments: {
//                   "location": widget.location,
//                   "game": widget.game,
//                   "slots": selectedSlots,
//                   "totalPrice": totalPrice,
//                   "date": DateFormat('yyyy-MM-dd').format(_selectedDay),
//                 });
//               } else {
//                 Navigator.push(
//                     context,
//                     MaterialPageRoute(
//                         builder: (_) => const LoginScreen()));
//               }
//             },
//             child: const Text("Proceed",
//                 style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
//           ),
//         ],
//       ),
//     );
//   }
//
//   bool isSameDate(DateTime a, DateTime b) =>
//       a.year == b.year && a.month == b.month && a.day == b.day;
// }



/// One row of the Venue sheet: what `/sports-complexes` returned, reduced to
/// what the picker and the card header need.
class _VenueOption {
  final int? id;
  final String name;
  final String address;

  const _VenueOption({
    required this.id,
    required this.name,
    required this.address,
  });
}

class SlotBookingScreen extends StatefulWidget {
  final String location;
  final String game;
  // 🔄 NEW API: numeric ids resolved upstream (optional; resolved by name if null)
  final int? sportId;
  final int? sportComplexId;

  const SlotBookingScreen({
    super.key,
    required this.location,
    required this.game,
    this.sportId,
    this.sportComplexId,
  });

  @override
  State<SlotBookingScreen> createState() => _SlotBookingScreenState();
}

class _SlotBookingScreenState extends State<SlotBookingScreen> {
  static const brandBlue = Color(0xFF1A237E);

  // ── Palette ───────────────────────────────────────────────────────────────
  static const _navy = Color(0xFF1E1B4B);
  static const _indigo = Color(0xFF4F46E5);
  static const _indigoDeep = Color(0xFF312E81);
  static const _pageBg = Color(0xFFF7F8FC);
  static const _fieldBg = Color(0xFFFCFCFE);
  static const _line = Color(0xFFEDEFF5);
  static const _border = Color(0xFFE4E7F0);
  static const _muted = Color(0xFF6B7280);

  /// Street address of the venue, from `/sports-complexes`. Null until it
  /// resolves — the card simply omits the line rather than showing a gap.
  String? _venueAddress;

  /// The venue and sport being booked. They start as whatever the caller
  /// passed, but the Venue and Sport rows change them here on this screen, so
  /// re-picking either never throws the user back to the sport list.
  late String _venue;
  late String _sport;

  /// Every venue `/sports-complexes` offers, backing the Venue sheet.
  List<_VenueOption> _venues = const [];

  /// The in-flight loads. The venue list is shared by the header address and
  /// the id resolution rather than fetched once each; the sport list is
  /// dropped and refetched whenever the venue changes.
  Future<void>? _venuesLoad;
  Future<List<Sport>>? _sportsLoad;

  /// The start time the user picked, and how many consecutive slots follow it.
  /// Together these are the booking: [_runSlots] turns them back into the slot
  /// maps the payment screen already expects.
  TimeSlot? _startSlot;
  int _durationSlots = 1;

  bool _offersExpanded = true;

  // ── Coupons ───────────────────────────────────────────────────────────────
  // The code is only previewed here through `/coupons/validate`; it travels to
  // the payment screen, which sends it with the booking so the backend applies
  // the discount itself. Nothing computed on this screen can lower the bill.
  final TextEditingController _couponController = TextEditingController();
  List<CouponModel> _coupons = const [];
  bool _loadingCoupons = true;
  CouponModel? _appliedCoupon;
  CouponValidation? _validation;
  bool _applyingCoupon = false;
  int _couponRequest = 0;
  String? _couponError;

  /// Every start time offered today, cheapest free court per time.
  ///
  /// [mergeSlotsByTime] works one hour type at a time because the old screen
  /// had a tab per type; this screen has no such tab, so the types are merged
  /// back together and re-sorted. Each slot keeps its own price, so a peak
  /// hour still costs what it costs.
  List<TimeSlot> get _allTimes {
    final merged = <TimeSlot>[];
    for (final type in _getHourTypes()) {
      merged.addAll(mergeSlotsByTime(courts, type));
    }
    merged.sort((a, b) => (a.slot['startTime'] ?? a.slot['time'])
        .toString()
        .compareTo((b.slot['startTime'] ?? b.slot['time']).toString()));
    return merged;
  }

  /// Bookable start times — a sold-out hour cannot begin a booking.
  List<TimeSlot> get _openTimes =>
      _allTimes.where((t) => !t.isSoldOut).toList(growable: false);

  /// The run of consecutive slots the booking covers.
  ///
  /// Walks forward from [_startSlot] and stops early at a sold-out hour or a
  /// gap in the timetable, so the duration stepper can never produce a booking
  /// that spans an hour someone else already has.
  List<TimeSlot> get _runSlots {
    final start = _startSlot;
    if (start == null) return const <TimeSlot>[];

    final all = _allTimes;
    final index = all.indexWhere(
      (t) => t.slot['startTime'] == start.slot['startTime'],
    );
    if (index < 0) return const <TimeSlot>[];

    final run = <TimeSlot>[all[index]];
    for (var i = index + 1; i < all.length && run.length < _durationSlots; i++) {
      final previousEnd = run.last.slot['endTime'].toString();
      final nextStart = all[i].slot['startTime'].toString();
      if (all[i].isSoldOut || nextStart != previousEnd) break;
      run.add(all[i]);
    }
    return run;
  }

  /// How many more consecutive hours are actually free after the current run.
  bool get _canExtend {
    final all = _allTimes;
    final run = _runSlots;
    if (run.isEmpty) return false;

    final index = all.indexWhere(
      (t) => t.slot['startTime'] == run.last.slot['startTime'],
    );
    if (index < 0 || index + 1 >= all.length) return false;

    final next = all[index + 1];
    return !next.isSoldOut &&
        next.slot['startTime'].toString() ==
            run.last.slot['endTime'].toString();
  }

  /// Price of the run before any discount.
  int get _baseTotal =>
      _runSlots.fold(0, (sum, t) => sum + (t.slot['price'] as int));

  /// What the coupon takes off, as the server priced it. Display only.
  int get _discount =>
      (_validation?.discountAmount ?? 0).round().clamp(0, _baseTotal);

  int get _payable => (_baseTotal - _discount).clamp(0, _baseTotal);

  /// Nothing to charge — a free court, or a coupon that covered it. The
  /// gateway is skipped entirely for these.
  bool get _isFree => _runSlots.isNotEmpty && _payable <= 0;

  /// `"1 Hr"` / `"2 Hrs"`, from the run's own clock times rather than an
  /// assumed slot length.
  String get _durationLabel {
    final run = _runSlots;
    if (run.isEmpty) return '—';
    return run.length == 1 ? '1 Hr' : '${run.length} Hrs';
  }

  /// `"7:00 AM–8:00 AM"` across the whole run.
  String get _runLabel {
    final run = _runSlots;
    if (run.isEmpty) return '';
    return '${_fmtTime(run.first.slot['startTime'].toString())}'
        '–${_fmtTime(run.last.slot['endTime'].toString())}';
  }

  // 🔄 NEW API base + resolved ids
  static const String _apiBase = "https://api.nahatasports.com/api";
  int? _sportComplexId;
  int? _sportId;

  DateTime _selectedDay = DateTime.now();  //
  bool isLoading = false;
  String? error;



  List<Map<String, dynamic>> courts = [];
  String? selectedHourType;

  List<Map<String, dynamic>> selectedSlots = [];
  int totalPrice = 0;

  // For horizontal calendar
  late ScrollController _dateScrollController;
  List<DateTime> _dateList = [];

  // For hour type tabs
  String? selectedHourTypeTab;

  @override
  void initState() {
    super.initState();
    _venue = widget.location;
    _sport = widget.game;
    // Seeded from the caller so the first fetch skips the name lookups; both
    // are re-resolved from scratch whenever a picker changes the selection.
    _sportComplexId = widget.sportComplexId;
    _sportId = widget.sportId;
    _dateScrollController = ScrollController();
    _generateDateList();
    fetchCourtsWisePrice();
    _loadVenues();
  }

  @override
  void dispose() {
    _dateScrollController.dispose();
    _couponController.dispose();
    super.dispose();
  }

  /// Offers for court bookings at this venue and sport.
  ///
  /// The ids matter: the server matches a coupon's scope as "unscoped **or**
  /// equal to this", so a coupon issued for this venue only comes back when
  /// the request names it. A failure here just means no offers strip.
  Future<void> _loadCoupons() async {
    final coupons = await CouponRepository.instance.fetchActiveCoupons(
      appliesTo: 'Court',
      sportComplexId: _sportComplexId,
      sportId: _sportId,
    );
    if (!mounted) return;
    setState(() {
      _coupons = coupons;
      _loadingCoupons = false;
    });
  }

  /// `POST /coupons/validate` — the server decides whether the code applies to
  /// this booking and how much comes off. Preview only; the payment screen
  /// sends the code again and the backend re-checks it there.
  Future<void> _applyCouponCode(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) {
      setState(() => _couponError = 'Enter a coupon code');
      return;
    }
    if (_runSlots.isEmpty) {
      setState(() => _couponError = 'Pick a start time first');
      return;
    }

    // Only the newest reply may write back.
    final request = ++_couponRequest;
    setState(() {
      _applyingCoupon = true;
      _couponError = null;
    });

    final result = await CouponRepository.instance.validateCoupon(
      code: trimmed,
      amount: _baseTotal,
      appliesTo: 'Court',
      sportComplexId: _sportComplexId,
      sportId: _sportId,
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
    _couponRequest++; // discard any validation still in flight
    setState(() {
      _appliedCoupon = null;
      _validation = null;
      _applyingCoupon = false;
      _couponError = null;
      _couponController.clear();
    });
  }

  /// Re-prices an applied coupon after the amount changes — a longer booking
  /// may clear a minimum the shorter one did not, and vice versa.
  void _revalidateCoupon() {
    final code = _appliedCoupon?.code;
    if (code == null || code.isEmpty) return;
    _applyCouponCode(code);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Venue and sport — the two things this screen can re-pick in place
  // ═══════════════════════════════════════════════════════════════════════

  /// The venue list, fetched once and shared.
  ///
  /// It backs the Venue sheet, the header address and the id resolution, so
  /// opening the screen makes one request rather than three.
  Future<void> _loadVenues() => _venuesLoad ??= _fetchVenues();

  Future<void> _fetchVenues() async {
    try {
      final res = await http.get(
        Uri.parse(
          '$_apiBase/sports-complexes?status=Active&showOnFrontend=true&limit=50',
        ),
        headers: {'Accept': 'application/json'},
      );
      if (res.statusCode != 200) return;

      final List complexes =
          jsonDecode(res.body)['data']?['sportsComplexes'] ?? [];

      final options = <_VenueOption>[];
      for (final c in complexes) {
        final name = (c['name'] ?? '').toString().trim();
        if (name.isEmpty) continue;

        final parts = <String>[
          if ((c['address'] ?? '').toString().trim().isNotEmpty)
            c['address'].toString().trim(),
          if ((c['city'] ?? '').toString().trim().isNotEmpty)
            c['city'].toString().trim(),
        ];

        options.add(_VenueOption(
          id: c['id'] is int ? c['id'] as int : int.tryParse('${c['id']}'),
          name: name,
          address: parts.join(', '),
        ));
      }

      if (!mounted) return;
      setState(() {
        _venues = options;
        _venueAddress ??= _addressForCurrentVenue();
      });
    } catch (e) {
      AppLogger.debug('Could not load venues: $e', name: 'slotbook');
      _venuesLoad = null; // the picker can try again on the next open
    }
  }

  /// The current venue's street address, by id when one is known and by name
  /// otherwise. Null while the list is still loading or when the venue has no
  /// address on file — the header then simply omits the line.
  String? _addressForCurrentVenue() {
    for (final v in _venues) {
      final matches = _sportComplexId != null
          ? v.id == _sportComplexId
          : v.name.toLowerCase() == _venue.toLowerCase().trim();
      if (matches) return v.address.isEmpty ? null : v.address;
    }
    return null;
  }

  /// The sports the current venue runs, from its courts. Dropped and refetched
  /// whenever the venue changes.
  Future<List<Sport>> _loadSports() =>
      _sportsLoad ??= Api_loc_Service.fetchSportsByLocation(_venue)
          .catchError((Object e) {
        _sportsLoad = null; // let the next open retry
        throw e;
      });

  /// Clears everything the previous venue/sport decided, so a stale start time
  /// or a coupon scoped to the old venue cannot survive the switch.
  void _resetSelectionForNewScope() {
    _startSlot = null;
    _durationSlots = 1;
    courts = [];
    selectedSlots = [];
    totalPrice = 0;
    _couponRequest++; // discard any validation still in flight
    _appliedCoupon = null;
    _validation = null;
    _applyingCoupon = false;
    _couponError = null;
    _couponController.clear();
    _coupons = const [];
    _loadingCoupons = true; // fetchCourtsWisePrice re-asks once the ids resolve
  }

  /// The Venue sheet. The venue changes right here: the ids are re-resolved,
  /// the sport is re-checked against the new venue, and the day reloads.
  Future<void> _pickVenue() async {
    final chosen = await _showPickerSheet<_VenueOption>(
      title: 'VENUE',
      options: _loadVenues().then((_) => _venues),
      labelOf: (v) => v.name,
      subtitleOf: (v) => v.address.isEmpty ? null : v.address,
      isSelected: (v) => v.name.toLowerCase() == _venue.toLowerCase().trim(),
      emptyLabel: 'No venues available right now',
    );
    if (chosen == null || !mounted) return;
    if (chosen.name.toLowerCase() == _venue.toLowerCase().trim()) return;

    setState(() {
      _venue = chosen.name;
      _venueAddress = chosen.address.isEmpty ? null : chosen.address;
      _sportComplexId = chosen.id;
      _sportId = null; // the old id belongs to the old venue's courts
      _sportsLoad = null;
      _resetSelectionForNewScope();
    });

    await _syncSportToVenue();
    if (!mounted) return;
    await fetchCourtsWisePrice();
  }

  /// The Sport sheet, listing what the current venue actually offers.
  Future<void> _pickSport() async {
    final chosen = await _showPickerSheet<Sport>(
      title: 'SPORT',
      options: _loadSports(),
      labelOf: (s) => s.name,
      isSelected: (s) =>
          s.name.toLowerCase().trim() == _sport.toLowerCase().trim(),
      emptyLabel: 'No sports listed at this venue',
    );
    if (chosen == null || !mounted) return;
    if (chosen.name.toLowerCase().trim() == _sport.toLowerCase().trim()) return;

    setState(() {
      _sport = chosen.name;
      _sportId = chosen.id;
      _resetSelectionForNewScope();
    });
    await fetchCourtsWisePrice();
  }

  /// Keeps the sport valid after a venue change: a venue that does not run it
  /// falls back to the first sport it does run, rather than loading a day with
  /// no courts in it and looking broken.
  Future<void> _syncSportToVenue() async {
    List<Sport> sports;
    try {
      sports = await _loadSports();
    } catch (e) {
      AppLogger.debug('Could not load sports for $_venue: $e', name: 'slotbook');
      return;
    }
    if (!mounted || sports.isEmpty) return;

    final wanted = _sport.toLowerCase().trim();
    final match = sports.where((s) => s.name.toLowerCase().trim() == wanted);

    if (match.isNotEmpty) {
      setState(() => _sportId = match.first.id);
      return;
    }

    final fallback = sports.first;
    final previous = _sport;
    setState(() {
      _sport = fallback.name;
      _sportId = fallback.id;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$previous is not offered at $_venue — showing ${fallback.name}',
        ),
      ),
    );
  }

  /// The start-time sheet's chrome, reused for the venue and sport lists.
  ///
  /// The rows come from a future so a list still being fetched shows a spinner
  /// inside the sheet instead of holding the sheet closed while it loads.
  Future<T?> _showPickerSheet<T>({
    required String title,
    required Future<List<T>> options,
    required String Function(T) labelOf,
    required bool Function(T) isSelected,
    String? Function(T)? subtitleOf,
    String emptyLabel = 'Nothing to choose from',
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E2EC),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: _navy,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ),
              const Divider(height: 1, color: _line),
              Expanded(
                child: FutureBuilder<List<T>>(
                  future: options,
                  builder: (_, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(
                        child: SizedBox(
                          height: 26,
                          width: 26,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.4, color: _indigo),
                        ),
                      );
                    }

                    final items = snapshot.data ?? const [];
                    if (snapshot.hasError || items.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            snapshot.hasError
                                ? 'Could not load the list. Try again.'
                                : emptyLabel,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      controller: controller,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: items.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: _line, indent: 20),
                      itemBuilder: (_, i) {
                        final item = items[i];
                        final selected = isSelected(item);
                        final subtitle = subtitleOf?.call(item);
                        return ListTile(
                          title: Text(
                            labelOf(item),
                            style: TextStyle(
                              color: _navy,
                              fontSize: 15,
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                          subtitle: subtitle == null
                              ? null
                              : Text(
                                  subtitle,
                                  style: const TextStyle(
                                      fontSize: 12, color: _muted),
                                ),
                          trailing: selected
                              ? const Icon(Icons.check_circle,
                                  color: _indigo, size: 20)
                              : null,
                          onTap: () => Navigator.pop(sheetContext, item),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Picks the first bookable time once the day's slots arrive, so the screen
  /// opens on a usable booking rather than empty fields.
  void _seedSelection() {
    final open = _openTimes;
    if (open.isEmpty) {
      _startSlot = null;
      _durationSlots = 1;
      return;
    }

    final current = _startSlot;
    final stillOpen = current != null &&
        open.any((t) => t.slot['startTime'] == current.slot['startTime']);

    if (!stillOpen) {
      _startSlot = open.first;
      _durationSlots = 1;
    }
  }

  void _generateDateList() {
    _dateList = List.generate(
      60,
          (index) => DateTime.now().add(Duration(days: index)),
    );
  }
  String normalizeTime(String time) {
    return time
        .toLowerCase()
        .replaceAll(' to ', ' to ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  // ---------------------- Day matcher ----------------------
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

    if (dayMap.containsKey(dayKey)) {
      return dayMap[dayKey] == selectedDayName;
    }

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
        final start = dayMap[parts[0]] ?? parts[0];
        final end = dayMap[parts[1]] ?? parts[1];

        final startIndex = daysOrder.indexOf(start);
        final endIndex = daysOrder.indexOf(end);

        if (startIndex != -1 && endIndex != -1) {
          if (startIndex <= endIndex) {
            return daysOrder.sublist(startIndex, endIndex + 1).contains(selectedDayName);
          } else {
            return (daysOrder.sublist(startIndex) + daysOrder.sublist(0, endIndex + 1))
                .contains(selectedDayName);
          }
        }
      }
    }

    if (dayKey.contains('all') || dayKey.contains('every')) return true;
    return dayKey == selectedDayName;
  }

  // ---------------------- OLD API: per-court availability (commented out) ----------------------
  // Replaced by GET /courts/{courtId}/available-slots?date=... in the new API.
  // Future<Map<String, bool>> fetchSlotAvailability({
  //   required String date,
  //   required String court,
  // }) async {
  //   final url = Uri.parse("https://nahatasports.com/booking_new");
  //
  //   final response = await http.post(
  //     url,
  //     headers: {"Content-Type": "application/json"},
  //     body: jsonEncode({
  //       "date": date,
  //       "court": court,
  //     }),
  //   );
  // print("🚀 fetchSlotAvailability()");
  // print(response);
  //   print("📅 Fetching availability for $court");
  //   if (response.statusCode != 200) {
  //     throw Exception("Failed to fetch availability");
  //   }
  //
  //   final decoded = jsonDecode(response.body);
  //
  //   final Map<String, bool> availabilityMap = {};
  //
  //   final monthKey = date.substring(0, 7); // yyyy-MM
  //   final slots =
  //   decoded['data']?[monthKey]?[date]?[court] as List<dynamic>?;
  //
  //   if (slots != null) {
  //     for (var slot in slots) {
  //       final rawStatus = slot['status'];
  //
  //       // 🔥 NORMALIZE TO BOOL
  //       bool isBlocked;
  //       if (rawStatus is bool) {
  //         isBlocked = rawStatus;
  //       } else if (rawStatus is String) {
  //         isBlocked = rawStatus.toLowerCase() == "true" || rawStatus == "1";
  //       } else if (rawStatus is int) {
  //         isBlocked = rawStatus == 1;
  //       } else {
  //         isBlocked = false;
  //       }
  //       final normalizedTime = normalizeTime(slot['time'].toString());
  //       availabilityMap[normalizedTime] = isBlocked;
  //
  //       // availabilityMap[slot['time']] = isBlocked;
  //     }
  //   }
  //
  //   return availabilityMap;
  // }

  // ---------------------- NEW API helpers ----------------------

  /// "06:00:00" -> "6:00 AM", "00:00:00" -> "12:00 AM"
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

  /// Resolve the sports-complex id for the current venue by name, off the same
  /// list the Venue sheet and the header address use.
  Future<int?> _resolveComplexId() async {
    await _loadVenues();
    for (final v in _venues) {
      if (v.name.toLowerCase() == _venue.toLowerCase().trim()) return v.id;
    }
    return null;
  }

  /// GET /courts of a complex (paginated), filtered to the current sport.
  Future<List<dynamic>> _fetchCourtsForSport(int complexId) async {
    final List<dynamic> matching = [];
    int page = 1;
    while (true) {
      final url = Uri.parse(
          '$_apiBase/courts?sportComplexId=$complexId&status=Active&limit=100&page=$page');
      final res = await http.get(url, headers: {'Accept': 'application/json'});
      if (res.statusCode != 200) break;
      final body = jsonDecode(res.body);
      final List data = body['data'] ?? [];
      for (final c in data) {
        final sportName = (c['Sport']?['name'] ?? '').toString();
        final sportId = c['Sport']?['id'];
        final matchesName =
            sportName.toLowerCase().trim() == _sport.toLowerCase().trim();
        final matchesId = _sportId != null && sportId == _sportId;
        if (matchesName || matchesId) matching.add(c);
      }
      final totalPages = body['pagination']?['totalPages'] ?? 1;
      if (page >= (totalPages is int ? totalPages : 1)) break;
      page++;
    }
    return matching;
  }

  /// GET /courts/{courtId}/available-slots?date=...
  Future<List<dynamic>> _fetchAvailableSlots(dynamic courtId, String date) async {
    final url = Uri.parse('$_apiBase/courts/$courtId/available-slots?date=$date');
    final res = await http.get(url, headers: {'Accept': 'application/json'});
    if (res.statusCode != 200) return [];
    final body = jsonDecode(res.body);
    return body['data'] ?? [];
  }




  // ---------------------- NEW API: courts + slots ----------------------
  // Builds the same `courts` slot-map list the existing UI consumes:
  //   court, hourType, dayType, time, price, date, isSoldOut
  // plus hidden booking metadata: courtId, slotId, sportId, sportComplexId,
  // startTime, endTime (ignored by the UI, used by PaymentScreen).
  Future<void> fetchCourtsWisePrice() async {
    AppLogger.debug("🚀 fetchCourtsWisePrice() [NEW API] called", name: 'slotbook');

    setState(() {
      isLoading = true;
      error = null;
    });

    final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDay);
    final selectedDayName = DateFormat('EEEE').format(_selectedDay);

    try {
      _sportComplexId ??= await _resolveComplexId();
      if (_sportComplexId == null) {
        setState(() {
          courts = [];
          error = "Location \"$_venue\" not found";
        });
        return;
      }

      final matchingCourts = await _fetchCourtsForSport(_sportComplexId!);
      if (matchingCourts.isNotEmpty) {
        _sportId ??= matchingCourts.first['Sport']?['id'] is int
            ? matchingCourts.first['Sport']['id'] as int
            : int.tryParse('${matchingCourts.first['Sport']?['id']}');
      }

      final List<Map<String, dynamic>> parsedSlots = [];

      for (final court in matchingCourts) {
        final courtId = court['id'];
        final courtName = (court['name'] ?? '').toString();
        final courtSportId = court['Sport']?['id'];

        final slots = await _fetchAvailableSlots(courtId, formattedDate);

        for (final s in slots) {
          final start = (s['startTime'] ?? '').toString(); // "06:00:00"
          final end = (s['endTime'] ?? '').toString();
          final booked = s['isBooked'] == true;
          final price = (s['price'] is num)
              ? (s['price'] as num).toInt()
              : int.tryParse('${s['price']}') ?? 0;

          parsedSlots.add({
            "court": courtName,
            "hourType": (s['slotType'] ?? 'Regular').toString(),
            "dayType": selectedDayName,
            "time": "${_fmtTime(start)} - ${_fmtTime(end)}",
            "price": price,
            "date": formattedDate,
            "isSoldOut": booked,
            // ---- hidden booking metadata (new API) ----
            "courtId": courtId,
            "slotId": s['id'],
            "sportId": courtSportId ?? _sportId,
            "sportComplexId": _sportComplexId,
            "startTime": start,
            "endTime": end,
          });
        }
      }

      AppLogger.debug("✅ Total AVAILABLE slots: ${parsedSlots.length}", name: 'slotbook');

      setState(() {
        courts = parsedSlots;
        selectedSlots =
            selectedSlots.where((s) => s['date'] != formattedDate).toList();
        totalPrice = selectedSlots.fold(
            0, (sum, s) => sum + (s['price'] as int));

        // No court to preselect any more — the tabs are the only choice left,
        // and the court is picked per slot when one is tapped.
        final hourTypes = _getHourTypes();
        selectedHourTypeTab = hourTypes.isNotEmpty ? hourTypes.first : null;

        // The day changed under the form, so re-seed the start time.
        _seedSelection();
      });

      // Offers are venue- and sport-scoped, so they can only be asked for once
      // those ids have been resolved above.
      if (_loadingCoupons) _loadCoupons();
      _revalidateCoupon();

      AppLogger.debug("🎉 fetchCourtsWisePrice() [NEW API] completed", name: 'slotbook');
    } catch (e, stack) {
      AppLogger.debug("🔥 Exception: $e", name: 'slotbook');
      AppLogger.debug('${stack}', name: 'slotbook');
      setState(() => error = "Error: $e");
    } finally {
      setState(() => isLoading = false);
      AppLogger.debug("⏹️ Loading finished", name: 'slotbook');
    }
  }

  // Future<void> fetchCourtsWisePrice() async {
  //   setState(() {
  //     isLoading = true;
  //     error = null;
  //   });
  //
  //   final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDay);
  //   final selectedDayName = DateFormat('EEEE').format(_selectedDay);
  //
  //   final url = Uri.https(
  //     "nahatasports.com",
  //     "/api/courts_wise_price",
  //     {
  //       "date": formattedDate,
  //       "sport_name": widget.game,
  //       "location": widget.location,
  //     },
  //   );
  //
  //   try {
  //     final response = await http.get(url);
  //     if (response.statusCode == 200) {
  //       final responseData = json.decode(response.body);
  //       if (responseData["status"] == "success") {
  //         final data = responseData["data"] as Map<String, dynamic>;
  //         final List<Map<String, dynamic>> parsedSlots = [];
  //
  //         data.forEach((courtName, courtData) {
  //           final courtMap = courtData as Map<String, dynamic>;
  //           courtMap.forEach((hourType, daysMap) {
  //             if (daysMap is Map<String, dynamic>) {
  //               daysMap.forEach((dayType, slotList) {
  //                 if (slotList is List &&
  //                     isSlotForSelectedDay(dayType, selectedDayName)) {
  //                   for (var slot in slotList) {
  //                     parsedSlots.add({
  //                       "court": courtName,
  //                       "hourType": hourType,
  //                       "dayType": dayType,
  //                       "time": slot["time"].toString(),
  //                       "price": int.tryParse(slot["price"].toString()) ?? 0,
  //                       "date": formattedDate, // Add date to each slot
  //                     });
  //                   }
  //                 }
  //               });
  //             }
  //           });
  //         });
  //
  //         // Keep selected slots from other dates, only update current date
  //         final otherDateSlots = selectedSlots.where((sel) => sel['date'] != formattedDate).toList();
  //         final currentDateSlots = selectedSlots.where((sel) {
  //           return sel['date'] == formattedDate && parsedSlots.any((p) =>
  //           p['court'] == sel['court'] &&
  //               p['hourType'] == sel['hourType'] &&
  //               p['time'] == sel['time'] &&
  //               p['date'] == sel['date']);
  //         }).toList();
  //
  //         setState(() {
  //           courts = parsedSlots;
  //           // Combine slots from other dates with current date selections
  //           selectedSlots = [...otherDateSlots, ...currentDateSlots];
  //           totalPrice = selectedSlots.fold(0, (sum, s) => sum + (s['price'] as int));
  //
  //           final courtNames = _getCourtNames();
  //           if (courtNames.isNotEmpty) {
  //             selectedCourt = courtNames.first;
  //           }
  //
  //           if (selectedCourt != null) {
  //             final hourTypes = _getHourTypesForCourt(selectedCourt);
  //             if (hourTypes.isNotEmpty) {
  //               selectedHourTypeTab = hourTypes.first;
  //             }
  //           }
  //         });
  //       } else {
  //         setState(() {
  //           courts = [];
  //           error = responseData["message"]?.toString() ?? "No data";
  //         });
  //       }
  //     } else {
  //       setState(() => error = "Server error ${response.statusCode}");
  //     }
  //   } catch (e) {
  //     setState(() => error = "Error: $e");
  //   } finally {
  //     setState(() => isLoading = false);
  //   }
  //   // final availability = await fetchSlotAvailability(
  //   //   date: formattedDate,
  //   //   court: courtNames.first, // or selectedCourt
  //   // );
  //
  // }

  // ---------------------- Helpers ----------------------
  // --------------------------------------------------------------------------
  // Time-first booking
  // --------------------------------------------------------------------------
  // The screen used to ask for a court before it would show a single time, so
  // booking an 8pm game meant checking four courts one by one to find out who
  // had 8pm free. Which court you play on is the venue's problem, not the
  // customer's — so the court picker is gone and a time is offered whenever
  // *any* court has it free. The court is still chosen here, just automatically,
  // and it still travels on the slot map that payment consumes.

  /// Every pricing tier present today, across all courts.
  List<String> _getHourTypes() {
    final hourTypes =
        courts.map((s) => s['hourType'].toString()).toSet().toList();
    hourTypes.sort();
    return hourTypes;
  }

  /// One entry per start time in this pricing tier. See [mergeSlotsByTime].
  List<TimeSlot> _timeSlotsFor(String hourType) =>
      mergeSlotsByTime(courts, hourType);
  void toggleSlot(Map<String, dynamic> slot) {
    if (slot['isSoldOut'] == true) return;

    setState(() {
      final exists = selectedSlots.any((s) =>
      s['court'] == slot['court'] &&
          s['hourType'] == slot['hourType'] &&
          s['time'] == slot['time'] &&
          s['date'] == slot['date']);

      if (exists) {
        selectedSlots.removeWhere((s) =>
        s['court'] == slot['court'] &&
            s['hourType'] == slot['hourType'] &&
            s['time'] == slot['time'] &&
            s['date'] == slot['date']);
      } else {
        selectedSlots.add(slot);
      }
      totalPrice = selectedSlots.fold(0, (sum, s) => sum + (s['price'] as int));
    });
  }

  void _showConfirmationBottomSheet() {
    // Group slots by date
    Map<String, List<Map<String, dynamic>>> groupedSlots = {};

    for (var slot in selectedSlots) {
      final date = slot['date'] as String;
      final dateKey = DateFormat('dd MMM yyyy').format(DateTime.parse(date));

      if (!groupedSlots.containsKey(dateKey)) {
        groupedSlots[dateKey] = [];
      }
      groupedSlots[dateKey]!.add(slot);
    }

    // Sort dates
    final sortedDates = groupedSlots.keys.toList()
      ..sort((a, b) {
        final dateA = DateFormat('dd MMM yyyy').parse(a);
        final dateB = DateFormat('dd MMM yyyy').parse(b);
        return dateA.compareTo(dateB);
      });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Confirm your selection",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Scrollable content
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Display slots grouped by date
                    ...sortedDates.map((dateKey) {
                      final slotsForDate = groupedSlots[dateKey]!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Date header
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              color: brandBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              dateKey,
                              style: TextStyle(
                                fontSize: 14,
                                color: brandBlue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Slots for this date
                          ...slotsForDate.map((slot) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        slot['time'],
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        slot['court'],
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  "₹${slot['price']}",
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          )),
                          const SizedBox(height: 16),
                        ],
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    final loggedIn = await ApiService.isLoggedIn();
                    if (loggedIn) {
                      final userDetails = ApiService.currentUser;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PaymentScreen(
                            bookingDetails: {
                              "location": _venue,
                              "game": _sport,
                              "slots": selectedSlots,
                              "price": totalPrice,
                              "date": DateFormat('yyyy-MM-dd').format(_selectedDay),
                              "phone": userDetails?['phone'] ?? '',
                              "cash": 0,
                              // 🔄 NEW API booking metadata
                              "sportComplexId": _sportComplexId,
                              "sportId": _sportId,
                            },
                          ),
                        ),
                      );
                    } else {
                      _showNotLoggedInPopup();
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Error: $e"),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandBlue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "CONFIRM SLOTS",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  // void _showConfirmationBottomSheet() {
  //   showModalBottomSheet(
  //     context: context,
  //     shape: const RoundedRectangleBorder(
  //       borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  //     ),
  //     builder: (context) => Container(
  //       padding: const EdgeInsets.all(24),
  //       child: Column(
  //         mainAxisSize: MainAxisSize.min,
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           Row(
  //             mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //             children: [
  //               const Text(
  //                 "Confirm your selection",
  //                 style: TextStyle(
  //                   fontSize: 18,
  //                   fontWeight: FontWeight.w600,
  //                 ),
  //               ),
  //               GestureDetector(
  //                 onTap: () => Navigator.pop(context),
  //                 child: Container(
  //                   padding: const EdgeInsets.all(6),
  //                   decoration: BoxDecoration(
  //                     color: Colors.grey.shade200,
  //                     shape: BoxShape.circle,
  //                   ),
  //                   child: const Icon(Icons.close, size: 20),
  //                 ),
  //               ),
  //             ],
  //           ),
  //           const SizedBox(height: 20),
  //           Text(
  //             DateFormat('dd MMM yyyy').format(_selectedDay),
  //             style: TextStyle(
  //               fontSize: 14,
  //               color: Colors.grey.shade600,
  //               fontWeight: FontWeight.w500,
  //             ),
  //           ),
  //           const SizedBox(height: 16),
  //           ...selectedSlots.map((slot) => Padding(
  //             padding: const EdgeInsets.only(bottom: 12),
  //             child: Row(
  //               children: [
  //                 Expanded(
  //                   child: Column(
  //                     crossAxisAlignment: CrossAxisAlignment.start,
  //                     children: [
  //                       Text(
  //                         slot['time'],
  //                         style: const TextStyle(
  //                           fontSize: 15,
  //                           fontWeight: FontWeight.w600,
  //                         ),
  //                       ),
  //                       const SizedBox(height: 2),
  //                       Text(
  //                         slot['court'],
  //                         style: TextStyle(
  //                           fontSize: 13,
  //                           color: Colors.grey.shade600,
  //                         ),
  //                       ),
  //                     ],
  //                   ),
  //                 ),
  //                 Text(
  //                   "₹${slot['price']}",
  //                   style: const TextStyle(
  //                     fontSize: 15,
  //                     fontWeight: FontWeight.w600,
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           )),
  //           const SizedBox(height: 24),
  //           SizedBox(
  //             width: double.infinity,
  //             child: ElevatedButton(
  //               onPressed: () async {
  //                 Navigator.pop(context);
  //                 try {
  //                   final loggedIn = await ApiService.isLoggedIn();
  //                   if (loggedIn) {
  //                     final userDetails = ApiService.currentUser;
  //                     Navigator.push(
  //                       context,
  //                       MaterialPageRoute(
  //                         builder: (context) => PaymentScreen(
  //                           bookingDetails: {
  //                             "location": widget.location,
  //                             "game": widget.game,
  //                             "slots": selectedSlots,
  //                             "price": totalPrice,
  //                             "date": DateFormat('yyyy-MM-dd').format(_selectedDay),
  //                             "phone": userDetails?['phone'] ?? '',
  //                             "cash": 0,
  //                           },
  //                         ),
  //                       ),
  //                     );
  //                   } else {
  //                     _showNotLoggedInPopup();
  //                   }
  //                 } catch (e) {
  //                   ScaffoldMessenger.of(context).showSnackBar(
  //                     SnackBar(
  //                       content: Text("Error: $e"),
  //                       backgroundColor: Colors.red,
  //                     ),
  //                   );
  //                 }
  //               },
  //               style: ElevatedButton.styleFrom(
  //                 backgroundColor: brandBlue,
  //                 padding: const EdgeInsets.symmetric(vertical: 16),
  //                 shape: RoundedRectangleBorder(
  //                   borderRadius: BorderRadius.circular(12),
  //                 ),
  //               ),
  //               child: const Text(
  //                 "CONFIRM SLOTS",
  //                 style: TextStyle(
  //                   color: Colors.white,
  //                   fontSize: 15,
  //                   fontWeight: FontWeight.w600,
  //                 ),
  //               ),
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  // ---------------------- UI ----------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      appBar: _buildAppBar(),
      // SafeArea on the bottom so the CTA clears the system navigation bar.
      body: SafeArea(
        top: false,
        child: isLoading || error != null
            // The shimmer and the error state are the screen's own, unchanged.
            ? _buildBody()
            : _buildBookingForm(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      leadingWidth: 64,
      leading: Center(
        child: Material(
          color: const Color(0xFFF2F3F8),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _goBackToSports,
            child: const SizedBox(
              height: 40,
              width: 40,
              child: Icon(Icons.chevron_left, color: _navy, size: 24),
            ),
          ),
        ),
      ),
      title: const Text(
        'BOOK A COURT',
        style: TextStyle(
          color: _navy,
          fontSize: 19,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
      centerTitle: false,
      titleSpacing: 4,
    );
  }

  /// Back out to the sport list for this venue — where the sport and venue are
  /// actually chosen, which is also what the Venue and Sport rows point at.
  void _goBackToSports() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Viewgame(locationName: _venue),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Book a Court — form layout
  // ═══════════════════════════════════════════════════════════════════════

  /// The whole screen is one white card on a tinted page, scrolling as a unit.
  ///
  /// Every figure in it is derived from the slots the API returned: nothing
  /// here is placeholder text, and a day with no free courts renders as one.
  Widget _buildBookingForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A1E1B4B),
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildVenueHeader(),
            _buildAssuranceStrip(),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildVenueRow(),
                  _rowDivider(),
                  _buildSportRow(),
                  _rowDivider(),
                  _buildDateRow(),
                  _rowDivider(),
                  _buildStartTimeRow(),
                  _rowDivider(),
                  _buildDurationRow(),
                  _rowDivider(),
                  _buildAvailabilityLine(),
                  const SizedBox(height: 14),
                  _buildOffersCard(),
                  const SizedBox(height: 14),
                  _buildTotalCard(),
                  const SizedBox(height: 14),
                  _buildPrimaryCta(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rowDivider() => const Divider(height: 1, thickness: 1, color: _line);

  /// Venue name and its street address.
  Widget _buildVenueHeader() {
    final address = _venueAddress;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _venue,
            style: const TextStyle(
              color: _navy,
              fontSize: 26,
              height: 1.15,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (address != null) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child:
                      Icon(Icons.location_on_outlined, size: 15, color: _muted),
                ),
                const SizedBox(width: 6),
                // Expanded, so a long address wraps instead of being cut off.
                Expanded(
                  child: Text(
                    address,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 13.5,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAssuranceStrip() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_indigoDeep, _indigo],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: const Text(
        '✓  Instant confirmation · Secure online payment',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// One labelled row: caption on the left, field on the right.
  ///
  /// Both halves are flexed rather than fixed, so the row holds its shape from
  /// a 320pt phone to a tablet and at any system text size.
  Widget _formRow({required String label, required Widget field}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(
                color: _navy,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(flex: 7, child: field),
        ],
      ),
    );
  }

  /// The bordered input container the reference uses for every field.
  Widget _fieldBox({
    required Widget child,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return Material(
      color: _fieldBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: [
              Expanded(child: child),
              if (trailing != null) ...[const SizedBox(width: 6), trailing],
            ],
          ),
        ),
      ),
    );
  }

  Widget _fieldText(String value) => Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: _navy,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      );

  static const _chevron = Icon(Icons.expand_more, size: 20, color: _muted);

  Widget _buildVenueRow() {
    return _formRow(
      label: 'Venue',
      field: _fieldBox(
        // Both rows re-pick in place: the sheet changes the selection and the
        // day reloads underneath it, so neither leaves this screen.
        onTap: _pickVenue,
        trailing: _chevron,
        child: _fieldText(_venue),
      ),
    );
  }

  Widget _buildSportRow() {
    return _formRow(
      label: 'Sport',
      field: _fieldBox(
        onTap: _pickSport,
        trailing: _chevron,
        child: _fieldText(_sport),
      ),
    );
  }

  Widget _buildDateRow() {
    return _formRow(
      label: 'Date',
      field: _fieldBox(
        onTap: _pickDate,
        trailing:
            const Icon(Icons.calendar_today_outlined, size: 17, color: _muted),
        child: _fieldText(DateFormat('EEE, MMM d, yyyy').format(_selectedDay)),
      ),
    );
  }

  /// Opens the platform date picker and reloads that day's slots.
  ///
  /// The window matches the horizontal date strip the screen used before, so
  /// the range of bookable days is unchanged.
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay.isBefore(today) ? today : _selectedDay,
      firstDate: today,
      lastDate: today.add(const Duration(days: 30)),
    );
    if (picked == null) return;
    if (DateUtils.isSameDay(picked, _selectedDay)) return;

    setState(() {
      _selectedDay = picked;
      _startSlot = null;
      _durationSlots = 1;
    });
    await fetchCourtsWisePrice();
  }

  Widget _buildStartTimeRow() {
    final open = _openTimes;
    final start = _startSlot;

    return _formRow(
      label: 'Start Time',
      field: _fieldBox(
        onTap: open.isEmpty ? null : _pickStartTime,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.access_time, size: 17, color: _muted),
            SizedBox(width: 2),
            _chevron,
          ],
        ),
        child: _fieldText(
          start == null
              ? (open.isEmpty ? 'No slots today' : 'Select a time')
              : _fmtTime(start.slot['startTime'].toString()),
        ),
      ),
    );
  }

  /// Start times for the day, in a sheet so a long list stays scrollable on a
  /// short screen.
  Future<void> _pickStartTime() async {
    final open = _openTimes;
    if (open.isEmpty) return;

    final chosen = await showModalBottomSheet<TimeSlot>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E2EC),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 18, 20, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'START TIME',
                    style: TextStyle(
                      color: _navy,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ),
              const Divider(height: 1, color: _line),
              Expanded(
                child: ListView.separated(
                  controller: controller,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: open.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: _line, indent: 20),
                  itemBuilder: (_, i) {
                    final entry = open[i];
                    final selected =
                        _startSlot?.slot['startTime'] == entry.slot['startTime'];
                    return ListTile(
                      title: Text(
                        _fmtTime(entry.slot['startTime'].toString()),
                        style: TextStyle(
                          color: _navy,
                          fontSize: 15,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        '₹${entry.slot['price']} · '
                        '${entry.freeCourts} of ${entry.totalCourts} free',
                        style: const TextStyle(fontSize: 12, color: _muted),
                      ),
                      trailing: selected
                          ? const Icon(Icons.check_circle,
                              color: _indigo, size: 20)
                          : null,
                      onTap: () => Navigator.pop(sheetContext, entry),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (chosen == null) return;
    setState(() {
      _startSlot = chosen;
      _durationSlots = 1;
    });
    _revalidateCoupon();
  }

  Widget _buildDurationRow() {
    return _formRow(
      label: 'Duration',
      field: Row(
        children: [
          _stepperButton(
            icon: Icons.remove,
            enabled: _durationSlots > 1,
            onTap: () {
              setState(() => _durationSlots -= 1);
              _revalidateCoupon();
            },
          ),
          Expanded(
            child: Text(
              _durationLabel,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _navy,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _stepperButton(
            icon: Icons.add,
            enabled: _canExtend,
            filled: true,
            onTap: () {
              setState(() => _durationSlots += 1);
              _revalidateCoupon();
            },
          ),
        ],
      ),
    );
  }

  /// A circular stepper control. The disabled state is a flat grey circle,
  /// matching the reference's minus button at one hour.
  Widget _stepperButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    final background = enabled && filled ? _indigo : const Color(0xFFF0F1F6);
    final foreground = !enabled
        ? const Color(0xFFB9BCC9)
        : (filled ? Colors.white : _navy);

    return Material(
      color: background,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled ? onTap : null,
        child: SizedBox(
          height: 42,
          width: 42,
          child: Icon(icon, size: 20, color: foreground),
        ),
      ),
    );
  }

  /// The availability line under the duration stepper.
  Widget _buildAvailabilityLine() {
    final run = _runSlots;

    if (run.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 14, bottom: 2),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 18, color: _muted),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'No courts free on this date',
                style: TextStyle(
                  color: _muted,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 2),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, size: 18, color: _indigo),
          const SizedBox(width: 8),
          // Wraps rather than clipping when the range plus a large system text
          // size outgrows one line.
          Expanded(
            child: Text(
              'Available · $_runLabel',
              style: const TextStyle(
                color: _indigo,
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// OFFERS & COUPONS — the offers the venue is running, plus a code field.
  ///
  /// The figures shown come from `/coupons/validate`; the money actually
  /// charged is decided by the server when the booking is created.
  Widget _buildOffersCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _offersExpanded = !_offersExpanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, size: 18, color: _indigo),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'OFFERS & COUPONS',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _navy,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  Icon(
                    _offersExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 22,
                    color: _muted,
                  ),
                ],
              ),
            ),
          ),
          if (_offersExpanded) ...[
            const Divider(height: 1, color: _line),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
              child: Column(children: [
                _buildOffersList(),
                const SizedBox(height: 16),
                _buildOrEnterCode(),
                const SizedBox(height: 12),
                _buildCouponField(),
                if (_couponError != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.error_outline,
                          size: 15, color: Color(0xFFDC2626)),
                      const SizedBox(width: 6),
                      // The server's own wording, which is already
                      // user-facing — wrapped, never truncated.
                      Expanded(
                        child: Text(
                          _couponError!,
                          style: const TextStyle(
                            color: Color(0xFFDC2626),
                            fontSize: 12.5,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ]),
            ),
          ],
        ],
      ),
    );
  }

  /// The offers strip: what the venue is running right now, or the empty line
  /// the reference shows when it is running nothing.
  Widget _buildOffersList() {
    if (_loadingCoupons) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: SizedBox(
          height: 18,
          width: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: _indigo),
        ),
      );
    }

    final applied = _appliedCoupon;
    if (applied != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle,
                size: 18, color: Color(0xFF16A34A)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    applied.code ?? 'Coupon applied',
                    style: const TextStyle(
                      color: Color(0xFF166534),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (_discount > 0)
                    Text(
                      'You saved ₹$_discount',
                      style: const TextStyle(
                        color: Color(0xFF16A34A),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            TextButton(
              onPressed: _applyingCoupon ? null : _removeCoupon,
              child: const Text('Remove'),
            ),
          ],
        ),
      );
    }

    final usable =
        _coupons.where((c) => (c.code ?? '').isNotEmpty).toList(growable: false);

    if (usable.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Text(
          'No active offers right now',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, fontSize: 13.5),
        ),
      );
    }

    return Column(
      children: [
        for (final coupon in usable.take(6))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _applyingCoupon
                  ? null
                  : () => _applyCouponCode(coupon.code!),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                decoration: BoxDecoration(
                  color: _fieldBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            coupon.code!,
                            style: const TextStyle(
                              color: _navy,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                          if ((coupon.description ?? '').isNotEmpty)
                            Text(
                              coupon.description!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 11.5,
                                height: 1.35,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      coupon.shortLabel,
                      style: const TextStyle(
                        color: _indigo,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildOrEnterCode() {
    return Row(
      children: const [
        Expanded(child: Divider(height: 1, color: _line)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OR ENTER CODE',
            style: TextStyle(
              color: Color(0xFFA9ADBD),
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Expanded(child: Divider(height: 1, color: _line)),
      ],
    );
  }

  Widget _buildCouponField() {
    final busy = _applyingCoupon;
    final hasCoupon = _appliedCoupon != null;

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: _fieldBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                const Icon(Icons.local_offer_outlined,
                    size: 17, color: _muted),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _couponController,
                    enabled: !busy && !hasCoupon,
                    textCapitalization: TextCapitalization.characters,
                    onSubmitted: _applyCouponCode,
                    style: const TextStyle(
                      color: _navy,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'COUPON CODE',
                      hintStyle: TextStyle(
                        color: Color(0xFFA9ADBD),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.6,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: 46,
          child: ElevatedButton(
            onPressed: busy
                ? null
                : (hasCoupon
                    ? _removeCoupon
                    : () => _applyCouponCode(_couponController.text)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9E9BC8),
              disabledBackgroundColor: const Color(0xFFCFCDE4),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: busy
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    hasCoupon ? 'REMOVE' : 'APPLY',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  /// TOTAL — the amount the CTA is about to charge, discount already off.
  Widget _buildTotalCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          if (_discount > 0) ...[
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Subtotal',
                    style: TextStyle(color: _muted, fontSize: 13.5),
                  ),
                ),
                Text(
                  '₹$_baseTotal',
                  style: const TextStyle(color: _muted, fontSize: 13.5),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Coupon ${_appliedCoupon?.code ?? ''}'.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF16A34A),
                      fontSize: 13.5,
                    ),
                  ),
                ),
                Text(
                  '− ₹$_discount',
                  style: const TextStyle(
                    color: Color(0xFF16A34A),
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: _border),
            const SizedBox(height: 14),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Expanded(
                child: Text(
                  'TOTAL',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              // Flexible so a five-figure total shrinks the gap rather than
              // running off the card.
              Flexible(
                child: Text(
                  '₹$_payable',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: _navy,
                    fontSize: 30,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The single call to action.
  ///
  /// A free court is never described as a payment: there is nothing to charge,
  /// the gateway is skipped, and the label says so.
  Widget _buildPrimaryCta() {
    final ready = _runSlots.isNotEmpty;
    final free = _isFree;

    final label = !ready
        ? 'Select a time'
        : (free ? 'Reserve Free Court' : 'Pay & Reserve · ₹$_payable');

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        key: const Key('court_book_cta'),
        onPressed: ready && !isLoading ? _onReservePressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _indigoDeep,
          disabledBackgroundColor: const Color(0xFFC7C9DC),
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: const Color(0x33312E81),
          padding: const EdgeInsets.symmetric(vertical: 17),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              free ? Icons.confirmation_number_outlined : Icons.credit_card,
              size: 19,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            // Flexible so the label ellipsises rather than overflowing the
            // button on a narrow phone at a large text size.
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Hands the chosen run to the payment screen.
  ///
  /// The slot maps handed over are exactly the ones the API produced —
  /// `courtId`, `slotId`, `startTime`, `endTime` and the rest — so the booking
  /// call downstream is unchanged. `couponCode` travels with them: the payment
  /// screen re-validates it and the backend applies the discount itself, which
  /// is the only place a coupon ever takes effect.
  Future<void> _onReservePressed() async {
    final run = _runSlots;
    if (run.isEmpty) return;

    try {
      final loggedIn = await ApiService.isLoggedIn();
      if (!mounted) return;

      if (!loggedIn) {
        _showNotLoggedInPopup();
        return;
      }

      final userDetails = ApiService.currentUser;

      // Keep the existing shape byte for byte; only the selection changed.
      selectedSlots = run.map((t) => t.slot).toList();
      totalPrice = _baseTotal;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentScreen(
            bookingDetails: {
              "location": _venue,
              "game": _sport,
              "slots": selectedSlots,
              // The original price: the backend re-applies the coupon itself,
              // so a pre-discounted figure here would discount it twice.
              "price": totalPrice,
              "date": DateFormat('yyyy-MM-dd').format(_selectedDay),
              "phone": userDetails?['phone'] ?? '',
              "cash": 0,
              "sportComplexId": _sportComplexId,
              "sportId": _sportId,
              if (_appliedCoupon?.code != null)
                "couponCode": _appliedCoupon!.code,
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildBody() {
    if (isLoading) {
      // Shaped like the calendar / courts / slots below it, so the screen fills
      // in place instead of snapping from a spinner to a full page.
      return AppShimmer.slotBooking();
    }
    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              error!,
              style: const TextStyle(color: Colors.red, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: fetchCourtsWisePrice,
              style: ElevatedButton.styleFrom(
                backgroundColor: brandBlue,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text("Retry", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        _buildHorizontalCalendar(),
        const SizedBox(height: 20),
        Expanded(child: _buildSlotsSection()),
      ],
    );
  }

  Widget _buildHorizontalCalendar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            DateFormat('MMMM yyyy').format(_selectedDay),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 80,
          child: ListView.builder(
            controller: _dateScrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _dateList.length,
            itemBuilder: (context, index) {
              final date = _dateList[index];
              final isSelected = isSameDate(date, _selectedDay);
              final isToday = isSameDate(date, DateTime.now());
              final isPast = date.isBefore(DateTime.now()) && !isToday;

              return GestureDetector(
                onTap: isPast
                    ? null
                    : () {
                  setState(() => _selectedDay = date);
                  fetchCourtsWisePrice();
                },
                child: Container(
                  width: 60,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? brandBlue : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? brandBlue
                          : (isToday ? brandBlue : Colors.grey.shade300),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('EEE').format(date).toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isPast
                              ? Colors.grey.shade400
                              : (isSelected ? Colors.white : Colors.grey.shade600),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        date.day.toString(),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: isPast
                              ? Colors.grey.shade400
                              : (isSelected ? Colors.white : Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSlotsSection() {
    final hourTypes = _getHourTypes();
    if (hourTypes.isEmpty) {
      return const Center(
        child: Text("No slots available for this date"),
      );
    }

    // Set default tab if not set
    if (selectedHourTypeTab == null || !hourTypes.contains(selectedHourTypeTab)) {
      selectedHourTypeTab = hourTypes.first;
    }

    return Column(
      children: [
        // Hour Type Tabs
        Container(
          height: 45,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: hourTypes.map((hourType) {
              final isSelected = selectedHourTypeTab == hourType;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedHourTypeTab = hourType;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      color: isSelected ? brandBlue : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? brandBlue : Colors.grey.shade300,
                      ),
                    ),
                    margin: EdgeInsets.only(
                      right: hourTypes.indexOf(hourType) == hourTypes.length - 1 ? 0 : 8,
                    ),
                    child: Center(
                      child: Text(
                        hourType,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 20),

        // Animated Slots Display
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.1, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: _buildSlotsList(selectedHourTypeTab!),
          ),
        ),
      ],
    );
  }
  Widget _buildSlotsList(String hourType) {
    final slots = _timeSlotsFor(hourType);

    if (slots.isEmpty) {
      return Center(
        key: ValueKey('empty_$hourType'),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              "No slots available for $hourType",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      key: ValueKey(hourType),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: slots.length,
      itemBuilder: (context, index) => _buildSlotChip(slots[index]),
    );
  }

  /// A start time, plus the court that will be booked for it.
  ///
  /// [slot] is a real slot map straight from the API — court id, slot id and
  /// price included — so nothing downstream of the tap has to change.

  // Widget _buildSlotChip(Map<String, dynamic> slot) {
  //   final isSelected = selectedSlots.any((s) =>
  //   s['court'] == slot['court'] &&
  //       s['hourType'] == slot['hourType'] &&
  //       s['time'] == slot['time']);
  //   final isSoldOut = (slot['price'] == 0);
  //
  //   return Container(
  //     width: double.infinity,
  //     padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
  //     margin: const EdgeInsets.only(bottom: 12),
  //     decoration: BoxDecoration(
  //       color: isSelected
  //           ? brandBlue
  //           : (isSoldOut ? Colors.grey.shade200 : Colors.white),
  //       borderRadius: BorderRadius.circular(12),
  //       border: Border.all(
  //         color: isSelected
  //             ? brandBlue
  //             : (isSoldOut ? Colors.grey.shade300 : Colors.grey.shade300),
  //         width: 1,
  //       ),
  //     ),
  //     child: InkWell(
  //       onTap: isSoldOut ? null : () => toggleSlot(slot),
  //       child: Row(
  //         mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //         children: [
  //           Row(
  //             children: [
  //               Text(
  //                 slot['time'],
  //                 style: TextStyle(
  //                   color: isSelected
  //                       ? Colors.white
  //                       : (isSoldOut ? Colors.grey : Colors.black87),
  //                   fontWeight: FontWeight.w600,
  //                   fontSize: 15,
  //                 ),
  //               ),
  //               const SizedBox(width: 12),
  //               Text(
  //                 isSoldOut ? "Sold Out" : "₹${slot['price']}",
  //                 style: TextStyle(
  //                   color: isSelected
  //                       ? Colors.white
  //                       : (isSoldOut ? Colors.grey : Colors.grey.shade600),
  //                   fontSize: 14,
  //                 ),
  //               ),
  //             ],
  //           ),
  //           Container(
  //             padding: const EdgeInsets.all(6),
  //             decoration: BoxDecoration(
  //               color: isSelected ? Colors.white : brandBlue,
  //               shape: BoxShape.circle,
  //             ),
  //             child: Icon(
  //               Icons.add,
  //               color: isSelected ? brandBlue : Colors.white,
  //               size: 20,
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  Widget _buildSlotChip(TimeSlot entry) {
    final slot = entry.slot;
    final isSelected = selectedSlots.any((s) =>
    s['court'] == slot['court'] &&
        s['hourType'] == slot['hourType'] &&
        s['time'] == slot['time'] &&
        s['date'] == slot['date']);
    final isSoldOut = entry.isSoldOut;

    // Which court you get is shown, not chosen — and only once the slot is in
    // the basket, so browsing stays a list of times and prices.
    final courtNote = isSoldOut
        ? 'All ${entry.totalCourts} courts booked'
        : (isSelected
            ? 'Court: ${slot['court']}'
            : (entry.freeCourts > 1 ? '${entry.freeCourts} courts free' : '1 court left'));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected
            ? brandBlue
            : (isSoldOut ? Colors.grey.shade200 : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? brandBlue : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: isSoldOut ? null : () => toggleSlot(slot),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        slot['time'],
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : (isSoldOut ? Colors.grey : Colors.black87),
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isSoldOut ? "Sold Out" : "₹${slot['price']}",
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : (isSoldOut ? Colors.grey : Colors.grey.shade600),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  // const SizedBox(height: 3),
                  // Text(
                  //   courtNote,
                  //   style: TextStyle(
                  //     color: isSelected
                  //         ? Colors.white70
                  //         : (isSoldOut ? Colors.grey : Colors.grey.shade600),
                  //     fontSize: 11.5,
                  //   ),
                  // ),
                ],
              ),
            ),
            if (!isSoldOut)
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : brandBlue,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSelected ? Icons.check : Icons.add,
                  color: isSelected ? brandBlue : Colors.white,
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Widget _buildSlotsList(String hourType) {
  //   final slots = _getSlotsForCourtAndHour(selectedCourt, hourType);
  //
  //   if (slots.isEmpty) {
  //     return Center(
  //       key: ValueKey('empty_$hourType'),
  //       child: Column(
  //         mainAxisAlignment: MainAxisAlignment.center,
  //         children: [
  //           Icon(Icons.event_busy, size: 64, color: Colors.grey.shade400),
  //           const SizedBox(height: 16),
  //           Text(
  //             "No slots available for $hourType",
  //             style: TextStyle(
  //               fontSize: 14,
  //               color: Colors.grey.shade600,
  //             ),
  //           ),
  //         ],
  //       ),
  //     );
  //   }
  //
  //   return ListView(
  //     key: ValueKey(hourType),
  //     padding: const EdgeInsets.symmetric(horizontal: 20),
  //     children: [
  //       Wrap(
  //         spacing: 10,
  //         runSpacing: 10,
  //         children: slots.map((slot) => _buildSlotChip(slot)).toList(),
  //       ),
  //       const SizedBox(height: 100), // Extra space for bottom bar
  //     ],
  //   );
  // }
  //
  // Widget _buildSlotChip(Map<String, dynamic> slot) {
  //   final isSelected = selectedSlots.any((s) =>
  //   s['court'] == slot['court'] &&
  //       s['hourType'] == slot['hourType'] &&
  //       s['time'] == slot['time']);
  //   final isSoldOut = (slot['price'] == 0);
  //
  //   return GestureDetector(
  //     onTap: isSoldOut ? null : () => toggleSlot(slot),
  //     child: Container(
  //       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  //       decoration: BoxDecoration(
  //         color: isSelected
  //             ? brandBlue
  //             : (isSoldOut ? Colors.grey.shade200 : Colors.white),
  //         borderRadius: BorderRadius.circular(8),
  //         border: Border.all(
  //           color: isSelected
  //               ? brandBlue
  //               : (isSoldOut ? Colors.grey.shade300 : Colors.grey.shade300),
  //         ),
  //       ),
  //       child: Row(
  //         mainAxisSize: MainAxisSize.min,
  //         children: [
  //           Text(
  //             slot['time'],
  //             style: TextStyle(
  //               color: isSelected
  //                   ? Colors.white
  //                   : (isSoldOut ? Colors.grey : Colors.black87),
  //               fontWeight: FontWeight.w600,
  //               fontSize: 14,
  //             ),
  //           ),
  //           const SizedBox(width: 8),
  //           Text(
  //             isSoldOut ? "Sold Out" : "₹${slot['price']}",
  //             style: TextStyle(
  //               color: isSelected
  //                   ? Colors.white
  //                   : (isSoldOut ? Colors.grey : Colors.grey.shade600),
  //               fontSize: 13,
  //             ),
  //           ),
  //           if (isSelected) ...[
  //             const SizedBox(width: 8),
  //             const Icon(Icons.add_circle, color: Colors.white, size: 18),
  //           ],
  //         ],
  //       ),
  //     ),
  //   );
  // }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: brandBlue,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Total",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                Text(
                  "${selectedSlots.length} Slot  ₹$totalPrice",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            ElevatedButton(
              onPressed: _showConfirmationBottomSheet,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: brandBlue,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Row(
                children: const [
                  Text(
                    "PROCEED",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, size: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

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
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_outline, size: 48, color: Colors.orange),
              ),
              const SizedBox(height: 20),
              const Text(
                "Login Required",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                "You need to log in to continue.\nRedirecting you shortly...",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 24),
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

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.pop(context);
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
      );
    });
  }
}



// void toggleSlot(Map<String, dynamic> slot) {

//   setState(() {
//     final exists = selectedSlots.any((s) =>
//     s['court'] == slot['court'] &&
//         s['hourType'] == slot['hourType'] &&
//         s['time'] == slot['time']);
//     if (exists) {
//       selectedSlots.removeWhere((s) =>
//       s['court'] == slot['court'] &&
//           s['hourType'] == slot['hourType'] &&
//           s['time'] == slot['time']);
//     } else {
//       selectedSlots.add(slot);
//     }
//     totalPrice = selectedSlots.fold(0, (sum, s) => sum + (s['price'] as int));
//   });
// }

/// One bookable start time on the slot screen.
///
/// [slot] is a real slot map from the API — court id, slot id, price and all —
/// so the court is decided here and everything downstream (the basket, the
/// confirmation sheet, `POST /courts/bookings/create`) is unchanged.
class TimeSlot {
  const TimeSlot({
    required this.slot,
    required this.freeCourts,
    required this.totalCourts,
  });

  /// The court that will be booked: the cheapest one still free at this time.
  final Map<String, dynamic> slot;

  /// How many courts still have this time. Zero means every court is taken.
  final int freeCourts;
  final int totalCourts;

  bool get isSoldOut => freeCourts == 0;
}

/// Collapses per-court slots into one row per start time, chronologically.
///
/// The booking screen used to ask which court you wanted before it would show
/// a single time, so finding a free 8pm meant opening four courts in turn.
/// Which court you play on is the venue's business, so it is decided here
/// instead: a time is offered while *any* court still has it, and the cheapest
/// free court is the one that gets booked.
///
/// [slots] are the raw per-court slot maps; only those in [hourType] are
/// considered. A time appears sold out only once every court is taken.
List<TimeSlot> mergeSlotsByTime(
  List<Map<String, dynamic>> slots,
  String hourType,
) {
  final byTime = <String, List<Map<String, dynamic>>>{};
  for (final slot in slots) {
    if (slot['hourType'].toString() != hourType) continue;
    byTime.putIfAbsent(slot['time'].toString(), () => []).add(slot);
  }

  final entries = <TimeSlot>[];
  byTime.forEach((time, candidates) {
    final free = candidates.where((s) => s['isSoldOut'] != true).toList()
      ..sort((a, b) => (a['price'] as int).compareTo(b['price'] as int));

    entries.add(
      TimeSlot(
        // Falls back to a taken slot purely so the row can render as sold out;
        // it is never selectable.
        slot: free.isNotEmpty ? free.first : candidates.first,
        freeCourts: free.length,
        totalCourts: candidates.length,
      ),
    );
  });

  // 24h startTime keeps the list chronological; `time` is a display string.
  entries.sort((a, b) => (a.slot['startTime'] ?? a.slot['time'])
      .toString()
      .compareTo((b.slot['startTime'] ?? b.slot['time']).toString()));
  return entries;
}
