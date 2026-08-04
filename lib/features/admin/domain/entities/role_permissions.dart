import 'admin_role.dart';

/// The permission set attached to one role.
///
/// [available] is the full catalogue the server offers for that role and
/// [granted] is the subset currently switched on. Some backends only return the
/// granted list; in that case [available] falls back to it, so the page still
/// renders (it just cannot offer permissions nobody holds yet).
class RolePermissions {
  const RolePermissions({
    required this.role,
    this.granted = const {},
    this.available = const [],
    this.raw = const {},
  });

  final AdminRole role;

  /// Slugs currently granted.
  final Set<String> granted;

  /// Every slug that can be granted, in the order the server listed them.
  final List<String> available;

  final Map<String, dynamic> raw;

  bool get isEmpty => available.isEmpty && granted.isEmpty;

  bool isGranted(String slug) => granted.contains(slug);

  /// The catalogue actually rendered — [available] when the server sent one,
  /// otherwise whatever is granted.
  List<String> get catalogue {
    if (available.isNotEmpty) return available;
    final fallback = granted.toList()..sort();
    return fallback;
  }

  /// Permissions grouped by their `module.action` prefix, so the page can show
  /// "Bookings", "Users" … sections instead of one flat wall of chips.
  Map<String, List<String>> get grouped {
    final groups = <String, List<String>>{};
    for (final slug in catalogue) {
      groups.putIfAbsent(_groupOf(slug), () => <String>[]).add(slug);
    }
    return groups;
  }

  static String _groupOf(String slug) {
    final separator = RegExp(r'[.:_\-]');
    final parts = slug.split(separator).where((p) => p.isNotEmpty).toList();
    if (parts.length < 2) return 'General';
    return _titleise(parts.first);
  }

  /// `manage_users` → `Manage Users`.
  static String labelFor(String slug) {
    final parts = slug
        .split(RegExp(r'[.:_\-\s]+'))
        .where((p) => p.isNotEmpty)
        .map(_titleise);
    return parts.isEmpty ? slug : parts.join(' ');
  }

  static String _titleise(String word) => word.isEmpty
      ? word
      : word[0].toUpperCase() + word.substring(1).toLowerCase();

  RolePermissions copyWith({Set<String>? granted, List<String>? available}) {
    return RolePermissions(
      role: role,
      granted: granted ?? this.granted,
      available: available ?? this.available,
      raw: raw,
    );
  }

  /// Toggles one slug, returning a new instance.
  RolePermissions toggled(String slug, bool value) {
    final next = Set<String>.from(granted);
    if (value) {
      next.add(slug);
    } else {
      next.remove(slug);
    }
    return copyWith(granted: next);
  }

  /// True when [other] grants exactly the same slugs — this is what keeps the
  /// Save button disabled until something really changed.
  bool sameGrantsAs(RolePermissions other) =>
      granted.length == other.granted.length &&
      granted.containsAll(other.granted);

  @override
  String toString() =>
      'RolePermissions(${role.slug}: ${granted.length}/${catalogue.length} granted)';
}
