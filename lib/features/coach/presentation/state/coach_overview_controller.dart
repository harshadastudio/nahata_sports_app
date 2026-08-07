import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../core/coach_log.dart';
import '../../domain/entities/coach_enquiry.dart';
import '../../domain/entities/coach_option.dart';
import '../../domain/entities/coach_overview.dart';
import '../../domain/repositories/coach_dashboard_repository.dart';
import 'coach_view_state.dart';

/// Everything the Dashboard Overview shows: the six stat tiles, today's
/// schedule, the top performers, and a preview of the coach's enquiry queue.
///
/// The four sections load **concurrently and fail independently**. The overview
/// is a summary of four unrelated endpoints, and one of them 500-ing must not
/// blank the other three — so each section keeps its own state and its own
/// error string, and the page renders whatever arrived.
///
/// The one thing that does fail the whole page is a missing coach profile: the
/// backend answers 404 on *every* `/coach/dashboard` route when the signed-in
/// user has no linked `Coach` row, and showing four identical "not found"
/// boxes would hide what is actually wrong. See [profileMissing].
class CoachOverviewController extends ChangeNotifier {
  CoachOverviewController(this._repository) {
    CoachLog.life('CoachOverviewController created');
  }

  final CoachDashboardRepository _repository;

  /// How many enquiries the overview previews. The full queue lives on the
  /// Coaching Enquiries screen.
  static const int enquiryPreviewLimit = 5;

  // ── Stats ──────────────────────────────────────────────────────────────────
  CoachViewState _statsState = CoachViewState.idle;
  CoachDashboardStats _stats = CoachDashboardStats.empty;
  String? _statsError;

  CoachViewState get statsState => _statsState;
  CoachDashboardStats get stats => _stats;
  String? get statsError => _statsError;

  // ── Today's schedule ───────────────────────────────────────────────────────
  CoachViewState _scheduleState = CoachViewState.idle;
  List<CoachSession> _schedule = const [];
  String? _scheduleError;

  CoachViewState get scheduleState => _scheduleState;
  List<CoachSession> get schedule => _schedule;
  String? get scheduleError => _scheduleError;

  // ── Top performers ─────────────────────────────────────────────────────────
  CoachViewState _performersState = CoachViewState.idle;
  List<CoachTopPerformer> _performers = const [];
  String? _performersError;

  CoachViewState get performersState => _performersState;
  List<CoachTopPerformer> get performers => _performers;
  String? get performersError => _performersError;

  // ── Enquiry preview ────────────────────────────────────────────────────────
  CoachViewState _enquiriesState = CoachViewState.idle;
  List<CoachEnquiry> _enquiries = const [];
  int _enquiryTotal = 0;
  String? _enquiriesError;

  CoachViewState get enquiriesState => _enquiriesState;
  List<CoachEnquiry> get enquiries => _enquiries;

  /// Every enquiry assigned to the coach, not just the previewed ones.
  int get enquiryTotal => _enquiryTotal;
  String? get enquiriesError => _enquiriesError;

  // ── Whole-page conditions ──────────────────────────────────────────────────
  bool _refreshing = false;
  bool _profileMissing = false;
  bool _disposed = false;

  /// True while a refresh runs over content already on screen — the page shows
  /// a hairline bar instead of blanking.
  bool get refreshing => _refreshing;

  /// The signed-in user has no linked `Coach` row, so nothing on this
  /// dashboard can load. Detected from a 404 on any section.
  bool get profileMissing => _profileMissing;

  /// True only before anything at all has arrived — the full-page shimmer.
  bool get isFirstLoad =>
      _statsState.isLoading &&
      _stats == CoachDashboardStats.empty &&
      _schedule.isEmpty &&
      _performers.isEmpty &&
      _enquiries.isEmpty;

  // ---------------------------------------------------------------------------
  // Loading
  // ---------------------------------------------------------------------------

  /// Loads all four sections at once.
  ///
  /// Awaited together rather than in sequence so the overview settles in the
  /// time of its slowest call, not the sum of four.
  Future<void> load() async {
    if (_disposed) return;

    _refreshing = _statsState.isReady;
    _profileMissing = false;
    _statsState = CoachViewState.loading;
    _scheduleState = CoachViewState.loading;
    _performersState = CoachViewState.loading;
    _enquiriesState = CoachViewState.loading;
    _notify();

    CoachLog.state('Overview loading');

    await Future.wait([
      _loadStats(),
      _loadSchedule(),
      _loadPerformers(),
      _loadEnquiries(),
    ]);

    _refreshing = false;
    CoachLog.state(
      'Overview ready — ${_schedule.length} sessions, '
      '${_performers.length} performers, $_enquiryTotal enquiries',
    );
    _notify();
  }

