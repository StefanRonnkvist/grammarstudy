import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import 'study_database_schema.dart';

/// Owns initialization, restoration, and typed reads for the bundled study data.
///
/// Native builds prefer the prebuilt Hive file. Web builds, and native builds
/// that cannot restore that file, seed Hive from the exported text and JSON
/// assets instead.
class StudyDatabaseService {
  static const String grammarTagValuesKey =
      StudyDatabaseSchema.grammarTagValuesKey;
  static const String grammarTagPreviousWordValuesKey =
      StudyDatabaseSchema.grammarTagPreviousWordValuesKey;
  static const String grammarTagPreviousWordValuesSmartCapitalizedKey =
      StudyDatabaseSchema.grammarTagPreviousWordValuesSmartCapitalizedKey;
  static const String dictionarySentencesSourceKey =
      StudyDatabaseSchema.dictionarySentencesSourceKey;
  static const String dictionarySentencesContextTaggedKey =
      StudyDatabaseSchema.dictionarySentencesContextTaggedKey;
  static const String wordTypeDefinitionsKey =
      StudyDatabaseSchema.wordTypeDefinitionsKey;

  Future<Box<dynamic>> _openBox() =>
      Hive.openBox<dynamic>(StudyDatabaseSchema.boxName);

  /// Ensures Hive contains data for the current schema version.
  ///
  /// A forced refresh always restores bundled content. During normal startup,
  /// an already-current box is left untouched so locally persisted data does
  /// not need to be rebuilt.
  Future<void> initializeFromAssetsIfNeeded({bool forceRefresh = false}) async {
    if (forceRefresh) {
      await restoreBundledDatabase();
      return;
    }

    final box = await _openBox();
    final existingVersion =
        box.get(StudyDatabaseSchema.schemaVersionKey) as int?;

    if (existingVersion == StudyDatabaseSchema.schemaVersion) {
      return;
    }

    final restoredFromPrebuilt = await _restoreFromPrebuiltAsset(box);
    if (restoredFromPrebuilt) {
      return;
    }

    await _seedBoxFromSourceAssets(box);
  }

  /// Replaces the current database with the bundled build data.
  ///
  /// Restoration first tries the packaged Hive file on native platforms, then
  /// falls back to rebuilding the box from source assets on every platform.
  Future<void> restoreBundledDatabase() async {
    final box = await _openBox();
    final restoredFromPrebuilt = await _restoreFromPrebuiltAsset(box);
    if (restoredFromPrebuilt) {
      return;
    }

    await _seedBoxFromSourceAssets(box);
  }

  /// Copies the packaged Hive database over the active native database.
  ///
  /// Returns `false` on web, on file-system failures, or when the copied file
  /// does not contain the expected schema version, allowing the caller to seed
  /// from source assets instead.
  Future<bool> _restoreFromPrebuiltAsset(Box<dynamic> box) async {
    if (kIsWeb) {
      return false;
    }

    try {
      final prebuiltData = await rootBundle.load(
        StudyDatabaseSchema.prebuiltDatabaseAssetPath,
      );
      final bytes = prebuiltData.buffer.asUint8List(
        prebuiltData.offsetInBytes,
        prebuiltData.lengthInBytes,
      );

      await box.close();

      final supportDirectory = await getApplicationSupportDirectory();
      final destinationFile = File(
        '${supportDirectory.path}${Platform.pathSeparator}${StudyDatabaseSchema.prebuiltDatabaseFileName}',
      );
      await destinationFile.parent.create(recursive: true);
      await destinationFile.writeAsBytes(bytes, flush: true);

      final restoredBox = await _openBox();
      final restoredVersion =
          restoredBox.get(StudyDatabaseSchema.schemaVersionKey) as int?;
      return restoredVersion == StudyDatabaseSchema.schemaVersion;
    } catch (_) {
      return false;
    }
  }

