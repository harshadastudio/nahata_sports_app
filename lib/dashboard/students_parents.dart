import 'package:flutter/material.dart';

class StudentsParentsScreen extends StatelessWidget {
  const StudentsParentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Students & Parents"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ Payment Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.yellow[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Payment Confirmed by Coach Sarah on Aug 25, 2025",
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      "PAID",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ✅ Student Info
          Card(
            // margin: const EdgeInsets.all(5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name & ID
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text("SACHIN K", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text("ID: 121", style: TextStyle(fontSize: 16, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Call Parent & WhatsApp
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow[700]),
                        child: const Text("CALL PARENT"),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.chat, color: Colors.white),
                        label: const Text("WHATSAPP"),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Fee Details
                  const Text("FEE DETAILS:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: const [
                      Text("MONTHLY FEE: \$12345.00", style: TextStyle(color: Colors.green)),
                      Text("LAST PAYMENT: 25/08/2025"),
                      Text("NEXT DUE: "),
                    ],
                  ),

                ],
              ),
            ),
          ),
            const SizedBox(height: 10),
            Card(
              color: Colors.indigo[50],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 4,
              child: Center(
                child: Column(
                  children: const [
                    Text("GATE PASS", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Icon(Icons.qr_code, size: 80, color: Colors.grey),
                    SizedBox(height: 4),
                    Text("Gate pass not issued yet."),
                  ],
                ),
              ),
            ),
          // ✅ Quick Actions
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.history, color: Colors.blue),
                    title: const Text("View Payment History"),
                    onTap: () {
                      // Navigate to payment history
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.sports_tennis, color: Colors.green),
                    title: const Text("Book Court & Share Pass"),
                    onTap: () {
                      // Navigate to booking
                    },
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
