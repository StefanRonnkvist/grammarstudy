import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:grammarstudy/features/games/crossword/domain/crossword_generator.dart';
import 'package:grammarstudy/features/games/crossword/domain/crossword_models.dart';

void main() {
  group('cellKey and parseCellKey', () {
    test('round-trips a coordinate', () {
      expect(parseCellKey(cellKey(3, 7)), (row: 3, col: 7));
    });
  });

  group('buildCrosswordCandidates', () {
    test('keeps grid-friendly words of length 3 to 9', () async {
      final candidates = await buildCrosswordCandidates({
        'Noun': ['cat', 'elephant', 'a', 'antidisestablishment'],
        'Verb': ['runs'],
      });

      final words = candidates.map((c) => c.word).toSet();
      expect(words, {'cat', 'elephant', 'runs'});
    });

    test('deduplicates words across categories', () async {
      final candidates = await buildCrosswordCandidates({
        'Noun': ['cat'],
        'Verb': ['cat'],
      });
      expect(candidates, hasLength(1));
    });

    test('skips blank category names', () async {
      final candidates = await buildCrosswordCandidates({
        '  ': ['cat'],
        'Noun': ['dog'],
      });
      expect(candidates.single.type, 'Noun');
    });
  });

  group('canPlaceWord', () {
    test('rejects a word that runs past the grid edge', () {
      expect(
        canPlaceWord('cat', 0, crosswordGridSize - 1, true, const {}),
        isFalse,
      );
    });

    test('accepts a clear row with a future crossing available later', () {
      // "cat" at row 0 col 0 is valid only if a crossing can be added; the
      // rule itself only requires the start/end cells to be free.
      expect(canPlaceWord('cat', 0, 0, true, const {}), isTrue);
    });

    test('rejects a placement blocked by a letter before the start', () {
      expect(canPlaceWord('cat', 3, 3, true, {cellKey(3, 2): 'x'}), isFalse);
    });

    test('rejects a placement blocked by a letter after the end', () {
      expect(canPlaceWord('cat', 3, 3, true, {cellKey(3, 6): 'x'}), isFalse);
    });

    test('rejects a letter that contradicts an existing crossing', () {
      expect(canPlaceWord('cat', 3, 3, true, {cellKey(3, 4): 'z'}), isFalse);
    });

    test('rejects a word that overlaps an entire matching row', () {
      // Fully covered by matching letters leaves no new intersection.
      final letters = {
        cellKey(3, 0): 'c',
        cellKey(3, 1): 'a',
        cellKey(3, 2): 't',
      };
      expect(canPlaceWord('cat', 3, 0, true, letters), isFalse);
    });

    test('rejects a word that starts directly below an existing letter', () {
      // The cell before the start of a down word must be free.
      expect(canPlaceWord('cat', 1, 0, false, {cellKey(0, 0): 'a'}), isFalse);
    });

    test('rejects a word that runs directly into an existing letter', () {
      // The cell after the end of an across word must be free.
      expect(canPlaceWord('cat', 3, 3, true, {cellKey(3, 6): 'x'}), isFalse);
    });
  });

  group('countIntersections', () {
    test('counts matching cells', () {
      final letters = {cellKey(0, 0): 'c', cellKey(0, 1): 'a'};
      expect(countIntersections('cat', 0, 0, true, letters), 2);
    });

    test('returns zero without matches', () {
      expect(countIntersections('cat', 5, 5, true, const {}), 0);
    });
  });

  group('generateCrosswordPuzzle', () {
    test('returns null for no candidates', () {
      expect(generateCrosswordPuzzle(const [], math.Random(1)), isNull);
    });

    test('places at least the first word', () {
      final puzzle = generateCrosswordPuzzle(const [
        CrosswordCandidate(word: 'cat', type: 'Noun'),
      ], math.Random(7));
      expect(puzzle, isNotNull);
      expect(puzzle!.placedWords, hasLength(1));
      expect(puzzle.placedWords.single.word, 'cat');
    });

    test('produces a consistent letter map and crossing index', () {
      final puzzle = generateCrosswordPuzzle(const [
        CrosswordCandidate(word: 'cat', type: 'Noun'),
        CrosswordCandidate(word: 'tar', type: 'Noun'),
        CrosswordCandidate(word: 'rat', type: 'Noun'),
      ], math.Random(3))!;

      // Every placed word must agree with the shared letter map.
      for (final word in puzzle.placedWords) {
        for (var i = 0; i < word.word.length; i++) {
          final row = word.row + (word.isAcross ? 0 : i);
          final col = word.col + (word.isAcross ? i : 0);
          expect(puzzle.letters[cellKey(row, col)], word.word[i]);
          expect(puzzle.wordIdsByCell[cellKey(row, col)], contains(word.id));
        }
      }
    });

    test('keeps every placement inside the grid', () {
      final puzzle = generateCrosswordPuzzle(const [
        CrosswordCandidate(word: 'cat', type: 'Noun'),
        CrosswordCandidate(word: 'tar', type: 'Noun'),
        CrosswordCandidate(word: 'rat', type: 'Noun'),
        CrosswordCandidate(word: 'art', type: 'Noun'),
      ], math.Random(11))!;

      for (final word in puzzle.placedWords) {
        final lastRow = word.row + (word.isAcross ? 0 : word.word.length - 1);
        final lastCol = word.col + (word.isAcross ? word.word.length - 1 : 0);
        expect(lastRow, lessThan(crosswordGridSize));
        expect(lastCol, lessThan(crosswordGridSize));
        expect(word.row, greaterThanOrEqualTo(0));
        expect(word.col, greaterThanOrEqualTo(0));
      }
    });

    test('wordById resolves known ids and returns null otherwise', () {
      final puzzle = generateCrosswordPuzzle(const [
        CrosswordCandidate(word: 'cat', type: 'Noun'),
      ], math.Random(5))!;
      expect(puzzle.wordById(1)?.word, 'cat');
      expect(puzzle.wordById(999), isNull);
    });
  });
}
