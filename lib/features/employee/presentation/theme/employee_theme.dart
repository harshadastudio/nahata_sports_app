import 'package:flutter/material.dart';

/// Design tokens for the employee dashboard.
///
/// Deliberately a copy of the coach module's `CoachTokens` rather than an
/// import of it: the two features stay independently movable, and an employee
/// screen must be free to diverge (it carries denser tables and a wider status
/// vocabulary) without a change rippling into the coach screens.
///
/// The brand navy is the one the rest of the app already ships
/// (`0xFF0A198D`), so an employee moving between the booking screens and the
/// dashboard does not see the app change colour. Status colours match the
/// website's employee dashboard one-for-one, so the same record reads the same
/// on a phone and on the web.
class EmployeeTokens {
  const EmployeeTokens._();

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

  /// The card elevation used everywhere on these screens — one soft shadow, so
  /// stacked cards do not compound into a grey page.
  static List<BoxShadow> get cardShadow => const [
        BoxShadow(
          color: Color(0x0F0F172A),
          blurRadius: 14,
          offset: Offset(0, 4),
        ),
      ];

  /// The colour for a status word.
  ///
  /// One table for the whole module, because the same words mean the same thing
  /// across bookings, payments, fees, enquiries and attendance — and a booking
  /// that is `Confirmed` should not be a different green from a fee that is
  /// `Approved`.
  ///
  /// Unknown values fall through to a neutral slate rather than a guess: a
  /// mislabelled colour is worse than an uncoloured one.
  static Color statusColor(String? status) {
    switch ((status ?? '').trim().toLowerCase()) {
      // Settled, collected, present.
      case 'paid':
      case 'approved':
      case 'confirmed':
      case 'present':
      case 'active':
        return success;

      // Waiting on somebody.
      case 'pending':
      case 'partial':
      case 'late':
      case 'reviewed':
      case 'upcoming':
        return warning;

      // Refused, failed, gone.
      case 'rejected':
      case 'failed':
      case 'cancelled':
      case 'absent':
      case 'overdue':
      case 'blocked':
        return danger;

      // In flight, or informational.
      case 'contacted':
      case 'refunded':
      case 'completed':
      case 'inactive':
        return info;

      default:
        return textMuted;
    }
  }

  /// The colour for a notification's type chip, matching the website's palette.
  static Color notificationTypeColor(String? type) {
    switch ((type ?? '').trim().toLowerCase()) {
      case 'booking':
        return purple;
      case 'payment':
        return success;
      case 'alert':
        return danger;
      case 'promotion':
        return warning;
      case 'feedback':
        return textMuted;
      case 'system':
      default:
        return info;
    }
  }

  /// The colour band a payment source reads in — court, event and coaching are
  /// three different books being merged into one ledger, and the tint is how a
  /// reader tells them apart at a glance.
  static Color paymentTypeColor(String? type) {
    switch ((type ?? '').trim().toLowerCase()) {
      case 'facility':
        return info;
      case 'event':
        return purple;
      case 'coaching':
        return accent;
      default:
        return textMuted;
    }
  }
}

/// A white rounded card — the one container every employee screen is built
/// from.
class EmployeeCard extends StatelessWidget {
  const EmployeeCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(EmployeeTokens.space4),
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
        color: EmployeeTokens.surface,
        borderRadius: BorderRadius.circular(EmployeeTokens.radiusMd),
        boxShadow: EmployeeTokens.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      // The stripe is positioned rather than a stretched Row child: a card sits
      // in an unbounded-height list, and CrossAxisAlignment.stretch there forces
      // an infinite height on its children. A Stack sizes to the padded content
      // and the stripe fills whatever that came out to.
      //
      // A left-only BoxDecoration border is not an option either — Flutter
      // rejects a non-uniform border combined with a borderRadius.
      child: Stack(
        children: [
          Padding(padding: padding, child: child),
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
        borderRadius: BorderRadius.circular(EmployeeTokens.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(EmployeeTokens.radiusMd),
          child: content,
        ),
      ),
    );
  }
}

/// A small pill for a status word.
class EmployeeChip extends StatelessWidget {
  const EmployeeChip({
    super.key,
    required this.label,
    this.color,
    this.icon,
    this.dense = false,
  });

  final String label;

  /// Defaults to [EmployeeTokens.statusColor] of [label].
  final Color? color;

  final IconData? icon;

  /// Tightens the pill for use inside a dense table row.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    if (label.trim().isEmpty) return const SizedBox.shrink();

    final tone = color ?? EmployeeTokens.statusColor(label);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? EmployeeTokens.space2 : EmployeeTokens.space3,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(EmployeeTokens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 11 : 13, color: tone),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: tone,
              fontSize: dense ? 10.5 : 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// A circular initial, used wherever a person has no photo.
class EmployeeAvatar extends StatelessWidget {
  const EmployeeAvatar({
    super.key,
    required this.initial,
    this.imageUrl,
    this.radius = 22,
    this.color = EmployeeTokens.brand,
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
                fontSize: radius * 0.7,
              ),
            ),
    );
  }
}

/// A label/value line — the unit every detail sheet in this module is built
/// from. Renders nothing at all for an empty value, so a sheet never shows a
/// row of em dashes for fields the record simply does not carry.
class EmployeeDetailRow extends StatelessWidget {
  const EmployeeDetailRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.monospace = false,
  });

  final String label;
  final String value;
  final Color? valueColor;

  /// For ids and codes, where character alignment matters more than looks.
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty || value.trim() == '—') {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: EmployeeTokens.space2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: EmployeeTokens.textMuted,
              ),
            ),
          ),
          const SizedBox(width: EmployeeTokens.space2),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w600,
                fontFamily: monospace ? 'monospace' : null,
                color: valueColor ?? EmployeeTokens.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
