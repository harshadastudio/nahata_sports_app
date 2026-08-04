import '../../domain/entities/paged.dart';
import '../../domain/entities/report.dart';
import 'court_model.dart';
import 'json_reader.dart';

/// One documented figure: where to look for it, and how it should read.
class FigureSpec {
  const FigureSpec(
    this.key,
    this.label,
    this.candidates, [
    this.format = ReportFormat.count,
  ]);

  final String key;
  final String label;
  final List<String> candidates;
  final ReportFormat format;
}

/// One documented series.
class SeriesSpec {
  const SeriesSpec(
    this.key,
    this.label,
    this.candidates, {
    this.format = ReportFormat.count,
    this.valueLabel,
  });

  final String key;
  final String label;
  final List<String> candidates;
  final ReportFormat format;
  final String? valueLabel;
}

/// Maps `/reports/*` JSON onto the report entities.
///
/// **No response was captured for any of these nineteen routes** — the module
/// documents what each screen must *display*, not what the payload looks like.
/// So each section is described by the figures the module names, read through
/// ordered candidate keys, and anything else numeric that came back is kept as
/// an extra rather than dropped.
class ReportMapper {
  const ReportMapper._();

  // ---------------------------------------------------------------------------
  // Section specs — one per documented endpoint.
  // ---------------------------------------------------------------------------

  /// `GET /reports/overview`
  static const List<FigureSpec> overviewFigures = [
    FigureSpec('revenue', 'Total revenue', [
      'totalRevenue',
      'total_revenue',
      'revenue',
    ], ReportFormat.currency),
    FigureSpec('bookings', 'Total bookings', [
      'totalBookings',
      'total_bookings',
      'bookings',
    ]),
    FigureSpec('students', 'Total students', [
      'totalStudents',
      'total_students',
      'students',
    ]),
    FigureSpec('coaches', 'Total coaches', [
      'totalCoaches',
      'total_coaches',
      'coaches',
    ]),
    FigureSpec('memberships', 'Total memberships', [
      'totalMemberships',
      'total_memberships',
      'memberships',
    ]),
    FigureSpec('courts', 'Active courts', [
      'activeCourts',
      'active_courts',
      'courts',
    ]),
    FigureSpec('occupancy', 'Occupancy', [
      'occupancy',
      'occupancyRate',
      'occupancy_rate',
    ], ReportFormat.percent),
    FigureSpec('growth', 'Growth', [
      'growth',
      'growthPercent',
      'growth_percent',
      'growthRate',
    ], ReportFormat.percent),
  ];

  /// `GET /reports/revenue`
  static const List<FigureSpec> revenueFigures = [
    FigureSpec('total', 'Total revenue', [
      'totalRevenue',
      'total_revenue',
      'revenue',
      'total',
    ], ReportFormat.currency),
    FigureSpec('paid', 'Paid', [
      'paidRevenue',
      'paid',
      'paidAmount',
    ], ReportFormat.currency),
    FigureSpec('pending', 'Pending', [
      'pendingRevenue',
      'pending',
      'pendingAmount',
    ], ReportFormat.currency),
    FigureSpec('refunded', 'Refunded', [
      'refundedRevenue',
      'refunded',
      'refundedAmount',
    ], ReportFormat.currency),
    FigureSpec('average', 'Average booking value', [
      'averageBookingValue',
      'avgBookingValue',
      'average',
    ], ReportFormat.currency),
  ];

  static const List<SeriesSpec> revenueSeries = [
    SeriesSpec('monthly', 'Monthly revenue', [
      'monthlyRevenue',
      'monthly',
      'byMonth',
      'months',
    ], format: ReportFormat.currency, valueLabel: 'Revenue'),
    SeriesSpec('daily', 'Daily revenue', [
      'dailyRevenue',
      'daily',
      'byDay',
      'days',
    ], format: ReportFormat.currency, valueLabel: 'Revenue'),
    SeriesSpec('paymentStatus', 'Payment status', [
      'paymentStatus',
      'payment_status',
      'byPaymentStatus',
      'payments',
    ], format: ReportFormat.currency, valueLabel: 'Revenue'),
    SeriesSpec('breakdown', 'Revenue breakdown', [
      'revenueBreakdown',
      'breakdown',
      'bySource',
      'sources',
    ], format: ReportFormat.currency, valueLabel: 'Revenue'),
  ];

