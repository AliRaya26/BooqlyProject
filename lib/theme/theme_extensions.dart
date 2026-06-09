import 'package:flutter/material.dart';

import 'package:booqly/theme/app_colors.dart';

/// Convenience accessors for theme-aware colors and Material theme data.
extension AppThemeContext on BuildContext {
  AppPalette get colors => AppColors.of(this);

  ThemeData get appTheme => Theme.of(this);

  bool get isDarkMode => appTheme.brightness == Brightness.dark;

  TextTheme get textTheme => appTheme.textTheme;

  ColorScheme get colorScheme => appTheme.colorScheme;
}
