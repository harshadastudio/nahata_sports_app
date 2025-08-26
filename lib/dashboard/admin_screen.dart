import 'package:flutter/material.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: Colors.yellow[200],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text("Office Admin Dashboard", style: TextStyle(color: Colors.black)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Chip(
              label: const Text("3 Pending", style: TextStyle(color: Colors.red)),
              backgroundColor: Colors.red.shade50,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---------- Subtitle ----------
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    "Review and confirm fee payments marked by coaches",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ---------- Stats Row ----------
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children:  [
                  _statCard(Icons.access_time, "3", "Pending Confirmations", Colors.orange),
                  _statCard(Icons.check_circle, "12", "Confirmed Today", Colors.green),
                  _statCard(Icons.people, "156", "Total Students", Colors.blue),
                ],
              ),

              const SizedBox(height: 16),

              // ---------- Search ----------
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, color: Colors.black),
                      hintText: "Search by student name, sport, or coach...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ---------- Section Title ----------
              const Text(
                "Payments Awaiting Confirmation",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 8),

              // ---------- Payment Cards ----------
              _paymentCard(
                name: "Sarah Davis",
                sport: "Basketball • Morning (8:00–10:00 AM)",
                id: "STU2024002",
                due: "2024-01-15",
                amount: "\$120",
                coach: "Coach Mike",
                date: "2024-02-10",
              ),
              _paymentCard(
                name: "Mike Wilson",
                sport: "Badminton • Evening (6:00–8:00 PM)",
                id: "STU2024003",
                due: "2024-02-01",
                amount: "\$150",
                coach: "Coach Sarah",
                date: "2024-02-12",
              ),
              _paymentCard(
                name: "Lisa Chen",
                sport: "Tennis • Morning (9:00–11:00 AM)",
                id: "STU2024005",
                due: "2024-02-05",
                amount: "\$180",
                coach: "Coach Mike",
                date: "2024-02-13",
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Helper Widgets ----------
  static Widget _statCard(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 6),
              Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 4),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _paymentCard({
    required String name,
    required String sport,
    required String id,
    required String due,
    required String amount,
    required String coach,
    required String date,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Icon
            const CircleAvatar(radius: 24, backgroundColor: Colors.grey),
            const SizedBox(width: 12),

            // Main Info Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),

                  // Sport
                  Text(sport, style: const TextStyle(color: Colors.black87)),

                  const SizedBox(height: 8),

                  // Buttons Row
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black,
                          side: const BorderSide(color: Colors.blue),
                          minimumSize: const Size(70, 32),
                        ),
                        child: const Text("Reject", style: TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(100, 32),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text("Confirm Payment", style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Marked By Chip
                  Chip(
                    label: Text(
                      "Marked by $coach on $date",
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: Colors.blue[100],
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
