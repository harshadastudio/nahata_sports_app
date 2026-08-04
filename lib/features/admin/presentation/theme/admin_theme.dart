import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../domain/entities/admin_role.dart';

/// The admin dashboard's design system.
///
/// The panel themes itself rather than inheriting the consumer app's theme, so
/// the SaaS look (dense typography, its own surfaces, light/dark switching)
/// stays contained and none of the customer-facing screens shift.
///
/// Everything the widgets need — spacing, radii, elevation, semantic colour —
/// is read from [AdminTokens] via `AdminTheme.of(context)`, so a future module
/// never picks its own numbers.
@immutable
class AdminTokens extends ThemeExtension<AdminTokens> {
  const AdminTokens({
    required this.brightness,
    required this.canvas,
    required this.surface,
    required this.surfaceAlt,
    required this.glass,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.accentSoft,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.shadow,
  });

  final Brightness brightness;

  final Color canvas;
  final Color surface;
  final Color surfaceAlt;

  /// Fill for glassmorphism cards — translucent, blurred behind.
  final Color glass;

  final Color border;
  final Color borderStrong;

  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  final Color accent;
  final Color accentSoft;

  final Color success;
  final Color warning;
  final Color danger;
  final Color info;

  final Color shadow;

  bool get isDark => brightness == Brightness.dark;

  // --- Spacing scale (4pt) ---------------------------------------------------
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 20;
  static const double space6 = 24;
  static const double space8 = 32;
  static const double space10 = 40;

  // --- Radii -----------------------------------------------------------------
  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 18;
  static const double radiusXl = 22;
  static const double radiusPill = 999;

  // --- Layout ----------------------------------------------------------------
  static const double sidebarWidth = 268;
  static const double sidebarCollapsedWidth = 76;
  static const double topBarHeight = 68;
  static const double detailDrawerWidth = 460;

  /// Breakpoints. Desktop-first: the table only degrades below [tablet].
  static const double mobileMax = 700;
  static const double tabletMax = 1100;

  // --- Motion ----------------------------------------------------------------
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 420);
  static const Curve curve = Curves.easeOutCubic;

  List<BoxShadow> get softShadow => [
    BoxShadow(
      color: shadow,
      blurRadius: 24,
      offset: const Offset(0, 8),
      spreadRadius: -6,
    ),
  ];

  List<BoxShadow> get liftedShadow => [
    BoxShadow(
      color: shadow,
      blurRadius: 36,
      offset: const Offset(0, 16),
      spreadRadius: -8,
    ),
  ];

  /// The colour that carries a status badge.
  Color statusColor(AdminUserStatus? status) {
    switch (status) {
      case AdminUserStatus.active:
        return success;
      case AdminUserStatus.inactive:
        return textMuted;
      case AdminUserStatus.suspended:
        return danger;
      case null:
        return textMuted;
    }
  }

  /// A stable accent per role, so a role reads the same everywhere.
  Color roleColor(AdminRole? role) {
    switch (role) {
      case AdminRole.admin:
        // A mid step of the brand indigo — it also forms the second half of
        // the sidebar's brand-mark gradient, and has to read on both themes.
        return const Color(0xFF3F51B5);
      case AdminRole.complexAdmin:
        return const Color(0xFF3B82F6);
      case AdminRole.employee:
        return const Color(0xFF0EA5E9);
      case AdminRole.coach:
        return const Color(0xFF10B981);
      case AdminRole.securityGuard:
        return const Color(0xFFF59E0B);
      case AdminRole.user:
        return const Color(0xFF64748B);
      case null:
        return textMuted;
    }
  }

  /// Deterministic gradient for an avatar with no picture — the same user keeps
  /// the same colours between reloads.
  List<Color> avatarGradient(String seed) {
    const palettes = <List<Color>>[
      [Color(0xFF1A237E), Color(0xFF5C6BC0)],
      [Color(0xFF0EA5E9), Color(0xFF67E8F9)],
      [Color(0xFF10B981), Color(0xFF6EE7B7)],
      [Color(0xFFF59E0B), Color(0xFFFCD34D)],
      [Color(0xFFEC4899), Color(0xFFF9A8D4)],
      [Color(0xFF3B82F6), Color(0xFF93C5FD)],
    ];
    if (seed.isEmpty) return palettes.first;
    final hash = seed.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
    return palettes[hash % palettes.length];
  }

  @override
  AdminTokens copyWith({
    Brightness? brightness,
    Color? canvas,
    Color? surface,
    Color? surfaceAlt,
    Color? glass,
    Color? border,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? accent,
    Color? accentSoft,
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
    Color? shadow,
  }) {
    return AdminTokens(
      brightness: brightness ?? this.brightness,
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      glass: glass ?? this.glass,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AdminTokens lerp(ThemeExtension<AdminTokens>? other, double t) {
    if (other is! AdminTokens) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t) ?? a;
    return AdminTokens(
      brightness: t < 0.5 ? brightness : other.brightness,
      canvas: mix(canvas, other.canvas),
      surface: mix(surface, other.surface),
      surfaceAlt: mix(surfaceAlt, other.surfaceAlt),
      glass: mix(glass, other.glass),
      border: mix(border, other.border),
      borderStrong: mix(borderStrong, other.borderStrong),
      textPrimary: mix(textPrimary, other.textPrimary),
      textSecondary: mix(textSecondary, other.textSecondary),
      textMuted: mix(textMuted, other.textMuted),
      accent: mix(accent, other.accent),
      accentSoft: mix(accentSoft, other.accentSoft),
      success: mix(success, other.success),
      warning: mix(warning, other.warning),
      danger: mix(danger, other.danger),
      info: mix(info, other.info),
      shadow: mix(shadow, other.shadow),
    );
  }

  static const AdminTokens light = AdminTokens(
    brightness: Brightness.light,
    canvas: Color(0xFFF6F7FB),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF1F3F9),
    glass: Color(0xCCFFFFFF),
    border: Color(0xFFE6E8F0),
    borderStrong: Color(0xFFD3D7E4),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF475569),
    textMuted: Color(0xFF94A3B8),
    // The brand colour, shared with the rest of the app.
    accent: Color(0xFF1A237E),
    accentSoft: Color(0xFFE8EAF6),
    success: Color(0xFF059669),
    warning: Color(0xFFD97706),
    danger: Color(0xFFDC2626),
    info: Color(0xFF2563EB),
    shadow: Color(0x1A1B2559),
  );

  static const AdminTokens dark = AdminTokens(
    brightness: Brightness.dark,
    canvas: Color(0xFF0B0F1A),
    surface: Color(0xFF121826),
    surfaceAlt: Color(0xFF1A2232),
    glass: Color(0xB3161E2E),
    border: Color(0xFF243044),
    borderStrong: Color(0xFF33415C),
    textPrimary: Color(0xFFF1F5F9),
    textSecondary: Color(0xFFB6C2D6),
    textMuted: Color(0xFF7688A3),
    // A lighter step of the same indigo: #1A237E on this canvas sits at about
    // 1.3:1, so a dark-mode button label on it would be unreadable.
    accent: Color(0xFF7986CB),
    accentSoft: Color(0xFF1E2440),
    success: Color(0xFF34D399),
    warning: Color(0xFFFBBF24),
    danger: Color(0xFFF87171),
    info: Color(0xFF60A5FA),
    shadow: Color(0x66000000),
  );
}

