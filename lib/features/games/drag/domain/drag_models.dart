/// Data model for the Drag game.
library;

/// Display sentence and unique annotation targets for one drag-game round.
class DragRound {
  const DragRound({required this.sentence, required this.removedWords});

  final String sentence;
  final List<String> removedWords;
}

/// A visible sentence token with the optional tag that follows it in source.
class DragSentenceToken {
  const DragSentenceToken({
    required this.display,
    required this.normalized,
    this.expectedParentheticalNormalized,
  });

  final String display;
  final String normalized;
  final String? expectedParentheticalNormalized;
}

/// Identifies a dragged token independently of duplicate display text.
class DragWordPayload {
  const DragWordPayload({
    required this.tokenIndex,
    required this.display,
    required this.normalized,
  });

  final int tokenIndex;
  final String display;
  final String normalized;
}

/// Palette of target colours cycled across a drag round.
const List<int> dragTargetPalette = <int>[
  0xFF1565C0,
  0xFF2E7D32,
  0xFF6A1B9A,
  0xFFEF6C00,
  0xFF00838F,
  0xFF5D4037,
  0xFF7B1FA2,
  0xFF0277BD,
  0xFF558B2F,
  0xFF00897B,
  0xFF3949AB,
  0xFFC0CA33,
];
