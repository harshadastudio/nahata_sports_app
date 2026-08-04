import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:nahata_app/core/network/http_logged.dart' as http;

// class BlockSlotsScreen extends StatefulWidget {
//   const BlockSlotsScreen({super.key});
//
//   @override
//   State<BlockSlotsScreen> createState() => _BlockSlotsScreenState();
// }
//
// class _BlockSlotsScreenState extends State<BlockSlotsScreen> {
//   final String baseUrl = "https://nahatasports.com/admin/api";
//
//   DateTime selectedDate = DateTime.now();
//   bool loading = false;
//
//   List<dynamic> blockedSlots = [];
//
//   final courtController = TextEditingController();
//   final slotController = TextEditingController();
//   final reasonController = TextEditingController();
//
//   @override
//   void initState() {
//     super.initState();
//     fetchBlockedSlots();
//   }
//
//   Future<void> fetchBlockedSlots() async {
//     setState(() => loading = true);
//
//     try {
//       final url = Uri.parse(
//         "$baseUrl/blocked-slots?date=${selectedDate.toString().split(' ')[0]}",
//       );
//
//       final response = await http.get(url);
//       final data = jsonDecode(response.body);
//
//       if (data["status"] == true) {
//         blockedSlots = data["blocked_slots"] ?? [];
//       }
//     } catch (e) {
//       debugPrint("Error fetching slots: $e");
//     }
//
//     setState(() => loading = false);
//   }
//
//   Future<void> blockSlot() async {
//     Navigator.pop(context);
//
//     final body = {
//       "date": selectedDate.toString().split(' ')[0],
//       "court_name": courtController.text,
//       "slot_time": slotController.text,
//       "reason": reasonController.text,
//     };
//
//     await http.post(
//       Uri.parse("$baseUrl/block-slot"),
//       body: jsonEncode(body),
//       headers: {"Content-Type": "application/json"},
//     );
//
//     fetchBlockedSlots();
//   }
//
//   Future<void> unblockSlot(slot) async {
//     final body = {
//       "date": selectedDate.toString().split(' ')[0],
//       "court_name": slot["court_name"],
//       "slot_time": slot["slot_time"],
//       "reason": slot["reason"] ?? "-",
//     };
//
//     await http.post(
//       Uri.parse("$baseUrl/unblock-slot"),
//       body: jsonEncode(body),
//       headers: {"Content-Type": "application/json"},
//     );
//
//     fetchBlockedSlots();
//   }
//
//   void showBlockDialog() {
//     showDialog(
//       context: context,
//       builder: (_) => AlertDialog(
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//         title: const Text(
//           "Block Slot",
//           style: TextStyle(fontWeight: FontWeight.bold),
//         ),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             _dialogInput(courtController, "Court Name"),
//             _dialogInput(slotController, "Slot Time"),
//             _dialogInput(reasonController, "Reason"),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text("Cancel"),
//           ),
//           ElevatedButton(
//             onPressed: blockSlot,
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Color(0xFF0A198D),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(8),
//               ),
//             ),
//             child: const Text("Block",style: TextStyle(color: Colors.white),),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _dialogInput(TextEditingController c, String label) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 12),
//       child: TextField(
//         controller: c,
//         decoration: InputDecoration(
//           labelText: label,
//           filled: true,
//           fillColor: Colors.grey.shade100,
//           border: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(12),
//           ),
//         ),
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final dateStr = selectedDate.toString().split(' ')[0];
//
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text(
//           "Blocked Slots",
//           style: TextStyle(fontWeight: FontWeight.bold),
//         ),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.add_box_rounded),
//             onPressed: showBlockDialog,
//           ),
//         ],
//       ),
//
//       body: Stack(
//         children: [
//           Column(
//             children: [
//               // --- Date Selector Card ---
//               Padding(
//                 padding: const EdgeInsets.all(16.0),
//                 child: Material(
//                   elevation: 4,
//                   borderRadius: BorderRadius.circular(16),
//                   child: Container(
//                     padding: const EdgeInsets.all(14),
//                     decoration: BoxDecoration(
//                       borderRadius: BorderRadius.circular(16),
//                       color: Colors.white,
//                     ),
//                     child: Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         Text(
//                           "Date: $dateStr",
//                           style: const TextStyle(
//                             fontSize: 16,
//                             fontWeight: FontWeight.w600,
//                           ),
//                         ),
//                         ElevatedButton.icon(
//                           onPressed: () async {
//                             final picked = await showDatePicker(
//                               context: context,
//                               initialDate: selectedDate,
//                               firstDate: DateTime(2023),
//                               lastDate: DateTime(2030),
//                             );
//                             if (picked != null) {
//                               selectedDate = picked;
//                               fetchBlockedSlots();
//                             }
//                           },
//                           icon: const Icon(Icons.calendar_today),
//                           label: const Text("Change"),
//                           style: ElevatedButton.styleFrom(
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(12),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ),
//
//               // --- List of Blocked Slots ---
//               Expanded(
//                 child: blockedSlots.isEmpty
//                     ? const Center(
//                   child: Text(
//                     "No blocked slots found",
//                     style: TextStyle(fontSize: 16),
//                   ),
//                 )
//                     : ListView.builder(
//                   padding: const EdgeInsets.symmetric(horizontal: 16),
//                   itemCount: blockedSlots.length,
//                   itemBuilder: (_, i) {
//                     final slot = blockedSlots[i];
//
//                     return Card(
//                       elevation: 5,
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(16),
//                       ),
//                       margin: const EdgeInsets.symmetric(vertical: 10),
//                       child: Padding(
//                         padding: const EdgeInsets.all(14),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               slot["court_name"],
//                               style: const TextStyle(
//                                 fontWeight: FontWeight.bold,
//                                 fontSize: 18,
//                               ),
//                             ),
//                             const SizedBox(height: 6),
//
//                             Text(
//                               "Slot: ${slot["slot_time"]}",
//                               style: const TextStyle(fontSize: 15),
//                             ),
//                             const SizedBox(height: 4),
//
//                             Text(
//                               "Reason: ${slot["reason"]}",
//                               style: const TextStyle(
//                                 fontSize: 15,
//                                 color: Colors.redAccent,
//                               ),
//                             ),
//
//                             const SizedBox(height: 10),
//
//                             Align(
//                               alignment: Alignment.centerRight,
//                               child: ElevatedButton.icon(
//                                 onPressed: () => unblockSlot(slot),
//                                 icon: const Icon(Icons.lock_open),
//                                 label: const Text("Unblock"),
//                                 style: ElevatedButton.styleFrom(
//                                   backgroundColor: Colors.green,
//                                   shape: RoundedRectangleBorder(
//                                     borderRadius: BorderRadius.circular(12),
//                                   ),
//                                 ),
//                               ),
//                             )
//                           ],
//                         ),
//                       ),
//                     );
//                   },
//                 ),
//               ),
//             ],
//           ),
//
//           // Loading Overlay
//           if (loading)
//             Container(
//               color: Colors.black.withOpacity(0.3),
//               child: const Center(
//                 child: CircularProgressIndicator(),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BlockSlotsScreen extends StatefulWidget {
  const BlockSlotsScreen({super.key});

  @override
  State<BlockSlotsScreen> createState() => _BlockSlotsScreenState();
}

