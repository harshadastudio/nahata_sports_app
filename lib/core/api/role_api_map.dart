import '../config/api_config.dart';
import '../network/api_exception.dart';
import '../services/app_session.dart';
import 'api_role.dart';

/// Every module the app implements, as the API-mapping layer names it.
///
/// The enum is the audit list: if a module exists in the console it has an
/// entry here, and [RoleApiMap] states which endpoint each role reaches it
/// through. `permissionKey` is the key the login payload uses in
/// `data.user.permissions` — spelled exactly as the backend sends it
/// (`sportsComplex` is camel case there while everything else is lower case).
enum ApiModule {
  dashboard('DASHBOARD', 'dashboard'),
  users('USERS', 'users'),
  roles('ROLES', 'roles'),
  complexAdmins('COMPLEX_ADMINS', 'users'),
  employees('EMPLOYEES', 'users'),
  securityGuards('SECURITY_GUARDS', 'users'),
  sportsComplexes('SPORTS_COMPLEXES', 'sportsComplex'),
  sports('SPORTS', 'sports'),
  coaches('COACHES', 'coaches'),
  batches('BATCHES', 'batches'),
  coachingEnquiries('COACHING_ENQUIRIES', 'students'),
  contactEnquiries('CONTACT_ENQUIRIES', 'contactEnquiries'),
  students('STUDENTS', 'students'),
  fees('FEES', 'payments'),
  courts('COURTS', 'courts'),
  courtSlots('COURT_SLOTS', 'courts'),
  bookings('BOOKINGS', 'bookings'),
  eventPasses('EVENT_PASSES', 'bookings'),
  visitorPasses('VISITOR_PASSES', 'bookings'),
  memberships('MEMBERSHIPS', 'memberships'),
  coupons('COUPONS', 'coupons'),
  payments('PAYMENTS', 'payments'),
  reports('REPORTS', 'reports'),
  settings('SETTINGS', 'settings'),
  notifications('NOTIFICATIONS', 'settings');

  const ApiModule(this.traceName, this.permissionKey);

  /// What the API trace prints — `[API] MODULE: EMPLOYEES`.
  final String traceName;

  /// The `data.user.permissions` key that gates this module.
  final String permissionKey;
}

/// How one role reaches one module's **list** route.
///
/// Writes (create/update/delete) hang off the same resource path and are not
/// enumerated here — the point of this table is the one thing that genuinely
/// differs by role, which is where the data comes from.
class ModuleApi {
  const ModuleApi({
    required this.module,
    required this.role,
    required this.method,
    required this.path,
    this.query = const <String, dynamic>{},
    this.complexScoped = false,
    this.scopeFromJwt = false,
    this.note = '',
  });

  final ApiModule module;
  final ApiRole role;

  /// `GET`, and only `GET` so far — every list route is a read.
  final String method;

  /// The path under [ApiConfig.baseUrl]. May contain a `{param}` placeholder
  /// for routes that need an id (`/courts/{courtId}/slots`).
  final String path;

  /// The query the confirmed URL carries. Callers merge their own filters over
  /// the top; a value of `null` here means "the caller always supplies it".
  final Map<String, dynamic> query;

  /// True when the rows this role sees belong to one sports complex only.
  final bool complexScoped;

  /// True when the backend derives that complex from the JWT, so the client
  /// must **not** append `sportComplexId` to the URL itself.
  final bool scopeFromJwt;

  /// Why this row is what it is — a confirmed capture, a documented route, or
  /// a deliberate omission.
  final String note;

  /// True when the route takes a path parameter the caller has to fill in.
  bool get isParameterised => path.contains('{');

  @override
  String toString() =>
      '${role.wire}/${module.traceName} → $method $path'
      '${query.isEmpty ? '' : '?${_queryString(query)}'}';

  static String _queryString(Map<String, dynamic> query) => query.entries
      .map((e) => '${e.key}=${e.value ?? ''}')
      .join('&');
}

/// Raised when a role asks for a module it has no route for.
///
/// Better than silently falling back to the other role's endpoint: a
/// COMPLEX_ADMIN reaching `/admin/employees` would be a real authorisation
/// question, not a UI glitch, so it stops here rather than going out over the
/// wire.
///
/// It is a [ForbiddenException] so the screens that already catch
/// [ApiException] show the same "you don't have permission" surface they show
/// for a real 403 — and, like a real 403, nothing about it routes the user
/// anywhere. The console stays where it is.
class UnmappedModuleException extends ForbiddenException {
  UnmappedModuleException(this.module, this.role)
    : super(
        'This console has no ${module.traceName.toLowerCase().replaceAll('_', ' ')} '
        'module for the ${role.wire} role.',
      );

  final ApiModule module;
  final ApiRole role;

