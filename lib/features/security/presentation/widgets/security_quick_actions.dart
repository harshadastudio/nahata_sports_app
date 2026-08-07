import 'package:flutter/material.dart';

import '../../../admin/presentation/theme/admin_theme.dart';

/// The six things a gate desk does, one tap from the dashboard.
class SecurityQuickActions extends StatelessWidget {
  const SecurityQuickActions({
    super.key,
    required this.onGenerate,
    required this.onScan,
    required this.onManualVerify,
    required this.onLookup,
    required this.onTodaysVisitors,
    required this.onReports,
    this.canGenerate = true,
    this.canScan = true,
    this.canOpenReports = true,
  });

  final VoidCallback onGenerate;
  final VoidCallback onScan;
  final VoidCallback onManualVerify;
  final VoidCallback onLookup;
  final VoidCallback onTodaysVisitors;
  final VoidCallback onReports;

  /// Permission gates. An action the account may not perform is not shown —
  /// offering a button that is certain to be refused is worse than omitting it.
  final bool canGenerate;
  final bool canScan;
  final bool canOpenReports;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = switch (width) {
      < AdminTokens.mobileMax => 2,
      < AdminTokens.tabletMax => 3,
      _ => 6,
    };

    final actions = <Widget>[
      if (canGenerate)
        _Action(
          label: 'Generate Pass',
          caption: 'New visitor',
          icon: Icons.add_card_rounded,
          color: const Color(0xFF1A237E),
          onTap: onGenerate,
        ),
      if (canScan) ...[
        _Action(
          label: 'Scan QR',
          caption: 'Camera',
          icon: Icons.qr_code_scanner_rounded,
          color: const Color(0xFF10B981),
          onTap: onScan,
        ),
        _Action(
          label: 'Manual Verify',
          caption: 'Type a code',
          icon: Icons.pin_rounded,
          color: const Color(0xFF0EA5E9),
          onTap: onManualVerify,
        ),
      ],
      _Action(
        label: 'Lookup Pass',
        caption: 'Check only',
        icon: Icons.plagiarism_outlined,
        color: const Color(0xFF8B5CF6),
        onTap: onLookup,
      ),
      _Action(
        label: "Today's Visitors",
        caption: 'Full list',
        icon: Icons.today_rounded,
        color: const Color(0xFFF59E0B),
        onTap: onTodaysVisitors,
      ),
      if (canOpenReports)
        _Action(
          label: 'Reports',
          caption: 'Analytics',
          icon: Icons.insights_rounded,
          color: const Color(0xFFEC4899),
          onTap: onReports,
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = AdminTokens.space3;
        final cardWidth =
            (constraints.maxWidth - (gap * (columns - 1))) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: actions
              .map((action) => SizedBox(width: cardWidth, child: action))
              .toList(),
        );
      },
    );
  }
}

class _Action extends StatefulWidget {
  const _Action({
    required this.label,
    required this.caption,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String caption;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_Action> createState() => _ActionState();
}

class _ActionState extends State<_Action> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: AdminTokens.fast,
          curve: AdminTokens.curve,
          padding: const EdgeInsets.all(AdminTokens.space4),
          decoration: BoxDecoration(
            color: _hovered
                ? widget.color.withValues(alpha: 0.10)
                : tokens.surface,
            borderRadius: BorderRadius.circular(AdminTokens.radiusLg),
            border: Border.all(
              color: _hovered
                  ? widget.color.withValues(alpha: 0.45)
                  : tokens.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
                  gradient: LinearGradient(
                    colors: [
                      widget.color.withValues(alpha: 0.22),
                      widget.color.withValues(alpha: 0.07),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Icon(widget.icon, size: 20, color: widget.color),
              ),
              const SizedBox(height: AdminTokens.space3),
              Text(
                widget.label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
              Text(
                widget.caption,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}