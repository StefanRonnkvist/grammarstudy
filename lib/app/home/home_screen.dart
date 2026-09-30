import 'package:flutter/material.dart';

import '../../core/layout/responsive.dart';
import '../../data/study_database_service.dart';
import 'home_tab_view.dart';
import 'home_tabs.dart';
import 'web_storage_notice.dart';

/// Hosts the six primary areas and application-wide utility actions.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  /// Shows loaded data counts and offers a bundled-data restore action.
  Future<void> _showDatabaseDiagnostics(BuildContext context) async {
    final databaseService = StudyDatabaseService();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Database Diagnostics'),
          content: FutureBuilder<StudyDatabaseSummary>(
            future: databaseService.readSummary(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  width: 280,
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }

              if (snapshot.hasError) {
                return SizedBox(
                  width: 280,
                  child: Text('Failed to read summary: ${snapshot.error}'),
                );
              }

              final summary = snapshot.data;
              if (summary == null) {
                return const SizedBox(
                  width: 280,
                  child: Text('No summary available.'),
                );
              }

              return SizedBox(
                width: 320,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Schema version: ${summary.schemaVersion ?? '-'}'),
                      const SizedBox(height: 8),
                      Text('Grammar types: ${summary.grammarTypesCount}'),
                      Text('Grammar values: ${summary.grammarValuesCount}'),
                      const SizedBox(height: 8),
                      Text('Prev-word types: ${summary.previousWordTypesCount}'),
                      Text(
                        'Prev-word values: ${summary.previousWordValuesCount}',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Prev-word smart types: '
                        '${summary.previousWordSmartCapitalizedTypesCount}',
                      ),
                      Text(
                        'Prev-word smart values: '
                        '${summary.previousWordSmartCapitalizedValuesCount}',
                      ),
                      const SizedBox(height: 8),
                      Text('Source sentences: ${summary.sourceSentencesCount}'),
                      Text(
                        'Tagged sentences: ${summary.taggedSentencesCount}',
                      ),
                      Text(
                        'Word type definitions: '
                        '${summary.wordTypeDefinitionsCount}',
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();

                final messenger = ScaffoldMessenger.of(context);
                messenger.showSnackBar(
                  const SnackBar(content: Text('Restoring bundled database...')),
                );

                try {
                  await databaseService.restoreBundledDatabase();
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Database restored from bundled data.'),
                    ),
                  );
                } catch (error) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Restore failed: $error')),
                  );
                }
              },
              child: const Text('Restore'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: homeTabLabels.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Grammar Study'),
          actions: [
            IconButton(
              tooltip: 'DB diagnostics',
              onPressed: () => _showDatabaseDiagnostics(context),
              icon: const Icon(Icons.storage_outlined),
            ),
            PopupMenuButton<ThemeMode>(
              tooltip: 'Theme',
              initialValue: themeMode,
              onSelected: onThemeModeChanged,
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: ThemeMode.system,
                  child: Text('System theme'),
                ),
                PopupMenuItem(
                  value: ThemeMode.light,
                  child: Text('Light theme'),
                ),
                PopupMenuItem(value: ThemeMode.dark, child: Text('Dark theme')),
              ],
              icon: const Icon(Icons.color_lens_outlined),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(kTextTabBarHeight),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return TabBar(
                  isScrollable: shouldUseScrollableTabs(
                    context,
                    homeTabLabels,
                    constraints.maxWidth,
                  ),
                  tabs: [
                    for (final label in homeTabLabels) Tab(text: label),
                  ],
                );
              },
            ),
          ),
        ),
        body: const Column(
          children: [WebStorageNotice(), Expanded(child: HomeTabView())],
        ),
      ),
    );
  }
}
