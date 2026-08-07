import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../core/coach_log.dart';
import '../../domain/entities/coach_notification.dart';
import '../state/coach_notifications_controller.dart';
import '../state/coach_view_state.dart';
import '../theme/coach_theme.dart';
import 'coach_states.dart';

/// Compose a notification.
///
/// Two audiences, matching the website: named recipients, or everyone.
///
/// The broadcast is deliberately behind a confirmation. The backend places a
/// ceiling on an EMPLOYEE's broadcast (their own complex only) but **not on a
/// coach's** — `recipient: 'all'` from a coach reaches every user in the
/// system, including website users and other complexes. That is almost
/// certainly wider than a coach intends, so it is never one tap away.
///
/// Returns `true` once something is sent.
Future<bool> showCoachNotificationComposeSheet({
  required BuildContext context,
  required CoachNotificationsController controller,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ComposeSheet(controller: controller),
  );
  return result ?? false;
}

class _ComposeSheet extends StatefulWidget {
  const _ComposeSheet({required this.controller});

  final CoachNotificationsController controller;

  @override
  State<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<_ComposeSheet> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _message = TextEditingController();
  final _recipientSearch = TextEditingController();

  CoachNotificationType _type = CoachNotificationType.system;
  CoachNotificationAudience _audience = CoachNotificationAudience.selected;
  final Set<int> _selected = {};

  bool _submitting = false;
  String? _error;

