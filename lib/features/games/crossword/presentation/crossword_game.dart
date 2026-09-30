import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/crossword_models.dart';
import '../domain/crossword_generator.dart';
import '../domain/crossword_navigation.dart';
import 'crossword_views.dart';

/// Hosts the Crossword game: grid, letter entry, and clue list.
///
/// Puzzles are generated from grammar vocabulary, so the game works offline and
/// the clue for each word is its grammar category.
class CrosswordGame extends StatefulWidget {
  const CrosswordGame({
    super.key,
    required this.candidates,
    required this.sentences,
    this.showSnackBar,
  });

  final List<CrosswordCandidate> candidates;
  final List<String> sentences;
  final void Function(String message)? showSnackBar;

  @override
  State<CrosswordGame> createState() => _CrosswordGameState();
}

class _CrosswordGameState extends State<CrosswordGame> {
  final math.Random _random = math.Random();
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();

  CrosswordPuzzle? _puzzle;
  List<CrosswordCandidate> _candidates = const [];
  Map<String, String> _enteredLettersByCell = <String, String>{};
  Set<int> _revealedWordIds = <int>{};
  String? _selectedCellKey;

  @override
  void initState() {
    super.initState();
    _candidates = widget.candidates;
    _generatePuzzle();
  }

  @override
  void didUpdateWidget(CrosswordGame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.candidates, widget.candidates)) {
      setState(() {
        _candidates = widget.candidates;
      });
      _generatePuzzle();
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _generatePuzzle() {
    final puzzle = generateCrosswordPuzzle(_candidates, _random);
    if (puzzle == null || !mounted) {
      return;
    }

    setState(() {
      _puzzle = puzzle;
      _revealedWordIds = <int>{};
      _enteredLettersByCell = <String, String>{};
      _selectedCellKey = null;
    });

    if (puzzle.placedWords.length < crosswordTargetWordCount) {
      widget.showSnackBar?.call(
        'Could only place ${puzzle.placedWords.length} words with current constraints.',
      );
    }
  }

  void _selectCell(String key) {
    setState(() {
      _selectedCellKey = key;
    });
    _inputController.clear();
    _inputFocusNode.requestFocus();
  }

  void _onInputChanged(String value) {
    final selected = _selectedCellKey;
    final puzzle = _puzzle;
    if (selected == null || value.isEmpty || puzzle == null) {
      return;
    }

    final letter = value.characters.last.toUpperCase();
    final nextCellKey = nextCellKeyAfterEntry(puzzle, selected);
    setState(() {
      _enteredLettersByCell = {..._enteredLettersByCell, selected: letter};
      _selectedCellKey = nextCellKey ?? selected;
    });
    _inputController.clear();
    _inputFocusNode.requestFocus();
  }

  void _clearSelectedCell() {
    final selected = _selectedCellKey;
    if (selected == null) {
      return;
    }

    setState(() {
      _enteredLettersByCell = Map<String, String>.from(_enteredLettersByCell)
        ..remove(selected);
    });
    _inputController.clear();
    _inputFocusNode.requestFocus();
  }

  void _revealWord(CrosswordPlacedWord word) {
    setState(() {
      _revealedWordIds = {..._revealedWordIds, word.id};
    });
  }

  Future<void> _showClueForWord(CrosswordPlacedWord word) async {
    if (!mounted) {
      return;
    }
    final number = _puzzle == null
        ? 0
        : buildStartNumberByWordId(
                _puzzle!,
                buildClueNumbersByCell(_puzzle!),
              )[word.id] ??
              0;

    await showCrosswordClueDialog(
      context,
      word: word,
      number: number,
      sentence: crosswordSentenceHint(word.word, widget.sentences),
      onReveal: () => _revealWord(word),
    );
  }

  Future<void> _showClueForCell(String key) async {
    final puzzle = _puzzle;
    if (puzzle == null) {
      return;
    }

    final cellWordIds = puzzle.wordIdsByCell[key] ?? const <int>{};
    if (cellWordIds.isEmpty) {
      return;
    }

    if (cellWordIds.length == 1) {
      final word = puzzle.wordById(cellWordIds.first);
      if (word != null) {
        await _showClueForWord(word);
      }
      return;
    }

    final startNumbers = buildStartNumberByWordId(
      puzzle,
      buildClueNumbersByCell(puzzle),
    );
    await showCellWordPickerDialog(
      context,
      puzzle: puzzle,
      cellWordIds: cellWordIds,
      startNumberByWordId: startNumbers,
      onWordSelected: _showClueForWord,
    );
  }

  @override
  Widget build(BuildContext context) {
    final puzzle = _puzzle;
    if (puzzle == null || puzzle.placedWords.isEmpty) {
      return const Center(child: Text('No crossword words available.'));
    }

    final clueNumbers = buildClueNumbersByCell(puzzle);
    final startNumbers = buildStartNumberByWordId(puzzle, clueNumbers);
    final startNumbersByCellKey = <String, int>{
      for (final word in puzzle.placedWords)
        cellKeyFor(word.row, word.col): startNumbers[word.id] ?? 0,
    };

    return Column(
      children: [
        Row(
          children: [
            const Expanded(child: SizedBox.shrink()),
            OutlinedButton.icon(
              onPressed: () => showCrosswordHintsDialog(
                context,
                puzzle: puzzle,
                enteredLettersByCell: _enteredLettersByCell,
                revealedWordIds: _revealedWordIds,
                startNumberByWordId: startNumbers,
              ),
              icon: const Icon(Icons.lightbulb_outline),
              label: const Text('Hint'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _generatePuzzle,
              icon: const Icon(Icons.shuffle),
              label: const Text('New Puzzle'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              Widget buildGrid() {
                return CrosswordGrid(
                  puzzle: puzzle,
                  enteredLettersByCell: _enteredLettersByCell,
                  revealedWordIds: _revealedWordIds,
                  selectedCellKey: _selectedCellKey,
                  startNumberByWordId: startNumbers,
                  startNumberByCellKey: startNumbersByCellKey,
                  onCellTapped: _selectCell,
                  onSelectedCellTapped: _showClueForCell,
                );
              }

              final controlsCard = CrosswordInputCard(
                controller: _inputController,
                focusNode: _inputFocusNode,
                selectedCellKey: _selectedCellKey,
                onInputChanged: _onInputChanged,
                onClearCell: _clearSelectedCell,
              );

              Widget buildClues({required bool scrollable}) {
                return CrosswordClueList(
                  puzzle: puzzle,
                  enteredLettersByCell: _enteredLettersByCell,
                  revealedWordIds: _revealedWordIds,
                  startNumberByWordId: startNumbers,
                  onClueTapped: _showClueForWord,
                  shrinkWrap: !scrollable,
                  physics: scrollable
                      ? const ClampingScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
                );
              }

              if (constraints.maxWidth < 900) {
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      buildGrid(),
                      const SizedBox(height: 10),
                      controlsCard,
                      const SizedBox(height: 10),
                      Card(child: buildClues(scrollable: false)),
                    ],
                  ),
                );
              }

              return Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          buildGrid(),
                          const SizedBox(height: 10),
                          controlsCard,
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Card(child: buildClues(scrollable: true)),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
