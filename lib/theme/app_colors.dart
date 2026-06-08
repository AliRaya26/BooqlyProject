import 'package:flutter/material.dart';

// ─── Static light constants ────────────────────────────────────────────────
// Keep these for const widget usage (e.g. const Icon(color: AppColors.brand)).
// For background / surface / text colors inside build(), use AppColors.of(ctx).

class AppColors {
  AppColors._();

  // Light palette (static – safe in const contexts)
  static const bg         = Color(0xFFF8F7F4);
  static const surface    = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF3F1EB);
  static const brand      = Color(0xFF4F46E5);
  static const brandSoft  = Color(0xFFEEF2FF);
  static const brandMid   = Color(0xFFC7D2FE);
  static const text       = Color(0xFF1C1B1F);
  static const textSub    = Color(0xFF6C6479);
  static const textMuted  = Color(0xFFB4B0BB);
  static const border     = Color(0xFFE8E4DE);
  static const green      = Color(0xFF16A34A);
  static const greenSoft  = Color(0xFFDCFCE7);
  static const amber      = Color(0xFFD97706);
  static const amberSoft  = Color(0xFFFEF3C7);
  static const red        = Color(0xFFDC2626);

  // Aliases
  static const textPrimary   = text;
  static const textSecondary = textSub;

  // ── Context-aware accessor ────────────────────────────────────────────────
  /// Returns the correct colour palette for the current theme brightness.
  static AppPalette of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? _dark
        : _light;
  }

  static const _light = AppPalette(
    bg:         Color(0xFFF8F7F4),
    surface:    Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF3F1EB),
    brand:      Color(0xFF4F46E5),
    brandSoft:  Color(0xFFEEF2FF),
    brandMid:   Color(0xFFC7D2FE),
    text:       Color(0xFF1C1B1F),
    textSub:    Color(0xFF6C6479),
    textMuted:  Color(0xFFB4B0BB),
    border:     Color(0xFFE8E4DE),
    green:      Color(0xFF16A34A),
    greenSoft:  Color(0xFFDCFCE7),
    amber:      Color(0xFFD97706),
    amberSoft:  Color(0xFFFEF3C7),
    red:        Color(0xFFDC2626),
  );

  static const _dark = AppPalette(
    bg:         Color(0xFF111110),
    surface:    Color(0xFF1C1B19),
    surfaceAlt: Color(0xFF252320),
    brand:      Color(0xFF6366F1),
    brandSoft:  Color(0xFF1E1D3F),
    brandMid:   Color(0xFF3730A3),
    text:       Color(0xFFF5F4F1),
    textSub:    Color(0xFFB0ACBA),
    textMuted:  Color(0xFF6E6A78),
    border:     Color(0xFF2A2825),
    green:      Color(0xFF4ADE80),
    greenSoft:  Color(0xFF052E16),
    amber:      Color(0xFFFBBF24),
    amberSoft:  Color(0xFF2D1900),
    red:        Color(0xFFF87171),
  );
}

/// Theme-aware colour palette returned by [AppColors.of].
class AppPalette {
  const AppPalette({
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
    required this.green,
    required this.greenSoft,
    required this.amber,
    required this.amberSoft,
    required this.red,
  });

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
  final Color green;
  final Color greenSoft;
  final Color amber;
  final Color amberSoft;
  final Color red;
}

// ─── Card shadow helpers ───────────────────────────────────────────────────

const kCardShadow = [
  BoxShadow(color: Color(0x0D000000), blurRadius: 16, offset: Offset(0, 4)),
  BoxShadow(color: Color(0x06000000), blurRadius:  4, offset: Offset(0, 1)),
];

List<BoxShadow> cardShadow(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? const [
          BoxShadow(color: Color(0x28000000), blurRadius: 16, offset: Offset(0, 4)),
          BoxShadow(color: Color(0x14000000), blurRadius:  4, offset: Offset(0, 1)),
        ]
      : kCardShadow;
}