  /// `GET /reports/bookings`
  static const List<FigureSpec> bookingFigures = [
    FigureSpec('total', 'Total bookings', [
      'totalBookings',
      'total_bookings',
      'total',
      'bookings',
    ]),
    FigureSpec('completed', 'Completed', [
      'completedBookings',
      'completed',
    ]),
    FigureSpec('confirmed', 'Confirmed', ['confirmedBookings', 'confirmed']),
    FigureSpec('pending', 'Pending', ['pendingBookings', 'pending']),
    FigureSpec('cancelled', 'Cancelled', [
      'cancelledBookings',
      'cancelled',
      'canceled',
    ]),
  ];

  static const List<SeriesSpec> bookingSeries = [
    SeriesSpec('trends', 'Booking trends', [
      'bookingTrends',
      'trends',
      'daily',
      'byDay',
    ], valueLabel: 'Bookings'),
  ];

  /// `GET /reports/students/new-retention`
  static const List<FigureSpec> retentionFigures = [
    FigureSpec('newStudents', 'New students', [
      'newStudents',
      'new_students',
      'new',
    ]),
    FigureSpec('returning', 'Returning students', [
      'returningStudents',
      'returning_students',
      'returning',
    ]),
    FigureSpec('retention', 'Retention', [
      'retentionRate',
      'retention_rate',
      'retention',
    ], ReportFormat.percent),
    FigureSpec('lost', 'Lost students', [
      'lostStudents',
      'lost_students',
      'lost',
      'churned',
    ]),
  ];

  static const List<SeriesSpec> retentionSeries = [
    SeriesSpec('growth', 'Monthly growth', [
      'monthlyGrowth',
      'monthly_growth',
      'growth',
      'monthly',
    ], valueLabel: 'Students'),
  ];

  /// `GET /reports/memberships`
  static const List<FigureSpec> membershipFigures = [
    FigureSpec('active', 'Active memberships', [
      'activeMemberships',
      'active',
    ]),
    FigureSpec('expired', 'Expired', ['expiredMemberships', 'expired']),
    FigureSpec('cancelled', 'Cancelled', [
      'cancelledMemberships',
      'cancelled',
      'canceled',
    ]),
    FigureSpec('revenue', 'Revenue', [
      'membershipRevenue',
      'totalRevenue',
      'revenue',
    ], ReportFormat.currency),
    FigureSpec('renewal', 'Renewal rate', [
      'renewalRate',
      'renewal_rate',
      'renewal',
    ], ReportFormat.percent),
  ];

  static const List<SeriesSpec> membershipSeries = [
    SeriesSpec('growth', 'Membership growth', [
      'membershipGrowth',
      'growth',
      'monthly',
      'byMonth',
    ], valueLabel: 'Memberships'),
  ];

  /// `GET /reports/users`
  static const List<FigureSpec> userFigures = [
    FigureSpec('newUsers', 'New users', ['newUsers', 'new_users', 'new']),
    FigureSpec('active', 'Active users', ['activeUsers', 'active']),
    FigureSpec('returning', 'Returning users', [
      'returningUsers',
      'returning',
    ]),
    FigureSpec('inactive', 'Inactive users', ['inactiveUsers', 'inactive']),
  ];

  static const List<SeriesSpec> userSeries = [
    SeriesSpec('signups', 'Daily signups', [
      'dailySignups',
      'daily_signups',
      'signups',
      'daily',
    ], valueLabel: 'Signups'),
  ];

