import 'package:flutter/material.dart';

/// Design tokens for the coach dashboard.
///
/// Deliberately not the admin console's `AdminTokens`: the admin module is
/// built around a desktop shell (sidebar, data tables, detail drawers) that the
/// coach screens do not use. These are mobile-first and keep the brand navy the
/// rest of the app already ships (`0xFF0A198D`), so a coach moving between the
/// old screens and the new ones does not see the app change colour.
///
/// The status colours match the website's coach dashboard one-for-one so a
/// coach reading the same record on a phone and on the web sees the same
/// badge in the same colour.
class CoachTokens {
  const CoachTokens._();

  // ── Brand ──────────────────────────────────────────────────────────────────
  static const Color brand = Color(0xFF0A198D);
  static const Color brandSoft = Color(0xFFEEF1FB);
  static const Color accent = Color(0xFFFF6B2C);

  // ── Surfaces ───────────────────────────────────────────────────────────────
  static const Color canvas = Color(0xFFF6F8FC);
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFE6EAF2);

  // ── Text ───────────────────────────────────────────────────────────────────
  static const Color textDark = Color(0xFF0F172A);
  static const Color textBody = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);

  // ── Semantic ───────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF059669);
  static const Color warning = Color(0xFFD97706);
  static const Color danger = Color(0xFFDC2626);
  static const Color info = Color(0xFF2563EB);
  static const Color purple = Color(0xFF6C52E8);

  // ── Spacing ────────────────────────────────────────────────────────────────
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 20;
  static const double space6 = 24;
  static const double space8 = 32;

  // ── Radius ─────────────────────────────────────────────────────────────────
  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 18;
  static const double radiusPill = 999;

  // ── Motion ─────────────────────────────────────────────────────────────────
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 240);
  static const Curve curve = Curves.easeOutCubic;

  /// The card elevation used everywhere on these screens — one soft shadow, so
  /// stacked cards do not compound into a grey page.
  static List<BoxShadow> get cardShadow => const [
        BoxShadow(
          color: Color(0x0F0F172A),
          blurRadius: 14,
          offset: Offset(0, 4),
        ),
      ];

  /// The colour for an attendance / enrollment / enquiry status word.
  ///
  /// Unknown values fall through to a neutral slate rather than a guess — a
  /// mislabelled colour is worse than an uncoloured one.
  static Color statusColor(String? status) {
    switch ((status ?? '').trim().toLowerCase()) {
      case 'present':
      case 'active':
      case 'approved':
      case 'paid':
      case 'completed':
        return success;
      case 'late':
      case 'pending':
      case 'reviewed':
      case 'upcoming':
        return warning;
      case 'absent':
      case 'rejected':
      case 'overdue':
      case 'dropped':
        return danger;
      case 'leave':
      case 'contacted':
      case 'transferred':
      case 'in progress':
        return info;
      default:
        return textMuted;
    }
  }

  /// The colour band the top-performers route assigns (`green`/`blue`/
  /// `orange`), mapped onto this palette.
  static Color performanceColor(String? colorKey) {
    switch ((colorKey ?? '').trim().toLowerCase()) {
      case 'green':
        return success;
      case 'blue':
        return info;
      case 'orange':
        return accent;
      default:
        return brand;
    }
  }

  /// Attendance percentage → the colour it should be read in. Deliberately
  /// coarse: three bands, not a gradient.
  static Color attendanceColor(int? percent) {
    if (percent == null) return textMuted;
    if (percent >= 75) return success;
    if (percent >= 50) return warning;
    return danger;
  }
}

/// A white rounded card — the one container every coach screen is built from.
class CoachCard extends StatelessWidget {
  const CoachCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(CoachTokens.space4),
    this.margin,
    this.onTap,
    this.accentColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  /// Draws a 4px stripe down the leading edge — used to colour-code a row by
  /// status without adding another badge.
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      decoration: BoxDecoration(
        color: CoachTokens.surface,
        borderRadius: BorderRadius.circular(CoachTokens.radiusMd),
        boxShadow: CoachTokens.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      // The stripe is positioned rather than a stretched Row child: a card
      // sits in an unbounded-height list, and CrossAxisAlignment.stretch there
      // forces an infinite height on its children. A Stack sizes to the
      // padded content and the stripe fills whatever that came out to.
      //
      // A left-only BoxDecoration border is not an option either — Flutter
      // rejects a non-uniform border combined with a borderRadius.
      child: Stack(
        children: [
          Padding(
            padding: padding,
            child: child,
          ),
          if (accentColor != null)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 4,
              child: ColoredBox(color: accentColor!),
            ),
        ],
      ),
    );

    if (onTap == null) {
      return Container(margin: margin, child: content);
    }

    return Container(
      margin: margin,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(CoachTokens.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(CoachTokens.radiusMd),
          child: content,
        ),
      ),
    );
  }
}

/// A small pill for a status word.
class CoachStatusChip extends StatelessWidget {
  const CoachStatusChip({
    super.key,
    required this.label,
    this.color,
    this.icon,
  });

  final String label;

  /// Defaults to [CoachTokens.statusColor] of [label].
  final Color? color;

  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    if (label.trim().isEmpty) return const SizedBox.shrink();

    final tone = color ?? CoachTokens.statusColor(label);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CoachTokens.space3,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(CoachTokens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: tone),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: tone,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// A circular initial, used wherever a student has no photo.
class CoachAvatar extends StatelessWidget {
  const CoachAvatar({
    super.key,
    required this.initial,
    this.imageUrl,
    this.radius = 22,
    this.color = CoachTokens.brand,
  });

  final String initial;
  final String? imageUrl;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final url = (imageUrl ?? '').trim();

    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.12),
      backgroundImage: url.isEmpty ? null : NetworkImage(url),
      child: url.isNotEmpty
          ? null
          : Text(
              initial,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: radius * 0.72,
              ),
            ),
    );
  }
}
