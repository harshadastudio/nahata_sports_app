import '../../domain/entities/admin_role.dart';
import '../../domain/entities/role_permissions.dart';
import 'json_reader.dart';

/// Maps `GET /admin/roles/{ROLE}/permissions` onto [RolePermissions].
///
/// Three shapes are handled, because permission endpoints differ the most
/// between backends:
///
/// * `{ permissions: ["users.read", …] }` — granted only,
/// * `{ permissions: [{ slug, granted }] }` — catalogue with flags,
/// * `{ granted: [...], available: [...] }` — both lists explicitly.
class RolePermissionsMapper {
  const RolePermissionsMapper._();

  static RolePermissions fromJson(AdminRole role, Map<String, dynamic> json) {
    final source = _unwrap(json);

    final availableRaw = JsonReader.pick(source, const [
      'available',
      'availablePermissions',
      'allPermissions',
      'catalogue',
      'catalog',
    ]);
    final grantedRaw = JsonReader.pick(source, const [
      'granted',
      'grantedPermissions',
      'assigned',
      'permissions',
      'abilities',
    ]);

    final available = <String>[];
    final granted = <String>{};

    // Objects carrying their own on/off flag define both lists at once.
    final flagged = _flagged(grantedRaw) ?? _flagged(availableRaw);
    if (flagged != null) {
      for (final entry in flagged) {
        available.add(entry.key);
        if (entry.value) granted.add(entry.key);
      }
    } else {
      granted.addAll(JsonReader.asStringList(grantedRaw));
      available.addAll(JsonReader.asStringList(availableRaw));
    }

    // Keep the catalogue a superset of what is granted, and stable in order.
    for (final slug in granted) {
      if (!available.contains(slug)) available.add(slug);
    }

    return RolePermissions(
      role: role,
      granted: granted,
      available: List<String>.unmodifiable(available),
      raw: source,
    );
  }

  /// `[{slug: 'x', granted: true}, …]` → ordered slug/flag pairs, or null when
  /// the value is not that shape.
  static List<MapEntry<String, bool>>? _flagged(Object? value) {
    if (value is! Iterable) return null;
    final entries = <MapEntry<String, bool>>[];

    for (final item in value) {
      if (item is! Map) return null; // A plain string list — not this shape.

      final slug = JsonReader.string(Map<String, dynamic>.from(item), const [
        'slug',
        'permission',
        'name',
        'key',
        'code',
      ]);
      if (slug == null) return null;

      final flag = JsonReader.boolean(Map<String, dynamic>.from(item), const [
        'granted',
        'enabled',
        'allowed',
        'checked',
        'hasPermission',
      ]);
      // No flag at all means the list is just a catalogue in object form; treat
      // membership of the list as "granted", matching the string-list case.
      entries.add(MapEntry(slug, flag ?? true));
    }

    return entries.isEmpty ? null : entries;
  }

  static Map<String, dynamic> _unwrap(Map<String, dynamic> json) {
    for (final key in const ['data', 'result', 'role']) {
      final inner = json[key];
      if (inner is Map) return Map<String, dynamic>.from(inner);
    }
    return json;
  }

  /// The body sent by `PUT /admin/roles/{ROLE}/permissions`.
  static Map<String, dynamic> toUpdateBody(Set<String> granted) {
    final slugs = granted.toList()..sort();
    return <String, dynamic>{'permissions': slugs};
  }
}