  /// `GET /reports/coaching`
  static const List<FigureSpec> coachingFigures = [
    FigureSpec('revenue', 'Coaching revenue', [
      'coachingRevenue',
      'totalRevenue',
      'revenue',
    ], ReportFormat.currency),
    FigureSpec('programs', 'Active programs', [
      'activePrograms',
      'programs',
      'activeBatches',
    ]),
    FigureSpec('utilization', 'Coach utilization', [
      'coachUtilization',
      'coach_utilization',
      'utilization',
    ], ReportFormat.percent),
    FigureSpec('attendance', 'Student attendance', [
      'studentAttendance',
      'attendance',
      'attendanceRate',
    ], ReportFormat.percent),
    FigureSpec('occupancy', 'Batch occupancy', [
      'batchOccupancy',
      'occupancy',
      'batch_occupancy',
    ], ReportFormat.percent),
  ];

  /// `GET /reports/facilities`
  static const List<FigureSpec> facilityFigures = [
    FigureSpec('utilization', 'Court utilization', [
      'courtUtilization',
      'court_utilization',
      'utilization',
    ], ReportFormat.percent),
    FigureSpec('usage', 'Facility usage', [
      'facilityUsage',
      'facility_usage',
      'usage',
    ], ReportFormat.percent),
    FigureSpec('idle', 'Idle hours', [
      'idleHours',
      'idle_hours',
      'idle',
    ], ReportFormat.minutes),
    FigureSpec('maintenance', 'Maintenance time', [
      'maintenanceTime',
      'maintenance_time',
      'maintenance',
    ], ReportFormat.minutes),
  ];

  static const List<SeriesSpec> facilitySeries = [
    SeriesSpec('peak', 'Peak hours', [
      'peakHours',
      'peak_hours',
      'peak',
      'byHour',
    ], valueLabel: 'Bookings'),
    SeriesSpec('usage', 'Facility usage', [
      'facilityUsage',
      'byFacility',
      'facilities',
      'courts',
    ], valueLabel: 'Bookings'),
  ];

  // ---------------------------------------------------------------------------
  // Section reading
  // ---------------------------------------------------------------------------

  /// Keys that are never a figure: envelope fields and the echoed window.
  static const Set<String> _ignoredKeys = {
    'success',
    'status',
    'message',
    'data',
    'from',
    'to',
    'startdate',
    'enddate',
    'start_date',
    'end_date',
    'range',
    'period',
    'id',
    '_id',
    'page',
    'limit',
    'total_pages',
    'totalpages',
    'currentpage',
  };

  /// A number, but only from a scalar.
  ///
  /// [CourtMapper.number] strips non-digits from `toString()`, which turns a
  /// whole nested list into a plausible-looking integer — so collections are
  /// refused here before they can become a figure or a chart point.
  static num? _numeric(Object? value) {
    if (value is List || value is Map || value is bool) return null;
    return CourtMapper.number(value);
  }

  static ReportSection section(
    Object? body, {
    List<FigureSpec> figures = const [],
    List<SeriesSpec> series = const [],
  }) {
    final source = _unwrap(body);
    if (source.isEmpty) return const ReportSection();

    final consumed = <String>{};

    final read = <ReportFigure>[];
    for (final spec in figures) {
      final match = _pick(source, spec.candidates, consumed);
      read.add(
        ReportFigure(
          key: spec.key,
          label: spec.label,
          value: _numeric(match?.value),
          text: match?.value is String && _numeric(match?.value) == null
              ? (match!.value as String).trim()
              : null,
          format: spec.format,
        ),
      );
    }

    final charts = <ChartSeries>[];
    for (final spec in series) {
      final match = _pick(source, spec.candidates, consumed);
      final points = match == null ? const <ChartPoint>[] : _points(match.value);
      charts.add(
        ChartSeries(
          key: spec.key,
          label: spec.label,
          points: points,
          valueLabel: spec.valueLabel,
          format: spec.format,
        ),
      );
    }

    return ReportSection(
      figures: read,
      extras: _extras(source, consumed),
      charts: charts,
      raw: source,
    );
  }

