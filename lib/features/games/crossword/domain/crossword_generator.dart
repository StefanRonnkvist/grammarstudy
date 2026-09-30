import 'dart:math' as math;

import '../../../../core/text/text_utils.dart';
import '../domain/crossword_models.dart';

/// Builds unique crossword candidates from grammar vocabulary.
///
/// Only alphabetic words of grid-friendly length are kept, and each retained
/// word remembers the grammar category it came from as its clue type.
Future<List<CrosswordCandidate>> buildCrosswordCandidates(
  Map<String, List<String>> valuesByType,
) async {
  final candidates = <CrosswordCandidate>[];
  final seenWords = <String>{};

  for (final entry in valuesByType.entries) {
    final type = entry.key.trim();
    if (type.isEmpty) {
      continue;
    }

    for (final rawValue in entry.value) {
      final normalized = normalizeWordLetters(rawValue);
      if (normalized.length < 3 || normalized.length > 9) {
        continue;
      }
      if (seenWords.add(normalized)) {
        candidates.add(CrosswordCandidate(word: normalized, type: type));
      }
    }
  }

  return candidates;
}

/// Generates the crossword that places the most words from [candidates].
///
/// Tries several shuffled candidate orders and stops early once the target
/// word count is reached. Returns null when there are no candidates.
CrosswordPuzzle? generateCrosswordPuzzle(
  List<CrosswordCandidate> candidates,
  math.Random random,
) {
  if (candidates.isEmpty) {
    return null;
  }

  CrosswordPuzzle? bestPuzzle;

  for (var attempt = 0; attempt < crosswordGenerationAttempts; attempt++) {
    final shuffled = List<CrosswordCandidate>.from(candidates)..shuffle(random);
    final puzzle = _buildPuzzle(shuffled);

    if (bestPuzzle == null ||
        puzzle.placedWords.length > bestPuzzle.placedWords.length) {
      bestPuzzle = puzzle;
    }

    if (puzzle.placedWords.length >= crosswordTargetWordCount) {
      bestPuzzle = puzzle;
      break;
    }
  }

  return bestPuzzle;
}

/// Greedily builds one puzzle by centering the first word and adding each
/// candidate at its highest-scoring valid intersection.
CrosswordPuzzle _buildPuzzle(List<CrosswordCandidate> shuffledCandidates) {
  final letters = <String, String>{};
  final wordIdsByCell = <String, Set<int>>{};
  final placedWords = <CrosswordPlacedWord>[];

  var nextWordId = 1;
  final first = shuffledCandidates.first;
  final firstRow = crosswordGridSize ~/ 2;
  final firstCol = ((crosswordGridSize - first.word.length) ~/ 2).clamp(
    0,
    crosswordGridSize - 1,
  );
  final firstPlaced = CrosswordPlacedWord(
    id: nextWordId++,
    word: first.word,
    type: first.type,
    row: firstRow,
    col: firstCol,
    isAcross: true,
  );
  placedWords.add(firstPlaced);
  placeWord(firstPlaced, letters, wordIdsByCell);

  for (final candidate in shuffledCandidates.skip(1)) {
    if (placedWords.length >= crosswordTargetWordCount) {
      break;
    }

    ({int row, int col, bool isAcross})? bestPlacement;
    var bestScore = -1;

    for (final cellEntry in letters.entries) {
      final cell = parseCellKey(cellEntry.key);
      final cellChar = cellEntry.value;

      for (var i = 0; i < candidate.word.length; i++) {
        if (candidate.word[i] != cellChar) {
          continue;
        }

        for (final isAcross in const [true, false]) {
          final startRow = isAcross ? cell.row : cell.row - i;
          final startCol = isAcross ? cell.col - i : cell.col;

          if (!canPlaceWord(
            candidate.word,
            startRow,
            startCol,
            isAcross,
            letters,
          )) {
            continue;
          }

          final score = countIntersections(
            candidate.word,
            startRow,
            startCol,
            isAcross,
            letters,
          );
          if (score <= 0) {
            continue;
          }

          if (score > bestScore) {
            bestScore = score;
            bestPlacement = (row: startRow, col: startCol, isAcross: isAcross);
          }
        }
      }
    }

    if (bestPlacement == null) {
      continue;
    }

    final placed = CrosswordPlacedWord(
      id: nextWordId++,
      word: candidate.word,
      type: candidate.type,
      row: bestPlacement.row,
      col: bestPlacement.col,
      isAcross: bestPlacement.isAcross,
    );
    placedWords.add(placed);
    placeWord(placed, letters, wordIdsByCell);
  }

  return CrosswordPuzzle(
    placedWords: placedWords,
    letters: letters,
    wordIdsByCell: wordIdsByCell,
  );
}

