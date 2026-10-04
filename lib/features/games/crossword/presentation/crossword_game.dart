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
  int? _activeWordId;
  bool _isSyncingField = false;

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
      _activeWordId = null;
      _isSyncingField = false;
    });

    if (puzzle.placedWords.length < crosswordTargetWordCount) {
      widget.showSnackBar?.call(
        'Could only place ${puzzle.placedWords.length} words with current constraints.',
      );
    }
  }

  /// Selects a cell and locks typing to the clue that runs through it.
  ///
  /// Crossing cells keep their current direction when it still runs through
  /// them, so a word can be typed end to end without the direction flipping
  /// mid-word. The field is rebuilt for the newly selected clue.
  void _selectCell(String key) {
    final puzzle = _puzzle;
    final activeWord = puzzle == null
        ? null
        : activeWordForCell(puzzle, key, preferredWordId: _activeWordId);
    setState(() {
      _selectedCellKey = key;
      _activeWordId = activeWord?.id;
    });
    _showFieldForActiveWord();
    _inputFocusNode.requestFocus();
  }

  /// Rewrites the entry field with the active clue's known letters and blanks.
  void _showFieldForActiveWord() {
    final puzzle = _puzzle;
    final activeWord = puzzle == null || _activeWordId == null
        ? null
        : puzzle.wordById(_activeWordId!);
    if (activeWord == null) {
      _writeFieldForSequence(const []);
      return;
    }
    _writeFieldForSequence(_letterSequenceForWord(activeWord));
  }

  /// Mirrors the letters of the active clue into the entry field so the word
  /// being typed stays visible while it fills the grid.
  ///
  /// Squares already known from crossing or revealed words are shown, so the
  /// field reads as the finished word with `_` where nothing is known yet.
  void _syncInputFieldToWord() {
    final puzzle = _puzzle;
    final activeWord = puzzle == null || _activeWordId == null
        ? null
        : puzzle.wordById(_activeWordId!);
    if (activeWord == null) {
      return;
    }

    _writeFieldForSequence(_letterSequenceForWord(activeWord));
  }

  /// Builds the letter sequence for [word], prefilled with the squares the
  /// player cannot type: the squares of a revealed word, and the squares of a
  /// different word that is already solved, whose letter the player does not
  /// need to enter again.
  ///
  /// Letters typed by the player are deliberately left blank here so typing
  /// always replaces them; a letter is never repeated no matter what is typed.
  List<String?> _letterSequenceForWord(CrosswordPlacedWord word) {
    final puzzle = _puzzle;
    final letters = List<String?>.filled(word.word.length, null);
    if (puzzle == null) {
      return letters;
    }

    final lockedCells = _lockedCellsForWord(puzzle, word);
    for (var index = 0; index < word.word.length; index++) {
      final key = cellKeyFor(
        word.row + (word.isAcross ? 0 : index),
        word.col + (word.isAcross ? index : 0),
      );
      if (lockedCells.contains(key)) {
        letters[index] = puzzle.letters[key]?.toUpperCase();
      }
    }

    return letters;
  }

  /// Returns the squares of [word] that already hold a letter the player does
  /// not type: every square of a revealed word, plus squares whose letter comes
  /// from another word that is already solved.
  Set<String> _lockedCellsForWord(
    CrosswordPuzzle puzzle,
    CrosswordPlacedWord word,
  ) {
    if (_revealedWordIds.contains(word.id)) {
      return {
        for (var index = 0; index < word.word.length; index++)
          cellKeyFor(
            word.row + (word.isAcross ? 0 : index),
            word.col + (word.isAcross ? index : 0),
          ),
      };
    }

    final locked = <String>{};
    for (var index = 0; index < word.word.length; index++) {
      final key = cellKeyFor(
        word.row + (word.isAcross ? 0 : index),
        word.col + (word.isAcross ? index : 0),
      );
      final entered = _enteredLettersByCell[key];
      if (entered == null ||
          entered.toLowerCase() != puzzle.letters[key]?.toLowerCase()) {
        continue;
      }

      final otherWordIds =
          (puzzle.wordIdsByCell[key] ?? const <int>{})..remove(word.id);
      final isSolvedByAnotherWord = otherWordIds.any((id) {
        if (id == word.id) {
          return false;
        }
        final other = puzzle.wordById(id);
        return other != null &&
            isWordCorrectlyAnswered(
              other,
              _enteredLettersByCell,
              _revealedWordIds,
            );
      });
      if (isSolvedByAnotherWord) {
        locked.add(key);
      }
    }
    return locked;
  }

  /// Rebuilds the entry field as the clue's masked word.
  ///
  /// Known letters are shown in place and unknown squares show `_`, so the
  /// field always reads like the clue with the correct characters filled in.
  /// The caret is parked on the first blank square so the next typed character
  /// lands in the right position.
  void _writeFieldForSequence(List<String?> sequence) {
    final text = sequence.map((letter) => letter ?? '_').join();
    final firstBlank = sequence.indexWhere((letter) => letter == null);
    _isSyncingField = true;
    _inputController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(
        offset: firstBlank == -1 ? text.length : firstBlank,
      ),
    );
    _isSyncingField = false;
  }

  /// Fills the active clue's squares from the text typed into the entry field.
  ///
  /// The field holds the clue in order: letters already known, from crossing or
  /// revealed words, stay locked in place and are re-inserted on every
  /// keystroke. The characters the player typed only occupy the remaining
  /// positions, so typing never overwrites a known letter and the grid mirrors
  /// the sequence exactly.
  void _onInputChanged(String value) {
    if (_isSyncingField) {
      return;
    }

    final puzzle = _puzzle;
    final activeWord = puzzle == null || _activeWordId == null
        ? null
        : puzzle.wordById(_activeWordId!);
    if (puzzle == null || activeWord == null) {
      return;
    }

    final length = activeWord.word.length;
    final known = _letterSequenceForWord(activeWord);

    // Known letters hold their position; everything typed fills the rest.
    final sequence = List<String?>.filled(length, null);
    final characters = value.characters.toList(growable: false);
    var typedIndex = 0;
    for (var index = 0; index < length; index++) {
      if (known[index] != null) {
        sequence[index] = known[index];
        continue;
      }
      if (typedIndex >= characters.length) {
        break;
      }
      final character = characters[typedIndex];
      if (RegExp(r'[a-zA-Z]').hasMatch(character)) {
        sequence[index] = character.toUpperCase();
      }
      typedIndex++;
    }

    final entered = Map<String, String>.from(_enteredLettersByCell);
    for (var index = 0; index < sequence.length; index++) {
      final key = cellKeyFor(
        activeWord.row + (activeWord.isAcross ? 0 : index),
        activeWord.col + (activeWord.isAcross ? index : 0),
      );
      final letter = sequence[index];
      if (letter == null) {
        entered.remove(key);
        continue;
      }
      entered[key] = letter;
    }

    setState(() {
      _enteredLettersByCell = entered;
      _selectedCellKey ??= cellKeyFor(activeWord.row, activeWord.col);
    });

    // Rewrite the field so the known letters stay visible in sequence and the
    // caret returns to the first blank, ready for the next character.
    _writeFieldForSequence(sequence);
    _inputFocusNode.requestFocus();
  }

  /// Clears the letters typed into the active clue, leaving the correct letters
  /// that came from crossing or revealed words in place.
  void _clearSelectedCell() {
    final puzzle = _puzzle;
    final activeWord = puzzle == null || _activeWordId == null
        ? null
        : puzzle.wordById(_activeWordId!);
    final selected = _selectedCellKey;
    final word = activeWord;
    if (puzzle == null || word == null) {
      if (selected == null) {
        return;
      }
      setState(() {
        _enteredLettersByCell = Map<String, String>.from(_enteredLettersByCell)
          ..remove(selected);
      });
      _writeFieldForSequence(const []);
      return;
    }

    setState(() {
      final entered = Map<String, String>.from(_enteredLettersByCell);
      for (var index = 0; index < word.word.length; index++) {
        final key = cellKeyFor(
          word.row + (word.isAcross ? 0 : index),
          word.col + (word.isAcross ? index : 0),
        );
        if (!_isCorrectLetterIn(puzzle, key)) {
          entered.remove(key);
        }
      }
      _enteredLettersByCell = entered;
    });
    _syncInputFieldToWord();
    _inputFocusNode.requestFocus();
  }

  /// Reports whether [key] holds the letter the puzzle expects there.
  bool _isCorrectLetterIn(CrosswordPuzzle puzzle, String key) {
    final entered = _enteredLettersByCell[key];
    return entered != null &&
        entered.toLowerCase() == puzzle.letters[key]?.toLowerCase();
  }

  void _revealWord(CrosswordPlacedWord word) {
    setState(() {
      _revealedWordIds = {..._revealedWordIds, word.id};
    });
    _syncInputFieldToWord();
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
    final activeWord = puzzle.wordById(_activeWordId ?? -1);
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
                  activeWordId: _activeWordId,
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
                activeWordLabel: activeWord == null
                    ? null
                    : '${startNumbers[activeWord.id] ?? 0} '
                          '${activeWord.directionLabel} · ${activeWord.word.length} letters',
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
