import '../../domain/entities/admin_sports_complex.dart';
import 'json_reader.dart';

/// Maps `/sports-complexes` JSON onto [AdminSportsComplex].
class AdminSportsComplexMapper {
  const AdminSportsComplexMapper._();

  static AdminSportsComplex fromJson(Map<String, dynamic> json) {
    final source = _unwrap(json);

    final manager = _nested(source, const ['manager', 'complexManager']);

    return AdminSportsComplex(
      id: JsonReader.integer(source, const ['id', '_id', 'sportComplexId']) ?? 0,
      name: JsonReader.string(source, const [
        'name',
        'complexName',
        'title',
        'sportComplexName',
      ]),
      image: JsonReader.string(source, const [
        'image',
        'imageUrl',
        'image_url',
        'photo',
        'coverImage',
      ]),
      address: JsonReader.string(source, const [
        'address',
        'fullAddress',
        'addressLine1',
        'street',
      ]),
      city: JsonReader.string(source, const ['city', 'town']),
      state: JsonReader.string(source, const ['state', 'province', 'region']),
      zipCode: JsonReader.string(source, const [
        'zipCode',
        'zip_code',
        'pincode',
        'pinCode',
        'postalCode',
      ]),
      contactPhone: JsonReader.string(source, const [
        'contactPhone',
        'contact_phone',
        'phone',
        'phoneNumber',
        'mobile',
      ]),
      contactEmail: JsonReader.string(source, const [
        'contactEmail',
        'contact_email',
        'email',
      ]),
      openingHours: JsonReader.string(source, const [
        'openingHours',
        'opening_hours',
        'timings',
        'workingHours',
      ]),
      facilities: JsonReader.string(source, const [
        'facilities',
        'amenities',
        'features',
      ]),
      statusRaw: JsonReader.string(source, const ['status', 'complexStatus']),
      showOnFrontend: JsonReader.boolean(source, const [
        'showOnFrontend',
        'show_on_frontend',
        'showOnFront',
        'isVisible',
        'visible',
      ]),
      mapUrl: JsonReader.string(source, const [
        'mapUrl',
        'map_url',
        'googleMapUrl',
        'googleMapsUrl',
        'mapLink',
      ]),
      latitude: _decimal(source, const ['latitude', 'lat']),
      longitude: _decimal(source, const ['longitude', 'lng', 'long', 'lon']),
      managerName:
          JsonReader.string(source, const [
            'managerName',
            'manager_name',
            'contactPerson',
          ]) ??
          (manager == null
              ? null
              : JsonReader.string(manager, const ['fullName', 'name'])),
      totalCourts: JsonReader.integer(source, const [
        'totalCourts',
        'total_courts',
        'courtsCount',
        'courtCount',
      ]),
      activeCourts: JsonReader.integer(source, const [
        'activeCourts',
        'active_courts',
        'availableCourts',
      ]),
      externalOrgId: JsonReader.string(source, const [
        'externalOrgId',
        'external_org_id',
        'orgId',
        'organizationId',
      ]),
      externalSiteId: JsonReader.string(source, const [
        'externalSiteId',
        'external_site_id',
        'siteId',
      ]),
      externalUuid: JsonReader.string(source, const [
        'externalUuid',
        'external_uuid',
        'uuid',
        'externalId',
      ]),
      createdAt: JsonReader.date(source, const [
        'createdAt',
        'created_at',
        'createdOn',
        'dateCreated',
      ]),
      raw: source,
    );
  }

  /// The catalogue, from whichever key this route wrapped it in.
  ///
  /// `sportsComplexes` leads because that is the key the app-wide
  /// `SportsComplexRepository` already reads from this same endpoint.
  static List<AdminSportsComplex> listFrom(Object? body) {
    return JsonReader.records(
          body,
          keys: const [
            'sportsComplexes',
            'sportComplexes',
            'sports_complexes',
            'complexes',
            'items',
            'data',
            'results',
            'records',
          ],
        )
        .map(fromJson)
        .where((complex) => complex.id != 0)
        .toList(growable: false);
  }

