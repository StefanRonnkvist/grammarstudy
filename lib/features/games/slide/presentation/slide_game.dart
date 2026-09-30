import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/text/text_utils.dart';
import '../../../../core/widgets/dialog_views.dart';
import '../../crossword/domain/crossword_models.dart';
import '../domain/slide_models.dart';
import '../domain/slide_logic.dart';

/// Hosts the Slide game: drag letter columns to spell the target word.
class SlideGame extends StatefulWidget {
  const SlideGame({
    super.key,
    required this.candidates,
    required this.sentences,
    required this.definitionsByWordType,
  });

  final List<CrosswordCandidate> candidates;
  final List<String> sentences;
  final Map<String, String> definitionsByWordType;

  @override
  State<SlideGame> createState() => _SlideGameState();
}

class _SlideGameState extends State<SlideGame> {
  static const double _horizontalGap = 10;
  static const double _typeLabelWidth = 140;
  static const double _typeLabelGap = 12;

  final math.Random _random = math.Random();

  SlideBoard _board = const SlideBoard(
    word: '',
    wordType: '',
    letters: [],
    revealedLetters: [],
    verticalWords: [],
    correctLetters: 0,
    isComplete: false,
    hasSubmitted: false,
  );

  double _topLaneHeight = 0;
  double _squareSize = 0;
  double _letterHeight = 0;

  @override
  void initState() {
    super.initState();
    _newWord();
  }

  void _newWord() {
    setState(() {
      _board = generateSlideBoard(widget.candidates, _random);
    });
  }

  void _onColumnDragged(int index, double delta) {
    setState(() {
      _board = dragSlideColumn(_board, index, delta);
    });
  }

  void _onColumnSnapped(int index) {
    setState(() {
      _board = snapSlideColumn(
        _board,
        index,
        letterHeight: _letterHeight,
        squareSize: _squareSize,
      );
    });
  }

  void _submit() {
    setState(() {
      _board = evaluateSlideBoard(
        _board,
        topLaneHeight: _topLaneHeight,
        squareSize: _squareSize,
        letterHeight: _letterHeight,
      );
    });
  }

  Future<void> _showWordTypeDefinition() async {
    if (!mounted) {
      return;
    }
    await showWordTypeDefinitionDialog(
      context,
      wordType: _board.wordType,
      definition: _definitionForBoard(),
    );
  }

  String? _definitionForBoard() {
    final normalized = _board.wordType.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    return widget.definitionsByWordType[normalized];
  }

