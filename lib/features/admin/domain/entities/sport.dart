import 'admin_role.dart';
import 'admin_sports_complex.dart';

/// Indoor or outdoor. Enumerated by the product spec rather than by any
/// endpoint — there is no `/categories` route — so this is the one definition
/// the form, the filters and the table all share. [slug] is what goes on the
/// wire; a value the server sends that is not in the list still renders through
/// [labelFor], so the list being wrong never hides data.
enum SportCategory {
  indoor('Indoor'),
  outdoor('Outdoor');

  const SportCategory(this.slug);

  final String slug;

  String get label => slug;

  static SportCategory? tryParse(Object? value) {
    if (value == null) return null;
    final wanted = value.toString().trim().toLowerCase();
    if (wanted.isEmpty) return null;
    for (final category in SportCategory.values) {
      if (category.slug.toLowerCase() == wanted) return category;
    }
    return null;
  }

  static String labelFor(String? raw) {
    final parsed = tryParse(raw);
    if (parsed != null) return parsed.label;
    final text = (raw ?? '').trim();
    if (text.isEmpty) return '—';
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }
}

/// A sport offered at a complex (`/sports`).
///
/// Every field except [id] is nullable so a thinner list payload is never
/// padded with invented values; the UI renders "—" for anything absent.
class Sport {
  const Sport({
    required this.id,
    this.name,
    this.image,
    this.sportComplexId,
    this.sportComplexName,
    this.categoryRaw,
    this.description,
    this.equipmentRequired,
    this.achievements,
    this.completeInformation,
    this.minAge,
    this.maxAge,
    this.duration,
    this.allowedMembers,
    this.statusRaw,
    this.showOnFrontend,
    this.programCount,
    this.courtCount,
    this.availableCourts,
    this.programNames = const [],
    this.createdAt,
    this.raw = const {},
  });

  /// The sport id, used in every `/sports/{id}` call.
  final int id;

  final String? name;

  /// As stored by the API — possibly a relative path. Read [imageUrl] to
  /// display it.
  final String? image;

  final int? sportComplexId;
  final String? sportComplexName;

  final String? categoryRaw;

  final String? description;
  final String? equipmentRequired;
  final String? achievements;
  final String? completeInformation;

  final int? minAge;
  final int? maxAge;

  /// Free text on the wire (`"60 mins"`), not a number.
  final String? duration;

  final int? allowedMembers;

  final String? statusRaw;

  /// Null when the payload did not say — distinct from an explicit `false`, so
  /// the table never claims a sport is hidden on the strength of a missing key.
  final bool? showOnFrontend;

  final int? programCount;
  final int? courtCount;
  final int? availableCourts;

  /// Programme names for the row's tooltip, when the list payload carries them.
  final List<String> programNames;

  final DateTime? createdAt;

  final Map<String, dynamic> raw;

  SportCategory? get category => SportCategory.tryParse(categoryRaw);
  String get categoryLabel => SportCategory.labelFor(categoryRaw);

  AdminUserStatus? get status => AdminUserStatus.tryParse(statusRaw);
  String get statusLabel => status?.label ?? ((statusRaw ?? '').trim());

  bool get isActive => status == AdminUserStatus.active;
  bool get isIndoor => category == SportCategory.indoor;
  bool get isOutdoor => category == SportCategory.outdoor;

  String get displayName {
    final trimmed = (name ?? '').trim();
    return trimmed.isEmpty ? 'Unnamed sport' : trimmed;
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
  /// the sports complex module's resolver — the two routes store URLs the same
  /// three ways.
  String? get imageUrl => resolveMediaUrl(image);

  /// "6–45 yrs", or one bound when only one was sent.
  String get ageRangeLabel {
    if (minAge == null && maxAge == null) return '—';
    if (minAge != null && maxAge != null) return '$minAge–$maxAge yrs';
    return minAge != null ? '$minAge yrs and up' : 'Up to $maxAge yrs';
  }

  /// Merges a detail read over the list row, keeping anything detail omitted.
  Sport mergedWith(Sport other) {
    return Sport(
      id: other.id == 0 ? id : other.id,
      name: other.name ?? name,
      image: other.image ?? image,
      sportComplexId: other.sportComplexId ?? sportComplexId,
      sportComplexName: other.sportComplexName ?? sportComplexName,
      categoryRaw: other.categoryRaw ?? categoryRaw,
      description: other.description ?? description,
      equipmentRequired: other.equipmentRequired ?? equipmentRequired,
      achievements: other.achievements ?? achievements,
      completeInformation: other.completeInformation ?? completeInformation,
      minAge: other.minAge ?? minAge,
      maxAge: other.maxAge ?? maxAge,
      duration: other.duration ?? duration,
      allowedMembers: other.allowedMembers ?? allowedMembers,
      statusRaw: other.statusRaw ?? statusRaw,
      showOnFrontend: other.showOnFrontend ?? showOnFrontend,
      programCount: other.programCount ?? programCount,
      courtCount: other.courtCount ?? courtCount,
      availableCourts: other.availableCourts ?? availableCourts,
      programNames: other.programNames.isEmpty
          ? programNames
          : other.programNames,
      createdAt: other.createdAt ?? createdAt,
      raw: {...raw, ...other.raw},
    );
  }

  /// Returns a copy with one field changed — used by the optimistic status,
  /// visibility and assign-complex writes, which must not wait for a list
  /// reload to repaint.
  Sport copyWith({
    String? statusRaw,
    bool? showOnFrontend,
    int? sportComplexId,
    String? sportComplexName,
    String? image,
    bool clearImage = false,
  }) {
    return Sport(
      id: id,
      name: name,
      image: clearImage ? null : (image ?? this.image),
      sportComplexId: sportComplexId ?? this.sportComplexId,
      sportComplexName: sportComplexName ?? this.sportComplexName,
      categoryRaw: categoryRaw,
      description: description,
      equipmentRequired: equipmentRequired,
      achievements: achievements,
      completeInformation: completeInformation,
      minAge: minAge,
      maxAge: maxAge,
      duration: duration,
      allowedMembers: allowedMembers,
      statusRaw: statusRaw ?? this.statusRaw,
      showOnFrontend: showOnFrontend ?? this.showOnFrontend,
      programCount: programCount,
      courtCount: courtCount,
      availableCourts: availableCourts,
      programNames: programNames,
      createdAt: createdAt,
      raw: raw,
    );
  }

  @override
  String toString() =>
      'Sport($id, $name, complex: $sportComplexId, $categoryRaw, '
      '$statusRaw, frontend: $showOnFrontend)';
}

/// Counters from `GET /sports/{sportId}/stats`.
///
/// Every counter is nullable: the drawer shows an em dash for one the endpoint
/// did not send rather than a zero it cannot vouch for.
class SportStats {
  const SportStats({
    this.totalPrograms,
    this.activePrograms,
    this.totalCourts,
    this.totalStudents,
  });