  /// The developer-facing form, for logs and test failures.
  String get detail =>
      'No API mapping for ${role.wire} + ${module.traceName}. '
      'Add one to RoleApiMap rather than reusing another role\'s endpoint.';

  @override
  String toString() => 'UnmappedModuleException: $detail';
}

/// ROLE + MODULE → endpoint.
///
/// The single place that answers "which API does this screen call?". Screens
/// and repositories ask here instead of testing the role string themselves, so
/// a mapping can be corrected in one file rather than hunted through twenty.
///
/// Two rules this table exists to enforce:
///
///  * **ADMIN Employees and COMPLEX_ADMIN Coaches are different modules on
///    different endpoints.** `/admin/employees` and `/coaches` are never
///    merged, and neither is renamed into the other.
///  * **Most modules genuinely are shared.** Where ADMIN and COMPLEX_ADMIN hit
///    the same path, the backend scopes the rows from the JWT — so the client
///    must not append `sportComplexId` itself ([ModuleApi.scopeFromJwt]).
///
/// Nothing here is invented. Every path is one already present in
/// [ApiEndpoints]; where a module has no confirmed COMPLEX_ADMIN endpoint the
/// shared route is kept, because guessing a new URL would 404 for both roles.
class RoleApiMap {
  const RoleApiMap._();

  /// Modules the COMPLEX_ADMIN console deliberately has no route for.
  ///
  /// These are estate-wide staff registries: an employee, a security guard, a
  /// complex admin and the role/permission matrix are all administered across
  /// venues, and no venue-scoped endpoint for them has been confirmed. The
  /// COMPLEX_ADMIN sidebar leaves them out, so this is a backstop rather than
  /// the primary guard.
  static const Set<ApiModule> _adminOnly = <ApiModule>{
    ApiModule.complexAdmins,
    ApiModule.employees,
    ApiModule.securityGuards,
    ApiModule.roles,
  };

  /// The list route for [module] as [role] reaches it, or null when that role
  /// has none.
  ///
  /// [role] defaults to the signed-in account.
  static ModuleApi? list(ApiModule module, {ApiRole? role}) {
    final effective = role ?? ApiRole.current;

    if (effective == ApiRole.complexAdmin && _adminOnly.contains(module)) {
      return null;
    }

    return _bindingFor(module, effective);
  }

  /// [list], but throwing [UnmappedModuleException] instead of returning null —
  /// for call sites that cannot carry on without a route.
  static ModuleApi require(ApiModule module, {ApiRole? role}) {
    final effective = role ?? ApiRole.current;
    final binding = list(module, role: effective);
    if (binding == null) throw UnmappedModuleException(module, effective);
    return binding;
  }

  /// Whether [role] may reach [module] at all — the API-side counterpart of the
  /// sidebar's permission filter.
  static bool supports(ApiModule module, {ApiRole? role}) =>
      list(module, role: role) != null;

  /// Modules whose rows belong to a single venue for the signed-in session.
  static bool isComplexScoped(ApiModule module, {ApiRole? role}) =>
      list(module, role: role)?.complexScoped ?? false;

  /// The venue every scoped call is limited to, from the session — never a
  /// constant, and never a value a COMPLEX_ADMIN picked in the UI.
  static int? get scopedComplexId => AppSession.instance.sportComplexId;

  // ---------------------------------------------------------------------------
  // Reverse lookup
  // ---------------------------------------------------------------------------

  /// Which module a request path belongs to.
  ///
  /// The trace needs this: it runs inside the HTTP client, which sees a URL and
  /// not the screen that asked for it. Matching here rather than tagging every
  /// call site is what gives *every* request a MODULE line for free — including
  /// detail, create and delete routes, not just the lists in this table.
  ///
  /// Null for paths outside the console (`/auth/*`, the storefront, the coach
  /// and employee dashboards); those still get a ROLE line.
  static ApiModule? moduleForPath(String path) {
    var normalised = path.startsWith('/') ? path : '/$path';

    // Tolerates a full request line: callers pass `uri.path`, but a hand-built
    // string with its query attached should not silently resolve to nothing.
    final queryStart = normalised.indexOf('?');
    if (queryStart >= 0) normalised = normalised.substring(0, queryStart);

    // Accepts both the relative path a data source names (`/coaches`) and the
    // absolute one the HTTP client ends up with (`/api/coaches`), since the
    // base URL carries the `/api` segment.
    if (normalised == '/api') return null;
    if (normalised.startsWith('/api/')) {
      normalised = normalised.substring(4);
    }

    // `/courts/{id}/slots…` is the Slots module, not Courts — checked first
    // because it lives underneath the Courts prefix.
    if (normalised.startsWith('/courts/') && normalised.contains('/slots')) {
      return ApiModule.courtSlots;
    }

    ApiModule? best;
    var bestLength = 0;

    _pathPrefixes.forEach((prefix, module) {
      if (prefix.length <= bestLength) return;
      // Segment-boundary match, so `/sports` never claims `/sports-complexes`.
      if (normalised == prefix || normalised.startsWith('$prefix/')) {
        best = module;
        bestLength = prefix.length;
      }
    });

    return best;
  }