  Future<void> _showSentenceHint() async {
    if (!mounted || !_board.hasWord) {
      return;
    }
    await showMessageDialog(
      context,
      title: 'Slide Hint',
      message:
          'Word type: ${_board.wordType}\n\nSentence hint:\n'
          '${findSentenceForWord(_board.word.toLowerCase(), widget.sentences)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (!_board.hasWord) {
                return const Center(child: Text('No slide word available.'));
              }
              return _buildBoard(constraints);
            },
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton.tonalIcon(
              onPressed: _showSentenceHint,
              icon: const Icon(Icons.lightbulb_outline),
              label: const Text('Hint'),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.task_alt),
              label: const Text('Submit'),
            ),
            const SizedBox(width: 12),
            FilledButton.tonalIcon(
              onPressed: _newWord,
              icon: const Icon(Icons.shuffle),
              label: const Text('New Word'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_board.hasSubmitted)
          Center(
            child: Text(
              'Correct letters: ${_board.correctLetters}/${_board.letters.length}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        if (_board.isSolved)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Complete! ✓',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.headlineMedium?.copyWith(color: Colors.green),
              ),
            ),
          ),
      ],
    );
  }

  /// Sizes the board to the available space and renders draggable columns.
  Widget _buildBoard(BoxConstraints constraints) {
    final availableHeight = constraints.maxHeight - 50;
    final availableWidth = constraints.maxWidth - 20;
    final columnCount = _board.letters.length;
    final numColumns = columnCount.toDouble();

    final showTypeLabel = _board.wordType.trim().isNotEmpty;
    final maxAboveLetters = longestColumnAbove(_board);
    final maxBelowLetters = longestColumnBelow(_board);
    final totalGapsWidth = math.max(0, columnCount - 1) * _horizontalGap;
    final widthBasedSquare = (availableWidth - totalGapsWidth) / numColumns;
    final heightFactor = 1 + (maxAboveLetters + maxBelowLetters);
    final heightBasedSquare = availableHeight / math.max(1.0, heightFactor);
    final squareSize = math
        .min(widthBasedSquare, heightBasedSquare)
        .clamp(12.0, 64.0);
    final contentWidth = (columnCount * squareSize) + totalGapsWidth;
    final typeLabelTotalWidth = showTypeLabel
        ? _typeLabelWidth + _typeLabelGap
        : 0.0;
    final boardContentWidth = math.max(
      availableWidth,
      contentWidth + typeLabelTotalWidth,
    );

    final topLaneHeight = squareSize * math.max(1, maxAboveLetters);
    final bottomLaneHeight = squareSize * math.max(1, maxBelowLetters);
    final fontSize = (squareSize * 0.35).clamp(8.0, 18.0);

    _topLaneHeight = topLaneHeight;
    _squareSize = squareSize;
    _letterHeight = squareSize;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final tileBorderColor = colorScheme.primary;
    final tileFillColor = isDark
        ? colorScheme.primaryContainer.withValues(alpha: 0.55)
        : Colors.blue.shade50;
    final tileTextColor = isDark
        ? colorScheme.onPrimaryContainer
        : Colors.blueGrey.shade900;
    final revealedBorderColor = isDark
        ? Colors.lightGreenAccent.shade400
        : Colors.green;
    final revealedFillColor = isDark
        ? Colors.green.shade900.withValues(alpha: 0.45)
        : Colors.green.shade50;
    final revealedTextColor = isDark
        ? Colors.green.shade100
        : Colors.green.shade900;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: boardContentWidth,
            child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (showTypeLabel)
                  SizedBox(
                    width: _typeLabelWidth,
                    height: topLaneHeight + squareSize + bottomLaneHeight,
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: InkWell(
                          onTap: _showWordTypeDefinition,
                          borderRadius: BorderRadius.circular(4),
                          child: Text(
                            _board.wordType,
                            textAlign: TextAlign.right,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colorScheme.primary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (showTypeLabel) const SizedBox(width: _typeLabelGap),
                for (var hIndex = 0; hIndex < _board.letters.length; hIndex++)
                  Padding(
                    padding: EdgeInsets.only(
                      right: hIndex == _board.letters.length - 1
                          ? 0
                          : _horizontalGap,
                    ),
                    child: _buildColumn(
                      hIndex: hIndex,
                      squareSize: squareSize,
                      topLaneHeight: topLaneHeight,
                      bottomLaneHeight: bottomLaneHeight,
                      letterHeight: squareSize,
                      fontSize: fontSize,
                      tileBorderColor: tileBorderColor,
                      tileFillColor: tileFillColor,
                      tileTextColor: tileTextColor,
                      revealedBorderColor: revealedBorderColor,
                      revealedFillColor: revealedFillColor,
                      revealedTextColor: revealedTextColor,
                      outlineColor: colorScheme.outline,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Renders one target square plus its draggable vertical letter column.
  Widget _buildColumn({
    required int hIndex,
    required double squareSize,
    required double topLaneHeight,
    required double bottomLaneHeight,
    required double letterHeight,
    required double fontSize,
    required Color tileBorderColor,
    required Color tileFillColor,
    required Color tileTextColor,
    required Color revealedBorderColor,
    required Color revealedFillColor,
    required Color revealedTextColor,
    required Color outlineColor,
  }) {
    final column = columnAt(_board, hIndex);
    final columnIndex = column == null
        ? -1
        : _board.verticalWords.indexOf(column);
    final isRevealed = _board.hasSubmitted && _board.revealedLetters[hIndex];
    final canDrag = column != null && !isRevealed;
    final columnHeight = topLaneHeight + squareSize + bottomLaneHeight;

    return GestureDetector(
      onVerticalDragUpdate: canDrag
          ? (details) => _onColumnDragged(columnIndex, details.delta.dy)
          : null,
      onVerticalDragEnd: canDrag ? (_) => _onColumnSnapped(columnIndex) : null,
      child: SizedBox(
        width: squareSize,
        height: columnHeight,
        child: ClipRect(
          child: Stack(
            children: [
              if (column != null && !isRevealed)
                Transform.translate(
                  offset: Offset(0, column.verticalOffset),
                  child: SizedBox(
                    width: squareSize,
                    height: letterHeight * column.word.length,
                    child: Stack(
                      children: [
                        for (
                          var letterIdx = 0;
                          letterIdx < column.word.length;
                          letterIdx++
                        )
                          Positioned(
                            top: letterHeight * letterIdx,
                            left: 0,
                            child: Container(
                              width: squareSize,
                              height: letterHeight,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: tileBorderColor,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(4),
                                color: tileFillColor,
                              ),
                              child: Center(
                                child: Text(
                                  column.word[letterIdx],
                                  style: TextStyle(
                                    fontSize: fontSize,
                                    fontWeight: FontWeight.bold,
                                    color: tileTextColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              Positioned(
                top: topLaneHeight,
                left: 0,
                child: Container(
                  width: squareSize,
                  height: squareSize,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isRevealed ? revealedBorderColor : outlineColor,
                      width: isRevealed ? 3 : 2,
                    ),
                    borderRadius: BorderRadius.circular(4),
                    color: isRevealed ? revealedFillColor : Colors.transparent,
                  ),
                  child: Center(
                    child: isRevealed
                        ? Text(
                            _board.letters[hIndex],
                            style: TextStyle(
                              fontSize: fontSize,
                              fontWeight: FontWeight.bold,
                              color: revealedTextColor,
                            ),
                          )
                        : const SizedBox(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
