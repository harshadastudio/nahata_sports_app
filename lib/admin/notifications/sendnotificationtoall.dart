import 'dart:convert';
import '../../core/utils/app_logger.dart';

import 'package:flutter/material.dart';
import 'package:nahata_app/core/network/http_logged.dart' as http;
import 'package:intl/intl.dart';
class NotificationModel {
  final String id;
  final String title;
  final String message;
  final String sendTo;
  final String sentCount;
  final String failCount;
  final String createdAt;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.sendTo,
    required this.sentCount,
    required this.failCount,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'].toString(),
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      sendTo: json['send_to'] ?? '',
      sentCount: json['sent_count'] ?? '0',
      failCount: json['fail_count'] ?? '0',
      createdAt: json['created_at'] ?? '',
    );
  }
}


class SendNotificationToAll extends StatefulWidget {
  const SendNotificationToAll({super.key});

  @override
  State<SendNotificationToAll> createState() =>
      _SendNotificationToAllState();
}

class _SendNotificationToAllState
    extends State<SendNotificationToAll> {

  final TextEditingController _titleController =
  TextEditingController();
  final TextEditingController _messageController =
  TextEditingController();
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;

  Future<void> saveFcmToken(int userId, String token) async {
    final response = await http.post(
      Uri.parse("https://nahatasports.com/api/save-fcm-token"),
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "user_id": userId,
        "fcm_token": token,
        "platform": "android",
      }),
    );

    final data = jsonDecode(response.body);
    AppLogger.debug('${data['message']}', name: 'sendnotificationtoall');
  }

  Future<void> _sendNotification() async {
    if (_titleController.text.isEmpty ||
        _messageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse("https://nahatasports.com/api/admin/send-notification"),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "title": _titleController.text,
          "message": _messageController.text,
        }),
      );

      final data = jsonDecode(response.body);

      if (data['status'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Notification Sent Successfully")),
        );

        _titleController.clear();
        _messageController.clear();

        // 🔥 Refresh History
        _fetchNotifications();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to send notification")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Something went wrong")),
      );
    }
  }

  Future<void> _fetchNotifications() async {
    try {
      final response = await http.get(
        Uri.parse("https://nahatasports.com/api/admin/users-notifications"),
      );

      final data = jsonDecode(response.body);

      if (data['status'] == true) {
        final List list = data['data'];

        setState(() {
          _notifications =
              list.map((e) => NotificationModel.fromJson(e)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }
  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff5f5f5),
      appBar: AppBar(
        title: const Text("Push Notifications",style: TextStyle(color: Colors.white),),
        backgroundColor: const Color(0xff3f3477),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),

        actions: [

        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            /// ================= SEND NOTIFICATION CARD =================
            _buildSendNotificationCard(),

            const SizedBox(height: 20),

            /// ================= SUMMARY CARDS =================
            _buildSummaryCards(),

            const SizedBox(height: 20),

            /// ================= HISTORY LIST =================
            _buildHistorySection(),
          ],
        ),
      ),
    );
  }

  /// ---------------------------------------------------------
  /// Send Notification Card
  /// ---------------------------------------------------------
  Widget _buildSendNotificationCard() {
    return Card(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            const Text(
              "Send Notification",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,),
            ),

            const SizedBox(height: 15),

            /// Dropdown
            const Text("Send To"),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: "All Users",
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: "All Users",
                  child: Text("All Users"),
                ),
              ],
              onChanged: (value) {},
            ),

            const SizedBox(height: 15),

            /// Title
            const Text("Notification Title"),
            const SizedBox(height: 6),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: "e.g. New Offer Available!",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 15),

            /// Message
            const Text("Message"),
            const SizedBox(height: 6),
            TextField(
              controller: _messageController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: "Write your notification message here...",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff3f3477),
                  padding:
                  const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _sendNotification,
                child: const Text("Send Notification",style: TextStyle(color: Colors.white),),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ---------------------------------------------------------
  /// Summary Cards
  /// ---------------------------------------------------------
  Widget _buildSummaryCards() {

    int total = _notifications.length;

    int delivered = _notifications.fold(
        0, (sum, item) => sum + int.parse(item.sentCount));

    int failed = _notifications.fold(
        0, (sum, item) => sum + int.parse(item.failCount));

    return Row(
      children: [
        Expanded(
          child: _summaryCard(
              total.toString(), "Total", Colors.deepPurple),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _summaryCard(
              delivered.toString(), "Delivered", Colors.green),
        ),
        const SizedBox(width: 10),
        Expanded(
          child:
          _summaryCard(failed.toString(), "Failed", Colors.red),
        ),
      ],
    );
  }

  Widget _summaryCard(
      String number, String title, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: color, width: 5),
        ),
      ),
      child: Column(
        children: [
          Text(
            number,
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color),
          ),
          const SizedBox(height: 5),
          Text(title),
        ],
      ),
    );
  }

  /// ---------------------------------------------------------
  /// Notification History
  /// ---------------------------------------------------------
  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        const Text(
          "Notification History",
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 10),

        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else if (_notifications.isEmpty)
          const Text("No notifications found")
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _notifications.length,
            itemBuilder: (context, index) {

              final item = _notifications[index];

              // Format Date
              DateTime parsedDate =
              DateTime.parse(item.createdAt);
              String formattedDate =
              DateFormat('dd MMM yyyy, hh:mm a')
                  .format(parsedDate);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [

                      Text(
                        "Title: ${item.title}",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold),
                      ),

                      const SizedBox(height: 6),

                      Text("Message: ${item.message}"),

                      const SizedBox(height: 6),

                      Row(
                        mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                        children: [
                          Chip(
                            label: Text(
                              item.sendTo.toUpperCase(),
                            ),
                            backgroundColor: Colors.blue,
                            labelStyle: const TextStyle(
                                color: Colors.white),
                          ),
                          Text(formattedDate),
                        ],
                      ),

                      const SizedBox(height: 8),

                      Row(
                        children: [
                          const Icon(Icons.check_circle,
                              color: Colors.green, size: 18),
                          const SizedBox(width: 4),
                          Text(item.sentCount),

                          const SizedBox(width: 16),

                          const Icon(Icons.cancel,
                              color: Colors.red, size: 18),
                          const SizedBox(width: 4),
                          Text(item.failCount),
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          )
      ],
    );
  }
}