import 'package:flutter/material.dart';

import '../theme/employee_theme.dart';
import 'employee_stat_tile.dart';

/// The loading / empty / error views every employee screen shares, so the
/// shimmer-then-content decision looks the same everywhere.

/// A pulsing grey block, used to sketch content while it loads.
class EmployeeShimmerBox extends StatefulWidget {
  const EmployeeShimmerBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius = EmployeeTokens.radiusSm,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  State<EmployeeShimmerBox> createState() => _EmployeeShimmerBoxState();
}

class _EmployeeShimmerBoxState extends State<EmployeeShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 0.95).animate(_controller),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// Placeholder cards for a list that is still loading.
class EmployeeListShimmer extends StatelessWidget {
  const EmployeeListShimmer({super.key, this.rows = 5});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        rows,
        (_) => EmployeeCard(
          margin: const EdgeInsets.only(bottom: EmployeeTokens.space3),
          child: Row(
            children: [
              const EmployeeShimmerBox(width: 42, height: 42, radius: 21),
              const SizedBox(width: EmployeeTokens.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    EmployeeShimmerBox(width: 150),
                    SizedBox(height: EmployeeTokens.space2),
                    EmployeeShimmerBox(width: 210, height: 11),
                  ],
                ),
              ),
              const EmployeeShimmerBox(width: 52, height: 22),
            ],
          ),
        ),
      ),
    );
  }
}

/// Placeholder tiles for a stat grid.
class EmployeeStatsShimmer extends StatelessWidget {
  const EmployeeStatsShimmer({super.key, this.tiles = 4});

  final int tiles;

  @override
  Widget build(BuildContext context) {
    // Same layout as the real tiles, so the page does not jump when the
    // numbers land.
    return EmployeeTileGrid(
      children: List.generate(
        tiles,
        (_) => const EmployeeCard(
          padding: EdgeInsets.all(EmployeeTokens.space3 + 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EmployeeShimmerBox(width: 34, height: 34, radius: 12),
              SizedBox(height: EmployeeTokens.space2),
              EmployeeShimmerBox(width: 58, height: 24),
              SizedBox(height: EmployeeTokens.space2),
              EmployeeShimmerBox(width: 88, height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

/// "There is nothing here" — a state, not a failure.
class EmployeeEmptyView extends StatelessWidget {
  const EmployeeEmptyView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Tightens the padding for use inside a card rather than a whole page.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: EmployeeTokens.space6,
        vertical: compact ? EmployeeTokens.space6 : EmployeeTokens.space8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(EmployeeTokens.space4),
            decoration: const BoxDecoration(
              color: EmployeeTokens.brandSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 30, color: EmployeeTokens.brand),
          ),
          const SizedBox(height: EmployeeTokens.space4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: EmployeeTokens.textDark,
            ),
          ),
          const SizedBox(height: EmployeeTokens.space2),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: EmployeeTokens.textBody,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: EmployeeTokens.space5),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: EmployeeTokens.brand,
                padding: const EdgeInsets.symmetric(
                  horizontal: EmployeeTokens.space6,
                  vertical: EmployeeTokens.space3,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(EmployeeTokens.radiusSm),
                ),
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

/// A failed load, with the server's own message and a way back.
class EmployeeErrorView extends StatelessWidget {
  const EmployeeErrorView({
    super.key,
    required this.message,
    this.onRetry,
    this.compact = false,
  });

  final String message;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: EmployeeTokens.space6,
        vertical: compact ? EmployeeTokens.space6 : EmployeeTokens.space8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(EmployeeTokens.space4),
            decoration: BoxDecoration(
              color: EmployeeTokens.danger.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              size: 30,
              color: EmployeeTokens.danger,
            ),
          ),
          const SizedBox(height: EmployeeTokens.space4),
          const Text(
            "That didn't load",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: EmployeeTokens.textDark,
            ),
          ),
          const SizedBox(height: EmployeeTokens.space2),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: EmployeeTokens.textBody,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: EmployeeTokens.space5),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
              style: OutlinedButton.styleFrom(
                foregroundColor: EmployeeTokens.brand,
                side: const BorderSide(color: EmployeeTokens.border),
                padding: const EdgeInsets.symmetric(
                  horizontal: EmployeeTokens.space5,
                  vertical: EmployeeTokens.space3,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(EmployeeTokens.radiusSm),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A hairline progress bar for a refresh happening over content that is already
/// on screen — so a pull-to-refresh does not blank the page.
class EmployeeRefreshLine extends StatelessWidget {
  const EmployeeRefreshLine({super.key, required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: EmployeeTokens.fast,
      child: const SizedBox(
        height: 2,
        child: LinearProgressIndicator(
          minHeight: 2,
          backgroundColor: Colors.transparent,
          valueColor: AlwaysStoppedAnimation(EmployeeTokens.brand),
        ),
      ),
    );
  }
}

/// A section heading with an optional trailing count / action.
class EmployeeSectionHeader extends StatelessWidget {
  const EmployeeSectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.padding = const EdgeInsets.only(
      top: EmployeeTokens.space6,
      bottom: EmployeeTokens.space3,
    ),
  });

  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
                color: EmployeeTokens.textDark,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// The "you are only seeing your own complex" note the website prints above
/// every operations module.
///
/// Worth repeating on each screen rather than saying it once on the menu: an
/// employee looking at three sports and wondering where the other venue's went
/// needs the answer on the screen they are looking at.
class EmployeeScopeNotice extends StatelessWidget {
  const EmployeeScopeNotice({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: EmployeeTokens.space3,
        vertical: EmployeeTokens.space2 + 2,
      ),
      decoration: BoxDecoration(
        color: EmployeeTokens.brandSoft,
        borderRadius: BorderRadius.circular(EmployeeTokens.radiusSm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 15,
            color: EmployeeTokens.brand,
          ),
          const SizedBox(width: EmployeeTokens.space2),
          Expanded(
            child: Text(
              message ??
                  'You are viewing and managing records for your own sports '
                      'complex only.',
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.4,
                color: EmployeeTokens.textBody,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The next-page footer for an infinite list: a spinner while a page is in
/// flight, "that's everything" once the list is exhausted, nothing otherwise.
class EmployeeListFooter extends StatelessWidget {
  const EmployeeListFooter({
    super.key,
    required this.loading,
    required this.hasMore,
    required this.isEmpty,
    this.exhaustedLabel = "That's everything",
  });

  final bool loading;
  final bool hasMore;
  final bool isEmpty;
  final String exhaustedLabel;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: EmployeeTokens.space5),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: EmployeeTokens.brand,
            ),
          ),
        ),
      );
    }

    if (hasMore || isEmpty) return const SizedBox(height: EmployeeTokens.space6);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: EmployeeTokens.space5),
      child: Center(
        child: Text(
          exhaustedLabel,
          style: const TextStyle(
            fontSize: 12,
            color: EmployeeTokens.textMuted,
          ),
        ),
      ),
    );
  }
}
