// lib/src/utils/theme/app_theme_builder.dart
import 'package:flutter/material.dart';

import '../../constants/app_theme.dart';
import 'app_color_scheme.dart';
import 'theme_tokens.dart';

/// Single source of truth for app ThemeData. Named themes use brand tokens;
/// custom uses ColorScheme.fromSeed. AMOLED applies only to dark.
ThemeData buildAppTheme({
  required AppTheme theme,
  required Brightness brightness,
  required Color customSeed,
  required bool amoled,
}) {
  ColorScheme scheme = theme == AppTheme.custom
      ? ColorScheme.fromSeed(seedColor: customSeed, brightness: brightness)
      : schemeFromTokens(tokensFor(theme, brightness), brightness);

  if (brightness == Brightness.dark && amoled) {
    scheme = applyAmoled(scheme);
  }

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    // Left-aligned titles app-wide (also set standalone in the UX-defaults
    // plan; keep it here so alignment persists after this builder replaces
    // the old sorayomi.dart theme construction).
    appBarTheme: const AppBarTheme(centerTitle: false),
    tabBarTheme:
        const TabBarThemeData(tabAlignment: TabAlignment.center),
  );
}
