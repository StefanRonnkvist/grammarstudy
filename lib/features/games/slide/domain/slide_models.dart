/// Data model for the Slide game.
library;

/// Mutable position and immutable identity for one slide-game letter column.
class SlideVerticalWord {
  SlideVerticalWord({
    required this.word,
    required this.horizontalIndex,
    required this.letterIndexInWord,
    required this.isAbove,
    required this.verticalOffset,
  });

  final String word;
  final int horizontalIndex;
  final int letterIndexInWord;
  final bool isAbove;
  double verticalOffset;
}

/// A Slide board: the target word, its columns, and reveal state.
class SlideBoard {
  const SlideBoard({
    required this.word,
    required this.wordType,
    required this.letters,
    required this.revealedLetters,
    required this.verticalWords,
    required this.correctLetters,
    required this.isComplete,
    required this.hasSubmitted,
  });

  final String word;
  final String wordType;
  final List<String> letters;
  final List<bool> revealedLetters;
  final List<SlideVerticalWord> verticalWords;
  final int correctLetters;
  final bool isComplete;
  final bool hasSubmitted;

  bool get hasWord => word.isNotEmpty;
  bool get isSolved =>
      hasSubmitted && isComplete && correctLetters == letters.length;
}
