import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
class AdminNotificationService {
  static const baseUrl = "https://nahatasports.com/api/admin";

  static Future<Map<String, dynamic>> fetchNotifications() async {
    final response = await http
        .get(Uri.parse("$baseUrl/notifications"))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception("Failed to fetch notifications");
    }

    return jsonDecode(response.body);
  }

  static Future<void> markAsRead(String id) async {
    await http.post(Uri.parse("$baseUrl/notifications/read/$id"));
  }

  static Future<void> markAllAsRead() async {
    await http.post(Uri.parse("$baseUrl/notifications/read-all"));
  }
}

// class AdminNotificationService {
//   static const baseUrl = "https://nahatasports.com/api/admin";
//
//   static Future<Map<String, dynamic>>   fetchNotifications() async {
//     final response =
//     await http.get(Uri.parse("$baseUrl/notifications"));
//
//     return jsonDecode(response.body);
//   }
//
//   static Future<void> markAsRead(String id) async {
//     await http.post(
//       Uri.parse("$baseUrl/notifications/read/$id"),
//     );
//   }
//
//   static Future<void> markAllAsRead() async {
//     await http.post(
//       Uri.parse("$baseUrl/notifications/read-all"),
//     );
//   }
// }

class AdminNotification {
  final String id;
  final String title;
  final String message;
  final String bookingId;
  final bool isRead;
  final String createdAt;

  AdminNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.bookingId,
    required this.isRead,
    required this.createdAt,
  });

  factory AdminNotification.fromJson(Map<String, dynamic> json) {
    return AdminNotification(
      id: json['id'],
      title: json['title'],
      message: json['message'],
      bookingId: json['booking_id'],
      isRead: json['is_read'] == "1",
      createdAt: json['created_at'],
    );
  }
}
//"is_read": "0"   // unread
// "is_read": "1"   // read


