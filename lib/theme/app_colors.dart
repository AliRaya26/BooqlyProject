import 'package:flutter/material.dart';

/// Central color system for Booqly light and dark themes.
///
/// Use [AppColors.of] inside `build()` for theme-aware colors.
/// Static light constants remain for `const` widgets where brightness
/// is fixed (e.g. brand-colored icons in light-only marketing screens).
class AppColors {
  AppColors._();

  // ── Light palette (static – safe in const contexts) ─────────────────────

  static const primary = Color(0xFF4F46E5);
  static const secondary = Color(0xFF7C3AED);
  static const bg = Color(0xFFF8F7F4);
  static const surface = Color(0xFFFAFAF8);
  static const surfaceAlt = Color(0xFFF3F1EB);
  static const brand = primary;
  static const brandSoft = Color(0xFFEEF2FF);
  static const brandMid = Color(0xFFC7D2FE);
  static const text = Color(0xFF1C1B1F);
  static const textSub = Color(0xFF6C6479);
  static const textMuted = Color(0xFFB4B0BB);
  static const border = Color(0xFFE8E4DE);
  static const onPrimary = Color(0xFFFAFAF8);
  static const success = Color(0xFF16A34A);
  static const successSoft = Color(0xFFDCFCE7);
  static const warning = Color(0xFFD97706);
  static const warningSoft = Color(0xFFFEF3C7);
  static const error = Color(0xFFDC2626);
  static const errorSoft = Color(0xFFFEE2E2);

  // Legacy aliases
  static const green = success;
  static const greenSoft = successSoft;
  static const amber = warning;
  static const amberSoft = warningSoft;
  static const red = error;
  static const textPrimary = text;
  static const textSecondary = textSub;

  // ── Context-aware accessor ────────────────────────────────────────────────

  static AppPalette of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? _dark : _light;
  }

  static AppPalette paletteFor(Brightness brightness) {
    return brightness == Brightness.dark ? _dark : _light;
  }

  static const _light = AppPalette(
    primary: Color(0xFF4F46E5),
    secondary: Color(0xFF7C3AED),
    bg: Color(0xFFF8F7F4),
    surface: Color(0xFFFAFAF8),
    surfaceAlt: Color(0xFFF3F1EB),
    brand: Color(0xFF4F46E5),
    brandSoft: Color(0xFFEEF2FF),
    brandMid: Color(0xFFC7D2FE),
    text: Color(0xFF1C1B1F),
    textSub: Color(0xFF6C6479),
    textMuted: Color(0xFFB4B0BB),
    border: Color(0xFFE8E4DE),
    onPrimary: Color(0xFFFAFAF8),
    success: Color(0xFF16A34A),
    successSoft: Color(0xFFDCFCE7),
    warning: Color(0xFFD97706),
    warningSoft: Color(0xFFFEF3C7),
    error: Color(0xFFDC2626),
    errorSoft: Color(0xFFFEE2E2),
    overlay: Color(0x99000000),
    scrim: Color(0x66000000),
    shadow: Color(0x0D000000),
    quoteAccent: Color(0xFF5B8DD9),
  );

  static const _dark = AppPalette(
    primary: Color(0xFF6366F1),
    secondary: Color(0xFF8B5CF6),
    bg: Color(0xFF111110),
    surface: Color(0xFF1C1B19),
    surfaceAlt: Color(0xFF252320),
    brand: Color(0xFF6366F1),
    brandSoft: Color(0xFF1E1D3F),
    brandMid: Color(0xFF3730A3),
    text: Color(0xFFF5F4F1),
    textSub: Color(0xFFB0ACBA),
    textMuted: Color(0xFF6E6A78),
    border: Color(0xFF2A2825),
    onPrimary: Color(0xFFFAFAF8),
    success: Color(0xFF4ADE80),
    successSoft: Color(0xFF052E16),
    warning: Color(0xFFFBBF24),
    warningSoft: Color(0xFF2D1900),
    error: Color(0xFFF87171),
    errorSoft: Color(0xFF450A0A),
    overlay: Color(0xB3000000),
    scrim: Color(0x80000000),
    shadow: Color(0x28000000),
    quoteAccent: Color(0xFF7EB0E8),
  );
}

/// Theme-aware colour palette returned by [AppColors.of].
class AppPalette {
  const AppPalette({
    required this.primary,
    required this.secondary,
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.brand,
    required this.brandSoft,
    required this.brandMid,
    required this.text,
    required this.textSub,
    required this.textMuted,
    required this.border,
    required this.onPrimary,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.error,
    required this.errorSoft,
    required this.overlay,
    required this.scrim,
    required this.shadow,
    required this.quoteAccent,
  });

  final Color primary;
  final Color secondary;
  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color brand;
  final Color brandSoft;
  final Color brandMid;
  final Color text;
  final Color textSub;
  final Color textMuted;
  final Color border;
  final Color onPrimary;
  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color error;
  final Color errorSoft;
  final Color overlay;
  final Color scrim;
  final Color shadow;
  final Color quoteAccent;

  // Legacy aliases used across existing screens
  Color get green => success;
  Color get greenSoft => successSoft;
  Color get amber => warning;
  Color get amberSoft => warningSoft;
  Color get red => error;
  Color get textPrimary => text;
  Color get textSecondary => textSub;
}

// ─── Card shadow helpers ───────────────────────────────────────────────────

const kCardShadow = [
  BoxShadow(color: Color(0x0D000000), blurRadius: 16, offset: Offset(0, 4)),
  BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 1)),
];

List<BoxShadow> cardShadow(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? const [
          BoxShadow(
              color: Color(0x28000000), blurRadius: 16, offset: Offset(0, 4)),
          BoxShadow(
              color: Color(0x14000000), blurRadius: 4, offset: Offset(0, 1)),
        ]
      : kCardShadow;
}
