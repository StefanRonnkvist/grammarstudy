import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/assets_database_service.dart';
import 'help_tab.dart';
import 'information_tab.dart';

/// Filters case-insensitively, ranks prefix matches first, then sorts
/// alphabetically without changing the source list.
List<String> _filterAndSortItems(List<String> source, String query) {
  final normalizedQuery = query.trim().toLowerCase();

  final filtered = normalizedQuery.isEmpty
      ? List<String>.from(source)
      : source
            .where((item) => item.toLowerCase().contains(normalizedQuery))
            .toList(growable: false);

  filtered.sort((a, b) {
    final aLower = a.toLowerCase();
    final bLower = b.toLowerCase();

    if (normalizedQuery.isNotEmpty) {
      final aStartsWith = aLower.startsWith(normalizedQuery);
      final bStartsWith = bLower.startsWith(normalizedQuery);
      if (aStartsWith != bStartsWith) {
        return aStartsWith ? -1 : 1;
      }
    }

    return aLower.compareTo(bLower);
  });
  return filtered;
}

/// Measures rendered labels to decide whether the top tab bar must scroll.
bool _shouldUseScrollableTopTabs(
  BuildContext context,
  List<String> labels,
  double maxWidth,
) {
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
    requiredWidth += painter.width + 32;
  }

  return requiredWidth > maxWidth;
}

