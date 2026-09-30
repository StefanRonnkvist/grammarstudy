import 'package:flutter/material.dart';

import '../../../core/widgets/searchable_collection_view.dart';
import '../../../data/study_database_service.dart';

/// Provides searchable access to plain, unannotated sentence examples.
class SentenceTab extends StatelessWidget {
  const SentenceTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SearchableCollectionView(
      futureFactory: () =>
          StudyDatabaseService().readDictionarySentencesSource(),
      loadingMessage: 'Loading sentence data...',
      errorMessagePrefix: 'Failed to load sentence file',
      emptyMessage: 'No sentence entries found.',
      noMatchesMessage: 'No matching sentences found.',
      searchHint: 'Search sentences...',
    );
  }
}
