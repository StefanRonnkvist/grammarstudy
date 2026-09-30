import 'dart:math' as math;

import '../../../../core/text/text_utils.dart';
import 'drag_models.dart';

/// Converts an annotated sentence into draggable display tokens.
///
/// A parenthesized tag is attached to the preceding visible token as its
/// expected drop target; the annotation itself is not displayed.
List<DragSentenceToken> parseDragSentenceTokens(String rawSentence) {
  final rawParts = RegExp(r'\([^()]*\)|\S+')
      .allMatches(rawSentence)
      .map((match) => match.group(0) ?? '')
      .toList(growable: false);

  final tokens = <DragSentenceToken>[];

  for (final part in rawParts) {
    final trimmed = part.trim();
    if (trimmed.isEmpty) {
      continue;
    }

    final isParenthetical = trimmed.startsWith('(') && trimmed.endsWith(')');
    if (isParenthetical) {
      if (tokens.isEmpty || trimmed.length < 3) {
        continue;
      }

      final inside = trimmed.substring(1, trimmed.length - 1);
      final expected = normalizeTagWord(inside);
      if (expected.isEmpty) {
        continue;
      }

      final previous = tokens.last;
      tokens[tokens.length - 1] = DragSentenceToken(
        display: previous.display,
        normalized: previous.normalized,
        expectedParentheticalNormalized: expected,
      );
      continue;
    }

    final normalized = normalizeComparable(trimmed);
    // Punctuation-only tokens carry no comparison value but must still be
    // displayed so the reconstructed sentence keeps its original wording.
    if (normalized.isEmpty && !_isPunctuationOnly(trimmed)) {
      continue;
    }
    tokens.add(DragSentenceToken(display: trimmed, normalized: normalized));
  }

  return tokens;
}

/// Whether [value] consists only of punctuation or symbols.
bool _isPunctuationOnly(String value) {
  return value.replaceAll(RegExp(r'[A-Za-z0-9]'), '').trim().isNotEmpty;
}

/// Builds one drag round from a tagged sentence.
///
/// Repeated tag targets are deduplicated while token occurrences stay distinct.
DragRound buildDragRound(String rawSentence) {
  final tokens = parseDragSentenceTokens(rawSentence);

  return DragRound(
    sentence: normalizeWhitespace(
      tokens.map((token) => token.display).join(' '),
    ),
    removedWords: _collectRemovedWords(tokens),
  );
}

/// Picks a random tagged sentence and builds a round together with its tokens.
///
/// Returning both avoids reparsing the chosen sentence to recover its tokens.
/// Returns null when [sentences] has no usable content.
({DragRound round, List<DragSentenceToken> tokens})? buildRandomDragRound(
  List<String> sentences,
  math.Random random,
) {
  final nonEmpty = sentences
      .map(normalizeWhitespace)
      .where((line) => line.isNotEmpty)
      .toList(growable: false);

  if (nonEmpty.isEmpty) {
    return null;
  }

  final tokens = parseDragSentenceTokens(
    nonEmpty[random.nextInt(nonEmpty.length)],
  );

  return (
    round: DragRound(
      sentence: normalizeWhitespace(
        tokens.map((token) => token.display).join(' '),
      ),
      removedWords: _collectRemovedWords(tokens),
    ),
    tokens: tokens,
  );
}

/// Collects the unique, sorted annotation targets referenced by [tokens].
List<String> _collectRemovedWords(List<DragSentenceToken> tokens) {
  return tokens
      .map((token) => token.expectedParentheticalNormalized)
      .whereType<String>()
      .where((word) => word.isNotEmpty)
      .toSet()
      .toList(growable: true)
    ..sort((a, b) => a.compareTo(b));
}

/// Whether the token at [tokenIndex] correctly fills the target [word].
///
/// A match is exact against the token's normalized parenthesized tag.
bool isDragTokenCorrect({
  required List<DragSentenceToken> tokens,
  required int tokenIndex,
  required String word,
}) {
  if (tokenIndex < 0 || tokenIndex >= tokens.length) {
    return false;
  }
  final expected = tokens[tokenIndex].expectedParentheticalNormalized;
  if (expected == null || expected.isEmpty) {
    return false;
  }
  return expected == normalizeComparable(word);
}
