import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/csv_browser/presentation/csv_buttons_screen.dart';

/// Configures application themes and supplies theme changes to the main screen.
class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  static const String _themeModeKey = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  /// Restores the saved theme, defaulting unknown or missing values to system.
  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString(_themeModeKey);
    final mode = _themeModeFromString(savedMode);

    if (!mounted) {
      return;
    }

    setState(() {
      _themeMode = mode;
    });
  }

  /// Persists a theme selection before applying it to the widget tree.
  Future<void> _setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode.name);

    if (!mounted) {
      return;
    }

    setState(() {
      _themeMode = mode;
    });
  }

  /// Converts the stored enum name into a supported [ThemeMode].
  ThemeMode _themeModeFromString(String? value) {
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Grammer Study',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: CsvButtonsScreen(
        themeMode: _themeMode,
        onThemeModeChanged: _setThemeMode,
      ),
    );
  }
}
