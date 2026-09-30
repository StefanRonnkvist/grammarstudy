import 'package:flutter_test/flutter_test.dart';
import 'package:grammarstudy/features/games/crossword/domain/crossword_models.dart';
import 'package:grammarstudy/features/games/crossword/domain/crossword_navigation.dart';

void main() {
  const placed = CrosswordPlacedWord(
    id: 1,
    word: 'cat',
    type: 'Noun',
    row: 0,
    col: 0,
    isAcross: true,
  );

  const puzzle = CrosswordPuzzle(
    placedWords: [placed],
    letters: {'0:0': 'c', '0:1': 'a', '0:2': 't'},
    wordIdsByCell: {
      '0:0': {1},
      '0:1': {1},
      '0:2': {1},
    },
  );

  group('nextCellInWord', () {
    test('advances within an across word', () {
      expect(nextCellInWord(placed, '0:0'), '0:1');
      expect(nextCellInWord(placed, '0:1'), '0:2');
    });

    test('returns null at the last letter', () {
      expect(nextCellInWord(placed, '0:2'), isNull);
    });

    test('returns null for a cell outside the word', () {
      expect(nextCellInWord(placed, '5:5'), isNull);
    });
  });

  group('nextFilledCellRowMajor', () {
    test('moves to the following occupied cell', () {
      expect(nextFilledCellRowMajor(puzzle, '0:0'), '0:1');
    });

    test('wraps to the first occupied cell at the end', () {
      expect(nextFilledCellRowMajor(puzzle, '0:2'), '0:0');
    });
  });

  group('nextCellKeyAfterEntry', () {
    test('continues through the intersecting word', () {
      expect(nextCellKeyAfterEntry(puzzle, '0:0'), '0:1');
    });
  });

  group('clue numbering', () {
    test('numbers occupied cells in row-major order', () {
      final numbers = buildClueNumbersByCell(puzzle);
      expect(numbers['0:0'], 1);
      expect(numbers['0:1'], 2);
      expect(numbers['0:2'], 3);
    });

    test('maps word ids to their starting cell number', () {
      final numbers = buildClueNumbersByCell(puzzle);
      expect(buildStartNumberByWordId(puzzle, numbers)[1], 1);
    });
  });

  group('isWordCorrectlyAnswered', () {
    test('is false with no letters entered', () {
      expect(isWordCorrectlyAnswered(placed, const {}, const {}), isFalse);
    });

    test('is true once every letter matches', () {
      final entered = {'0:0': 'C', '0:1': 'A', '0:2': 'T'};
      expect(isWordCorrectlyAnswered(placed, entered, const {}), isTrue);
    });

    test('is false when a letter is wrong', () {
      final entered = {'0:0': 'C', '0:1': 'A', '0:2': 'X'};
      expect(isWordCorrectlyAnswered(placed, entered, const {}), isFalse);
    });

    test('is true for a revealed word regardless of entries', () {
      expect(isWordCorrectlyAnswered(placed, const {}, const {1}), isTrue);
    });
  });

  group('hiddenWordPattern', () {
    test('masks every letter of an unsolved word', () {
      expect(hiddenWordPattern(placed, const {}, const {}), '_ _ _');
    });

    test('reveals correct letters and masks the rest', () {
      final entered = {'0:0': 'C', '0:1': 'X', '0:2': 'T'};
      expect(hiddenWordPattern(placed, entered, const {}), 'C _ T');
    });

    test('shows the full word once revealed', () {
      expect(hiddenWordPattern(placed, const {}, const {1}), 'C A T');
    });
  });
}
