import 'employee_formats.dart';

/// An event the complex is running, from `GET /event-passes`.
///
/// An event is a header plus three child collections: the [slots] people buy,
/// the [customFields] the booking form asks for, and the [faqs] shown beside
/// it. The list route sends the header and usually the slots; `GET
/// /event-passes/{id}` is the one that reliably carries all three, which is why
/// the detail sheet re-reads rather than trusting the row it was opened from.
class EmployeeEvent {
  const EmployeeEvent({
    required this.id,
    this.title = '',
    this.description,
    this.image,
    this.status = 'Active',
    this.slots = const [],
    this.customFields = const [],
    this.faqs = const [],
    this.createdAt,
  });

  final int id;
  final String title;
  final String? description;
  final String? image;

  /// `Active` | `Inactive`. Not part of the create/update body the panel sends
  /// — it is set elsewhere — so it is read-only here.
  final String status;

  final List<EmployeeEventSlot> slots;
  final List<EmployeeEventCustomField> customFields;
  final List<EmployeeEventFaq> faqs;

  final DateTime? createdAt;

  String get displayTitle => title.trim().isEmpty ? 'Event #$id' : title.trim();

  bool get isActive => status.toLowerCase() == 'active';

  /// The earliest slot date, which is what "when is this event" means for a
  /// multi-day camp. Null when no slot carried a readable date.
  DateTime? get earliestDate {
    final dates = slots
        .map((slot) => slot.date)
        .whereType<DateTime>()
        .toList(growable: false);
    if (dates.isEmpty) return null;

    return dates.reduce((a, b) => a.isBefore(b) ? a : b);
  }

  DateTime? get latestDate {
    final dates = slots
        .map((slot) => slot.date)
        .whereType<DateTime>()
        .toList(growable: false);
    if (dates.isEmpty) return null;

    return dates.reduce((a, b) => a.isAfter(b) ? a : b);
  }

  /// True once every dated slot is in the past. An event whose slots carry no
  /// date is never "past" — there is nothing to compare against, and hiding it
  /// would lose it entirely.
  bool get isPast {
    final last = latestDate;
    if (last == null) return false;
    // Compared against the start of today so an event running right now still
    // reads as upcoming rather than flipping at midnight of its own date.
    final today = DateTime.now();
    return last.isBefore(DateTime(today.year, today.month, today.day));
  }

  /// `10 Sep 2026`, or `10 Sep 2026 – 24 Sep 2026` when the slots span days.
  String get dateLabel {
    final first = earliestDate;
    if (first == null) return 'Dates not set';

    final last = latestDate;
    if (last == null || last == first) return formatDay(first);
    return '${formatDay(first)} – ${formatDay(last)}';
  }

  /// The cheapest slot price, which is what a "from ₹500" line should read.
  num? get lowestPrice {
    final prices = slots.map((slot) => slot.price).toList(growable: false);
    if (prices.isEmpty) return null;

    return prices.reduce((a, b) => a < b ? a : b);
  }

  String get priceLabel {
    final lowest = lowestPrice;
    if (lowest == null) return 'No slots';
    if (slots.length == 1) return formatRupees(lowest);
    return 'From ${formatRupees(lowest)}';
  }

  String get slotsLabel =>
      '${slots.length} slot${slots.length == 1 ? '' : 's'}';

  @override
  String toString() => 'EmployeeEvent($id, $displayTitle, ${slots.length} slots)';
}

/// One bookable slot on an event.
class EmployeeEventSlot {
  const EmployeeEventSlot({
    this.id,
    this.name = '',
    this.date,
    this.price = 0,
    this.passType = 'Single',
    this.startTime,
    this.endTime,
    this.capacity,
    this.booked,
  });

  /// Null for a slot the form has just added. Sending an existing id back
  /// updates that slot in place; omitting it creates a new one.
  final int? id;

  final String name;
  final DateTime? date;
  final num price;

  /// `Single` | `Couple` | `Family` | `Group` — how many people one pass admits.
  final String passType;

  /// `"07:00"`. Kept as the wire string rather than a `TimeOfDay` so a slot can
  /// round-trip through the form untouched when the user did not edit it.
  final String? startTime;
  final String? endTime;

  final int? capacity;
  final int? booked;

  String get displayName => name.trim().isEmpty ? 'Slot' : name.trim();

  String get dateLabel => formatDay(date);

  /// `7:00 AM – 9:00 AM`, or null when neither end arrived.
  String? get timeLabel {
    final from = formatClock(startTime);
    final to = formatClock(endTime);
    if (from == null && to == null) return null;
    if (to == null) return from;
    if (from == null) return to;
    return '$from – $to';
  }

  String get priceLabel => formatRupees(price);

  /// `12/40 booked`, or null when the slot did not report capacity.
  String? get capacityLabel {
    final max = capacity;
    final taken = booked;
    if (max == null || taken == null) return null;
    return '$taken/$max booked';
  }

  Map<String, dynamic> toJson() {
    final body = <String, dynamic>{
      if (id != null) 'id': id,
      'name': name.trim(),
      'price': price,
      'passType': passType,
    };

    final day = date;
    if (day != null) body['date'] = formatIsoDate(day);

    final from = startTime?.trim();
    if (from != null && from.isNotEmpty) body['startTime'] = from;

    final to = endTime?.trim();
    if (to != null && to.isNotEmpty) body['endTime'] = to;

    return body;
  }