  final int? totalPrograms;
  final int? activePrograms;
  final int? totalCourts;
  final int? totalStudents;

  bool get isEmpty =>
      totalPrograms == null &&
      activePrograms == null &&
      totalCourts == null &&
      totalStudents == null;

  @override
  String toString() =>
      'SportStats(programs: $activePrograms/$totalPrograms, '
      'courts: $totalCourts, students: $totalStudents)';
}

/// The write payload for create and update.
class SportDraft {
  const SportDraft({
    this.name,
    this.sportComplexId,
    this.description,
    this.category,
    this.minAge,
    this.maxAge,
    this.duration,
    this.equipmentRequired,
    this.image,
    this.allowedMembers,
    this.achievements,
    this.completeInformation,
    this.status,
    this.showOnFrontend,
  });

  final String? name;
  final int? sportComplexId;
  final String? description;
  final SportCategory? category;

  /// Numbers on the wire, unlike the staff modules' text salary — the
  /// documented payload sends `"minAge": 6`, not `"6"`.
  final int? minAge;
  final int? maxAge;

  final String? duration;
  final String? equipmentRequired;

  /// The URL returned by the upload route, or empty to send no image.
  final String? image;

  final int? allowedMembers;
  final String? achievements;
  final String? completeInformation;
  final AdminUserStatus? status;
  final bool? showOnFrontend;

  /// `POST /sports` — every documented key, in the documented shape.
  ///
  /// Optional text fields are sent as `""` rather than omitted: that is the
  /// shape the payload documents, and it lets a create explicitly leave a
  /// column blank. The three numbers are sent as null when unset, so the server
  /// stores "not specified" rather than a zero the admin never typed.
  Map<String, dynamic> toCreateJson() {
    return <String, dynamic>{
      'name': (name ?? '').trim(),
      'sportComplexId': sportComplexId,
      'description': (description ?? '').trim(),
      'category': category?.slug ?? '',
      'minAge': minAge,
      'maxAge': maxAge,
      'duration': (duration ?? '').trim(),
      'equipmentRequired': (equipmentRequired ?? '').trim(),
      'image': (image ?? '').trim(),
      'allowedMembers': allowedMembers,
      'achievements': (achievements ?? '').trim(),
      'completeInformation': (completeInformation ?? '').trim(),
      'status': (status ?? AdminUserStatus.active).slug,
      'showOnFrontend': showOnFrontend ?? false,
    };
  }

  /// `PUT /sports/{sportId}`.
  ///
  /// Every field the route documents as editable is sent, including the ones
  /// deliberately blanked — a sport's achievements or equipment list is
  /// legitimately clearable, and dropping empties would make an erase
  /// impossible. Only a field the form never set (null) is omitted.
  Map<String, dynamic> toUpdateJson() {
    final body = <String, dynamic>{};

    void put(String key, Object? value) {
      if (value == null) return;
      body[key] = value is String ? value.trim() : value;
    }

    put('name', name);
    put('sportComplexId', sportComplexId);
    put('description', description);
    put('category', category?.slug);
    put('minAge', minAge);
    put('maxAge', maxAge);
    put('duration', duration);
    put('equipmentRequired', equipmentRequired);
    put('image', image);
    put('allowedMembers', allowedMembers);
    put('achievements', achievements);
    put('completeInformation', completeInformation);
    put('status', status?.slug);
    put('showOnFrontend', showOnFrontend);

    return body;
  }
}
