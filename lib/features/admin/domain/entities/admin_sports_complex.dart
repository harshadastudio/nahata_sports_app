import '../../../../core/config/api_config.dart';
import 'admin_role.dart';

/// A venue as the admin console sees it (`/sports-complexes`).
///
/// Deliberately richer than the app-wide `SportsComplex` model, which carries
/// only id/name/city for the customer-facing pickers — this one owns the
/// address, contact, operating and integration fields the console edits. The
/// two are separate on purpose: widening the shared model would push admin-only
/// fields into every storefront screen that reads it.
///
/// Every field except [id] is nullable so a thinner list payload is never
/// padded with invented values; the UI renders "—" for anything absent.
class AdminSportsComplex {
  const AdminSportsComplex({
    required this.id,
    this.name,
    this.image,
    this.address,
    this.city,
    this.state,
    this.zipCode,
    this.contactPhone,
    this.contactEmail,
    this.openingHours,
    this.facilities,
    this.statusRaw,
    this.showOnFrontend,
    this.mapUrl,
    this.latitude,
    this.longitude,
    this.managerName,
    this.totalCourts,
    this.activeCourts,
    this.externalOrgId,
    this.externalSiteId,
    this.externalUuid,
    this.createdAt,
    this.raw = const {},
  });

  /// The venue id, used in every `/sports-complexes/{id}` call.
  final int id;

  final String? name;

  /// As stored by the API — possibly a relative path. Read [imageUrl] to
  /// display it.
  final String? image;

  final String? address;
  final String? city;
  final String? state;
  final String? zipCode;

  final String? contactPhone;
  final String? contactEmail;

  final String? openingHours;
  final String? facilities;

  final String? statusRaw;

  /// Null when the payload did not say — distinct from an explicit `false`, so
  /// the table never claims a venue is hidden on the strength of a missing key.
  final bool? showOnFrontend;

  final String? mapUrl;
  final double? latitude;
  final double? longitude;

  final String? managerName;
  final int? totalCourts;
  final int? activeCourts;

  final String? externalOrgId;
  final String? externalSiteId;
  final String? externalUuid;

  final DateTime? createdAt;

  final Map<String, dynamic> raw;

  AdminUserStatus? get status => AdminUserStatus.tryParse(statusRaw);
  String get statusLabel => status?.label ?? ((statusRaw ?? '').trim());

  bool get isActive => status == AdminUserStatus.active;

  String get displayName {
    final trimmed = (name ?? '').trim();
    return trimmed.isEmpty ? 'Unnamed complex' : trimmed;
  }

  /// "Kothrud Arena, Pune" — how the venue reads in a one-line summary.
  String get displayLabel {
    final town = (city ?? '').trim();
    return town.isEmpty ? displayName : '$displayName, $town';
  }