  CoachNotificationsController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    _controller.loadRecipients();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _title.dispose();
    _message.dispose();
    _recipientSearch.dispose();
    super.dispose();
  }

  List<CoachNotificationRecipient> get _visibleRecipients {
    final term = _recipientSearch.text;
    return _controller.recipients
        .where((r) => r.matches(term))
        .toList(growable: false);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final broadcast = _audience == CoachNotificationAudience.everyone;

    if (!broadcast && _selected.isEmpty) {
      setState(() => _error = 'Pick at least one recipient.');
      return;
    }

    if (broadcast && !await _confirmBroadcast()) return;

    if (!mounted) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await _controller.send(
        CoachNotificationDraft(
          title: _title.text,
          message: _message.text,
          type: _type,
          audience: _audience,
          userIds: _selected.toList(growable: false),
        ),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      CoachLog.failure('Send notification failed', error: e);
      setState(() {
        _error = e is ApiException
            ? e.message
            : 'Could not send that notification. Please try again.';
        _submitting = false;
      });
    }
  }

  /// A broadcast reaches every user in the system, so it is never sent on a
  /// single tap.
  Future<bool> _confirmBroadcast() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CoachTokens.radiusMd),
        ),
        icon: const Icon(
          Icons.campaign_outlined,
          size: 30,
          color: CoachTokens.warning,
        ),
        title: const Text(
          'Send to everyone?',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'This goes to every user of Nahata Sports — not just your own '
          'students. There is no way to unsend it.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13.5, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(foregroundColor: CoachTokens.textMuted),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: CoachTokens.warning),
            child: const Text('Send to everyone'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets.bottom;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: CoachTokens.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(CoachTokens.radiusLg + 4),
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 4,
                margin:
                    const EdgeInsets.symmetric(vertical: CoachTokens.space3),
                decoration: BoxDecoration(
                  color: CoachTokens.border,
                  borderRadius: BorderRadius.circular(CoachTokens.radiusPill),
                ),
              ),
              _header(),
              const Divider(height: 1, color: CoachTokens.border),
              Expanded(child: _body(scrollController)),
              _footer(insets),
            ],
          ),
        );
      },
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CoachTokens.space5,
        0,
        CoachTokens.space3,
        CoachTokens.space4,
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'New notification',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: CoachTokens.textDark,
              ),
            ),
          ),
          IconButton(
            onPressed:
                _submitting ? null : () => Navigator.of(context).pop(false),
            icon: const Icon(Icons.close_rounded),
            color: CoachTokens.textMuted,
          ),
        ],
      ),
    );
  }

  Widget _body(ScrollController scrollController) {
    return Form(
      key: _formKey,
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.all(CoachTokens.space5),
        children: [
          _label('Title *'),
          const SizedBox(height: CoachTokens.space2),
          TextFormField(
            controller: _title,
            enabled: !_submitting,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 14.5),
            decoration: _decoration('e.g. Practice moved to 6pm',
                Icons.title_rounded),
            validator: (v) =>
                (v ?? '').trim().isEmpty ? 'Enter a title' : null,
          ),
          const SizedBox(height: CoachTokens.space4),
          _label('Message *'),
          const SizedBox(height: CoachTokens.space2),
          TextFormField(
            controller: _message,
            enabled: !_submitting,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 14.5),
            decoration:
                _decoration('What do they need to know?', Icons.notes_rounded),
            validator: (v) =>
                (v ?? '').trim().isEmpty ? 'Enter a message' : null,
          ),
          const SizedBox(height: CoachTokens.space5),
          _label('Category'),
          const SizedBox(height: CoachTokens.space2),
          Wrap(
            spacing: CoachTokens.space2,
            runSpacing: CoachTokens.space2,
            children: CoachNotificationType.values.map((type) {
              final selected = _type == type;
              return ChoiceChip(
                label: Text(type.label),
                selected: selected,
                showCheckmark: false,
                onSelected:
                    _submitting ? null : (_) => setState(() => _type = type),
                labelStyle: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? CoachTokens.brand : CoachTokens.textBody,
                ),
                backgroundColor: CoachTokens.canvas,
                selectedColor: CoachTokens.brandSoft,
                side: BorderSide(
                  color: selected ? CoachTokens.brand : CoachTokens.border,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(CoachTokens.radiusPill),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: CoachTokens.space5),
          _label('Send to'),
          const SizedBox(height: CoachTokens.space2),
          _audienceToggle(),
          if (_audience == CoachNotificationAudience.selected) ...[
            const SizedBox(height: CoachTokens.space4),
            _recipientPicker(),
          ],
        ],
      ),
    );
  }

  Widget _audienceToggle() {
    return Column(
      children: [
        _audienceOption(
          audience: CoachNotificationAudience.selected,
          icon: Icons.person_search_rounded,
          title: 'Selected people',
          subtitle: _selected.isEmpty
              ? 'Pick who should get this'
              : '${_selected.length} selected',
        ),
        const SizedBox(height: CoachTokens.space2),
        _audienceOption(
          audience: CoachNotificationAudience.everyone,
          icon: Icons.campaign_outlined,
          title: 'Everyone',
          subtitle: 'Every user of the app — not just your students',
          tone: CoachTokens.warning,
        ),
      ],
    );
  }

  Widget _audienceOption({
    required CoachNotificationAudience audience,
    required IconData icon,
    required String title,
    required String subtitle,
    Color tone = CoachTokens.brand,
  }) {
    final selected = _audience == audience;

    return InkWell(
      onTap: _submitting ? null : () => setState(() => _audience = audience),
      borderRadius: BorderRadius.circular(CoachTokens.radiusSm),
      child: Container(
        padding: const EdgeInsets.all(CoachTokens.space3 + 1),
        decoration: BoxDecoration(
          color: selected ? tone.withValues(alpha: 0.08) : CoachTokens.canvas,
          borderRadius: BorderRadius.circular(CoachTokens.radiusSm),
          border: Border.all(
            color: selected ? tone : CoachTokens.border,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? tone : CoachTokens.textMuted,
            ),
            const SizedBox(width: CoachTokens.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: selected ? tone : CoachTokens.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: CoachTokens.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 19,
              color: selected ? tone : CoachTokens.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _recipientPicker() {
    if (_controller.recipientsState.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: CoachTokens.space6),
        child: Center(
          child: CircularProgressIndicator(color: CoachTokens.brand),
        ),
      );
    }

    if (_controller.recipientsState.isFailed) {
      return CoachErrorView(
        compact: true,
        message: _controller.recipientsError ?? 'Could not load recipients.',
        onRetry: _controller.loadRecipients,
      );
    }

    final visible = _visibleRecipients;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _recipientSearch,
          enabled: !_submitting,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontSize: 14),
          decoration: _decoration(
            'Search people',
            Icons.search_rounded,
          ).copyWith(
            suffixIcon: _recipientSearch.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 17),
                    color: CoachTokens.textMuted,
                    onPressed: () {
                      _recipientSearch.clear();
                      setState(() {});
                    },
                  ),
          ),
        ),
        const SizedBox(height: CoachTokens.space2),
        if (visible.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: CoachTokens.space5),
            child: Center(
              child: Text(
                'Nobody matches that search.',
                style: TextStyle(fontSize: 13, color: CoachTokens.textMuted),
              ),
            ),
          )
        else
          Container(
            constraints: const BoxConstraints(maxHeight: 280),
            decoration: BoxDecoration(
              border: Border.all(color: CoachTokens.border),
              borderRadius: BorderRadius.circular(CoachTokens.radiusSm),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: visible.length,
              itemBuilder: (context, index) {
                final person = visible[index];
                final checked = _selected.contains(person.id);

                return CheckboxListTile(
                  value: checked,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: CoachTokens.brand,
                  onChanged: _submitting
                      ? null
                      : (value) => setState(() {
                            if (value == true) {
                              _selected.add(person.id);
                            } else {
                              _selected.remove(person.id);
                            }
                          }),
                  title: Text(
                    person.displayName,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: CoachTokens.textDark,
                    ),
                  ),
                  subtitle: Text(
                    [
                      if (person.email.trim().isNotEmpty) person.email.trim(),
                      if (person.roleLabel.isNotEmpty) person.roleLabel,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: CoachTokens.textMuted,
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
          color: CoachTokens.textMuted,
        ),
      );

  InputDecoration _decoration(String hint, IconData icon) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(CoachTokens.radiusSm),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 14, color: CoachTokens.textMuted),
      prefixIcon: Icon(icon, size: 19, color: CoachTokens.textMuted),
      filled: true,
      fillColor: CoachTokens.canvas,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: CoachTokens.space3,
        vertical: CoachTokens.space3 + 2,
      ),
      border: border(CoachTokens.border),
      enabledBorder: border(CoachTokens.border),
      focusedBorder: border(CoachTokens.brand, 1.4),
      errorBorder: border(CoachTokens.danger),
      focusedErrorBorder: border(CoachTokens.danger, 1.4),
    );
  }

  Widget _footer(double insets) {
    final broadcast = _audience == CoachNotificationAudience.everyone;

    return Container(
      padding: EdgeInsets.fromLTRB(
        CoachTokens.space5,
        CoachTokens.space4,
        CoachTokens.space5,
        CoachTokens.space4 + insets,
      ),
      decoration: const BoxDecoration(
        color: CoachTokens.canvas,
        border: Border(top: BorderSide(color: CoachTokens.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 17,
                  color: CoachTokens.danger,
                ),
                const SizedBox(width: CoachTokens.space2),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: CoachTokens.danger,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: CoachTokens.space3),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(
                _submitting
                    ? 'Sending…'
                    : broadcast
                        ? 'Send to everyone'
                        : 'Send to ${_selected.length} '
                            '${_selected.length == 1 ? 'person' : 'people'}',
              ),
              style: FilledButton.styleFrom(
                backgroundColor:
                    broadcast ? CoachTokens.warning : CoachTokens.brand,
                padding:
                    const EdgeInsets.symmetric(vertical: CoachTokens.space4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(CoachTokens.radiusSm),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
