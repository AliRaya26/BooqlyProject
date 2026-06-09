import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:booqly/theme/app_colors.dart';

/// Central typography helpers built on Google Fonts.
class AppTypography {
  AppTypography._();

  static TextStyle displayLarge(BuildContext context) => GoogleFonts.outfit(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: AppColors.of(context).text,
        height: 1.2,
      );

  static TextStyle headlineMedium(BuildContext context) => GoogleFonts.outfit(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.of(context).text,
        height: 1.25,
      );

  static TextStyle titleLarge(BuildContext context) => GoogleFonts.outfit(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.of(context).text,
        height: 1.3,
      );

  static TextStyle titleMedium(BuildContext context) => GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.of(context).text,
        height: 1.35,
      );

  static TextStyle bodyLarge(BuildContext context) => GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.of(context).text,
        height: 1.5,
      );

  static TextStyle bodyMedium(BuildContext context) => GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.of(context).textSub,
        height: 1.45,
      );

  static TextStyle bodySmall(BuildContext context) => GoogleFonts.outfit(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.of(context).textMuted,
        height: 1.4,
      );

  static TextStyle labelLarge(BuildContext context) => GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.of(context).text,
        height: 1.3,
      );

  static TextStyle button(BuildContext context) => GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.of(context).onPrimary,
        height: 1.2,
      );

  static TextStyle serifTitle(BuildContext context) =>
      GoogleFonts.figtree(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: AppColors.of(context).text,
        height: 1.15,
      );
}
