

import 'package:flutter/material.dart';


class CoachDashboardScreen extends StatelessWidget {
  const CoachDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: Colors.yellow[200], // background like screenshot
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text("Coach Dashboard", style: TextStyle(color: Colors.black)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // --------- Role Selector ---------
              // Card(
              //   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              //   child: Padding(
              //     padding: const EdgeInsets.all(12),
              //     child: Row(
              //       mainAxisAlignment: MainAxisAlignment.spaceAround,
              //       children: [
              //         _roleButton("Student/Parent", Icons.person, false),
              //         _roleButton("Coach", Icons.sports, true),
              //         _roleButton("Office Admin", Icons.admin_panel_settings, false),
              //         _roleButton("Security", Icons.security, false),
              //         _roleButton("Manager/Owner", Icons.manage_accounts, false),
              //       ],
              //     ),
              //   ),
              // ),

              const SizedBox(height: 16),

              // --------- Dashboard Heading ---------
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: const [
                      // Text("Coach Dashboard", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      // SizedBox(height: 6),
                      Text("Mark provisional fee payments for office confirmation",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black54)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // --------- Stats Row ---------
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children:  [
                  _statCard(Icons.people, "4", "Total Students", Colors.blue),
                  _statCard(Icons.check_circle, "2", "Fees Paid", Colors.green),
                  _statCard(Icons.access_time, "0", "Pending", Colors.orange),
                  _statCard(Icons.error, "2", "Overdue", Colors.red),
                ],
              ),

              const SizedBox(height: 16),

              // --------- Search & Filters ---------
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      TextField(
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search, color: Colors.black),
                          hintText: "Search students by name or sport...",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey[200],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _filterChip("All", true),
                          _filterChip("Paid", false),
                          _filterChip("Pending", false),
                          _filterChip("Overdue", false),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // --------- Student List ---------
              _studentCard("Alex Johnson", "Badminton • Evening (5:00–7:00 PM)", "Paid",
                  "Due: 2024-03-15 • \$150", Colors.green, "Confirmed"),
              _studentCard("Sarah Davis", "Basketball • Morning (8:00–10:00 AM)", "Overdue",
                  "Due: 2024-01-15 • \$120", Colors.red, "Mark as Paid"),
              _studentCard("Mike Wilson", "Badminton • Evening (6:00–8:00 PM)", "Overdue",
                  "Due: 2024-02-01 • \$150", Colors.red, "Mark as Paid"),
            ],
          ),
        ),
      ),
    );
  }

  // --------- Helper Widgets ---------
  static Widget _roleButton(String label, IconData icon, bool isSelected) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: isSelected ? Colors.green : Colors.blue,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10), // reduce padding
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () {},
          icon: Icon(icon, size: 14), // smaller icon
          label: Flexible( // ensures text wraps instead of overflow
            child: Text(
              label,
              style: const TextStyle(fontSize: 11), // smaller text
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ),
      ),
    );
  }


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
              Text(label, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _filterChip(String label, bool isSelected) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: Colors.blue,
      onSelected: (_) {},
    );
  }

  static Widget _studentCard(String name, String subtitle, String status,
      String due, Color statusColor, String actionText) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(radius: 24, backgroundColor: Colors.grey),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(subtitle),
                  const SizedBox(height: 4),
                  Text(due, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(status,
                      style: TextStyle(color: statusColor, fontSize: 12)),
                ),
                const SizedBox(height: 6),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(90, 30),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(actionText, style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

}

