import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class BlockSlotsScreen extends StatefulWidget {
  const BlockSlotsScreen({super.key});

  @override
  State<BlockSlotsScreen> createState() => _BlockSlotsScreenState();
}

class _BlockSlotsScreenState extends State<BlockSlotsScreen> {
  final String baseUrl = "https://nahatasports.com/admin/api";

  DateTime selectedDate = DateTime.now();
  bool loading = false;

  List<dynamic> blockedSlots = [];

  final courtController = TextEditingController();
  final slotController = TextEditingController();
  final reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchBlockedSlots();
  }

  Future<void> fetchBlockedSlots() async {
    setState(() => loading = true);

    try {
      final url = Uri.parse(
        "$baseUrl/blocked-slots?date=${selectedDate.toString().split(' ')[0]}",
      );

      final response = await http.get(url);
      final data = jsonDecode(response.body);

      if (data["status"] == true) {
        blockedSlots = data["blocked_slots"] ?? [];
      }
    } catch (e) {
      debugPrint("Error fetching slots: $e");
    }

    setState(() => loading = false);
  }

  Future<void> blockSlot() async {
    Navigator.pop(context);

    final body = {
      "date": selectedDate.toString().split(' ')[0],
      "court_name": courtController.text,
      "slot_time": slotController.text,
      "reason": reasonController.text,
    };

    await http.post(
      Uri.parse("$baseUrl/block-slot"),
      body: jsonEncode(body),
      headers: {"Content-Type": "application/json"},
    );

    fetchBlockedSlots();
  }

  Future<void> unblockSlot(slot) async {
    final body = {
      "date": selectedDate.toString().split(' ')[0],
      "court_name": slot["court_name"],
      "slot_time": slot["slot_time"],
      "reason": slot["reason"] ?? "-",
    };

    await http.post(
      Uri.parse("$baseUrl/unblock-slot"),
      body: jsonEncode(body),
      headers: {"Content-Type": "application/json"},
    );

    fetchBlockedSlots();
  }

  void showBlockDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Block Slot",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogInput(courtController, "Court Name"),
            _dialogInput(slotController, "Slot Time"),
            _dialogInput(reasonController, "Reason"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: blockSlot,
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF0A198D),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text("Block",style: TextStyle(color: Colors.white),),
          ),
        ],
      ),
    );
  }

  Widget _dialogInput(TextEditingController c, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = selectedDate.toString().split(' ')[0];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Blocked Slots",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box_rounded),
            onPressed: showBlockDialog,
          ),
        ],
      ),

      body: Stack(
        children: [
          Column(
            children: [
              // --- Date Selector Card ---
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.white,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Date: $dateStr",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2023),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              selectedDate = picked;
                              fetchBlockedSlots();
                            }
                          },
                          icon: const Icon(Icons.calendar_today),
                          label: const Text("Change"),
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // --- List of Blocked Slots ---
              Expanded(
                child: blockedSlots.isEmpty
                    ? const Center(
                  child: Text(
                    "No blocked slots found",
                    style: TextStyle(fontSize: 16),
                  ),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: blockedSlots.length,
                  itemBuilder: (_, i) {
                    final slot = blockedSlots[i];

                    return Card(
                      elevation: 5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              slot["court_name"],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 6),

                            Text(
                              "Slot: ${slot["slot_time"]}",
                              style: const TextStyle(fontSize: 15),
                            ),
                            const SizedBox(height: 4),

                            Text(
                              "Reason: ${slot["reason"]}",
                              style: const TextStyle(
                                fontSize: 15,
                                color: Colors.redAccent,
                              ),
                            ),

                            const SizedBox(height: 10),

                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton.icon(
                                onPressed: () => unblockSlot(slot),
                                icon: const Icon(Icons.lock_open),
                                label: const Text("Unblock"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          // Loading Overlay
          if (loading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
