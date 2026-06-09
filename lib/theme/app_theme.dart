import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:booqly/theme/app_colors.dart';
import 'package:booqly/theme/app_spacing.dart';

/// Builds complete [ThemeData] for light and dark modes from [AppColors].
class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(AppColors.paletteFor(Brightness.light));

  static ThemeData dark() => _build(AppColors.paletteFor(Brightness.dark));

  static ThemeData _build(AppPalette p) {
    final isDark = p.bg.computeLuminance() < 0.5;
    final base = isDark ? ThemeData.dark() : ThemeData.light();

    final colorScheme = ColorScheme(
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: p.primary,
      onPrimary: p.onPrimary,
      secondary: p.secondary,
      onSecondary: p.onPrimary,
      surface: p.surface,
      onSurface: p.text,
      error: p.error,
      onError: p.onPrimary,
    );

    return base.copyWith(
      scaffoldBackgroundColor: p.bg,
      colorScheme: colorScheme,
      canvasColor: p.bg,
      cardColor: p.surface,
      dividerColor: p.border,
      splashColor: p.brand.withValues(alpha: 0.12),
      highlightColor: p.brand.withValues(alpha: 0.08),
      iconTheme: IconThemeData(color: p.textSub),
      primaryIconTheme: IconThemeData(color: p.onPrimary),
      textTheme: _textTheme(p),
      appBarTheme: AppBarTheme(
        backgroundColor: p.bg,
        foregroundColor: p.text,
        elevation: AppSpacing.elevationNone,
        scrolledUnderElevation: AppSpacing.elevationLow,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: p.text,
        ),
        iconTheme: IconThemeData(color: p.text),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: p.surface,
        selectedItemColor: p.brand,
        unselectedItemColor: p.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: AppSpacing.elevationMid,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        indicatorColor: p.brandSoft,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? p.brand : p.textMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? p.brand : p.textMuted,
            size: 24,
          );
        }),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: AppSpacing.elevationNone,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.borderRadiusLg,
          side: BorderSide(color: p.border.withValues(alpha: 0.6)),
        ),
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        elevation: AppSpacing.elevationHigh,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.borderRadiusXl,
        ),
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: p.text,
        ),
        contentTextStyle: GoogleFonts.outfit(
          fontSize: 14,
          color: p.textSub,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        modalBackgroundColor: p.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusXl),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md + 2,
        ),
        border: OutlineInputBorder(
          borderRadius: AppSpacing.borderRadiusMd,
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppSpacing.borderRadiusMd,
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppSpacing.borderRadiusMd,
          borderSide: BorderSide(color: p.brand, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppSpacing.borderRadiusMd,
          borderSide: BorderSide(color: p.error),
        ),
        labelStyle: GoogleFonts.outfit(color: p.textSub, fontSize: 14),
        hintStyle: GoogleFonts.outfit(color: p.textMuted, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.brand,
          foregroundColor: p.onPrimary,
          disabledBackgroundColor: p.brand.withValues(alpha: 0.45),
          disabledForegroundColor: p.onPrimary.withValues(alpha: 0.7),
          elevation: AppSpacing.elevationNone,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md + 2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.brand,
          side: BorderSide(color: p.border),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md + 2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.brand,
          textStyle: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return p.brand;
          return p.textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return p.brandMid;
          }
          return p.border;
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.surfaceAlt,
        contentTextStyle: GoogleFonts.outfit(color: p.text, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.borderRadiusMd,
        ),
      ),
      dividerTheme: DividerThemeData(color: p.border, thickness: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.brand),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.brand,
        foregroundColor: p.onPrimary,
        elevation: AppSpacing.elevationMid,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.textSub,
        textColor: p.text,
        tileColor: p.surface,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surfaceAlt,
        selectedColor: p.brandSoft,
        labelStyle: GoogleFonts.outfit(color: p.text, fontSize: 13),
        side: BorderSide(color: p.border),
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.borderRadiusMd,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: p.brand,
        inactiveTrackColor: p.border,
        thumbColor: p.brand,
        overlayColor: p.brand.withValues(alpha: 0.12),
      ),
    );
  }

  static TextTheme _textTheme(AppPalette p) {
    return TextTheme(
      displayLarge: GoogleFonts.outfit(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: p.text,
      ),
      headlineMedium: GoogleFonts.outfit(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: p.text,
      ),
      titleLarge: GoogleFonts.outfit(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: p.text,
      ),
      titleMedium: GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: p.text,
      ),
      bodyLarge: GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: p.text,
      ),
      bodyMedium: GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: p.textSub,
      ),
      bodySmall: GoogleFonts.outfit(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: p.textMuted,
      ),
      labelLarge: GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: p.text,
      ),
    );
  }
}
