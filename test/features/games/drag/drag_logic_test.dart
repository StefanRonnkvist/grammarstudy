import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:grammarstudy/features/games/drag/domain/drag_logic.dart';

void main() {
  group('parseDragSentenceTokens', () {
    test('attaches a parenthesized tag to the preceding token', () {
      final tokens = parseDragSentenceTokens('The (determiner) cat (noun)');

      expect(tokens.map((t) => t.display).toList(), ['The', 'cat']);
      expect(tokens[0].expectedParentheticalNormalized, 'DETERMINER');
      expect(tokens[1].expectedParentheticalNormalized, 'NOUN');
    });

    test('leaves untagged tokens without an expected word', () {
      final tokens = parseDragSentenceTokens('A plain sentence .');

      expect(tokens.map((t) => t.display).toList(), [
        'A',
        'plain',
        'sentence',
        '.',
      ]);
      expect(
        tokens.every((t) => t.expectedParentheticalNormalized == null),
        isTrue,
      );
    });

    test('ignores a leading tag with no preceding token', () {
      final tokens = parseDragSentenceTokens('(leading) word');
      expect(tokens.single.display, 'word');
      expect(tokens.single.expectedParentheticalNormalized, isNull);
    });

    test('preserves repeated tokens as separate entries', () {
      final tokens = parseDragSentenceTokens('the (det) cat and the (det) dog');

      expect(tokens[0].display, 'the');
      expect(tokens[3].display, 'the');
    });
  });

  group('buildDragRound', () {
    test('deduplicates and sorts the removed words', () {
      final round = buildDragRound('the (det) cat and the (det) dog (noun)');

      expect(round.removedWords, ['DET', 'NOUN']);
    });

    test('strips tags from the displayed sentence', () {
      final round = buildDragRound('The (determiner) cat (noun) sleeps .');
      expect(round.sentence, 'The cat sleeps .');
    });
  });

  group('buildRandomDragRound', () {
    test('returns null for no sentences', () {
      expect(buildRandomDragRound(const [], math.Random(1)), isNull);
      expect(buildRandomDragRound(const ['', '   '], math.Random(1)), isNull);
    });

    test('returns tokens matching the returned round', () {
      final sentences = ['The (determiner) cat (noun) sleeps .'];
      final generated = buildRandomDragRound(sentences, math.Random(1))!;

      expect(generated.tokens, isNotEmpty);
      expect(generated.round.removedWords, isNotEmpty);
      // Every removed word must come from a token in the same round.
      final expected = generated.tokens
          .map((t) => t.expectedParentheticalNormalized)
          .whereType<String>()
          .toSet();
      expect(generated.round.removedWords.toSet(), expected);
    });

    test('the displayed sentence contains no parentheses', () {
      final sentences = ['The (determiner) cat (noun) sleeps .'];
      final generated = buildRandomDragRound(sentences, math.Random(1))!;
      expect(generated.round.sentence, isNot(contains('(')));
    });
  });

  group('isDragTokenCorrect', () {
    const tagged = 'The (determiner) cat (noun)';
    final tokens = parseDragSentenceTokens(tagged);

    test('accepts the exact normalized tag', () {
      expect(
        isDragTokenCorrect(tokens: tokens, tokenIndex: 0, word: 'determiner'),
        isTrue,
      );
    });

    test('rejects a mismatched word', () {
      expect(
        isDragTokenCorrect(tokens: tokens, tokenIndex: 0, word: 'noun'),
        isFalse,
      );
    });

    test('rejects an out-of-range token index', () {
      expect(
        isDragTokenCorrect(tokens: tokens, tokenIndex: 99, word: 'determiner'),
        isFalse,
      );
    });

    test('rejects an untagged token', () {
      expect(
        isDragTokenCorrect(tokens: tokens, tokenIndex: -1, word: 'determiner'),
        isFalse,
      );
    });
  });
}
