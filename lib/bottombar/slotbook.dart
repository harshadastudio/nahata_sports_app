import 'package:flutter/material.dart';


import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:nahata_app/auth/login.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:nahata_app/auth/login.dart';

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:nahata_app/auth/login.dart';
import 'package:nahata_app/bottombar/Viewgame.dart' hide ApiService;
import 'package:nahata_app/bottombar/bkpayment.dart';



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
  DateTime _selectedDay = DateTime.now();
  bool isLoading = false;
  String? error;

  List<Map<String, dynamic>> courts = [];
  String? selectedCourt;
  String? selectedHourType;

  List<Map<String, dynamic>> selectedSlots = [];
  int totalPrice = 0;

  @override
  void initState() {
    super.initState();
    fetchCourtsWisePrice();
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

  // ---------------------- API fetch ----------------------
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

          final currentSelected = selectedSlots.where((sel) {
            return parsedSlots.any((p) =>
            p['court'] == sel['court'] &&
                p['hourType'] == sel['hourType'] &&
                p['time'] == sel['time']);
          }).toList();

          setState(() {
            courts = parsedSlots;
            selectedSlots = currentSelected;
            totalPrice = selectedSlots.fold(0, (sum, s) => sum + (s['price'] as int));

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

  // ---------------------- Helpers ----------------------
  List<String> _getCourtNames() {
    final names = courts.map((s) => s['court'].toString()).toSet().toList();
    names.sort();
    return names;
  }

  List<String> _getHourTypesForCourt(String? court) {
    if (court == null) return [];
    final hourTypes = courts
        .where((s) => s['court'] == court)
        .map((s) => s['hourType'].toString())
        .toSet()
        .toList();
    hourTypes.sort();
    return hourTypes;
  }

  List<Map<String, dynamic>> _getSlotsForCourtAndHour(
      String? court, String? hourType) {
    if (court == null || hourType == null) return [];
    final list = courts
        .where((s) => s['court'] == court && s['hourType'] == hourType)
        .toList();
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
      totalPrice = selectedSlots.fold(0, (sum, s) => sum + (s['price'] as int));
    });
  }

  void removeAllSlots() {
    setState(() {
      selectedSlots.clear();
      totalPrice = 0;
    });
  }

  // ---------------------- UI ----------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(child: _buildBody()),
          _buildBottomBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: InkWell(
        onTap: (){
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => Viewgame()),
          );
        },
        child: const Icon(
          Icons.arrow_back_ios_new,
          color: Colors.black87,
          size: 18,
        ),
      ),
      title: const Text(
        "Book and Play",
        style: TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center
      ),
      centerTitle: false,
      actions: [
        if (selectedSlots.isNotEmpty)
          TextButton(
            onPressed: removeAllSlots,
            child: const Text(
              "Clear All",
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF6366F1),
        ),
      );
    }
    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              error!,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: fetchCourtsWisePrice,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text(
                "Retry",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          _buildGameTitle(),
          const SizedBox(height: 24),
          _buildCalendar(),
          const SizedBox(height: 24),
          _buildCourtsList(),
          const SizedBox(height: 100), // Extra space for bottom bar
        ],
      ),
    );
  }

  Widget _buildGameTitle() {
    return Center(
      child: Column(
        children: [
          Text(
            widget.game,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.location,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A237E),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A237E).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('MMMM yyyy').format(_selectedDay),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedDay = DateTime(
                          _selectedDay.year,
                          _selectedDay.month - 1,
                          1,
                        );
                      });
                      fetchCourtsWisePrice();
                    },
                    child: const Icon(
                      Icons.keyboard_arrow_left,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedDay = DateTime(
                          _selectedDay.year,
                          _selectedDay.month + 1,
                          1,
                        );
                      });
                      fetchCourtsWisePrice();
                    },
                    child: const Icon(
                      Icons.keyboard_arrow_right,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildWeekDaysHeader(),
          const SizedBox(height: 12),
          _buildCalendarGrid(),
        ],
      ),
    );
  }

  Widget _buildWeekDaysHeader() {
    const days = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
    return Row(
      children: days.map((day) => Expanded(
        child: Center(
          child: Text(
            day,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDayOfMonth = DateTime(_selectedDay.year, _selectedDay.month, 1);
    final lastDayOfMonth = DateTime(_selectedDay.year, _selectedDay.month + 1, 0);
    final startDate = firstDayOfMonth.subtract(Duration(days: firstDayOfMonth.weekday % 7));
    final today = DateTime.now();

    return Column(
      children: List.generate(6, (weekIndex) {
        return Row(
          children: List.generate(7, (dayIndex) {
            final date = startDate.add(Duration(days: weekIndex * 7 + dayIndex));
            final isCurrentMonth = date.month == _selectedDay.month;
            final isSelected = isSameDate(date, _selectedDay);
            final isToday = isSameDate(date, today);
            final isPast = date.isBefore(today) && !isToday;

            if (!isCurrentMonth) {
              return const Expanded(child: SizedBox(height: 40));
            }

            return Expanded(
              child: GestureDetector(
                onTap: isPast ? null : () {
                  setState(() => _selectedDay = date);
                  fetchCourtsWisePrice();
                },
                child: Container(
                  height: 40,
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isToday && !isSelected
                        ? Border.all(color: Colors.white70, width: 1)
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      date.day.toString(),
                      style: TextStyle(
                        color: isPast
                            ? Colors.white38
                            : (isSelected
                            ? const Color(0xFF1A237E)
                            : Colors.white),
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      }).where((widget) => widget != null).take(5).toList(),
    );
  }

  Widget _buildCourtsList() {
    final courtNames = _getCourtNames();
    if (courtNames.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.sports_tennis,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              const Text(
                "No courts available for this date.",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        ...courtNames.map((court) => _buildCourtCard(court)).toList(),
        if (selectedSlots.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildSelectedSlotsList(),
        ],
      ],
    );
  }

  Widget _buildCourtCard(String court) {
    final hourTypes = _getHourTypesForCourt(court);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Row(
            children: [
              Icon(
                Icons.sports_tennis,
                color: const Color(0xFF1A237E),
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                court,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
            ],
          ),
          trailing: const Icon(
            Icons.keyboard_arrow_down,
            color: Color(0xFF1A237E),
          ),
          children: [
            if (hourTypes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: hourTypes.map((hourType) {
                    final slots = _getSlotsForCourtAndHour(court, hourType);
                    if (slots.isEmpty) return const SizedBox.shrink();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: hourType.toLowerCase().contains('happy')
                                ? Colors.orange.shade100
                                : const Color(0xFF1A237E).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            hourType,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: hourType.toLowerCase().contains('happy')
                                  ? Colors.orange.shade700
                                  : const Color(0xFF1A237E),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: slots.map((slot) => _buildSlotChip(slot)).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlotChip(Map<String, dynamic> slot) {
    final isSelected = selectedSlots.any((s) =>
    s['court'] == slot['court'] &&
        s['hourType'] == slot['hourType'] &&
        s['time'] == slot['time']);
    final isSoldOut = (slot['price'] == 0);

    return GestureDetector(
      onTap: isSoldOut ? null : () => toggleSlot(slot),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1A237E)
              : (isSoldOut ? Colors.grey.shade300 : Colors.white),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF1A237E)
                : (isSoldOut ? Colors.grey.shade300 : Colors.grey.shade300),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: const Color(0xFF1A237E).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: isSelected
                      ? Colors.white
                      : (isSoldOut ? Colors.grey : Colors.grey.shade600),
                ),
                const SizedBox(width: 4),
                Text(
                  slot['time'],
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : (isSoldOut ? Colors.grey : Colors.black87),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              isSoldOut ? "Sold Out" : "₹${slot['price']}",
              style: TextStyle(
                color: isSelected
                    ? Colors.white70
                    : (isSoldOut ? Colors.grey : Colors.grey.shade600),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedSlotsList() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade100,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle,
                color: Colors.green.shade600,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                "Selected Slots",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade700,
                ),
              ),
              const Spacer(),
              Text(
                "${selectedSlots.length} slot${selectedSlots.length > 1 ? 's' : ''}",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.green.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            children: selectedSlots.map((slot) => _buildSelectedSlotItem(slot)).toList(),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Total Amount",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade700,
                  ),
                ),
                Text(
                  "₹$totalPrice",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget _buildSelectedSlotItem(Map<String, dynamic> slot) {
  //   return Container(
  //     margin: const EdgeInsets.only(bottom: 8),
  //     padding: const EdgeInsets.all(12),
  //     decoration: BoxDecoration(
  //       color: Colors.white,
  //       borderRadius: BorderRadius.circular(8),
  //       border: Border.all(color: Colors.green.shade200),
  //     ),
  //     child: Row(
  //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //       children: [
  //         Expanded(
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               Text(
  //                 slot['court'],
  //                 style: const TextStyle(
  //                   fontSize: 14,
  //                   fontWeight: FontWeight.w600,
  //                   color: Colors.black87,
  //                 ),
  //               ),
  //               const SizedBox(height: 4),
  //               Row(
  //                 children: [
  //                   Icon(
  //                     Icons.access_time,
  //                     size: 16,
  //                     color: Colors.grey.shade600,
  //                   ),
  //                   const SizedBox(width: 4),
  //                   Text(
  //                     slot['time'],
  //                     style: TextStyle(
  //                       fontSize: 13,
  //                       color: Colors.grey.shade600,
  //                     ),
  //                   ),
  //                   const SizedBox(width: 16),
  //                   Icon(
  //                     Icons.category,
  //                     size: 16,
  //                     color: Colors.grey.shade600,
  //                   ),
  //                   const SizedBox(width: 4),
  //                   Text(
  //                     slot['hourType'],
  //                     style: TextStyle(
  //                       fontSize: 13,
  //                       color: Colors.grey.shade600,
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ],
  //           ),
  //         ),
  //         Text(
  //           "₹${slot['price']}",
  //           style: const TextStyle(
  //             fontSize: 16,
  //             fontWeight: FontWeight.w600,
  //             color: Colors.black87,
  //           ),
  //         ),
  //         const SizedBox(width: 12),
  //         GestureDetector(
  //           onTap: () => toggleSlot(slot),
  //           child: Container(
  //             padding: const EdgeInsets.all(6),
  //             decoration: BoxDecoration(
  //               color: Colors.red.shade100,
  //               borderRadius: BorderRadius.circular(6),
  //             ),
  //             child: Icon(
  //               Icons.close,
  //               size: 16,
  //               color: Colors.red.shade600,
  //             ),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }
  Widget _buildSelectedSlotItem(Map<String, dynamic> slot) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left side - details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slot['court'] ?? '',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        slot['time'] ?? '',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.category, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        slot['hourType'] ?? '',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Right side - Price + Close button
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "₹${slot['price'] ?? ''}",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => toggleSlot(slot),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.close, size: 16, color: Colors.red.shade600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: selectedSlots.isEmpty
                    ? Colors.grey.shade400
                    : const Color(0xFF1A237E),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: selectedSlots.isEmpty ? 0 : 2,
              ),
                onPressed: selectedSlots.isEmpty
                    ? null
                    : () async {
                  try {
                    final loggedIn = await ApiService.isLoggedIn();
                    if (loggedIn) {
                      // Get user details for payment
                      final userDetails = ApiService.currentUser;

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PaymentScreen(
                            bookingDetails: {
                              "location": widget.location,
                              "game": widget.game,
                              "slots": selectedSlots,
                              "price": totalPrice, // Changed from totalPrice to price
                              "date": DateFormat('yyyy-MM-dd').format(_selectedDay),
                              "phone": userDetails?['phone'] ?? '', // Add phone for Razorpay
                              "cash": 0, // Initialize cash amount
                            },
                          ),
                        ),
                      );
                    } else {
                      // Show login dialog or navigate to login
                      _showNotLoggedInPopup();
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Error: $e"),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                        margin: EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    );
                  }
                },


              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (selectedSlots.isNotEmpty) ...[
                    Text(
                      "₹$totalPrice • ",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                  Text(
                    selectedSlots.isEmpty
                        ? "Select slots to proceed"
                        : "Proceed to Payment",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  if (selectedSlots.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward,
                      color: Colors.white,
                      size: 20,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

// Add this helper method to your class
//   void _showLoginRequiredDialog() {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(16),
//         ),
//         title: Row(
//           children: [
//             Icon(Icons.login, color: Colors.blue, size: 28),
//             SizedBox(width: 12),
//             Text(
//               "Login Required",
//               style: TextStyle(
//                 fontSize: 18,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//           ],
//         ),
//         content: Text(
//           "Please log in to continue with your booking.",
//           style: TextStyle(fontSize: 16),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text("Cancel"),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               Navigator.pop(context);
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(
//                   builder: (_) => const LoginScreen(),
//                 ),
//               );
//             },
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.blue,
//               foregroundColor: Colors.white,
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(8),
//               ),
//             ),
//             child: Text("Login"),
//           ),
//         ],
//       ),
//     );
//   }
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
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.pop(context); // Close popup
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
      );
    });
  }

  // void _showNotLoggedInPopup() {
  //   showDialog(
  //     context: context,
  //     barrierDismissible: false,
  //     builder: (_) => AlertDialog(
  //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  //       title: const Text("Not Logged In"),
  //       content: Column(
  //         mainAxisSize: MainAxisSize.min,
  //         children: const [
  //           Icon(Icons.warning_amber_rounded, size: 50, color: Colors.orange),
  //           SizedBox(height: 16),
  //           Text(
  //             "You are not logged in.\nRedirecting to Login Screen...",
  //             textAlign: TextAlign.center,
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  //
  //   Future.delayed(const Duration(seconds: 3), () {
  //     if (!mounted) return;
  //     Navigator.pop(context);  // Close the popup
  //     Navigator.pushAndRemoveUntil(
  //       context,
  //       MaterialPageRoute(builder: (context) => LoginScreen()),
  //           (route) => false,
  //     );
  //   });
  // }

}

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
//   String? selectedCourt;
//   String? selectedHourType;
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
//   List<String> _getCourtNames() {
//     final names = courts.map((s) => s['court'].toString()).toSet().toList();
//     names.sort();
//     return names;
//   }
//
//   List<String> _getHourTypesForCourt(String? court) {
//     if (court == null) return [];
//     final hourTypes = courts
//         .where((s) => s['court'] == court)
//         .map((s) => s['hourType'].toString())
//         .toSet()
//         .toList();
//     hourTypes.sort();
//     return hourTypes;
//   }
//
//   List<Map<String, dynamic>> _getSlotsForCourtAndHour(
//       String? court, String? hourType) {
//     if (court == null || hourType == null) return [];
//     final list = courts
//         .where((s) => s['court'] == court && s['hourType'] == hourType)
//         .toList();
//     list.sort((a, b) => a['time'].toString().compareTo(b['time'].toString()));
//     return list;
//   }
//
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
