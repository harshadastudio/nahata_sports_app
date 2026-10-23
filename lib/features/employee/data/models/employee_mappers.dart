import '../../domain/entities/employee_attendance.dart';
import '../../domain/entities/employee_booking.dart';
import '../../domain/entities/employee_coach.dart';
import '../../domain/entities/employee_contact_enquiry.dart';
import '../../domain/entities/employee_coupon.dart';
import '../../domain/entities/employee_enquiry.dart';
import '../../domain/entities/employee_event.dart';
import '../../domain/entities/employee_event_booking.dart';
import '../../domain/entities/employee_fee.dart';
import '../../domain/entities/employee_master.dart';
import '../../domain/entities/employee_notification.dart';
import '../../domain/entities/employee_overview.dart';
import '../../domain/entities/employee_paged.dart';
import '../../domain/entities/employee_payment.dart';
import '../../domain/entities/employee_staff_details.dart';
import '../../domain/entities/employee_student.dart';
import '../../domain/entities/employee_user.dart';
import '../../domain/entities/employee_visitor_pass.dart';

/// JSON → entity for the employee dashboard.
///
/// The employee screens read from five different controllers and **none of them
/// agree on an envelope**. Rather than teach every page which shape its route
/// uses, the readers here accept all of them:
///
/// | route                | rows at                        | totals at                     |
/// |----------------------|--------------------------------|-------------------------------|
/// | `/bookings`          | `bookings` or `data`           | top level `total/totalPages`  |
/// | `/attendance`        | `data.attendance` or top level | either                        |
/// | `/coaches`           | `data.coaches` or `coaches`    | `data.totalItems` or `total`  |
/// | `/payments/all`      | `data`                         | `pagination.totalCount`       |
/// | `/admin/users`       | `data`                         | `pagination.totalItems`       |
/// | `/notifications`     | `data`                         | `pagination.totalItems`       |
/// | `/coaching-enquiries`| `data.enquiries`               | `data.total`                  |
/// | `/fees`              | `data.fees` or `data`          | `data.total` or `total`       |
///
/// Every reader tolerates a null, a wrong type and a missing key: these screens
/// are read-mostly and one odd row must never take a page down. Rows with no
/// usable id are dropped rather than shown as `#0`, and the repository logs when
/// that happens.
class EmployeeMappers {
  const EmployeeMappers._();

  // ───────────────────────────────────────────────────────────────────────────
  // Envelopes
  // ───────────────────────────────────────────────────────────────────────────

  /// The `data` object of a `{success, data: {...}}` body, or the body itself
  /// when the server did not wrap it.
  static Map<String, dynamic> envelope(Object? body) {
    if (body is! Map) return const {};
    final inner = body['data'];
    if (inner is Map) return Map<String, dynamic>.from(inner);
    return Map<String, dynamic>.from(body);
  }

  /// The row array of a `{success, data: [...]}` body.
  static List<Map<String, dynamic>> rows(Object? body) {
    if (body is List) return _objects(body);
    if (body is Map) {
      final inner = body['data'];
      if (inner is List) return _objects(inner);
    }
    return const [];
  }

  /// Rows under [key], looked for **both** at the top level and inside `data`.
  ///
  /// This is the one reader that copes with the whole table above: `/bookings`
  /// puts its array at `bookings`, `/attendance` at `data.attendance`, and both
  /// spellings appear in the wild for the same route depending on which service
  /// answered.
  static List<Map<String, dynamic>> rowsAt(Object? body, String key) {
    if (body is! Map) return const [];

    final direct = body[key];
    if (direct is List) return _objects(direct);

    final inner = body['data'];
    if (inner is Map) {
      final nested = inner[key];
      if (nested is List) return _objects(nested);
    }
    if (inner is List) return _objects(inner);

    return const [];
  }

