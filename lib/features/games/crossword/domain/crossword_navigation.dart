import 'crossword_generator.dart';
import 'crossword_models.dart';

/// Returns the next cell key within [word] after [currentCellKey].
String? nextCellInWord(CrosswordPlacedWord word, String currentCellKey) {
  for (var i = 0; i < word.word.length; i++) {
    final row = word.row + (word.isAcross ? 0 : i);
    final col = word.col + (word.isAcross ? i : 0);
    if (cellKey(row, col) != currentCellKey) {
      continue;
    }

    if (i + 1 >= word.word.length) {
      return null;
    }

    final nextRow = word.row + (word.isAcross ? 0 : i + 1);
    final nextCol = word.col + (word.isAcross ? i + 1 : 0);
    return cellKey(nextRow, nextCol);
  }

  return null;
}

/// Returns the next occupied cell in row-major order, wrapping at the end.
String? nextFilledCellRowMajor(CrosswordPuzzle puzzle, String currentCellKey) {
  final current = parseCellKey(currentCellKey);
  final currentIndex = current.row * crosswordGridSize + current.col;
  final maxIndex = (crosswordGridSize * crosswordGridSize) - 1;

  for (var index = currentIndex + 1; index <= maxIndex; index++) {
    final key = cellKey(index ~/ crosswordGridSize, index % crosswordGridSize);
    if (puzzle.letters.containsKey(key)) {
      return key;
    }
  }

  for (var index = 0; index < currentIndex; index++) {
    final key = cellKey(index ~/ crosswordGridSize, index % crosswordGridSize);
    if (puzzle.letters.containsKey(key)) {
      return key;
    }
  }

  return null;
}

/// Chooses input focus progression: continue through an intersecting word,
/// preferring Across, then wrap to the next occupied grid cell.
String? nextCellKeyAfterEntry(CrosswordPuzzle puzzle, String currentCellKey) {
  final wordIds = puzzle.wordIdsByCell[currentCellKey] ?? const <int>{};

  final words =
      wordIds
          .map(puzzle.wordById)
          .whereType<CrosswordPlacedWord>()
          .toList(growable: false)
        ..sort((a, b) {
          if (a.isAcross != b.isAcross) {
            return a.isAcross ? -1 : 1;
          }
          return a.id.compareTo(b.id);
        });

  for (final word in words) {
    final nextInWord = nextCellInWord(word, currentCellKey);
    if (nextInWord != null) {
      return nextInWord;
    }
  }

  return nextFilledCellRowMajor(puzzle, currentCellKey);
}

/// Returns the word that typing should fill when [cellKey] is selected.
///
/// Keeps [preferredWordId] when that word still runs through the cell, so
/// typing stays inside one clue; otherwise Across wins, then Down.
CrosswordPlacedWord? activeWordForCell(
  CrosswordPuzzle puzzle,
  String cellKey, {
  int? preferredWordId,
}) {
  final wordIds = puzzle.wordIdsByCell[cellKey] ?? const <int>{};
  final words =
      wordIds
          .map(puzzle.wordById)
          .whereType<CrosswordPlacedWord>()
          .toList(growable: false)
        ..sort((a, b) {
          if (a.isAcross != b.isAcross) {
            return a.isAcross ? -1 : 1;
          }
          return a.id.compareTo(b.id);
        });

  if (preferredWordId != null) {
    for (final word in words) {
      if (word.id == preferredWordId) {
        return word;
      }
    }
  }
  return words.isEmpty ? null : words.first;
}

/// Assigns sequential clue numbers to occupied cells in row-major order.
Map<String, int> buildClueNumbersByCell(CrosswordPuzzle puzzle) {
  final clueNumbers = <String, int>{};
  var clueNumber = 1;
  for (var row = 0; row < crosswordGridSize; row++) {
    for (var col = 0; col < crosswordGridSize; col++) {
      final key = cellKey(row, col);
      if (puzzle.letters.containsKey(key)) {
        clueNumbers[key] = clueNumber++;
      }
    }
  }
  return clueNumbers;
}

/// Maps each word id to the clue number of its starting cell.
Map<int, int> buildStartNumberByWordId(
  CrosswordPuzzle puzzle,
  Map<String, int> clueNumbersByCell,
) {
  return <int, int>{
    for (final word in puzzle.placedWords)
      word.id: clueNumbersByCell[cellKey(word.row, word.col)] ?? 0,
  };
}

/// Reports completion from entered grid letters.
///
/// Revealed words also count as answered so the clue list reflects all
/// solved-visible state.
bool isWordCorrectlyAnswered(
  CrosswordPlacedWord word,
  Map<String, String> enteredLettersByCell,
  Set<int> revealedWordIds,
) {
  if (revealedWordIds.contains(word.id)) {
    return true;
  }

  for (var i = 0; i < word.word.length; i++) {
    final row = word.row + (word.isAcross ? 0 : i);
    final col = word.col + (word.isAcross ? i : 0);
    final enteredLetter = enteredLettersByCell[cellKey(row, col)];

    if (enteredLetter == null ||
        enteredLetter.toLowerCase() != word.word[i].toLowerCase()) {
      return false;
    }
  }
  return true;
}

/// Renders a masked word where solved letters are shown and others are `_`.
String hiddenWordPattern(
  CrosswordPlacedWord word,
  Map<String, String> enteredLettersByCell,
  Set<int> revealedWordIds,
) {
  if (revealedWordIds.contains(word.id)) {
    return word.word.toUpperCase().split('').join(' ');
  }

  final chars = <String>[];
  for (var i = 0; i < word.word.length; i++) {
    final row = word.row + (word.isAcross ? 0 : i);
    final col = word.col + (word.isAcross ? i : 0);
    final enteredLetter = enteredLettersByCell[cellKey(row, col)];
    final isCorrect =
        enteredLetter != null &&
        enteredLetter.toLowerCase() == word.word[i].toLowerCase();
    chars.add(isCorrect ? word.word[i].toUpperCase() : '_');
  }

  return chars.join(' ');
}
