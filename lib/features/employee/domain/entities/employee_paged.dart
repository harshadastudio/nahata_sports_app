/// One page of a server-paginated employee collection.
///
/// The employee routes are drawn from five different controllers and none of
/// them agree on an envelope: `/bookings` sends `{bookings, total, totalPages}`
/// at the top level, `/attendance` nests the same under `data`, `/payments/all`
/// uses `{data, pagination:{currentPage,totalPages,totalCount}}` and
/// `/admin/users` uses `{data, pagination:{totalItems}}`. The mapper normalises
/// all four onto this one shape so no page has to know which it is talking to.
///
/// Deliberately duplicates the coach module's `CoachPaged` rather than
/// importing it: the two features stay independently movable, and the shape is
/// small enough that sharing it would couple them for no gain.
class EmployeePaged<T> {
  const EmployeePaged({
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
  /// list, and several of these routes omit it entirely.
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

  EmployeePaged<T> copyWith({
    List<T>? items,
    int? page,
    int? limit,
    int? total,
    int? totalPages,
  }) {
    return EmployeePaged<T>(
      items: items ?? this.items,
      page: page ?? this.page,
      limit: limit ?? this.limit,
      total: total ?? this.total,
      totalPages: totalPages ?? this.totalPages,
    );
  }

  static EmployeePaged<T> empty<T>() => EmployeePaged<T>(items: const []);

  @override
  String toString() =>
      'EmployeePaged(page: $page/$effectiveTotalPages, items: ${items.length}, '
      'total: $total)';
}

/// An `{id, name}` pair for a picker.
///
/// Every list an employee form picks from — sports, courts, batches, coaches,
/// students — is complex-scoped by the API, so an option offered here can never
/// point at another complex's record.
class EmployeeOption {
  const EmployeeOption({required this.id, required this.name, this.detail});

  final int id;
  final String name;

  /// Secondary line for the picker row — a batch's fee, a court's sport.
  final String? detail;

  String get displayName => name.trim().isEmpty ? '#$id' : name.trim();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is EmployeeOption && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'EmployeeOption($id, $name)';
}