// class AdminNotificationsScreen extends StatefulWidget {
//   const AdminNotificationsScreen({super.key});
//
//   @override
//   State<AdminNotificationsScreen> createState() =>
//       _AdminNotificationsScreenState();
// }
//
//
// class _AdminNotificationsScreenState
//     extends State<AdminNotificationsScreen> {
//   List<AdminNotification> notifications = [];
//   bool loading = true;
//
//   @override
//   void initState() {
//     super.initState();
//     _fetch();
//   }
//
//   Future<void> _fetch() async {
//     final res = await AdminNotificationService.fetchNotifications();
//     setState(() {
//       notifications = (res['data'] as List)
//           .map((e) => AdminNotification.fromJson(e))
//           .toList();
//       loading = false;
//     });
//   }
//
//   Future<void> _readAll() async {
//     await AdminNotificationService.markAllAsRead();
//     _fetch();
//   }
//
//   Future<void> _onNotificationTap(AdminNotification n) async {
//     // ✅ mark as read only if unread
//     if (!n.isRead) {
//       await AdminNotificationService.markAsRead(n.id);
//     }
//
//     // ✅ open detail screen
//     await Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (_) => NotificationDetailScreen(notification: n),
//       ),
//     );
//
//     // ✅ refresh list & badge after return
//     _fetch();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("Notifications"),
//         actions: [
//           TextButton(
//             onPressed: _readAll,
//             child: const Text(
//               "Read All",
//               style: TextStyle(color: Colors.white),
//             ),
//           )
//         ],
//       ),
//       body: loading
//           ? const Center(child: CircularProgressIndicator())
//           : notifications.isEmpty
//           ? Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: const [
//             Icon(
//               Icons.notifications_off_outlined,
//               size: 80,
//               color: Colors.grey,
//             ),
//             SizedBox(height: 16),
//             Text(
//               "No notifications yet",
//               style: TextStyle(
//                 fontSize: 16,
//                 color: Colors.grey,
//                 fontWeight: FontWeight.w500,
//               ),
//             ),
//           ],
//         ),
//       )
//           : ListView.builder(
//         itemCount: notifications.length,
//         itemBuilder: (context, index) {
//           final n = notifications[index];
//
//           return ListTile(
//             tileColor:
//             n.isRead ? Colors.white : Colors.blue.shade50,
//             title: Text(
//               n.title,
//               style: TextStyle(
//                 fontWeight: n.isRead
//                     ? FontWeight.normal
//                     : FontWeight.bold,
//               ),
//             ),
//             subtitle: Text(n.message),
//             trailing: Text(
//               n.createdAt.substring(0, 16),
//               style: const TextStyle(fontSize: 11),
//             ),
//             onTap: () => _onNotificationTap(n),
//           );
//         },
//       ),
//
//       // body: loading
//       //     ? const Center(child: CircularProgressIndicator())
//       //     : ListView.builder(
//       //   itemCount: notifications.length,
//       //   itemBuilder: (context, index) {
//       //     final n = notifications[index];
//       //
//       //     return ListTile(
//       //       tileColor:
//       //       n.isRead ? Colors.white : Colors.blue.shade50,
//       //       title: Text(
//       //         n.title,
//       //         style: TextStyle(
//       //           fontWeight: n.isRead
//       //               ? FontWeight.normal
//       //               : FontWeight.bold,
//       //         ),
//       //       ),
//       //       subtitle: Text(n.message),
//       //       trailing: Text(
//       //         n.createdAt.substring(0, 16),
//       //         style: const TextStyle(fontSize: 11),
//       //       ),
//       //       onTap: () => _onNotificationTap(n), // 🔥 UPDATED
//       //     );
//       //   },
//       // ),
//     );
//   }
// }

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState
    extends State<AdminNotificationsScreen>
    with SingleTickerProviderStateMixin {
  List<AdminNotification> notifications = [];
  bool loading = true;

  late AnimationController _controller;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _fade = Tween<double>(begin: 0, end: 1).animate(_controller);

    _fetch();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    final res = await AdminNotificationService.fetchNotifications();
    setState(() {
      notifications = (res['data'] as List)
          .map((e) => AdminNotification.fromJson(e))
          .toList();
      loading = false;
    });

    _controller.forward(from: 0);
  }

  Future<void> _refresh() async {
    loading = true;
    setState(() {});
    await _fetch();
  }

  Future<void> _readAll() async {
    await AdminNotificationService.markAllAsRead();
    await _fetch();
  }

  Future<void> _onNotificationTap(AdminNotification n) async {
    if (!n.isRead) {
      await AdminNotificationService.markAsRead(n.id);
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotificationDetailScreen(notification: n),
      ),
    );

    _fetch();
  }

  bool _isNew(AdminNotification n) {
    final created =
    DateTime.parse(n.createdAt.replaceAll(' ', 'T'));
    return DateTime.now().difference(created).inSeconds < 5 &&
        !n.isRead;
  }

  Widget _emptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(
                Icons.notifications_active_outlined,
                size: 80,
                color: Colors.grey,
              ),
              SizedBox(height: 16),
              Text(
                "You're all caught up!",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: 6),
              Text(
                "No new notifications",
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _notificationList() {
    return ListView.builder(
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        final n = notifications[index];

        return FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: ListTile(
              tileColor:
              n.isRead ? Colors.white : Colors.blue.shade50,
              title: _isNew(n)
                  ? TweenAnimationBuilder<double>(
                tween: Tween(begin: -2, end: 2),
                duration:
                const Duration(milliseconds: 400),
                curve: Curves.elasticIn,
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(value, 0),
                    child: child,
                  );
                },
                child: Text(
                  n.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold),
                ),
              )
                  : Text(
                n.title,
                style: TextStyle(
                  fontWeight: n.isRead
                      ? FontWeight.normal
                      : FontWeight.bold,
                ),
              ),
              subtitle: Text(n.message),
              trailing: Text(
                n.createdAt.substring(0, 16),
                style: const TextStyle(fontSize: 11),
              ),
              onTap: () => _onNotificationTap(n),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications"),
        actions: [
          TextButton(
            onPressed: _readAll,
            child: const Text(
              "Read All",
              style: TextStyle(color: Colors.white),
            ),
          )
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _refresh,
        child: notifications.isEmpty
            ? _emptyState()
            : _notificationList(),
      ),
    );
  }
}



class NotificationDetailScreen extends StatefulWidget {
  final AdminNotification notification;

  const NotificationDetailScreen({
    super.key,
    required this.notification,
  });

  @override
  State<NotificationDetailScreen> createState() =>
      _NotificationDetailScreenState();
}