  String get initials {
    final parts = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  bool get hasImage => (image ?? '').trim().isNotEmpty;

  /// The image as something a network image widget can actually load.
  String? get imageUrl => resolveMediaUrl(image);

  bool get hasCoordinates => latitude != null && longitude != null;

  /// Where "Open in Maps" should go: the stored map URL when there is one,
  /// otherwise a pin built from the coordinates, otherwise a search for the
  /// address. Null when there is nothing to point at.
  String? get mapsLink {
    final stored = (mapUrl ?? '').trim();
    if (stored.isNotEmpty) return stored;

    if (hasCoordinates) {
      return 'https://www.google.com/maps/search/?api=1&query='
          '$latitude,$longitude';
    }

    final query = [
      (name ?? '').trim(),
      (address ?? '').trim(),
      (city ?? '').trim(),
      (state ?? '').trim(),
    ].where((part) => part.isNotEmpty).join(', ');

    if (query.isEmpty) return null;
    return 'https://www.google.com/maps/search/?api=1&query='
        '${Uri.encodeComponent(query)}';
  }

  /// Facilities as a list — the API stores them as one free-text field, and the
  /// separator drifts between commas and newlines.
  List<String> get facilityList {
    final text = (facilities ?? '').trim();
    if (text.isEmpty) return const [];
    return text
        .split(RegExp(r'[,\n;]+'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
  }

  bool get hasIntegrationIds =>
      (externalOrgId ?? '').trim().isNotEmpty ||
      (externalSiteId ?? '').trim().isNotEmpty ||
      (externalUuid ?? '').trim().isNotEmpty;

  /// Merges a detail read over the list row, keeping anything detail omitted.
  AdminSportsComplex mergedWith(AdminSportsComplex other) {
    return AdminSportsComplex(
      id: other.id == 0 ? id : other.id,
      name: other.name ?? name,
      image: other.image ?? image,
      address: other.address ?? address,
      city: other.city ?? city,
      state: other.state ?? state,
      zipCode: other.zipCode ?? zipCode,
      contactPhone: other.contactPhone ?? contactPhone,
      contactEmail: other.contactEmail ?? contactEmail,
      openingHours: other.openingHours ?? openingHours,
      facilities: other.facilities ?? facilities,
      statusRaw: other.statusRaw ?? statusRaw,
      showOnFrontend: other.showOnFrontend ?? showOnFrontend,
      mapUrl: other.mapUrl ?? mapUrl,
      latitude: other.latitude ?? latitude,
      longitude: other.longitude ?? longitude,
      managerName: other.managerName ?? managerName,
      totalCourts: other.totalCourts ?? totalCourts,
      activeCourts: other.activeCourts ?? activeCourts,
      externalOrgId: other.externalOrgId ?? externalOrgId,
      externalSiteId: other.externalSiteId ?? externalSiteId,
      externalUuid: other.externalUuid ?? externalUuid,
      createdAt: other.createdAt ?? createdAt,
      raw: {...raw, ...other.raw},
    );
  }

  /// Returns a copy with one field changed — used by the optimistic status and
  /// visibility toggles, which must not wait for a list reload to repaint.
  AdminSportsComplex copyWith({
    String? statusRaw,
    bool? showOnFrontend,
    String? image,
    bool clearImage = false,
  }) {
    return AdminSportsComplex(
      id: id,
      name: name,
      image: clearImage ? null : (image ?? this.image),
      address: address,
      city: city,
      state: state,
      zipCode: zipCode,
      contactPhone: contactPhone,
      contactEmail: contactEmail,
      openingHours: openingHours,
      facilities: facilities,
      statusRaw: statusRaw ?? this.statusRaw,
      showOnFrontend: showOnFrontend ?? this.showOnFrontend,
      mapUrl: mapUrl,
      latitude: latitude,
      longitude: longitude,
      managerName: managerName,
      totalCourts: totalCourts,
      activeCourts: activeCourts,
      externalOrgId: externalOrgId,
      externalSiteId: externalSiteId,
      externalUuid: externalUuid,
      createdAt: createdAt,
      raw: raw,
    );
  }

  @override
  String toString() =>
      'AdminSportsComplex($id, $name, $city/$state, $statusRaw, '
      'frontend: $showOnFrontend)';
}

/// Court counters from `GET /sports-complexes/{id}/stats`.
///
/// Every counter is nullable: the drawer shows an em dash for one the endpoint
/// did not send rather than a zero it cannot vouch for.
class SportsComplexStats {
  const SportsComplexStats({
    this.totalCourts,
    this.activeCourts,
    this.totalBookings,
    this.totalSports,
    this.totalStaff,
  });

  final int? totalCourts;
  final int? activeCourts;
  final int? totalBookings;
  final int? totalSports;
  final int? totalStaff;

  bool get isEmpty =>
      totalCourts == null &&
      activeCourts == null &&
      totalBookings == null &&
      totalSports == null &&
      totalStaff == null;

  @override
  String toString() =>
      'SportsComplexStats(courts: $activeCourts/$totalCourts, '
      'bookings: $totalBookings, sports: $totalSports, staff: $totalStaff)';
}

/// The write payload for create and update.
class SportsComplexDraft {
  const SportsComplexDraft({
    this.name,
    this.address,
    this.city,
    this.state,
    this.zipCode,
    this.contactPhone,
    this.contactEmail,
    this.openingHours,
    this.facilities,
    this.status,
    this.mapUrl,
    this.image,
    this.showOnFrontend,
  });

  final String? name;
  final String? address;
  final String? city;
  final String? state;
  final String? zipCode;
  final String? contactPhone;
  final String? contactEmail;
  final String? openingHours;
  final String? facilities;
  final AdminUserStatus? status;
  final String? mapUrl;

  /// The URL returned by the upload route, or empty to send no image.
  final String? image;

  final bool? showOnFrontend;

  /// `POST /sports-complexes` — every documented key, in the documented shape.
  ///
  /// Optional text fields are sent as `""` rather than omitted: that is the
  /// shape the payload documents, and it lets a create explicitly leave a
  /// column blank.
  Map<String, dynamic> toCreateJson() {
    return <String, dynamic>{
      'name': (name ?? '').trim(),
      'address': (address ?? '').trim(),
      'city': (city ?? '').trim(),
      'state': (state ?? '').trim(),
      'zipCode': (zipCode ?? '').trim(),
      'contactPhone': (contactPhone ?? '').trim(),
      'contactEmail': (contactEmail ?? '').trim(),
      'openingHours': (openingHours ?? '').trim(),
      'facilities': (facilities ?? '').trim(),
      'status': (status ?? AdminUserStatus.active).slug,
      'mapUrl': (mapUrl ?? '').trim(),
      'image': (image ?? '').trim(),
      'showOnFrontend': showOnFrontend ?? false,
    };
  }

  /// `PUT /sports-complexes/{id}`.
  ///
  /// Every field the route documents as editable is sent, including the ones
  /// deliberately blanked — unlike the staff modules, a venue's address line or
  /// map URL is legitimately clearable, and dropping empties would make an
  /// erase impossible. Only a field the form never set (null) is omitted.
  Map<String, dynamic> toUpdateJson() {
    final body = <String, dynamic>{};

    void put(String key, Object? value) {
      if (value == null) return;
      body[key] = value is String ? value.trim() : value;
    }

    put('name', name);
    put('address', address);
    put('city', city);
    put('state', state);
    put('zipCode', zipCode);
    put('contactPhone', contactPhone);
    put('contactEmail', contactEmail);
    put('openingHours', openingHours);
    put('facilities', facilities);
    put('status', status?.slug);
    put('mapUrl', mapUrl);
    put('image', image);
    put('showOnFrontend', showOnFrontend);

    return body;
  }
}

/// Turns a stored image value into something a network image widget can load.
///
/// The API returns three shapes across its routes: an absolute URL, a path
/// rooted at the API host (`/uploads/x.jpg`), and a bare filename. Guessing
/// wrong shows a broken image, so each shape is handled explicitly.
String? resolveMediaUrl(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty || text == 'null') return null;

  if (text.startsWith('http://') || text.startsWith('https://')) return text;

  if (text.startsWith('/')) {
    final origin = Uri.parse(ApiConfig.baseUrl).origin;
    return '$origin$text';
  }

  return '${ApiConfig.mediaBaseUrl}/$text';
}
