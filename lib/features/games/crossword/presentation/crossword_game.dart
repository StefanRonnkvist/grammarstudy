import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/crossword_models.dart';
import '../domain/crossword_generator.dart';
import '../domain/crossword_navigation.dart';
import '../../presentation/game_scoreboard.dart';
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
  int _correctValues = 0;
  int _incorrectValues = 0;
  final Set<int> _scoredWordIds = <int>{};

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
      _scoredWordIds.clear();
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
  /// A square that belongs to both an Across and a Down word shares one clue
  /// number with both, so the player is asked which one to answer. A square
  /// that belongs to the clue already being typed keeps that clue, so working
  /// along a word is never interrupted.
  void _selectCell(String key) {
    final puzzle = _puzzle;
    if (puzzle == null) {
      setState(() {
        _selectedCellKey = key;
        _activeWordId = null;
      });
      _showFieldForActiveWord();
      return;
    }

    final cellWordIds = puzzle.wordIdsByCell[key] ?? const <int>{};
    final continuesCurrentClue = cellWordIds.contains(_activeWordId);

    if (cellWordIds.length > 1 && !continuesCurrentClue) {
      setState(() {
        _selectedCellKey = key;
      });
      _inputFocusNode.requestFocus();
      _askWhichClueToAnswer(key);
      return;
    }

    final activeWord = activeWordForCell(
      puzzle,
      key,
      preferredWordId: _activeWordId,
    );
    setState(() {
      _selectedCellKey = key;
      _activeWordId = activeWord?.id;
    });
    _showFieldForActiveWord();
    _inputFocusNode.requestFocus();
  }

  /// Asks the player which of the clues sharing [key] should be answered.
  Future<void> _askWhichClueToAnswer(String key) async {
    final puzzle = _puzzle;
    if (puzzle == null) {
      return;
    }

    await showCellWordPickerDialog(
      context,
      puzzle: puzzle,
      cellWordIds: puzzle.wordIdsByCell[key] ?? const <int>{},
      startNumberByWordId: buildStartNumberByWordId(
        puzzle,
        buildClueNumbersByCell(puzzle),
      ),
      onWordSelected: (word) {
        setState(() {
          _activeWordId = word.id;
          _selectedCellKey = key;
        });
        _showFieldForActiveWord();
        _inputFocusNode.requestFocus();
      },
    );
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

  /// Builds the letter sequence for [word] as the player should see it.
  ///
  /// Every letter that is already correct self fills into the sequence, either
  /// because the player typed it correctly or because it comes from a revealed
  /// word, so the field always shows the green characters in place. Squares
  /// that are blank or hold a wrong letter stay open for typing.
  List<String?> _letterSequenceForWord(CrosswordPlacedWord word) {
    final puzzle = _puzzle;
    final letters = List<String?>.filled(word.word.length, null);
    if (puzzle == null) {
      return letters;
    }

    for (var index = 0; index < word.word.length; index++) {
      final key = cellKeyFor(
        word.row + (word.isAcross ? 0 : index),
        word.col + (word.isAcross ? index : 0),
      );
      final expected = puzzle.letters[key];
      if (expected == null) {
        continue;
      }

      final entered = _enteredLettersByCell[key];
      final isCorrect =
          entered != null && entered.toLowerCase() == expected.toLowerCase();
      if (isCorrect ||
          _revealedWordIds.contains(word.id) ||
          _isFixedBySettledWord(puzzle, word, key)) {
        letters[index] = expected.toUpperCase();
      }
    }

    return letters;
  }

  /// Returns the squares of [word] whose letter the player cannot type.
  ///
  /// A square is fixed when the letter belongs to another clue that is already
  /// settled, either because that clue was solved by the player or because it
  /// was revealed. Those letters must not be typed over or the crossing would
  /// break. Letters typed by the player for this word stay editable so a word
  /// can always be corrected.
  Set<String> _lockedCellsForWord(
    CrosswordPuzzle puzzle,
    CrosswordPlacedWord word,
  ) {
    final locked = <String>{};
    for (var index = 0; index < word.word.length; index++) {
      final key = cellKeyFor(
        word.row + (word.isAcross ? 0 : index),
        word.col + (word.isAcross ? index : 0),
      );
      final expected = puzzle.letters[key];
      if (expected == null) {
        continue;
      }

      // Every square of this word is fixed when the word was revealed.
      if (_revealedWordIds.contains(word.id)) {
        locked.add(key);
        continue;
      }

      // A square that takes its letter from another settled word is locked
      // even when the player has typed there, because overwriting it would
      // break the crossing. The correct letter is shown in its place.
      if (_isFixedBySettledWord(puzzle, word, key)) {
        locked.add(key);
        continue;
      }

      // A letter the player typed into a square of this word alone is correct
      // but still changeable, so the word can always be corrected.
      if (_enteredLettersByCell[key] != null) {
        continue;
      }
    }
    return locked;
  }

  /// Reports whether every square of [word] already holds a letter.
  bool _allCellsFilled(
    CrosswordPuzzle puzzle,
    CrosswordPlacedWord word, {
    Map<String, String>? letters,
  }) {
    final enteredLetters = letters ?? _enteredLettersByCell;
    for (var index = 0; index < word.word.length; index++) {
      final key = cellKeyFor(
        word.row + (word.isAcross ? 0 : index),
        word.col + (word.isAcross ? index : 0),
      );
      final entered = enteredLetters[key];
      if ((entered == null || entered == '_') &&
          !_revealedWordIds.contains(word.id)) {
        return false;
      }
    }
    return true;
  }

  /// Reports whether [key] takes its letter from another settled clue.
  ///
  /// A revealed or solved crossing word fixes the letter in its squares, so the
  /// letter shows in the field without the player typing it again.
  bool _isFixedBySettledWord(
    CrosswordPuzzle puzzle,
    CrosswordPlacedWord word,
    String key,
  ) {
    return (puzzle.wordIdsByCell[key] ?? const <int>{}).any((id) {
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
  }

  /// Rebuilds the entry field as the clue's masked word.
  ///
  /// Known letters are shown in place and unknown squares show `_`, so the
  /// field always reads like the clue with the correct characters filled in.
  /// The caret moves to the next square the player can type into, so typing
  /// walks along the clue and a visible crossing letter is stepped over rather
  /// than typed over.
  void _writeFieldForSequence(
    List<String?> sequence, {
    Set<String> lockedCells = const <String>{},
    List<String> keys = const <String>[],
  }) {
    final text = sequence.map((letter) => letter ?? '_').join();
    final lockedIndexes = <int>{
      for (var index = 0; index < keys.length; index++)
        if (lockedCells.contains(keys[index])) index,
    };
    final caret = nextTypingIndex(sequence, lockedIndexes: lockedIndexes);

    _isSyncingField = true;
    _inputController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: caret.clamp(0, text.length)),
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

    // Correct letters are shown in the sequence so the field matches the green
    // characters on the board, but only the letters the player did not type
    // here are fixed. A typed letter can still be replaced, which is what keeps
    // a word from becoming impossible to correct.
    final shown = _letterSequenceForWord(activeWord);
    final lockedCells = _lockedCellsForWord(puzzle, activeWord);
    final keys = <String>[
      for (var index = 0; index < length; index++)
        cellKeyFor(
          activeWord.row + (activeWord.isAcross ? 0 : index),
          activeWord.col + (activeWord.isAcross ? index : 0),
        ),
    ];
    final characters = value.characters.toList(growable: false);

    // The field always carries one character per square, `_` marking a square
    // the player has not typed yet. Reading it positionally is what keeps a
    // crossing letter anchored to its own square, so it is never mistaken for
    // typed input and nothing shifts along it.
    final fieldCharacters = <String>[
      for (var index = 0; index < length; index++)
        index < characters.length ? characters[index] : '_',
    ];
    final sequence = resolveClueLettersFromField(
      lockedLetters: [
        for (var index = 0; index < length; index++)
          lockedCells.contains(keys[index]) ? shown[index] : null,
      ],
      shownLetters: shown,
      existingLetters: [
        for (var index = 0; index < length; index++)
          _enteredLettersByCell[keys[index]]?.toUpperCase(),
      ],
      fieldCharacters: fieldCharacters,
    );

    final entered = Map<String, String>.from(_enteredLettersByCell);
    for (var index = 0; index < sequence.length; index++) {
      final letter = sequence[index];
      if (letter == null) {
        entered.remove(keys[index]);
        continue;
      }
      entered[keys[index]] = letter;
    }

    final isComplete = _allCellsFilled(puzzle, activeWord, letters: entered);
    var correctValues = 0;
    var incorrectValues = 0;
    if (isComplete &&
        !_scoredWordIds.contains(activeWord.id) &&
        !_revealedWordIds.contains(activeWord.id)) {
      for (var index = 0; index < activeWord.word.length; index++) {
        final key = keys[index];
        final value = entered[key];
        if (value == null) {
          continue;
        }
        if (value.toLowerCase() == puzzle.letters[key]?.toLowerCase()) {
          correctValues++;
        } else {
          incorrectValues++;
        }
      }
    }

    setState(() {
      _enteredLettersByCell = entered;
      _selectedCellKey ??= cellKeyFor(activeWord.row, activeWord.col);
      if (isComplete &&
          !_revealedWordIds.contains(activeWord.id) &&
          (correctValues + incorrectValues) > 0) {
        _scoredWordIds.add(activeWord.id);
      }
      _correctValues += correctValues;
      _incorrectValues += incorrectValues;
    });

    // Rewrite the field so the known letters stay visible in sequence and the
    // caret returns to the first blank, ready for the next character.
    _writeFieldForSequence(sequence, lockedCells: lockedCells, keys: keys);
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

    // Entered letters are only graded once every square of the clue is filled.
    final isActiveWordComplete =
        activeWord != null && _allCellsFilled(puzzle, activeWord);
    final startNumbersByCellKey = <String, int>{
      for (final word in puzzle.placedWords)
        cellKeyFor(word.row, word.col): startNumbers[word.id] ?? 0,
    };

    return Column(
      children: [
        GameScoreboard(
          correctValues: _correctValues,
          incorrectValues: _incorrectValues,
        ),
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
                  isActiveWordComplete: isActiveWordComplete,
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
                        children: [buildGrid(), controlsCard],
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
