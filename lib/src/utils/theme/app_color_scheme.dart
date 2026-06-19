// lib/src/utils/theme/app_color_scheme.dart
import 'package:flutter/material.dart';

import 'theme_tokens.dart';

/// Builds a complete Material 3 [ColorScheme] from brand [ThemeTokens].
///
/// Starts from a seeded scheme (so every M3 role — containers, inverse,
/// scrim, etc. — is populated and harmonized with the accent), then overrides
/// the brand-critical roles with exact token values.
ColorScheme schemeFromTokens(ThemeTokens t, Brightness brightness) {
  final base = ColorScheme.fromSeed(
    seedColor: t.accent,
    brightness: brightness,
  );
  return base.copyWith(
    primary: t.accent,
    secondary: t.accent2,
    tertiary: t.accent2,
    surface: t.bg,
    onSurface: t.ink,
    onSurfaceVariant: t.muted,
    outline: t.faint,
    error: t.danger,
  );
}
