/// Centralised API configuration.
///
/// Every base URL / endpoint used by the authentication + profile stack lives
/// here so nothing is hardcoded at the call site. Values can be overridden at
/// build time without touching code:
///
/// ```
/// flutter build apk \
///   --dart-define=API_BASE_URL=https://api.nahatasports.com/api \
///   --dart-define=LEGACY_BASE_URL=https://nahatasports.com/api
/// ```
class ApiConfig {
  const ApiConfig._();

  /// Primary (JWT) backend.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.nahatasports.com/api',
  );

  /// Legacy backend still serving student/dashboard/booking endpoints.
  static const String legacyBaseUrl = String.fromEnvironment(
    'LEGACY_BASE_URL',
    defaultValue: 'https://nahatasports.com/api',
  );

  /// Host that serves uploaded student media.
  static const String mediaBaseUrl = String.fromEnvironment(
    'MEDIA_BASE_URL',
    defaultValue: 'https://nahatasports.com/public/uploads',
  );

  /// Root host for the handful of legacy routes served outside `/api`
  /// (attendance, for example).
  static const String attendanceBaseUrl = String.fromEnvironment(
    'WEB_BASE_URL',
    defaultValue: 'https://nahatasports.com',
  );

  /// Value of the `x-client-platform` header the coupon endpoints require.
  ///
  /// The backend decides App-only vs Web-only coupons from this header, and the
  /// coupon module specifies `android` for the mobile app — so it is sent on
  /// iOS too, because what the header actually distinguishes is *app* traffic
  /// from *web* traffic, and an iOS build claiming `ios` would fall outside the
  /// vocabulary the backend matches on. Override without touching code if the
  /// backend gains a separate iOS value:
  /// `--dart-define=CLIENT_PLATFORM=ios`.
  static const String clientPlatform = String.fromEnvironment(
    'CLIENT_PLATFORM',
    defaultValue: 'android',
  );

  /// The header itself, ready to spread into a request.
  static const Map<String, String> platformHeader = {
    'x-client-platform': clientPlatform,
  };

  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration uploadTimeout = Duration(seconds: 60);

  /// HTTPS is mandatory — see [assertSecure].
  static bool isSecure(String url) => url.startsWith('https://');

  static void assertSecure(String url) {
    assert(
      isSecure(url),
      'Insecure URL rejected: $url. All API traffic must use HTTPS.',
    );
  }
}

/// Endpoint paths, relative to [ApiConfig.baseUrl] unless stated otherwise.
class ApiEndpoints {
  const ApiEndpoints._();

  static const String login = '/auth/login';
  static const String googleLogin = '/auth/google-login';
  static const String registerStudent = '/students/register';
  static const String studentMe = '/students/me';
  static const String refresh = '/auth/refresh';
  static const String profile = '/auth/profile';
  static const String logout = '/auth/logout';

  static const String sportsComplexes = '/sports-complexes';

  /// `GET | PUT | DELETE /sports-complexes/{sportComplexId}`
  static String sportsComplex(Object id) => '/sports-complexes/$id';

  /// `GET /sports-complexes/{sportComplexId}/stats` — court counters for the
  /// admin detail drawer.
  static String sportsComplexStats(Object id) => '/sports-complexes/$id/stats';

  /// `PUT /sports-complexes/{sportComplexId}/status`
  static String sportsComplexStatus(Object id) =>
      '/sports-complexes/$id/status';

  /// `PUT /sports-complexes/{sportComplexId}/show-on-frontend`
  static String sportsComplexVisibility(Object id) =>
      '/sports-complexes/$id/show-on-frontend';

  /// `GET /sports-complexes/city/{city}` — the city-scoped list.
  ///
  /// The segment is encoded: a city like `Navi Mumbai` would otherwise break
  /// the path.
  static String sportsComplexesByCity(String city) =>
      '/sports-complexes/city/${Uri.encodeComponent(city.trim())}';

