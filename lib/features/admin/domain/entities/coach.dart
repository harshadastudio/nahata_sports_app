import 'admin_role.dart';
import 'admin_sports_complex.dart';
import 'sport.dart';

/// The seven days, in the order a schedule reads.
///
/// Enumerated by the product spec rather than by any endpoint — there is no
/// `/availability` route — and used only to *interpret* what the API stored.
/// A schedule this list cannot parse is kept verbatim; see [CoachAvailability].
enum Weekday {
  monday('Monday', 'Mon'),
  tuesday('Tuesday', 'Tue'),
  wednesday('Wednesday', 'Wed'),
  thursday('Thursday', 'Thu'),
  friday('Friday', 'Fri'),
  saturday('Saturday', 'Sat'),
  sunday('Sunday', 'Sun');

  const Weekday(this.label, this.shortLabel);

  final String label;
  final String shortLabel;

  /// `DateTime.monday` is 1 and `DateTime.sunday` is 7 — the same order as this
  /// enum, so the index maps straight across.
  int get dateTimeWeekday => index + 1;

  static Weekday? tryParse(Object? value) {
    final text = (value ?? '').toString().trim().toLowerCase();
    if (text.isEmpty) return null;
    for (final day in Weekday.values) {
      if (day.label.toLowerCase() == text) return day;
      if (day.shortLabel.toLowerCase() == text) return day;
    }
    return null;
  }

  static Weekday of(DateTime moment) =>
      Weekday.values[moment.weekday - 1];
}

/// A coach's availability, as stored by the API.
///
/// The payload carries one free-text field (`"availability": ""`), and the spec
/// asks for it to be stored "exactly as the API expects" — so [raw] is the only
/// thing ever sent. [days] is a *reading* of that text for the chips and the
/// "available today" card: when every comma-separated token is a day name the
/// schedule is understood, and when it is not ([isCustom]) the text is shown as
/// written rather than being coerced into days it does not say.
class CoachAvailability {
  const CoachAvailability({
    required this.raw,
    this.days = const [],
    this.isCustom = false,
  });

  static const CoachAvailability none = CoachAvailability(raw: '');

  /// Exactly what the server stored, and exactly what a save sends back.
  final String raw;

  /// The days [raw] names, in week order. Empty when [isCustom].
  final List<Weekday> days;

  /// True when [raw] says something the day list cannot express — an hour
  /// range, "Weekdays only", a note. The chips go read-only in that case.
  final bool isCustom;

  bool get isEmpty => raw.trim().isEmpty;
  bool get isNotEmpty => !isEmpty;

  /// True when the coach's schedule names today. Null when there is nothing to
  /// go on — an unset or unparseable schedule is not evidence of absence, so
  /// the summary card counts it as unknown rather than unavailable.
  bool? availableOn(DateTime moment) {
    if (isEmpty || isCustom) return null;
    return days.contains(Weekday.of(moment));
  }

  /// Reads a stored value. Separators drift between commas, slashes, pipes and
  /// newlines, so all four split.
  static CoachAvailability parse(Object? value) {
    final text = (value ?? '').toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return none;

    final tokens = text
        .split(RegExp(r'[,/|\n]+'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);

    if (tokens.isEmpty) return CoachAvailability(raw: text, isCustom: true);

    final parsed = <Weekday>{};
    for (final token in tokens) {
      final day = Weekday.tryParse(token);
      // One unrecognised token makes the whole schedule custom: a partial
      // reading would silently drop whatever the admin actually wrote.
      if (day == null) return CoachAvailability(raw: text, isCustom: true);
      parsed.add(day);
    }

    final ordered = Weekday.values
        .where(parsed.contains)
        .toList(growable: false);
    return CoachAvailability(raw: text, days: ordered);
  }

  /// The canonical string for a set of days — what the day chips write back.
  static String compose(Iterable<Weekday> days) {
    final selected = Weekday.values
        .where(days.toSet().contains)
        .map((day) => day.label);
    return selected.join(', ');
  }

  /// "3 days", "Every day", or the raw text when it is custom.
  String get summaryLabel {
    if (isEmpty) return '—';
    if (isCustom) return raw;
    if (days.length == 7) return 'Every day';
    if (days.length == 1) return days.first.label;
    return '${days.length} days';
  }

  @override
  String toString() =>
      'CoachAvailability(${isCustom ? 'custom' : days.map((d) => d.shortLabel).join('/')})';
}

/// A coach (`/coaches`).
///
/// Every field except [id] is nullable so a thinner list payload is never
/// padded with invented values; the UI renders "—" for anything absent.
class Coach {
  const Coach({
    required this.id,
    this.name,
    this.email,
    this.phone,
    this.image,
    this.sportId,
    this.sportName,
    this.sportNames = const [],
    this.sportComplexId,
    this.sportComplexName,
    this.ground,
    this.categoryRaw,
    this.experience,
    this.price,
    this.certification,
    this.qualifications,
    this.specialization,
    this.bio,
    this.availabilityRaw,
    this.statusRaw,
    this.createdAt,
    this.raw = const {},
  });

