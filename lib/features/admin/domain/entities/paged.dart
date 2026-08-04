/// One page of a server-paginated collection.
///
/// The admin endpoints are read with `?page=&limit=`, and the meta block comes
/// back under a few different names depending on the route; the data layer
/// normalises all of them onto this shape.
class Paged<T> {
  const Paged({
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

  /// Derived rather than trusted: some routes omit `totalPages`.
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

  Paged<T> copyWith({
    List<T>? items,
    int? page,
    int? limit,
    int? total,
    int? totalPages,
  }) {
    return Paged<T>(
      items: items ?? this.items,
      page: page ?? this.page,
      limit: limit ?? this.limit,
      total: total ?? this.total,
      totalPages: totalPages ?? this.totalPages,
    );
  }

  static Paged<T> empty<T>() => Paged<T>(items: const []);

  @override
  String toString() =>
      'Paged(page: $page/$effectiveTotalPages, items: ${items.length}, total: $total)';
}