  /// `GET /sports-complexes/state/{state}`
  static String sportsComplexesByState(String state) =>
      '/sports-complexes/state/${Uri.encodeComponent(state.trim())}';

  /// `POST /sports-complexes/upload-image` — multipart, field `image`.
  static const String sportsComplexUploadImage =
      '/sports-complexes/upload-image';

  /// `DELETE /sports-complexes/delete-image?imageUrl=`
  static const String sportsComplexDeleteImage =
      '/sports-complexes/delete-image';

  // Coaching module.
  static const String sports = '/sports';

  /// `GET | PUT | DELETE /sports/{sportId}`
  static String sport(Object id) => '/sports/$id';

  /// `GET /sports/{sportId}/stats` — programme, court and student counters.
  static String sportStats(Object id) => '/sports/$id/stats';

  /// `PATCH /sports/{sportId}/status`
  static String sportStatus(Object id) => '/sports/$id/status';

  /// `PATCH /sports/{sportId}/show-on-frontend`
  static String sportVisibility(Object id) => '/sports/$id/show-on-frontend';

  /// `POST /sports/{sportId}/assign-ground` — moves a sport to a complex.
  static String sportAssignGround(Object id) => '/sports/$id/assign-ground';

  /// `POST /sports/upload-image` — multipart, field `image`.
  static const String sportUploadImage = '/sports/upload-image';

  /// `GET /coaches?status=` — the admin coach catalogue. Unpaginated.
  static const String coaches = '/coaches';

  /// `GET | PUT | DELETE /coaches/{coachId}`
  static String coach(Object id) => '/coaches/$id';

  /// `GET /coaches/{coachId}/stats` — programme and student counters.
  static String coachStatsFor(Object id) => '/coaches/$id/stats';

  /// `GET /coaches/sport/{sportId}` — the sport-scoped coach list.
  static String coachesBySport(Object sportId) => '/coaches/sport/$sportId';

  /// `GET /coaches/{coachId}/password`
  static String coachPassword(Object id) => '/coaches/$id/password';

  /// `POST /coaches/{coachId}/reset-password`
  static String coachResetPassword(Object id) => '/coaches/$id/reset-password';

  /// `POST /coaches/upload-image` — multipart, field `image`.
  static const String coachUploadImage = '/coaches/upload-image';

  static const String batches = '/batches';

  /// `GET /coaching-enquiries?page=&limit=` and `POST /coaching-enquiries`.
  ///
  /// The POST is the one public route in this family — a prospect submits it
  /// before they have an account.
  static const String coachingEnquiries = '/coaching-enquiries';

  /// `GET | PUT | DELETE /coaching-enquiries/{enquiryId}`
  static String coachingEnquiry(Object id) => '/coaching-enquiries/$id';

  /// `PATCH /coaching-enquiries/{enquiryId}/assign-coach`
  static String coachingEnquiryAssignCoach(Object id) =>
      '/coaching-enquiries/$id/assign-coach';

  /// `PATCH /coaching-enquiries/{enquiryId}/status`
  static String coachingEnquiryStatus(Object id) =>
      '/coaching-enquiries/$id/status';

  /// `GET /coaching-enquiries/stats` — the counters for the dashboard cards.
  ///
  /// Declared before [coachingEnquiry] would match it: `/stats` is a fixed
  /// segment, not an id, so it must never be built through that helper.
  static const String coachingEnquiryStats = '/coaching-enquiries/stats';

  // ---------------------------------------------------------------------------
  // Coach dashboard.
  //
  // Everything under `/coach/dashboard` is gated on the `COACH` role and scoped
  // by the bearer token — the coach is resolved from the token's email, so no
  // coach id is ever sent. See `coachDashboardRoutes.js`.
  // ---------------------------------------------------------------------------

