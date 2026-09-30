import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:grammarstudy/features/games/crossword/domain/crossword_models.dart';
import 'package:grammarstudy/features/games/slide/domain/slide_logic.dart';
import 'package:grammarstudy/features/games/slide/domain/slide_models.dart';

void main() {
  const candidates = [
    CrosswordCandidate(word: 'cat', type: 'Noun'),
    CrosswordCandidate(word: 'tap', type: 'Noun'),
    CrosswordCandidate(word: 'pat', type: 'Noun'),
    CrosswordCandidate(word: 'rat', type: 'Noun'),
  ];

  group('generateSlideBoard', () {
    test('returns an empty board with no candidates', () {
      final board = generateSlideBoard(const [], math.Random(1));
      expect(board.hasWord, isFalse);
      expect(board.verticalWords, isEmpty);
    });

    test('creates one column per target letter when possible', () {
      final board = generateSlideBoard(candidates, math.Random(4));
      expect(board.hasWord, isTrue);
      expect(board.letters, isNotEmpty);
      expect(board.revealedLetters.every((revealed) => !revealed), isTrue);
      expect(board.hasSubmitted, isFalse);
    });

    test('every column word contains the letter it must align', () {
      // Repeat to cover different random draws.
      for (var seed = 0; seed < 25; seed++) {
        final board = generateSlideBoard(candidates, math.Random(seed));
        for (final column in board.verticalWords) {
          final target = board.letters[column.horizontalIndex];
          expect(column.word, contains(target));
        }
      }
    });

    test('each column targets a distinct horizontal index', () {
      for (var seed = 0; seed < 25; seed++) {
        final board = generateSlideBoard(candidates, math.Random(seed));
        final indexes = board.verticalWords
            .map((column) => column.horizontalIndex)
            .toSet();
        expect(indexes.length, board.verticalWords.length);
        for (final column in board.verticalWords) {
          expect(column.horizontalIndex, lessThan(board.letters.length));
        }
      }
    });
  });

  group('letterInsideTargetSquare', () {
    test('returns the letter covering the square centre', () {
      final column = SlideVerticalWord(
        word: 'CAT',
        horizontalIndex: 0,
        letterIndexInWord: 0,
        isAbove: true,
        verticalOffset: 0,
      );
      // Square centre is the middle of the first letter row.
      expect(letterInsideTargetSquare(column, 50, 100), 'C');
      expect(letterInsideTargetSquare(column, 150, 100), 'A');
    });

    test('returns null above the first letter', () {
      final column = SlideVerticalWord(
        word: 'CAT',
        horizontalIndex: 0,
        letterIndexInWord: 0,
        isAbove: true,
        verticalOffset: 0,
      );
      expect(letterInsideTargetSquare(column, -50, 100), isNull);
    });

    test('returns null past the last letter', () {
      final column = SlideVerticalWord(
        word: 'CAT',
        horizontalIndex: 0,
        letterIndexInWord: 0,
        isAbove: true,
        verticalOffset: 0,
      );
      expect(letterInsideTargetSquare(column, 9999, 100), isNull);
    });
  });

  group('evaluateSlideBoard', () {
    SlideBoard boardWithOffsets(Map<int, double> offsets) {
      final board = generateSlideBoard(candidates, math.Random(2));
      for (final column in board.verticalWords) {
        if (offsets.containsKey(column.horizontalIndex)) {
          column.verticalOffset = offsets[column.horizontalIndex]!;
        }
      }
      return board;
    }

    test('submits and reveals only the letters that already align', () {
      final board = evaluateSlideBoard(
        boardWithOffsets(const {}),
        topLaneHeight: 100,
        squareSize: 100,
        letterHeight: 100,
      );
      expect(board.hasSubmitted, isTrue);
      // With all offsets at zero some letters may already line up, so assert
      // consistency rather than a fixed count.
      expect(board.correctLetters, lessThanOrEqualTo(board.letters.length));
      expect(
        board.revealedLetters.where((revealed) => revealed).length,
        board.correctLetters,
      );
      expect(board.isComplete, board.correctLetters == board.letters.length);
    });

    test('marks the board solved when every letter is correct', () {
      // Build a board then force every column to the offset that yields the
      // target letter, proving a fully correct arrangement is detected.
      final board = generateSlideBoard(candidates, math.Random(9));
      final topLaneHeight = 100.0;
      const squareSize = 100.0;
      const letterHeight = 100.0;
      final squareCenterY = topLaneHeight + (squareSize / 2);

      for (final column in board.verticalWords) {
        final target = board.letters[column.horizontalIndex];
        final letterIndex = column.word.indexOf(target);
        // Offset that places letterIndex at the square centre row.
        column.verticalOffset = squareCenterY - (letterIndex * letterHeight);
      }

      final evaluated = evaluateSlideBoard(
        board,
        topLaneHeight: topLaneHeight,
        squareSize: squareSize,
        letterHeight: letterHeight,
      );

      expect(evaluated.correctLetters, evaluated.letters.length);
      expect(evaluated.isComplete, isTrue);
      expect(evaluated.isSolved, isTrue);
      expect(evaluated.revealedLetters.every((revealed) => revealed), isTrue);
    });
  });

  group('clearSlideSubmission', () {
    test('leaves an unsubmitted board untouched', () {
      final board = generateSlideBoard(candidates, math.Random(6));
      expect(clearSlideSubmission(board).hasSubmitted, isFalse);
    });

    test('resets a submitted board', () {
      final submitted = evaluateSlideBoard(
        generateSlideBoard(candidates, math.Random(6)),
        topLaneHeight: 100,
        squareSize: 100,
        letterHeight: 100,
      );
      final cleared = clearSlideSubmission(submitted);
      expect(cleared.hasSubmitted, isFalse);
      expect(cleared.correctLetters, 0);
      expect(cleared.revealedLetters.every((revealed) => !revealed), isTrue);
    });
  });

  group('dragSlideColumn', () {
    test('moves the column and clears a prior submission', () {
      final board = evaluateSlideBoard(
        generateSlideBoard(candidates, math.Random(8)),
        topLaneHeight: 100,
        squareSize: 100,
        letterHeight: 100,
      );
      final index = 0;
      final before = board.verticalWords[index].verticalOffset;
      final moved = dragSlideColumn(board, index, 25);

      expect(moved.verticalWords[index].verticalOffset, before + 25);
      expect(moved.hasSubmitted, isFalse);
    });

    test('ignores an out-of-range index', () {
      final board = generateSlideBoard(candidates, math.Random(8));
      expect(dragSlideColumn(board, 999, 10).hasSubmitted, isFalse);
    });
  });

  group('columnAt', () {
    test('finds the column for a horizontal index', () {
      final board = generateSlideBoard(candidates, math.Random(3));
      final first = board.verticalWords.first;
      expect(columnAt(board, first.horizontalIndex)?.word, first.word);
    });

    test('returns null when no column serves the index', () {
      final board = generateSlideBoard(candidates, math.Random(3));
      expect(columnAt(board, 999), isNull);
    });
  });

  group('lane sizing', () {
    test('reports the longest column above and below', () {
      final board = generateSlideBoard(candidates, math.Random(12));
      final above = board.verticalWords
          .where((column) => column.isAbove)
          .fold<int>(0, (max, c) => math.max(max, c.word.length));
      final below = board.verticalWords
          .where((column) => !column.isAbove)
          .fold<int>(0, (max, c) => math.max(max, c.word.length));

      expect(longestColumnAbove(board), above);
      expect(longestColumnBelow(board), below);
    });
  });
}
