import 'package:flutter/material.dart';

import '../theme/coach_theme.dart';

/// One number on the overview's stat grid.
///
/// Laid out the way the website's coach dashboard lays its cards out — a
/// coloured stripe down the leading edge, a tinted icon, then the number above
/// its label — so the two dashboards read the same at a glance.
class CoachStatTile extends StatelessWidget {
  const CoachStatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return CoachCard(
      onTap: onTap,
      accentColor: color,
      padding: const EdgeInsets.all(CoachTokens.space3 + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(CoachTokens.space2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(CoachTokens.radiusSm),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: CoachTokens.space2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 26,
                height: 1.1,
                fontWeight: FontWeight.w800,
                color: CoachTokens.textDark,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              letterSpacing: 0.7,
              fontWeight: FontWeight.w600,
              color: CoachTokens.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