  static const String coachStats = '/coach/dashboard/stats';
  static const String coachScheduleToday = '/coach/dashboard/schedule/today';
  static const String coachTopPerformers =
      '/coach/dashboard/students/top-performers';
  static const String coachAttendanceRecords =
      '/coach/dashboard/attendance/records';

  /// `GET /coach/dashboard/students/my-students?page=&limit=&search=&status=`
  static const String coachMyStudents = '/coach/dashboard/students/my-students';

  /// `GET /coach/dashboard/students/enrollments-by-month?month=&search=&status=`
  ///
  /// `month` is `yyyy-MM`. Answers one month's roster grouped batch-wise, plus
  /// the index of every month that has enrollments so the picker needs no
  /// second round trip.
  static const String coachEnrollmentsByMonth =
      '/coach/dashboard/students/enrollments-by-month';

  /// `GET /coach/dashboard/schedule/batches?page=&limit=&status=&sportId=`
  static const String coachBatches = '/coach/dashboard/schedule/batches';

  /// `GET | POST /coach/dashboard/performance/progress`
  static const String coachProgress = '/coach/dashboard/performance/progress';

  /// `PUT | DELETE /coach/dashboard/performance/progress/{performanceId}`
  static String coachProgressRecord(Object id) =>
      '/coach/dashboard/performance/progress/$id';

  // Autocomplete. Each answers a bare `[{id, name}]` under `data`, already
  // scoped to the coach's own batches.
  static const String coachAutocompleteStudents =
      '/coach/dashboard/autocomplete/students';
  static const String coachAutocompleteSports =
      '/coach/dashboard/autocomplete/sports';
  static const String coachAutocompleteBatches =
      '/coach/dashboard/autocomplete/batches';
  static const String coachAutocompletePrograms =
      '/coach/dashboard/autocomplete/programs';

  // Coach-side coaching enquiries. A different route family from the admin
  // ones above — note the `/coach` segment.

  /// `GET /coaching-enquiries/coach/my-enquiries?page=&limit=`
  static const String coachEnquiries = '/coaching-enquiries/coach/my-enquiries';

  /// `POST /coaching-enquiries/coach/create`
  static const String coachCreateEnquiry = '/coaching-enquiries/coach/create';

  /// `PATCH /coaching-enquiries/coach/{enquiryId}/status`
  static String coachEnquiryStatus(Object id) =>
      '/coaching-enquiries/coach/$id/status';

  /// `DELETE /coaching-enquiries/coach/{enquiryId}`
  static String coachEnquiry(Object id) => '/coaching-enquiries/coach/$id';

  /// `POST /coaching-enquiries/{enquiryId}/approve-and-enroll`
  ///
  /// Note the path has **no** `/coach` segment — unlike the other three, this
  /// is the shared route, and it grants COACH alongside ADMIN, COMPLEX_ADMIN
  /// and EMPLOYEE. Approving here is what creates the student and their
  /// enrollment, so it is the one enquiry action that changes more than a
  /// status. Takes `{paymentStatus, amountPaid, notes}`.
  static String coachingEnquiryApproveAndEnroll(Object id) =>
      '/coaching-enquiries/$id/approve-and-enroll';

  // Attendance. Shared with admin/employee — the backend scopes the list to
  // the caller's own batches when the caller is a coach.

  /// `GET /attendance?page=&limit=&date=&batchId=&status=` and
  /// `POST /attendance` to mark.
  static const String attendance = '/attendance';

  /// `PATCH /attendance/{attendanceId}` — correct an already-marked record.
  static String attendanceRecord(Object id) => '/attendance/$id';

  // Fees. Read and write are open to COACH; approve/reject are not (those are
  // ADMIN/EMPLOYEE only), which is why Fees Approval is read-only for a coach.

  /// `GET | POST /fees?page=&limit=&status=&search=`
  static const String fees = '/fees';

  /// `GET /fees/stats`
  static const String feesStats = '/fees/stats';

  /// `PUT | DELETE /fees/{feeId}`
  static String fee(Object id) => '/fees/$id';

