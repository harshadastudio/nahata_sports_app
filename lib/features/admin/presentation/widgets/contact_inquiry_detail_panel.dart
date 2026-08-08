import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/contact_inquiry.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';
import 'contact_enquiries_table.dart';
import 'contact_status_chip.dart';
import 'glass_card.dart';

/// The full record for one contact enquiry.
///
/// Everything the row shows plus the whole message and both timestamps. There
/// is no `GET /contact-us/admin/{id}` in the confirmed API, so this renders the
/// row it was given and never waits on a second request — which is also why it
/// has no loading state.
///
/// [ContactInquiry.ipAddress] and [ContactInquiry.userAgent] are **not** part of
/// the list, and here they sit behind an expander: they are diagnostics, useful
/// when chasing spam and noise the rest of the time.
class ContactInquiryDetailPanel extends StatelessWidget {
  const ContactInquiryDetailPanel({
    super.key,
    required this.enquiry,
    required this.onClose,
    this.onEmail,
    this.showCloseButton = true,
  });

  final ContactInquiry enquiry;
  final VoidCallback onClose;

  /// Hands off to the device's mail app. Null hides the button — the console
  /// itself cannot send a reply, and a dead button would suggest it could.
  final VoidCallback? onEmail;

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
                  'Contact enquiry',
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
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AdminTokens.space5),
            children: [
              _IdentityCard(enquiry: enquiry, onEmail: onEmail),
              const SizedBox(height: AdminTokens.space4),
              _Card(
                icon: Icons.subject_rounded,
                title: 'Message',
                child: _Message(enquiry: enquiry),
              ),
              const SizedBox(height: AdminTokens.space4),
              _Card(
                icon: Icons.confirmation_number_outlined,
                title: 'Reference',
                child: Column(
                  children: [
                    _CopyRow(
                      label: 'Reference number',
                      value: AdminFormat.text(enquiry.referenceNumber),
                      copyable: (enquiry.referenceNumber ?? '')
                          .trim()
                          .isNotEmpty,
                    ),
                    _Row('Status', enquiry.statusLabel),
                  ],
                ),
              ),
              const SizedBox(height: AdminTokens.space4),
              _Card(
                icon: Icons.stadium_outlined,
                title: 'Sport complex',
                child: Column(
                  children: [
                    _Row(
                      'Complex',
                      enquiry.sportComplexName.isEmpty
                          ? '—'
                          : enquiry.sportComplexName,
                    ),
                    _Row(
                      'City',
                      AdminFormat.text(enquiry.sportComplex?.city),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AdminTokens.space4),
              _Card(
                icon: Icons.schedule_rounded,
                title: 'Timeline',
                child: Column(
                  children: [
                    _Row('Received', AdminFormat.dateTime(enquiry.createdAt)),
                    _Row('Last updated', AdminFormat.dateTime(enquiry.updatedAt)),
                    if (enquiry.isDeleted)
                      _Row('Deleted', AdminFormat.dateTime(enquiry.deletedAt)),
                  ],
                ),
              ),
              if (_hasDiagnostics) ...[
                const SizedBox(height: AdminTokens.space4),
                _Diagnostics(enquiry: enquiry),
              ],
              const SizedBox(height: AdminTokens.space5),
            ],
          ),
        ),
      ],
    );
  }

  bool get _hasDiagnostics =>
      (enquiry.ipAddress ?? '').trim().isNotEmpty ||
      (enquiry.userAgent ?? '').trim().isNotEmpty;
}

// -----------------------------------------------------------------------------

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.enquiry, this.onEmail});

  final ContactInquiry enquiry;
  final VoidCallback? onEmail;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final hasEmail = (enquiry.email ?? '').trim().isNotEmpty;

    return SolidCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ContactAvatar(enquiry: enquiry, size: 46),
              const SizedBox(width: AdminTokens.space4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      enquiry.displayName,
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      AdminFormat.text(enquiry.email),
                      style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              ContactStatusChip(statusRaw: enquiry.statusRaw),
            ],
          ),
          const SizedBox(height: AdminTokens.space4),
          Text(
            enquiry.subjectLabel,
            style: TextStyle(
              color: tokens.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (hasEmail && onEmail != null) ...[
            const SizedBox(height: AdminTokens.space4),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onEmail,
                icon: const Icon(Icons.reply_rounded, size: 18),
                label: const Text('Reply by email'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.enquiry});

  final ContactInquiry enquiry;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final text = (enquiry.message ?? '').trim();

    if (text.isEmpty) {
      return Text(
        'No message was sent with this enquiry.',
        style: TextStyle(
          color: tokens.textMuted,
          fontSize: 12.5,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    // SelectableText: the whole point of opening an enquiry is usually to copy
    // something out of it.
    return SelectableText(
      text,
      style: TextStyle(
        color: tokens.textSecondary,
        fontSize: 13,
        height: 1.55,
      ),
    );
  }
}

/// IP address and user agent, collapsed by default.
class _Diagnostics extends StatelessWidget {
  const _Diagnostics({required this.enquiry});

  final ContactInquiry enquiry;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return SolidCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(
            horizontal: AdminTokens.space5,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            AdminTokens.space5,
            0,
            AdminTokens.space5,
            AdminTokens.space4,
          ),
          leading: Icon(
            Icons.dns_outlined,
            size: 17,
            color: tokens.textMuted,
          ),
          title: Text(
            'Technical details',
            style: TextStyle(
              color: tokens.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            'Where the message was submitted from',
            style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
          ),
          children: [
            _Row('IP address', AdminFormat.text(enquiry.ipAddress)),
            _Row('User agent', AdminFormat.text(enquiry.userAgent), wrap: true),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.icon, required this.title, required this.child});

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return SolidCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: tokens.textMuted),
              const SizedBox(width: AdminTokens.space2),
              Text(
                title,
                style: TextStyle(
                  color: tokens.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: AdminTokens.space3),
          child,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.wrap = false});

  final String label;
  final String value;
  final bool wrap;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: TextStyle(color: tokens.textMuted, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: wrap ? 4 : 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tokens.textPrimary,
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

/// A row whose value can be copied — the reference number is the thing a desk
/// quotes back to whoever wrote in.
class _CopyRow extends StatelessWidget {
  const _CopyRow({
    required this.label,
    required this.value,
    required this.copyable,
  });

  final String label;
  final String value;
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: TextStyle(color: tokens.textMuted, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
          if (copyable)
            IconButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: value));
                if (!context.mounted) return;
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                  const SnackBar(content: Text('Reference number copied')),
                );
              },
              icon: const Icon(Icons.copy_rounded, size: 15),
              tooltip: 'Copy',
              color: tokens.textMuted,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 30, height: 30),
            ),
        ],
      ),
    );
  }
}