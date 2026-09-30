/// Shared search behaviour used by the Grammar, Structure, and Sentence tabs.
library;

/// Filters case-insensitively, ranks prefix matches first, then sorts
/// alphabetically without mutating [source].
List<String> filterAndSortItems(List<String> source, String query) {
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