  /// `PATCH /fees/{feeId}/payment` — record a payment against a fee record.
  static String feePayment(Object id) => '/fees/$id/payment';

  /// `POST /fees/scan-pass` — scanning a student gate pass. For a COACH this
  /// **also marks the student Present for today**, so it must never be called
  /// merely to look a pass up.
  static const String feesScanPass = '/fees/scan-pass';

  /// `GET /fees/scan-logs?date=` — the date-wise log of gate-pass scans.
  static const String feesScanLogs = '/fees/scan-logs';

  // Notifications.

  /// `GET /notifications/admin?page=&limit=` — notifications this coach sent.
  static const String notificationsAdmin = '/notifications/admin';

  /// `POST /notifications/send`
  static const String notificationsSend = '/notifications/send';

  /// `GET /notifications/users` — the addressable audience.
  static const String notificationsUsers = '/notifications/users';

  /// `GET /notifications` — the caller's own inbox.
  static const String notifications = '/notifications';

  /// `GET /notifications/unread-count`
  static const String notificationsUnreadCount = '/notifications/unread-count';

  /// `PATCH /notifications/{notificationId}/read`
  static String notificationRead(Object id) => '/notifications/$id/read';

  /// `PATCH /notifications/mark-all-read`
  static const String notificationsMarkAllRead = '/notifications/mark-all-read';

  /// `PATCH | DELETE /notifications/{notificationId}`
  static String notification(Object id) => '/notifications/$id';

  /// `GET /permissions/{role}` — the permission slugs granted to a role.
  static String permissionsForRole(String role) =>
      '/permissions/${role.toLowerCase()}';

  // ---------------------------------------------------------------------------
  // Admin dashboard.
  // ---------------------------------------------------------------------------

  /// `GET /admin/stats` — the summary counters on the dashboard home.
  static const String adminStats = '/admin/stats';

  /// `GET /admin/users?page=&limit=&role=&search=&status=`
  static const String adminUsers = '/admin/users';

  /// `POST /admin/create-user`
  static const String adminCreateUser = '/admin/create-user';

  /// `GET | PUT | DELETE /admin/users/{userId}`
  static String adminUser(Object userId) => '/admin/users/$userId';

  /// `GET | PUT /admin/roles/{ROLE}/permissions`
  ///
  /// The role segment is sent in the backend's own casing, never lowercased —
  /// but this route has its **own** vocabulary, captured from a live 400 on
  /// 2026-08-04: `Must be one of: EMPLOYEE, COACH, SECURITY, USER`. Pass
  /// `AdminRole.permissionsSlug` (which says `SECURITY`, not `SECURITY_GUARD`),
  /// not `AdminRole.slug`.
  static String adminRolePermissions(String role) =>
      '/admin/roles/$role/permissions';

  // Dashboard home. Note these sit under `/dashboard`, not `/admin/dashboard`.
  static const String dashboardStats = '/dashboard/stats';
  static const String dashboardEnrollmentTrends =
      '/dashboard/enrollment-trends';
  static const String dashboardSportDistribution =
      '/dashboard/sport-distribution';
  static const String dashboardLiveEnquiries = '/dashboard/live-enquiries';

  /// `GET | POST /admin/complex-admins`
  static const String complexAdmins = '/admin/complex-admins';

  /// `PUT | DELETE /admin/complex-admins/{complexAdminId}`
  static String complexAdmin(Object id) => '/admin/complex-admins/$id';

  /// `GET | POST /admin/employees`
  static const String employees = '/admin/employees';

  /// `GET | PUT | DELETE /admin/employees/{employeeId}`
  static String employee(Object id) => '/admin/employees/$id';

  /// `GET /admin/employees/{employeeId}/password` — the employee's current
  /// temporary credentials. Responses are redacted in logs by [AppLogger].
  static String employeePassword(Object id) => '/admin/employees/$id/password';