/// Builds the stable `row:column` key used by crossword maps.
String cellKey(int row, int col) => '$row:$col';

/// Decodes the stable `row:column` key used by crossword maps.
({int row, int col}) parseCellKey(String key) {
  final parts = key.split(':');
  return (row: int.parse(parts[0]), col: int.parse(parts[1]));
}

/// Checks bounds, matching intersections, and crossword adjacency rules.
///
/// Placements must create exactly one useful intersection with the grid.
bool canPlaceWord(
  String word,
  int startRow,
  int startCol,
  bool isAcross,
  Map<String, String> letters,
) {
  bool hasLetterAt(int row, int col) {
    if (row < 0 ||
        row >= crosswordGridSize ||
        col < 0 ||
        col >= crosswordGridSize) {
      return false;
    }
    return letters.containsKey(cellKey(row, col));
  }

  final beforeRow = isAcross ? startRow : startRow - 1;
  final beforeCol = isAcross ? startCol - 1 : startCol;
  if (hasLetterAt(beforeRow, beforeCol)) {
    return false;
  }

  final afterRow = isAcross ? startRow : startRow + word.length;
  final afterCol = isAcross ? startCol + word.length : startCol;
  if (hasLetterAt(afterRow, afterCol)) {
    return false;
  }

  var intersections = 0;

  for (var i = 0; i < word.length; i++) {
    final row = startRow + (isAcross ? 0 : i);
    final col = startCol + (isAcross ? i : 0);
    if (row < 0 ||
        row >= crosswordGridSize ||
        col < 0 ||
        col >= crosswordGridSize) {
      return false;
    }

    final key = cellKey(row, col);
    final existing = letters[key];
    if (existing != null) {
      if (existing != word[i]) {
        return false;
      }
      intersections++;
      continue;
    }

    if (isAcross) {
      if (hasLetterAt(row - 1, col) || hasLetterAt(row + 1, col)) {
        return false;
      }
    } else {
      if (hasLetterAt(row, col - 1) || hasLetterAt(row, col + 1)) {
        return false;
      }
    }
  }

  if (intersections == word.length) {
    return false;
  }

  if (intersections > 1) {
    return false;
  }

  return true;
}

/// Counts how many cells of a placement already match [letters].
int countIntersections(
  String word,
  int startRow,
  int startCol,
  bool isAcross,
  Map<String, String> letters,
) {
  var count = 0;
  for (var i = 0; i < word.length; i++) {
    final row = startRow + (isAcross ? 0 : i);
    final col = startCol + (isAcross ? i : 0);
    final key = cellKey(row, col);
    if (letters[key] == word[i]) {
      count++;
    }
  }
  return count;
}

/// Writes a placed word into the letter grid and reverse cell-to-word index.
void placeWord(
  CrosswordPlacedWord placedWord,
  Map<String, String> letters,
  Map<String, Set<int>> wordIdsByCell,
) {
  for (var i = 0; i < placedWord.word.length; i++) {
    final row = placedWord.row + (placedWord.isAcross ? 0 : i);
    final col = placedWord.col + (placedWord.isAcross ? i : 0);
    final key = cellKey(row, col);
    letters[key] = placedWord.word[i];
    wordIdsByCell.putIfAbsent(key, () => <int>{}).add(placedWord.id);
  }
}
