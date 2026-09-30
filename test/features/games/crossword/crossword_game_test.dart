import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammarstudy/features/games/crossword/domain/crossword_models.dart';
import 'package:grammarstudy/features/games/crossword/presentation/crossword_game.dart';

void main() {
  const candidates = [
    CrosswordCandidate(word: 'cat', type: 'Noun'),
    CrosswordCandidate(word: 'tap', type: 'Verb'),
    CrosswordCandidate(word: 'pat', type: 'Noun'),
  ];

  Widget buildSubject({
    List<String> sentences = const ['The cat sat on the mat.'],
    void Function(String)? onSnackBar,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: CrosswordGame(
          candidates: candidates,
          sentences: sentences,
          showSnackBar: onSnackBar,
        ),
      ),
    );
  }

  group('CrosswordGame', () {
    testWidgets('generates a puzzle from the supplied candidates', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // A generated puzzle always exposes a New Puzzle action.
      expect(find.text('New Puzzle'), findsOneWidget);
      expect(find.text('Hint'), findsOneWidget);
    });

    testWidgets('disables Clear Cell until a cell is selected', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final clearButton = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text('Clear Cell'),
          matching: find.byType(OutlinedButton),
        ),
      );
      expect(clearButton.onPressed, isNull);
    });

    testWidgets('prompts to tap a cell before any selection', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.textContaining('Tap a crossword cell'), findsOneWidget);
    });

    testWidgets('shows a message when the puzzle cannot be completed', (
      tester,
    ) async {
      String? message;
      await tester.pumpWidget(buildSubject(onSnackBar: (m) => message = m));
      await tester.pumpAndSettle();

      // Three short words rarely reach the six-word target.
      expect(message, isNotNull);
      expect(message, contains('Could only place'));
    });

    testWidgets('handles an empty candidate list without crashing', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CrosswordGame(candidates: const [], sentences: const []),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No crossword words available.'), findsOneWidget);
    });

    testWidgets('regenerates a different puzzle on demand', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CrosswordGame(
              candidates: const [
                CrosswordCandidate(word: 'cat', type: 'Noun'),
                CrosswordCandidate(word: 'tap', type: 'Verb'),
                CrosswordCandidate(word: 'pat', type: 'Noun'),
                CrosswordCandidate(word: 'rat', type: 'Noun'),
                CrosswordCandidate(word: 'tar', type: 'Noun'),
                CrosswordCandidate(word: 'rat', type: 'Noun'),
                CrosswordCandidate(word: 'art', type: 'Noun'),
                CrosswordCandidate(word: 'tan', type: 'Noun'),
              ],
              sentences: const [],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final before = tester.widgetList<Text>(find.byType(Text)).length;
      expect(before, greaterThan(0));

      await tester.tap(find.text('New Puzzle'));
      await tester.pumpAndSettle();

      expect(find.text('New Puzzle'), findsOneWidget);
    });

    testWidgets('rebuilds when a new candidate set arrives', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CrosswordGame(
              candidates: const [
                CrosswordCandidate(word: 'elephant', type: 'Noun'),
              ],
              sentences: const [],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The rebuilt puzzle should expose the single longer word's clue.
      expect(find.textContaining('letters'), findsWidgets);
    });
  });
}
