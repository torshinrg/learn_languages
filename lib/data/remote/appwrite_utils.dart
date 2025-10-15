import 'package:appwrite/appwrite.dart';

/// Utility functions for building Appwrite database queries.
class AppwriteUtils {
  /// Build a list of query strings for simple equality filters.
  static List<String> buildFilters(Map<String, dynamic>? filters) {
    final queries = <String>[];
    if (filters == null) return queries;

    for (final entry in filters.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key.endsWith('>=')) {
        final field = key.substring(0, key.length - 2);
        queries.add(Query.greaterThanEqual(field, value));
      } else if (key.endsWith('<=')) {
        final field = key.substring(0, key.length - 2);
        queries.add(Query.lessThanEqual(field, value));
      } else if (key.endsWith('>')) {
        final field = key.substring(0, key.length - 1);
        queries.add(Query.greaterThan(field, value));
      } else if (key.endsWith('<')) {
        final field = key.substring(0, key.length - 1);
        queries.add(Query.lessThan(field, value));
      } else {
        queries.add(Query.equal(key, [value]));
      }
    }

    return queries;
  }

  /// Append a sort order to an existing list of queries.
  static List<String> applySorting(
    List<String> base,
    String field, {
    bool descending = false,
  }) {
    final queries = [...base];
    if (descending) {
      queries.add(Query.orderDesc(field));
    } else {
      queries.add(Query.orderAsc(field));
    }
    return queries;
  }
}
