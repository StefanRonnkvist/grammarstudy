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

  group('nextTypingIndex', () {
    test('moves to the next blank square', () {
      expect(nextTypingIndex([null, null, null]), 0);
      expect(nextTypingIndex(['A', null, null]), 1);
      expect(nextTypingIndex(['A', 'B', null]), 2);
    });

    test('steps over a square locked by a crossing letter', () {
      // "A _ _" where the first square is locked by another clue: the caret
      // must land on the second square, not restart at the start.
      expect(
        nextTypingIndex(
          [null, null, null],
          lockedIndexes: {0},
        ),
        1,
      );

      expect(
        nextTypingIndex(
          ['A', null, null],
          lockedIndexes: {0},
        ),
        1,
      );

      expect(
        nextTypingIndex(
          ['A', null, null],
          lockedIndexes: {0, 1},
        ),
        2,
      );
    });

    test('rests on the last square when every square is filled', () {
      expect(nextTypingIndex(['A', 'B', 'C']), 2);
      expect(nextTypingIndex(const []), 0);
    });
  });

  group('resolveClueLettersFromField', () {
    List<String?> call({
      required List<String?> locked,
      required List<String?> shown,
      required List<String?> existing,
      required String field,
    }) => resolveClueLettersFromField(
      lockedLetters: locked,
      shownLetters: shown,
      existingLetters: existing,
      fieldCharacters: field.split(''),
    );

    test('keeps a crossing letter anchored when typing after it', () {
      // "G___" with E supplied by a crossing Down word at index 1.
      expect(
        call(
          locked: [null, 'E', null, null],
          shown: [null, 'E', null, null],
          existing: [null, 'E', null, null],
          field: 'GE__',
        ),
        ['G', 'E', null, null],
      );
    });

    test('a blank square keeps the letter it already holds', () {
      // "G__E": index 2 is a blank, so the square keeps the G it already has.
      expect(
        call(
          locked: [null, 'E', null, null],
          shown: [null, 'E', null, null],
          existing: [null, 'E', 'G', null],
          field: 'G__E',
        ),
        ['G', 'E', 'G', 'E'],
      );
    });

    test('a correct letter is shown again even when the field blanks it', () {
      // The square at index 2 already holds the correct G, so it shows again
      // rather than being cleared by the blank in the field.
      expect(
        call(
          locked: [null, 'E', null, null],
          shown: [null, 'E', 'G', null],
          existing: [null, 'E', 'G', null],
          field: 'G__E',
        ),
        ['G', 'E', 'G', 'E'],
      );
    });

    test('a crossing letter is never overwritten by typed input', () {
      expect(
        call(
          locked: [null, 'E', null],
          shown: [null, 'E', null],
          existing: [null, 'E', null],
          field: 'GZG',
        ),
        ['G', 'E', 'G'],
      );
    });

    test('typing letters fills each square in place without shifting', () {
      const length = 8;

      // An "E" crossing at index 1 of an eight letter word.
            final locked = List<String?>.filled(length, null)..[1] = 'E';

            final typed = List<String?>.filled(length, null)..[1] = 'E';
            var existing = List<String?>.filled(length, null);
            for (var index = 0; index < length; index++) {
              if (typed[index] != null) {
                continue;
              }
              typed[index] = 'X';
              final shown = List<String?>.filled(length, null)..[1] = 'E';
              final result = resolveClueLettersFromField(
                lockedLetters: locked,
                shownLetters: shown,
                existingLetters: existing,
                fieldCharacters: typed
                    .map((letter) => letter ?? '_')
                    .toList(growable: false),
              );

              expect(
                result[1],
                'E',
                reason: 'the crossing letter must never move or be replaced',
              );
              expect(result.length, length);
              for (var check = 0; check < length; check++) {
                expect(
                  result[check],
                  typed[check],
                  reason: 'square $check holds exactly the letter typed into it',
                );
              }
              existing = List<String?>.from(result);
            }
          });
  });

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
