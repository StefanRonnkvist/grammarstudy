import 'dart:math' as math;

import '../../crossword/domain/crossword_models.dart';
import 'slide_models.dart';

/// Chooses a target word and one draggable vertical word per target letter.
///
/// Each vertical word is guaranteed to contain the letter it must align.
SlideBoard generateSlideBoard(
  List<CrosswordCandidate> candidates,
  math.Random random,
) {
  if (candidates.isEmpty) {
    return const SlideBoard(
      word: '',
      wordType: '',
      letters: [],
      revealedLetters: [],
      verticalWords: [],
      correctLetters: 0,
      isComplete: false,
      hasSubmitted: false,
    );
  }

  final randomCandidate = candidates[random.nextInt(candidates.length)];
  final randomWord = randomCandidate.word.toUpperCase();
  final letters = randomWord.split('');

  final verticalWords = <SlideVerticalWord>[];
  for (var i = 0; i < letters.length; i++) {
    final targetLetter = letters[i];

    final matchingWords = candidates
        .where((c) => c.word.toUpperCase().contains(targetLetter))
        .toList();

    if (matchingWords.isEmpty) {
      continue;
    }

    final chosen = matchingWords[random.nextInt(matchingWords.length)];
    final verticalWord = chosen.word.toUpperCase();

    verticalWords.add(
      SlideVerticalWord(
        word: verticalWord,
        horizontalIndex: i,
        letterIndexInWord: verticalWord.indexOf(targetLetter),
        isAbove: random.nextBool(),
        verticalOffset: 0.0,
      ),
    );
  }

  return SlideBoard(
    word: randomWord,
    wordType: randomCandidate.type,
    letters: letters,
    revealedLetters: List<bool>.filled(letters.length, false),
    verticalWords: verticalWords,
    correctLetters: 0,
    isComplete: false,
    hasSubmitted: false,
  );
}

/// Returns the vertical-word letter whose row covers the target square center.
String? letterInsideTargetSquare(
  SlideVerticalWord verticalWord,
  double squareCenterY,
  double letterHeight,
) {
  final relativeCenter = squareCenterY - verticalWord.verticalOffset;
  final letterIndex = (relativeCenter / letterHeight).floor();
  if (letterIndex < 0 || letterIndex >= verticalWord.word.length) {
    return null;
  }
  return verticalWord.word[letterIndex];
}

/// Evaluates every aligned column and returns the resulting board.
///
/// Only correct positions are revealed; the board is marked complete when all
/// target letters line up.
SlideBoard evaluateSlideBoard(
  SlideBoard board, {
  required double topLaneHeight,
  required double squareSize,
  required double letterHeight,
}) {
  final squareCenterY = topLaneHeight + (squareSize / 2);
  var correctLetters = 0;
  var isComplete = true;
  final revealed = List<bool>.filled(board.letters.length, false);

  for (var i = 0; i < board.letters.length; i++) {
    SlideVerticalWord? verticalWord;
    for (final candidate in board.verticalWords) {
      if (candidate.horizontalIndex == i) {
        verticalWord = candidate;
        break;
      }
    }

    final selectedLetter = verticalWord == null
        ? null
        : letterInsideTargetSquare(verticalWord, squareCenterY, letterHeight);
    final matched = selectedLetter == board.letters[i];

    revealed[i] = matched;
    if (matched) {
      correctLetters++;
    } else {
      isComplete = false;
    }
  }

  return SlideBoard(
    word: board.word,
    wordType: board.wordType,
    letters: board.letters,
    revealedLetters: revealed,
    verticalWords: board.verticalWords,
    correctLetters: correctLetters,
    isComplete: isComplete,
    hasSubmitted: true,
  );
}

/// Clears a previous submission because the board arrangement has changed.
SlideBoard clearSlideSubmission(SlideBoard board) {
  if (!board.hasSubmitted) {
    return board;
  }
  return SlideBoard(
    word: board.word,
    wordType: board.wordType,
    letters: board.letters,
    revealedLetters: List<bool>.filled(board.letters.length, false),
    verticalWords: board.verticalWords,
    correctLetters: 0,
    isComplete: false,
    hasSubmitted: false,
  );
}

/// Snaps a dragged column to the nearest letter-height boundary.
SlideBoard snapSlideColumn(
  SlideBoard board,
  int index, {
  required double letterHeight,
  required double squareSize,
}) {
  if (index < 0 || index >= board.verticalWords.length) {
    return board;
  }

  final cellStep = letterHeight > 0 ? letterHeight : squareSize;
  if (cellStep > 0) {
    final currentOffset = board.verticalWords[index].verticalOffset;
    board.verticalWords[index].verticalOffset =
        (currentOffset / cellStep).roundToDouble() * cellStep;
  }

  return clearSlideSubmission(board);
}

/// Applies a vertical drag delta to one column.
SlideBoard dragSlideColumn(SlideBoard board, int index, double delta) {
  if (index < 0 || index >= board.verticalWords.length) {
    return board;
  }
  board.verticalWords[index].verticalOffset += delta;
  return clearSlideSubmission(board);
}

/// Finds the column that serves horizontal position [horizontalIndex].
SlideVerticalWord? columnAt(SlideBoard board, int horizontalIndex) {
  for (final column in board.verticalWords) {
    if (column.horizontalIndex == horizontalIndex) {
      return column;
    }
  }
  return null;
}

/// Longest column above the target row, used to size the top lane.
int longestColumnAbove(SlideBoard board) {
  var maxLength = 0;
  for (final column in board.verticalWords) {
    if (column.isAbove && column.word.length > maxLength) {
      maxLength = column.word.length;
    }
  }
  return maxLength;
}

/// Longest column below the target row, used to size the bottom lane.
int longestColumnBelow(SlideBoard board) {
  var maxLength = 0;
  for (final column in board.verticalWords) {
    if (!column.isAbove && column.word.length > maxLength) {
      maxLength = column.word.length;
    }
  }
  return maxLength;
}
