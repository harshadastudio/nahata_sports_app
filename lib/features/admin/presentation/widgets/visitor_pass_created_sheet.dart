import 'package:flutter/material.dart';

import '../../core/admin_log.dart';
import '../../domain/entities/visitor_pass.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';
import '../utils/visitor_pass_sharing.dart';
import 'glass_card.dart';
import 'visitor_pass_detail_panel.dart';
import 'visitor_pass_qr_view.dart';

/// The pass that was just generated: its QR, its code, and every way to get it
/// to the visitor.
///
/// This is the point of the whole create flow — the desk needs the QR in front
/// of it the moment the pass exists, not after finding the row in the list.
class VisitorPassCreatedSheet extends StatelessWidget {
  const VisitorPassCreatedSheet({
    super.key,
    required this.pass,
    required this.onShareOutcome,
    this.onEmail,
  });

  final VisitorPass pass;
  final void Function(ShareOutcome outcome) onShareOutcome;
  final VoidCallback? onEmail;

  static Future<void> show(
    BuildContext context, {
    required VisitorPass pass,
    required void Function(ShareOutcome outcome) onShareOutcome,
    VoidCallback? onEmail,
  }) {
    AdminLog.ui('Created-pass sheet opened for ${pass.reference}');

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AdminTheme.of(context).canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AdminTokens.radiusXl),
        ),
      ),
      builder: (_) => VisitorPassCreatedSheet(
        pass: pass,
        onShareOutcome: onShareOutcome,
        onEmail: onEmail,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: AdminTokens.space3),
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: tokens.borderStrong,
                  borderRadius: BorderRadius.circular(AdminTokens.radiusPill),
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(AdminTokens.space5),
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: tokens.success.withValues(alpha: 0.12),
                        ),
                        child: Icon(
                          Icons.check_circle_rounded,
                          size: 24,
                          color: tokens.success,
                        ),
                      ),
                      const SizedBox(width: AdminTokens.space4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Visitor pass generated',
                              style: TextStyle(
                                color: tokens.textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              pass.displayName,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: tokens.textMuted,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, size: 20),
                        color: tokens.textMuted,
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                  const SizedBox(height: AdminTokens.space5),
                  SolidCard(
                    child: Column(
                      children: [
                        VisitorPassQrView(pass: pass, size: 210),
                        const SizedBox(height: AdminTokens.space5),
                        VisitorPassShareBar(
                          pass: pass,
                          onOutcome: onShareOutcome,
                          onEmail: onEmail,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AdminTokens.space4),
                  SolidCard(
                    padding: const EdgeInsets.all(AdminTokens.space4),
                    child: Column(
                      children: [
                        _Row('Phone', AdminFormat.text(pass.phoneNumber)),
                        _Row('Purpose', AdminFormat.text(pass.visitPurpose)),
                        _Row(
                          'Sport complex',
                          AdminFormat.text(pass.sportComplexName),
                        ),
                        _Row('Generated', AdminFormat.dateTime(pass.createdAt)),
                      ],
                    ),
                  ),
                  const SizedBox(height: AdminTokens.space5),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
          ],
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
            width: 112,
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
