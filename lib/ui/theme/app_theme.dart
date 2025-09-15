// lib/ui/theme/app_theme.dart
import 'package:flutter/material.dart';

const _bordeaux = Color(0xFF3A0D14); // fon
const _card = Color(0xFF4A121A);
const _gold = Color(0xFFF7C651);

ThemeData buildRestaurantTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: _bordeaux,
    colorScheme: base.colorScheme.copyWith(
      surface: _bordeaux,
      surfaceContainerHighest: const Color(0xFF2A090E),
      primary: _gold,
      onPrimary: const Color(0xFF2A090E),
      primaryContainer: _gold,
      onPrimaryContainer: const Color(0xFF2A090E),
      secondaryContainer: const Color(0xFF2A090E),
      onSecondaryContainer: _gold,
      outline: Colors.white.withValues(alpha: 0.12),
      tertiaryContainer: _card,
      onTertiaryContainer: Colors.white,
    ),
    cardColor: _card,
    textTheme: base.textTheme.apply(
      bodyColor: Colors.white.withValues(alpha: 0.92),
      displayColor: Colors.white,
    ),
    dividerColor: Colors.white.withValues(alpha: 0.08),
  );
}
