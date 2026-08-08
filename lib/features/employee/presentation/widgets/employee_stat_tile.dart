import 'package:flutter/material.dart';

import '../theme/employee_theme.dart';

/// Lays tiles out in equal-width columns, each row as tall as its tallest tile.
///
/// Deliberately **not** a `GridView` with a `childAspectRatio`. A fixed ratio
/// ties the tile's height to the screen's width, and the two have nothing to do
/// with each other: the content is text, so its height follows the user's font
/// scale. On a 320dp phone a tile is ~138px wide, which at ratio 1.4 leaves
/// ~99px of height for content that needs ~111px — and it overflows before the
/// font scale is touched at all.
///
/// [IntrinsicHeight] costs an extra layout pass over each row. With a handful
/// of tiles that is not measurable, and it buys a layout that cannot overflow
/// on any screen at any text size.
class EmployeeTileGrid extends StatelessWidget {
  const EmployeeTileGrid({
    super.key,
    required this.children,
    this.columns = 2,
    this.spacing = EmployeeTokens.space3,
  });

  final List<Widget> children;
  final int columns;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    final rows = <Widget>[];

    for (var start = 0; start < children.length; start += columns) {
      final end = (start + columns).clamp(0, children.length);
      final slice = children.sublist(start, end);

      rows.add(
        IntrinsicHeight(
          // `stretch` is what makes both tiles in a row match the taller one;
          // without it a short tile would float centred against a tall one.
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var column = 0; column < columns; column++) ...[
                if (column > 0) SizedBox(width: spacing),
                Expanded(
                  // A trailing gap on the last row keeps the final tile the
                  // same width as the ones above it rather than stretching it
                  // across the row.
                  child: column < slice.length
                      ? slice[column]
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );

      if (end < children.length) rows.add(SizedBox(height: spacing));
    }

    return Column(children: rows);
  }
}

/// One number on a stat grid.
///
/// Laid out the way the website's employee dashboard lays its cards out — a
/// coloured stripe down the leading edge, a tinted icon, then the number above
/// its label — so the two dashboards read the same at a glance.
class EmployeeStatTile extends StatelessWidget {
  const EmployeeStatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.trend,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  /// Percentage change against the previous window. Null when the backend had
  /// no baseline — the badge is dropped rather than showing a fabricated
  /// `+100%`.
  final double? trend;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return EmployeeCard(
      onTap: onTap,
      accentColor: color,
      padding: const EdgeInsets.all(EmployeeTokens.space3 + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(EmployeeTokens.space2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(EmployeeTokens.radiusSm),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: EmployeeTokens.space2),
              if (trend != null)
                // The badge is text and grows with the user's font scale,
                // while the tile's width is fixed by the column. Scaling it
                // down is better than clipping it — the arrow still reads at
                // a glance even when the number shrinks.
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: _trendBadge(trend!),
                  ),
                )
              else
                const Spacer(),
            ],
          ),
          const SizedBox(height: EmployeeTokens.space2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 25,
                height: 1.1,
                fontWeight: FontWeight.w800,
                color: EmployeeTokens.textDark,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 9.5,
              letterSpacing: 0.7,
              fontWeight: FontWeight.w600,
              color: EmployeeTokens.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _trendBadge(double value) {
    final rising = value >= 0;
    final tone = rising ? EmployeeTokens.success : EmployeeTokens.danger;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(EmployeeTokens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            rising ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            size: 11,
            color: tone,
          ),
          const SizedBox(width: 2),
          Text(
            '${value.abs().toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: tone,
            ),
          ),
        ],
      ),
    );
  }
}

/// A wide summary tile for a strip above a list — the fee queue's "awaiting
/// approval", the ledger's "collected". Reads left-to-right rather than
/// top-to-bottom so three of them fit on one row on a phone.
class EmployeeSummaryTile extends StatelessWidget {
  const EmployeeSummaryTile({
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
    return EmployeeCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: EmployeeTokens.space3,
        vertical: EmployeeTokens.space3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(height: EmployeeTokens.space2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontSize: 19,
                height: 1.1,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label.toUpperCase(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 9,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w600,
              color: EmployeeTokens.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
