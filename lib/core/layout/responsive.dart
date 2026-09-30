import 'package:flutter/material.dart';

/// Decides whether a tab bar must scroll to fit [labels] within [maxWidth].
///
/// Labels are measured with the resolved tab label style and text scaler so the
/// decision respects the user's accessibility text size.
bool shouldUseScrollableTabs(
  BuildContext context,
  List<String> labels,
  double maxWidth, {
  double labelPadding = 32,
}) {
  final tabLabelStyle =
      Theme.of(context).tabBarTheme.labelStyle ??
      Theme.of(context).textTheme.titleSmall;
  final textScaler = MediaQuery.textScalerOf(context);
  final textDirection = Directionality.of(context);

  var requiredWidth = 0.0;
  for (final label in labels) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: tabLabelStyle),
      textDirection: textDirection,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();

    // TabBar default horizontal label padding is 16 on each side.
    requiredWidth += painter.width + labelPadding;
  }

  return requiredWidth > maxWidth;
}

/// Estimates tab widths arithmetically for label sets that are not yet known.
bool shouldScrollEstimatedTabs(
  BuildContext context,
  List<String> labels, {
  double charWidth = 10.0,
  double labelPadding = 56.0,
}) {
  final textScale = MediaQuery.textScalerOf(context).scale(1);
  final estimatedTabWidth = labels
      .map((label) => (label.length * charWidth * textScale) + labelPadding)
      .fold<double>(0, (sum, width) => sum + width);

  return estimatedTabWidth > MediaQuery.sizeOf(context).width;
}

/// Width at or above which two-pane study layouts are shown side by side.
const double wideLayoutBreakpoint = 900.0;

/// Whether [maxWidth] is wide enough to render a two-pane layout.
bool isWideLayout(double maxWidth) => maxWidth >= wideLayoutBreakpoint;
