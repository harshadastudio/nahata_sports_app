import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class CoachingEnquiryScreen extends StatefulWidget {
  final int userId;  // Pass user_id dynamically

  const CoachingEnquiryScreen({super.key, required this.userId});

  @override
  State<CoachingEnquiryScreen> createState() => _CoachingEnquiryScreenState();
}

class _CoachingEnquiryScreenState extends State<CoachingEnquiryScreen> {
  bool loading = true;
  List enquiries = [];

  @override
  void initState() {
    super.initState();
    fetchEnquiries();
  }

  Future<void> fetchEnquiries() async {
    final url = Uri.parse(
        "https://nahatasports.com/api/coaching-enquiry?user_id=${widget.userId}");

    try {
      final response = await http.get(url);
      final data = jsonDecode(response.body);

      if (data["status"] == 200) {
        setState(() {
          enquiries = data["enquiries"] ?? [];
          loading = false;
        });
      } else {
        setState(() => loading = false);
      }
    } catch (e) {
      print("Error: $e");
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Coaching Enquiries"),

      ),

      body: loading
          ? const Center(child: CircularProgressIndicator())
          : enquiries.isEmpty
          ? const Center(
        child: Text(
          "No enquiries found.",
          style: TextStyle(fontSize: 16),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: enquiries.length,
        itemBuilder: (context, index) {
          final item = enquiries[index];

          return Card(
            color: Colors.white,
            elevation: 3,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.only(bottom: 16),

            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item["coach_name"] ?? "",
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black),
                  ),
                  const SizedBox(height: 4),

                  Text(
                    "Sport: ${item["sport_name"]}",
                    style: const TextStyle(fontSize: 15),
                  ),
                  const SizedBox(height: 8),

                  Text("User: ${item["user_name"]}"),
                  Text("Email: ${item["user_email"]}"),
                  Text("Contact: ${item["user_contact"]}"),
                  const SizedBox(height: 8),

                  Text(
                    "Enquiry Date: ${item["created_at"]}",
                    style: TextStyle(
                        color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
