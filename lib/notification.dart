import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'bottombar/Custombottombar.dart';
import 'core/config/api_config.dart';
import 'core/network/api_client.dart';
import 'core/network/api_exception.dart';

/// The signed-in user's own notification inbox.
///
/// Reads `GET /notifications` on the JWT backend through [ApiClient], so the
/// call carries the access token and refreshes it when it has expired.
///
/// The old version hit `https://nahatasports.com/api/notifications/status` —
/// the *website* host, and a path the backend has never served. The site
/// answers any unknown path with its React `index.html`, so the app got a 200
/// carrying HTML and blew up decoding it. Nothing was wrong with the server.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<Map<String, dynamic>> notifications = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    fetchNotifications();
  }

  Future<void> fetchNotifications() async {
    if (mounted) setState(() => error = null);

    try {
      final response = await ApiClient.instance.get(
        ApiEndpoints.notifications,
        query: const {'page': 1, 'limit': 50},
      );

      if (!response.isOk) throw response.toException();

      // A 200 whose body is not JSON never came from the API — a catch-all page
      // or a captive portal answered instead. Saying so beats rendering an
      // inbox that looks empty. (This is precisely what the old wrong URL hit.)
      final body = response.data;
      if (body is! Map) {
        throw const ServerException('Notifications are unavailable right now.');
      }

      // `{success: true, data: [...], pagination: {...}}` — the rows sit
      // directly under `data`, and the server already sorts them newest first.
      final rows = body['data'];

      if (!mounted) return;
      setState(() {
        notifications = rows is List
            ? rows
                .whereType<Map>()
                .map((row) => Map<String, dynamic>.from(row))
                .toList()
            : <Map<String, dynamic>>[];
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        error = e is ApiException
            ? e.message
            : 'Could not load your notifications. Please try again.';
      });
    }
  }

  /// `sentAt`, falling back to the row's creation time.
  DateTime? _sentAt(Map<String, dynamic> notif) {
    final raw = notif['sentAt'] ?? notif['createdAt'] ?? notif['created_at'];
    return raw is String ? DateTime.tryParse(raw) : null;
  }

  /// The notification's `type` ENUM, drawn as the icon beside it.
  (IconData, Color) _badge(Map<String, dynamic> notif) {
    switch ((notif['type'] ?? '').toString().toLowerCase()) {
      case 'booking':
        return (Icons.event_available_rounded, const Color(0xFF2563EB));
      case 'payment':
        return (Icons.payments_rounded, const Color(0xFF059669));
      case 'alert':
        return (Icons.warning_amber_rounded, const Color(0xFFDC2626));
      case 'promotion':
        return (Icons.local_offer_rounded, const Color(0xFFD97706));
      case 'feedback':
        return (Icons.rate_review_rounded, const Color(0xFF6C52E8));
      default:
        return (Icons.notifications_rounded, const Color(0xFF1A237E));
    }
  }

  Widget buildNotificationItem(Map<String, dynamic> notif) {
    final sentAt = _sentAt(notif);
    final (icon, tone) = _badge(notif);
    final isRead = notif['isRead'] == true;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: tone.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 22, color: tone),
        ),
        title: Text(
          (notif['title'] ?? '').toString(),
          style: TextStyle(
            fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text((notif['message'] ?? '').toString()),
            const SizedBox(height: 4),
            Text(
              sentAt == null ? '' : timeago.format(sentAt),
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        trailing: isRead
            ? null
            : Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: Color(0xFF1A237E),
                  shape: BoxShape.circle,
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            // Navigate to CustomBottomNav
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const CustomBottomNav()),
              (route) => false,
            );
          },
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.black87,
              size: 18,
            ),
          ),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // A failure that says so and offers a retry, rather than a screen that
    // looks permanently empty behind a snackbar the user already missed.
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                size: 44,
                color: Colors.black26,
              ),
              const SizedBox(height: 14),
              Text(
                error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54, height: 1.4),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () {
                  setState(() => isLoading = true);
                  fetchNotifications();
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try again'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1A237E),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (notifications.isEmpty) {
      // Scrollable, so pull-to-refresh still works on an empty inbox.
      return RefreshIndicator(
        onRefresh: fetchNotifications,
        child: ListView(
          children: const [
            SizedBox(height: 140),
            Center(child: Text('No notifications')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: fetchNotifications,
      child: ListView.builder(
        itemCount: notifications.length,
        itemBuilder: (context, index) =>
            buildNotificationItem(notifications[index]),
      ),
    );
  }
}