/// Displays database counts and offers a bundled-data restore action.
Future<void> _showAssetsDbDiagnosticsDialog(BuildContext context) async {
  final assetsDatabaseService = AssetsDatabaseService();

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Assets DB Diagnostics'),
        content: FutureBuilder<AssetsDatabaseSummary>(
          future: assetsDatabaseService.readSummary(),
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
                child: Text('Failed to read DB summary: ${snapshot.error}'),
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
                      'Prev-word smart types: ${summary.previousWordSmartCapitalizedTypesCount}',
                    ),
                    Text(
                      'Prev-word smart values: ${summary.previousWordSmartCapitalizedValuesCount}',
                    ),
                    const SizedBox(height: 8),
                    Text('Source sentences: ${summary.sourceSentencesCount}'),
                    Text('Tagged sentences: ${summary.taggedSentencesCount}'),
                    Text(
                      'Word type definitions: ${summary.wordTypeDefinitionsCount}',
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
                await assetsDatabaseService.restoreBundledDatabase();
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Database restored from bundled build data.'),
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

/// Hosts the six primary areas and application-wide utility actions.
class CsvButtonsScreen extends StatefulWidget {
  const CsvButtonsScreen({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<CsvButtonsScreen> createState() => _CsvButtonsScreenState();
}

class _CsvButtonsScreenState extends State<CsvButtonsScreen> {
  bool _showWebDatabaseNotice = kIsWeb;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Grammer Study'),
          actions: [
            IconButton(
              tooltip: 'DB diagnostics',
              onPressed: () => _showAssetsDbDiagnosticsDialog(context),
              icon: const Icon(Icons.storage_outlined),
            ),
            PopupMenuButton<ThemeMode>(
              tooltip: 'Theme',
              initialValue: widget.themeMode,
              onSelected: widget.onThemeModeChanged,
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
                const labels = [
                  'Games',
                  'Grammar',
                  'Structure',
                  'Sentence',
                  'Help',
                  'Information',
                ];
                final isScrollable = _shouldUseScrollableTopTabs(
                  context,
                  labels,
                  constraints.maxWidth,
                );

                return TabBar(
                  isScrollable: isScrollable,
                  tabs: const [
                    Tab(text: 'Games'),
                    Tab(text: 'Grammar'),
                    Tab(text: 'Structure'),
                    Tab(text: 'Sentence'),
                    Tab(text: 'Help'),
                    Tab(text: 'Information'),
                  ],
                );
              },
            ),
          ),
        ),
        body: Column(
          children: [
            if (_showWebDatabaseNotice)
              Material(
                color: Theme.of(context).colorScheme.error,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Web notice: study data and preferences use browser storage. Clearing site data removes them; bundled study content is loaded again when the app starts.',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onError,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Dismiss notice',
                          onPressed: () {
                            setState(() {
                              _showWebDatabaseNotice = false;
                            });
                          },
                          icon: const Icon(Icons.close),
                          color: Theme.of(context).colorScheme.onError,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Expanded(
              child: TabBarView(
                children: [
                  _GameTab(),
                  _GrammarTab(),
                  _StructureTab(),
                  _SentenceTab(),
                  const HelpTab(),
                  InformationTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Browses vocabulary by grammar category and links values to tagged examples.
class _GrammarTab extends StatefulWidget {
  const _GrammarTab();

  @override
  State<_GrammarTab> createState() => _GrammarTabState();
}

class _GrammarTabState extends State<_GrammarTab> {
  static const String _selectedTabPrefKey = 'selected_grammar_tab_index';

  final AssetsDatabaseService _assetsDatabaseService = AssetsDatabaseService();

  bool _isLoading = true;
  String? _loadError;
  String _searchQuery = '';

  Map<String, List<String>> _grammarValuesByTag = const {};
  Map<String, String> _wordTypeDefinitionsByTag = const {};
  List<String> _grammarTabs = const [];
  int _selectedGrammarTabIndex = 0;
  List<String>? _structureValuesCache;

  @override
  void initState() {
    super.initState();
    _restoreSelectedGrammarTabPreference();
    _loadWordTypeDefinitions();
    _loadGrammarValues();
  }

  /// Loads optional definitions independently so missing definitions do not
  /// prevent the grammar vocabulary from being used.
  Future<void> _loadWordTypeDefinitions() async {
    try {
      final parsed = await _assetsDatabaseService.readWordTypeDefinitions();

      if (!mounted) {
        return;
      }

      setState(() {
        _wordTypeDefinitionsByTag = parsed;
      });
    } catch (_) {
      // Keep the screen usable even if definitions file is missing or malformed.
    }
  }

  String? _wordTypeDefinitionForTab(String grammarKey) {
    final normalizedKey = grammarKey.trim().toLowerCase();
    if (normalizedKey.isEmpty) {
      return null;
    }
    return _wordTypeDefinitionsByTag[normalizedKey];
  }

  bool _useScrollableGrammarTabs(BuildContext context, List<String> labels) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final estimatedTabWidth = labels
        .map((label) => (label.length * 10.0 * textScale) + 56.0)
        .fold<double>(0, (sum, width) => sum + width);

    return estimatedTabWidth > MediaQuery.sizeOf(context).width;
  }

  Future<void> _persistGrammarTabPreference(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_selectedTabPrefKey, index);
  }

  /// Restores the last grammar tab before loaded categories clamp the index to
  /// the current category count.
  Future<void> _restoreSelectedGrammarTabPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIndex = prefs.getInt(_selectedTabPrefKey);
    if (savedIndex == null || !mounted) {
      return;
    }

    setState(() {
      _selectedGrammarTabIndex = math.max(0, savedIndex);
    });
  }

  /// Loads category values and reconciles the persisted tab index with them.
  Future<void> _loadGrammarValues() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }

    try {
      final parsed = await _assetsDatabaseService.readGrammarTagValues();

      final tabs = parsed.keys.toList(growable: false);
      if (!mounted) {
        return;
      }

      setState(() {
        _grammarValuesByTag = parsed;
        _grammarTabs = tabs;
        if (_grammarTabs.isEmpty) {
          _selectedGrammarTabIndex = 0;
        } else {
          _selectedGrammarTabIndex = math.min(
            _selectedGrammarTabIndex,
            _grammarTabs.length - 1,
          );
        }
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
  Future<List<String>> _loadStructureValues() async {
    final cachedValues = _structureValuesCache;
    if (cachedValues != null) {
      return cachedValues;
    }

    final values = await _assetsDatabaseService
        .readDictionarySentencesContextTagged();

    _structureValuesCache = values;
    return values;
  }

  /// Builds a case-insensitive matcher; single words require word boundaries,
  /// while phrases are matched literally.
  RegExp _matchPattern(String word) {
    final normalizedWord = word.trim();
    if (normalizedWord.contains(' ')) {
      return RegExp(RegExp.escape(normalizedWord), caseSensitive: false);
    }

    return RegExp(
      '\\b${RegExp.escape(normalizedWord)}\\b',
      caseSensitive: false,
    );
  }

  bool _containsSpecificWord(String text, String word) {
    final normalizedText = text.trim();
    final normalizedWord = word.trim();

    if (normalizedText.isEmpty || normalizedWord.isEmpty) {
      return false;
    }

    return _matchPattern(normalizedWord).hasMatch(normalizedText);
  }

  /// Removes parenthesized grammar annotations and repairs punctuation spacing.
  String _extractPlainSentence(String taggedSentence) {
    return taggedSentence
        .replaceAll(RegExp(r'\s*\([^\)]*\)'), '')
        .replaceAll(RegExp(r'\s+([,.;:!?])'), r'$1')
        .trim();
  }

  /// Splits a sentence into styled spans so every matched value is emphasized.
  TextSpan _buildHighlightedSentence(
    BuildContext context,
    String sentence,
    String value,
  ) {
    final baseStyle = Theme.of(context).textTheme.bodyMedium;
    final highlightStyle = baseStyle?.copyWith(
      fontWeight: FontWeight.bold,
      color: Theme.of(context).colorScheme.primary,
    );

    final pattern = _matchPattern(value);
    final matches = pattern.allMatches(sentence).toList(growable: false);
    if (matches.isEmpty) {
      return TextSpan(text: sentence, style: baseStyle);
    }

    final children = <TextSpan>[];
    var cursor = 0;
    for (final match in matches) {
      if (match.start > cursor) {
        children.add(
          TextSpan(
            text: sentence.substring(cursor, match.start),
            style: baseStyle,
          ),
        );
      }

      children.add(
        TextSpan(
          text: sentence.substring(match.start, match.end),
          style: highlightStyle,
        ),
      );
      cursor = match.end;
    }

    if (cursor < sentence.length) {
      children.add(
        TextSpan(text: sentence.substring(cursor), style: baseStyle),
      );
    }

    return TextSpan(children: children, style: baseStyle);
  }

  /// Finds tagged examples containing a selected value and lets each row toggle
  /// independently between its plain and annotated forms.
  Future<void> _showStructureMatchesDialog(String value) async {
    try {
      final structureValues = await _loadStructureValues();
      final matches = structureValues
          .where((entry) => _containsSpecificWord(entry, value))
          .toList(growable: false);

      if (!mounted) {
        return;
      }

      await showDialog<void>(
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
                            final plainSentence = _extractPlainSentence(match);

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
                                      _buildHighlightedSentence(
                                        context,
                                        match,
                                        value,
                                      ),
                                    )
                                  : Text(plainSentence),
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
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Loading grammar categories...'),
          ],
        ),
      );
    }

    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Failed to load grammar values: $_loadError',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: _loadGrammarValues,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_grammarTabs.isEmpty) {
      return const Center(child: Text('No grammar entries found.'));
    }

    return DefaultTabController(
      length: _grammarTabs.length,
      initialIndex: math.min(_selectedGrammarTabIndex, _grammarTabs.length - 1),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Builder(
              builder: (context) {
                final labels = _grammarTabs;
                final isScrollable = _useScrollableGrammarTabs(context, labels);

                return TabBar(
                  isScrollable: isScrollable,
                  onTap: (index) {
                    setState(() {
                      _selectedGrammarTabIndex = index;
                    });
                    _persistGrammarTabPreference(index);
                  },
                  tabs: [
                    for (final grammarTab in _grammarTabs)
                      Tab(text: grammarTab),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildGrammarTabContent(
                _grammarTabs[_selectedGrammarTabIndex],
                _searchQuery,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrammarTabContent(String grammarKey, String query) {
    final values = _grammarValuesByTag[grammarKey] ?? const <String>[];
    final wordTypeDefinition = _wordTypeDefinitionForTab(grammarKey);
    final filteredValues = _filterAndSortItems(values, query);

    if (values.isEmpty) {
      return Center(child: Text('No values found for $grammarKey.'));
    }

    return Column(
      children: [
        if (wordTypeDefinition != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.menu_book_outlined,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      grammarKey,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  wordTypeDefinition,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
          decoration: const InputDecoration(
            hintText: 'Search grammar values...',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: filteredValues.isEmpty
              ? const Center(child: Text('No matching grammar values found.'))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: filteredValues.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final value = filteredValues[index];
                    return ListTile(
                      leading: CircleAvatar(child: Text('${index + 1}')),
                      title: InkWell(
                        onTap: () => _showStructureMatchesDialog(value),
                        child: Text(
                          value,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Provides searchable access to sentences that retain grammar annotations.
class _StructureTab extends StatefulWidget {
  const _StructureTab();

  @override
  State<_StructureTab> createState() => _StructureTabState();
}

class _StructureTabState extends State<_StructureTab> {
  static const String _structureSourceLabel =
      AssetsDatabaseService.dictionarySentencesContextTaggedKey;
  final AssetsDatabaseService _assetsDatabaseService = AssetsDatabaseService();

  late Future<List<String>> _itemsFuture;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _itemsFuture = _loadItems();
  }

  void _reloadItems() {
    setState(() {
      _itemsFuture = _loadItems();
    });
  }

  Future<List<String>> _loadItems() async {
    return _assetsDatabaseService.readDictionarySentencesContextTagged();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: _itemsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('Loading structure data...'),
                SizedBox(height: 4),
                Text(_structureSourceLabel, textAlign: TextAlign.center),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Failed to load structure file: ${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: _reloadItems,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final items = snapshot.data ?? const <String>[];
        if (items.isEmpty) {
          return const Center(child: Text('No structure entries found.'));
        }

        final filteredItems = _filterAndSortItems(items, _searchQuery);
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              TextField(
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: const InputDecoration(
                  hintText: 'Search structure entries...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: filteredItems.isEmpty
                    ? const Center(
                        child: Text('No matching structure entries.'),
                      )
                    : ListView.separated(
                        itemCount: filteredItems.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          return ListTile(
                            leading: CircleAvatar(child: Text('${index + 1}')),
                            title: Text(filteredItems[index]),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Coordinates the crossword, slide, and drag games over shared study data.
class _GameTab extends StatefulWidget {
  const _GameTab();

  @override
  State<_GameTab> createState() => _GameTabState();
}

class _GameTabState extends State<_GameTab> {
  static const int _gridSize = 13;
  static const int _targetWordCount = 6;
  static const int _generationAttempts = 40;

  final AssetsDatabaseService _assetsDatabaseService = AssetsDatabaseService();
  final math.Random _random = math.Random();
  final TextEditingController _cellInputController = TextEditingController();
  final FocusNode _cellInputFocusNode = FocusNode();

  late Future<void> _loadFuture;
  List<_CrosswordCandidate> _candidates = const [];
  List<String> _sentences = const [];
  List<String> _structureSentences = const [];
  Map<String, String> _wordTypeDefinitionsByTag = const {};
  _CrosswordPuzzle? _puzzle;
  _DragRound? _dragRound;
  List<_DragSentenceToken> _dragSentenceTokens = const [];
  Map<String, List<_DragWordPayload>> _dragCorrectByTarget =
      <String, List<_DragWordPayload>>{};
  Map<int, bool> _dragTokenIsCorrectByIndex = <int, bool>{};
  Map<int, String> _dragMatchedTargetByTokenIndex = <int, String>{};
  Map<String, Color> _dragTargetColors = <String, Color>{};
  bool _dragShowMissFeedback = false;
  Set<int> _revealedWordIds = <int>{};
  Map<String, String> _enteredLettersByCell = <String, String>{};
  String? _selectedCellKey;

  // Slide game state
  List<String> _slideWordLetters = [];
  List<bool> _slideRevealedLetters = [];
  List<_SlideVerticalWord> _slideVerticalWords = [];
  String _slideWordType = '';
  int _slideCorrectLetters = 0;
  bool _slideGameComplete = false;
  bool _slideHasSubmitted = false;
  double _slideTopLaneHeightPx = 0;
  double _slideSquareSizePx = 0;
  double _slideLetterHeightPx = 0;

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadData();
  }

  @override
  void dispose() {
    _cellInputController.dispose();
    _cellInputFocusNode.dispose();
    super.dispose();
  }

  /// Loads all game inputs concurrently, then creates an initial round for each
  /// game only after every dependent dataset is available.
  Future<void> _loadData() async {
    final grammarFuture = _loadGrammarCandidates();
    final sentenceFuture = _loadSentences();
    final structureSentenceFuture = _loadStructureSentences();
    final wordTypeDefinitionsFuture = _loadWordTypeDefinitions();

    final results = await Future.wait([
      grammarFuture,
      sentenceFuture,
      structureSentenceFuture,
      wordTypeDefinitionsFuture,
    ]);
    _candidates = results[0] as List<_CrosswordCandidate>;
    _sentences = results[1] as List<String>;
    _structureSentences = results[2] as List<String>;
    _wordTypeDefinitionsByTag = results[3] as Map<String, String>;

    _generatePuzzle();
    _generateSlideWord();
    _generateDragRound();
  }

  Future<Map<String, String>> _loadWordTypeDefinitions() async {
    return _assetsDatabaseService.readWordTypeDefinitions();
  }

  String? _slideWordTypeDefinition() {
    final normalized = _slideWordType.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    return _wordTypeDefinitionsByTag[normalized];
  }

  Future<void> _showSlideWordTypeDefinitionDialog() async {
    if (!mounted) {
      return;
    }

    final definition = _slideWordTypeDefinition();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(_slideWordType),
          content: Text(
            definition ?? 'Definition not available for this word type.',
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

  Future<void> _showSlideSentenceHintDialog() async {
    if (!mounted || _slideWordLetters.isEmpty) {
      return;
    }

    final slideWord = _slideWordLetters.join('').toLowerCase();
    final sentence = _sentenceForWord(slideWord);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Slide Hint'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Word type: $_slideWordType'),
              const SizedBox(height: 8),
              const Text('Sentence hint:'),
              const SizedBox(height: 6),
              Text(sentence),
            ],
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

  /// Builds unique crossword candidates from alphabetic words of grid-friendly
  /// length, retaining the grammar category as each candidate's clue.
  Future<List<_CrosswordCandidate>> _loadGrammarCandidates() async {
    final decoded = await _assetsDatabaseService.readGrammarTagValues();

    final candidates = <_CrosswordCandidate>[];
    final seenWords = <String>{};

    for (final entry in decoded.entries) {
      final type = entry.key.trim();
      if (type.isEmpty) {
        continue;
      }

      for (final rawValue in entry.value) {
        final normalized = _normalizeWord(rawValue);
        if (normalized.length < 3 || normalized.length > 9) {
          continue;
        }
        if (seenWords.add(normalized)) {
          candidates.add(_CrosswordCandidate(word: normalized, type: type));
        }
      }
    }

    return candidates;
  }

  Future<List<String>> _loadSentences() async {
    return _assetsDatabaseService.readDictionarySentencesSource();
  }

  Future<List<String>> _loadStructureSentences() async {
    return _assetsDatabaseService.readDictionarySentencesContextTagged();
  }

  String _normalizeWhitespace(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _normalizeDragWord(String word) {
    final normalized = _normalizeWhitespace(word);
    return normalized.toUpperCase();
  }

  String _normalizeDragComparable(String value) {
    final upper = _normalizeWhitespace(value).toUpperCase();
    return upper.replaceAll(RegExp(r'[^A-Z0-9 ]'), '');
  }

  /// Converts an annotated sentence into draggable display tokens.
  ///
  /// A parenthesized tag is attached to the preceding visible token as its
  /// expected drop target; the annotation itself is not displayed.
  List<_DragSentenceToken> _buildDragSentenceTokensFromRaw(String rawSentence) {
    final rawParts = RegExp(r'\([^()]*\)|\S+')
        .allMatches(rawSentence)
        .map((match) => match.group(0) ?? '')
        .toList(growable: false);

    final tokens = <_DragSentenceToken>[];

    for (final part in rawParts) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) {
        continue;
      }

      final isParenthetical = trimmed.startsWith('(') && trimmed.endsWith(')');
      if (isParenthetical) {
        if (tokens.isEmpty || trimmed.length < 3) {
          continue;
        }

        final inside = trimmed.substring(1, trimmed.length - 1);
        final expected = _normalizeDragWord(inside);
        if (expected.isEmpty) {
          continue;
        }

        final previous = tokens.last;
        tokens[tokens.length - 1] = _DragSentenceToken(
          display: previous.display,
          normalized: previous.normalized,
          expectedParentheticalNormalized: expected,
        );
        continue;
      }

      final normalized = _normalizeDragComparable(trimmed);
      if (normalized.isEmpty) {
        continue;
      }
      tokens.add(_DragSentenceToken(display: trimmed, normalized: normalized));
    }

    return tokens;
  }

  /// Selects a tagged sentence and resets all drag-match state for a new round.
  /// Repeated tag targets are deduplicated while token occurrences stay distinct.
  void _generateDragRound() {
    if (_structureSentences.isEmpty) {
      _dragRound = null;
      _dragSentenceTokens = const [];
      _dragCorrectByTarget = <String, List<_DragWordPayload>>{};
      _dragTokenIsCorrectByIndex = <int, bool>{};
      _dragMatchedTargetByTokenIndex = <int, String>{};
      _dragTargetColors = <String, Color>{};
      _dragShowMissFeedback = false;
      return;
    }

    final nonEmpty = _structureSentences
        .map(_normalizeWhitespace)
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    if (nonEmpty.isEmpty) {
      _dragRound = null;
      _dragSentenceTokens = const [];
      _dragCorrectByTarget = <String, List<_DragWordPayload>>{};
      _dragTokenIsCorrectByIndex = <int, bool>{};
      _dragMatchedTargetByTokenIndex = <int, String>{};
      _dragTargetColors = <String, Color>{};
      _dragShowMissFeedback = false;
      return;
    }

    final rawSentence = nonEmpty[_random.nextInt(nonEmpty.length)];
    final sentenceTokens = _buildDragSentenceTokensFromRaw(rawSentence);
    final removedWords =
        sentenceTokens
            .map((token) => token.expectedParentheticalNormalized)
            .whereType<String>()
            .where((word) => word.isNotEmpty)
            .toSet()
            .toList(growable: true)
          ..sort((a, b) => a.compareTo(b));
    final sentenceWithoutParentheses = _normalizeWhitespace(
      sentenceTokens.map((token) => token.display).join(' '),
    );

    _dragRound = _DragRound(
      sentence: sentenceWithoutParentheses,
      removedWords: removedWords,
    );
    _dragSentenceTokens = sentenceTokens;
    _dragCorrectByTarget = <String, List<_DragWordPayload>>{};
    _dragTokenIsCorrectByIndex = <int, bool>{};
    _dragMatchedTargetByTokenIndex = <int, String>{};
    _dragTargetColors = <String, Color>{
      for (var i = 0; i < removedWords.length; i++)
        removedWords[i]: _dragColorForIndex(i),
    };
    _dragShowMissFeedback = false;
  }

  Color _dragColorForIndex(int index) {
    const colors = <Color>[
      Color(0xFF1565C0),
      Color(0xFF2E7D32),
      Color(0xFF6A1B9A),
      Color(0xFFEF6C00),
      Color(0xFF00838F),
      Color(0xFF5D4037),
      Color(0xFF7B1FA2),
      Color(0xFF0277BD),
      Color(0xFF558B2F),
      Color(0xFF00897B),
      Color(0xFF3949AB),
      Color(0xFFC0CA33),
    ];

    return colors[index % colors.length];
  }

  Color _dragReadableOnColor(Color backgroundColor) {
    return ThemeData.estimateBrightnessForColor(backgroundColor) ==
            Brightness.dark
        ? Colors.white
        : Colors.black;
  }

  Color _dragTargetBackgroundColor(String word, {required bool isMatched}) {
    final baseColor =
        _dragTargetColors[word] ?? Theme.of(context).colorScheme.primary;
    return isMatched
        ? baseColor.withValues(alpha: 0.18)
        : baseColor.withValues(alpha: 0.28);
  }

  /// Briefly flashes unmatched targets after an incorrect or abandoned drag.
  Future<void> _triggerDragMissFeedback() async {
    if (!mounted || _dragShowMissFeedback) {
      return;
    }
    setState(() {
      _dragShowMissFeedback = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!mounted) {
      return;
    }
    setState(() {
      _dragShowMissFeedback = false;
    });
  }

  /// Creates a target that accepts unused sentence tokens and records only
  /// exact normalized matches against the token's parenthesized tag.
  Widget _buildDragWordChip(String word) {
    final theme = Theme.of(context);
    final matchedPayloads = _dragCorrectByTarget[word] ?? const [];
    final isMatched = matchedPayloads.isNotEmpty;
    final backgroundColor = _dragTargetBackgroundColor(
      word,
      isMatched: isMatched,
    );
    final foregroundColor = _dragReadableOnColor(backgroundColor);
    final baseBorderColor =
        _dragTargetColors[word] ?? theme.colorScheme.outline;
    final baseFillColor = backgroundColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: DragTarget<_DragWordPayload>(
        onWillAcceptWithDetails: (details) {
          final payload = details.data;
          if (_dragTokenIsCorrectByIndex[payload.tokenIndex] == true) {
            return false;
          }

          final existing = _dragCorrectByTarget[word] ?? const [];
          final alreadyInTarget = existing.any(
            (item) => item.tokenIndex == payload.tokenIndex,
          );
          if (alreadyInTarget) {
            return false;
          }

          return true;
        },
        onAcceptWithDetails: (details) {
          final payload = details.data;
          final tokenIndex = payload.tokenIndex;
          if (tokenIndex < 0 || tokenIndex >= _dragSentenceTokens.length) {
            return;
          }
          final expected =
              _dragSentenceTokens[tokenIndex].expectedParentheticalNormalized;
          final targetNormalized = _normalizeDragComparable(word);
          final isCorrect =
              expected != null &&
              expected.isNotEmpty &&
              expected == targetNormalized;

          setState(() {
            _dragTokenIsCorrectByIndex[tokenIndex] = isCorrect;
            if (isCorrect) {
              _dragMatchedTargetByTokenIndex[tokenIndex] = word;
              _dragCorrectByTarget =
                  Map<String, List<_DragWordPayload>>.from(_dragCorrectByTarget)
                    ..update(
                      word,
                      (existing) => [...existing, payload],
                      ifAbsent: () => [payload],
                    );
            }
          });

          if (!isCorrect) {
            _triggerDragMissFeedback();
          }
        },
        builder: (context, candidateData, rejectedData) {
          final isHoveringAccepted = candidateData.isNotEmpty;
          final isHoveringRejected = rejectedData.isNotEmpty;
          final showMissFlash = _dragShowMissFeedback && !isMatched;
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
                          : baseFillColor));
          final targetTextStyle = _halfTextStyle(
            theme.textTheme.titleMedium,
            fontWeight: FontWeight.w700,
          ).copyWith(color: foregroundColor);

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
                Text(word, textAlign: TextAlign.left, style: targetTextStyle),
                if (isMatched) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Matched: ${matchedPayloads.map((p) => p.display).join(', ')}',
                    style: _halfTextStyle(
                      theme.textTheme.bodySmall,
                    ).copyWith(color: foregroundColor),
                  ),
                ] else if (isHoveringAccepted) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Drop here',
                    style: _halfTextStyle(
                      theme.textTheme.bodySmall,
                    ).copyWith(color: foregroundColor),
                  ),
                ] else if (isHoveringRejected) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Wrong match',
                    style: _halfTextStyle(
                      theme.textTheme.bodySmall,
                    ).copyWith(color: Colors.red.shade800),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  /// Uses binary search to find the largest one-line font size that fits.
  double _fitFontSizeToWidth({
    required String text,
    required TextStyle baseStyle,
    required double maxWidth,
  }) {
    final trimmed = text.trim();
    final baseSize = baseStyle.fontSize ?? 14;
    if (trimmed.isEmpty || maxWidth <= 0) {
      return baseSize;
    }

    double low = 8;
    double high = baseSize;
    double best = low;

    for (var i = 0; i < 16; i++) {
      final mid = (low + high) / 2;
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: baseStyle.copyWith(fontSize: mid),
        ),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout();

      if (painter.width <= maxWidth) {
        best = mid;
        low = mid;
      } else {
        high = mid;
      }
    }

    return best;
  }

  Widget _buildDragSentenceWords({
    required String sentence,
    required double maxWidth,
  }) {
    final baseStyle = _halfTextStyle(
      Theme.of(context).textTheme.titleMedium,
    ).copyWith(fontSize: 25);
    final fittedFontSize = _fitFontSizeToWidth(
      text: sentence,
      baseStyle: baseStyle,
      maxWidth: maxWidth,
    );
    final wordStyle = baseStyle.copyWith(fontSize: fittedFontSize);
    final usedTokenIndexes = _dragTokenIsCorrectByIndex.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toSet();

    return Wrap(
      alignment: WrapAlignment.center,
      runAlignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < _dragSentenceTokens.length; i++)
          _buildDraggableSentenceToken(
            token: _dragSentenceTokens[i],
            tokenIndex: i,
            textStyle: wordStyle,
            isUsed: usedTokenIndexes.contains(i),
            isIncorrect: _dragTokenIsCorrectByIndex[i] == false,
          ),
      ],
    );
  }

  Widget _buildDraggableSentenceToken({
    required _DragSentenceToken token,
    required int tokenIndex,
    required TextStyle textStyle,
    required bool isUsed,
    required bool isIncorrect,
  }) {
    final matchedTarget = _dragMatchedTargetByTokenIndex[tokenIndex];
    final matchedColor = matchedTarget == null
        ? null
        : _dragTargetColors[matchedTarget];
    if (isUsed) {
      return Text(
        token.display,
        style: textStyle.copyWith(
          color: matchedColor ?? Colors.green.shade700,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    final payload = _DragWordPayload(
      tokenIndex: tokenIndex,
      display: token.display,
      normalized: token.normalized,
    );

    return Draggable<_DragWordPayload>(
      data: payload,
      maxSimultaneousDrags: 1,
      onDragEnd: (details) {
        if (!details.wasAccepted) {
          _triggerDragMissFeedback();
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
                    : _dragReadableOnColor(matchedColor),
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

  TextStyle _halfTextStyle(TextStyle? base, {FontWeight? fontWeight}) {
    final fallback = base ?? const TextStyle(fontSize: 14);
    final baseSize = fallback.fontSize ?? 14;
    return fallback.copyWith(
      fontSize: baseSize * 0.5,
      fontWeight: fontWeight ?? fallback.fontWeight,
    );
  }

  /// Reduces a value to lowercase ASCII letters for crossword generation.
  String _normalizeWord(String raw) {
    final lower = raw.trim().toLowerCase();
    return lower.replaceAll(RegExp(r'[^a-z]'), '');
  }

  /// Chooses a target word and one draggable vertical word per target letter.
  /// Each vertical word is guaranteed to contain the letter it must align.
  void _generateSlideWord() {
    if (_candidates.isEmpty) {
      _slideWordType = '';
      return;
    }
    final randomCandidate = _candidates[_random.nextInt(_candidates.length)];
    final randomWord = randomCandidate.word.toUpperCase();
    _slideWordType = randomCandidate.type;
    _slideWordLetters = randomWord.split('');
    _slideRevealedLetters = List<bool>.filled(randomWord.length, false);
    _slideCorrectLetters = 0;
    _slideGameComplete = false;
    _slideHasSubmitted = false;

    // Generate vertical words, one per horizontal square
    _slideVerticalWords = [];

    for (int i = 0; i < randomWord.length; i++) {
      final targetLetter = randomWord[i];

      // Find words containing this letter
      final matchingWords = _candidates
          .where((c) => c.word.toUpperCase().contains(targetLetter))
          .toList();

      if (matchingWords.isEmpty) continue;

      final verticalWord = matchingWords[_random.nextInt(matchingWords.length)]
          .word
          .toUpperCase();
      final letterPositionInVertical = verticalWord.indexOf(targetLetter);
      final isAbove = _random.nextBool();

      _slideVerticalWords.add(
        _SlideVerticalWord(
          word: verticalWord,
          horizontalIndex: i,
          letterIndexInWord: letterPositionInVertical,
          isAbove: isAbove,
          verticalOffset: 0.0,
        ),
      );
    }
  }

  void _slideVerticalWord(int index, double delta) {
    if (index < 0 || index >= _slideVerticalWords.length) return;
    setState(() {
      _slideVerticalWords[index].verticalOffset += delta;
      if (_slideHasSubmitted) {
        _slideHasSubmitted = false;
        _slideCorrectLetters = 0;
        _slideGameComplete = false;
        _slideRevealedLetters = List<bool>.filled(
          _slideWordLetters.length,
          false,
        );
      }
    });
  }

  /// Snaps a dragged column to the nearest letter-height boundary and clears a
  /// previous submission because the arrangement has changed.
  void _snapSlideVerticalWord(int index) {
    if (index < 0 || index >= _slideVerticalWords.length) return;
    setState(() {
      final cellStep = _slideLetterHeightPx > 0
          ? _slideLetterHeightPx
          : _slideSquareSizePx;
      if (cellStep > 0) {
        final currentOffset = _slideVerticalWords[index].verticalOffset;
        _slideVerticalWords[index].verticalOffset =
            (currentOffset / cellStep).roundToDouble() * cellStep;
      }
      if (_slideHasSubmitted) {
        _slideHasSubmitted = false;
        _slideCorrectLetters = 0;
        _slideGameComplete = false;
        _slideRevealedLetters = List<bool>.filled(
          _slideWordLetters.length,
          false,
        );
      }
    });
  }

  /// Returns the vertical-word letter whose row covers the target square center.
  String? _letterInsideHorizontalSquare(
    _SlideVerticalWord verticalWord,
    double squareCenterY,
    double letterHeight,
  ) {
    final relativeCenter = squareCenterY - verticalWord.verticalOffset;
    final letterIndex = (relativeCenter / letterHeight).floor();
    if (letterIndex < 0 || letterIndex >= verticalWord.word.length) {
      return null;
    }
    return verticalWord.word[letterIndex];
  }

  /// Evaluates every aligned slide column and reveals only correct positions.
  void _submitSlideGuess({
    required double topLaneHeight,
    required double squareSize,
    required double letterHeight,
  }) {
    final squareCenterY = topLaneHeight + (squareSize / 2);
    _slideCorrectLetters = 0;
    _slideGameComplete = true;

    for (int i = 0; i < _slideWordLetters.length; i++) {
      final verticalWord = _slideVerticalWords
          .where((v) => v.horizontalIndex == i)
          .cast<_SlideVerticalWord?>()
          .firstWhere((v) => v != null, orElse: () => null);
      final selectedLetter = verticalWord == null
          ? null
          : _letterInsideHorizontalSquare(
              verticalWord,
              squareCenterY,
              letterHeight,
            );
      final matched = selectedLetter == _slideWordLetters[i];

      if (matched) {
        _slideRevealedLetters[i] = true;
        _slideCorrectLetters++;
      } else {
        _slideRevealedLetters[i] = false;
        _slideGameComplete = false;
      }
    }

    _slideHasSubmitted = true;
  }

  String _cellKey(int row, int col) => '$row:$col';

  /// Decodes the stable `row:column` key used by crossword maps.
  ({int row, int col}) _parseCellKey(String key) {
    final parts = key.split(':');
    return (row: int.parse(parts[0]), col: int.parse(parts[1]));
  }

  String? _nextCellInWord(_CrosswordPlacedWord word, String currentCellKey) {
    for (var i = 0; i < word.word.length; i++) {
      final row = word.row + (word.isAcross ? 0 : i);
      final col = word.col + (word.isAcross ? i : 0);
      if (_cellKey(row, col) != currentCellKey) {
        continue;
      }

      if (i + 1 >= word.word.length) {
        return null;
      }

      final nextRow = word.row + (word.isAcross ? 0 : i + 1);
      final nextCol = word.col + (word.isAcross ? i + 1 : 0);
      return _cellKey(nextRow, nextCol);
    }

    return null;
  }

  String? _nextFilledCellRowMajor(
    _CrosswordPuzzle puzzle,
    String currentCellKey,
  ) {
    final current = _parseCellKey(currentCellKey);
    final currentIndex = current.row * _gridSize + current.col;
    final maxIndex = (_gridSize * _gridSize) - 1;

    for (var index = currentIndex + 1; index <= maxIndex; index++) {
      final row = index ~/ _gridSize;
      final col = index % _gridSize;
      final key = _cellKey(row, col);
      if (puzzle.letters.containsKey(key)) {
        return key;
      }
    }

    for (var index = 0; index < currentIndex; index++) {
      final row = index ~/ _gridSize;
      final col = index % _gridSize;
      final key = _cellKey(row, col);
      if (puzzle.letters.containsKey(key)) {
        return key;
      }
    }

    return null;
  }

  /// Chooses input focus progression: continue through an intersecting word,
  /// preferring Across, then wrap to the next occupied grid cell.
  String? _nextCellKeyAfterEntry(
    _CrosswordPuzzle puzzle,
    String currentCellKey,
  ) {
    final wordIds = puzzle.wordIdsByCell[currentCellKey] ?? const <int>{};

    final words =
        wordIds
            .map((id) => _wordById(puzzle, id))
            .whereType<_CrosswordPlacedWord>()
            .toList(growable: false)
          ..sort((a, b) {
            if (a.isAcross != b.isAcross) {
              return a.isAcross ? -1 : 1;
            }
            return a.id.compareTo(b.id);
          });

    for (final word in words) {
      final nextInWord = _nextCellInWord(word, currentCellKey);
      if (nextInWord != null) {
        return nextInWord;
      }
    }

    return _nextFilledCellRowMajor(puzzle, currentCellKey);
  }

  void _selectCell(String key) {
    setState(() {
      _selectedCellKey = key;
    });
    _cellInputController.clear();
    _cellInputFocusNode.requestFocus();
  }

  void _onCellInputChanged(String value) {
    final selected = _selectedCellKey;
    if (selected == null || value.isEmpty) {
      return;
    }

    final puzzle = _puzzle;
    if (puzzle == null) {
      return;
    }

    final letter = value.characters.last.toUpperCase();
    final nextCellKey = _nextCellKeyAfterEntry(puzzle, selected);
    setState(() {
      _enteredLettersByCell = {..._enteredLettersByCell, selected: letter};
      _selectedCellKey = nextCellKey ?? selected;
    });
    _cellInputController.clear();
    _cellInputFocusNode.requestFocus();
  }

  void _clearSelectedCell() {
    final selected = _selectedCellKey;
    if (selected == null) {
      return;
    }

    setState(() {
      _enteredLettersByCell = Map<String, String>.from(_enteredLettersByCell)
        ..remove(selected);
    });
    _cellInputController.clear();
    _cellInputFocusNode.requestFocus();
  }

  /// Checks bounds, matching intersections, and crossword adjacency rules.
  /// Placements must create exactly one useful intersection with the grid.
  bool _canPlace(
    String word,
    int startRow,
    int startCol,
    bool isAcross,
    Map<String, String> letters,
  ) {
    bool hasLetterAt(int row, int col) {
      if (row < 0 || row >= _gridSize || col < 0 || col >= _gridSize) {
        return false;
      }
      return letters.containsKey(_cellKey(row, col));
    }

    final beforeRow = isAcross ? startRow : startRow - 1;
    final beforeCol = isAcross ? startCol - 1 : startCol;
    if (hasLetterAt(beforeRow, beforeCol)) {
      return false;
    }

    final afterRow = isAcross ? startRow : startRow + word.length;
    final afterCol = isAcross ? startCol + word.length : startCol;
    if (hasLetterAt(afterRow, afterCol)) {
      return false;
    }

    var intersections = 0;

    for (var i = 0; i < word.length; i++) {
      final row = startRow + (isAcross ? 0 : i);
      final col = startCol + (isAcross ? i : 0);
      if (row < 0 || row >= _gridSize || col < 0 || col >= _gridSize) {
        return false;
      }

      final key = _cellKey(row, col);
      final existing = letters[key];
      if (existing != null) {
        if (existing != word[i]) {
          return false;
        }
        intersections++;
        continue;
      }

      if (isAcross) {
        if (hasLetterAt(row - 1, col) || hasLetterAt(row + 1, col)) {
          return false;
        }
      } else {
        if (hasLetterAt(row, col - 1) || hasLetterAt(row, col + 1)) {
          return false;
        }
      }
    }

    if (intersections == word.length) {
      return false;
    }

    if (intersections > 1) {
      return false;
    }

    return true;
  }

  int _intersectionCount(
    String word,
    int startRow,
    int startCol,
    bool isAcross,
    Map<String, String> letters,
  ) {
    var count = 0;
    for (var i = 0; i < word.length; i++) {
      final row = startRow + (isAcross ? 0 : i);
      final col = startCol + (isAcross ? i : 0);
      final key = _cellKey(row, col);
      if (letters[key] == word[i]) {
        count++;
      }
    }
    return count;
  }

  /// Writes a placed word into the letter grid and reverse cell-to-word index.
  void _placeWord(
    _CrosswordPlacedWord placedWord,
    Map<String, String> letters,
    Map<String, Set<int>> wordIdsByCell,
  ) {
    for (var i = 0; i < placedWord.word.length; i++) {
      final row = placedWord.row + (placedWord.isAcross ? 0 : i);
      final col = placedWord.col + (placedWord.isAcross ? i : 0);
      final key = _cellKey(row, col);
      letters[key] = placedWord.word[i];
      wordIdsByCell.putIfAbsent(key, () => <int>{}).add(placedWord.id);
    }
  }

  /// Greedily builds one puzzle by centering the first word and adding each
  /// candidate at its highest-scoring valid intersection.
  _CrosswordPuzzle _buildPuzzle(List<_CrosswordCandidate> shuffledCandidates) {
    final letters = <String, String>{};
    final wordIdsByCell = <String, Set<int>>{};
    final placedWords = <_CrosswordPlacedWord>[];

    var nextWordId = 1;
    final first = shuffledCandidates.first;
    final firstRow = _gridSize ~/ 2;
    final firstCol = ((_gridSize - first.word.length) ~/ 2).clamp(
      0,
      _gridSize - 1,
    );
    final firstPlaced = _CrosswordPlacedWord(
      id: nextWordId++,
      word: first.word,
      type: first.type,
      row: firstRow,
      col: firstCol,
      isAcross: true,
    );
    placedWords.add(firstPlaced);
    _placeWord(firstPlaced, letters, wordIdsByCell);

    for (final candidate in shuffledCandidates.skip(1)) {
      if (placedWords.length >= _targetWordCount) {
        break;
      }

      ({int row, int col, bool isAcross})? bestPlacement;
      var bestScore = -1;

      for (final cellEntry in letters.entries) {
        final cell = _parseCellKey(cellEntry.key);
        final cellChar = cellEntry.value;

        for (var i = 0; i < candidate.word.length; i++) {
          if (candidate.word[i] != cellChar) {
            continue;
          }

          for (final isAcross in const [true, false]) {
            final startRow = isAcross ? cell.row : cell.row - i;
            final startCol = isAcross ? cell.col - i : cell.col;

            if (!_canPlace(
              candidate.word,
              startRow,
              startCol,
              isAcross,
              letters,
            )) {
              continue;
            }

            final score = _intersectionCount(
              candidate.word,
              startRow,
              startCol,
              isAcross,
              letters,
            );
            if (score <= 0) {
              continue;
            }

            if (score > bestScore) {
              bestScore = score;
              bestPlacement = (
                row: startRow,
                col: startCol,
                isAcross: isAcross,
              );
            }
          }
        }
      }

      if (bestPlacement == null) {
        continue;
      }

      final placed = _CrosswordPlacedWord(
        id: nextWordId++,
        word: candidate.word,
        type: candidate.type,
        row: bestPlacement.row,
        col: bestPlacement.col,
        isAcross: bestPlacement.isAcross,
      );
      placedWords.add(placed);
      _placeWord(placed, letters, wordIdsByCell);
    }

    return _CrosswordPuzzle(
      placedWords: placedWords,
      letters: letters,
      wordIdsByCell: wordIdsByCell,
    );
  }

  /// Tries multiple shuffled candidate orders and keeps the puzzle containing
  /// the most words, stopping early once the target count is reached.
  void _generatePuzzle() {
    if (_candidates.isEmpty) {
      return;
    }

    _CrosswordPuzzle? bestPuzzle;

    for (var attempt = 0; attempt < _generationAttempts; attempt++) {
      final shuffled = List<_CrosswordCandidate>.from(_candidates)
        ..shuffle(_random);
      final puzzle = _buildPuzzle(shuffled);

      if (bestPuzzle == null ||
          puzzle.placedWords.length > bestPuzzle.placedWords.length) {
        bestPuzzle = puzzle;
      }

      if (puzzle.placedWords.length >= _targetWordCount) {
        bestPuzzle = puzzle;
        break;
      }
    }

    if (bestPuzzle == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _revealedWordIds = <int>{};
      _enteredLettersByCell = <String, String>{};
      _selectedCellKey = null;
      _puzzle = bestPuzzle;
    });

    if (bestPuzzle.placedWords.length < _targetWordCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could only place ${bestPuzzle.placedWords.length} words with current constraints.',
          ),
        ),
      );
    }
  }

  /// Returns the first plain sentence containing [word] as a complete word.
  String _sentenceForWord(String word) {
    final pattern = RegExp(
      '\\b${RegExp.escape(word)}\\b',
      caseSensitive: false,
    );
    for (final sentence in _sentences) {
      if (pattern.hasMatch(sentence)) {
        return sentence;
      }
    }
    return 'No sentence found for "$word" in the sentence list.';
  }

  Future<void> _showSentenceHint(
    _CrosswordPlacedWord placedWord,
    int number,
  ) async {
    final sentence = _sentenceForWord(placedWord.word);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Clue $number • ${placedWord.directionLabel}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Word type: ${placedWord.type}'),
              const SizedBox(height: 8),
              Text('Sentence hint:'),
              const SizedBox(height: 6),
              Text(sentence),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
            FilledButton.tonal(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                setState(() {
                  _revealedWordIds = {..._revealedWordIds, placedWord.id};
                });
              },
              child: const Text('Reveal Word'),
            ),
          ],
        );
      },
    );
  }

  _CrosswordPlacedWord? _wordById(_CrosswordPuzzle puzzle, int id) {
    for (final word in puzzle.placedWords) {
      if (word.id == id) {
        return word;
      }
    }
    return null;
  }

  /// Reports completion from entered grid letters; revealed words also count as
  /// answered so the clue list reflects all solved-visible state.
  bool _isWordCorrectlyAnswered(_CrosswordPlacedWord word) {
    // If the word is revealed, it's considered correctly answered
    if (_revealedWordIds.contains(word.id)) {
      return true;
    }

    // Otherwise check if all letters are entered and correct
    for (var i = 0; i < word.word.length; i++) {
      final row = word.row + (word.isAcross ? 0 : i);
      final col = word.col + (word.isAcross ? i : 0);
      final key = _cellKey(row, col);
      final enteredLetter = _enteredLettersByCell[key];

      // Check if all letters are entered and correct
      if (enteredLetter == null ||
          enteredLetter.toLowerCase() != word.word[i].toLowerCase()) {
        return false;
      }
    }
    return true;
  }

  String _hiddenWordPattern(_CrosswordPlacedWord word) {
    if (_revealedWordIds.contains(word.id)) {
      return word.word.toUpperCase().split('').join(' ');
    }

    final chars = <String>[];
    for (var i = 0; i < word.word.length; i++) {
      final row = word.row + (word.isAcross ? 0 : i);
      final col = word.col + (word.isAcross ? i : 0);
      final key = _cellKey(row, col);
      final enteredLetter = _enteredLettersByCell[key];
      final isCorrect =
          enteredLetter != null &&
          enteredLetter.toLowerCase() == word.word[i].toLowerCase();
      chars.add(isCorrect ? word.word[i].toUpperCase() : '_');
    }

    return chars.join(' ');
  }

  Future<void> _showCrosswordHiddenWordHints(
    _CrosswordPuzzle puzzle,
    Map<int, int> startNumberByWordId,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Crossword Hints'),
          content: SizedBox(
            width: 360,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: puzzle.placedWords.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final word = puzzle.placedWords[index];
                final number = startNumberByWordId[word.id] ?? 0;
                return ListTile(
                  dense: true,
                  title: Text(
                    '$number. ${word.directionLabel} • ${word.word.length} letters',
                  ),
                  subtitle: Text(
                    'Hidden word: ${_hiddenWordPattern(word)}\nType: ${word.type}',
                  ),
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

  Future<void> _showCellSentenceHint(
    _CrosswordPuzzle puzzle,
    Set<int> cellWordIds,
    Map<int, int> startNumberByWordId,
  ) async {
    if (cellWordIds.isEmpty) {
      return;
    }

    if (cellWordIds.length == 1) {
      final id = cellWordIds.first;
      final word = _wordById(puzzle, id);
      if (word == null) {
        return;
      }
      final number = startNumberByWordId[id] ?? 0;
      await _showSentenceHint(word, number);
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Choose a word'),
          content: SizedBox(
            width: 320,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final id in cellWordIds)
                  ListTile(
                    dense: true,
                    onTap: () {
                      Navigator.of(dialogContext).pop();
                      final word = _wordById(puzzle, id);
                      if (word == null) {
                        return;
                      }
                      final number = startNumberByWordId[id] ?? 0;
                      _showSentenceHint(word, number);
                    },
                    leading: CircleAvatar(
                      radius: 14,
                      child: Text('${startNumberByWordId[id] ?? 0}'),
                    ),
                    title: Text(
                      '${_wordById(puzzle, id)?.directionLabel ?? ''} • ${_wordById(puzzle, id)?.type ?? ''}',
                    ),
                    subtitle: Text(
                      '${_wordById(puzzle, id)?.word.length ?? 0} letters',
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('Building crossword...'),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Failed to load crossword data: ${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      setState(() {
                        _loadFuture = _loadData();
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final puzzle = _puzzle;
        if (puzzle == null || puzzle.placedWords.isEmpty) {
          return const Center(child: Text('No crossword words available.'));
        }

        // Calculate actual grid square numbers (1, 2, 3...) for cells with letters
        final cellNumberByKey = <String, int>{};
        var cellNumber = 1;
        for (var row = 0; row < _gridSize; row++) {
          for (var col = 0; col < _gridSize; col++) {
            final key = _cellKey(row, col);
            if (puzzle.letters.containsKey(key)) {
              cellNumberByKey[key] = cellNumber++;
            }
          }
        }

        // Map each word to its starting cell number
        final startNumberByWordId = <int, int>{};
        for (final word in puzzle.placedWords) {
          final startKey = _cellKey(word.row, word.col);
          startNumberByWordId[word.id] = cellNumberByKey[startKey] ?? 0;
        }

        final startNumberByCellKey = <String, int>{
          for (final word in puzzle.placedWords)
            _cellKey(word.row, word.col): (startNumberByWordId[word.id] ?? 0),
        };

        return DefaultTabController(
          length: 3,
          initialIndex: 2,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TabBar(
                  tabs: const [
                    Tab(text: 'Crossword'),
                    Tab(text: 'Slide'),
                    Tab(text: 'Drag'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      Column(
                        children: [
                          Row(
                            children: [
                              const Expanded(child: SizedBox.shrink()),
                              OutlinedButton.icon(
                                onPressed: () => _showCrosswordHiddenWordHints(
                                  puzzle,
                                  startNumberByWordId,
                                ),
                                icon: const Icon(Icons.lightbulb_outline),
                                label: const Text('Hint'),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.icon(
                                onPressed: _generatePuzzle,
                                icon: const Icon(Icons.shuffle),
                                label: const Text('New Puzzle'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                const wideLayoutBreakpoint = 900.0;
                                final isWideLayout =
                                    constraints.maxWidth >=
                                    wideLayoutBreakpoint;

                                Widget buildPuzzleGrid({
                                  required double maxWidth,
                                }) {
                                  final maxGridSide = maxWidth < 620
                                      ? maxWidth
                                      : 620.0;
                                  final cellSize = maxGridSide / _gridSize;
                                  final gridDimension = cellSize * _gridSize;
                                  final colorScheme = Theme.of(
                                    context,
                                  ).colorScheme;
                                  final isDark =
                                      Theme.of(context).brightness ==
                                      Brightness.dark;
                                  final defaultCellBorderColor =
                                      colorScheme.outline;
                                  final defaultCellFillColor = isDark
                                      ? colorScheme.surfaceContainer
                                      : colorScheme.surfaceContainerHighest;
                                  final cellNumberColor =
                                      colorScheme.onSurfaceVariant;
                                  final enteredCorrectColor = isDark
                                      ? Colors.lightGreenAccent.shade400
                                      : Colors.green.shade800;
                                  final enteredWrongColor = isDark
                                      ? Colors.red.shade300
                                      : Colors.red.shade800;

                                  return Center(
                                    child: SizedBox(
                                      width: gridDimension,
                                      height: gridDimension,
                                      child: GridView.builder(
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        itemCount: _gridSize * _gridSize,
                                        gridDelegate:
                                            const SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: _gridSize,
                                            ),
                                        itemBuilder: (context, index) {
                                          final row = index ~/ _gridSize;
                                          final col = index % _gridSize;
                                          final key = _cellKey(row, col);
                                          final letter = puzzle.letters[key];

                                          if (letter == null) {
                                            return const SizedBox.shrink();
                                          }

                                          final cellWordIds =
                                              puzzle.wordIdsByCell[key] ??
                                              <int>{};
                                          final isRevealed = cellWordIds.any(
                                            _revealedWordIds.contains,
                                          );
                                          final enteredLetter =
                                              _enteredLettersByCell[key];
                                          final isSelected =
                                              _selectedCellKey == key;
                                          final number =
                                              startNumberByCellKey[key];
                                          final displayLetter = isRevealed
                                              ? letter.toUpperCase()
                                              : (enteredLetter ?? '');
                                          final isCorrectEntry =
                                              enteredLetter != null &&
                                              enteredLetter.toLowerCase() ==
                                                  letter;

                                          return GestureDetector(
                                            onTap: () {
                                              if (_selectedCellKey == key) {
                                                _showCellSentenceHint(
                                                  puzzle,
                                                  cellWordIds,
                                                  startNumberByWordId,
                                                );
                                                return;
                                              }
                                              _selectCell(key);
                                            },
                                            child: Container(
                                              margin: const EdgeInsets.all(1),
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color: isSelected
                                                      ? colorScheme.primary
                                                      : defaultCellBorderColor,
                                                  width: isSelected ? 2 : 1,
                                                ),
                                                color: defaultCellFillColor,
                                              ),
                                              child: Stack(
                                                children: [
                                                  if (number != null)
                                                    Positioned(
                                                      left: 2,
                                                      top: 1,
                                                      child: Text(
                                                        '$number',
                                                        style: TextStyle(
                                                          fontSize: 8,
                                                          color:
                                                              cellNumberColor,
                                                        ),
                                                      ),
                                                    ),
                                                  Center(
                                                    child: Text(
                                                      displayLetter,
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: isRevealed
                                                            ? colorScheme
                                                                  .onSurface
                                                            : (enteredLetter ==
                                                                      null
                                                                  ? colorScheme
                                                                        .onSurface
                                                                  : (isCorrectEntry
                                                                        ? enteredCorrectColor
                                                                        : enteredWrongColor)),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  );
                                }

                                final controlsCard = Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                _selectedCellKey == null
                                                    ? 'Tap a crossword cell to enter letters. Tap the same cell again for its sentence hint.'
                                                    : 'Selected cell: $_selectedCellKey',
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            OutlinedButton.icon(
                                              onPressed:
                                                  _selectedCellKey == null
                                                  ? null
                                                  : _clearSelectedCell,
                                              icon: const Icon(
                                                Icons.backspace_outlined,
                                              ),
                                              label: const Text('Clear Cell'),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        TextField(
                                          controller: _cellInputController,
                                          focusNode: _cellInputFocusNode,
                                          enabled: _selectedCellKey != null,
                                          maxLength: 1,
                                          textCapitalization:
                                              TextCapitalization.characters,
                                          inputFormatters: [
                                            FilteringTextInputFormatter.allow(
                                              RegExp(r'[a-zA-Z]'),
                                            ),
                                          ],
                                          onChanged: _onCellInputChanged,
                                          decoration: const InputDecoration(
                                            counterText: '',
                                            hintText: 'Type one letter',
                                            prefixIcon: Icon(Icons.keyboard),
                                            border: OutlineInputBorder(),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );

                                final hintsList = ListView.separated(
                                  shrinkWrap: !isWideLayout,
                                  physics: isWideLayout
                                      ? const ClampingScrollPhysics()
                                      : const NeverScrollableScrollPhysics(),
                                  itemCount: puzzle.placedWords.length,
                                  separatorBuilder: (context, index) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final word = puzzle.placedWords[index];
                                    final number =
                                        startNumberByWordId[word.id] ?? 0;
                                    final isRevealed = _revealedWordIds
                                        .contains(word.id);
                                    final isCorrect = _isWordCorrectlyAnswered(
                                      word,
                                    );
                                    return ListTile(
                                      dense: true,
                                      onTap: () =>
                                          _showSentenceHint(word, number),
                                      title: Text(
                                        '$number. ${word.directionLabel} • ${word.word.length} letters',
                                      ),
                                      subtitle: Text(
                                        'Type hint: ${word.type}${isRevealed ? ' • ${word.word.toUpperCase()}' : ''}',
                                      ),
                                      trailing: isCorrect
                                          ? Icon(
                                              Icons.check_circle,
                                              color: Colors.green.shade700,
                                            )
                                          : const Icon(
                                              Icons.chat_bubble_outline,
                                            ),
                                    );
                                  },
                                );

                                if (!isWideLayout) {
                                  return SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        buildPuzzleGrid(
                                          maxWidth: constraints.maxWidth,
                                        ),
                                        const SizedBox(height: 10),
                                        controlsCard,
                                        const SizedBox(height: 10),
                                        Card(child: hintsList),
                                      ],
                                    ),
                                  );
                                }

                                return Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: SingleChildScrollView(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            buildPuzzleGrid(
                                              maxWidth: constraints.maxWidth,
                                            ),
                                            const SizedBox(height: 10),
                                            controlsCard,
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 2,
                                      child: Card(child: hintsList),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Main game grid with dynamic responsive sizing
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                if (_slideWordLetters.isEmpty) {
                                  return const Center(
                                    child: Text('No slide word available.'),
                                  );
                                }

                                // Calculate dynamic sizes based on available space
                                final maxWidth = constraints.maxWidth;
                                final maxHeight = constraints.maxHeight;
                                // Calculate dynamic sizes to fit in available space
                                const horizontalGap = 10.0;
                                final columnCount = _slideWordLetters.length;
                                final numColumns = _slideWordLetters.length
                                    .toDouble();

                                // Calculate available space with generous margin
                                final availableHeight = maxHeight - 50;
                                final availableWidth = maxWidth - 20;
                                final showTypeLabel = _slideWordType
                                    .trim()
                                    .isNotEmpty;
                                const typeLabelWidth = 140.0;
                                const typeLabelGap = 12.0;
                                final maxAboveLetters = _slideVerticalWords
                                    .where((v) => v.isAbove)
                                    .fold<int>(
                                      0,
                                      (maxLen, v) =>
                                          math.max(maxLen, v.word.length),
                                    );
                                final maxBelowLetters = _slideVerticalWords
                                    .where((v) => !v.isAbove)
                                    .fold<int>(
                                      0,
                                      (maxLen, v) =>
                                          math.max(maxLen, v.word.length),
                                    );
                                final totalGapsWidth =
                                    math.max(0, columnCount - 1) *
                                    horizontalGap;
                                final widthBasedSquare =
                                    (availableWidth - totalGapsWidth) /
                                    numColumns;
                                final heightFactor =
                                    1 + (maxAboveLetters + maxBelowLetters);
                                final heightBasedSquare =
                                    availableHeight /
                                    math.max(1.0, heightFactor);
                                final squareSize = math
                                    .min(widthBasedSquare, heightBasedSquare)
                                    .clamp(12.0, 64.0);
                                final contentWidth =
                                    (columnCount * squareSize) + totalGapsWidth;
                                final typeLabelTotalWidth = showTypeLabel
                                    ? typeLabelWidth + typeLabelGap
                                    : 0.0;
                                final boardContentWidth = math.max(
                                  availableWidth,
                                  contentWidth + typeLabelTotalWidth,
                                );

                                final letterHeight = squareSize;
                                final topLaneHeight =
                                    letterHeight * math.max(1, maxAboveLetters);
                                final bottomLaneHeight =
                                    letterHeight * math.max(1, maxBelowLetters);
                                final fontSize = (squareSize * 0.35).clamp(
                                  8.0,
                                  18.0,
                                );
                                final colorScheme = Theme.of(
                                  context,
                                ).colorScheme;
                                final isDark =
                                    Theme.of(context).brightness ==
                                    Brightness.dark;
                                final slideTileBorderColor =
                                    colorScheme.primary;
                                final slideTileFillColor = isDark
                                    ? colorScheme.primaryContainer.withValues(
                                        alpha: 0.55,
                                      )
                                    : Colors.blue.shade50;
                                final slideTileTextColor = isDark
                                    ? colorScheme.onPrimaryContainer
                                    : Colors.blueGrey.shade900;
                                final revealedTileBorderColor = isDark
                                    ? Colors.lightGreenAccent.shade400
                                    : Colors.green;
                                final revealedTileFillColor = isDark
                                    ? Colors.green.shade900.withValues(
                                        alpha: 0.45,
                                      )
                                    : Colors.green.shade50;
                                final revealedTileTextColor = isDark
                                    ? Colors.green.shade100
                                    : Colors.green.shade900;

                                _slideTopLaneHeightPx = topLaneHeight;
                                _slideSquareSizePx = squareSize;
                                _slideLetterHeightPx = letterHeight;

                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 10,
                                  ),
                                  child: SingleChildScrollView(
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: SizedBox(
                                        width: boardContentWidth,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.max,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            if (showTypeLabel)
                                              SizedBox(
                                                width: typeLabelWidth,
                                                height:
                                                    topLaneHeight +
                                                    squareSize +
                                                    bottomLaneHeight,
                                                child: Align(
                                                  alignment: Alignment.topRight,
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          top: 4,
                                                        ),
                                                    child: InkWell(
                                                      onTap:
                                                          _showSlideWordTypeDefinitionDialog,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                      child: Text(
                                                        _slideWordType,
                                                        textAlign:
                                                            TextAlign.right,
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .titleMedium
                                                            ?.copyWith(
                                                              color:
                                                                  Theme.of(
                                                                        context,
                                                                      )
                                                                      .colorScheme
                                                                      .primary,
                                                              decoration:
                                                                  TextDecoration
                                                                      .underline,
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            if (showTypeLabel)
                                              const SizedBox(
                                                width: typeLabelGap,
                                              ),
                                            ...List.generate(_slideWordLetters.length, (
                                              hIndex,
                                            ) {
                                              final vIdx = _slideVerticalWords
                                                  .indexWhere(
                                                    (v) =>
                                                        v.horizontalIndex ==
                                                        hIndex,
                                                  );
                                              final vWord = vIdx >= 0
                                                  ? _slideVerticalWords[vIdx]
                                                  : null;
                                              final hideVerticalWord =
                                                  _slideHasSubmitted &&
                                                  _slideRevealedLetters[hIndex];
                                              final canDragVerticalWord =
                                                  vWord != null &&
                                                  !hideVerticalWord;
                                              final columnHeight =
                                                  topLaneHeight +
                                                  squareSize +
                                                  bottomLaneHeight;

                                              return Padding(
                                                padding: EdgeInsets.only(
                                                  right:
                                                      hIndex ==
                                                          _slideWordLetters
                                                                  .length -
                                                              1
                                                      ? 0
                                                      : horizontalGap,
                                                ),
                                                child: GestureDetector(
                                                  onVerticalDragUpdate:
                                                      !canDragVerticalWord
                                                      ? null
                                                      : (details) =>
                                                            _slideVerticalWord(
                                                              vIdx,
                                                              details.delta.dy,
                                                            ),
                                                  onVerticalDragEnd:
                                                      !canDragVerticalWord
                                                      ? null
                                                      : (_) =>
                                                            _snapSlideVerticalWord(
                                                              vIdx,
                                                            ),
                                                  child: SizedBox(
                                                    width: squareSize,
                                                    height: columnHeight,
                                                    child: ClipRect(
                                                      child: Stack(
                                                        children: [
                                                          if (vWord != null &&
                                                              !hideVerticalWord)
                                                            Transform.translate(
                                                              offset: Offset(
                                                                0,
                                                                vWord
                                                                    .verticalOffset,
                                                              ),
                                                              child: SizedBox(
                                                                width:
                                                                    squareSize,
                                                                height:
                                                                    letterHeight *
                                                                    vWord
                                                                        .word
                                                                        .length,
                                                                child: Stack(
                                                                  children: List.generate(
                                                                    vWord
                                                                        .word
                                                                        .length,
                                                                    (
                                                                      letterIdx,
                                                                    ) => Positioned(
                                                                      top:
                                                                          letterHeight *
                                                                          letterIdx,
                                                                      left: 0,
                                                                      child: Container(
                                                                        width:
                                                                            squareSize,
                                                                        height:
                                                                            letterHeight,
                                                                        decoration: BoxDecoration(
                                                                          border: Border.all(
                                                                            color:
                                                                                slideTileBorderColor,
                                                                            width:
                                                                                2,
                                                                          ),
                                                                          borderRadius:
                                                                              BorderRadius.circular(
                                                                                4,
                                                                              ),
                                                                          color:
                                                                              slideTileFillColor,
                                                                        ),
                                                                        child: Center(
                                                                          child: Text(
                                                                            vWord.word[letterIdx],
                                                                            style: TextStyle(
                                                                              fontSize: fontSize,
                                                                              fontWeight: FontWeight.bold,
                                                                              color: slideTileTextColor,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          Positioned(
                                                            top: topLaneHeight,
                                                            left: 0,
                                                            child: Container(
                                                              width: squareSize,
                                                              height:
                                                                  squareSize,
                                                              decoration: BoxDecoration(
                                                                border: Border.all(
                                                                  color:
                                                                      _slideRevealedLetters[hIndex]
                                                                      ? revealedTileBorderColor
                                                                      : colorScheme
                                                                            .outline,
                                                                  width:
                                                                      _slideRevealedLetters[hIndex]
                                                                      ? 3
                                                                      : 2,
                                                                ),
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      4,
                                                                    ),
                                                                color:
                                                                    _slideRevealedLetters[hIndex]
                                                                    ? revealedTileFillColor
                                                                    : Colors
                                                                          .transparent,
                                                              ),
                                                              child: Center(
                                                                child:
                                                                    _slideRevealedLetters[hIndex]
                                                                    ? Text(
                                                                        _slideWordLetters[hIndex],
                                                                        style: TextStyle(
                                                                          fontSize:
                                                                              fontSize,
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                          color:
                                                                              revealedTileTextColor,
                                                                        ),
                                                                      )
                                                                    : const SizedBox(),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              FilledButton.tonalIcon(
                                onPressed: _showSlideSentenceHintDialog,
                                icon: const Icon(Icons.lightbulb_outline),
                                label: const Text('Hint'),
                              ),
                              const SizedBox(width: 12),
                              FilledButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _submitSlideGuess(
                                      topLaneHeight: _slideTopLaneHeightPx,
                                      squareSize: _slideSquareSizePx,
                                      letterHeight: _slideLetterHeightPx,
                                    );
                                  });
                                },
                                icon: const Icon(Icons.task_alt),
                                label: const Text('Submit'),
                              ),
                              const SizedBox(width: 12),
                              FilledButton.tonalIcon(
                                onPressed: () {
                                  setState(() {
                                    _generateSlideWord();
                                  });
                                },
                                icon: const Icon(Icons.shuffle),
                                label: const Text('New Word'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          if (_slideHasSubmitted)
                            Center(
                              child: Text(
                                'Correct letters: $_slideCorrectLetters/${_slideWordLetters.length}',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          if (_slideHasSubmitted &&
                              _slideGameComplete &&
                              _slideCorrectLetters == _slideWordLetters.length)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Text(
                                  'Complete! ✓',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(color: Colors.green),
                                ),
                              ),
                            ),
                        ],
                      ),
                      Column(
                        children: [
                          Row(
                            children: [
                              const Expanded(child: SizedBox.shrink()),
                              FilledButton.tonalIcon(
                                onPressed: () {
                                  setState(() {
                                    _generateDragRound();
                                  });
                                },
                                icon: const Icon(Icons.shuffle),
                                label: const Text('New Sentence'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: _dragRound == null
                                ? Center(
                                    child: Text(
                                      'No structure sentence available for Drag.',
                                      style: _halfTextStyle(
                                        Theme.of(context).textTheme.bodyMedium,
                                      ),
                                    ),
                                  )
                                : LayoutBuilder(
                                    builder: (context, constraints) {
                                      const wideLayoutBreakpoint = 900.0;
                                      final isWideLayout =
                                          constraints.maxWidth >=
                                          wideLayoutBreakpoint;

                                      if (isWideLayout) {
                                        return Row(
                                          children: [
                                            Expanded(
                                              flex: 3,
                                              child: Card(
                                                child: Padding(
                                                  padding: const EdgeInsets.all(
                                                    12,
                                                  ),
                                                  child: LayoutBuilder(
                                                    builder: (context, constraints) {
                                                      return Center(
                                                        child:
                                                            _buildDragSentenceWords(
                                                              sentence:
                                                                  _dragRound!
                                                                      .sentence,
                                                              maxWidth:
                                                                  constraints
                                                                      .maxWidth,
                                                            ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              flex: 2,
                                              child: Card(
                                                child: Padding(
                                                  padding: const EdgeInsets.all(
                                                    12,
                                                  ),
                                                  child:
                                                      _dragRound!
                                                          .removedWords
                                                          .isEmpty
                                                      ? Center(
                                                          child: Text(
                                                            'No parenthesized words found.',
                                                            style: _halfTextStyle(
                                                              Theme.of(context)
                                                                  .textTheme
                                                                  .bodyMedium,
                                                            ),
                                                          ),
                                                        )
                                                      : ListView.separated(
                                                          itemCount: _dragRound!
                                                              .removedWords
                                                              .length,
                                                          separatorBuilder:
                                                              (
                                                                context,
                                                                index,
                                                              ) =>
                                                                  const SizedBox(
                                                                    height: 8,
                                                                  ),
                                                          itemBuilder:
                                                              (
                                                                context,
                                                                index,
                                                              ) => _buildDragWordChip(
                                                                _dragRound!
                                                                    .removedWords[index],
                                                              ),
                                                        ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      }

                                      return SingleChildScrollView(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Card(
                                              child: Padding(
                                                padding: const EdgeInsets.all(
                                                  12,
                                                ),
                                                child: LayoutBuilder(
                                                  builder: (context, constraints) {
                                                    return Center(
                                                      child:
                                                          _buildDragSentenceWords(
                                                            sentence:
                                                                _dragRound!
                                                                    .sentence,
                                                            maxWidth:
                                                                constraints
                                                                    .maxWidth,
                                                          ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            Card(
                                              child: Padding(
                                                padding: const EdgeInsets.all(
                                                  12,
                                                ),
                                                child:
                                                    _dragRound!
                                                        .removedWords
                                                        .isEmpty
                                                    ? Center(
                                                        child: Text(
                                                          'No parenthesized words found.',
                                                          style: _halfTextStyle(
                                                            Theme.of(context)
                                                                .textTheme
                                                                .bodyMedium,
                                                          ),
                                                        ),
                                                      )
                                                    : ListView.separated(
                                                        shrinkWrap: true,
                                                        physics:
                                                            const NeverScrollableScrollPhysics(),
                                                        itemCount: _dragRound!
                                                            .removedWords
                                                            .length,
                                                        separatorBuilder:
                                                            (context, index) =>
                                                                const SizedBox(
                                                                  height: 8,
                                                                ),
                                                        itemBuilder:
                                                            (
                                                              context,
                                                              index,
                                                            ) => _buildDragWordChip(
                                                              _dragRound!
                                                                  .removedWords[index],
                                                            ),
                                                      ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
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

/// Mutable position and immutable identity for one slide-game letter column.
class _SlideVerticalWord {
  _SlideVerticalWord({
    required this.word,
    required this.horizontalIndex,
    required this.letterIndexInWord,
    required this.isAbove,
    required this.verticalOffset,
  });

  final String word;
  final int horizontalIndex;
  final int letterIndexInWord;
  final bool isAbove;
  double verticalOffset;
}

/// A normalized vocabulary item paired with its grammar clue.
class _CrosswordCandidate {
  const _CrosswordCandidate({required this.word, required this.type});

  final String word;
  final String type;
}

/// A crossword candidate assigned an ID, origin, and direction on the grid.
class _CrosswordPlacedWord {
  const _CrosswordPlacedWord({
    required this.id,
    required this.word,
    required this.type,
    required this.row,
    required this.col,
    required this.isAcross,
  });

  final int id;
  final String word;
  final String type;
  final int row;
  final int col;
  final bool isAcross;

  String get directionLabel => isAcross ? 'Across' : 'Down';
}

/// Crossword output plus indexes for rendering cells and resolving crossings.
class _CrosswordPuzzle {
  const _CrosswordPuzzle({
    required this.placedWords,
    required this.letters,
    required this.wordIdsByCell,
  });

  final List<_CrosswordPlacedWord> placedWords;
  final Map<String, String> letters;
  final Map<String, Set<int>> wordIdsByCell;
}

/// Display sentence and unique annotation targets for one drag-game round.
class _DragRound {
  const _DragRound({required this.sentence, required this.removedWords});

  final String sentence;
  final List<String> removedWords;
}

/// A visible sentence token with the optional tag that follows it in source.
class _DragSentenceToken {
  const _DragSentenceToken({
    required this.display,
    required this.normalized,
    this.expectedParentheticalNormalized,
  });

  final String display;
  final String normalized;
  final String? expectedParentheticalNormalized;
}

/// Identifies a dragged token independently of duplicate display text.
class _DragWordPayload {
  const _DragWordPayload({
    required this.tokenIndex,
    required this.display,
    required this.normalized,
  });

  final int tokenIndex;
  final String display;
  final String normalized;
}

/// Provides searchable access to plain, unannotated sentence examples.
class _SentenceTab extends StatefulWidget {
  const _SentenceTab();

  @override
  State<_SentenceTab> createState() => _SentenceTabState();
}

class _SentenceTabState extends State<_SentenceTab> {
  static const String _sentenceSourceLabel =
      AssetsDatabaseService.dictionarySentencesSourceKey;
  final AssetsDatabaseService _assetsDatabaseService = AssetsDatabaseService();

  late Future<List<String>> _itemsFuture;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _itemsFuture = _loadItems();
  }

  void _reloadItems() {
    setState(() {
      _itemsFuture = _loadItems();
    });
  }

  Future<List<String>> _loadItems() async {
    return _assetsDatabaseService.readDictionarySentencesSource();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: _itemsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('Loading sentence data...'),
                SizedBox(height: 4),
                Text(_sentenceSourceLabel, textAlign: TextAlign.center),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Failed to load sentence file: ${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: _reloadItems,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final items = snapshot.data ?? const <String>[];
        if (items.isEmpty) {
          return const Center(child: Text('No sentence entries found.'));
        }

        final filteredItems = _filterAndSortItems(items, _searchQuery);
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              TextField(
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: const InputDecoration(
                  hintText: 'Search sentences...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: filteredItems.isEmpty
                    ? const Center(child: Text('No matching sentences found.'))
                    : ListView.separated(
                        itemCount: filteredItems.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          return ListTile(
                            leading: CircleAvatar(child: Text('${index + 1}')),
                            title: Text(filteredItems[index]),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