  /// Builds a page from whichever pagination envelope the route used.
  ///
  /// [fallbackPage] and [fallbackLimit] are what was *asked for*: several of
  /// these routes echo neither, and a missing `page` must not reset the pager
  /// to 1 while the user is on page 4.
  static EmployeePaged<T> pageOf<T>(
    Object? body, {
    required String key,
    required T? Function(Map<String, dynamic>) parse,
    required int fallbackPage,
    required int fallbackLimit,
  }) {
    final items =
        rowsAt(body, key).map(parse).whereType<T>().toList(growable: false);

    final top = body is Map ? Map<String, dynamic>.from(body) : const {};
    final data = envelope(body);
    final pagination = _mapAt(top['pagination']) ?? _mapAt(data['pagination']);

    // Read in precedence order: the dedicated pagination block, then the data
    // envelope, then the top level. `totalItems` and `totalCount` are the two
    // spellings the pagination block uses for the same number.
    final page = _firstInt([
      pagination?['currentPage'],
      pagination?['page'],
      data['page'],
      data['currentPage'],
      top['page'],
      top['currentPage'],
    ]);
    final limit = _firstInt([
      pagination?['limit'],
      pagination?['itemsPerPage'],
      // `/visitor-passes` spells it this third way.
      pagination?['pageSize'],
      data['limit'],
      top['limit'],
    ]);
    final total = _firstInt([
      pagination?['totalCount'],
      pagination?['totalItems'],
      pagination?['total'],
      data['totalItems'],
      data['total'],
      top['total'],
    ]);
    final totalPages = _firstInt([
      pagination?['totalPages'],
      data['totalPages'],
      top['totalPages'],
    ]);

    return EmployeePaged<T>(
      items: items,
      page: page > 0 ? page : fallbackPage,
      limit: limit > 0 ? limit : fallbackLimit,
      // A route that reports no total still has at least the rows in hand —
      // otherwise the pager would claim "0 records" over a full page.
      total: total > 0 ? total : items.length,
      totalPages: totalPages,
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Overview
  // ───────────────────────────────────────────────────────────────────────────

  static EmployeeStats stats(Object? body) {
    final json = envelope(body);
    return EmployeeStats(
      todayBookings: _int(json['todayBookings']),
      upcomingBookings: _int(json['upcomingBookings']),
      totalBookings: _int(json['totalBookings']),
      totalRevenue: _num(json['totalRevenue']),
      totalStudents: _int(json['totalStudents']),
      activeEnrollments: _int(json['activeEnrollments']),
      totalCoaches: _int(json['totalCoaches']),
      totalCourts: _int(json['totalCourts']),
      // The backend flags a trend with no baseline separately; showing
      // "+100% vs nothing" would be a lie, so those come through as null.
      revenueTrend: _bool(json['revenueTrendIsNew'])
          ? null
          : _doubleOrNull(json['revenueChange']),
      bookingsTrend: _bool(json['bookingsTrendIsNew'])
          ? null
          : _doubleOrNull(json['bookingsTrend']),
    );
  }

  /// `{role, sections: [{title, fields: [{label, value}]}]}`.
  ///
  /// The backend already drops fields whose value is blank, but a field is
  /// dropped again here if it arrives empty anyway — a row with a label and
  /// nothing beside it reads as a loading bug.
  static EmployeeStaffDetails staffDetails(Object? body) {
    final json = envelope(body);

    final sections = _objectsAt(json['sections'])
        .map((row) {
          final title = _string(row['title']);
          if (title == null) return null;

          final fields = _objectsAt(row['fields'])
              .map((field) {
                final label = _string(field['label']);
                final value = _string(field['value']);
                if (label == null || value == null) return null;
                return EmployeeStaffField(label: label, value: value);
              })
              .whereType<EmployeeStaffField>()
              .toList(growable: false);

          if (fields.isEmpty) return null;
          return EmployeeStaffSection(title: title, fields: fields);
        })
        .whereType<EmployeeStaffSection>()
        .toList(growable: false);

    return EmployeeStaffDetails(
      role: _string(json['role']) ?? '',
      sections: sections,
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Bookings
  // ───────────────────────────────────────────────────────────────────────────

  static EmployeeBooking? booking(Map<String, dynamic> json) {
    final id = _int(json['id']);
    if (id <= 0) return null;

    final user = _mapAt(json['user']) ?? const {};
    final sport = _mapAt(json['sport']) ?? const {};
    final court = _mapAt(json['court']) ?? const {};
    // The complex hangs off the court with a capitalised association name.
    final complex =
        _mapAt(court['SportComplex']) ?? _mapAt(court['sportComplex']) ?? const {};

    return EmployeeBooking(
      id: id,
      customerName: _string(json['customerName']),
      userName: _string(user['name']) ?? '',
      userEmail: _string(user['email']) ?? '',
      userPhone: _string(user['phone_number']) ?? _string(user['phone']) ?? '',
      sportId: _intOrNull(json['sportId']) ?? _intOrNull(sport['id']),
      sportName: _string(sport['name']) ?? '',
      courtId: _intOrNull(json['courtId']) ?? _intOrNull(court['id']),
      courtName: _string(court['name']) ?? '',
      venueName: _string(complex['name']) ?? '',
      date: _date(json['date']),
      startTime: _string(json['startTime']),
      endTime: _string(json['endTime']),
      source: _string(json['bookingSource']) ?? '',
      paymentStatus: _string(json['paymentStatus']) ?? '',
      bookingStatus: _string(json['bookingStatus']) ?? '',
      totalAmount: _num(json['totalAmount']),
      transactionId: _string(json['transactionId']),
      passCode: _string(json['passCode']),
      qrCode: _string(json['qrCode']),
      maxPersons: _intOrNull(json['maxPersons']),
      notes: _string(json['notes']),
      movedFromCourtId: _intOrNull(json['movedFromCourtId']),
      moveReason: _string(json['moveReason']),
      createdAt: _date(json['createdAt']),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Payments
  // ───────────────────────────────────────────────────────────────────────────

  static EmployeePayment? payment(Map<String, dynamic> json) {
    // The id is a composite string (`FEE_31`), never a number — so this is the
    // one row type where an empty id, not a zero id, means "unusable".
    final id = _string(json['id']);
    if (id == null) return null;

    return EmployeePayment(
      id: id,
      sourceId: _intOrNull(json['sourceId']),
      type: _string(json['type']) ?? '',
      typeLabel: _string(json['typeLabel']) ?? '',
      transactionId: _string(json['transactionId']),
      razorpayPaymentId: _string(json['razorpayPaymentId']),
      razorpayOrderId: _string(json['razorpayOrderId']),
      userName: _string(json['userName']) ?? '',
      userEmail: _string(json['userEmail']) ?? '',
      userPhone: _string(json['userPhone']) ?? '',
      amount: _num(json['amount']),
      paymentMode: _string(json['paymentMode']) ?? '',
      status: _string(json['status']) ?? '',
      description: _string(json['description']) ?? '',
      venue: _string(json['venue']) ?? '',
      createdAt: _date(json['createdAt']),
      date: _string(json['date']),
    );
  }

  /// The whole `/payments/all` response — rows, stats and pagination together,
  /// because the stats describe the filtered set the rows came from and would
  /// go stale if fetched separately.
  static EmployeePaymentsPage paymentsPage(
    Object? body, {
    required int fallbackPage,
    required int fallbackLimit,
  }) {
    final top = body is Map ? Map<String, dynamic>.from(body) : const {};
    final statsJson = _mapAt(top['stats']) ?? const {};
    final pagination = _mapAt(top['pagination']) ?? const {};

    final items =
        rows(body).map(payment).whereType<EmployeePayment>().toList(growable: false);

    final page = _int(pagination['currentPage']);
    final limit = _int(pagination['limit']);
    final total = _int(pagination['totalCount']);

    return EmployeePaymentsPage(
      payments: items,
      stats: EmployeePaymentStats(
        totalRevenue: _num(statsJson['totalRevenue']),
        successCount: _int(statsJson['successCount']),
        pendingCount: _int(statsJson['pendingCount']),
        failedCount: _int(statsJson['failedCount']),
        totalCount: _int(statsJson['totalCount']),
      ),
      page: page > 0 ? page : fallbackPage,
      limit: limit > 0 ? limit : fallbackLimit,
      total: total > 0 ? total : items.length,
      totalPages: _int(pagination['totalPages']),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Attendance
  // ───────────────────────────────────────────────────────────────────────────

  static EmployeeAttendanceRecord? attendance(Map<String, dynamic> json) {
    final id = _int(json['id']);
    if (id <= 0) return null;

    // The student's name sits three levels deep on the nested shape
    // (`student.User.name`) and flat on the legacy one.
    final student = _mapAt(json['student']) ?? const {};
    final studentUser = _mapAt(student['User']) ?? _mapAt(student['user']) ?? const {};
    final user = _mapAt(json['user']) ?? const {};
    final marker = _mapAt(json['marker']) ?? const {};
    final batch = _mapAt(json['batch']) ?? const {};
    final batchSport = _mapAt(batch['sport']) ?? const {};
    final sport = _mapAt(json['sport']) ?? const {};

    return EmployeeAttendanceRecord(
      id: id,
      studentName: _string(studentUser['name']) ??
          _string(student['name']) ??
          _string(user['name']) ??
          _string(json['studentName']) ??
          '',
      studentEmail:
          _string(studentUser['email']) ?? _string(user['email']) ?? '',
      batchName: _string(batch['name']) ?? _string(json['batchName']) ?? '',
      sportName: _string(batchSport['name']) ?? _string(sport['name']) ?? '',
      date: _date(json['date']),
      status: _string(json['status']) ?? '',
      markedBy: _string(marker['name']) ?? _string(json['markedBy']) ?? '',
      markedByRole: _string(marker['role']) ?? '',
      notes: _string(json['notes']),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Coaches
  // ───────────────────────────────────────────────────────────────────────────

  static EmployeeCoach? coach(Map<String, dynamic> json) {
    final id = _int(json['id']);
    if (id <= 0) return null;

    final user = _mapAt(json['user']) ?? const {};

    // `status` is a word on some rows and a boolean `isActive` on others.
    final status = _string(json['status']) ??
        (json.containsKey('isActive')
            ? (_bool(json['isActive']) ? 'Active' : 'Inactive')
            : 'Active');

    return EmployeeCoach(
      id: id,
      name: _string(user['name']) ?? _string(json['name']) ?? '',
      email: _string(user['email']) ?? _string(json['email']) ?? '',
      phone: _string(user['phone_number']) ??
          _string(json['phone']) ??
          _string(json['phone_number']) ??
          '',
      status: status,
      bio: _string(json['bio']),
      experience: _string(json['experience']),
      sports: _names(json['sports']),
      joinedAt: _date(json['createdAt']),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Coaching enquiries
  // ───────────────────────────────────────────────────────────────────────────

  static EmployeeEnquiry? enquiry(Map<String, dynamic> json) {
    final id = _int(json['id']);
    if (id <= 0) return null;

    final user = _mapAt(json['user']) ?? const {};
    final batch = _mapAt(json['batch']) ?? const {};
    final sport = _mapAt(json['sport']) ?? const {};
    final coachMap = _mapAt(json['coach']) ?? const {};

    return EmployeeEnquiry(
      id: id,
      // The signed-in account wins over the free-text form fields: an enquiry
      // filed while logged in carries both, and the account is authoritative.
      name: _string(user['name']) ?? _string(json['name']) ?? '',
      email: _string(user['email']) ?? _string(json['email']) ?? '',
      phone: _string(user['phone_number']) ?? _string(json['phone']) ?? '',
      batchId: _intOrNull(batch['id']) ?? _intOrNull(json['batchId']),
      batchName: _string(batch['name']) ?? '',
      batchFees: _numOrNull(batch['fees']),
      batchMaxStudents: _intOrNull(batch['maxStudents']),
      batchCurrentStudents: _intOrNull(batch['currentStudents']),
      sportId: _intOrNull(sport['id']) ?? _intOrNull(json['sportId']),
      sportName: _string(sport['name']) ?? '',
      coachId: _intOrNull(coachMap['id']) ?? _intOrNull(json['coachId']),
      coachName: _string(coachMap['name']) ?? '',
      isAllSports: _bool(json['isAllSports']),
      status: _string(json['status']) ?? 'Pending',
      message: _string(json['message']),
      referenceNumber: _string(json['referenceNumber']),
      // Both spellings are read: the API documents `enrolments`, and the
      // double-l form appears wherever the payload was built from the
      // `Enrollment` model's own name.
      enrolments: _objectsAt(json['enrolments'] ?? json['enrollments'])
          .map(enquiryEnrolment)
          .whereType<EmployeeEnquiryEnrolment>()
          .toList(growable: false),
      createdAt: _date(json['createdAt']),
      updatedAt: _date(json['updatedAt']),
    );
  }

  /// One row of an enquiry's `enrolments[]`.
  ///
  /// The names arrive flattened (`sportName`, `coachName`, `batchName`), but a
  /// payload that nested the associations instead is read too — the same route
  /// answers both ways depending on the include.
  static EmployeeEnquiryEnrolment? enquiryEnrolment(Map<String, dynamic> json) {
    final batch = _mapAt(json['batch']) ?? const {};
    final sport = _mapAt(json['sport']) ?? const {};
    final coachMap = _mapAt(json['coach']) ?? const {};

    final batchName = _string(json['batchName']) ?? _string(batch['name']);
    final sportName = _string(json['sportName']) ?? _string(sport['name']);
    final coachName = _string(json['coachName']) ?? _string(coachMap['name']);

    // A row that names nothing is noise, not an enrolment.
    if (batchName == null && sportName == null && coachName == null) {
      return null;
    }

    return EmployeeEnquiryEnrolment(
      id: _intOrNull(json['id']),
      batchName: batchName ?? '',
      sportName: sportName ?? '',
      coachName: coachName ?? '',
      status: _string(json['status']) ?? '',
    );
  }

  /// The answer to `POST /coaching-enquiries/admin/create`.
  ///
  /// `studentAccount` is the part that matters: it says whether the route had
  /// to create the login it just emailed. A response without the block is not a
  /// failure — the enquiry was still created — so every field is optional.
  static EmployeeEnquiryCreateResult enquiryCreateResult(Object? body) {
    final data = envelope(body);
    final enquiry = _mapAt(data['enquiry']) ?? data;
    final account = _mapAt(data['studentAccount']) ??
        _mapAt(enquiry['studentAccount']) ??
        const {};

    return EmployeeEnquiryCreateResult(
      enquiryId: _intOrNull(enquiry['id']) ?? _intOrNull(data['id']),
      userId: _intOrNull(account['userId']),
      studentId: _intOrNull(account['studentId']),
      isNewAccount: _bool(account['isNewAccount']),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Fees
  // ───────────────────────────────────────────────────────────────────────────

  static EmployeeFee? fee(Map<String, dynamic> json) {
    final id = _int(json['id']);
    if (id <= 0) return null;

    final student = _mapAt(json['student']) ?? const {};
    final studentUser = _mapAt(student['User']) ?? _mapAt(student['user']) ?? const {};
    final batch = _mapAt(json['batch']) ?? const {};
    final batchSport = _mapAt(batch['sport']) ?? const {};

    return EmployeeFee(
      id: id,
      studentId: _int(json['studentId']),
      batchId: _int(json['batchId']),
      studentName: _string(studentUser['name']) ?? '',
      studentPhone: _string(studentUser['phone_number']) ?? '',
      studentEmail: _string(studentUser['email']) ?? '',
      batchName: _string(batch['name']) ?? '',
      sportName: _string(batchSport['name']) ?? '',
      batchFees: _numOrNull(batch['fees']),
      amountPaid: _num(json['amountPaid']),
      paymentStatus: _string(json['paymentStatus']) ?? 'Pending',
      approvalStatus: _string(json['approvalStatus']) ?? 'Pending',
      paymentMode: _string(json['paymentMode']),
      enrollmentDate: _date(json['enrollmentDate']),
      notes: _string(json['notes']),
    );
  }

  static EmployeeFeeStats feeStats(Object? body) {
    final json = envelope(body);
    return EmployeeFeeStats(
      total: _int(json['total']),
      paid: _int(json['paid']),
      unpaid: _int(json['unpaid']),
      pendingApproval: _int(json['pendingApproval']),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Users
  // ───────────────────────────────────────────────────────────────────────────

  static EmployeeUser? user(Map<String, dynamic> json) {
    // Ids arrive as numbers here and as strings elsewhere in the same module,
    // so this is kept as whatever came in — nothing does arithmetic on it.
    final id = json['id'];
    if (id == null) return null;

    return EmployeeUser(
      id: id,
      name: _string(json['name']) ?? '',
      email: _string(json['email']) ?? '',
      phoneNumber:
          _string(json['phoneNumber']) ?? _string(json['phone_number']) ?? '',
      role: _string(json['role']) ?? 'USER',
      status: _string(json['status']) ?? 'Active',
      membershipType:
          _string(json['membershipType']) ?? _string(json['membership_type']),
      totalBookings: _int(json['totalBookings']),
      joinDate: _string(json['joinDate']),
      lastActive: _string(json['lastActive']),
      avatar: _string(json['avatar']),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Notifications
  // ───────────────────────────────────────────────────────────────────────────

  static EmployeeNotification? notification(Map<String, dynamic> json) {
    final id = _int(json['id']);
    if (id <= 0) return null;

    return EmployeeNotification(
      id: id,
      title: _string(json['title']) ?? '',
      message: _string(json['message']) ?? '',
      type: _string(json['type']) ?? 'System',
      targetRole: _string(json['targetRole']),
      isRead: _bool(json['isRead']),
      actionUrl: _string(json['actionUrl']),
      sentAt: _date(json['sentAt']),
      createdAt: _date(json['createdAt']),
    );
  }

  /// `{coaches, students, userIds}` → the two pickers the compose sheet needs.
  ///
  /// A coach is addressable two ways and the ids are **not** interchangeable:
  /// `coachIds` wants the coach row's id, `userIds` wants their login's id. The
  /// coaches list keeps the former; the people list merges coaches (by their
  /// `userId`) with students and de-duplicates, which is exactly what the
  /// website's picker does.
  static EmployeeAudience audience(Object? body) {
    final json = envelope(body);

    final coachRows = _objectsAt(json['coaches']);
    final coaches = coachRows
        .map((row) {
          final id = _int(row['id']);
          if (id <= 0) return null;
          return EmployeeRecipient(
            id: id,
            name: _string(row['name']) ?? '',
            email: _string(row['email']),
          );
        })
        .whereType<EmployeeRecipient>()
        .toList(growable: false);

    final people = <int, EmployeeRecipient>{};

    // Coaches first so a coach who is also on the student list keeps their
    // coach name, then students.
    for (final row in coachRows) {
      final userId = _intOrNull(row['userId']);
      if (userId == null || userId <= 0) continue;
      people[userId] = EmployeeRecipient(
        id: userId,
        name: _string(row['name']) ?? '',
        email: _string(row['email']),
      );
    }
    for (final row in _objectsAt(json['students'])) {
      final id = _int(row['id']);
      if (id <= 0) continue;
      people[id] = EmployeeRecipient(
        id: id,
        name: _string(row['name']) ?? '',
        email: _string(row['email']),
      );
    }

    return EmployeeAudience(
      coaches: coaches,
      people: people.values.toList(growable: false),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Operations masters
  // ───────────────────────────────────────────────────────────────────────────

  static EmployeeSport? sport(Map<String, dynamic> json) {
    final id = _int(json['id']);
    if (id <= 0) return null;

    return EmployeeSport(
      id: id,
      name: _string(json['name']) ?? '',
      description: _string(json['description']),
      category: _string(json['category']),
      minAge: _intOrNull(json['minAge']),
      maxAge: _intOrNull(json['maxAge']),
      allowedMembers: _intOrNull(json['allowedMembers']),
      status: _string(json['status']) ?? 'Active',
    );
  }

  static EmployeeCourt? court(Map<String, dynamic> json) {
    final id = _int(json['id']);
    if (id <= 0) return null;

    // The sport association is capitalised on this route and lower-cased on
    // the booking one.
    final sportMap = _mapAt(json['Sport']) ?? _mapAt(json['sport']) ?? const {};

    return EmployeeCourt(
      id: id,
      name: _string(json['name']) ?? '',
      sportId: _intOrNull(json['sportId']) ?? _intOrNull(sportMap['id']),
      sportName: _string(sportMap['name']) ?? '',
      capacity: _intOrNull(json['capacity']),
      surfaceType: _string(json['surfaceType']),
      lightingAvailable: _bool(json['lightingAvailable']),
      hourlyRate: _num(json['hourlyRate']),
      status: _string(json['status']) ?? 'Active',
    );
  }

  static EmployeeSlot? slot(Map<String, dynamic> json) {
    final id = _int(json['id']);
    if (id <= 0) return null;

    return EmployeeSlot(
      id: id,
      courtId: _intOrNull(json['courtId']),
      startTime: _string(json['startTime']) ?? '',
      endTime: _string(json['endTime']) ?? '',
      slotType: _string(json['slotType']) ?? 'Regular',
      priceOverride: _numOrNull(json['priceOverride']),
      availableDays: _string(json['availableDays']),
      status: _string(json['status']) ?? 'Active',
    );
  }

  static EmployeeAvailableSlot? availableSlot(Map<String, dynamic> json) {
    final id = _int(json['id']);
    if (id <= 0) return null;

    return EmployeeAvailableSlot(
      id: id,
      startTime: _string(json['startTime']) ?? '',
      endTime: _string(json['endTime']) ?? '',
      slotType: _string(json['slotType']) ?? 'Regular',
      price: _num(json['price']),
      isBooked: _bool(json['isBooked']),
      isUserBooked: _bool(json['isUserBooked']),
      isBlocked: _bool(json['isBlocked']),
      blockedBy: _string(json['blockedBy']),
      blockId: _intOrNull(json['blockId']),
      blockNotes: _string(json['blockNotes']),
      blockBilled: _bool(json['blockBilled']),
      blockAmount: _num(json['blockAmount']),
    );
  }

  static EmployeeBatch? batch(Map<String, dynamic> json) {
    final id = _int(json['id']);
    if (id <= 0) return null;

    final sportMap = _mapAt(json['sport']) ?? _mapAt(json['Sport']) ?? const {};
    final coachMap = _mapAt(json['coach']) ?? _mapAt(json['Coach']) ?? const {};

    return EmployeeBatch(
      id: id,
      name: _string(json['name']) ?? '',
      sportId: _intOrNull(sportMap['id']) ?? _intOrNull(json['sportId']),
      sportName: _string(sportMap['name']) ?? '',
      coachId: _intOrNull(coachMap['id']) ?? _intOrNull(json['coachId']),
      coachName: _string(coachMap['name']) ?? '',
      schedule: _string(json['schedule']),
      days: _string(json['days']),
      startDate: _date(json['startDate']),
      endDate: _date(json['endDate']),
      maxStudents: _intOrNull(json['maxStudents']),
      currentStudents: _intOrNull(json['currentStudents']),
      fees: _num(json['fees']),
      status: _string(json['status']) ?? 'Active',
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Students
  // ───────────────────────────────────────────────────────────────────────────

  /// A `Student` row joined to the `User` behind it.
  ///
  /// The person's details are on the account, not on the student row, and the
  /// include arrives capitalised (`User`) or not (`user`) depending on which
  /// service answered — both spellings are read.
  static EmployeeStudent? student(Map<String, dynamic> json) {
    final id = _int(json['id']);
    if (id <= 0) return null;

    final user = _mapAt(json['User']) ?? _mapAt(json['user']) ?? const {};
    final batch = _mapAt(json['Batch']) ?? _mapAt(json['batch']) ?? const {};
    final sport = _mapAt(json['Sport']) ?? _mapAt(json['sport']) ?? const {};
    final coachMap = _mapAt(json['Coach']) ?? _mapAt(json['coach']) ?? const {};

    // The batch's own sport is the more reliable of the two: a student row
    // only carries `sportId` when it was enrolled directly.
    final batchSport = _mapAt(batch['Sport']) ?? _mapAt(batch['sport']);

    return EmployeeStudent(
      id: id,
      userId: _intOrNull(user['id']) ?? _intOrNull(json['userId']),
      name: _string(user['name']) ?? _string(json['name']) ?? '',
      email: _string(user['email']) ?? _string(json['email']) ?? '',
      phone: _string(user['phone_number']) ??
          _string(user['phoneNumber']) ??
          _string(json['phone_number']) ??
          '',
      gender: _string(user['gender']) ?? _string(json['gender']),
      bloodGroup:
          _string(user['blood_group']) ?? _string(json['blood_group']),
      avatar: _string(user['avatar']) ?? _string(json['avatar']),
      status: _string(user['status']) ?? _string(json['status']) ?? 'Active',
      dob: _date(user['dob']) ?? _date(json['dob']),
      batchId: _intOrNull(batch['id']) ?? _intOrNull(json['batchId']),
      batchName: _string(batch['name']) ?? '',
      sportName: _string(batchSport?['name']) ?? _string(sport['name']) ?? '',
      coachName: _string(coachMap['name']) ?? '',
      enrollmentDate:
          _date(json['enrollmentDate']) ?? _date(json['enrollment_date']),
      createdAt: _date(json['createdAt']),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Coupons
  // ───────────────────────────────────────────────────────────────────────────

  static EmployeeCoupon? coupon(Map<String, dynamic> json) {
    final id = _int(json['id']);
    if (id <= 0) return null;

    return EmployeeCoupon(
      id: id,
      code: _string(json['code']) ?? '',
      discountType: _string(json['discountType']) ?? 'Percentage',
      discountValue: _num(json['discountValue']),
      maxDiscount: _numOrNull(json['maxDiscount']),
      description: _string(json['description']),
      validFrom: _date(json['validFrom']),
      validUntil: _date(json['validUntil']),
      // Nullable on purpose: no limit and a limit of zero are different
      // things, and only the first means "unlimited".
      usageLimit: _intOrNull(json['usageLimit']),
      usedCount: _int(json['usedCount'] ?? json['usageCount']),
      status: _string(json['status']) ?? 'Active',
      appliesTo: _string(json['appliesTo']) ?? 'Court',
      platform: _string(json['platform']) ?? 'All',
      createdAt: _date(json['createdAt']),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Visitor passes
  // ───────────────────────────────────────────────────────────────────────────

  static EmployeeVisitorPass? visitorPass(Map<String, dynamic> json) {
    final id = _int(json['id']);
    if (id <= 0) return null;

    return EmployeeVisitorPass(
      id: id,
      passNumber:
          _string(json['passNumber']) ?? _string(json['passCode']) ?? '',
      visitorName: _string(json['visitorName']) ?? _string(json['name']) ?? '',
      phoneNumber: _string(json['phoneNumber']) ??
          _string(json['phone_number']) ??
          '',
      email: _string(json['email']),
      visitPurpose:
          _string(json['visitPurpose']) ?? _string(json['purpose']) ?? 'Visit',
      status: _string(json['status']) ?? 'Active',
      // The live route names these `qrUrl` (a rendered PNG) and `qrData` (the
      // payload behind it); the two camel spellings are older aliases.
      qrCode: _string(json['qrUrl']) ??
          _string(json['qrCode']) ??
          _string(json['qrCodeUrl']) ??
          _string(json['qrData']),
      validFrom: _date(json['validFrom']),
      validUntil: _date(json['validUntil']),
      checkInAt: _date(json['checkInTime']) ?? _date(json['checkInAt']),
      checkOutAt: _date(json['checkOutTime']) ?? _date(json['checkOutAt']),
      createdAt: _date(json['createdAt']),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Events
  // ───────────────────────────────────────────────────────────────────────────

  static EmployeeEvent? event(Map<String, dynamic> json) {
    final id = _int(json['id']);
    if (id <= 0) return null;

    return EmployeeEvent(
      id: id,
      title: _string(json['title']) ?? _string(json['name']) ?? '',
      description: _string(json['description']),
      image: _string(json['image']) ?? _string(json['imageUrl']),
      status: _string(json['status']) ?? 'Active',
      slots: _objectsAt(json['slots'] ?? json['EventPassSlots'])
          .map(eventSlot)
          .whereType<EmployeeEventSlot>()
          .toList(growable: false),
      customFields:
          _objectsAt(json['customFields'] ?? json['EventPassCustomFields'])
              .map(eventCustomField)
              .whereType<EmployeeEventCustomField>()
              .toList(growable: false),
      faqs: _objectsAt(json['faqs'] ?? json['EventPassFaqs'])
          .map(eventFaq)
          .whereType<EmployeeEventFaq>()
          .toList(growable: false),
      createdAt: _date(json['createdAt']),
    );
  }

  /// A slot keeps its id so the edit form can send it back and update in place
  /// rather than replacing the row — and with it, its bookings.
  static EmployeeEventSlot? eventSlot(Map<String, dynamic> json) {
    final name = _string(json['name']);
    final date = _date(json['date']);
    final id = _intOrNull(json['id']);

    // A slot with nothing identifying it at all is noise, not a row.
    if (id == null && name == null && date == null) return null;

    return EmployeeEventSlot(
      id: id,
      name: name ?? '',
      date: date,
      price: _num(json['price']),
      passType: _string(json['passType']) ?? 'Single',
      startTime: _string(json['startTime']),
      endTime: _string(json['endTime']),
      capacity: _intOrNull(json['capacity']) ?? _intOrNull(json['maxPasses']),
      booked: _intOrNull(json['booked']) ?? _intOrNull(json['bookedCount']),
    );
  }

  static EmployeeEventCustomField? eventCustomField(Map<String, dynamic> json) {
    final label = _string(json['label']);
    if (label == null) return null;

    return EmployeeEventCustomField(
      id: _intOrNull(json['id']),
      label: label,
      type: _string(json['type']) ?? 'text',
      required: _bool(json['required'] ?? json['isRequired']),
      placeholder: _string(json['placeholder']),
      options: _strings(json['options']),
    );
  }

  static EmployeeEventFaq? eventFaq(Map<String, dynamic> json) {
    final question = _string(json['question']);
    final answer = _string(json['answer']);
    if (question == null || answer == null) return null;

    return EmployeeEventFaq(
      id: _intOrNull(json['id']),
      question: question,
      answer: answer,
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Event bookings
  // ───────────────────────────────────────────────────────────────────────────

  static EmployeeEventBooking? eventBooking(Map<String, dynamic> json) {
    final id = _int(json['id']);
    if (id <= 0) return null;

    final event = _mapAt(json['EventPass']) ??
        _mapAt(json['eventPass']) ??
        _mapAt(json['event']) ??
        const {};
    final slot = _mapAt(json['EventPassSlot']) ??
        _mapAt(json['slot']) ??
        const {};
    final user = _mapAt(json['User']) ?? _mapAt(json['user']) ?? const {};

    return EmployeeEventBooking(
      id: id,
      bookingNumber: _string(json['bookingNumber']) ??
          _string(json['bookingId']) ??
          _string(json['referenceNumber']) ??
          '',
      eventId: _intOrNull(event['id']) ?? _intOrNull(json['eventPassId']),
      eventTitle: _string(event['title']) ?? _string(json['eventTitle']) ?? '',
      slotName: _string(slot['name']) ?? _string(json['slotName']) ?? '',
      slotDate: _date(slot['date']) ?? _date(json['slotDate']),
      // The booking's own guest fields win over the account: an event pass is
      // routinely bought for someone else, and the buyer's name on the ticket
      // would be the wrong one at the gate.
      customerName: _string(json['customerName']) ??
          _string(json['guestName']) ??
          _string(json['name']) ??
          _string(user['name']) ??
          '',
      email: _string(json['email']) ??
          _string(json['guestEmail']) ??
          _string(user['email']) ??
          '',
      phone: _string(json['phone']) ??
          _string(json['phoneNumber']) ??
          _string(user['phone_number']) ??
          '',
      quantity: _intOrNull(json['quantity']) ??
          _intOrNull(json['numberOfPasses']) ??
          1,
      totalAmount: _num(json['totalAmount'] ?? json['amount']),
      paymentStatus: _string(json['paymentStatus']) ?? 'Pending',
      bookingStatus: _string(json['bookingStatus']) ??
          _string(json['status']) ??
          'Confirmed',
      // The list route names them `individualPasses`; the other two spellings
      // are what older payloads used for the same array.
      passes: _objectsAt(json['individualPasses'] ??
              json['passes'] ??
              json['IndividualPasses'])
          .map(individualPass)
          .whereType<EmployeeIndividualPass>()
          .toList(growable: false),
      createdAt: _date(json['createdAt']),
    );
  }

  static EmployeeIndividualPass? individualPass(Map<String, dynamic> json) {
    final id = _int(json['id']);
    if (id <= 0) return null;

    return EmployeeIndividualPass(
      id: id,
      passCode: _string(json['passCode']) ?? _string(json['passNumber']) ?? '',
      holderName: _string(json['holderName']) ??
          _string(json['memberName']) ??
          _string(json['name']) ??
          '',
      // `holderEmail` is the pass holder's own address, which on a group
      // booking is not the buyer's — emailing a pass must not default to the
      // person who paid for it.
      email: _string(json['holderEmail']) ?? _string(json['email']),
      status: _string(json['status']) ?? 'Active',
      // `NotScanned` rather than null: the gate reports one of three states,
      // and "no value" is the first of them, not a fourth.
      scanStatus: _string(json['scanStatus']) ?? 'NotScanned',
      qrCode: _string(json['qrCode']) ?? _string(json['qrCodeUrl']),
      // The gate stamps the two directions separately; the later one is when
      // the pass was last seen.
      scannedAt: _date(json['scannedOutAt']) ??
          _date(json['scannedInAt']) ??
          _date(json['scannedAt']) ??
          _date(json['scanTime']),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Contact enquiries
  // ───────────────────────────────────────────────────────────────────────────

  static EmployeeContactEnquiry? contactEnquiry(Map<String, dynamic> json) {
    // A UUID, not a number: parsing this as an int would yield 0 and drop
    // every row on the route.
    final id = _string(json['id']);
    if (id == null) return null;

    return EmployeeContactEnquiry(
      id: id,
      name: _string(json['name']) ?? _string(json['fullName']) ?? '',
      email: _string(json['email']) ?? '',
      phone: _string(json['phone']) ?? _string(json['phoneNumber']) ?? '',
      subject: _string(json['subject']) ?? '',
      message: _string(json['message']) ?? '',
      status: _string(json['status']) ?? 'New',
      createdAt: _date(json['createdAt']),
      updatedAt: _date(json['updatedAt']),
    );
  }

  /// The `statusCounts` block beside the contact-enquiry rows.
  ///
  /// Arrives either as an object (`{new: 4, resolved: 2}`) or as the rows a
  /// `GROUP BY` produced (`[{status: 'New', count: 4}]`); both are read. Keys
  /// are lower-cased so a lookup does not depend on the casing that came back.
  static EmployeeContactEnquiryCounts contactEnquiryCounts(Object? body) {
    final data = envelope(body);
    final raw = data['statusCounts'] ??
        (body is Map ? body['statusCounts'] : null);

    final counts = <String, int>{};

    final asMap = _mapAt(raw);
    if (asMap != null) {
      asMap.forEach((key, value) {
        final name = _string(key)?.toLowerCase();
        if (name != null) counts[name] = _int(value);
      });
      return EmployeeContactEnquiryCounts(byStatus: counts);
    }

    for (final row in _objectsAt(raw)) {
      final name = _string(row['status'])?.toLowerCase();
      if (name == null) continue;
      counts[name] = _int(row['count'] ?? row['total']);
    }

    return EmployeeContactEnquiryCounts(byStatus: counts);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Pickers
  // ───────────────────────────────────────────────────────────────────────────

  /// A student row → a picker option. The display name is on the linked `User`,
  /// not on the student row itself.
  static EmployeeOption? studentOption(Map<String, dynamic> json) {
    final id = _int(json['id']);
    if (id <= 0) return null;

    final user = _mapAt(json['User']) ?? _mapAt(json['user']) ?? const {};
    final name = _string(user['name']) ?? _string(json['name']) ?? 'Student #$id';

    return EmployeeOption(
      id: id,
      name: name,
      detail: _string(user['phone_number']),
    );
  }

  static EmployeeOption sportOption(EmployeeSport sport) =>
      EmployeeOption(id: sport.id, name: sport.displayName);

  static EmployeeOption courtOption(EmployeeCourt court) => EmployeeOption(
        id: court.id,
        name: court.displayName,
        detail: court.sportName.isEmpty ? null : court.sportName,
      );

  static EmployeeOption batchOption(EmployeeBatch batch) => EmployeeOption(
        id: batch.id,
        name: batch.displayName,
        detail: batch.feesLabel,
      );

  static EmployeeOption coachOption(EmployeeCoach coach) =>
      EmployeeOption(id: coach.id, name: coach.displayName);

  // ───────────────────────────────────────────────────────────────────────────
  // Primitives
  // ───────────────────────────────────────────────────────────────────────────

  static List<Map<String, dynamic>> _objects(List<dynamic> list) => list
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList(growable: false);

  /// [_objects] for a value that may not be a list at all.
  static List<Map<String, dynamic>> _objectsAt(Object? value) =>
      value is List ? _objects(value) : const <Map<String, dynamic>>[];

  static Map<String, dynamic>? _mapAt(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  /// A plain `["S", "M", "L"]`, with blanks dropped. Used for a custom field's
  /// options, which the API rejects as empty for a `select` — so an array of
  /// empty strings must not read as "has options".
  static List<String> _strings(Object? value) {
    if (value is! List) return const [];
    return value.map(_string).whereType<String>().toList(growable: false);
  }

  /// A list that is either `[{id, name}]` or `["Badminton"]`, flattened to
  /// names. Both shapes come back from `/coaches` depending on the include.
  static List<String> _names(Object? value) {
    if (value is! List) return const [];
    return value
        .map((entry) {
          if (entry is Map) return _string(entry['name']);
          return _string(entry);
        })
        .whereType<String>()
        .toList(growable: false);
  }

  /// The first candidate that reads as a positive int — used to walk the
  /// pagination shapes in precedence order without a pile of null checks.
  static int _firstInt(List<Object?> candidates) {
    for (final candidate in candidates) {
      final value = _intOrNull(candidate);
      if (value != null && value > 0) return value;
    }
    return 0;
  }

  static int _int(Object? value) => _intOrNull(value) ?? 0;

  static int? _intOrNull(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString().trim() ?? '');
  }

  static num _num(Object? value) => _numOrNull(value) ?? 0;

  /// Kept apart from [_num] where zero and "absent" mean different things — a
  /// batch fee of ₹0 is not the same as a batch with no fee set.
  static num? _numOrNull(Object? value) {
    if (value is num) return value;
    return num.tryParse(value?.toString().trim() ?? '');
  }

  /// The trend fields arrive as strings (`"12.40"`), so this parses rather
  /// than casts.
  static double? _doubleOrNull(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().trim() ?? '');
  }

  /// Tolerates the `1` / `"true"` spellings a JSON boolean can arrive as when
  /// it has been through a database driver.
  static bool _bool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().trim().toLowerCase();
    return text == 'true' || text == '1';
  }

  /// Trims, and treats the literal strings `"null"` and `""` as absent — both
  /// appear in these responses where a join found nothing.
  static String? _string(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text == 'null') return null;
    return text;
  }

  /// Reads a `DATEONLY` (`"2026-08-07"`) or a full ISO timestamp. Null rather
  /// than a fallback so the UI can tell "no date" from "the epoch".
  static DateTime? _date(Object? value) {
    if (value is DateTime) return value;
    final text = _string(value);
    if (text == null) return null;
    return DateTime.tryParse(text);
  }
}
