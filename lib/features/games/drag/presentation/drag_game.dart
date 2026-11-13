import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/layout/responsive.dart';
import '../../../../core/layout/text_measurement.dart';
import '../domain/drag_logic.dart';
import '../domain/drag_models.dart';
import '../../presentation/game_scoreboard.dart';

/// Hosts the Drag game: rebuild a tagged sentence by placing its words.
///
/// Matching colours confirm a correct placement; an incorrect drop flashes red
/// and leaves the word available to try again.
class DragGame extends StatefulWidget {
  const DragGame({super.key, required this.structureSentences});

  final List<String> structureSentences;

  @override
  State<DragGame> createState() => _DragGameState();
}

class _DragGameState extends State<DragGame> {
  final math.Random _random = math.Random();

  DragRound? _round;
  List<DragSentenceToken> _tokens = const [];
  Map<String, List<DragWordPayload>> _matchedByTarget =
      <String, List<DragWordPayload>>{};
  Map<int, bool> _tokenIsCorrectByIndex = <int, bool>{};
  Map<int, String> _matchedTargetByTokenIndex = <int, String>{};
  Map<String, Color> _targetColors = <String, Color>{};
  bool _showMissFeedback = false;
  int _correctValues = 0;
  int _incorrectValues = 0;

  @override
  void initState() {
    super.initState();
    _newRound();
  }

  void _newRound() {
    final generated = buildRandomDragRound(widget.structureSentences, _random);
    if (generated == null) {
      setState(() {
        _round = null;
        _tokens = const [];
        _matchedByTarget = <String, List<DragWordPayload>>{};
        _tokenIsCorrectByIndex = <int, bool>{};
        _matchedTargetByTokenIndex = <int, String>{};
        _targetColors = <String, Color>{};
        _showMissFeedback = false;
      });
      return;
    }

    final round = generated.round;
    setState(() {
      _round = round;
      _tokens = generated.tokens;
      _matchedByTarget = <String, List<DragWordPayload>>{};
      _tokenIsCorrectByIndex = <int, bool>{};
      _matchedTargetByTokenIndex = <int, String>{};
      _targetColors = <String, Color>{
        for (var i = 0; i < round.removedWords.length; i++)
          round.removedWords[i]: _colorForIndex(i),
      };
      _showMissFeedback = false;
    });
  }

  Color _colorForIndex(int index) {
    final colorValue = dragTargetPalette[index % dragTargetPalette.length];
    return Color(colorValue);
  }