  /// A standalone chart route (`/reports/charts/*`).
  static ChartSeries chart(
    Object? body, {
    required String key,
    required String label,
    String? valueLabel,
    ReportFormat format = ReportFormat.count,
    String? secondaryLabel,
    ReportFormat secondaryFormat = ReportFormat.count,
    /// Read first when a point carries more than one figure. The captured
    /// booking-trends payload sends `{date, bookings, revenue}`, so which of
    /// the two a chart means is the caller's to say, not the reader's to guess.
    List<String> valueKeys = const [],
    List<String> candidates = const [
      'data',
      'points',
      'series',
      'items',
      'results',
      'chart',
      'values',
    ],
  }) {
    final direct = _points(body, preferred: valueKeys);
    if (direct.isNotEmpty) {
      return ChartSeries(
        key: key,
        label: label,
        points: direct,
        valueLabel: valueLabel,
        format: format,
        secondaryLabel: secondaryLabel,
        secondaryFormat: secondaryFormat,
      );
    }

    final source = _unwrap(body);
    for (final candidate in candidates) {
      final value = source[candidate];
      final points = _points(value, preferred: valueKeys);
      if (points.isNotEmpty) {
        return ChartSeries(
          key: key,
          label: label,
          points: points,
          valueLabel: valueLabel,
          format: format,
          secondaryLabel: secondaryLabel,
          secondaryFormat: secondaryFormat,
        );
      }
    }

    return ChartSeries(
      key: key,
      label: label,
      valueLabel: valueLabel,
      format: format,
      secondaryLabel: secondaryLabel,
      secondaryFormat: secondaryFormat,
    );
  }

  /// Reads a series from a list of objects, a list of numbers, or a map of
  /// label → number. Anything else yields no points rather than a guess.
  static List<ChartPoint> _points(
    Object? value, {
    List<String> preferred = const [],
  }) {
    const labelKeys = [
      'label',
      'name',
      'date',
      'day',
      'month',
      'hour',
      'time',
      'court',
      'courtName',
      'sport',
      'status',
      'key',
      '_id',
      'category',
    ];
    const valueKeys = [
      'value',
      'count',
      'total',
      'bookings',
      'revenue',
      'amount',
      'y',
      'sum',
    ];
    const secondaryKeys = ['revenue', 'amount', 'secondary', 'total'];

    if (value is List) {
      final points = <ChartPoint>[];

      for (var index = 0; index < value.length; index++) {
        final entry = value[index];

        if (entry is num) {
          points.add(ChartPoint(label: '${index + 1}', value: entry));
          continue;
        }
        if (entry is! Map) continue;

        final row = Map<String, dynamic>.from(entry);
        final label = JsonReader.string(row, labelKeys) ?? '${index + 1}';

        String? primaryKey;
        num? primary;
        for (final key in [...preferred, ...valueKeys]) {
          final candidate = _numeric(row[key]);
          if (candidate != null) {
            primaryKey = key;
            primary = candidate;
            break;
          }
        }
        if (primary == null) continue;

        num? secondary;
        for (final key in [...secondaryKeys, ...valueKeys]) {
          if (key == primaryKey) continue;
          final candidate = _numeric(row[key]);
          if (candidate != null) {
            secondary = candidate;
            break;
          }
        }

        points.add(
          ChartPoint(label: label, value: primary, secondary: secondary),
        );
      }
      return points;
    }

    if (value is Map) {
      final points = <ChartPoint>[];
      value.forEach((key, entry) {
        final number = _numeric(entry);
        if (number != null) {
          points.add(ChartPoint(label: key.toString(), value: number));
        }
      });
      return points;
    }

    return const [];
  }

  /// Numbers the endpoint sent that no spec claimed.
  static List<ReportFigure> _extras(
    Map<String, dynamic> source,
    Set<String> consumed,
  ) {
    final extras = <ReportFigure>[];

    source.forEach((key, value) {
      if (consumed.contains(key)) return;
      if (_ignoredKeys.contains(key.toLowerCase())) return;

      final number = _numeric(value);
      if (number == null) return;

      extras.add(
        ReportFigure(
          key: key,
          label: humanise(key),
          value: number,
          format: _formatFor(key),
        ),
      );
    });

    return extras;
  }