  /// Path prefix → module. Longest match wins, so the `/admin/*` registries
  /// take precedence over the bare `/admin` group.
  static const Map<String, ApiModule> _pathPrefixes = <String, ApiModule>{
    '/dashboard': ApiModule.dashboard,
    '/admin/stats': ApiModule.dashboard,
    '/admin/users': ApiModule.users,
    '/admin/create-user': ApiModule.users,
    '/admin/roles': ApiModule.roles,
    '/admin/complex-admins': ApiModule.complexAdmins,
    '/admin/employees': ApiModule.employees,
    '/admin/security-guards': ApiModule.securityGuards,
    '/admin/coupons': ApiModule.coupons,
    '/sports-complexes': ApiModule.sportsComplexes,
    '/sports': ApiModule.sports,
    '/coaches': ApiModule.coaches,
    '/coaching-enquiries': ApiModule.coachingEnquiries,
    '/contact-us': ApiModule.contactEnquiries,
    '/students': ApiModule.students,
    '/fees': ApiModule.fees,
    '/batches': ApiModule.batches,
    '/courts': ApiModule.courts,
    '/bookings': ApiModule.bookings,
    '/event-passes': ApiModule.eventPasses,
    '/visitor-passes': ApiModule.visitorPasses,
    '/memberships': ApiModule.memberships,
    '/payments': ApiModule.payments,
    '/reports': ApiModule.reports,
    '/settings': ApiModule.settings,
    '/notifications': ApiModule.notifications,
  };

  // ---------------------------------------------------------------------------
  // The table
  // ---------------------------------------------------------------------------

