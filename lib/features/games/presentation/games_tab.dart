import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/widgets/status_views.dart';
import '../../../data/study_database_service.dart';
import '../crossword/domain/crossword_generator.dart';
import '../crossword/domain/crossword_models.dart';
import '../crossword/presentation/crossword_game.dart';
import '../drag/presentation/drag_game.dart';
import '../slide/presentation/slide_game.dart';

/// Shared study data every game draws from.
class GameData {
  const GameData({
    required this.candidates,
    required this.sentences,
    required this.structureSentences,
    required this.definitionsByWordType,
  });

  /// Grid-friendly vocabulary words shared by the crossword and slide games.
  final List<CrosswordCandidate> candidates;
  final List<String> sentences;
  final List<String> structureSentences;
  final Map<String, String> definitionsByWordType;
}

/// Coordinates the crossword, slide, and drag games over shared study data.
class GamesTab extends StatefulWidget {
  const GamesTab({super.key});

  @override
  State<GamesTab> createState() => _GamesTabState();
}

class _GamesTabState extends State<GamesTab> {
  static const int _gameCount = 3;
  static const int _defaultGameIndex = 2;

  late Future<GameData> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadData();
  }

  /// Loads every dataset the games need concurrently.
  Future<GameData> _loadData() async {
    final databaseService = StudyDatabaseService();

    final results = await Future.wait([
      databaseService.readGrammarTagValues(),
      databaseService.readDictionarySentencesSource(),
      databaseService.readDictionarySentencesContextTagged(),
      databaseService.readWordTypeDefinitions(),
    ]);

    final valuesByType = results[0] as Map<String, List<String>>;
    final candidates = await buildCrosswordCandidates(valuesByType);

    return GameData(
      candidates: candidates,
      sentences: results[1] as List<String>,
      structureSentences: results[2] as List<String>,
      definitionsByWordType: results[3] as Map<String, String>,
    );
  }

  void _reload() {
    setState(() {
      _loadFuture = _loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<GameData>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView(message: 'Loading game data...');
        }

        if (snapshot.hasError) {
          return ErrorRetryView(
            message: 'Failed to load game data: ${snapshot.error}',
            onRetry: _reload,
          );
        }

        final data = snapshot.data;
        if (data == null) {
          return const EmptyStateView(message: 'No game data available.');
        }

        return DefaultTabController(
          length: _gameCount,
          initialIndex: _defaultGameIndex,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: 'Crossword'),
                    Tab(text: 'Slide'),
                    Tab(text: 'Drag'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      CrosswordGame(
                        candidates: data.candidates,
                        sentences: data.sentences,
                        showSnackBar: (message) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(message)));
                        },
                      ),
                      SlideGame(
                        candidates: data.candidates,
                        sentences: data.sentences,
                        definitionsByWordType: data.definitionsByWordType,
                      ),
                      DragGame(structureSentences: data.structureSentences),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
