import 'package:flutter/material.dart';

import '../../../core/layout/text_measurement.dart';
import '../../../core/text/text_utils.dart';

/// Shows tagged sentence matches for a selected grammar value.
///
/// Each row starts as plain text and toggles to its annotated structure when
/// the row is selected, so the two forms can be compared directly.
Future<void> showGrammarValueMatchesDialog(
  BuildContext context, {
  required String value,
  required List<String> taggedSentences,
}) {
  final pattern = buildWordPattern(value);
  final matches = taggedSentences
      .where((entry) => pattern.hasMatch(entry))
      .toList(growable: false);

  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final toggledIndices = <int>{};
      return AlertDialog(
        title: Text('Matches for "$value" (${matches.length})'),
        content: SizedBox(
          width: 720,
          child: matches.isEmpty
              ? const Text('No structure entries found for this value.')
              : StatefulBuilder(
                  builder: (context, setDialogState) {
                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: matches.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final match = matches[index];
                        final showStructureText = toggledIndices.contains(
                          index,
                        );

                        return ListTile(
                          dense: true,
                          onTap: () {
                            setDialogState(() {
                              if (showStructureText) {
                                toggledIndices.remove(index);
                              } else {
                                toggledIndices.add(index);
                              }
                            });
                          },
                          leading: CircleAvatar(
                            radius: 14,
                            child: Text('${index + 1}'),
                          ),
                          title: showStructureText
                              ? Text.rich(
                                  buildHighlightedSpan(
                                    context: context,
                                    text: match,
                                    pattern: pattern,
                                  ),
                                )
                              : Text(stripGrammarTags(match)),
                        );
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}
