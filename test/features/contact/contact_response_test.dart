import 'package:flutter_test/flutter_test.dart';
import 'package:grammarstudy/features/contact/domain/contact_response.dart';

void main() {
  group('formatContactResponseSummary', () {
    test('includes the status and trimmed body', () {
      expect(
        formatContactResponseSummary(statusCode: 200, body: '  ok  '),
        'Status: 200\nok',
      );
    });

    test('substitutes a placeholder for an empty body', () {
      expect(
        formatContactResponseSummary(statusCode: 500, body: '   '),
        'Status: 500\n(empty response body)',
      );
    });

    test('preserves multi-line bodies', () {
      expect(
        formatContactResponseSummary(statusCode: 400, body: 'line1\nline2'),
        'Status: 400\nline1\nline2',
      );
    });

    test('does not truncate the diagnostic body', () {
      final body = 'x' * 500;
      final result = formatContactResponseSummary(statusCode: 200, body: body);

      expect(result, contains(body));
      expect(result, isNot(contains('...')));
    });
  });

  group('formatContactErrorMessage', () {
    test('reports status only for an empty body', () {
      expect(
        formatContactErrorMessage(statusCode: 503, body: ''),
        'The server returned error 503.',
      );
      expect(
        formatContactErrorMessage(statusCode: 503, body: '  \n '),
        'The server returned error 503.',
      );
    });

    test('includes a short body verbatim', () {
      expect(
        formatContactErrorMessage(statusCode: 400, body: '  Bad Request  '),
        'The server returned error 400: Bad Request',
      );
    });

    test('truncates a body beyond the maximum length', () {
      final body = 'y' * (contactErrorBodyMaxLength + 50);
      final result = formatContactErrorMessage(statusCode: 500, body: body);

      expect(result, endsWith('...'));
      // The retained prefix must equal the maximum length.
      final marker = 'The server returned error 500: ';
      expect(
        result.substring(marker.length, result.length - 3),
        'y' * contactErrorBodyMaxLength,
      );
    });

    test('keeps a body exactly at the maximum length intact', () {
      final body = 'z' * contactErrorBodyMaxLength;
      final result = formatContactErrorMessage(statusCode: 500, body: body);

      expect(result, isNot(endsWith('...')));
      expect(result.endsWith(body), isTrue);
    });
  });
}