  /// `POST /admin/employees/{employeeId}/reset-password`
  static String employeeResetPassword(Object id) =>
      '/admin/employees/$id/reset-password';

  /// `GET | POST /admin/security-guards`
  static const String securityGuards = '/admin/security-guards';

  /// `GET | PUT | DELETE /admin/security-guards/{guardId}`
  static String securityGuard(Object id) => '/admin/security-guards/$id';

  /// `GET /admin/security-guards/{guardId}/password` — the guard's current
  /// temporary credentials. Responses are redacted in logs by [AppLogger].
  static String securityGuardPassword(Object id) =>
      '/admin/security-guards/$id/password';

  /// `POST /admin/security-guards/{guardId}/reset-password`
  static String securityGuardResetPassword(Object id) =>
      '/admin/security-guards/$id/reset-password';

  // Events.
  static const String eventPasses = '/event-passes';

  /// `GET | PUT | DELETE /event-passes/{eventPassId}`
  static String eventPass(Object id) => '/event-passes/$id';

  /// `POST /event-passes/upload-image` — multipart, field `image`.
  static const String eventPassUploadImage = '/event-passes/upload-image';

  // Event gate scanning (the security console).

  /// `GET /event-passes/{eventPassId}/scan-stats` — `{totalPasses,
  /// totalPersons, in, out, notScanned, currentlyInside}`.
  static String eventPassScanStats(Object id) => '/event-passes/$id/scan-stats';

  /// `POST /event-passes/scan` — `{passCode, scanType: In|Out}`. **Changes the
  /// pass**: the first scan records the entry and the second the exit.
  static const String eventPassScan = '/event-passes/scan';

  /// `POST /event-passes/members/{memberId}/scan` — one member of a group
  /// booking, `{scanType: In|Out}`.
  static String eventPassMemberScan(Object memberId) =>
      '/event-passes/members/$memberId/scan';

  /// `GET /event-passes/bookings/all?page=&limit=` — every event booking.
  static const String allEventBookings = '/event-passes/bookings/all';

  /// Creates the pending booking whose id `/payments/create-order` needs.
  ///
  /// ⚠️ This is the one payment-chain path that has not been confirmed against
  /// the live API. Override it without touching code if it differs:
  /// `--dart-define=EVENT_BOOKING_PATH=/whatever/the/backend/uses`.
  static const String eventBookingCreate = String.fromEnvironment(
    'EVENT_BOOKING_PATH',
    defaultValue: '/event-passes/bookings/create',
  );

  /// Bookings belonging to the signed-in user.
  static const String myEventBookings = '/event-passes/bookings/my';
  static const String myCourtBookings = '/courts/bookings/my';

  // Visitor passes. The lifecycle is IN → OUT: `/verify` advances it, and
  // `/lookup` reads it without ever advancing it.

  /// `GET /visitor-passes?page=&limit=` and `POST /visitor-passes`.
  static const String visitorPasses = '/visitor-passes';

  /// `GET | DELETE /visitor-passes/{visitorPassId}`
  ///
  /// The route accepts either the numeric id or the pass code, so the segment
  /// is encoded — a code is free text and must not be able to open a path.
  static String visitorPass(Object idOrCode) =>
      '/visitor-passes/${Uri.encodeComponent(idOrCode.toString())}';

  /// `POST /visitor-passes/verify` — `{passCode, scanType: In|Out}`. **Changes
  /// the pass status.**
  static const String visitorPassVerify = '/visitor-passes/verify';

  /// `POST /visitor-passes/lookup` — `{passCode}`. Read-only: it must never
  /// mark a pass in or out.
  static const String visitorPassLookup = '/visitor-passes/lookup';

  /// `POST /visitor-passes/{visitorPassId}/send-email`
  static String visitorPassSendEmail(Object id) =>
      '/visitor-passes/$id/send-email';

