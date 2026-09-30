import 'package:flutter/material.dart';

/// Seed colour used to generate the light and dark Material 3 schemes.
const Color _seedColor = Colors.blue;

/// Builds the application theme for [brightness].
ThemeData buildAppTheme(Brightness brightness) {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: brightness,
    ),
    useMaterial3: true,
  );
}
