import 'package:flutter/material.dart';

import '../../domain/entities/contact_inquiry.dart';
import '../theme/admin_theme.dart';

/// Colour and icon per contact-enquiry state, from the console's own semantic
/// tokens so this module reads like the rest of the panel.
extension ContactStatusStyle on AdminTokens {
  Color contactStatusColor(ContactInquiryStatus? status) {
    switch (status) {
      case ContactInquiryStatus.isNew:
        // Untouched work — the same blue the console uses for "needs looking
        // at" everywhere else.
        return info;
      case ContactInquiryStatus.read:
        return warning;
      case ContactInquiryStatus.replied:
        return success;
      case null:
        return textMuted;
    }
  }

  IconData contactStatusIcon(ContactInquiryStatus? status) {
    switch (status) {
      case ContactInquiryStatus.isNew:
        return Icons.mark_email_unread_outlined;
      case ContactInquiryStatus.read:
        return Icons.drafts_outlined;
      case ContactInquiryStatus.replied:
        return Icons.mark_email_read_outlined;
      case null:
        return Icons.help_outline_rounded;
    }
  }

  List<Color> contactStatusGradient(ContactInquiryStatus status) {
    switch (status) {
      case ContactInquiryStatus.isNew:
        return const [Color(0xFF2563EB), Color(0xFF60A5FA)];
      case ContactInquiryStatus.read:
        return const [Color(0xFFD97706), Color(0xFFFBBF24)];
      case ContactInquiryStatus.replied:
        return const [Color(0xFF059669), Color(0xFF6EE7B7)];
    }
  }
}

/// A dot-and-label pill for an enquiry's state.
///
/// Takes the **raw** value, so a status this build has never heard of still
/// renders with its own text rather than being flattened to "Unknown".
class ContactStatusChip extends StatelessWidget {
  const ContactStatusChip({super.key, required this.statusRaw, this.dense = false});

  final String? statusRaw;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final status = ContactInquiryStatus.tryParse(statusRaw);
    final color = tokens.contactStatusColor(status);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AdminTokens.space2 : AdminTokens.space3,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AdminTokens.radiusPill),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(tokens.contactStatusIcon(status), size: dense ? 12 : 13, color: color),
          SizedBox(width: dense ? 4 : AdminTokens.space2),
          Text(
            ContactInquiryStatus.labelFor(statusRaw),
            style: TextStyle(
              color: color,
              fontSize: dense ? 11 : 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}