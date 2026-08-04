/// Models for `GET /event-passes`.
library;

/// A bookable phase/slot of an event pass.
class EventPassSlot {
  const EventPassSlot({
    this.id,
    this.eventPassId,
    this.name,
    this.date,
    this.price,
    this.passType,
    this.startTime,
    this.endTime,
    this.status,
  });

  final int? id;
  final int? eventPassId;
  final String? name;

  /// `yyyy-MM-dd`.
  final String? date;

  /// Decimal string, e.g. `"200.00"`.
  final String? price;

  final String? passType;

  /// `HH:mm:ss`.
  final String? startTime;
  final String? endTime;

  final String? status;

  bool get isActive => (status ?? 'Active').toLowerCase() == 'active';

  DateTime? get dateTime => DateTime.tryParse(date ?? '');

  /// True when the slot's date is today or later.
  bool get isUpcoming {
    final day = dateTime;
    if (day == null) return false;
    final today = DateTime.now();
    return !day.isBefore(DateTime(today.year, today.month, today.day));
  }

  double get priceValue => double.tryParse(price ?? '') ?? 0;

  factory EventPassSlot.fromJson(Map<String, dynamic> json) => EventPassSlot(
        id: _asInt(json['id']),
        eventPassId: _asInt(json['eventPassId'] ?? json['event_pass_id']),
        name: _asString(json['name'] ?? json['slot_name']),
        date: _asString(json['date'] ?? json['pass_date']),
        price: _asString(json['price'] ?? json['pass_price']),
        passType: _asString(json['passType'] ?? json['pass_type']),
        startTime: _asString(json['startTime'] ?? json['start_time']),
        endTime: _asString(json['endTime'] ?? json['end_time']),
        status: _asString(json['status']),
      );

  /// Shape consumed by the booking UI, which reads a plain map.
  Map<String, dynamic> toBookingMap() => <String, dynamic>{
        'id': id,
        'name': name ?? '',
        'date': date ?? '',
        'price': price ?? '0',
        'pass_type': passType ?? '',
        'start': startTime ?? '',
        'end': endTime ?? '',
      };
}

/// A question/answer pair attached to an event pass.
class EventFaq {
  const EventFaq({this.question, this.answer});

  final String? question;
  final String? answer;

  factory EventFaq.fromJson(Map<String, dynamic> json) => EventFaq(
        question: _asString(json['question']),
        answer: _asString(json['answer']),
      );

  Map<String, dynamic> toJson() => {'question': question, 'answer': answer};
}

/// An event pass, with its slots and the venue that hosts it.
class EventPassModel {
  const EventPassModel({
    this.id,
    this.sportComplexId,
    this.title,
    this.description,
    this.image,
    this.status,
    this.createdAt,
    this.updatedAt,
    this.slots = const <EventPassSlot>[],
    this.faqs = const <EventFaq>[],
    this.venueName,
  });

  final int? id;
  final int? sportComplexId;
  final String? title;
  final String? description;
  final String? image;
  final String? status;
  final String? createdAt;
  final String? updatedAt;
  final List<EventPassSlot> slots;
  final List<EventFaq> faqs;

  /// From the nested `sportComplex` object.
  final String? venueName;

  bool get isActive => (status ?? '').toLowerCase() == 'active';

  List<EventPassSlot> get activeSlots =>
      slots.where((s) => s.isActive).toList(growable: false);

  /// True when any slot is today or later — what "upcoming" means for an event.
  bool get hasUpcomingSlot => activeSlots.any((s) => s.isUpcoming);

  /// Earliest slot date, used to order upcoming events.
  DateTime? get earliestSlotDate {
    final dates = activeSlots
        .map((s) => s.dateTime)
        .whereType<DateTime>()
        .toList()
      ..sort();
    return dates.isEmpty ? null : dates.first;
  }

  /// Lowest slot price, or 0 when there are no slots.
  double get lowestPrice {
    final prices =
        activeSlots.map((s) => s.priceValue).where((p) => p > 0).toList()
          ..sort();
    return prices.isEmpty ? 0 : prices.first;
  }

  factory EventPassModel.fromJson(Map<String, dynamic> json) {
    final complex = _asObject(json['sportComplex']);

    return EventPassModel(
      id: _asInt(json['id']),
      sportComplexId: _asInt(json['sportComplexId'] ?? json['sport_complex_id']),
      title: _asString(json['title']),
      description: _asString(json['description']),
      image: _asString(json['image']),
      status: _asString(json['status']),
      createdAt: _asString(json['createdAt']),
      updatedAt: _asString(json['updatedAt']),
      slots: _asList(json['slots'])
          .map(EventPassSlot.fromJson)
          .toList(growable: false),
      faqs:
          _asList(json['faqs']).map(EventFaq.fromJson).toList(growable: false),
      venueName: complex == null ? null : _asString(complex['name']),
    );
  }
}

/// One page of `GET /event-passes`.
class EventPassPage {
  const EventPassPage({
    this.events = const <EventPassModel>[],
    this.currentPage = 1,
    this.totalPages = 1,
    this.totalItems = 0,
    this.itemsPerPage = 50,
  });

  final List<EventPassModel> events;
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final int itemsPerPage;

  bool get hasMore => currentPage < totalPages;

  /// The list lives at the top level in `data`; paging metadata sits beside it
  /// in `pagination`.
  factory EventPassPage.fromJson({
    Object? data,
    Map<String, dynamic>? pagination,
  }) {
    final page = pagination ?? const <String, dynamic>{};
    return EventPassPage(
      events: _asList(data)
          .map(EventPassModel.fromJson)
          .toList(growable: false),
      currentPage: _asInt(page['currentPage']) ?? 1,
      totalPages: _asInt(page['totalPages']) ?? 1,
      totalItems: _asInt(page['totalItems']) ?? 0,
      itemsPerPage: _asInt(page['itemsPerPage']) ?? 50,
    );
  }
}

// -----------------------------------------------------------------------------
// Parsing helpers — null- and type-tolerant.
// -----------------------------------------------------------------------------

String? _asString(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  if (text.isEmpty || text.toLowerCase() == 'null') return null;
  return text;
}

int? _asInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

Map<String, dynamic>? _asObject(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

List<Map<String, dynamic>> _asList(Object? value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return value
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList(growable: false);
}
