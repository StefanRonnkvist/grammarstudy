import 'package:flutter/material.dart';

/// Uses binary search to find the largest one-line font size that fits.
///
/// Returns [TextStyle]'s own size when the text is empty, there is no room,
/// or the text already fits at the base size. The early return keeps that case
/// exact instead of returning a value the search merely approached.
double fitFontSizeToWidth({
  required String text,
  required TextStyle baseStyle,
  required double maxWidth,
  double minSize = 8,
  int iterations = 16,
}) {
  final trimmed = text.trim();
  final baseSize = baseStyle.fontSize ?? 14;
  if (trimmed.isEmpty || maxWidth <= 0) {
    return baseSize;
  }

  if (_measureWidth(text, baseStyle.copyWith(fontSize: baseSize)) <= maxWidth) {
    return baseSize;
  }

  var low = minSize;
  var high = baseSize;
  var best = low;

  for (var i = 0; i < iterations; i++) {
    final mid = (low + high) / 2;

    if (_measureWidth(text, baseStyle.copyWith(fontSize: mid)) <= maxWidth) {
      best = mid;
      low = mid;
    } else {
      high = mid;
    }
  }

  return best;
}

/// Lays out [text] at one line with [style] and returns its width.
double _measureWidth(String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    maxLines: 1,
    textDirection: TextDirection.ltr,
  )..layout();
  return painter.width;
}

/// Shrinks [base] to half its size, used for secondary game annotations.
TextStyle halfTextStyle(TextStyle? base, {FontWeight? fontWeight}) {
  final fallback = base ?? const TextStyle(fontSize: 14);
  final baseSize = fallback.fontSize ?? 14;
  return fallback.copyWith(
    fontSize: baseSize * 0.5,
    fontWeight: fontWeight ?? fallback.fontWeight,
  );
}

/// Returns black or white depending on [background] brightness.
Color readableTextColorOn(Color background) {
  return ThemeData.estimateBrightnessForColor(background) == Brightness.dark
      ? Colors.white
      : Colors.black;
}

/// Builds a span that bolds and colours every occurrence of [value] in [text].
InlineSpan buildHighlightedSpan({
  required BuildContext context,
  required String text,
  required RegExp pattern,
}) {
  final baseStyle = Theme.of(context).textTheme.bodyMedium;
  final highlightStyle = baseStyle?.copyWith(
    fontWeight: FontWeight.bold,
    color: Theme.of(context).colorScheme.primary,
  );

  final matches = pattern.allMatches(text).toList(growable: false);
  if (matches.isEmpty) {
    return TextSpan(text: text, style: baseStyle);
  }

  final children = <TextSpan>[];
  var cursor = 0;
  for (final match in matches) {
    if (match.start > cursor) {
      children.add(
        TextSpan(text: text.substring(cursor, match.start), style: baseStyle),
      );
    }

    children.add(
      TextSpan(
        text: text.substring(match.start, match.end),
        style: highlightStyle,
      ),
    );
    cursor = match.end;
  }

  if (cursor < text.length) {
    children.add(TextSpan(text: text.substring(cursor), style: baseStyle));
  }

  return TextSpan(children: children, style: baseStyle);
}
