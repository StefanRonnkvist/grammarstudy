import 'package:flutter/material.dart';

import 'app/bootstrap/database_bootstrap.dart';
import 'app/main_app.dart';
import 'app/splash_screen.dart';

/// Starts Flutter with a bootstrap widget that prepares persistent study data.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppBootstrap());
}

/// Shows the splash screen while study data loads, then the main application.
class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  /// Minimum time the splash screen stays visible.
  static const Duration _minimumSplashDuration = Duration(milliseconds: 1800);

  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  /// Initializes storage while enforcing a minimum splash-screen duration.
  Future<void> _initializeApp() async {
    await Future.wait([
      initializeStudyDatabase(),
      Future<void>.delayed(_minimumSplashDuration),
    ]);

    if (mounted) {
      setState(() => _isReady = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isReady) {
      return const MainApp();
    }

    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
    );
  }
}
