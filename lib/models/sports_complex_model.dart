/// Model for `GET /sports-complexes`.
library;

/// A venue. Its id scopes courts, sports, event passes and registrations.
class SportsComplex {
  const SportsComplex({required this.id, required this.name, this.city});

  final int id;
  final String name;
  final String? city;

  /// "Sinhagad Road, Pune" when the city is known.
  String get label => (city == null || city!.isEmpty) ? name : '$name, $city';

  /// Null when the entry has no usable id/name.
  static SportsComplex? fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    final name = json['name']?.toString().trim();
    if (id == null || name == null || name.isEmpty) return null;

    final city = json['city']?.toString().trim();
    return SportsComplex(
      id: id,
      name: name,
      city: (city == null || city.isEmpty || city == 'null') ? null : city,
    );
  }

  static List<SportsComplex> listFrom(Object? data) {
    if (data is! List) return const <SportsComplex>[];
    return data
        .whereType<Map>()
        .map((e) => SportsComplex.fromJson(Map<String, dynamic>.from(e)))
        .whereType<SportsComplex>()
        .toList(growable: false);
  }
}