/// Builds the [ThemeData] the dashboard runs under.
class AdminTheme {
  const AdminTheme._();

  /// Tokens for the current context. Falls back to [AdminTokens.light] so a
  /// widget previewed outside the dashboard still renders.
  static AdminTokens of(BuildContext context) =>
      Theme.of(context).extension<AdminTokens>() ?? AdminTokens.light;

  static ThemeData build(Brightness brightness) {
    final tokens = brightness == Brightness.dark
        ? AdminTokens.dark
        : AdminTokens.light;

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: tokens.accent,
        brightness: brightness,
        surface: tokens.surface,
        error: tokens.danger,
      ),
      scaffoldBackgroundColor: tokens.canvas,
      dividerColor: tokens.border,
      splashFactory: InkSparkle.splashFactory,
    );

    final textTheme = GoogleFonts.dmSansTextTheme(
      base.textTheme,
    ).apply(bodyColor: tokens.textPrimary, displayColor: tokens.textPrimary);

    return base.copyWith(
      extensions: <ThemeExtension<dynamic>>[tokens],
      textTheme: textTheme.copyWith(
        headlineSmall: textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.6,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(color: tokens.textSecondary),
        bodySmall: textTheme.bodySmall?.copyWith(color: tokens.textMuted),
        labelLarge: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      iconTheme: IconThemeData(color: tokens.textSecondary, size: 20),
      dividerTheme: DividerThemeData(
        color: tokens.border,
        space: 1,
        thickness: 1,
      ),
      cardTheme: CardThemeData(
        color: tokens.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AdminTokens.radiusLg),
          side: BorderSide(color: tokens.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AdminTokens.radiusXl),
          side: BorderSide(color: tokens.border),
        ),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: tokens.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: tokens.isDark
            ? tokens.surfaceAlt
            : const Color(0xFF111827),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: tokens.isDark ? tokens.surfaceAlt : const Color(0xFF111827),
          borderRadius: BorderRadius.circular(AdminTokens.radiusSm),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
        waitDuration: const Duration(milliseconds: 400),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surfaceAlt,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AdminTokens.space4,
          vertical: AdminTokens.space3,
        ),
        hintStyle: TextStyle(color: tokens.textMuted, fontSize: 14),
        labelStyle: TextStyle(color: tokens.textSecondary, fontSize: 13),
        border: _fieldBorder(tokens.border),
        enabledBorder: _fieldBorder(tokens.border),
        focusedBorder: _fieldBorder(tokens.accent, width: 1.6),
        errorBorder: _fieldBorder(tokens.danger),
        focusedErrorBorder: _fieldBorder(tokens.danger, width: 1.6),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: tokens.accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: AdminTokens.space5,
            vertical: AdminTokens.space3 + 2,
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.textPrimary,
          side: BorderSide(color: tokens.borderStrong),
          padding: const EdgeInsets.symmetric(
            horizontal: AdminTokens.space5,
            vertical: AdminTokens.space3 + 2,
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: tokens.accent,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: tokens.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
          side: BorderSide(color: tokens.border),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : tokens.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? tokens.accent
              : tokens.surfaceAlt,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.transparent
              : tokens.borderStrong,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: tokens.accent,
        linearTrackColor: tokens.surfaceAlt,
        circularTrackColor: tokens.surfaceAlt,
      ),
    );
  }

  static OutlineInputBorder _fieldBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
