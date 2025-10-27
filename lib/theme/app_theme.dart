import 'package:flutter/material.dart';

class AppTheme {
  // Pick a seed color that matches your Inventory page primary color.
  // Change this to your exact hex (e.g., Color(0xFF0B6EFD) for blue).
  static const Color seed = Color(0xFF2E7D32); // default: green

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light);
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      dividerTheme: const DividerThemeData(space: 0, thickness: 1, indent: 0, endIndent: 0),
      scaffoldBackgroundColor: scheme.background,
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark);
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      dividerTheme: const DividerThemeData(space: 0, thickness: 1, indent: 0, endIndent: 0),
      scaffoldBackgroundColor: scheme.background,
    );
  }
}
