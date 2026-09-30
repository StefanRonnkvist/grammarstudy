import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/layout/responsive.dart';
import '../../../core/search/search_filter.dart';
import '../../../core/widgets/status_views.dart';
import '../../../data/study_database_service.dart';
import 'grammar_value_dialog.dart';

/// Browses vocabulary by grammar category and links values to tagged examples.
///
/// The last selected category is remembered across launches.
class GrammarTab extends StatefulWidget {
  const GrammarTab({super.key});

  @override
  State<GrammarTab> createState() => _GrammarTabState();
}

class _GrammarTabState extends State<GrammarTab> {
  static const String _selectedTabPrefKey = 'selected_grammar_tab_index';

  final StudyDatabaseService _databaseService = StudyDatabaseService();

  bool _isLoading = true;
  String? _loadError;
  String _searchQuery = '';

  Map<String, List<String>> _valuesByCategory = const {};
  Map<String, String> _definitionsByWordType = const {};
  List<String> _categories = const [];
  int _selectedCategoryIndex = 0;
  List<String>? _taggedSentencesCache;

  @override
  void initState() {
    super.initState();
    _restoreSelectedCategory();
    _loadWordTypeDefinitions();
    _loadCategories();
  }

  /// Loads optional definitions independently so missing definitions do not
  /// prevent the grammar vocabulary from being used.
  Future<void> _loadWordTypeDefinitions() async {
    try {
      final definitions = await _databaseService.readWordTypeDefinitions();
      if (!mounted) {
        return;
      }
      setState(() {
        _definitionsByWordType = definitions;
      });
    } catch (_) {
      // Keep the tab usable even if definitions are missing or malformed.
    }
  }

  Future<void> _restoreSelectedCategory() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIndex = prefs.getInt(_selectedTabPrefKey);
    if (savedIndex == null || !mounted) {
      return;
    }
    setState(() {
      _selectedCategoryIndex = math.max(0, savedIndex);
    });
  }

  Future<void> _persistSelectedCategory(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_selectedTabPrefKey, index);
  }

  /// Loads category values and reconciles the saved index with them.
  Future<void> _loadCategories() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }

    try {
      final parsed = await _databaseService.readGrammarTagValues();
      if (!mounted) {
        return;
      }

      final categories = parsed.keys.toList(growable: false);
      setState(() {
        _valuesByCategory = parsed;
        _categories = categories;
        _selectedCategoryIndex = categories.isEmpty
            ? 0
            : math.min(_selectedCategoryIndex, categories.length - 1);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadError = '$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Lazily loads tagged sentences once for all value-match dialogs.
  Future<List<String>> _loadTaggedSentences() async {
    final cached = _taggedSentencesCache;
    if (cached != null) {
      return cached;
    }
    final values = await _databaseService
        .readDictionarySentencesContextTagged();
    _taggedSentencesCache = values;
    return values;
  }

  String? _definitionForCategory(String category) {
    final normalized = category.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    return _definitionsByWordType[normalized];
  }

  Future<void> _showValueMatches(String value) async {
    try {
      final taggedSentences = await _loadTaggedSentences();
      if (!mounted) {
        return;
      }
      await showGrammarValueMatchesDialog(
        context,
        value: value,
        taggedSentences: taggedSentences,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to find structure matches: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LoadingView(message: 'Loading grammar categories...');
    }

    if (_loadError != null) {
      return ErrorRetryView(
        message: 'Failed to load grammar values: $_loadError',
        onRetry: _loadCategories,
      );
    }

    if (_categories.isEmpty) {
      return const EmptyStateView(message: 'No grammar entries found.');
    }

    return DefaultTabController(
      length: _categories.length,
      initialIndex: math.min(_selectedCategoryIndex, _categories.length - 1),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Builder(
              builder: (context) {
                return TabBar(
                  isScrollable: shouldScrollEstimatedTabs(context, _categories),
                  onTap: (index) {
                    setState(() {
                      _selectedCategoryIndex = index;
                    });
                    _persistSelectedCategory(index);
                  },
                  tabs: [
                    for (final category in _categories) Tab(text: category),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildCategoryContent(_categories[_selectedCategoryIndex]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryContent(String category) {
    final values = _valuesByCategory[category] ?? const <String>[];
    final definition = _definitionForCategory(category);
    final filteredValues = filterAndSortItems(values, _searchQuery);

    if (values.isEmpty) {
      return EmptyStateView(message: 'No values found for $category.');
    }

    return Column(
      children: [
        if (definition != null) ...[
          _CategoryDefinitionCard(category: category, definition: definition),
          const SizedBox(height: 12),
        ],
        SearchField(
          hintText: 'Search grammar values...',
          onChanged: (value) => setState(() => _searchQuery = value),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: filteredValues.isEmpty
              ? const EmptyStateView(
                  message: 'No matching grammar values found.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: filteredValues.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final value = filteredValues[index];
                    return NumberedListTile(
                      index: index,
                      title: value,
                      onTap: () => _showValueMatches(value),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Shows the definition of the selected grammar category.
class _CategoryDefinitionCard extends StatelessWidget {
  const _CategoryDefinitionCard({
    required this.category,
    required this.definition,
  });

  final String category;
  final String definition;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.menu_book_outlined,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                category,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(definition, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