  /// The coach id, used in every `/coaches/{id}` call.
  final int id;

  final String? name;
  final String? email;
  final String? phone;

  /// As stored by the API — possibly a relative path. Read [imageUrl] to
  /// display it.
  final String? image;

  /// The primary sport — the one the create payload sends as `sportId`.
  final int? sportId;
  final String? sportName;

  /// Every sport the coach is assigned to, when the payload lists them. The
  /// primary sport is not assumed to be in here, and is not added to it.
  final List<String> sportNames;

  final int? sportComplexId;
  final String? sportComplexName;

  /// Free text: there is no `/grounds` route to pick from.
  final String? ground;

  /// Indoor / outdoor. Belongs to the sport rather than the coach, so it is
  /// only present when the payload carried it.
  final String? categoryRaw;

  /// Free text on the wire (`"5 years"`), not a number.
  final String? experience;

  /// The coaching fee. Numeric on the wire (`"price": 0`).
  final num? price;

  final String? certification;
  final String? qualifications;
  final String? specialization;
  final String? bio;

  final String? availabilityRaw;

  final String? statusRaw;

  final DateTime? createdAt;

  final Map<String, dynamic> raw;

  CoachAvailability get availability => CoachAvailability.parse(availabilityRaw);

  SportCategory? get category => SportCategory.tryParse(categoryRaw);
  String get categoryLabel => SportCategory.labelFor(categoryRaw);

  AdminUserStatus? get status => AdminUserStatus.tryParse(statusRaw);
  String get statusLabel => status?.label ?? ((statusRaw ?? '').trim());

  bool get isActive => status == AdminUserStatus.active;

  String get displayName {
    final trimmed = (name ?? '').trim();
    return trimmed.isEmpty ? 'Unnamed coach' : trimmed;
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

  /// Every sport worth showing as a chip: the primary one first, then any
  /// others the payload listed, without repeating it.
  List<String> get allSportNames {
    final primary = (sportName ?? '').trim();
    final seen = <String>{if (primary.isNotEmpty) primary.toLowerCase()};
    final result = <String>[if (primary.isNotEmpty) primary];

    for (final sport in sportNames) {
      final trimmed = sport.trim();
      if (trimmed.isEmpty) continue;
      if (seen.add(trimmed.toLowerCase())) result.add(trimmed);
    }
    return result;
  }

  /// Text a local search should match, per the spec: name, email and phone.
  bool matches(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    return displayName.toLowerCase().contains(needle) ||
        (email ?? '').toLowerCase().contains(needle) ||
        (phone ?? '').toLowerCase().contains(needle);
  }

  /// Merges a detail read over the list row, keeping anything detail omitted.
  Coach mergedWith(Coach other) {
    return Coach(
      id: other.id == 0 ? id : other.id,
      name: other.name ?? name,
      email: other.email ?? email,
      phone: other.phone ?? phone,
      image: other.image ?? image,
      sportId: other.sportId ?? sportId,
      sportName: other.sportName ?? sportName,
      sportNames: other.sportNames.isEmpty ? sportNames : other.sportNames,
      sportComplexId: other.sportComplexId ?? sportComplexId,
      sportComplexName: other.sportComplexName ?? sportComplexName,
      ground: other.ground ?? ground,
      categoryRaw: other.categoryRaw ?? categoryRaw,
      experience: other.experience ?? experience,
      price: other.price ?? price,
      certification: other.certification ?? certification,
      qualifications: other.qualifications ?? qualifications,
      specialization: other.specialization ?? specialization,
      bio: other.bio ?? bio,
      availabilityRaw: other.availabilityRaw ?? availabilityRaw,
      statusRaw: other.statusRaw ?? statusRaw,
      createdAt: other.createdAt ?? createdAt,
      raw: {...raw, ...other.raw},
    );
  }

  /// Returns a copy with one field changed — used by the optimistic status
  /// write, which must not wait for a list reload to repaint.
  Coach copyWith({String? statusRaw, String? image, bool clearImage = false}) {
    return Coach(
      id: id,
      name: name,
      email: email,
      phone: phone,
      image: clearImage ? null : (image ?? this.image),
      sportId: sportId,
      sportName: sportName,
      sportNames: sportNames,
      sportComplexId: sportComplexId,
      sportComplexName: sportComplexName,
      ground: ground,
      categoryRaw: categoryRaw,
      experience: experience,
      price: price,
      certification: certification,
      qualifications: qualifications,
      specialization: specialization,
      bio: bio,
      availabilityRaw: availabilityRaw,
      statusRaw: statusRaw ?? this.statusRaw,
      createdAt: createdAt,
      raw: raw,
    );
  }

  @override
  String toString() =>
      'Coach($id, $name, sport: $sportId, complex: $sportComplexId, '
      '$statusRaw)';
}

/// Counters from `GET /coaches/{coachId}/stats`.
///
/// Every counter is nullable: the drawer shows an em dash for one the endpoint
/// did not send rather than a zero it cannot vouch for.
class CoachStats {
  const CoachStats({
    this.totalPrograms,
    this.activePrograms,
    this.totalStudents,
    this.statusRaw,
  });

