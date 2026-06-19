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

/// Layers AMOLED pure-black on a DARK [ColorScheme]: backgrounds → black,
/// elevated containers → stepped near-black. Accents and on-colors unchanged.
ColorScheme applyAmoled(ColorScheme dark) {
  return dark.copyWith(
    surface: const Color(0xFF000000),
    surfaceContainerLowest: const Color(0xFF000000),
    surfaceContainerLow: const Color(0xFF0A0A0A),
    surfaceContainer: const Color(0xFF101010),
    surfaceContainerHigh: const Color(0xFF161616),
    surfaceContainerHighest: const Color(0xFF1C1C1C),
  );
}