class _NotificationDetailScreenState
    extends State<NotificationDetailScreen> {
  CourtResponse? booking;
  bool loading = true;
  bool loadingMore = false;
  bool hasMore = true;

  int page = 1;
  final int perPage = 10;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadBookings();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 100 &&
          !loadingMore &&
          hasMore &&
          booking == null) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadBookings() async {
    final list = await CourtResponseService.fetchCourtResponses(
      page: page,
      perPage: perPage,
    );

    for (var item in list) {
      if (item.id == widget.notification.bookingId) {
        booking = item;
        hasMore = false;
        break;
      }
    }

    if (list.length < perPage) {
      hasMore = false;
    }

    setState(() => loading = false);
  }

  Future<void> _loadMore() async {
    loadingMore = true;
    page++;

    final list = await CourtResponseService.fetchCourtResponses(
      page: page,
      perPage: perPage,
    );

    for (var item in list) {
      if (item.id == widget.notification.bookingId) {
        booking = item;
        hasMore = false;
        break;
      }
    }

    if (list.length < perPage) {
      hasMore = false;
    }

    setState(() => loadingMore = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Notification Details")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : booking != null
          ? _bookingCard()
          : _searchingView(),
    );
  }

  Widget _searchingView() {
    return ListView(
      controller: _scrollController,
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                hasMore
                    ? "Searching booking details..."
                    : "Booking details not found",
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bookingCard() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.notification.title,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(widget.notification.message),
              const Divider(height: 30),

              _row("Booking ID", booking!.id),
              _row("Court", booking!.courtName),
              _row("Date", booking!.selectedDate),
              _row(
                "Time",
                booking!.slots
                    .map((s) => s.time)
                    .join(", "),
              ),
              _row("Amount", "₹${booking!.amount}"),
              _row("Status", booking!.status),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              "$label:",
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}



class CourtResponse {
  final String id;
  final String courtName;
  final String selectedDate;
  final List<SlotItem> slots;
  final double amount;
  final String status;
  final String? qrCode; // 👈 add this

  CourtResponse({
    required this.id,
    required this.courtName,
    required this.selectedDate,
    required this.slots,
    required this.amount,
    required this.status,
    this.qrCode, // 👈 add this

  });

  factory CourtResponse.fromJson(Map<String, dynamic> json) {
    List<SlotItem> parsedSlots = [];

    final rawSlots = json['slots'];

    try {
      if (rawSlots is String && rawSlots.isNotEmpty) {
        final cleaned = rawSlots
            .trim()
            .replaceAll(RegExp(r'\.+$'), ''); // remove trailing dots

        final decoded = jsonDecode(cleaned);

        if (decoded is List) {
          parsedSlots =
              decoded.map((e) => SlotItem.fromJson(e)).toList();
        }
      } else if (rawSlots is List) {
        parsedSlots =
            rawSlots.map((e) => SlotItem.fromJson(e)).toList();
      }
    } catch (e) {
      parsedSlots = [];
    }

    return CourtResponse(
      id: json['id']?.toString() ?? '',
      courtName: json['court_name']?.toString() ?? '',
      selectedDate: json['selected_date']?.toString() ?? '',
      slots: parsedSlots,
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0,
      status: json['status']?.toString() ?? '',
      qrCode: json['qr_code'], // 👈 add this (will be null if not set)

    );
  }
}

// class CourtResponseService {
//   static const String url =
//       "https://nahatasports.com/api/admin/court-response?page=1&per_page=10";
//
//   static Future<List<CourtResponse>> fetchCourtResponses() async {
//     final response = await http.get(Uri.parse(url));
//     final data = jsonDecode(response.body);
//
//     return (data['data'] as List)
//         .map((e) => CourtResponse.fromJson(e))
//         .toList();
//   }
// }
class CourtResponseService {
  static const String baseUrl =
      "https://nahatasports.com/api/admin/court-response";

  static Future<List<CourtResponse>> fetchCourtResponses({
    required int page,
    int perPage = 10,
  }) async {
    final url = "$baseUrl?page=$page&per_page=$perPage";
    final response = await http.get(Uri.parse(url));
    final json = jsonDecode(response.body);

    return (json['data'] as List)
        .map((e) => CourtResponse.fromJson(e))
        .toList();
  }
}

class SlotItem {
  final String court;
  final String time;

  SlotItem({
    required this.court,
    required this.time,
  });

  factory SlotItem.fromJson(Map<String, dynamic> json) {
    return SlotItem(
      court: json['court'] ?? '',
      time: json['time'] ?? '',
    );
  }
}
