import 'package:flutter/material.dart';

import '../../data/repositories/employee_dashboard_repository_impl.dart';
import '../../domain/entities/employee_notification.dart';
import '../state/employee_notifications_controller.dart';
import '../theme/employee_theme.dart';
import '../widgets/employee_forms.dart';
import '../widgets/employee_list_scaffold.dart';

/// Notifications — the inbox, and composing a broadcast to the complex.
class EmployeeNotificationsPage extends StatefulWidget {
  const EmployeeNotificationsPage({super.key});

  @override
  State<EmployeeNotificationsPage> createState() =>
      _EmployeeNotificationsPageState();
}

class _EmployeeNotificationsPageState extends State<EmployeeNotificationsPage> {
  late final EmployeeNotificationsController _controller =
      EmployeeNotificationsController(EmployeeDashboardRepositoryImpl());

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EmployeeListScaffold<EmployeeNotification>(
      title: 'Notifications',
      controller: _controller,
      subtitle: () {
        final unread = _controller.unread;
        if (unread > 0) return '$unread unread';
        return '${_controller.total} notification'
            '${_controller.total == 1 ? '' : 's'}';
      },
      actions: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => IconButton(
            icon: const Icon(Icons.done_all_rounded),
            tooltip: 'Mark all read',
            onPressed: _controller.unread == 0 ? null : _markAllRead,
          ),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCompose,
        backgroundColor: EmployeeTokens.brand,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.campaign_outlined),
        label: const Text('Send'),
      ),
      itemBuilder: (context, notification) => _notificationCard(notification),
      emptyIcon: Icons.notifications_none_rounded,
      emptyTitle: 'Nothing in your inbox',
      emptyMessage: 'Notifications sent to you will show up here. Tap Send to '
          'broadcast one to your complex.',
    );
  }

  Future<void> _markAllRead() async {
    final error = await _controller.markAllRead();
    if (!mounted) return;
    showEmployeeToast(
      context,
      error ?? 'All marked read',
      isError: error != null,
    );
  }

  Widget _notificationCard(EmployeeNotification notification) {
    final tone = EmployeeTokens.notificationTypeColor(notification.type);

    return EmployeeCard(
      margin: const EdgeInsets.only(bottom: EmployeeTokens.space3),
      // Unread rows get the stripe; read ones do not, so the inbox reads at a
      // glance without a second badge per row.
      accentColor: notification.isRead ? null : tone,
      onTap: () => _openDetail(notification),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(EmployeeTokens.space2 + 1),
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(EmployeeTokens.radiusSm),
                ),
                child: Icon(
                  _iconFor(notification.type),
                  size: 17,
                  color: tone,
                ),
              ),
              const SizedBox(width: EmployeeTokens.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: notification.isRead
                            ? FontWeight.w600
                            : FontWeight.w800,
                        color: EmployeeTokens.textDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      notification.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: EmployeeTokens.textBody,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: EmployeeTokens.space3),
          Row(
            children: [
              EmployeeChip(
                label: notification.type,
                color: tone,
                dense: true,
              ),
              const Spacer(),
              Text(
                notification.relativeLabel,
                style: const TextStyle(
                  fontSize: 11,
                  color: EmployeeTokens.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String type) {
    switch (type.toLowerCase()) {
      case 'booking':
        return Icons.event_note_outlined;
      case 'payment':
        return Icons.payments_outlined;
      case 'alert':
        return Icons.warning_amber_rounded;
      case 'promotion':
        return Icons.local_offer_outlined;
      case 'feedback':
        return Icons.chat_bubble_outline_rounded;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  Future<void> _openDetail(EmployeeNotification notification) async {
    // Opening it is reading it.
    await _controller.markRead(notification);
    if (!mounted) return;

    await showEmployeeSheet<void>(
      context: context,
      title: notification.displayTitle,
      subtitle: notification.timeLabel,
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EmployeeChip(
            label: notification.type,
            color: EmployeeTokens.notificationTypeColor(notification.type),
          ),
          const SizedBox(height: EmployeeTokens.space4),
          Text(
            notification.message,
            style: const TextStyle(
              fontSize: 14,
              height: 1.55,
              color: EmployeeTokens.textBody,
            ),
          ),
          const SizedBox(height: EmployeeTokens.space5),
          EmployeeDetailRow(
            label: 'Received',
            value: notification.timeLabel,
          ),
          if ((notification.targetRole ?? '').isNotEmpty)
            EmployeeDetailRow(
              label: 'Sent to',
              value: notification.targetRole!,
            ),
        ],
      ),
    );
  }

  Future<void> _openCompose() async {
    // The audience is only needed once the sheet is open, so it is fetched
    // here rather than on every visit to the inbox.
    _controller.loadAudience();

    await showEmployeeSheet<void>(
      context: context,
      title: 'New notification',
      subtitle: 'Broadcast to your sports complex',
      builder: (context) => _ComposeSheet(controller: _controller),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Compose
// ─────────────────────────────────────────────────────────────────────────────

class _ComposeSheet extends StatefulWidget {
  const _ComposeSheet({required this.controller});

  final EmployeeNotificationsController controller;

  @override
  State<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<_ComposeSheet> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _message = TextEditingController();

  String _type = employeeNotificationTypes.first;
  EmployeeRecipientMode _mode = EmployeeRecipientMode.all;

  final Set<int> _coachIds = {};
  final Set<int> _userIds = {};

  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_title.text.trim().isEmpty || _message.text.trim().isEmpty) {
      setState(() => _error = 'A title and a message are both required.');
      return;
    }
    if (_mode == EmployeeRecipientMode.coaches && _coachIds.isEmpty) {
      setState(() => _error = 'Pick at least one coach.');
      return;
    }
    if (_mode == EmployeeRecipientMode.selected && _userIds.isEmpty) {
      setState(() => _error = 'Pick at least one recipient.');
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    final result = await widget.controller.send(
      EmployeeNotificationDraft(
        title: _title.text,
        message: _message.text,
        type: _type,
        mode: _mode,
        coachIds: _coachIds.toList(),
        userIds: _userIds.toList(),
      ),
    );

    if (!mounted) return;

    if (result.error != null) {
      setState(() {
        _sending = false;
        _error = result.error;
      });
      return;
    }

    Navigator.of(context).pop();
    showEmployeeToast(context, result.message ?? 'Notification sent');
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final audience = widget.controller.audience;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EmployeeFormError(message: _error),

            const Text(
              'WHO IT GOES TO',
              style: TextStyle(
                fontSize: 10.5,
                letterSpacing: 0.9,
                fontWeight: FontWeight.w700,
                color: EmployeeTokens.textMuted,
              ),
            ),
            const SizedBox(height: EmployeeTokens.space3),

            _modeTile(
              mode: EmployeeRecipientMode.all,
              subtitle: widget.controller.audienceLoading
                  ? 'Loading…'
                  : 'All coaches and students at your complex'
                      '${audience.people.isEmpty ? '' : ' (${audience.people.length} people)'}',
            ),
            _modeTile(
              mode: EmployeeRecipientMode.selected,
              subtitle: 'Choose specific coaches or students',
            ),
            _modeTile(
              mode: EmployeeRecipientMode.coaches,
              subtitle: 'Pick coaches — it reaches each coach and every '
                  'student in their batches',
            ),

            if (widget.controller.audienceError != null) ...[
              const SizedBox(height: EmployeeTokens.space3),
              EmployeeFormError(message: widget.controller.audienceError),
              OutlinedButton.icon(
                onPressed: () => widget.controller.loadAudience(force: true),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry loading recipients'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: EmployeeTokens.brand,
                  side: const BorderSide(color: EmployeeTokens.border),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(EmployeeTokens.radiusSm),
                  ),
                ),
              ),
            ],

            if (_mode == EmployeeRecipientMode.coaches)
              _picker(
                label: 'Coaches',
                people: audience.coaches,
                selected: _coachIds,
                emptyMessage: 'No coaches at your complex.',
              ),

            if (_mode == EmployeeRecipientMode.selected)
              _picker(
                label: 'People',
                people: audience.people,
                selected: _userIds,
                emptyMessage: 'No coaches or students at your complex.',
              ),

            const SizedBox(height: EmployeeTokens.space5),
            const Text(
              'MESSAGE',
              style: TextStyle(
                fontSize: 10.5,
                letterSpacing: 0.9,
                fontWeight: FontWeight.w700,
                color: EmployeeTokens.textMuted,
              ),
            ),
            const SizedBox(height: EmployeeTokens.space3),

            EmployeeField(
              label: 'Title',
              required: true,
              child: EmployeeTextField(
                controller: _title,
                hintText: 'What it is about',
              ),
            ),
            EmployeeField(
              label: 'Message',
              required: true,
              child: EmployeeTextField(
                controller: _message,
                maxLines: 5,
                hintText: 'What you want them to know',
              ),
            ),
            EmployeeField(
              label: 'Type',
              child: EmployeeDropdown<String>(
                value: _type,
                items: employeeNotificationTypes,
                labelOf: (t) => t,
                onChanged: (value) => setState(() => _type = value ?? _type),
              ),
            ),

            EmployeeSheetActions(
              saving: _sending,
              saveLabel: 'Send notification',
              onSave: _send,
            ),
          ],
        );
      },
    );
  }

  Widget _modeTile({
    required EmployeeRecipientMode mode,
    required String subtitle,
  }) {
    final active = _mode == mode;

    return Padding(
      padding: const EdgeInsets.only(bottom: EmployeeTokens.space2),
      child: Material(
        color: active ? EmployeeTokens.brandSoft : EmployeeTokens.canvas,
        borderRadius: BorderRadius.circular(EmployeeTokens.radiusSm),
        child: InkWell(
          onTap: () => setState(() {
            _mode = mode;
            // The two id sets address different things, so switching mode
            // clears both rather than carrying a stale selection across.
            _coachIds.clear();
            _userIds.clear();
          }),
          borderRadius: BorderRadius.circular(EmployeeTokens.radiusSm),
          child: Container(
            padding: const EdgeInsets.all(EmployeeTokens.space3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(EmployeeTokens.radiusSm),
              border: Border.all(
                color: active ? EmployeeTokens.brand : EmployeeTokens.border,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  active
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 19,
                  color: active
                      ? EmployeeTokens.brand
                      : EmployeeTokens.textMuted,
                ),
                const SizedBox(width: EmployeeTokens.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mode.label,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: EmployeeTokens.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11.5,
                          height: 1.35,
                          color: EmployeeTokens.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _picker({
    required String label,
    required List<EmployeeRecipient> people,
    required Set<int> selected,
    required String emptyMessage,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: EmployeeTokens.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${label.toUpperCase()} (${selected.length})',
                style: const TextStyle(
                  fontSize: 10.5,
                  letterSpacing: 0.9,
                  fontWeight: FontWeight.w700,
                  color: EmployeeTokens.textMuted,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: people.isEmpty
                    ? null
                    : () => setState(
                          () => selected
                            ..clear()
                            ..addAll(people.map((p) => p.id)),
                        ),
                style: TextButton.styleFrom(
                  foregroundColor: EmployeeTokens.brand,
                  minimumSize: const Size(0, 0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: EmployeeTokens.space2,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('All', style: TextStyle(fontSize: 12)),
              ),
              TextButton(
                onPressed: selected.isEmpty
                    ? null
                    : () => setState(selected.clear),
                style: TextButton.styleFrom(
                  foregroundColor: EmployeeTokens.textMuted,
                  minimumSize: const Size(0, 0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: EmployeeTokens.space2,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Clear', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: EmployeeTokens.space2),
          Container(
            constraints: const BoxConstraints(maxHeight: 240),
            decoration: BoxDecoration(
              border: Border.all(color: EmployeeTokens.border),
              borderRadius: BorderRadius.circular(EmployeeTokens.radiusSm),
            ),
            child: people.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(EmployeeTokens.space5),
                    child: Center(
                      child: Text(
                        widget.controller.audienceLoading
                            ? 'Loading…'
                            : emptyMessage,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: EmployeeTokens.textMuted,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: people.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: EmployeeTokens.border),
                    itemBuilder: (context, index) {
                      final person = people[index];
                      final checked = selected.contains(person.id);

                      return CheckboxListTile(
                        value: checked,
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: EmployeeTokens.brand,
                        title: Text(
                          person.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: (person.email ?? '').isEmpty
                            ? null
                            : Text(
                                person.email!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11.5),
                              ),
                        onChanged: (value) => setState(() {
                          if (value == true) {
                            selected.add(person.id);
                          } else {
                            selected.remove(person.id);
                          }
                        }),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