  Future<void> refresh() => load();

  Future<void> _loadStats() async {
    try {
      _stats = await _repository.getStats();
      _statsError = null;
      _statsState = CoachViewState.ready;
    } catch (e) {
      _statsError = _describe(e);
      _statsState = CoachViewState.failed;
      _noteProfileMissing(e);
      CoachLog.failure('Overview stats failed', error: e);
    }
  }

  Future<void> _loadSchedule() async {
    try {
      _schedule = await _repository.getTodaySchedule();
      _scheduleError = null;
      _scheduleState = CoachViewState.ready;
    } catch (e) {
      _scheduleError = _describe(e);
      _scheduleState = CoachViewState.failed;
      _noteProfileMissing(e);
      CoachLog.failure("Overview schedule failed", error: e);
    }
  }

  Future<void> _loadPerformers() async {
    try {
      _performers = await _repository.getTopPerformers();
      _performersError = null;
      _performersState = CoachViewState.ready;
    } catch (e) {
      _performersError = _describe(e);
      _performersState = CoachViewState.failed;
      _noteProfileMissing(e);
      CoachLog.failure('Overview performers failed', error: e);
    }
  }

  Future<void> _loadEnquiries() async {
    try {
      final page = await _repository.getEnquiries(
        page: 1,
        limit: enquiryPreviewLimit,
      );
      _enquiries = page.items;
      _enquiryTotal = page.total;
      _enquiriesError = null;
      _enquiriesState = CoachViewState.ready;
    } catch (e) {
      _enquiriesError = _describe(e);
      _enquiriesState = CoachViewState.failed;
      // Deliberately not fed to [_noteProfileMissing]: this is a different
      // route family (`/coaching-enquiries`), where a 404 means the enquiry
      // itself is missing, not the coach profile.
      CoachLog.failure('Overview enquiries failed', error: e);
    }
  }

  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------

  /// Logs a new enquiry, then reloads the preview and the stat tile that
  /// counts it.
  ///
  /// Throws on failure so the form can keep the sheet open and show why.
  Future<void> submitEnquiry(CoachEnquiryDraft draft) async {
    CoachLog.ui('Submitting enquiry for ${draft.name}');
    await _repository.createEnquiry(draft);

    // Only these two sections can have changed, so the schedule and the
    // performers are left alone.
    await Future.wait([_loadEnquiries(), _loadStats()]);
    _notify();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// A 404 from a `/coach/dashboard` route means "no Coach row for this
  /// account" — every route answers it the same way, so one is enough.
  void _noteProfileMissing(Object error) {
    if (error is NotFoundException) _profileMissing = true;
  }

  static String _describe(Object error) => error is ApiException
      ? error.message
      : 'Something went wrong. Please try again.';

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    CoachLog.life('CoachOverviewController disposed');
    super.dispose();
  }
}

/// The batch and sport pickers the Send Enquiry sheet needs.
///
/// Kept apart from [CoachOverviewController] because the options are only
/// fetched when the sheet actually opens — the overview should not pay for two
/// autocomplete calls on every load.
class CoachEnquiryFormController extends ChangeNotifier {
  CoachEnquiryFormController(this._repository);

  final CoachDashboardRepository _repository;

  CoachViewState _state = CoachViewState.idle;
  List<CoachOption> _batches = const [];
  List<CoachOption> _sports = const [];
  String? _error;
  bool _disposed = false;

  CoachViewState get state => _state;

  /// The coach's **Active** batches. A coach with none cannot file an enquiry
  /// at all, because `batchId` is required.
  List<CoachOption> get batches => _batches;

  /// Sports derived from those batches. Optional on the form.
  List<CoachOption> get sports => _sports;

  String? get error => _error;

  Future<void> load() async {
    if (_disposed) return;

    _state = CoachViewState.loading;
    _notify();

    try {
      final results = await Future.wait([
        _repository.searchBatches(),
        _repository.searchSports(),
      ]);
      _batches = results[0];
      _sports = results[1];
      _error = null;
      _state = CoachViewState.ready;
    } catch (e) {
      _error = e is ApiException
          ? e.message
          : 'Could not load your batches. Please try again.';
      _state = CoachViewState.failed;
      CoachLog.failure('Enquiry form options failed', error: e);
    }

    _notify();
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
