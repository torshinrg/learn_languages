import 'package:appwrite/appwrite.dart';

/// Utility functions for building Appwrite database queries.
class AppwriteUtils {
  /// Build a list of query strings for simple equality filters.
  static List<String> buildFilters(Map<String, dynamic>? filters) {
    final queries = <String>[];
    if (filters == null) return queries;
    for (final entry in filters.entries) {
      queries.add(Query.equal(entry.key, [entry.value]));
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