  /// `totalRevenue` → `Total revenue`, `peak_hours` → `Peak hours`.
  static String humanise(String key) {
    final spaced = key
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (match) => '${match[1]} ${match[2]}',
        )
        .replaceAll(RegExp(r'[_\-]+'), ' ')
        .trim();
    if (spaced.isEmpty) return key;
    return spaced[0].toUpperCase() + spaced.substring(1).toLowerCase();
  }

  /// Guessed from the name, and only for figures the module never documented —
  /// a wrong guess here mislabels an extra, never a headline number.
  static ReportFormat _formatFor(String key) {
    final lower = key.toLowerCase();
    if (lower.contains('revenue') ||
        lower.contains('amount') ||
        lower.contains('earning') ||
        lower.contains('income')) {
      return ReportFormat.currency;
    }
    if (lower.contains('rate') ||
        lower.contains('percent') ||
        lower.contains('occupancy') ||
        lower.contains('utilization') ||
        lower.contains('utilisation') ||
        lower.contains('growth')) {
      return ReportFormat.percent;
    }
    if (lower.contains('hours') || lower.contains('minutes')) {
      return ReportFormat.minutes;
    }
    return ReportFormat.count;
  }

  static ({String key, Object? value})? _pick(
    Map<String, dynamic> source,
    List<String> candidates,
    Set<String> consumed,
  ) {
    for (final candidate in candidates) {
      if (source.containsKey(candidate) && source[candidate] != null) {
        consumed.add(candidate);
        return (key: candidate, value: source[candidate]);
      }
    }
    return null;
  }

  /// The object the figures live in, whichever envelope the route used.
  static Map<String, dynamic> _unwrap(Object? body) {
    if (body is! Map) return const {};
    var source = Map<String, dynamic>.from(body);

    for (final key in const ['data', 'result', 'report', 'analytics']) {
      final inner = source[key];
      if (inner is Map) {
        source = Map<String, dynamic>.from(inner);
        break;
      }
    }

    // Some backends nest one level further, e.g. `{data: {summary: {...}}}`.
    // Only followed when the outer object carries nothing else worth reading.
    for (final key in const ['summary', 'stats', 'overview', 'totals']) {
      final inner = source[key];
      if (inner is Map && source.length == 1) {
        return Map<String, dynamic>.from(inner);
      }
    }

    return source;
  }

  // ---------------------------------------------------------------------------
  // Filter options
  // ---------------------------------------------------------------------------

  /// A `/filter-options` payload.
  ///
  /// Every list-valued key becomes a group; each entry may be a plain string, a
  /// number, or an object with an id and a label under any of the usual names.
  static ReportFilterOptions filterOptions(Object? body) {
    final source = _unwrap(body);
    if (source.isEmpty) return const ReportFilterOptions();

    final groups = <String, List<FilterOption>>{};

    source.forEach((key, value) {
      final options = _options(value);
      if (options.isNotEmpty) groups[key] = options;
    });

    return ReportFilterOptions(groups: groups);
  }

  static List<FilterOption> _options(Object? value) {
    if (value is! List) return const [];

    const idKeys = ['id', '_id', 'value', 'key', 'code', 'slug'];
    const labelKeys = ['label', 'name', 'title', 'text', 'displayName'];

    final options = <FilterOption>[];

    for (final entry in value) {
      if (entry == null) continue;

      if (entry is String) {
        final text = entry.trim();
        if (text.isNotEmpty) options.add(FilterOption(id: text, label: text));
        continue;
      }
      if (entry is num) {
        options.add(FilterOption(id: '$entry', label: '$entry'));
        continue;
      }
      if (entry is! Map) continue;

      final row = Map<String, dynamic>.from(entry);
      final id = JsonReader.string(row, idKeys);
      final label = JsonReader.string(row, labelKeys) ?? id;
      if (id == null || label == null) continue;

      options.add(FilterOption(id: id, label: label));
    }

    return options;
  }

  // ---------------------------------------------------------------------------
  // Tabular reports
  // ---------------------------------------------------------------------------

  static const List<String> _listKeys = [
    'data',
    'items',
    'results',
    'records',
    'rows',
    'bookings',
    'students',
    'coaches',
    'list',
  ];

  static List<Map<String, dynamic>> rowsIn(Object? body) =>
      JsonReader.records(body, keys: _listKeys);

  /// `{success, message, data: [], total, page, limit}` — the documented
  /// paginated envelope, with the counters beside the rows.
  static Paged<T> page<T>(
    Object? body, {
    required T Function(Map<String, dynamic>) map,
    required bool Function(T) keep,
    required int requestedPage,
    required int requestedLimit,
  }) {
    final items = rowsIn(body).map(map).where(keep).toList(growable: false);
    final counters = _counters(body);

    int? read(List<String> keys) =>
        counters == null ? null : JsonReader.integer(counters, keys);

    final page = read(const ['page', 'currentPage', 'current_page']) ??
        requestedPage;
    final limit =
        read(const ['limit', 'perPage', 'per_page', 'itemsPerPage']) ??
        requestedLimit;
    final total =
        read(const ['total', 'totalItems', 'total_items', 'count']) ??
        items.length;

    return Paged<T>(
      items: items,
      page: page < 1 ? 1 : page,
      limit: limit < 1 ? requestedLimit : limit,
      total: total,
      // Left at 0 when the route did not say: `effectiveTotalPages` derives it
      // from the total, and deriving beats guessing 1.
      totalPages: read(const ['totalPages', 'total_pages', 'pages']) ?? 0,
    );
  }

  static Map<String, dynamic>? _counters(Object? body) {
    if (body is! Map) return null;
    final map = Map<String, dynamic>.from(body);

    for (final key in const ['pagination', 'meta', 'pageInfo']) {
      final value = map[key];
      if (value is Map) return Map<String, dynamic>.from(value);
    }
    if (map.containsKey('total') ||
        map.containsKey('page') ||
        map.containsKey('totalPages')) {
      return map;
    }
    final data = map['data'];
    if (data is Map) return _counters(data);
    return null;
  }

  static BookingReportRow bookingRow(Map<String, dynamic> json) {
    final user = _nested(json, const ['user', 'User', 'customer']);
    final court = _nested(json, const ['court', 'Court']);
    final sport = _nested(json, const ['sport', 'Sport']);

    return BookingReportRow(
      // Top level only: a booking row embeds the customer as `user`, and
      // inheriting `user.id` would name the wrong record in the export.
      id:
          JsonReader.ownString(json, const ['id', '_id', 'bookingId']) ??
          JsonReader.ownString(json, const [
            'bookingReference',
            'reference',
          ]) ??
          '',
      reference: JsonReader.string(json, const [
        'bookingReference',
        'booking_reference',
        'reference',
        'bookingId',
      ]),
      userName:
          JsonReader.string(json, const [
            'userName',
            'customerName',
            'name',
          ]) ??
          (user == null
              ? null
              : JsonReader.string(user, const ['name', 'fullName'])),
      userContact:
          JsonReader.string(json, const [
            'userPhone',
            'phone',
            'phoneNumber',
            'email',
          ]) ??
          (user == null
              ? null
              : JsonReader.string(user, const [
                  'phone_number',
                  'phoneNumber',
                  'phone',
                  'email',
                ])),
      sportName:
          JsonReader.string(json, const ['sportName', 'sport_name']) ??
          (sport == null
              ? null
              : JsonReader.string(sport, const ['name', 'title'])),
      courtName:
          JsonReader.string(json, const ['courtName', 'court_name']) ??
          (court == null
              ? null
              : JsonReader.string(court, const ['name', 'courtName'])),
      date: JsonReader.date(json, const [
        'date',
        'bookingDate',
        'booking_date',
      ]),
      slotLabel: _slotLabel(json),
      amount: CourtMapper.number(
        JsonReader.pick(json, const [
          'amount',
          'totalAmount',
          'total_amount',
          'price',
        ]),
      ),
      statusRaw: JsonReader.string(json, const [
        'bookingStatus',
        'booking_status',
        'status',
      ]),
      paymentStatusRaw: JsonReader.string(json, const [
        'paymentStatus',
        'payment_status',
      ]),
      raw: json,
    );
  }

  static String? _slotLabel(Map<String, dynamic> json) {
    final direct = JsonReader.string(json, const [
      'slot',
      'slotLabel',
      'timeSlot',
      'time_slot',
    ]);
    if (direct != null) return direct;

    final start = JsonReader.string(json, const ['startTime', 'start_time']);
    final end = JsonReader.string(json, const ['endTime', 'end_time']);
    if (start == null && end == null) return null;
    return '${_time(start)} – ${_time(end)}';
  }

  /// `07:00:00` → `07:00`; anything unparseable is left as it came.
  static String _time(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return '—';
    final parts = text.split(':');
    if (parts.length >= 2) return '${parts[0]}:${parts[1]}';
    return text;
  }

  static StudentReportRow studentRow(Map<String, dynamic> json) {
    final user = _nested(json, const ['user', 'User', 'student', 'Student']);
    final coach = _nested(json, const ['coach', 'Coach']);
    final batch = _nested(json, const ['batch', 'Batch']);
    final sport = _nested(json, const ['sport', 'Sport']);

    return StudentReportRow(
      id:
          JsonReader.ownString(json, const [
            'id',
            '_id',
            'studentId',
            'student_id',
          ]) ??
          '',
      name:
          JsonReader.string(json, const [
            'studentName',
            'name',
            'fullName',
          ]) ??
          (user == null
              ? null
              : JsonReader.string(user, const ['name', 'fullName'])),
      contact:
          JsonReader.string(json, const ['phone', 'phoneNumber', 'email']) ??
          (user == null
              ? null
              : JsonReader.string(user, const [
                  'phone_number',
                  'phoneNumber',
                  'email',
                ])),
      sportName:
          JsonReader.string(json, const ['sportName', 'sport_name']) ??
          (sport == null
              ? null
              : JsonReader.string(sport, const ['name', 'title'])),
      coachName:
          JsonReader.string(json, const ['coachName', 'coach_name']) ??
          (coach == null
              ? null
              : JsonReader.string(coach, const ['name', 'fullName'])),
      batchName:
          JsonReader.string(json, const ['batchName', 'batch_name']) ??
          (batch == null
              ? null
              : JsonReader.string(batch, const ['name', 'batchName'])),
      membership: JsonReader.string(json, const [
        'membership',
        'membershipType',
        'membership_type',
        'planName',
      ]),
      joinedAt: JsonReader.date(json, const [
        'joiningDate',
        'joining_date',
        'joinedAt',
        'joined_at',
        'enrollmentDate',
        'createdAt',
      ]),
      statusRaw: JsonReader.string(json, const ['status', 'studentStatus']),
      raw: json,
    );
  }

  static CoachReportRow coachRow(Map<String, dynamic> json) {
    final user = _nested(json, const ['user', 'User', 'coach', 'Coach']);
    final sport = _nested(json, const ['sport', 'Sport']);
    final complex = _nested(json, const [
      'sportComplex',
      'SportComplex',
      'complex',
    ]);

    return CoachReportRow(
      id:
          JsonReader.ownString(json, const [
            'id',
            '_id',
            'coachId',
            'coach_id',
          ]) ??
          '',
      name:
          JsonReader.string(json, const [
            'coachName',
            'name',
            'fullName',
          ]) ??
          (user == null
              ? null
              : JsonReader.string(user, const ['name', 'fullName'])),
      sportName:
          JsonReader.string(json, const ['sportName', 'sport_name']) ??
          (sport == null
              ? null
              : JsonReader.string(sport, const ['name', 'title'])),
      complexName:
          JsonReader.string(json, const [
            'complexName',
            'sportComplexName',
          ]) ??
          (complex == null
              ? null
              : JsonReader.string(complex, const ['name', 'title'])),
      studentCount: JsonReader.integer(json, const [
        'students',
        'studentCount',
        'student_count',
        'totalStudents',
      ]),
      revenue: CourtMapper.number(
        JsonReader.pick(json, const [
          'revenue',
          'totalRevenue',
          'total_revenue',
          'earnings',
        ]),
      ),
      programCount: JsonReader.integer(json, const [
        'programs',
        'programCount',
        'program_count',
        'totalPrograms',
        'batches',
      ]),
      statusRaw: JsonReader.string(json, const ['status', 'coachStatus']),
      raw: json,
    );
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
}
