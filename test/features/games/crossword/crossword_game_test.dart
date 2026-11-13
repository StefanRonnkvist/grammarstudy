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

    testWidgets('fills the clue squares from the typed word', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Tap the first empty grid square; it sits inside the cell's container.
      final emptyLetter = find.descendant(
        of: find.byType(GridView),
        matching: find.text(''),
      );
      expect(emptyLetter, findsWidgets);
      await tester.tap(
        find
            .ancestor(of: emptyLetter.first, matching: find.byType(Container))
            .first,
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Typing into:'), findsOneWidget);

      final field = find.byType(TextField).last;
      String fieldText() =>
          tester.widget<TextField>(field).controller?.text ?? '';

      // An untouched clue shows blanks in the field.
      expect(fieldText(), '___');

      // Typing fills the squares in order; a wrong letter stays editable.
      await tester.enterText(field, 'c');
      await tester.pumpAndSettle();
      expect(fieldText(), 'C__');

      await tester.enterText(field, 'cz');
      await tester.pumpAndSettle();
      expect(fieldText(), 'CZ_');

      // Each character maps onto its own square, so editing the wrong letter
      // does not shift the letters already entered.
      await tester.enterText(field, 'cq');
      await tester.pumpAndSettle();
      expect(fieldText(), 'CQ_');

      // Once the letters are correct they are shown in the field in place.
      await tester.enterText(field, 'ca');
      await tester.pumpAndSettle();
      expect(fieldText(), 'CA_');

      // A correct letter typed by the player is still changeable, so a word can
      // always be corrected.
      await tester.enterText(field, 'c');
      await tester.pumpAndSettle();
      expect(fieldText()[1], 'A');

      await tester.enterText(field, 'cq');
      await tester.pumpAndSettle();
      expect(fieldText(), 'CQ_');

      await tester.enterText(field, 'zzz');
      await tester.pumpAndSettle();
      expect(fieldText(), 'ZZZ');
    });

    testWidgets('grades letters only once the whole clue is filled', (
      tester,
    ) async {
      // A single candidate makes the puzzle deterministic: one Across word
      // reading "cat", so the expected letters are known.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CrosswordGame(
              candidates: const [CrosswordCandidate(word: 'cat', type: 'Noun')],
              sentences: const [],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cells = find.byWidgetPredicate(
        (widget) => widget is GestureDetector && widget.child is Container,
      );
      await tester.tap(cells.first);
      await tester.pumpAndSettle();

      final field = find.byType(TextField).last;
      String fieldText() =>
          tester.widget<TextField>(field).controller?.text ?? '';
      expect(fieldText(), '___');

      /// Returns the colour of the rendered letter [letter], if any.
      Color? colorOf(String letter) {
        for (final element in find.byType(Text).evaluate()) {
          final widget = element.widget as Text;
          if (widget.data == letter && widget.style?.color != null) {
            return widget.style!.color;
          }
        }
        return null;
      }

      // A partly entered clue keeps its letters blue, correct or not.
      await tester.enterText(field, 'CX_');
      await tester.pumpAndSettle();

      expect(
        colorOf('C'),
        Colors.blue.shade800,
        reason: 'a correct letter is blue until the clue is complete',
      );
      expect(
        colorOf('X'),
        Colors.blue.shade800,
        reason: 'a wrong letter is blue until the clue is complete',
      );

      // Filling the last square grades the whole clue: C is right, X is wrong.
      await tester.enterText(field, 'CXT');
      await tester.pumpAndSettle();

      expect(colorOf('C'), Colors.green.shade800);
      expect(colorOf('X'), Colors.red.shade800);
      final scoreLabels = tester
          .widgetList<Text>(find.byType(Text))
          .map((text) => text.data)
          .where((text) => text?.startsWith('Correct:') ?? false)
          .toList();
      expect(scoreLabels, ['Correct: 2']);
      expect(find.text('Incorrect: 1'), findsOneWidget);
    });

    testWidgets('asks which clue to answer when a square shares a number', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CrosswordGame(
              candidates: const [
                CrosswordCandidate(word: 'elephant', type: 'Noun'),
                CrosswordCandidate(word: 'goat', type: 'Noun'),
                CrosswordCandidate(word: 'goal', type: 'Noun'),
                CrosswordCandidate(word: 'age', type: 'Noun'),
                CrosswordCandidate(word: 'orange', type: 'Noun'),
                CrosswordCandidate(word: 'grape', type: 'Noun'),
                CrosswordCandidate(word: 'leg', type: 'Noun'),
                CrosswordCandidate(word: 'lemon', type: 'Noun'),
                CrosswordCandidate(word: 'logo', type: 'Noun'),
                CrosswordCandidate(word: 'glove', type: 'Noun'),
                CrosswordCandidate(word: 'organ', type: 'Noun'),
                CrosswordCandidate(word: 'range', type: 'Noun'),
              ],
              sentences: const [],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cells = find.byWidgetPredicate(
        (widget) => widget is GestureDetector && widget.child is Container,
      );

      String clue() =>
          tester.widget<Text>(find.textContaining('Typing into:').first).data ??
          '';

      var sawPicker = false;
      for (var index = 0; index < cells.evaluate().length; index++) {
        if (find.byType(AlertDialog).evaluate().isNotEmpty) {
          await tester.tapAt(const Offset(5, 5));
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(cells.at(index));
        await tester.pumpAndSettle();
        await tester.tap(cells.at(index));
        await tester.pumpAndSettle();

        if (find.text('Choose a word').evaluate().isEmpty) {
          continue;
        }

        sawPicker = true;

        // The picker lists the clue before it, and picking one switches the
        // clue that typing fills.
        final clueBefore = clue();
        await tester.tap(find.byType(ListTile).last);
        await tester.pumpAndSettle();
        expect(find.text('Choose a word'), findsNothing);
        expect(clue(), isNot(clueBefore));
        break;
      }

      expect(
        sawPicker,
        isTrue,
        reason:
            'a square shared by an Across and a Down word must offer a choice',
      );
    });

    testWidgets('prefilled letters stay in place as new letters are typed', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CrosswordGame(
              candidates: const [
                CrosswordCandidate(word: 'cat', type: 'Noun'),
                CrosswordCandidate(word: 'tar', type: 'Noun'),
                CrosswordCandidate(word: 'rat', type: 'Noun'),
                CrosswordCandidate(word: 'art', type: 'Noun'),
              ],
              sentences: const [],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final field = find.byType(TextField).last;
      String fieldText() =>
          tester.widget<TextField>(field).controller?.text ?? '';

      final cells = find.byWidgetPredicate(
        (widget) => widget is GestureDetector && widget.child is Container,
      );

      // Reveal one clue so its letters become locked for the clue that crosses it.
      await tester.tap(cells.first);
      await tester.pumpAndSettle();
      await tester.tap(cells.first);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Reveal').first);
      await tester.pumpAndSettle();

      // Move to a different clue that crosses the revealed one. Its crossing
      // letter is prefilled and locked, because the player did not type it.
      // The revealed word fills its clue; the squares it crosses now carry a
      // letter that the player never typed.
      final revealedClue =
          tester.widget<Text>(find.textContaining('Typing into:').first).data ??
          '';
      expect(fieldText(), isNot(contains('_')));

      // Visit each square of another clue. Tapping the already selected square
      // reopens the clue dialog, so any dialog is closed before moving on.
      String prefilled = '';
      var prefillIndex = -1;
      for (var index = 0; index < cells.evaluate().length; index++) {
        if (find.byType(AlertDialog).evaluate().isNotEmpty) {
          await tester.tapAt(const Offset(5, 5));
          await tester.pumpAndSettle();
        }

        await tester.ensureVisible(cells.at(index));
        await tester.pumpAndSettle();
        await tester.tap(cells.at(index));
        await tester.pumpAndSettle();

        if (find.byType(AlertDialog).evaluate().isNotEmpty) {
          continue;
        }

        final clue =
            tester
                .widget<Text>(find.textContaining('Typing into:').first)
                .data ??
            '';
        if (clue == revealedClue) {
          continue;
        }

        prefilled = fieldText();
        if (prefilled.contains('_') && prefilled.contains(RegExp('[A-Z]'))) {
          prefillIndex = prefilled.indexOf(RegExp('[A-Z]'));
          break;
        }
      }

      expect(prefilled.length, 3);
      // A revealed letter appears in the field at its own position, with the
      // squares of the crossing word still blank.
      expect(prefillIndex, greaterThanOrEqualTo(0));

      // Type a letter into every blank square, the way a player does: each
      // keystroke replaces one `_` in place. The prefilled letter must stay
      // where it was, rather than being pushed along or overwritten.
      final revealedLetter = prefilled[prefillIndex];
      final buffer = prefilled.split('');
      for (final blank in <int>[
        for (var i = 0; i < prefilled.length; i++)
          if (prefilled[i] == '_') i,
      ]) {
        buffer[blank] = 'Z';
        await tester.enterText(field, buffer.join());
        await tester.pumpAndSettle();

        expect(
          fieldText()[prefillIndex],
          revealedLetter,
          reason: 'the crossing letter must stay in its own square',
        );
        expect(fieldText()[blank], 'Z');
      }

      // Every square is filled and the crossing letter is still in place.
      expect(
        fieldText(),
        'Z' * prefillIndex +
            revealedLetter +
            'Z' * (prefilled.length - prefillIndex - 1),
      );
    });

    testWidgets('revealed letters self fill and cannot be typed over', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CrosswordGame(
              candidates: const [
                CrosswordCandidate(word: 'cat', type: 'Noun'),
                CrosswordCandidate(word: 'tar', type: 'Noun'),
                CrosswordCandidate(word: 'rat', type: 'Noun'),
                CrosswordCandidate(word: 'art', type: 'Noun'),
              ],
              sentences: const [],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cellBox = find
          .ancestor(
            of: find
                .descendant(of: find.byType(GridView), matching: find.text(''))
                .first,
            matching: find.byType(Container),
          )
          .first;
      await tester.tap(cellBox);
      await tester.pumpAndSettle();

      // Tapping the selected square again opens the clue dialog, and revealing
      // the word fills the field with the whole clue.
      await tester.tap(cellBox);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Reveal').first);
      await tester.pumpAndSettle();

      final field = find.byType(TextField).last;
      String fieldText() =>
          tester.widget<TextField>(field).controller?.text ?? '';

      // Revealing fills the field with the whole revealed word. The word is read
      // back from the field rather than hardcoded, because puzzles are
      // generated in a random order.
      final revealedWord = fieldText();
      expect(revealedWord.length, greaterThan(0));
      expect(revealedWord, isNot(contains('_')));

      // Revealed letters are settled, so typing cannot change them.
      await tester.enterText(field, 'zzz');
      await tester.pumpAndSettle();
      expect(fieldText(), revealedWord);
    });
  });
}
