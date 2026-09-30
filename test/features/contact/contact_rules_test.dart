import 'package:flutter_test/flutter_test.dart';
import 'package:grammarstudy/features/contact/domain/contact_rules.dart';
import 'package:grammarstudy/features/contact/presentation/contact_page.dart';

void main() {
  group('validateContactName', () {
    test('rejects null and blank values', () {
      expect(validateContactName(null), isNotNull);
      expect(validateContactName(''), 'Enter your name.');
      expect(validateContactName('   '), 'Enter your name.');
    });

    test('rejects a single character', () {
      expect(validateContactName('A'), isNotNull);
    });

    test('accepts two or more characters', () {
      expect(validateContactName('Al'), isNull);
      expect(validateContactName('Alice'), isNull);
    });

    test('ignores surrounding whitespace when measuring length', () {
      expect(validateContactName('  A  '), isNotNull);
      expect(validateContactName('  Al  '), isNull);
    });
  });

  group('validateContactEmail', () {
    test('rejects empty input', () {
      expect(validateContactEmail(null), 'Enter your return email.');
      expect(validateContactEmail('  '), 'Enter your return email.');
    });

    test('rejects a missing @ or domain dot', () {
      expect(validateContactEmail('ann'), isNotNull);
      expect(validateContactEmail('ann@example'), isNotNull);
      expect(validateContactEmail('example.com'), isNotNull);
    });

    test('rejects addresses containing spaces', () {
      expect(validateContactEmail('ann smith@example.com'), isNotNull);
    });

    test('accepts a plain address', () {
      expect(validateContactEmail('ann@example.com'), isNull);
    });

    test('ignores surrounding whitespace', () {
      expect(validateContactEmail('  ann@example.com  '), isNull);
    });
  });

  group('validateContactQuestion', () {
    test('rejects null and blank values', () {
      expect(validateContactQuestion(null), 'Enter your question.');
      expect(validateContactQuestion('  '), 'Enter your question.');
    });

    test('rejects fewer than five characters', () {
      expect(validateContactQuestion('Why?'), isNotNull);
    });

    test('accepts five or more characters', () {
      expect(validateContactQuestion('Why is this?'), isNull);
    });
  });

  group('formatArtifactVersion', () {
    test('reports Unavailable without a version', () {
      expect(formatArtifactVersion(), 'Unavailable');
      expect(formatArtifactVersion(version: ''), 'Unavailable');
    });

    test('returns the version alone without a build number', () {
      expect(formatArtifactVersion(version: '1.0.43'), '1.0.43');
    });

    test('combines version and build number', () {
      expect(
        formatArtifactVersion(version: '1.0.43', buildNumber: '45'),
        '1.0.43 (build 45)',
      );
    });

    test('omits a blank build number', () {
      expect(
        formatArtifactVersion(version: '1.0.43', buildNumber: '  '),
        '1.0.43',
      );
    });
  });

  group('contactLayoutName', () {
    test('labels narrow widths as Phone', () {
      expect(contactLayoutName(320), 'Phone');
      expect(contactLayoutName(599), 'Phone');
    });

    test('labels medium widths as Tablet', () {
      expect(contactLayoutName(600), 'Tablet');
      expect(contactLayoutName(1099), 'Tablet');
    });

    test('labels wide widths as Desktop', () {
      expect(contactLayoutName(1100), 'Desktop');
      expect(contactLayoutName(2560), 'Desktop');
    });
  });

  group('buildContactEndpoint', () {
    test('appends contact.php to a bare origin', () {
      expect(
        buildContactEndpoint(Uri.parse('https://example.com')).toString(),
        'https://example.com/contact.php',
      );
    });

    test('appends contact.php under an existing path', () {
      expect(
        buildContactEndpoint(Uri.parse('https://example.com/app')).toString(),
        'https://example.com/app/contact.php',
      );
    });

    test('does not duplicate an existing contact.php', () {
      expect(
        buildContactEndpoint(
          Uri.parse('https://example.com/contact.php'),
        ).toString(),
        'https://example.com/contact.php',
      );
    });

    test('preserves the scheme, host, and port', () {
      final result = buildContactEndpoint(Uri.parse('http://localhost:8080'));
      expect(result.scheme, 'http');
      expect(result.host, 'localhost');
      expect(result.port, 8080);
      expect(result.path, '/contact.php');
    });

    test('resolves a trailing slash without doubling separators', () {
      expect(
        buildContactEndpoint(Uri.parse('https://example.com/')).toString(),
        'https://example.com/contact.php',
      );
    });
  });

  group('createContactPage', () {
    test('rejects a URL without a scheme', () {
      expect(
        () => createContactPage(serverUrl: 'example.com'),
        throwsArgumentError,
      );
    });

    test('rejects a malformed URL', () {
      expect(
        () => createContactPage(serverUrl: 'not a url'),
        throwsArgumentError,
      );
    });

    test('accepts a valid URL and honors wrapInScaffold', () {
      expect(createContactPage(serverUrl: 'https://example.com'), isNotNull);
      expect(
        createContactPage(
          serverUrl: 'https://example.com',
          wrapInScaffold: false,
        ),
        isNotNull,
      );
    });
  });
}
