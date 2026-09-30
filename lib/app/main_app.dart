import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home/home_screen.dart';
import 'theme/app_theme.dart';

/// Reads and persists the user's theme selection.
class ThemeController extends ChangeNotifier {
  ThemeController({ThemeMode initialMode = ThemeMode.system})
    : _themeMode = initialMode;

  static const String _themeModeKey = 'theme_mode';

  ThemeMode _themeMode;

  ThemeMode get themeMode => _themeMode;

  /// Restores the saved theme, defaulting unknown or missing values to system.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _themeMode = _fromString(prefs.getString(_themeModeKey));
    notifyListeners();
  }

  /// Persists a theme selection before applying it to the widget tree.
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode.name);
  }

  /// Converts the stored enum name into a supported [ThemeMode].
  ThemeMode _fromString(String? value) {
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }
}

/// Configures application themes and supplies theme changes to the home screen.
class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  final ThemeController _themeController = ThemeController();

  @override
  void initState() {
    super.initState();
    _themeController.load();
  }

  @override
  void dispose() {
    _themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _themeController,
      builder: (context, _) {
        return MaterialApp(
          title: 'Grammar Study',
          debugShowCheckedModeBanner: false,
          themeMode: _themeController.themeMode,
          theme: buildAppTheme(Brightness.light),
          darkTheme: buildAppTheme(Brightness.dark),
          home: HomeScreen(
            themeMode: _themeController.themeMode,
            onThemeModeChanged: _themeController.setThemeMode,
          ),
        );
      },
    );
  }
}
