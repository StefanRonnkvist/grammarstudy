import 'package:flutter/material.dart';

import '../../features/games/presentation/games_tab.dart';
import '../../features/grammar/presentation/grammar_tab.dart';
import '../../features/help/presentation/help_tab.dart';
import '../../features/information/presentation/information_tab.dart';
import '../../features/sentence/presentation/sentence_tab.dart';
import '../../features/structure/presentation/structure_tab.dart';

/// Renders the content pane for each top-level study area.
class HomeTabView extends StatelessWidget {
  const HomeTabView({super.key});

  @override
  Widget build(BuildContext context) {
    return const TabBarView(
      children: [
        GamesTab(),
        GrammarTab(),
        StructureTab(),
        SentenceTab(),
        HelpTab(),
        InformationTab(),
      ],
    );
  }
}
