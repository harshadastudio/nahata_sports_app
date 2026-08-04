import 'admin_role.dart';
import 'admin_sports_complex.dart';

/// A bookable court (`/courts`).
///
/// Deliberately a *second* model beside the storefront's `BookedCourt`, which
/// keeps `hourlyRate` as the raw decimal string the booking screens display —
/// the same split this console already makes for sports complexes and batches.
///
/// Every field except [id] is nullable so a thinner list payload is never
/// padded with invented values; the UI renders "—" for anything absent.
class Court {
  const Court({
    required this.id,
    this.name,
    this.image,
    this.sportId,
    this.sportName,
    this.sportComplexId,
    this.sportComplexName,
    this.description,
    this.capacity,
    this.surfaceType,
    this.lightingAvailable,
    this.equipmentAvailable,
    this.hourlyRate,
    this.statusRaw,
    this.showOnFrontend,
    this.slotCount,
    this.availableSlotCount,
    this.createdAt,
    this.raw = const {},
  });

  /// The court id, used in every `/courts/{id}` call and as the parent of
  /// every slot route.
  final int id;

  final String? name;

  /// As stored by the API — possibly a relative path. Read [imageUrl] to
  /// display it.
  final String? image;

  final int? sportId;
  final String? sportName;

  final int? sportComplexId;
  final String? sportComplexName;

  final String? description;

  final int? capacity;

  /// Free text as far as this app can prove. The backend has enum-backed
  /// columns elsewhere (`assignedArea`), so a value outside whatever it
  /// accepts comes back as a 400 the form surfaces on the field — see
  /// `ServerFieldErrors`.
  final String? surfaceType;

  /// Null when the payload did not say — distinct from an explicit `false`, so
  /// the table never claims a court is unlit on the strength of a missing key.
  final bool? lightingAvailable;

  /// Free text: "Rackets, balls". Not a list on the wire.
  final String? equipmentAvailable;

  /// A decimal string on the wire (`"800.00"`), parsed here so the table can
  /// sort and total it.
  final num? hourlyRate;

  final String? statusRaw;
  final bool? showOnFrontend;

  /// Counters the list payload sometimes carries, so the summary cards do not
  /// need a slot read per court.
  final int? slotCount;
  final int? availableSlotCount;

  final DateTime? createdAt;

  final Map<String, dynamic> raw;

  AdminUserStatus? get status => AdminUserStatus.tryParse(statusRaw);
  String get statusLabel => status?.label ?? ((statusRaw ?? '').trim());
  bool get isActive => status == AdminUserStatus.active;

