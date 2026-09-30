import 'package:flutter/material.dart';

import '../../../core/widgets/searchable_collection_view.dart';
import '../../../data/study_database_service.dart';

/// Provides searchable access to sentences that retain grammar annotations.
class StructureTab extends StatelessWidget {
  const StructureTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SearchableCollectionView(
      futureFactory: () =>
          StudyDatabaseService().readDictionarySentencesContextTagged(),
      loadingMessage: 'Loading structure data...',
      errorMessagePrefix: 'Failed to load structure file',
      emptyMessage: 'No structure entries found.',
      noMatchesMessage: 'No matching structure entries.',
      searchHint: 'Search structure entries...',
    );
  }
}