  // Offers (customer side). Both require `x-client-platform` so the backend
  // can enforce App-only and Web-only coupons — see [ApiConfig.platformHeader].
  static const String activeCoupons = '/coupons/active';
  static const String validateCoupon = '/coupons/validate';

  // Coupon administration. Note the `/admin` prefix: these are a different
  // route family from the two customer endpoints above, not a variant of them.

  /// `GET | POST /admin/coupons` — the list takes `page`, `limit` and `search`.
  static const String adminCoupons = '/admin/coupons';

  /// `GET | PUT | DELETE /admin/coupons/{couponId}`
  static String adminCoupon(Object id) => '/admin/coupons/$id';

  /// `GET /admin/coupons/code/{couponCode}` — the lookup the create form uses
  /// to refuse a code that already exists. The segment is encoded because a
  /// code is free text.
  static String adminCouponByCode(String code) =>
      '/admin/coupons/code/${Uri.encodeComponent(code.trim())}';

  // Payments (shared by facility and event bookings).
  static const String createOrder = '/payments/create-order';
  static const String verifyPayment = '/payments/verify';

  // Admin bookings.

  /// `GET | POST /bookings`
  static const String bookings = '/bookings';

  /// `GET | PUT | DELETE /bookings/{bookingId}`
  static String booking(Object id) => '/bookings/$id';

  /// `GET /bookings/stats` — the dashboard counters.
  static const String bookingsStats = '/bookings/stats';

  /// `GET /bookings/current` — today's active, upcoming and finished slots.
  static const String bookingsCurrent = '/bookings/current';

  // Reports and analytics. Every route takes `from` and `to` (`yyyy-MM-dd`)
  // unless noted; the three `/all` routes also take `page` and `limit`.

  /// `GET /reports/overview`
  static const String reportsOverview = '/reports/overview';

  /// `GET /reports/revenue`
  static const String reportsRevenue = '/reports/revenue';

  /// `GET /reports/bookings` — the booking analytics, not the list.
  static const String reportsBookings = '/reports/bookings';

  /// `GET /reports/bookings/all?page=&limit=`
  static const String reportsBookingsAll = '/reports/bookings/all';

  /// `GET /reports/bookings/filter-options`
  static const String reportsBookingFilters = '/reports/bookings/filter-options';

  /// `GET /reports/students/all?page=&limit=`
  static const String reportsStudentsAll = '/reports/students/all';

  /// `GET /reports/students/filter-options`
  static const String reportsStudentFilters = '/reports/students/filter-options';

  /// `GET /reports/students/new-retention`
  static const String reportsRetention = '/reports/students/new-retention';

  /// `GET /reports/students/new-retention/filter-options`
  static const String reportsRetentionFilters =
      '/reports/students/new-retention/filter-options';

  /// `GET /reports/coaches/all?page=&limit=`
  static const String reportsCoachesAll = '/reports/coaches/all';

  /// `GET /reports/coaches/filter-options`
  static const String reportsCoachFilters = '/reports/coaches/filter-options';

  /// `GET /reports/memberships`
  static const String reportsMemberships = '/reports/memberships';

  /// `GET /reports/users`
  static const String reportsUsers = '/reports/users';

  /// `GET /reports/coaching`
  static const String reportsCoaching = '/reports/coaching';

  /// `GET /reports/facilities`
  static const String reportsFacilities = '/reports/facilities';

  // Chart routes. **The module documents these under `/reports/charts/…`, and
  // the live API serves them without that segment**: a capture on 2026-08-04
  // showed `GET /reports/booking-trends?from=&to=` answering
  // `{success, data: [{date, bookings, revenue}]}`. Only booking-trends was
  // captured, so the unprefixed path is tried first and the documented one is
  // kept as a fallback the data source falls back to on a 404.

  /// `GET /reports/booking-trends` — captured live.
  static const String reportsChartBookingTrends = '/reports/booking-trends';
  static const String reportsChartBookingTrendsAlt =
      '/reports/charts/booking-trends';

