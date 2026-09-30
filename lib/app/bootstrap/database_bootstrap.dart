import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/study_database_service.dart';

/// File name of the Hive box written by earlier app versions.
const String _legacyBoxFileName = 'words_database_v2.hive';

/// Opens Hive in the platform-appropriate location and seeds missing data.
///
/// Native builds also copy forward the legacy database before Hive opens.
Future<void> initializeStudyDatabase() async {
  if (kIsWeb) {
    await Hive.initFlutter();
    await StudyDatabaseService().initializeFromAssetsIfNeeded();
    return;
  }

  final appSupportDirectory = await getApplicationSupportDirectory();
  await _migrateLegacyHiveBoxIfNeeded(appSupportDirectory.path);
  await Hive.initFlutter(appSupportDirectory.path);
  await StudyDatabaseService().initializeFromAssetsIfNeeded();
}

/// Copies a legacy database from Documents to Application Support when needed.
///
/// Migration is best-effort: failure is ignored because normal initialization
/// can recreate the database from bundled assets.
Future<void> _migrateLegacyHiveBoxIfNeeded(String destinationDirectory) async {
  final legacyDocumentsDirectory = await getApplicationDocumentsDirectory();
  final legacyDirectoryPath = legacyDocumentsDirectory.path;

  if (legacyDirectoryPath == destinationDirectory) {
    return;
  }

  final sourceFile = File(
    '$legacyDirectoryPath${Platform.pathSeparator}$_legacyBoxFileName',
  );
  final destinationFile = File(
    '$destinationDirectory${Platform.pathSeparator}$_legacyBoxFileName',
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