  /// Parses all source exports and writes them as one consistent Hive snapshot.
  ///
  /// The schema marker is written last so an interrupted seed cannot be
  /// mistaken for a complete, current database on the next launch.
  Future<void> _seedBoxFromSourceAssets(Box<dynamic> box) async {
    if (!box.isOpen) {
      box = await _openBox();
    }

    final grammarTagValues = await _loadStringListMapAsset(
      StudyDatabaseSchema.exportWordTypeCategoriesAssetPath,
    );
    final grammarTagPreviousWordValues = <String, List<String>>{
      for (final entry in grammarTagValues.entries)
        entry.key: List<String>.from(entry.value, growable: false),
    };
    final grammarTagPreviousWordValuesSmartCapitalized = _flattenUniqueValues(
      grammarTagValues,
    );
    final dictionarySentencesSource = await _loadTextLinesAsset(
      StudyDatabaseSchema.exportSentencesWithoutWordTypeAssetPath,
    );
    final dictionarySentencesContextTagged = await _loadTextLinesAsset(
      StudyDatabaseSchema.exportSentencesWithWordTypeAssetPath,
    );
    final wordTypeDefinitions = await _loadStringMapAsset(
      StudyDatabaseSchema.exportWordTypeDefinitionsAssetPath,
    );
    final effectiveWordTypeDefinitions = wordTypeDefinitions.isEmpty
        ? {
            for (final key in grammarTagValues.keys)
              key.toLowerCase(): 'Definition unavailable for $key.',
          }
        : wordTypeDefinitions;

    await box.clear();
    await box.put(grammarTagValuesKey, grammarTagValues);
    await box.put(
      grammarTagPreviousWordValuesKey,
      grammarTagPreviousWordValues,
    );
    await box.put(
      grammarTagPreviousWordValuesSmartCapitalizedKey,
      grammarTagPreviousWordValuesSmartCapitalized,
    );
    await box.put(dictionarySentencesSourceKey, dictionarySentencesSource);
    await box.put(
      dictionarySentencesContextTaggedKey,
      dictionarySentencesContextTagged,
    );
    await box.put(wordTypeDefinitionsKey, effectiveWordTypeDefinitions);
    await box.put(
      StudyDatabaseSchema.schemaVersionKey,
      StudyDatabaseSchema.schemaVersion,
    );
  }

  /// Reads the grammar categories and their associated vocabulary.
  Future<Map<String, List<String>>> readGrammarTagValues() async {
    final box = await _openBox();
    return _readStringListMap(box.get(grammarTagValuesKey));
  }

  /// Reads the category lookup used by features that match preceding words.
  Future<Map<String, List<String>>> readGrammarTagPreviousWordValues() async {
    final box = await _openBox();
    return _readStringListMap(box.get(grammarTagPreviousWordValuesKey));
  }

  Future<List<String>>
  readGrammarTagPreviousWordValuesSmartCapitalized() async {
    final box = await _openBox();
    return _readStringList(
      box.get(grammarTagPreviousWordValuesSmartCapitalizedKey),
    );
  }

  /// Reads plain sentence examples with grammar annotations removed.
  Future<List<String>> readDictionarySentencesSource() async {
    final box = await _openBox();
    return _readStringList(box.get(dictionarySentencesSourceKey));
  }

  /// Reads sentence examples that retain their parenthesized grammar tags.
  Future<List<String>> readDictionarySentencesContextTagged() async {
    final box = await _openBox();
    return _readStringList(box.get(dictionarySentencesContextTaggedKey));
  }

  /// Reads definitions keyed by normalized, lower-case grammar type.
  Future<Map<String, String>> readWordTypeDefinitions() async {
    final box = await _openBox();
    return _readStringMap(box.get(wordTypeDefinitionsKey));
  }

  /// Computes record counts used by the database diagnostics dialog.
  Future<StudyDatabaseSummary> readSummary() async {
    final box = await _openBox();

    final grammarTagValues = _readStringListMap(box.get(grammarTagValuesKey));
    final grammarTagPreviousWordValues = _readStringListMap(
      box.get(grammarTagPreviousWordValuesKey),
    );
    final grammarTagPreviousWordValuesSmartCapitalized = _readStringList(
      box.get(grammarTagPreviousWordValuesSmartCapitalizedKey),
    );
    final dictionarySentencesSource = _readStringList(
      box.get(dictionarySentencesSourceKey),
    );
    final dictionarySentencesContextTagged = _readStringList(
      box.get(dictionarySentencesContextTaggedKey),
    );
    final wordTypeDefinitions = _readStringMap(box.get(wordTypeDefinitionsKey));

    return StudyDatabaseSummary(
      schemaVersion: box.get(StudyDatabaseSchema.schemaVersionKey) as int?,
      grammarTypesCount: grammarTagValues.length,
      grammarValuesCount: grammarTagValues.values.fold<int>(
        0,
        (sum, values) => sum + values.length,
      ),
      previousWordTypesCount: grammarTagPreviousWordValues.length,
      previousWordValuesCount: grammarTagPreviousWordValues.values.fold<int>(
        0,
        (sum, values) => sum + values.length,
      ),
      previousWordSmartCapitalizedTypesCount:
          grammarTagPreviousWordValuesSmartCapitalized.isEmpty ? 0 : 1,
      previousWordSmartCapitalizedValuesCount:
          grammarTagPreviousWordValuesSmartCapitalized.length,
      sourceSentencesCount: dictionarySentencesSource.length,
      taggedSentencesCount: dictionarySentencesContextTagged.length,
      wordTypeDefinitionsCount: wordTypeDefinitions.length,
    );
  }