  /// Briefly flashes unmatched targets after an incorrect or abandoned drag.
  Future<void> _triggerMissFeedback() async {
    if (!mounted || _showMissFeedback) {
      return;
    }
    setState(() {
      _showMissFeedback = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!mounted) {
      return;
    }
    setState(() {
      _showMissFeedback = false;
    });
  }

  Color _targetBackgroundColor(String word, {required bool isMatched}) {
    final baseColor =
        _targetColors[word] ?? Theme.of(context).colorScheme.primary;
    return isMatched
        ? baseColor.withValues(alpha: 0.18)
        : baseColor.withValues(alpha: 0.28);
  }

  void _onWordDropped(DragWordPayload payload, String word) {
    final isCorrect = isDragTokenCorrect(
      tokens: _tokens,
      tokenIndex: payload.tokenIndex,
      word: word,
    );

    setState(() {
      _tokenIsCorrectByIndex[payload.tokenIndex] = isCorrect;
      if (isCorrect) {
        _correctValues++;
        _matchedTargetByTokenIndex[payload.tokenIndex] = word;
        _matchedByTarget =
            Map<String, List<DragWordPayload>>.from(_matchedByTarget)..update(
              word,
              (existing) => [...existing, payload],
              ifAbsent: () => [payload],
            );
      } else {
        _incorrectValues++;
      }
    });

    if (!isCorrect) {
      _triggerMissFeedback();
    }
  }

  bool _canAcceptWord(DragWordPayload payload, String word) {
    if (_tokenIsCorrectByIndex[payload.tokenIndex] == true) {
      return false;
    }
    final existing = _matchedByTarget[word] ?? const [];
    return !existing.any((item) => item.tokenIndex == payload.tokenIndex);
  }

  @override
  Widget build(BuildContext context) {
    final round = _round;
    return Column(
      children: [
        GameScoreboard(
          correctValues: _correctValues,
          incorrectValues: _incorrectValues,
        ),
        Row(
          children: [
            const Expanded(child: SizedBox.shrink()),
            FilledButton.tonalIcon(
              onPressed: _newRound,
              icon: const Icon(Icons.shuffle),
              label: const Text('New Sentence'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: round == null
              ? Center(
                  child: Text(
                    'No structure sentence available for Drag.',
                    style: halfTextStyle(
                      Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    Widget buildSentence() {
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return Center(
                                child: _buildSentenceWords(
                                  round.sentence,
                                  constraints.maxWidth,
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    }

                    Widget buildTargets() {
                      if (round.removedWords.isEmpty) {
                        return Center(
                          child: Text(
                            'No parenthesized words found.',
                            style: halfTextStyle(
                              Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        );
                      }
                      return ListView.separated(
                        shrinkWrap: !isWideLayout(constraints.maxWidth),
                        physics: isWideLayout(constraints.maxWidth)
                            ? const ClampingScrollPhysics()
                            : const NeverScrollableScrollPhysics(),
                        itemCount: round.removedWords.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) =>
                            _buildWordChip(round.removedWords[index]),
                      );
                    }

                    if (isWideLayout(constraints.maxWidth)) {
                      return Row(
                        children: [
                          Expanded(flex: 3, child: buildSentence()),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: buildTargets(),
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          buildSentence(),
                          const SizedBox(height: 12),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: buildTargets(),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// Renders the sentence as draggable tokens sized to the available width.
  Widget _buildSentenceWords(String sentence, double maxWidth) {
    final baseStyle = halfTextStyle(
      Theme.of(context).textTheme.titleMedium,
    ).copyWith(fontSize: 25);
    final fittedFontSize = fitFontSizeToWidth(
      text: sentence,
      baseStyle: baseStyle,
      maxWidth: maxWidth,
    );
    final wordStyle = baseStyle.copyWith(fontSize: fittedFontSize);
    final usedTokenIndexes = _tokenIsCorrectByIndex.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toSet();

    return Wrap(
      alignment: WrapAlignment.center,
      runAlignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < _tokens.length; i++)
          _buildDraggableToken(
            token: _tokens[i],
            tokenIndex: i,
            textStyle: wordStyle,
            isUsed: usedTokenIndexes.contains(i),
            isIncorrect: _tokenIsCorrectByIndex[i] == false,
          ),
      ],
    );
  }

  /// Renders one sentence token, making it draggable while unused.
  Widget _buildDraggableToken({
    required DragSentenceToken token,
    required int tokenIndex,
    required TextStyle textStyle,
    required bool isUsed,
    required bool isIncorrect,
  }) {
    final matchedTarget = _matchedTargetByTokenIndex[tokenIndex];
    final matchedColor = matchedTarget == null
        ? null
        : _targetColors[matchedTarget];

    if (isUsed) {
      return Text(
        token.display,
        style: textStyle.copyWith(
          color: matchedColor ?? Colors.green.shade700,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    final payload = DragWordPayload(
      tokenIndex: tokenIndex,
      display: token.display,
      normalized: token.normalized,
    );

    return Draggable<DragWordPayload>(
      data: payload,
      maxSimultaneousDrags: 1,
      onDragEnd: (details) {
        if (!details.wasAccepted) {
          _triggerMissFeedback();
        }
      },
      feedback: Material(
        color: Colors.transparent,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color:
                matchedColor ?? Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              token.display,
              style: textStyle.copyWith(
                color: matchedColor == null
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : readableTextColorOn(matchedColor),
              ),
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: Text(
          token.display,
          style: textStyle.copyWith(
            color: isIncorrect ? Colors.red.shade700 : matchedColor,
          ),
        ),
      ),
      child: Text(
        token.display,
        style: textStyle.copyWith(
          color: isIncorrect ? Colors.red.shade700 : matchedColor,
          fontWeight: isUsed ? FontWeight.w700 : textStyle.fontWeight,
        ),
      ),
    );
  }

  /// Renders a drop target that accepts a matching token from the sentence.
  Widget _buildWordChip(String word) {
    final theme = Theme.of(context);
    final matchedPayloads = _matchedByTarget[word] ?? const [];
    final isMatched = matchedPayloads.isNotEmpty;
    final backgroundColor = _targetBackgroundColor(word, isMatched: isMatched);
    final foregroundColor = readableTextColorOn(backgroundColor);
    final baseBorderColor = _targetColors[word] ?? theme.colorScheme.outline;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: DragTarget<DragWordPayload>(
        onWillAcceptWithDetails: (details) =>
            _canAcceptWord(details.data, word),
        onAcceptWithDetails: (details) => _onWordDropped(details.data, word),
        builder: (context, candidateData, rejectedData) {
          final isHoveringAccepted = candidateData.isNotEmpty;
          final isHoveringRejected = rejectedData.isNotEmpty;
          final showMissFlash = _showMissFeedback && !isMatched;
          final borderColor = isHoveringRejected
              ? Colors.red.shade400
              : (showMissFlash
                    ? Colors.red.shade300
                    : (isHoveringAccepted
                          ? theme.colorScheme.primary
                          : baseBorderColor));
          final fillColor = isHoveringRejected
              ? Colors.red.withValues(alpha: 0.12)
              : (showMissFlash
                    ? Colors.red.withValues(alpha: 0.08)
                    : (isHoveringAccepted
                          ? backgroundColor.withValues(alpha: 0.34)
                          : backgroundColor));

          String? statusText;
          Color? statusColor;
          if (isMatched) {
            statusText =
                'Matched: ${matchedPayloads.map((p) => p.display).join(', ')}';
            statusColor = foregroundColor;
          } else if (isHoveringAccepted) {
            statusText = 'Drop here';
            statusColor = foregroundColor;
          } else if (isHoveringRejected) {
            statusText = 'Wrong match';
            statusColor = Colors.red.shade800;
          }

          return AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            decoration: BoxDecoration(
              border: Border.all(color: borderColor, width: isMatched ? 2 : 1),
              borderRadius: BorderRadius.circular(8),
              color: fillColor,
            ),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  word,
                  textAlign: TextAlign.left,
                  style: halfTextStyle(
                    theme.textTheme.titleMedium,
                    fontWeight: FontWeight.w700,
                  ).copyWith(color: foregroundColor),
                ),
                if (statusText != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    statusText,
                    style: halfTextStyle(
                      theme.textTheme.bodySmall,
                    ).copyWith(color: statusColor),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
