import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grammarstudy/data/study_database_service.dart';
import 'package:grammarstudy/data/study_database_schema.dart';
import 'package:hive/hive.dart';

void main() {
  // The service loads bundled exports through rootBundle, which requires the
  // services binding to exist in a test environment.
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('grammar_study_db');
    Hive.init(tempDirectory.path);
  });

  tearDown(() async {
    await Hive.close();
    if (tempDirectory.existsSync()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  /// Seeds the box from the bundled exports without the prebuilt snapshot.
  Future<void> seed() async {
    final service = StudyDatabaseService();
    await service.initializeFromAssetsIfNeeded(forceRefresh: true);
  }

  group('schema', () {
    test('exposes stable box and key names', () {
      expect(StudyDatabaseSchema.boxName, 'assets_database_v1');
      expect(
        StudyDatabaseSchema.dictionarySentencesContextTaggedKey,
        'dictionary_sentences_context_grammar_tagged',
      );
    });

    test('service constants mirror the schema constants', () {
      expect(
        StudyDatabaseService.grammarTagValuesKey,
        StudyDatabaseSchema.grammarTagValuesKey,
      );
      expect(
        StudyDatabaseService.wordTypeDefinitionsKey,
        StudyDatabaseSchema.wordTypeDefinitionsKey,
      );
    });
  });

  group('seeding from bundled exports', () {
    test('writes the current schema version', () async {
      await seed();
      final box = await Hive.openBox<dynamic>(StudyDatabaseSchema.boxName);
      expect(
        box.get(StudyDatabaseSchema.schemaVersionKey),
        StudyDatabaseSchema.schemaVersion,
      );
    });

    test('stores grammar categories with associated values', () async {
      await seed();
      final values = await StudyDatabaseService().readGrammarTagValues();

      expect(values, isNotEmpty);
      expect(values.keys.every((key) => key.trim().isNotEmpty), isTrue);
      expect(
        values.values.every((list) => list.every((v) => v.isNotEmpty)),
        isTrue,
      );
    });

    test('stores plain and tagged sentence collections', () async {
      await seed();
      final service = StudyDatabaseService();

      final plain = await service.readDictionarySentencesSource();
      final tagged = await service.readDictionarySentencesContextTagged();

      expect(plain, isNotEmpty);
      expect(tagged, isNotEmpty);
      expect(plain.every((line) => line.trim().isNotEmpty), isTrue);
      // Tagged sentences keep their parenthesized annotations.
      expect(tagged.any((line) => line.contains('(')), isTrue);
    });

    test('stores word type definitions keyed by lower-case type', () async {
      await seed();
      final definitions = await StudyDatabaseService()
          .readWordTypeDefinitions();

      expect(definitions, isNotEmpty);
      expect(definitions.keys.every((key) => key == key.toLowerCase()), isTrue);
    });

    test('derives previous-word lookups from grammar categories', () async {
      await seed();
      final service = StudyDatabaseService();

      final values = await service.readGrammarTagValues();
      final previous = await service.readGrammarTagPreviousWordValues();
      final flattened = await service
          .readGrammarTagPreviousWordValuesSmartCapitalized();

      expect(previous.keys.toSet(), values.keys.toSet());
      expect(flattened, isNotEmpty);
      expect(flattened.every((value) => value.trim().isNotEmpty), isTrue);
    });
  });

  group('initializeFromAssetsIfNeeded', () {
    test('leaves a current database untouched', () async {
      await seed();
      final box = await Hive.openBox<dynamic>(StudyDatabaseSchema.boxName);

      // Mark the box so a reseed would be observable.
      const markerKey = 'test_marker';
      await box.put(markerKey, 'keep me');

      await StudyDatabaseService().initializeFromAssetsIfNeeded();

      expect(box.get(markerKey), 'keep me');
    });

    test('reseeds when the stored schema version is stale', () async {
      await seed();
      final box = await Hive.openBox<dynamic>(StudyDatabaseSchema.boxName);
      await box.put(StudyDatabaseSchema.schemaVersionKey, -1);
      await box.close();

      await StudyDatabaseService().initializeFromAssetsIfNeeded();

      // The reseed replaces the underlying file, so re-open before reading.
      final reseeded = await Hive.openBox<dynamic>(StudyDatabaseSchema.boxName);
      expect(
        reseeded.get(StudyDatabaseSchema.schemaVersionKey),
        StudyDatabaseSchema.schemaVersion,
      );
    });
  });

  group('readSummary', () {
    test('reports counts that match the stored collections', () async {
      await seed();
      final service = StudyDatabaseService();

      final summary = await service.readSummary();
      final values = await service.readGrammarTagValues();
      final plain = await service.readDictionarySentencesSource();
      final tagged = await service.readDictionarySentencesContextTagged();
      final definitions = await service.readWordTypeDefinitions();

      expect(summary.schemaVersion, StudyDatabaseSchema.schemaVersion);
      expect(summary.grammarTypesCount, values.length);
      expect(
        summary.grammarValuesCount,
        values.values.fold<int>(0, (sum, list) => sum + list.length),
      );
      expect(summary.sourceSentencesCount, plain.length);
      expect(summary.taggedSentencesCount, tagged.length);
      expect(summary.wordTypeDefinitionsCount, definitions.length);
    });
  });

  group('tolerant decoding', () {
    test('returns empty collections when the box has no data', () async {
      // A fresh, never-seeded box must read as empty rather than throwing.
      final service = StudyDatabaseService();

      expect(await service.readGrammarTagValues(), isEmpty);
      expect(await service.readDictionarySentencesSource(), isEmpty);
      expect(await service.readWordTypeDefinitions(), isEmpty);
    });
  });
}
