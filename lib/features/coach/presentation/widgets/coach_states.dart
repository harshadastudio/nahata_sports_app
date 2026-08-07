import 'package:flutter/material.dart';

import '../theme/coach_theme.dart';

/// The loading / empty / error views every coach screen shares, so the
/// shimmer-then-content decision looks the same everywhere.

/// A pulsing grey block, used to sketch content while it loads.
class CoachShimmerBox extends StatefulWidget {
  const CoachShimmerBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius = CoachTokens.radiusSm,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  State<CoachShimmerBox> createState() => _CoachShimmerBoxState();
}

class _CoachShimmerBoxState extends State<CoachShimmerBox>
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
class CoachListShimmer extends StatelessWidget {
  const CoachListShimmer({super.key, this.rows = 5});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        rows,
        (_) => CoachCard(
          margin: const EdgeInsets.only(bottom: CoachTokens.space3),
          child: Row(
            children: [
              const CoachShimmerBox(width: 44, height: 44, radius: 22),
              const SizedBox(width: CoachTokens.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    CoachShimmerBox(width: 140),
                    SizedBox(height: CoachTokens.space2),
                    CoachShimmerBox(width: 200, height: 11),
                  ],
                ),
              ),
              const CoachShimmerBox(width: 52, height: 22),
            ],
          ),
        ),
      ),
    );
  }
}

/// Placeholder tiles for the overview's stat grid.
class CoachStatsShimmer extends StatelessWidget {
  const CoachStatsShimmer({super.key, this.tiles = 6});

  final int tiles;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: CoachTokens.space3,
      crossAxisSpacing: CoachTokens.space3,
      childAspectRatio: 1.45,
      children: List.generate(
        tiles,
        (_) => CoachCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              CoachShimmerBox(width: 36, height: 36, radius: 12),
              CoachShimmerBox(width: 54, height: 24),
              CoachShimmerBox(width: 84, height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

/// "There is nothing here" — a state, not a failure.
class CoachEmptyView extends StatelessWidget {
  const CoachEmptyView({
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
        horizontal: CoachTokens.space6,
        vertical: compact ? CoachTokens.space6 : CoachTokens.space8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(CoachTokens.space4),
            decoration: BoxDecoration(
              color: CoachTokens.brandSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 30, color: CoachTokens.brand),
          ),
          const SizedBox(height: CoachTokens.space4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: CoachTokens.textDark,
            ),
          ),
          const SizedBox(height: CoachTokens.space2),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: CoachTokens.textBody,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: CoachTokens.space5),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: CoachTokens.brand,
                padding: const EdgeInsets.symmetric(
                  horizontal: CoachTokens.space6,
                  vertical: CoachTokens.space3,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(CoachTokens.radiusSm),
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
class CoachErrorView extends StatelessWidget {
  const CoachErrorView({
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
        horizontal: CoachTokens.space6,
        vertical: compact ? CoachTokens.space6 : CoachTokens.space8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(CoachTokens.space4),
            decoration: BoxDecoration(
              color: CoachTokens.danger.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              size: 30,
              color: CoachTokens.danger,
            ),
          ),
          const SizedBox(height: CoachTokens.space4),
          const Text(
            "That didn't load",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: CoachTokens.textDark,
            ),
          ),
          const SizedBox(height: CoachTokens.space2),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: CoachTokens.textBody,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: CoachTokens.space5),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
              style: OutlinedButton.styleFrom(
                foregroundColor: CoachTokens.brand,
                side: const BorderSide(color: CoachTokens.border),
                padding: const EdgeInsets.symmetric(
                  horizontal: CoachTokens.space5,
                  vertical: CoachTokens.space3,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(CoachTokens.radiusSm),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A hairline progress bar for a refresh happening over content that is
/// already on screen — so a pull-to-refresh does not blank the page.
class CoachRefreshLine extends StatelessWidget {
  const CoachRefreshLine({super.key, required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: CoachTokens.fast,
      child: const SizedBox(
        height: 2,
        child: LinearProgressIndicator(
          minHeight: 2,
          backgroundColor: Colors.transparent,
          valueColor: AlwaysStoppedAnimation(CoachTokens.brand),
        ),
      ),
    );
  }
}

/// A section heading with an optional trailing count / action.
class CoachSectionHeader extends StatelessWidget {
  const CoachSectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.padding = const EdgeInsets.only(
      top: CoachTokens.space6,
      bottom: CoachTokens.space3,
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
                color: CoachTokens.textDark,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