  static AdminSportsComplex? maybeFromBody(Object? body) {
    if (body is! Map) return null;
    final complex = fromJson(Map<String, dynamic>.from(body));
    return complex.id == 0 ? null : complex;
  }

  /// The URL returned by `POST /sports-complexes/upload-image`.
  ///
  /// The route may answer with a bare string, or with the URL under any of a
  /// handful of keys — all of which are accepted rather than guessed at.
  static String? uploadedUrlFrom(Object? body) {
    if (body is String) {
      final text = body.trim();
      return text.isEmpty ? null : text;
    }
    if (body is! Map) return null;

    final source = Map<String, dynamic>.from(body);
    final direct = JsonReader.string(source, const [
      'imageUrl',
      'image_url',
      'image',
      'url',
      'path',
      'location',
      'filename',
      'fileName',
    ]);
    if (direct != null) return direct;

    // One more level down, for `{ "data": { "image": ... } }`.
    for (final key in const ['data', 'result', 'file']) {
      final inner = source[key];
      if (inner is Map) {
        final nested = JsonReader.string(Map<String, dynamic>.from(inner), const [
          'imageUrl',
          'image_url',
          'image',
          'url',
          'path',
          'location',
          'filename',
          'fileName',
        ]);
        if (nested != null) return nested;
      } else if (inner is String && inner.trim().isNotEmpty) {
        return inner.trim();
      }
    }
    return null;
  }

  static double? _decimal(Map<String, dynamic> json, List<String> keys) {
    final value = JsonReader.pick(json, keys);
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().trim());
  }

  static Map<String, dynamic>? _nested(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = json[key];
      if (value is Map) return Map<String, dynamic>.from(value);
    }
    return null;
  }

  static Map<String, dynamic> _unwrap(Map<String, dynamic> json) {
    for (final key in const [
      'sportsComplex',
      'sportComplex',
      'sports_complex',
      'complex',
      'data',
      'result',
    ]) {
      final inner = json[key];
      if (inner is Map) {
        final unwrapped = Map<String, dynamic>.from(inner);
        for (final nested in const [
          'sportsComplex',
          'sportComplex',
          'complex',
          'data',
        ]) {
          final deeper = unwrapped[nested];
          if (deeper is Map) return Map<String, dynamic>.from(deeper);
        }
        return unwrapped;
      }
    }
    return json;
  }
}

/// Maps `GET /sports-complexes/{id}/stats`.
class SportsComplexStatsMapper {
  const SportsComplexStatsMapper._();

  static SportsComplexStats fromJson(Map<String, dynamic> json) {
    final source = _unwrap(json);

    return SportsComplexStats(
      totalCourts: JsonReader.integer(source, const [
        'totalCourts',
        'total_courts',
        'courts',
        'courtCount',
        'courtsCount',
      ]),
      activeCourts: JsonReader.integer(source, const [
        'activeCourts',
        'active_courts',
        'availableCourts',
        'activeCourtCount',
      ]),
      totalBookings: JsonReader.integer(source, const [
        'totalBookings',
        'total_bookings',
        'bookings',
        'bookingCount',
      ]),
      totalSports: JsonReader.integer(source, const [
        'totalSports',
        'total_sports',
        'sports',
        'sportCount',
      ]),
      totalStaff: JsonReader.integer(source, const [
        'totalStaff',
        'total_staff',
        'staff',
        'employees',
        'totalEmployees',
      ]),
    );
  }

  static Map<String, dynamic> _unwrap(Map<String, dynamic> json) {
    for (final key in const ['stats', 'statistics', 'data', 'result']) {
      final inner = json[key];
      if (inner is Map) {
        final unwrapped = Map<String, dynamic>.from(inner);
        final deeper = unwrapped['stats'];
        if (deeper is Map) return Map<String, dynamic>.from(deeper);
        return unwrapped;
      }
    }
    return json;
  }
}
