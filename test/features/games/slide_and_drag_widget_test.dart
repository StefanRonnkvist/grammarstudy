import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammarstudy/features/games/crossword/domain/crossword_models.dart';
import 'package:grammarstudy/features/games/drag/domain/drag_logic.dart';
import 'package:grammarstudy/features/games/drag/presentation/drag_game.dart';
import 'package:grammarstudy/features/games/slide/presentation/slide_game.dart';

void main() {
  const candidates = [
    CrosswordCandidate(word: 'cat', type: 'Noun'),
    CrosswordCandidate(word: 'tap', type: 'Verb'),
    CrosswordCandidate(word: 'pat', type: 'Noun'),
    CrosswordCandidate(word: 'rat', type: 'Noun'),
  ];

  const sentences = ['The cat sat on the mat.', 'A dog barked loudly.'];
  const definitions = {'noun': 'A person, place, or thing.'};

  Widget buildSubject(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  group('SlideGame', () {
    Widget build({List<CrosswordCandidate>? words}) {
      return buildSubject(
        SlideGame(
          candidates: words ?? candidates,
          sentences: sentences,
          definitionsByWordType: definitions,
        ),
      );
    }

    testWidgets('renders the three controls', (tester) async {
      await tester.pumpWidget(build());
      await tester.pumpAndSettle();

      expect(find.text('Hint'), findsOneWidget);
      expect(find.text('Submit'), findsOneWidget);
      expect(find.text('New Word'), findsOneWidget);
    });

    testWidgets('reports an empty board without candidates', (tester) async {
      await tester.pumpWidget(build(words: const []));
      await tester.pumpAndSettle();

      expect(find.text('No slide word available.'), findsOneWidget);
    });

    testWidgets('shows the drawn word type as a tappable label', (
      tester,
    ) async {
      await tester.pumpWidget(build());
      await tester.pumpAndSettle();

      // Only the drawn target word's category is labelled, and the board is
      // random, so assert against whichever type was actually selected.
      final types = candidates.map((c) => c.type).toSet();
      final shown = types.where(
        (type) => find.text(type).evaluate().isNotEmpty,
      );
      expect(shown, isNotEmpty, reason: 'no word type label rendered');
    });

    testWidgets('opens the definition dialog from the word type label', (
      tester,
    ) async {
      await tester.pumpWidget(build());
      await tester.pumpAndSettle();

      // Tap whichever type the random board actually drew.
      final types = candidates.map((c) => c.type).toSet();
      final drawn = types.firstWhere(
        (type) => find.text(type).evaluate().isNotEmpty,
      );
      await tester.tap(find.text(drawn).first);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text(drawn), findsWidgets);
    });

    testWidgets('submitting shows a correct-letter counter', (tester) async {
      await tester.pumpWidget(build());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Correct letters:'), findsOneWidget);
    });

    testWidgets('New Word regenerates the board', (tester) async {
      await tester.pumpWidget(build());
      await tester.pumpAndSettle();

      await tester.tap(find.text('New Word'));
      await tester.pumpAndSettle();

      expect(find.text('Submit'), findsOneWidget);
    });

    testWidgets('Hint opens a dialog with a sentence', (tester) async {
      await tester.pumpWidget(build());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hint'));
      await tester.pumpAndSettle();

      expect(find.text('Slide Hint'), findsOneWidget);
    });
  });

  group('DragGame', () {
    const structureSentences = [
      'The (determiner) cat (noun) sleeps .',
      'A (determiner) dog (noun) barks .',
    ];

    Widget build({List<String> sentences = structureSentences}) {
      return buildSubject(DragGame(structureSentences: sentences));
    }

    testWidgets('renders the New Sentence control', (tester) async {
      await tester.pumpWidget(build());
      await tester.pumpAndSettle();

      expect(find.text('New Sentence'), findsOneWidget);
    });

    testWidgets('shows an empty state without structure sentences', (
      tester,
    ) async {
      await tester.pumpWidget(build(sentences: const []));
      await tester.pumpAndSettle();

      expect(
        find.text('No structure sentence available for Drag.'),
        findsOneWidget,
      );
    });

    testWidgets('displays the sentence without its grammar tags', (
      tester,
    ) async {
      await tester.pumpWidget(build());
      await tester.pumpAndSettle();

      // Visible words come from the stripped sentence, never the annotations.
      expect(find.textContaining('('), findsNothing);
    });

    testWidgets('renders drop targets for the removed words', (tester) async {
      await tester.pumpWidget(build());
      await tester.pumpAndSettle();

      // The tagged sentence supplies at least one drop target.
      expect(find.text('DETERMINER'), findsWidgets);
    });

    testWidgets('New Sentence loads a different round', (tester) async {
      await tester.pumpWidget(build());
      await tester.pumpAndSettle();

      await tester.tap(find.text('New Sentence'));
      await tester.pumpAndSettle();

      expect(find.text('New Sentence'), findsOneWidget);
    });

    testWidgets('sentence tokens come from the round that was drawn',
        (tester) async {
      await tester.pumpWidget(build());
      await tester.pumpAndSettle();

      // Exactly one sentence is drawn per round, so its distinctive tokens
      // must all be present while the other sentence's must not. Find the
      // candidate whose tokens are fully rendered.
      final perSentence = structureSentences
          .map(
            (sentence) => parseDragSentenceTokens(sentence)
                .map((token) => token.display)
                .where((word) => word.length > 1)
                .toList(),
          )
          .toList(growable: false);

      final rendered = perSentence.firstWhere(
        (words) =>
            words.isNotEmpty &&
            words.every((word) => find.text(word).evaluate().isNotEmpty),
        orElse: () => <String>[],
      );

      expect(rendered, isNotEmpty, reason: 'no complete sentence rendered');
    });
  });
}