  /// `GET /reports/revenue-by-court`
  static const String reportsChartRevenueByCourt = '/reports/revenue-by-court';
  static const String reportsChartRevenueByCourtAlt =
      '/reports/charts/revenue-by-court';

  /// `GET /reports/peak-hours`
  static const String reportsChartPeakHours = '/reports/peak-hours';
  static const String reportsChartPeakHoursAlt = '/reports/charts/peak-hours';

  /// `GET /reports/court-performance`
  static const String reportsChartCourtPerformance =
      '/reports/court-performance';
  static const String reportsChartCourtPerformanceAlt =
      '/reports/charts/court-performance';

  // Memberships.

  /// `GET | POST /memberships` — list takes `page`, `limit` and `status`.
  static const String memberships = '/memberships';

  /// `GET | PUT | DELETE /memberships/{membershipId}`
  static String membership(Object id) => '/memberships/$id';

  /// `GET /memberships/stats` — the dashboard counters.
  static const String membershipsStats = '/memberships/stats';

  /// `GET /memberships/user/{userId}` — every membership a user has held.
  static String membershipsForUser(Object userId) =>
      '/memberships/user/$userId';

  /// `GET /memberships/user/{userId}/active` — the plan in force, if any.
  static String activeMembershipForUser(Object userId) =>
      '/memberships/user/$userId/active';

  /// `PATCH /memberships/{membershipId}/status`
  static String membershipStatus(Object id) => '/memberships/$id/status';

  /// `PATCH /memberships/{membershipId}/payment-status`
  static String membershipPaymentStatus(Object id) =>
      '/memberships/$id/payment-status';

  /// `PATCH /memberships/{membershipId}/cancel` — takes a `reason`.
  static String membershipCancel(Object id) => '/memberships/$id/cancel';

  /// `POST /memberships/{membershipId}/renew`
  static String membershipRenew(Object id) => '/memberships/$id/renew';

  /// `POST /memberships/check-expired` — the maintenance sweep.
  static const String membershipsCheckExpired = '/memberships/check-expired';

  // Courts and their slots.

  /// `GET | POST /courts` — the admin court list, filtered by complex/sport.
  static const String courts = '/courts';

  /// `GET | PUT | DELETE /courts/{courtId}`
  static String court(Object id) => '/courts/$id';

  /// `PATCH /courts/{courtId}/show-on-frontend`
  static String courtVisibility(Object id) => '/courts/$id/show-on-frontend';

  // Court-booking gate scanning (the security console).

  /// `GET /courts/bookings/scan-stats?courtId=&date=` — the same six counters
  /// the event scanner reports.
  static const String courtBookingScanStats = '/courts/bookings/scan-stats';

  /// `POST /courts/bookings/scan` — `{passCode, scanType: In|Out}`.
  static const String courtBookingScan = '/courts/bookings/scan';

  /// `POST /courts/members/{bookingMemberId}/scan` — one member of a booking.
  static String courtBookingMemberScan(Object memberId) =>
      '/courts/members/$memberId/scan';

  /// `POST /courts/bookings/{bookingId}/members/{bookingMemberId}/send-email`
  /// — `{recipientEmail}`.
  static String courtBookingMemberEmail(Object bookingId, Object memberId) =>
      '/courts/bookings/$bookingId/members/$memberId/send-email';

  /// `GET | POST /courts/{courtId}/slots`
  static String courtSlots(Object courtId) => '/courts/$courtId/slots';

  /// `PUT | DELETE /courts/{courtId}/slots/{slotId}`
  static String courtSlot(Object courtId, Object slotId) =>
      '/courts/$courtId/slots/$slotId';

  /// `PATCH /courts/{courtId}/slots/{slotId}/toggle` — block / unblock.
  static String courtSlotToggle(Object courtId, Object slotId) =>
      '/courts/$courtId/slots/$slotId/toggle';