  final int? totalPrograms;
  final int? activePrograms;
  final int? totalStudents;

  /// The stats route echoes the coach's status; it is shown beside the
  /// counters rather than being used to overwrite the row.
  final String? statusRaw;

  AdminUserStatus? get status => AdminUserStatus.tryParse(statusRaw);

  bool get isEmpty =>
      totalPrograms == null &&
      activePrograms == null &&
      totalStudents == null &&
      (statusRaw ?? '').trim().isEmpty;

  @override
  String toString() =>
      'CoachStats(programs: $activePrograms/$totalPrograms, '
      'students: $totalStudents, status: $statusRaw)';
}

/// A coach's sign-in credentials, from `GET /coaches/{coachId}/password`.
class CoachCredentials {
  const CoachCredentials({this.email, this.password});

  final String? email;
  final String? password;

  bool get hasPassword => (password ?? '').trim().isNotEmpty;

  /// Never interpolates the password — this is what shows up in a log line if
  /// one of these is ever printed by accident.
  @override
  String toString() =>
      'CoachCredentials(email: $email, password: ${hasPassword ? '***' : 'none'})';
}

/// The write payload for create and update.
class CoachDraft {
  const CoachDraft({
    this.name,
    this.email,
    this.phone,
    this.password,
    this.sportId,
    this.sportComplexId,
    this.ground,
    this.price,
    this.availability,
    this.certification,
    this.bio,
    this.image,
    this.experience,
    this.specialization,
    this.qualifications,
    this.status,
  });

  final String? name;
  final String? email;
  final String? phone;

  /// Create only. The update route does not document a password field, and
  /// changing one goes through `/reset-password` instead.
  final String? password;

  final int? sportId;
  final int? sportComplexId;
  final String? ground;

  /// A number on the wire, unlike the staff modules' text salary — the
  /// documented payload sends `"price": 0`.
  final num? price;

  /// Sent exactly as stored; see [CoachAvailability].
  final String? availability;

  final String? certification;
  final String? bio;

  /// The URL returned by the upload route, or empty to send no image.
  final String? image;

  final String? experience;
  final String? specialization;

  /// The documented key is plural even though the form labels it
  /// "Qualification".
  final String? qualifications;

  final AdminUserStatus? status;

  /// `POST /coaches` — every documented key, in the documented order and shape.
  ///
  /// Optional text fields are sent as `""` rather than omitted: that is the
  /// shape the payload documents, and it lets a create explicitly leave a
  /// column blank. [price] is sent as null when unset, so the server stores
  /// "not specified" rather than a zero fee the admin never typed.
  Map<String, dynamic> toCreateJson() {
    return <String, dynamic>{
      'name': (name ?? '').trim(),
      'email': (email ?? '').trim(),
      'phone': (phone ?? '').trim(),
      'password': password ?? '',
      'sportId': sportId,
      'sportComplexId': sportComplexId,
      'ground': (ground ?? '').trim(),
      'price': price,
      'availability': (availability ?? '').trim(),
      'certification': (certification ?? '').trim(),
      'bio': (bio ?? '').trim(),
      'image': (image ?? '').trim(),
      'experience': (experience ?? '').trim(),
      'specialization': (specialization ?? '').trim(),
      'qualifications': (qualifications ?? '').trim(),
      'status': (status ?? AdminUserStatus.active).slug,
    };
  }

  /// `PUT /coaches/{coachId}`.
  ///
  /// Only the eleven fields the route documents as editable are sent. Email,
  /// password and the sport / complex / ground assignment are deliberately
  /// absent: the edit dialog renders those read-only for the same reason.
  ///
  /// A field the form never set (null) is omitted; one the admin deliberately
  /// blanked is sent empty, or a bio could never be cleared once written.
  Map<String, dynamic> toUpdateJson() {
    final body = <String, dynamic>{};

    void put(String key, Object? value) {
      if (value == null) return;
      body[key] = value is String ? value.trim() : value;
    }

    put('name', name);
    put('phone', phone);
    put('experience', experience);
    put('price', price);
    put('certification', certification);
    put('qualifications', qualifications);
    put('specialization', specialization);
    put('bio', bio);
    put('availability', availability);
    put('image', image);
    put('status', status?.slug);

    return body;
  }
}