  static ModuleApi _bindingFor(ApiModule module, ApiRole role) {
    final scoped = role == ApiRole.complexAdmin;

    ModuleApi shared(
      String path, {
      Map<String, dynamic> query = const <String, dynamic>{},
      String note = '',
    }) => ModuleApi(
      module: module,
      role: role,
      method: 'GET',
      path: path,
      query: query,
      complexScoped: scoped,
      scopeFromJwt: scoped,
      note: note,
    );

    switch (module) {
      // ── Overview ──────────────────────────────────────────────────────────
      case ApiModule.dashboard:
        return shared(
          ApiEndpoints.dashboardStats,
          note: 'Shared. Counters come back scoped to the caller\'s venue.',
        );

      // ── Access control ────────────────────────────────────────────────────
      case ApiModule.users:
        return shared(
          ApiEndpoints.adminUsers,
          query: const {'page': 1, 'limit': 10},
          note: 'Shared route; COMPLEX_ADMIN sees its own venue\'s users.',
        );

      case ApiModule.roles:
        return ModuleApi(
          module: module,
          role: role,
          method: 'GET',
          path: ApiEndpoints.adminRolePermissions('{role}'),
          note:
              'ADMIN only. The route rejects ADMIN and COMPLEX_ADMIN as values '
              '— only EMPLOYEE, COACH, SECURITY and USER are permission-managed.',
        );

      case ApiModule.complexAdmins:
        return ModuleApi(
          module: module,
          role: role,
          method: 'GET',
          path: ApiEndpoints.complexAdmins,
          query: const {'page': 1, 'limit': 10},
          note: 'ADMIN only — a venue admin does not administer its peers.',
        );

      // The rule the brief is emphatic about: ADMIN Employees is
      // `/admin/employees`, and it is never swapped for `/coaches`.
      case ApiModule.employees:
        return ModuleApi(
          module: module,
          role: role,
          method: 'GET',
          path: ApiEndpoints.employees,
          query: const {
            'page': 1,
            'limit': 10,
            'search': '',
            'department': '',
            'status': '',
          },
          note:
              'ADMIN only, confirmed URL. Employees are NOT coaches; this is a '
              'different module from COMPLEX_ADMIN + COACHES.',
        );

      case ApiModule.securityGuards:
        return ModuleApi(
          module: module,
          role: role,
          method: 'GET',
          path: ApiEndpoints.securityGuards,
          query: const {'page': 1, 'limit': 10},
          note: 'ADMIN only.',
        );

      case ApiModule.sportsComplexes:
        return ModuleApi(
          module: module,
          role: role,
          method: 'GET',
          path: ApiEndpoints.sportsComplexes,
          query: const {'page': 1, 'limit': 100},
          complexScoped: scoped,
          // Not JWT-derived: the route is the global catalogue, so a
          // venue-scoped console narrows it to its own complex client-side and
          // refuses to let another one be picked.
          scopeFromJwt: false,
          note: scoped
              ? 'Confirmed URL. COMPLEX_ADMIN is restricted to its assigned '
                    'complex and may not select another.'
              : 'Confirmed URL. ADMIN works with the global catalogue.',
        );

      // ── Operations ────────────────────────────────────────────────────────
      case ApiModule.sports:
        return shared(
          ApiEndpoints.sports,
          query: const {'page': 1, 'limit': 100, 'status': 'Active'},
          note:
              'Confirmed URL, shared by both roles. The backend answers within '
              'the caller\'s authorised scope — do not filter the response.',
        );

      // The other half of the rule: COMPLEX_ADMIN Coaches is `/coaches`, and it
      // never becomes `/admin/employees`.
      case ApiModule.coaches:
        return shared(
          ApiEndpoints.coaches,
          query: const {'page': 1, 'limit': 100},
          note:
              'Confirmed URL for COMPLEX_ADMIN; ADMIN\'s Coaches module has '
              'always used the same route. Never `/admin/employees`.',
        );

      case ApiModule.batches:
        return shared(
          ApiEndpoints.batches,
          query: const {'page': 1, 'limit': 100},
          note: 'Shared, server-paginated.',
        );

      case ApiModule.coachingEnquiries:
        return shared(
          ApiEndpoints.coachingEnquiriesAll,
          query: const {'page': 1, 'limit': 10},
          note:
              'Shared. `/coaching-enquiries/all` is the admin-side queue; the '
              'coach console uses `/coaching-enquiries/coach/my-enquiries`.',
        );

      // Confirmed 2026-08-08: one route for both administrative roles. No
      // `/contact-us/complex-admin` has been confirmed to exist, so none is
      // called — the backend scopes the rows from the JWT.
      case ApiModule.contactEnquiries:
        return shared(
          ApiEndpoints.contactUsAdmin,
          query: const {'page': 1, 'limit': 10},
          note:
              'Confirmed URL, shared. Answers {inquiries, pagination, '
              'statusCounts}. `status` and `search` parameters are NOT '
              'confirmed and are never sent.',
        );

      case ApiModule.students:
        return shared(
          ApiEndpoints.students,
          query: const {'page': 1, 'limit': 10},
          note: 'Confirmed URL, shared by both roles.',
        );

      case ApiModule.fees:
        return shared(
          ApiEndpoints.fees,
          query: const {'page': 1, 'limit': 20},
          note:
              'Confirmed URL, shared. Retention figures are a separate route, '
              '`${ApiEndpoints.feesRetentionStats}`, which takes no parameters. '
              'Approve/reject are ADMIN, COMPLEX_ADMIN and EMPLOYEE only — a '
              'COACH may read and write but not approve.',
        );

      case ApiModule.courts:
        return shared(
          ApiEndpoints.courts,
          query: const {'limit': 100},
          note: 'Confirmed URL, shared. Unpaginated — `limit` only, no `page`.',
        );

      case ApiModule.courtSlots:
        return shared(
          ApiEndpoints.courtSlots('{courtId}'),
          note: 'Shared. Needs the court id, so it has no standalone list.',
        );

      case ApiModule.bookings:
        return shared(
          ApiEndpoints.bookings,
          query: const {'page': 1, 'limit': 10},
          note: 'Shared. The route documents no filter parameters.',
        );

      case ApiModule.eventPasses:
        return shared(
          ApiEndpoints.eventPasses,
          query: const {'page': 1, 'limit': 10},
          note: 'Shared.',
        );

      case ApiModule.visitorPasses:
        return shared(
          ApiEndpoints.visitorPasses,
          query: const {'page': 1, 'limit': 20},
          note: 'Shared.',
        );

      // ── Business ──────────────────────────────────────────────────────────
      case ApiModule.memberships:
        return shared(
          ApiEndpoints.memberships,
          query: const {'page': 1, 'limit': 10},
          note: 'Shared.',
        );

      case ApiModule.coupons:
        return shared(
          ApiEndpoints.adminCoupons,
          query: const {'page': 1, 'limit': 10},
          note: 'Shared. Requires the x-client-platform header.',
        );

      case ApiModule.payments:
        return shared(
          ApiEndpoints.paymentsAll,
          query: const {'page': 1, 'limit': 10},
          note: 'Shared. No console screen renders it yet.',
        );

      case ApiModule.reports:
        return shared(
          ApiEndpoints.reportsOverview,
          note: 'Shared. Nineteen `/reports/*` routes behind one date range.',
        );

      case ApiModule.settings:
        return shared(
          ApiEndpoints.settings,
          note: 'Shared.',
        );

      case ApiModule.notifications:
        return shared(
          ApiEndpoints.notificationsAdmin,
          query: const {'page': 1, 'limit': 20},
          note: 'Shared admin feed.',
        );
    }
  }
}