  /// `GET /courts/{courtId}/available-slots?date=`
  static String courtAvailableSlots(Object courtId) =>
      '/courts/$courtId/available-slots';

  /// `GET /courts/availability?sportComplexId=&sportId=&date=` — free time
  /// across every court, without naming them.
  static const String courtsAvailability = '/courts/availability';

  static String batchById(Object id) => '/batches/$id';
  static String batchesBySport(Object sportId) => '/batches/sport/$sportId';
  static String batchesByCoach(Object coachId) => '/batches/coach/$coachId';
  static String batchStats(Object id) => '/batches/$id/stats';

  /// `PATCH /batches/{batchId}/status`
  static String batchStatus(Object id) => '/batches/$id/status';

  /// `POST /batches/upload-image` — multipart, field `image`.
  ///
  /// **Not in the documented batch endpoint list.** It is named after the three
  /// upload routes that are documented (`/sports-complexes`, `/sports` and
  /// `/coaches` all expose `{resource}/upload-image`), so the admin console can
  /// offer the image field the batch form specifies. A failure here is
  /// surfaced in the field and never blocks saving the batch itself.
  static const String batchUploadImage = '/batches/upload-image';

  // Application settings. `GET /settings` answers with every group at once;
  // each group is written back through its own route.

  /// `GET /settings`
  static const String settings = '/settings';

  /// `GET /settings/{key}` — one configuration value.
  ///
  /// The segment is encoded: a key is free text and must not be able to open a
  /// path of its own.
  static String setting(String key) =>
      '/settings/${Uri.encodeComponent(key.trim())}';

  /// `PUT /settings/general`
  static const String settingsGeneral = '/settings/general';

  /// `PUT /settings/booking`
  static const String settingsBooking = '/settings/booking';

  /// `PUT /settings/payment`
  static const String settingsPayment = '/settings/payment';

  /// `PUT /settings/notifications`
  static const String settingsNotifications = '/settings/notifications';

  /// `PUT /settings/branding`
  static const String settingsBranding = '/settings/branding';

  /// `POST /settings/upload-logo` — multipart, field `logo`.
  static const String settingsUploadLogo = '/settings/upload-logo';

  /// `POST /settings/upload-favicon` — multipart, field `favicon`.
  static const String settingsUploadFavicon = '/settings/upload-favicon';

  /// `POST /settings/reset` — restores the defaults. Destructive.
  static const String settingsReset = '/settings/reset';

  // Legacy backend (relative to [ApiConfig.legacyBaseUrl]).
  static const String studentDashboard = '/student_dashboard';
  static const String saveFcmToken = '/save-fcm-token';
  static const String deleteFcmToken = '/delete-fcm-token';

  static String userEdit(String userId) => '/$userId/edit';
  static String userUpdate(String userId) => '/$userId/update';
  static String deleteStudent(String userId) => '/students/$userId';
}

/// Storage keys. Kept in one place so nothing drifts between screens.
class StorageKeys {
  const StorageKeys._();

  // Secure storage (tokens only).
  static const String accessToken = 'ns_access_token';
  static const String refreshToken = 'ns_refresh_token';

  // SharedPreferences.
  static const String isLoggedIn = 'isLoggedIn';
  static const String user = 'user';
  static const String role = 'role';
  static const String permissions = 'permissions';
  static const String profileCache = 'profile_cache';
  static const String profileCachedAt = 'profile_cached_at';

  // Legacy keys, migrated into secure storage on first launch after upgrade.
  static const String legacyAuthToken = 'authToken';
  static const String legacyRefreshToken = 'refreshToken';
}

/// User-facing strings for auth/session events.
class AuthMessages {
  const AuthMessages._();

  static const String sessionExpired =
      'Your session has expired. Please login again.';
  static const String noInternet =
      'No internet connection. Please check your network and try again.';
  static const String timeout = 'The request timed out. Please try again.';
  static const String unknown = 'Something went wrong. Please try again.';
}
