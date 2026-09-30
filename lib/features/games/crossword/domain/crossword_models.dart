/// Data model for the Crossword game.
library;

/// Grid width and height in cells.
const int crosswordGridSize = 13;

/// Number of words a complete puzzle aims to place.
const int crosswordTargetWordCount = 6;

/// Generation attempts before the best partial puzzle is accepted.
const int crosswordGenerationAttempts = 40;

/// A normalized vocabulary item paired with its grammar clue.
class CrosswordCandidate {
  const CrosswordCandidate({required this.word, required this.type});

  final String word;
  final String type;
}

/// A crossword candidate assigned an ID, origin, and direction on the grid.
class CrosswordPlacedWord {
  const CrosswordPlacedWord({
    required this.id,
    required this.word,
    required this.type,
    required this.row,
    required this.col,
    required this.isAcross,
  });

  final int id;
  final String word;
  final String type;
  final int row;
  final int col;
  final bool isAcross;

  String get directionLabel => isAcross ? 'Across' : 'Down';
}

/// Crossword output plus indexes for rendering cells and resolving crossings.
class CrosswordPuzzle {
  const CrosswordPuzzle({
    required this.placedWords,
    required this.letters,
    required this.wordIdsByCell,
  });

  final List<CrosswordPlacedWord> placedWords;
  final Map<String, String> letters;
  final Map<String, Set<int>> wordIdsByCell;

  /// Returns the placed word with [id], or null when it is unknown.
  CrosswordPlacedWord? wordById(int id) {
    for (final word in placedWords) {
      if (word.id == id) {
        return word;
      }
    }
    return null;
  }
}