  String get displayName {
    final trimmed = (name ?? '').trim();
    return trimmed.isEmpty ? 'Unnamed court' : trimmed;
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

  /// The image as something a network image widget can actually load. Shares
  /// the sports complex module's resolver — the routes store URLs the same
  /// three ways.
  String? get imageUrl => resolveMediaUrl(image);

  /// Text a local search should match. The spec makes only the name
  /// searchable.
  bool matches(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    return displayName.toLowerCase().contains(needle);
  }

  /// Merges a detail read over the list row, keeping anything detail omitted.
  Court mergedWith(Court other) {
    return Court(
      id: other.id == 0 ? id : other.id,
      name: other.name ?? name,
      image: other.image ?? image,
      sportId: other.sportId ?? sportId,
      sportName: other.sportName ?? sportName,
      sportComplexId: other.sportComplexId ?? sportComplexId,
      sportComplexName: other.sportComplexName ?? sportComplexName,
      description: other.description ?? description,
      capacity: other.capacity ?? capacity,
      surfaceType: other.surfaceType ?? surfaceType,
      lightingAvailable: other.lightingAvailable ?? lightingAvailable,
      equipmentAvailable: other.equipmentAvailable ?? equipmentAvailable,
      hourlyRate: other.hourlyRate ?? hourlyRate,
      statusRaw: other.statusRaw ?? statusRaw,
      showOnFrontend: other.showOnFrontend ?? showOnFrontend,
      slotCount: other.slotCount ?? slotCount,
      availableSlotCount: other.availableSlotCount ?? availableSlotCount,
      createdAt: other.createdAt ?? createdAt,
      raw: {...raw, ...other.raw},
    );
  }

  /// Returns a copy with one field changed — used by the optimistic status and
  /// visibility writes, which must not wait for a list reload to repaint.
  Court copyWith({
    String? statusRaw,
    bool? showOnFrontend,
    String? image,
    bool clearImage = false,
  }) {
    return Court(
      id: id,
      name: name,
      image: clearImage ? null : (image ?? this.image),
      sportId: sportId,
      sportName: sportName,
      sportComplexId: sportComplexId,
      sportComplexName: sportComplexName,
      description: description,
      capacity: capacity,
      surfaceType: surfaceType,
      lightingAvailable: lightingAvailable,
      equipmentAvailable: equipmentAvailable,
      hourlyRate: hourlyRate,
      statusRaw: statusRaw ?? this.statusRaw,
      showOnFrontend: showOnFrontend ?? this.showOnFrontend,
      slotCount: slotCount,
      availableSlotCount: availableSlotCount,
      createdAt: createdAt,
      raw: raw,
    );
  }

  @override
  String toString() =>
      'Court($id, $name, sport: $sportId, complex: $sportComplexId, '
      '$statusRaw, frontend: $showOnFrontend)';
}

/// The write payload for create and update.
class CourtDraft {
  const CourtDraft({
    this.name,
    this.sportId,
    this.sportComplexId,
    this.description,
    this.capacity,
    this.surfaceType,
    this.lightingAvailable,
    this.equipmentAvailable,
    this.hourlyRate,
    this.image,
    this.status,
    this.showOnFrontend,
  });

  final String? name;
  final int? sportId;
  final int? sportComplexId;
  final String? description;
  final int? capacity;
  final String? surfaceType;
  final bool? lightingAvailable;
  final String? equipmentAvailable;
  final num? hourlyRate;

  /// The URL returned by the upload route, or empty to send no image.
  final String? image;

  final AdminUserStatus? status;
  final bool? showOnFrontend;

  /// `POST /courts`.
  ///
  /// Optional text fields are sent as `""` rather than omitted: that is the
  /// shape the sibling create payloads document, and it lets a create
  /// explicitly leave a column blank.
  Map<String, dynamic> toCreateJson() {
    return <String, dynamic>{
      'name': (name ?? '').trim(),
      'sportId': sportId,
      'sportComplexId': sportComplexId,
      'description': (description ?? '').trim(),
      'capacity': capacity,
      'surfaceType': (surfaceType ?? '').trim(),
      'lightingAvailable': lightingAvailable ?? false,
      'equipmentAvailable': (equipmentAvailable ?? '').trim(),
      'hourlyRate': hourlyRate,
      'image': (image ?? '').trim(),
      'status': (status ?? AdminUserStatus.active).slug,
      'showOnFrontend': showOnFrontend ?? false,
    };
  }

  /// `PUT /courts/{courtId}`.
  ///
  /// Only the eight fields the route documents as editable are sent. The sport
  /// and complex assignment is deliberately absent: the edit dialog renders
  /// those read-only for the same reason.
  ///
  /// A field the form never set (null) is omitted; one the admin deliberately
  /// blanked is sent empty, or a description could never be cleared once
  /// written.
  Map<String, dynamic> toUpdateJson() {
    final body = <String, dynamic>{};

    void put(String key, Object? value) {
      if (value == null) return;
      body[key] = value is String ? value.trim() : value;
    }

    put('name', name);
    put('description', description);
    put('capacity', capacity);
    put('hourlyRate', hourlyRate);
    put('surfaceType', surfaceType);
    put('lightingAvailable', lightingAvailable);
    put('equipmentAvailable', equipmentAvailable);
    put('status', status?.slug);

    return body;
  }
}