  /// Decodes a JSON object whose values are string arrays, dropping invalid
  /// keys, non-list values, and blank entries.
  Future<Map<String, List<String>>> _loadStringListMapAsset(
    String assetPath,
  ) async {
    final jsonText = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(jsonText);
    if (decoded is! Map) {
      return const <String, List<String>>{};
    }

    final result = <String, List<String>>{};
    for (final entry in decoded.entries) {
      final key = entry.key?.toString().trim();
      if (key == null || key.isEmpty || entry.value is! List) {
        continue;
      }

      final values = (entry.value as List)
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
      result[key] = values;
    }

    return result;
  }

  /// Splits a text asset into trimmed, non-empty records.
  Future<List<String>> _loadTextLinesAsset(String assetPath) async {
    final rawText = await rootBundle.loadString(assetPath);
    return const LineSplitter()
        .convert(rawText)
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
  }

  /// Decodes a string-to-string JSON object and normalizes keys for lookup.
  Future<Map<String, String>> _loadStringMapAsset(String assetPath) async {
    final jsonText = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(jsonText);
    if (decoded is! Map) {
      return const <String, String>{};
    }

    final result = <String, String>{};
    for (final entry in decoded.entries) {
      final key = entry.key?.toString().trim();
      final value = entry.value?.toString().trim();
      if (key == null || key.isEmpty || value == null || value.isEmpty) {
        continue;
      }
      result[key.toLowerCase()] = value;
    }

    return result;
  }

  /// Flattens category values while preserving first-seen spelling and order.
  /// Duplicate detection is case-insensitive.
  List<String> _flattenUniqueValues(Map<String, List<String>> valuesByType) {
    final seen = <String>{};
    final flattened = <String>[];

    for (final values in valuesByType.values) {
      for (final value in values) {
        final trimmed = value.trim();
        if (trimmed.isEmpty) {
          continue;
        }
        if (seen.add(trimmed.toLowerCase())) {
          flattened.add(trimmed);
        }
      }
    }

    return flattened;
  }

  /// Safely converts dynamically typed Hive data into a string-list map.
  Map<String, List<String>> _readStringListMap(dynamic raw) {
    if (raw is! Map) {
      return const <String, List<String>>{};
    }

    final result = <String, List<String>>{};
    for (final entry in raw.entries) {
      final key = entry.key?.toString().trim();
      if (key == null || key.isEmpty || entry.value is! List) {
        continue;
      }

      result[key] = _readStringList(entry.value);
    }
    return result;
  }

  /// Safely converts a Hive value into trimmed, non-empty strings.
  List<String> _readStringList(dynamic raw) {
    if (raw is! List) {
      return const <String>[];
    }

    return raw
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  /// Safely converts a Hive value into a normalized definition map.
  Map<String, String> _readStringMap(dynamic raw) {
    if (raw is! Map) {
      return const <String, String>{};
    }

    final result = <String, String>{};
    for (final entry in raw.entries) {
      final key = entry.key?.toString().trim();
      final value = entry.value?.toString().trim();
      if (key == null || key.isEmpty || value == null || value.isEmpty) {
        continue;
      }
      result[key.toLowerCase()] = value;
    }
    return result;
  }
}

/// Immutable counts describing the currently loaded study database.
class StudyDatabaseSummary {
  const StudyDatabaseSummary({
    required this.schemaVersion,
    required this.grammarTypesCount,
    required this.grammarValuesCount,
    required this.previousWordTypesCount,
    required this.previousWordValuesCount,
    required this.previousWordSmartCapitalizedTypesCount,
    required this.previousWordSmartCapitalizedValuesCount,
    required this.sourceSentencesCount,
    required this.taggedSentencesCount,
    required this.wordTypeDefinitionsCount,
  });

  final int? schemaVersion;
  final int grammarTypesCount;
  final int grammarValuesCount;
  final int previousWordTypesCount;
  final int previousWordValuesCount;
  final int previousWordSmartCapitalizedTypesCount;
  final int previousWordSmartCapitalizedValuesCount;
  final int sourceSentencesCount;
  final int taggedSentencesCount;
  final int wordTypeDefinitionsCount;
}
