import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/text/text_utils.dart';
import '../domain/crossword_generator.dart';
import '../domain/crossword_models.dart';
import '../domain/crossword_navigation.dart';

/// Renders the interactive crossword grid.
///
/// Tapping a cell selects it; tapping the selected cell again opens the
/// sentence hint for the word that occupies it.
class CrosswordGrid extends StatelessWidget {
  const CrosswordGrid({
    super.key,
    required this.puzzle,
    required this.enteredLettersByCell,
    required this.revealedWordIds,
    required this.selectedCellKey,
    required this.activeWordId,
    required this.isActiveWordComplete,
    required this.startNumberByWordId,
    required this.startNumberByCellKey,
    required this.onCellTapped,
    required this.onSelectedCellTapped,
  });

  final CrosswordPuzzle puzzle;
  final Map<String, String> enteredLettersByCell;
  final Set<int> revealedWordIds;
  final String? selectedCellKey;
  /// Word whose squares typing currently fills, highlighted on the board.
  final int? activeWordId;

  /// Whether every square of [activeWordId] has a letter.
  ///
  /// Entered letters stay blue until the whole clue is filled, then turn green
  /// or red according to whether they match the puzzle.
  final bool isActiveWordComplete;
  final Map<int, int> startNumberByWordId;
  final Map<String, int> startNumberByCellKey;
  final ValueChanged<String> onCellTapped;
  final ValueChanged<String> onSelectedCellTapped;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final defaultCellBorderColor = colorScheme.outline;
    final defaultCellFillColor = isDark
        ? colorScheme.surfaceContainer
        : colorScheme.surfaceContainerHighest;
    final cellNumberColor = colorScheme.onSurfaceVariant;
    final enteredCorrectColor = isDark
        ? Colors.lightGreenAccent.shade400
        : Colors.green.shade800;
    final enteredWrongColor = isDark
        ? Colors.red.shade300
        : Colors.red.shade800;
    // An entered letter is blue while the clue is still being filled in, so
    // the colour only reports right or wrong once the whole clue is typed.
    final enteredPendingColor = isDark
        ? Colors.lightBlueAccent.shade200
        : Colors.blue.shade800;

