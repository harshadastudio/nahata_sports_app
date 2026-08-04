import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/admin_theme.dart';

/// The surface every panel in the dashboard sits on.
///
/// Translucent fill + a backdrop blur gives the glassmorphism look; the blur is
/// skipped when [blur] is 0 so long lists are not paying for a filter layer per
/// row (`BackdropFilter` is the expensive part, not the colour).
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AdminTokens.space5),
    this.radius = AdminTokens.radiusLg,
    this.blur = 18,
    this.color,
    this.borderColor,
    this.shadows,
    this.clip = true,
    this.width,
    this.height,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;
  final Color? color;
  final Color? borderColor;
  final List<BoxShadow>? shadows;
  final bool clip;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final borderRadius = BorderRadius.circular(radius);

    Widget content = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? tokens.glass,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor ?? tokens.border),
      ),
      child: child,
    );

    if (blur > 0) {
      content = ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: content,
        ),
      );
    } else if (clip) {
      content = ClipRRect(borderRadius: borderRadius, child: content);
    }

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: shadows ?? tokens.softShadow,
      ),
      child: content,
    );
  }
}

/// A plain (unblurred) card — used inside scrolling lists and tables where a
/// backdrop filter per row would cost more than it is worth.
class SolidCard extends StatelessWidget {
  const SolidCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AdminTokens.space5),
    this.radius = AdminTokens.radiusLg,
    this.color,
    this.borderColor,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final Color? borderColor;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? tokens.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? tokens.border),
      ),
      child: child,
    );
  }
}

/// Adds a lift-and-tint hover response to any child. Pointer hover only exists
/// on desktop/web, so this is inert on touch devices and costs nothing there.
class HoverLift extends StatefulWidget {
  const HoverLift({
    super.key,
    required this.builder,
    this.onTap,
    this.cursor = SystemMouseCursors.click,
  });

  final Widget Function(BuildContext context, bool hovered) builder;
  final VoidCallback? onTap;
  final MouseCursor cursor;

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap == null ? MouseCursor.defer : widget.cursor,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _hovered && widget.onTap != null ? 1.01 : 1,
          duration: AdminTokens.fast,
          curve: AdminTokens.curve,
          child: widget.builder(context, _hovered),
        ),
      ),
    );
  }
}
