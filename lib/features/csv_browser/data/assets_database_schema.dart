/// Defines the Hive keys and bundled asset locations used by the study database.
///
/// Increment [schemaVersion] whenever the stored shape changes so startup will
/// replace stale data with the current bundled content.
class AssetsDatabaseSchema {
  static const String boxName = 'assets_database_v1';
  static const String schemaVersionKey = '__schema_version__';
  static const int schemaVersion = 1;

  static const String grammarTagValuesKey = 'grammar_tag_values';
  static const String grammarTagPreviousWordValuesKey =
      'grammar_tag_previous_word_values';
  static const String grammarTagPreviousWordValuesSmartCapitalizedKey =
      'grammar_tag_previous_word_values_smart_capitalized';
  static const String dictionarySentencesSourceKey =
      'dictionary_sentences_source';
  static const String dictionarySentencesContextTaggedKey =
      'dictionary_sentences_context_grammar_tagged';
  static const String wordTypeDefinitionsKey = 'word_type_definitions';

  static const String prebuiltDatabaseAssetPath =
      'assets/prebuilt_db/assets_database_v1.hive';
  static const String prebuiltDatabaseFileName = 'assets_database_v1.hive';

  static const String exportSentencesWithWordTypeAssetPath =
      'assets/db_exports/sentences_with_word_type.txt';
  static const String exportSentencesWithoutWordTypeAssetPath =
      'assets/db_exports/sentences_without_word_type.txt';
  static const String exportWordTypeCategoriesAssetPath =
      'assets/db_exports/word_type_categories_with_associated_words.json';
  static const String exportWordTypeDefinitionsAssetPath =
      'assets/db_exports/word_type_definitions.json';
}
