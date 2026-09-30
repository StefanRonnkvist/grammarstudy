import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammarstudy/core/layout/responsive.dart';
import 'package:grammarstudy/core/layout/text_measurement.dart';

void main() {
  /// Hosts [child] at a fixed logical size with a given text scale.
  Widget host(Widget child, {Size size = const Size(1200, 800)}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size, textScaler: const TextScaler.linear(1)),
        child: Builder(
          builder: (context) => Directionality(
            textDirection: TextDirection.ltr,
            child: Theme(
              data: ThemeData(useMaterial3: true),
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Captures the [BuildContext] of a simple centered child.
  Future<BuildContext> captureContext(
    WidgetTester tester, {
    Size size = const Size(1200, 800),
    double textScale = 1,
  }) async {
    late BuildContext captured;
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) {
            captured = context;
            return const SizedBox.shrink();
          },
        ),
        size: size,
      ),
    );
    captured = tester.element(find.byType(SizedBox).last);
    return captured;
  }

  group('shouldUseScrollableTabs', () {
    testWidgets('does not scroll when labels fit comfortably', (tester) async {
      final context = await captureContext(tester);

      expect(
        shouldUseScrollableTabs(context, ['One', 'Two'], 1200),
        isFalse,
      );
    });

    testWidgets('scrolls when labels exceed the width', (tester) async {
      final context = await captureContext(tester, size: const Size(200, 800));

      expect(
        shouldUseScrollableTabs(
          context,
          ['Games', 'Grammar', 'Structure', 'Sentence', 'Help', 'Information'],
          200,
        ),
        isTrue,
      );
    });

    testWidgets('scrolls for more labels at the same width', (tester) async {
      final context = await captureContext(tester, size: const Size(500, 800));

      expect(shouldUseScrollableTabs(context, ['A', 'B'], 500), isFalse);
      expect(
        shouldUseScrollableTabs(
          context,
          ['Alphabetical', 'Beta', 'Gamma', 'Delta', 'Epsilon'],
          500,
        ),
        isTrue,
      );
    });

    testWidgets('handles an empty label list', (tester) async {
      final context = await captureContext(tester);

      expect(shouldUseScrollableTabs(context, const [], 400), isFalse);
    });
  });

  group('shouldScrollEstimatedTabs', () {
    testWidgets('does not scroll for a short label set', (tester) async {
      final context = await captureContext(tester);

      expect(
        shouldScrollEstimatedTabs(context, ['Games', 'Help']),
        isFalse,
      );
    });

    testWidgets('scrolls for a long label set on a narrow screen',
        (tester) async {
      final context = await captureContext(tester, size: const Size(320, 640));

      expect(
        shouldScrollEstimatedTabs(
          context,
          ['Noun', 'Verb', 'Adjective', 'Adverb', 'Pronoun', 'Preposition'],
        ),
        isTrue,
      );
    });

    testWidgets('respects a custom character width', (tester) async {
      final context = await captureContext(tester, size: const Size(320, 640));

      expect(
        shouldScrollEstimatedTabs(
          context,
          ['Noun', 'Verb'],
          charWidth: 200,
        ),
        isTrue,
      );
    });
  });

  group('isWideLayout', () {
    test('uses the shared breakpoint', () {
      expect(wideLayoutBreakpoint, 900);
      expect(isWideLayout(899), isFalse);
      expect(isWideLayout(900), isTrue);
    });
  });

  group('fitFontSizeToWidth', () {
    const baseStyle = TextStyle(fontSize: 20);

    test('returns the base size for empty text', () {
      expect(
        fitFontSizeToWidth(text: '   ', baseStyle: baseStyle, maxWidth: 500),
        20,
      );
    });

    test('returns the base size when there is no room', () {
      expect(
        fitFontSizeToWidth(text: 'text', baseStyle: baseStyle, maxWidth: 0),
        20,
      );
    });

    test('returns the base size when the text already fits', () {
      expect(
        fitFontSizeToWidth(text: 'hi', baseStyle: baseStyle, maxWidth: 5000),
        20,
      );
    });

    test('shrinks the size for long text in a narrow space', () {
      final fitted = fitFontSizeToWidth(
        text: 'A considerably longer sentence than before',
        baseStyle: baseStyle,
        maxWidth: 60,
      );

      expect(fitted, lessThan(20));
      expect(fitted, greaterThanOrEqualTo(8));
    });

    test('never returns less than the minimum size', () {
      final fitted = fitFontSizeToWidth(
        text: 'x' * 200,
        baseStyle: baseStyle,
        maxWidth: 1,
        minSize: 8,
      );

      expect(fitted, greaterThanOrEqualTo(8));
    });

    test('falls back to 14 when the style has no font size', () {
      const noSize = TextStyle();
      expect(
        fitFontSizeToWidth(text: 'text', baseStyle: noSize, maxWidth: 5000),
        14,
      );
    });

    testWidgets('produces a size that actually fits', (tester) async {
      // Short enough that it fits at the minimum size under the test font.
      const text = 'Shrink me now';
      const maxWidth = 120.0;
      final fitted = fitFontSizeToWidth(
        text: text,
        baseStyle: baseStyle,
        maxWidth: maxWidth,
      );

      // Measure inside the test harness so the same font resolution applies
      // to the verification as it did during the search.
      var measured = 0.0;
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) {
              final painter = TextPainter(
                text: TextSpan(
                  text: text,
                  style: baseStyle.copyWith(fontSize: fitted),
                ),
                maxLines: 1,
                textDirection: Directionality.of(context),
              )..layout();
              measured = painter.width;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(measured, lessThanOrEqualTo(maxWidth));
    });
  });

  group('halfTextStyle', () {
    test('halves the font size', () {
      expect(
        halfTextStyle(const TextStyle(fontSize: 20)).fontSize,
        10,
      );
    });

    test('preserves the original weight unless overridden', () {
      const bold = TextStyle(fontSize: 20, fontWeight: FontWeight.w700);
      expect(halfTextStyle(bold).fontWeight, FontWeight.w700);
      expect(
        halfTextStyle(bold, fontWeight: FontWeight.w400).fontWeight,
        FontWeight.w400,
      );
    });

    test('falls back to 14 for a null style', () {
      expect(halfTextStyle(null).fontSize, 7);
    });
  });

  group('readableTextColorOn', () {
    testWidgets('returns white on a dark background', (tester) async {
      await tester.pumpWidget(host(const SizedBox.shrink()));

      expect(
        readableTextColorOn(const Color(0xFF000000)),
        Colors.white,
      );
    });

    testWidgets('returns black on a light background', (tester) async {
      await tester.pumpWidget(host(const SizedBox.shrink()));

      expect(
        readableTextColorOn(const Color(0xFFFFFFFF)),
        Colors.black,
      );
    });
  });

  group('buildHighlightedSpan', () {
    testWidgets('returns plain text when nothing matches', (tester) async {
      late InlineSpan span;
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) {
              span = buildHighlightedSpan(
                context: context,
                text: 'no match here',
                pattern: RegExp('zzz'),
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(span.toPlainText(), 'no match here');
      expect((span as TextSpan).children, isNull);
    });

    testWidgets('splits text around matches', (tester) async {
      late InlineSpan span;
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) {
              span = buildHighlightedSpan(
                context: context,
                text: 'the cat sat',
                pattern: RegExp('cat'),
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(span.toPlainText(), 'the cat sat');
      final children = (span as TextSpan).children;
      expect(children, isNotNull);
      expect(children, hasLength(3));
    });

    testWidgets('handles a match at the start and end', (tester) async {
      late InlineSpan span;
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) {
              span = buildHighlightedSpan(
                context: context,
                text: 'cat and cat',
                pattern: RegExp('cat'),
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(span.toPlainText(), 'cat and cat');
    });
  });
}
