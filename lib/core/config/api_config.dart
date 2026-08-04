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
  static const String coachingEnquiries = '/coaching-enquiries';

  // Coach dashboard.
  static const String coachStats = '/coach/dashboard/stats';
  static const String coachScheduleToday = '/coach/dashboard/schedule/today';
  static const String coachTopPerformers =
      '/coach/dashboard/students/top-performers';
  static const String coachAttendanceRecords =
      '/coach/dashboard/attendance/records';
  static const String coachEnquiries = '/coaching-enquiries/coach/my-enquiries';

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

  // Offers.
  static const String activeCoupons = '/coupons/active';
  static const String validateCoupon = '/coupons/validate';

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
