import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grammarstudy/data/study_database_service.dart';
import 'package:hive/hive.dart';

/// Backing store for the temporary Hive directory used by widget tests.
Directory? _tempDirectory;

/// Initializes the services binding and seeds a temporary study database.
///
/// Widget tests that render data-driven tabs need real content, because the
/// games and study tabs load everything from Hive at construction time.
Future<void> seedTestDatabase() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  _tempDirectory ??= await Directory.systemTemp.createTemp(
    'grammar_study_widget',
  );
  Hive.init(_tempDirectory!.path);

  await StudyDatabaseService().initializeFromAssetsIfNeeded(forceRefresh: true);
}

/// Closes Hive and removes the temporary database directory.
Future<void> disposeTestDatabase() async {
  await Hive.close();
  final directory = _tempDirectory;
  if (directory != null && directory.existsSync()) {
    await directory.delete(recursive: true);
  }
  _tempDirectory = null;
}
