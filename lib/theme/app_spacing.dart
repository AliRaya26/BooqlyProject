import 'package:flutter/material.dart';

/// Shared layout tokens for consistent spacing, radii, and elevation.
class AppSpacing {
  AppSpacing._();

  // Spacing scale
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  // Border radius
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 20;
  static const double radiusPill = 999;

  static BorderRadius get borderRadiusSm => BorderRadius.circular(radiusSm);
  static BorderRadius get borderRadiusMd => BorderRadius.circular(radiusMd);
  static BorderRadius get borderRadiusLg => BorderRadius.circular(radiusLg);
  static BorderRadius get borderRadiusXl => BorderRadius.circular(radiusXl);

  // Elevation
  static const double elevationNone = 0;
  static const double elevationLow = 2;
  static const double elevationMid = 4;
  static const double elevationHigh = 8;

  // Screen padding
  static const EdgeInsets screenPadding =
      EdgeInsets.symmetric(horizontal: xl, vertical: lg);
  static const EdgeInsets cardPadding = EdgeInsets.all(lg);
}
