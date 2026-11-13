import 'package:flutter/material.dart';

/// Compact running score shared by the three game screens.
class GameScoreboard extends StatelessWidget {
  const GameScoreboard({
    super.key,
    required this.correctValues,
    required this.incorrectValues,
  });

  final int correctValues;
  final int incorrectValues;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Correct: $correctValues', style: style),
          const SizedBox(width: 20),
          Text('Incorrect: $incorrectValues', style: style),
        ],
      ),
    );
  }
}