  EmployeeEventSlot copyWith({
    String? name,
    DateTime? date,
    num? price,
    String? passType,
    String? startTime,
    String? endTime,
  }) {
    return EmployeeEventSlot(
      id: id,
      name: name ?? this.name,
      date: date ?? this.date,
      price: price ?? this.price,
      passType: passType ?? this.passType,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      capacity: capacity,
      booked: booked,
    );
  }

  static const List<String> passTypes = ['Single', 'Couple', 'Family', 'Group'];
}

/// One extra question on the event's booking form.
class EmployeeEventCustomField {
  const EmployeeEventCustomField({
    this.id,
    this.label = '',
    this.type = 'text',
    this.required = false,
    this.placeholder,
    this.options = const [],
  });

  final int? id;
  final String label;

  /// `text` | `number` | `date` | `select`.
  final String type;

  final bool required;
  final String? placeholder;

  /// Only meaningful for `select`, where the API requires at least one.
  final List<String> options;

  bool get isSelect => type.toLowerCase() == 'select';

  /// The server's rule: a `select` with no options is rejected.
  bool get isValid {
    if (label.trim().isEmpty) return false;
    if (isSelect && options.isEmpty) return false;
    return true;
  }

  String get summary {
    final parts = <String>[
      type,
      if (required) 'required',
      if (isSelect) '${options.length} option${options.length == 1 ? '' : 's'}',
    ];
    return parts.join(' · ');
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (id != null) 'id': id,
        'label': label.trim(),
        'type': type,
        'required': required,
        'placeholder': placeholder?.trim().isEmpty ?? true
            ? null
            : placeholder!.trim(),
        // Sent only for `select`: the API reads `options` for that type alone,
        // and an empty array on a text field reads as a malformed select.
        if (isSelect) 'options': options,
      };

  static const List<String> types = ['text', 'number', 'date', 'select'];
}

/// One question-and-answer shown beside the event.
class EmployeeEventFaq {
  const EmployeeEventFaq({this.id, this.question = '', this.answer = ''});

  final int? id;
  final String question;
  final String answer;

  bool get isValid =>
      question.trim().isNotEmpty && answer.trim().isNotEmpty;

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (id != null) 'id': id,
        'question': question.trim(),
        'answer': answer.trim(),
      };
}

/// The create/edit form behind `POST /event-passes` and
/// `PUT /event-passes/{id}`.
///
/// Create and update take the **same** body. Including a child's existing `id`
/// updates that row in place; leaving it out creates a new one, and a child
/// left out of the array entirely is removed — which is why the form always
/// sends all three collections, even when empty.
class EmployeeEventDraft {
  const EmployeeEventDraft({
    this.title = '',
    this.description,
    this.image,
    this.slots = const [],
    this.customFields = const [],
    this.faqs = const [],
  });

  final String title;
  final String? description;
  final String? image;

  final List<EmployeeEventSlot> slots;
  final List<EmployeeEventCustomField> customFields;
  final List<EmployeeEventFaq> faqs;

  String? get validationError {
    if (title.trim().isEmpty) return 'Enter a title for the event.';

    for (final field in customFields) {
      if (field.label.trim().isEmpty) {
        return 'Every custom field needs a label.';
      }
      if (field.isSelect && field.options.isEmpty) {
        return 'The "${field.label.trim()}" dropdown needs at least one option.';
      }
    }

    for (final faq in faqs) {
      if (!faq.isValid) return 'Every FAQ needs both a question and an answer.';
    }

    return null;
  }

  Map<String, dynamic> toJson() {
    final note = description?.trim();
    final banner = image?.trim();

    return <String, dynamic>{
      'title': title.trim(),
      'description': note == null || note.isEmpty ? null : note,
      // Explicit null clears the banner, which is how the panel removes one.
      'image': banner == null || banner.isEmpty ? null : banner,
      'slots': slots.map((slot) => slot.toJson()).toList(growable: false),
      'customFields':
          customFields.map((field) => field.toJson()).toList(growable: false),
      'faqs': faqs.map((faq) => faq.toJson()).toList(growable: false),
    };
  }

  /// Seeds the edit form from an event already on screen.
  factory EmployeeEventDraft.from(EmployeeEvent event) {
    return EmployeeEventDraft(
      title: event.title,
      description: event.description,
      image: event.image,
      slots: event.slots,
      customFields: event.customFields,
      faqs: event.faqs,
    );
  }
}

/// The `timeframe` filter on `GET /event-passes`.
///
/// The split is made server-side, so the two tabs are two queries rather than
/// one list filtered on the phone — a past event may be many pages back.
enum EmployeeEventTimeframe {
  upcoming('upcoming', 'Upcoming'),
  past('past', 'Past'),

  /// Sends no `timeframe` at all, which asks for both.
  all('', 'All');

  const EmployeeEventTimeframe(this.query, this.label);

  final String query;
  final String label;

  /// Null for [all], so the data source can drop the parameter rather than
  /// sending an empty one the backend would have to interpret.
  String? get queryOrNull => query.isEmpty ? null : query;
}
