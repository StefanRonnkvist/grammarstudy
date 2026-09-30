import 'package:flutter/material.dart';

import '../../../core/search/search_filter.dart';
import '../../../core/widgets/status_views.dart';

/// Renders a searchable, sorted list of study collection entries.
///
/// Used by the Structure and Sentence tabs, which differ only in the source
/// they load and the labels they show.
class SearchableCollectionView extends StatefulWidget {
  const SearchableCollectionView({
    super.key,
    required this.futureFactory,
    required this.loadingMessage,
    required this.errorMessagePrefix,
    required this.emptyMessage,
    required this.noMatchesMessage,
    required this.searchHint,
  });

  /// Creates a fresh load each time it is called, for example on retry.
  final Future<List<String>> Function() futureFactory;
  final String loadingMessage;
  final String errorMessagePrefix;
  final String emptyMessage;
  final String noMatchesMessage;
  final String searchHint;

  @override
  State<SearchableCollectionView> createState() =>
      _SearchableCollectionViewState();
}

class _SearchableCollectionViewState extends State<SearchableCollectionView> {
  late Future<List<String>> _itemsFuture;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _itemsFuture = widget.futureFactory();
  }

  void _reload() {
    setState(() {
      _itemsFuture = widget.futureFactory();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: _itemsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return LoadingView(message: widget.loadingMessage);
        }

        if (snapshot.hasError) {
          return ErrorRetryView(
            message: '${widget.errorMessagePrefix}: ${snapshot.error}',
            onRetry: _reload,
          );
        }

        final items = snapshot.data ?? const <String>[];
        if (items.isEmpty) {
          return EmptyStateView(message: widget.emptyMessage);
        }

        final filteredItems = filterAndSortItems(items, _searchQuery);
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              SearchField(
                hintText: widget.searchHint,
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: filteredItems.isEmpty
                    ? EmptyStateView(message: widget.noMatchesMessage)
                    : ListView.separated(
                        itemCount: filteredItems.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) => NumberedListTile(
                          index: index,
                          title: filteredItems[index],
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
