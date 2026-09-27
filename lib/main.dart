import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'app/main_app.dart';
import 'app/splash_screen.dart';
import 'features/csv_browser/data/assets_database_service.dart';

/// Starts Flutter with a bootstrap widget that prepares persistent study data.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppBootstrap());
}

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  Object? _startupError;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  /// Initializes storage while enforcing a minimum splash-screen duration.
  /// Startup errors are captured and rendered by [DatabaseLoadErrorApp].
  Future<void> _initializeApp() async {
    try {
      await Future.wait([
        _initializeDatabase(),
        Future<void>.delayed(const Duration(milliseconds: 1800)),
      ]);

      if (mounted) {
        setState(() => _isReady = true);
      }
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          context: ErrorDescription('while loading the application database'),
        ),
      );

      if (mounted) {
        setState(() => _startupError = error);
      }
    }
  }

  /// Opens Hive in the platform-appropriate location and seeds missing data.
  /// Native builds also copy forward the legacy database before Hive opens.
  Future<void> _initializeDatabase() async {
    if (kIsWeb) {
      await Hive.initFlutter();
      await AssetsDatabaseService().initializeFromAssetsIfNeeded();
      return;
    }

    final appSupportDirectory = await getApplicationSupportDirectory();
    await _migrateLegacyHiveBoxIfNeeded(appSupportDirectory.path);
    await Hive.initFlutter(appSupportDirectory.path);
    await AssetsDatabaseService().initializeFromAssetsIfNeeded();
  }

  @override
  Widget build(BuildContext context) {
    if (_startupError case final error?) {
      return DatabaseLoadErrorApp(error: error);
    }

    if (_isReady) {
      return const MainApp();
    }

    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
    );
  }
}

/// Displays a standalone recovery message when startup cannot load Hive data.
class DatabaseLoadErrorApp extends StatelessWidget {
  const DatabaseLoadErrorApp({required this.error, super.key});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Grammer Study',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.storage_rounded, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Database failed to load in web mode.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                SelectableText('$error', textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Copies a legacy database from Documents to Application Support when needed.
///
/// Migration is best-effort: failure is ignored because normal initialization
/// can recreate the database from bundled assets.
Future<void> _migrateLegacyHiveBoxIfNeeded(String destinationDirectory) async {
  const boxFileName = 'words_database_v2.hive';

  final legacyDocumentsDirectory = await getApplicationDocumentsDirectory();
  final legacyDirectoryPath = legacyDocumentsDirectory.path;

  if (legacyDirectoryPath == destinationDirectory) {
    return;
  }

  final sourceFile = File(
    '$legacyDirectoryPath${Platform.pathSeparator}$boxFileName',
  );
  final destinationFile = File(
    '$destinationDirectory${Platform.pathSeparator}$boxFileName',
  );

  if (!await sourceFile.exists() || await destinationFile.exists()) {
    return;
  }

  try {
    await destinationFile.parent.create(recursive: true);
    await sourceFile.copy(destinationFile.path);
  } catch (_) {
    // Ignore migration failures; app can still seed from bundled JSON assets.
  }
}