class _BlockSlotsScreenState extends State<BlockSlotsScreen> {
  DateTime? selectedDate;
  String? selectedCourt;

  final List<String> courts = [
    'Badminton Court 1',
    'Badminton Court 2',
    'Badminton Court 3',
    'Badminton Court 4',
    'Pickle Ball (Indoor)',
    'Basketball Court',
    'Cricket Nets',
  ];

  List<CourtSlot> slots = [];
  bool isLoading = false;
  String? errorMessage;

  Future<void> fetchSlots() async {
    if (selectedDate == null || selectedCourt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select date and court")),
      );
      return;
    }

    setState(() {
      isLoading = true;
      slots.clear();
      errorMessage = null;
    });

    final date = DateFormat('yyyy-MM-dd').format(selectedDate!);
    final court = Uri.encodeComponent(selectedCourt!);

    final url =
        'https://nahatasports.com/api/fetchslots?date=$date&court=$court';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);

        final monthKey = date.substring(0, 7); // yyyy-MM
        final dayData =
        decoded['data']?[monthKey]?[date]?[selectedCourt];

        if (dayData != null) {
          slots = (dayData as List)
              .map((e) => CourtSlot.fromJson(e))
              .toList();
        } else {
          errorMessage = "No slots available";
        }
      } else {
        errorMessage = "Server error";
      }
    } catch (e) {
      errorMessage = "Something went wrong";
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  Widget _dateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Select Date",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: _pickDate,
          child: Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selectedDate == null
                        ? "mm/dd/yyyy"
                        : DateFormat('MM/dd/yyyy')
                        .format(selectedDate!),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color:
                      selectedDate == null ? Colors.grey : Colors.black,
                    ),
                  ),
                ),
                const Icon(Icons.calendar_today, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _courtField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Select Court",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          isExpanded: true,
          // 🔥 IMPORTANT
          value: selectedCourt,
          hint: const Text("Select Court"),
          items: courts
              .map(
                (court) =>
                DropdownMenuItem(
                  value: court,
                  child: Text(
                    court,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
          )
              .toList(),
          onChanged: (value) {
            setState(() {
              selectedCourt = value;
            });
          },
          decoration: InputDecoration(
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _fetchButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFF0A198D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onPressed: fetchSlots,

        child: const Text(
          "Fetch Slots",
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _slotsHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Slots for $selectedCourt on ${DateFormat('dd/MM/yyyy').format(selectedDate!)}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: _blockSelectedSlots,
              child: const Text(
                'Block Selected',
                style: TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(width: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: _unblockSelectedSlots,
              child: const Text(
                'Unblock Selected',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ],
    );
  }


  Widget _slotsTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 40,
        headingRowColor: MaterialStateProperty.all(Colors.grey.shade100),
        columns: const [
          // DataColumn(label: Text('Select')),
          DataColumn(label: Text('Time')),
          DataColumn(label: Text('Price')),
          DataColumn(label: Text('Type')),
          DataColumn(label: Text('Status')),
        ],
        rows: slots.map((slot) {
          return DataRow(
            selected: slot.isSelected,
            onSelectChanged: (value) {
              setState(() {
                slot.isSelected = value ?? false;
              });
            },
            cells: [
              DataCell(Text(slot.time)),
              DataCell(Text(slot.price.toString())),
              DataCell(Text(slot.type)),
              DataCell(_statusBadge(slot)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _statusBadge(CourtSlot slot) {
    Color color;
    String text;

    if (slot.blocked) {
      color = Colors.grey;
      text = 'Blocked';
    } else if (slot.booked) {
      color = Colors.red;
      text = 'Booked';
    } else {
      color = Colors.green;
      text = 'Available';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  Future<void> _blockSelectedSlots() async {
    final selected = slots.where((s) => s.isSelected).toList();
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select slots to block")),
      );
      return;
    }

    final slotTimes = selected.map((e) => e.time).toList();

    final body = {
      "court_name": selectedCourt,
      "date": DateFormat('yyyy-MM-dd').format(selectedDate!),
      "slot_times": slotTimes,
    };

    try {
      final response = await http.post(
        Uri.parse('https://nahatasports.com/admin/api/block-bulk-slot'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      final decoded = jsonDecode(response.body);

      if (response.statusCode == 200 && decoded['status'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(decoded['message'])),
        );

        // Refresh slots
        fetchSlots();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to block slots")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Something went wrong")),
      );
    }
  }

  Future<void> _unblockSelectedSlots() async {
    final selected = slots.where((s) => s.isSelected).toList();
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select slots to unblock")),
      );
      return;
    }

    final slotTimes = selected.map((e) => e.time).toList();

    final body = {
      "court_name": selectedCourt,
      "date": DateFormat('yyyy-MM-dd').format(selectedDate!),
      "slot_times": slotTimes,
    };

    try {
      final response = await http.post(
        Uri.parse('https://nahatasports.com/admin/api/unblock-bulk-slot'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      final decoded = jsonDecode(response.body);

      if (response.statusCode == 200 && decoded['status'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(decoded['message'])),
        );

        // Refresh slots
        fetchSlots();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to unblock slots")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Something went wrong")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F6FA),
      appBar: AppBar(
        title: const Text("Block Court Slots"),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            /// 🔹 FILTER CARD
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    bool isMobile = constraints.maxWidth < 700;

                    return isMobile
                        ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _dateField(),
                        const SizedBox(height: 12),
                        _courtField(),
                        const SizedBox(height: 16),
                        _fetchButton(),
                      ],
                    )
                        : Row(
                      children: [
                        Expanded(child: _dateField()),
                        const SizedBox(width: 16),
                        Expanded(child: _courtField()),
                        const SizedBox(width: 16),
                        SizedBox(width: 160, child: _fetchButton()),
                      ],
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 16),

            /// 🔹 LOADER
            if (isLoading)
              const Center(child: CircularProgressIndicator()),

            /// 🔹 ERROR
            if (errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),

            /// 🔹 TABLE HEADER + TABLE
            if (!isLoading && slots.isNotEmpty && selectedDate != null)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _slotsHeader(),
                    const SizedBox(height: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        child: _slotsTable(),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
  class CourtSlot {
  final String time;
  final int price;
  final String type;
  final bool booked;
  final bool blocked;
  final bool available;

  bool isSelected; // 👈 NEW

  CourtSlot({
    required this.time,
    required this.price,
    required this.type,
    required this.booked,
    required this.blocked,
    required this.available,
    this.isSelected = false,
  });

  factory CourtSlot.fromJson(Map<String, dynamic> json) {
    return CourtSlot(
      time: json['time'],
      price: json['price'],
      type: json['type'],
      booked: json['booked'],
      blocked: json['blocked'],
      available: json['available'],
    );
  }
}
