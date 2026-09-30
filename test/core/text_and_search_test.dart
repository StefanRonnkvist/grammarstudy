import 'package:flutter_test/flutter_test.dart';
import 'package:grammarstudy/core/search/search_filter.dart';
import 'package:grammarstudy/core/text/text_utils.dart';

void main() {
  group('normalizeWhitespace', () {
    test('collapses runs and trims', () {
      expect(normalizeWhitespace('  a   b \n c  '), 'a b c');
    });

    test('leaves clean text unchanged', () {
      expect(normalizeWhitespace('one two'), 'one two');
    });
  });

  group('normalizeTagWord', () {
    test('uppercases after collapsing', () {
      expect(normalizeTagWord('  noun   '), 'NOUN');
    });
  });

  group('normalizeComparable', () {
    test('strips punctuation and uppercases', () {
      expect(normalizeComparable('don’t'), 'DONT');
      expect(normalizeComparable('well-known'), 'WELLKNOWN');
    });

    test('keeps digits and collapses spaces', () {
      expect(normalizeComparable(' word   2 '), 'WORD 2');
    });
  });

  group('normalizeWordLetters', () {
    test('keeps only lowercase letters', () {
      expect(normalizeWordLetters('The-Quick Fox!'), 'thequickfox');
    });
  });

  group('buildWordPattern', () {
    test('requires word boundaries for single words', () {
      expect(buildWordPattern('art').hasMatch('start'), isFalse);
      expect(buildWordPattern('art').hasMatch('an art.'), isTrue);
    });

    test('matches multi-word phrases literally', () {
      expect(
        buildWordPattern('in spite of').hasMatch('Done in spite of rain'),
        isTrue,
      );
    });

    test('is case-insensitive', () {
      expect(buildWordPattern('NOUN').hasMatch('a noun here'), isTrue);
    });
  });

  group('containsWholeWord', () {
    test('rejects empty inputs', () {
      expect(containsWholeWord('text', ''), isFalse);
      expect(containsWholeWord('', 'text'), isFalse);
    });

    test('does not match a substring', () {
      expect(containsWholeWord('partition', 'art'), isFalse);
    });

    test('matches a whole word', () {
      expect(containsWholeWord('the art of war', 'art'), isTrue);
    });
  });

  group('findSentenceForWord', () {
    final sentences = ['A cat sat.', 'The dog barked loudly.'];

    test('returns the first matching sentence', () {
      expect(findSentenceForWord('dog', sentences), 'The dog barked loudly.');
    });

    test('returns a readable fallback when nothing matches', () {
      final result = findSentenceForWord('zebra', sentences);
      expect(result, contains('zebra'));
      expect(result, startsWith('No sentence found'));
    });
  });

  group('stripGrammarTags', () {
    test('removes annotations and repairs spacing before punctuation', () {
      expect(
        stripGrammarTags('The (determiner) cat , (noun) sleeps .'),
        'The cat, sleeps.',
      );
    });

    test('joins a tag directly attached to its word', () {
      expect(stripGrammarTags('a (det) cat (noun)'), 'a cat');
    });

    test('leaves plain sentences untouched', () {
      expect(
        stripGrammarTags('Nothing to strip here.'),
        'Nothing to strip here.',
      );
    });
  });

  group('filterAndSortItems', () {
    test('returns all items for an empty query', () {
      final result = filterAndSortItems(['b', 'a'], '');
      expect(result, ['a', 'b']);
    });

    test('filters case-insensitively', () {
      expect(filterAndSortItems(['Apple', 'Banana'], 'app'), ['Apple']);
    });

    test('ranks prefix matches before other substring matches', () {
      final result = filterAndSortItems(['replay', 'play', 'display'], 'play');
      expect(result.first, 'play');
      expect(result, contains('display'));
    });

    test('does not mutate the source list', () {
      final source = ['b', 'a'];
      filterAndSortItems(source, '');
      expect(source, ['b', 'a']);
    });
  });
}
