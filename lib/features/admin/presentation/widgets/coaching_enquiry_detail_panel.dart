import 'package:flutter/material.dart';

import '../../domain/entities/coaching_enquiry.dart';
import '../state/view_state.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';
import 'admin_states.dart';
import 'coaching_enquiries_table.dart';
import 'enquiry_status_chip.dart';
import 'glass_card.dart';

/// The right-side detail panel for a coaching enquiry.
///
/// The list row does not carry the message, the remarks or the assigned coach,
/// so the panel opens on the row and fills in as
/// `GET /coaching-enquiries/{id}` lands — [state] drives the thin progress
/// line rather than a spinner that would hide what is already readable.
class CoachingEnquiryDetailPanel extends StatelessWidget {
  const CoachingEnquiryDetailPanel({
    super.key,
    required this.enquiry,
    required this.state,
    required this.onClose,
    required this.onAction,
    this.showCloseButton = true,
  });

  final CoachingEnquiry enquiry;
  final ViewState state;
  final VoidCallback onClose;
  final void Function(EnquiryAction action, CoachingEnquiry enquiry) onAction;
  final bool showCloseButton;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(
            AdminTokens.space5,
            AdminTokens.space4,
            AdminTokens.space3,
            AdminTokens.space4,
          ),
          decoration: BoxDecoration(
            color: tokens.surface,
            border: Border(bottom: BorderSide(color: tokens.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Coaching enquiry',
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (showCloseButton)
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded, size: 20),
                  tooltip: 'Close',
                  color: tokens.textMuted,
                ),
            ],
          ),
        ),
        RefreshLine(visible: state.isLoading),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AdminTokens.space5),
            children: [
              _IdentityCard(enquiry: enquiry, onAction: onAction),
              const SizedBox(height: AdminTokens.space4),
              _Card(
                icon: Icons.timeline_rounded,
                title: 'Follow-up',
                child: EnquiryStatusTimeline(statusRaw: enquiry.statusRaw),
              ),
              const SizedBox(height: AdminTokens.space4),
              _Card(
                icon: Icons.contact_page_outlined,
                title: 'Contact',
                child: Column(
                  children: [
                    _Row('Phone', AdminFormat.text(enquiry.phone)),
                    _Row('Email', AdminFormat.text(enquiry.email)),
                  ],
                ),
              ),
              const SizedBox(height: AdminTokens.space4),
              _Card(
                icon: Icons.sports_tennis_outlined,
                title: 'Interest',
                child: Column(
                  children: [
                    _Row('Sport', AdminFormat.text(enquiry.sportName)),
                    _Row(
                      'Sport complex',
                      AdminFormat.text(enquiry.sportComplexName),
                    ),
                    if ((enquiry.batchName ?? '').trim().isNotEmpty)
                      _Row('Batch', enquiry.batchName!.trim()),
                  ],
                ),
              ),
              const SizedBox(height: AdminTokens.space4),
              _Card(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'Message',
                child: _Body(
                  text: enquiry.message,
                  empty: 'No message was sent with this enquiry.',
                ),
              ),
              const SizedBox(height: AdminTokens.space4),
              _Card(
                icon: Icons.sticky_note_2_outlined,
                title: 'Remarks',
                trailing: TextButton.icon(
                  onPressed: () => onAction(EnquiryAction.edit, enquiry),
                  icon: const Icon(Icons.edit_outlined, size: 15),
                  label: Text(enquiry.hasRemarks ? 'Edit' : 'Add'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
                child: _Body(
                  text: enquiry.remarks,
                  empty: 'Nothing has been noted yet.',
                ),
              ),
              const SizedBox(height: AdminTokens.space4),
              _Card(
                icon: Icons.person_outline_rounded,
                title: 'Assigned coach',
                trailing: TextButton.icon(
                  onPressed: () => onAction(EnquiryAction.assignCoach, enquiry),
                  icon: const Icon(Icons.person_add_alt_1_outlined, size: 15),
                  label: Text(enquiry.isAssigned ? 'Reassign' : 'Assign'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
                child: enquiry.isAssigned
                    ? Row(
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            size: 17,
                            color: tokens.success,
                          ),
                          const SizedBox(width: AdminTokens.space3),
                          Expanded(
                            child: Text(
                              AdminFormat.text(enquiry.assignedCoachName),
                              style: TextStyle(
                                color: tokens.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      )
                    : _Body(
                        text: null,
                        empty: 'No coach has been assigned to this enquiry.',
                      ),
              ),
              const SizedBox(height: AdminTokens.space4),
              _Card(
                icon: Icons.info_outline_rounded,
                title: 'Record',
                child: Column(
                  children: [
                    if ((enquiry.referenceNumber ?? '').trim().isNotEmpty)
                      _Row('Reference', enquiry.referenceNumber!.trim()),
                    _Row('Created', AdminFormat.dateTime(enquiry.createdAt)),
                    _Row(
                      'Last updated',
                      AdminFormat.dateTime(enquiry.updatedAt),
                    ),
                  ],
                ),
              ),
              if (state.isFailed) ...[
                const SizedBox(height: AdminTokens.space4),
                const _StaleNotice(),
              ],
              const SizedBox(height: AdminTokens.space6),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(AdminTokens.space4),
          decoration: BoxDecoration(
            color: tokens.surface,
            border: Border(top: BorderSide(color: tokens.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => onAction(EnquiryAction.delete, enquiry),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Delete'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tokens.danger,
                    side: BorderSide(
                      color: tokens.danger.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AdminTokens.space3),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: () =>
                      onAction(EnquiryAction.changeStatus, enquiry),
                  icon: const Icon(Icons.flag_outlined, size: 18),
                  label: const Text('Change status'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.enquiry, required this.onAction});

  final CoachingEnquiry enquiry;
  final void Function(EnquiryAction action, CoachingEnquiry enquiry) onAction;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    final hasPhone = (enquiry.phone ?? '').trim().isNotEmpty;
    final hasEmail = (enquiry.email ?? '').trim().isNotEmpty;

    return SolidCard(
      child: Column(
        children: [
          EnquirerAvatar(enquiry: enquiry, size: 76),
          const SizedBox(height: AdminTokens.space4),
          Text(
            enquiry.displayName,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: tokens.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: AdminTokens.space1),
          Text(
            enquiry.interestLabel.isEmpty
                ? AdminFormat.text(enquiry.email)
                : enquiry.interestLabel,
            textAlign: TextAlign.center,
            style: TextStyle(color: tokens.textMuted, fontSize: 13),
          ),
          const SizedBox(height: AdminTokens.space4),
          EnquiryStatusChip(statusRaw: enquiry.statusRaw),
          if (hasPhone || hasEmail) ...[
            const SizedBox(height: AdminTokens.space4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (hasPhone)
                  OutlinedButton.icon(
                    onPressed: () => onAction(EnquiryAction.call, enquiry),
                    icon: const Icon(Icons.call_outlined, size: 16),
                    label: const Text('Call'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: tokens.textSecondary,
                      side: BorderSide(color: tokens.border),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AdminTokens.space4,
                        vertical: AdminTokens.space2 + 2,
                      ),
                      textStyle: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                if (hasPhone && hasEmail)
                  const SizedBox(width: AdminTokens.space3),
                if (hasEmail)
                  OutlinedButton.icon(
                    onPressed: () => onAction(EnquiryAction.email, enquiry),
                    icon: const Icon(Icons.mail_outline_rounded, size: 16),
                    label: const Text('Email'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: tokens.textSecondary,
                      side: BorderSide(color: tokens.border),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AdminTokens.space4,
                        vertical: AdminTokens.space2 + 2,
                      ),
                      textStyle: const TextStyle(fontSize: 12.5),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StaleNotice extends StatelessWidget {
  const _StaleNotice();

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(AdminTokens.space3),
      decoration: BoxDecoration(
        color: tokens.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
        border: Border.all(color: tokens.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cloud_off_rounded, size: 16, color: tokens.warning),
          const SizedBox(width: AdminTokens.space3),
          Expanded(
            child: Text(
              'Showing what the list returned — the full enquiry could not be '
              'loaded, so the message, remarks and assigned coach may be '
              'missing.',
              style: TextStyle(
                color: tokens.textSecondary,
                fontSize: 11.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return SolidCard(
      padding: const EdgeInsets.all(AdminTokens.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: tokens.accent),
              const SizedBox(width: AdminTokens.space2),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: AdminTokens.space3),
          child,
        ],
      ),
    );
  }
}

/// Free text, or a muted line explaining that there is none.
class _Body extends StatelessWidget {
  const _Body({required this.text, required this.empty});

  final String? text;
  final String empty;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final trimmed = (text ?? '').trim();

    return SizedBox(
      width: double.infinity,
      child: Text(
        trimmed.isEmpty ? empty : trimmed,
        style: TextStyle(
          color: trimmed.isEmpty ? tokens.textMuted : tokens.textPrimary,
          fontSize: 12.5,
          height: 1.5,
          fontStyle: trimmed.isEmpty ? FontStyle.italic : FontStyle.normal,
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: value == AdminFormat.dash
                    ? tokens.textMuted
                    : tokens.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
