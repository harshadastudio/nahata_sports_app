/// One page of a server-paginated coach collection.
///
/// Every paginated coach route answers the same envelope — `{ <rows>, total,
/// page, limit, totalPages }` inside `data` — but names the row array
/// differently per route (`students`, `records`, `progress`, `batches`,
/// `enquiries`), so the key is passed in at the mapping site.
///
/// This deliberately duplicates the admin module's `Paged` rather than
/// importing it: the two features stay independently movable, and the shape is
/// small enough that sharing it would couple them for no gain.
class CoachPaged<T> {
  const CoachPaged({
    this.items = const [],
    this.page = 1,
    this.limit = 20,
    this.total = 0,
    this.totalPages = 0,
  });

  final List<T> items;
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  /// Derived rather than trusted: `totalPages` is `0` when there is nothing to
  /// list, and a few routes omit it entirely.
  int get effectiveTotalPages {
    if (totalPages > 0) return totalPages;
    if (total > 0 && limit > 0) return (total / limit).ceil();
    return items.isEmpty ? 0 : page;
  }

  bool get hasPrevious => page > 1;
  bool get hasNext => page < effectiveTotalPages;

  /// 1-based index of the first row on this page, for "showing X–Y of Z".
  int get firstIndex => items.isEmpty ? 0 : ((page - 1) * limit) + 1;

  int get lastIndex => items.isEmpty ? 0 : firstIndex + items.length - 1;

  CoachPaged<T> copyWith({
    List<T>? items,
    int? page,
    int? limit,
    int? total,
    int? totalPages,
  }) {
    return CoachPaged<T>(
      items: items ?? this.items,
      page: page ?? this.page,
      limit: limit ?? this.limit,
      total: total ?? this.total,
      totalPages: totalPages ?? this.totalPages,
    );
  }

  static CoachPaged<T> empty<T>() => CoachPaged<T>(items: const []);

  @override
  String toString() =>
      'CoachPaged(page: $page/$effectiveTotalPages, items: ${items.length}, '
      'total: $total)';
}
