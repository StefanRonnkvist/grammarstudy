import 'package:flutter_test/flutter_test.dart';
import 'package:grammarstudy/features/contact/domain/submissions_csv.dart';

void main() {
  group('parseSubmissionsCsv', () {
    test('returns no rows for empty input', () {
      expect(parseSubmissionsCsv(''), isEmpty);
    });

    test('parses a single simple row', () {
      expect(parseSubmissionsCsv('a,b,c'), [
        ['a', 'b', 'c'],
      ]);
    });

    test('keeps commas inside quoted fields', () {
      expect(parseSubmissionsCsv('"hello, world",b,c'), [
        ['hello, world', 'b', 'c'],
      ]);
    });

    test('unescapes doubled quotes', () {
      expect(parseSubmissionsCsv('"say ""hi""",b'), [
        ['say "hi"', 'b'],
      ]);
    });

    test('handles Windows line endings as one break', () {
      expect(parseSubmissionsCsv('a,b\r\nc,d\r\n'), [
        ['a', 'b'],
        ['c', 'd'],
      ]);
    });

    test('handles Unix line endings', () {
      expect(parseSubmissionsCsv('a,b\nc,d'), [
        ['a', 'b'],
        ['c', 'd'],
      ]);
    });

    test('does not emit a trailing empty row after a final newline', () {
      expect(parseSubmissionsCsv('a,b\n'), [
        ['a', 'b'],
      ]);
    });

    test('drops rows where every field is empty', () {
      expect(parseSubmissionsCsv('a,b\n\n\nc,d'), [
        ['a', 'b'],
        ['c', 'd'],
      ]);
    });

    test('keeps a single-column row', () {
      expect(parseSubmissionsCsv('solo'), [
        ['solo'],
      ]);
    });

    test('preserves empty fields between commas', () {
      expect(parseSubmissionsCsv('a,,c'), [
        ['a', '', 'c'],
      ]);
    });

    test('preserves a quoted newline inside a field', () {
      expect(parseSubmissionsCsv('"line1\nline2",b'), [
        ['line1\nline2', 'b'],
      ]);
    });
  });

  group('buildSubmissionsTable', () {
    const currentApp = 'com.stefanronnkvist.paid.grammarstudy';

    test('returns an empty table for no rows', () {
      final table = buildSubmissionsTable(const [], currentApp: currentApp);
      expect(table.isEmpty, isTrue);
      expect(table.headers, isEmpty);
    });

    test('keeps only rows matching the current package', () {
      final table = buildSubmissionsTable([
        ['Ann', 'a@b.c', currentApp, '1.0', 's', 'hello', 'now'],
        ['Bob', 'b@b.c', 'com.other.app', '1.0', 's', 'hi', 'now'],
      ], currentApp: currentApp);

      expect(table.rows, hasLength(1));
      expect(table.rows.single.first, 'Ann');
    });

    test('matches the package case-insensitively', () {
      final table = buildSubmissionsTable([
        ['Ann', 'a@b.c', currentApp.toUpperCase(), '1.0', 's', 'x', 'now'],
      ], currentApp: currentApp);

      expect(table.rows, hasLength(1));
    });

    test('pads short rows to the fixed schema', () {
      final table = buildSubmissionsTable([
        ['Ann', 'a@b.c', currentApp],
      ], currentApp: currentApp);

      expect(table.rows.single, hasLength(submissionsHeaders.length));
      expect(table.headers, submissionsHeaders);
    });

    test('accepts a row longer than the schema without throwing', () {
      // Padding with a negative length would throw; extra columns must survive.
      final table = buildSubmissionsTable([
        ['Ann', 'a@b.c', currentApp, '1.0', 's', 'x', 'now', 'extra'],
      ], currentApp: currentApp);

      expect(table.rows.single, hasLength(8));
      expect(table.rows.single.last, 'extra');
    });

    test('filters out rows with an empty app column', () {
      final table = buildSubmissionsTable([
        ['Ann', 'a@b.c', '', '1.0', 's', 'x', 'now'],
      ], currentApp: currentApp);

      expect(table.isEmpty, isTrue);
    });

    test('parses and filters an end-to-end document', () {
      final csv = [
        'Name,eMail,App,Version,Series,Content,DateTime',
        '"Smith, Ann",ann@x.com,$currentApp,1.0.43,stable,"Hello, there!",2026',
        'Bob,bob@x.com,com.other.app,1.0,stable,Hi,2026',
      ].join('\n');

      final table = buildSubmissionsTable(
        parseSubmissionsCsv(csv),
        currentApp: currentApp,
      );

      expect(table.rows, hasLength(1));
      expect(table.rows.single[0], 'Smith, Ann');
      expect(table.rows.single[5], 'Hello, there!');
    });
  });
}
