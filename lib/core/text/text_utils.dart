/// Shared string helpers for normalizing and matching study content.
library;

/// Collapses all whitespace runs into single spaces and trims the result.
String normalizeWhitespace(String value) {
  return value.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Uppercases [word] after collapsing internal whitespace.
String normalizeTagWord(String word) => normalizeWhitespace(word).toUpperCase();

/// Uppercases [value] and strips everything except letters, digits, and spaces.
///
/// This produces the comparable form used when matching a visible word
/// against a parenthesized grammar tag.
String normalizeComparable(String value) {
  return normalizeWhitespace(
    value,
  ).toUpperCase().replaceAll(RegExp(r'[^A-Z0-9 ]'), '');
}

/// Reduces a value to lowercase ASCII letters, used for crossword vocabulary.
String normalizeWordLetters(String raw) {
  return raw.trim().toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
}

/// Builds a case-insensitive matcher for [word].
///
/// Single words require word boundaries so that `art` does not match
/// `start`; multi-word phrases are matched literally.
RegExp buildWordPattern(String word) {
  final normalizedWord = word.trim();
  if (normalizedWord.contains(' ')) {
    return RegExp(RegExp.escape(normalizedWord), caseSensitive: false);
  }

  return RegExp('\\b${RegExp.escape(normalizedWord)}\\b', caseSensitive: false);
}

/// Whether [text] contains [word] as a whole word or literal phrase.
bool containsWholeWord(String text, String word) {
  final normalizedText = text.trim();
  final normalizedWord = word.trim();
  if (normalizedText.isEmpty || normalizedWord.isEmpty) {
    return false;
  }

  return buildWordPattern(normalizedWord).hasMatch(normalizedText);
}

/// Returns the first sentence in [sentences] that contains [word].
///
/// Falls back to a readable message when no sentence matches.
String findSentenceForWord(String word, List<String> sentences) {
  final pattern = buildWordPattern(word);
  for (final sentence in sentences) {
    if (pattern.hasMatch(sentence)) {
      return sentence;
    }
  }
  return 'No sentence found for "$word" in the sentence list.';
}

/// Removes parenthesized grammar annotations and repairs punctuation spacing.
String stripGrammarTags(String taggedSentence) {
  return taggedSentence
      .replaceAll(RegExp(r'\s*\([^\)]*\)'), '')
      .replaceAllMapped(RegExp(r'\s+([,.;:!?])'), (match) => match[1]!)
      .trim();
}
