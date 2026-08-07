import 'package:flutter/material.dart';

import '../../../admin/presentation/theme/admin_theme.dart';

/// The title and the one button every gate console needs: Scan QR.
class GatePageHeader extends StatelessWidget {
  const GatePageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onScan,
    this.scanLabel = 'Scan QR',
  });

  final String title;
  final String subtitle;
  final VoidCallback onScan;
  final String scanLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final narrow = MediaQuery.sizeOf(context).width < AdminTokens.tabletMax;

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: TextStyle(
            color: tokens.textPrimary,
            fontSize: narrow ? 19 : 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            height: 1.2,
          ),
        ),
        Text(
          subtitle,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
        ),
      ],
    );

    final scan = FilledButton.icon(
      onPressed: onScan,
      icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
      label: Text(scanLabel),
      style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
    );

    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [text, const SizedBox(height: AdminTokens.space3), scan],
      );
    }

    return Row(children: [Expanded(child: text), scan]);
  }
}