    return Center(
      child: AspectRatio(
        aspectRatio: 1,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: crosswordGridSize * crosswordGridSize,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crosswordGridSize,
          ),
          itemBuilder: (context, index) {
            final row = index ~/ crosswordGridSize;
            final col = index % crosswordGridSize;
            final key = cellKeyFor(row, col);
            final letter = puzzle.letters[key];

            if (letter == null) {
              return const SizedBox.shrink();
            }

            final cellWordIds = puzzle.wordIdsByCell[key] ?? <int>{};
            final isActiveWord = activeWordId != null && cellWordIds.contains(activeWordId);
            final isRevealed = cellWordIds.any(revealedWordIds.contains);
            final enteredLetter = enteredLettersByCell[key];
            final isSelected = selectedCellKey == key;
            final number = startNumberByCellKey[key];
            final displayLetter = isRevealed
                ? letter.toUpperCase()
                : (enteredLetter ?? '');
            final isCorrectEntry =
                enteredLetter != null &&
                enteredLetter.toLowerCase() == letter.toLowerCase();
            final enteredColor =
                isCorrectEntry ? enteredCorrectColor : enteredWrongColor;
            final letterColor = isRevealed
                ? colorScheme.onSurface
                : enteredLetter == null
                ? colorScheme.onSurface
                : isActiveWord && !isActiveWordComplete
                ? enteredPendingColor
                : enteredColor;

            return GestureDetector(
              onTap: () {
                if (selectedCellKey == key) {
                  onSelectedCellTapped(key);
                  return;
                }
                onCellTapped(key);
              },
              child: Container(
                margin: const EdgeInsets.all(1),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isSelected
                        ? colorScheme.primary
                        : defaultCellBorderColor,
                    width: isSelected ? 2 : 1,
                  ),
                  color: isSelected || isActiveWord
                      ? colorScheme.primary.withValues(alpha: isSelected ? 0.16 : 0.08)
                      : defaultCellFillColor,
                ),
                child: Stack(
                  children: [
                    if (number != null)
                      Positioned(
                        left: 2,
                        top: 1,
                        child: Text(
                          '$number',
                          style: TextStyle(fontSize: 8, color: cellNumberColor),
                        ),
                      ),
                    Center(
                      child: Text(
                        displayLetter,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: letterColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Builds the `row:column` key for a grid coordinate.
///
/// Re-exported so the grid view can build cell keys without importing the
/// generator, keeping one definition of the key format.
String cellKeyFor(int row, int col) => cellKey(row, col);

/// Renders the letter entry field, clear action, and selection message.
class CrosswordInputCard extends StatelessWidget {
  const CrosswordInputCard({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.selectedCellKey,
    required this.activeWordLabel,
    required this.onInputChanged,
    required this.onClearCell,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String? selectedCellKey;
  /// Clue text shown while typing, describing the squares being filled.
  final String? activeWordLabel;
  final ValueChanged<String> onInputChanged;
  final VoidCallback onClearCell;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    selectedCellKey == null
                        ? 'Tap a crossword cell to enter letters. '
                              'Tap the same cell again for its sentence hint.'
                        : 'Typing into: $activeWordLabel',
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: selectedCellKey == null ? null : onClearCell,
                  icon: const Icon(Icons.backspace_outlined),
                  label: const Text('Clear Cell'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: selectedCellKey != null,
              maxLength: null,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z_]')),
              ],
              onChanged: onInputChanged,
              decoration: const InputDecoration(
                hintText: 'Type the letters for this clue',
                prefixIcon: Icon(Icons.keyboard),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders the clue list; tapping a clue opens its sentence hint.
class CrosswordClueList extends StatelessWidget {
  const CrosswordClueList({
    super.key,
    required this.puzzle,
    required this.enteredLettersByCell,
    required this.revealedWordIds,
    required this.startNumberByWordId,
    required this.onClueTapped,
    this.shrinkWrap = true,
    this.physics = const NeverScrollableScrollPhysics(),
  });

  final CrosswordPuzzle puzzle;
  final Map<String, String> enteredLettersByCell;
  final Set<int> revealedWordIds;
  final Map<int, int> startNumberByWordId;
  final ValueChanged<CrosswordPlacedWord> onClueTapped;

  /// Whether the list sizes to its content instead of filling the viewport.
  ///
  /// Narrow layouts place this inside a scroll view and must shrink-wrap,
  /// while the wide two-pane layout gives it a bounded column to scroll.
  final bool shrinkWrap;
  final ScrollPhysics physics;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: shrinkWrap,
      physics: physics,
      itemCount: puzzle.placedWords.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final word = puzzle.placedWords[index];
        final number = startNumberByWordId[word.id] ?? 0;
        final isRevealed = revealedWordIds.contains(word.id);
        final isCorrect = isWordCorrectlyAnswered(
          word,
          enteredLettersByCell,
          revealedWordIds,
        );
        return ListTile(
          dense: true,
          onTap: () => onClueTapped(word),
          title: Text(
            '$number. ${word.directionLabel} • ${word.word.length} letters',
          ),
          subtitle: Text(
            'Type hint: ${word.type}'
            '${isRevealed ? ' • ${word.word.toUpperCase()}' : ''}',
          ),
          trailing: isCorrect
              ? Icon(Icons.check_circle, color: Colors.green.shade700)
              : const Icon(Icons.chat_bubble_outline),
        );
      },
    );
  }
}

/// Shows the word type, a sentence hint, and the option to reveal the word.
Future<void> showCrosswordClueDialog(
  BuildContext context, {
  required CrosswordPlacedWord word,
  required int number,
  required String sentence,
  required VoidCallback onReveal,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text('Clue $number • ${word.directionLabel}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Word type: ${word.type}'),
            const SizedBox(height: 8),
            const Text('Sentence hint:'),
            const SizedBox(height: 6),
            Text(sentence),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
          FilledButton.tonal(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onReveal();
            },
            child: const Text('Reveal Word'),
          ),
        ],
      );
    },
  );
}

/// Summarizes every word in the puzzle with a masked letter pattern.
Future<void> showCrosswordHintsDialog(
  BuildContext context, {
  required CrosswordPuzzle puzzle,
  required Map<String, String> enteredLettersByCell,
  required Set<int> revealedWordIds,
  required Map<int, int> startNumberByWordId,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Crossword Hints'),
        content: SizedBox(
          width: 360,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: puzzle.placedWords.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final word = puzzle.placedWords[index];
              final number = startNumberByWordId[word.id] ?? 0;
              return ListTile(
                dense: true,
                title: Text(
                  '$number. ${word.directionLabel} • ${word.word.length} letters',
                ),
                subtitle: Text(
                  'Hidden word: ${hiddenWordPattern(word, enteredLettersByCell, revealedWordIds)}\n'
                  'Type: ${word.type}',
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}

/// Lets the player pick which intersecting word to get a hint for.
Future<void> showCellWordPickerDialog(
  BuildContext context, {
  required CrosswordPuzzle puzzle,
  required Set<int> cellWordIds,
  required Map<int, int> startNumberByWordId,
  required ValueChanged<CrosswordPlacedWord> onWordSelected,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Choose a word'),
        content: SizedBox(
          width: 320,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final id in cellWordIds)
                ListTile(
                  dense: true,
                  onTap: () {
                    Navigator.of(dialogContext).pop();
                    final word = puzzle.wordById(id);
                    if (word != null) {
                      onWordSelected(word);
                    }
                  },
                  leading: CircleAvatar(
                    radius: 14,
                    child: Text('${startNumberByWordId[id] ?? 0}'),
                  ),
                  title: Text(
                    '${puzzle.wordById(id)?.directionLabel ?? ''} • '
                    '${puzzle.wordById(id)?.type ?? ''}',
                  ),
                  subtitle: Text(
                    '${puzzle.wordById(id)?.word.length ?? 0} letters',
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
        ],
      );
    },
  );
}

/// Finds a sentence hint for [word] from the plain sentence collection.
String crosswordSentenceHint(String word, List<String> sentences) {
  return findSentenceForWord(word, sentences);
}
