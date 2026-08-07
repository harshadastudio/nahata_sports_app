import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../core/coach_log.dart';
import '../../data/repositories/coach_dashboard_repository_impl.dart';
import '../../domain/entities/coach_notification.dart';
import '../../domain/repositories/coach_dashboard_repository.dart';
import '../state/coach_notifications_controller.dart';
import '../state/coach_view_state.dart';
import '../theme/coach_theme.dart';
import '../widgets/coach_notification_compose_sheet.dart';
import '../widgets/coach_states.dart';

/// The coach's notifications — their inbox, and composing a new one.
///
/// The list is the coach's **own** notifications (`GET /notifications`), which
/// is scoped server-side to the signed-in user. The unscoped
/// `GET /notifications/admin` is not used.
class CoachNotificationsPage extends StatefulWidget {
  const CoachNotificationsPage({super.key, this.repository});

  final CoachDashboardRepository? repository;

  @override
  State<CoachNotificationsPage> createState() => _CoachNotificationsPageState();
}

class _CoachNotificationsPageState extends State<CoachNotificationsPage> {
  late final CoachNotificationsController _controller =
      CoachNotificationsController(
    widget.repository ?? CoachDashboardRepositoryImpl(),
  );

  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    _scroll.addListener(_onScroll);
    _controller.load();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final remaining = _scroll.position.maxScrollExtent - _scroll.position.pixels;
    if (remaining < 400) _controller.loadMore();
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _compose() async {
    CoachLog.ui('Compose notification tapped');

    final sent = await showCoachNotificationComposeSheet(
      context: context,
      controller: _controller,
    );

    if (!mounted || !sent) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Notification sent'),
        backgroundColor: CoachTokens.success,
      ),
    );
  }

  Future<void> _markAllRead() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _controller.markAllRead();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException ? e.message : 'Could not mark everything read.',
          ),
          backgroundColor: CoachTokens.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = _controller.unreadCount;

    return Scaffold(
      backgroundColor: CoachTokens.canvas,
      appBar: AppBar(
        backgroundColor: CoachTokens.brand,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          if (unread > 0)
            IconButton(
              tooltip: 'Mark all read',
              onPressed: _markAllRead,
              icon: const Icon(Icons.done_all_rounded),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: CoachRefreshLine(visible: _controller.refreshing),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _compose,
        backgroundColor: CoachTokens.brand,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Send'),
      ),
      body: Column(
        children: [
          _filters(unread),
          Expanded(
            child: RefreshIndicator(
              color: CoachTokens.brand,
              onRefresh: _controller.refresh,
              child: _list(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filters(int unread) {
    return Container(
      color: CoachTokens.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: CoachTokens.space4,
        vertical: CoachTokens.space2 + 2,
      ),
      child: Row(
        children: [
          FilterChip(
            label: Text(unread > 0 ? 'Unread ($unread)' : 'Unread'),
            selected: _controller.unreadOnly,
            onSelected: (value) => _controller.setUnreadOnly(value),
            showCheckmark: false,
            labelStyle: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: _controller.unreadOnly
                  ? CoachTokens.brand
                  : CoachTokens.textBody,
            ),
            backgroundColor: CoachTokens.canvas,
            selectedColor: CoachTokens.brandSoft,
            side: BorderSide(
              color: _controller.unreadOnly
                  ? CoachTokens.brand
                  : CoachTokens.border,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(CoachTokens.radiusPill),
            ),
          ),
          const Spacer(),
          Text(
            '${_controller.total} total',
            style: const TextStyle(
              fontSize: 12,
              color: CoachTokens.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _list() {
    if (_controller.state.isLoading && _controller.notifications.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(CoachTokens.space4),
        children: const [CoachListShimmer()],
      );
    }

    if (_controller.state.isFailed && _controller.notifications.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: CoachTokens.space8),
          CoachErrorView(
            message: _controller.error ?? 'Could not load notifications.',
            onRetry: _controller.load,
          ),
        ],
      );
    }

    if (_controller.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: CoachTokens.space8),
          // "Nothing unread" and "nothing at all" are different situations.
          if (!_controller.inboxEmpty)
            CoachEmptyView(
              icon: Icons.mark_email_read_outlined,
              title: 'All caught up',
              message: 'You have read everything in your inbox.',
              actionLabel: 'Show all',
              onAction: () => _controller.setUnreadOnly(false),
            )
          else
            CoachEmptyView(
              icon: Icons.notifications_none_rounded,
              title: 'No notifications',
              message:
                  'Alerts about your batches and enquiries land here. You can '
                  'also send one to your students.',
              actionLabel: 'Send a notification',
              onAction: _compose,
            ),
        ],
      );
    }

    final items = _controller.notifications;

    return ListView.builder(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        CoachTokens.space4,
        CoachTokens.space3,
        CoachTokens.space4,
        // Room for the FAB.
        CoachTokens.space8 + 56,
      ),
      itemCount: items.length + 1,
      itemBuilder: (context, index) {
        if (index == items.length) return _footer();
        return _notificationCard(items[index]);
      },
    );
  }

  Widget _footer() {
    if (_controller.loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: CoachTokens.space5),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: CoachTokens.brand,
            ),
          ),
        ),
      );
    }

    if (_controller.error != null && _controller.hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: CoachTokens.space4),
        child: Center(
          child: TextButton.icon(
            onPressed: _controller.loadMore,
            icon: const Icon(Icons.refresh_rounded, size: 17),
            label: const Text('Load more'),
            style: TextButton.styleFrom(foregroundColor: CoachTokens.brand),
          ),
        ),
      );
    }

    // The unread filter hides rows client-side, so an exhausted list can still
    // have more pages worth fetching.
    if (_controller.hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: CoachTokens.space4),
        child: Center(
          child: TextButton.icon(
            onPressed: _controller.loadMore,
            icon: const Icon(Icons.expand_more_rounded, size: 18),
            label: const Text('Load more'),
            style: TextButton.styleFrom(foregroundColor: CoachTokens.brand),
          ),
        ),
      );
    }

    return const SizedBox(height: CoachTokens.space4);
  }

  Widget _notificationCard(CoachNotification notification) {
    final tone = _typeColor(notification.type);

    return CoachCard(
      margin: const EdgeInsets.only(bottom: CoachTokens.space3),
      accentColor: notification.isRead ? null : tone,
      onTap: notification.isRead
          ? null
          : () => _controller.markRead(notification.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(CoachTokens.space2 + 1),
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(CoachTokens.radiusSm),
                ),
                child: Icon(
                  _typeIcon(notification.type),
                  size: 17,
                  color: tone,
                ),
              ),
              const SizedBox(width: CoachTokens.space3),
              Expanded(
                child: Text(
                  notification.displayTitle,
                  style: TextStyle(
                    fontSize: 14.5,
                    // Unread reads heavier, the way a mail app does.
                    fontWeight: notification.isRead
                        ? FontWeight.w600
                        : FontWeight.w800,
                    color: CoachTokens.textDark,
                  ),
                ),
              ),
              if (!notification.isRead)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 5, left: CoachTokens.space2),
                  decoration: const BoxDecoration(
                    color: CoachTokens.brand,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          if (notification.message.trim().isNotEmpty) ...[
            const SizedBox(height: CoachTokens.space3),
            Text(
              notification.message.trim(),
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: CoachTokens.textBody,
              ),
            ),
          ],
          const SizedBox(height: CoachTokens.space3),
          Row(
            children: [
              if (notification.typeLabel.isNotEmpty)
                CoachStatusChip(label: notification.typeLabel, color: tone),
              const Spacer(),
              if (notification.sentAt != null)
                Text(
                  _relative(notification.sentAt!),
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: CoachTokens.textMuted,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static Color _typeColor(CoachNotificationType? type) => switch (type) {
        CoachNotificationType.alert => CoachTokens.danger,
        CoachNotificationType.payment => CoachTokens.success,
        CoachNotificationType.booking => CoachTokens.info,
        CoachNotificationType.promotion => CoachTokens.accent,
        CoachNotificationType.feedback => CoachTokens.purple,
        _ => CoachTokens.brand,
      };

  static IconData _typeIcon(CoachNotificationType? type) => switch (type) {
        CoachNotificationType.alert => Icons.warning_amber_rounded,
        CoachNotificationType.payment => Icons.payments_outlined,
        CoachNotificationType.booking => Icons.event_available_outlined,
        CoachNotificationType.promotion => Icons.local_offer_outlined,
        CoachNotificationType.feedback => Icons.rate_review_outlined,
        _ => Icons.notifications_none_rounded,
      };

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// `"2h ago"` for the last day, then a date. Written by hand so the coach
  /// screens do not depend on a locale being initialised.
  static String _relative(DateTime sentAt) {
    final diff = DateTime.now().difference(sentAt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return '${sentAt.day.toString().padLeft(2, '0')} '
        '${_months[sentAt.month - 1]} ${sentAt.year}';
  }
}
