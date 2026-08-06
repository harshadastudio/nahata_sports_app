import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../models/sports_complex_model.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/coach.dart';
import '../../domain/entities/coaching_enquiry.dart';
import '../../domain/entities/paged.dart';
import '../../domain/entities/sport.dart';
import '../../domain/repositories/coaching_enquiry_repository.dart';
import 'view_state.dart';

/// Everything the Coaching Enquiries page needs: the paged queue, the stats
/// cards, debounced search, the status filter, the detail panel and the five
/// write operations.
///
/// The list is kept in [enquiries] rather than read straight off [page]
/// because the two layouts page differently: the desktop table jumps between
/// pages (each load replaces the rows) while the phone list scrolls infinitely
/// (each load appends). One accumulated list serves both.
class CoachingEnquiriesController extends ChangeNotifier {
  CoachingEnquiriesController(this._repository) {
    AdminLog.life('CoachingEnquiriesController created');
  }

  final CoachingEnquiryRepository _repository;

  static const Duration searchDebounce = Duration(milliseconds: 400);
  static const List<int> pageSizes = [10, 20, 50, 100];

  ViewState _state = ViewState.idle;
  Paged<CoachingEnquiry> _page = const Paged<CoachingEnquiry>();
  List<CoachingEnquiry> _enquiries = const [];
  String? _error;

  int _requestedPage = 1;
  int _limit = 20;
  String _search = '';
  CoachingEnquiryStatus? _statusFilter;

  Timer? _debounce;
  int _requestId = 0;
  bool _loadingMore = false;
  bool _disposed = false;

  CoachingEnquiry? _selected;
  ViewState _detailState = ViewState.idle;
  int _detailRequestId = 0;

  CoachingEnquiryStats _stats = const CoachingEnquiryStats();
  ViewState _statsState = ViewState.idle;

  List<Coach> _coaches = const [];
  ViewState _coachesState = ViewState.idle;

  List<Sport> _sports = const [];
  ViewState _sportsState = ViewState.idle;

  List<SportsComplex> _complexes = const [];
  ViewState _complexesState = ViewState.idle;

  // --- Reads -----------------------------------------------------------------

  ViewState get state => _state;
  Paged<CoachingEnquiry> get page => _page;
  List<CoachingEnquiry> get enquiries => _enquiries;
  String? get error => _error;

  int get limit => _limit;
  String get search => _search;
  CoachingEnquiryStatus? get statusFilter => _statusFilter;

  CoachingEnquiry? get selected => _selected;
  ViewState get detailState => _detailState;

  CoachingEnquiryStats get stats => _stats;
  ViewState get statsState => _statsState;

  List<Coach> get coaches => _coaches;
  ViewState get coachesState => _coachesState;

  List<Sport> get sports => _sports;
  ViewState get sportsState => _sportsState;

  List<SportsComplex> get complexes => _complexes;
  ViewState get complexesState => _complexesState;

  bool get hasFilters => _search.trim().isNotEmpty || _statusFilter != null;
  bool get isFirstLoad => _state.isLoading && _enquiries.isEmpty;
  bool get isRefreshing => _state.isLoading && _enquiries.isNotEmpty;
  bool get isLoadingMore => _loadingMore;
  bool get hasMore => _page.hasNext;

  // --- Loading ---------------------------------------------------------------

  /// Loads a page. [append] adds to the rows already on screen (infinite
  /// scroll); otherwise it replaces them (table paging, search, refresh).
  Future<void> load({int? page, bool append = false}) async {
    final target = page ?? _requestedPage;

    // A second request for the same append would duplicate rows.
    if (append && _loadingMore) return;

    final id = ++_requestId;

    AdminLog.state(
      'Coaching enquiries loading → page=$target limit=$_limit '
      'search="${_search.trim()}" status=${_statusFilter?.slug ?? 'any'} '
      'append=$append',
    );

    _requestedPage = target;
    _state = ViewState.loading;
    _loadingMore = append;
    _error = null;
    _safeNotify();

    try {
      final result = await _repository.getEnquiries(
        page: target,
        limit: _limit,
        search: _search.trim().isEmpty ? null : _search.trim(),
        status: _statusFilter,
      );

      if (_disposed || id != _requestId) {
        AdminLog.state('Coaching enquiries response superseded — dropped');
        return;
      }

      _page = result;
      _requestedPage = result.page;
      _enquiries = append
          ? _mergeById(_enquiries, result.items)
          : List<CoachingEnquiry>.unmodifiable(result.items);
      _state = ViewState.ready;

      AdminLog.state(
        'Coaching enquiries ready → ${result.items.length} rows '
        '(${_enquiries.length} on screen), page ${result.page}/'
        '${result.effectiveTotalPages}',
      );
    } on ApiException catch (error) {
      if (_disposed || id != _requestId) return;
      _state = ViewState.failed;
      _error = error.message;
      AdminLog.failure(
        'Coaching enquiries load failed: ${error.message}',
        error: error,
      );
    } catch (error, stackTrace) {
      if (_disposed || id != _requestId) return;
      _state = ViewState.failed;
      _error = 'Could not load coaching enquiries. Please try again.';
      AdminLog.failure(
        'Coaching enquiries load crashed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      if (!_disposed && id == _requestId) _loadingMore = false;
      _safeNotify();
    }
  }

  /// Pull-to-refresh and the toolbar's Refresh: the queue and its counters
  /// move together, so both are re-read.
  Future<void> refresh() {
    AdminLog.ui('Coaching enquiries refresh requested');
    return Future.wait<void>([
      load(page: 1),
      loadStats(refresh: true),
    ]).then((_) {});
  }

  /// The next page, appended. Called from the phone list's scroll listener, so
  /// it must be cheap and idempotent when there is nothing more to fetch.
  Future<void> loadMore() {
    if (_loadingMore || _state.isLoading || !_page.hasNext) {
      return Future<void>.value();
    }
    AdminLog.ui('Coaching enquiries infinite scroll → page ${_page.page + 1}');
    return load(page: _page.page + 1, append: true);
  }

  /// `GET /coaching-enquiries/stats`. Cached after the first call unless
  /// [refresh] is set; a failure leaves the previous numbers on screen.
  Future<void> loadStats({bool refresh = false}) async {
    if (_statsState.isLoading) return;
    if (!_stats.isEmpty && !refresh) return;

    _statsState = ViewState.loading;
    _safeNotify();

    try {
      final result = await _repository.getStats();
      if (_disposed) return;
      _stats = result;
      _statsState = ViewState.ready;
      AdminLog.state('Enquiry stats ready → $result');
    } catch (error, stackTrace) {
      if (_disposed) return;
      _statsState = ViewState.failed;
      AdminLog.failure(
        'Enquiry stats failed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _safeNotify();
    }
  }

  /// The option lists the create form and the assign dialog need.
  Future<void> loadFormOptions({bool refresh = false}) async {
    await Future.wait<void>([
      loadSports(refresh: refresh),
      loadComplexes(refresh: refresh),
    ]);
  }

  Future<void> loadCoaches({bool refresh = false, int? sportId}) async {
    if (_coachesState.isLoading) return;
    if (_coaches.isNotEmpty && !refresh) return;

    _coachesState = ViewState.loading;
    _safeNotify();

    try {
      final result = await _repository.fetchCoaches(
        refresh: refresh,
        sportId: sportId,
      );
      if (_disposed) return;
      _coaches = result;
      _coachesState = ViewState.ready;
      AdminLog.state('Coaches for enquiries ready → ${result.length}');
    } catch (error, stackTrace) {
      if (_disposed) return;
      _coachesState = ViewState.failed;
      AdminLog.failure(
        'Coaches for enquiries failed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _safeNotify();
    }
  }

  Future<void> loadSports({bool refresh = false}) async {
    if (_sportsState.isLoading) return;
    if (_sports.isNotEmpty && !refresh) return;

    _sportsState = ViewState.loading;
    _safeNotify();

    try {
      final result = await _repository.fetchSports(refresh: refresh);
      if (_disposed) return;
      _sports = result;
      _sportsState = ViewState.ready;
      AdminLog.state('Sports for enquiries ready → ${result.length}');
    } catch (error, stackTrace) {
      if (_disposed) return;
      _sportsState = ViewState.failed;
      AdminLog.failure(
        'Sports for enquiries failed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _safeNotify();
    }
  }

  Future<void> loadComplexes({bool refresh = false}) async {
    if (_complexesState.isLoading) return;
    if (_complexes.isNotEmpty && !refresh) return;

    _complexesState = ViewState.loading;
    _safeNotify();

    try {
      final result = await _repository.fetchSportComplexes(refresh: refresh);
      if (_disposed) return;
      _complexes = result;
      _complexesState = ViewState.ready;
      AdminLog.state('Complexes for enquiries ready → ${result.length}');
    } catch (error, stackTrace) {
      if (_disposed) return;
      _complexesState = ViewState.failed;
      AdminLog.failure(
        'Complexes for enquiries failed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _safeNotify();
    }
  }

  // --- Search / filter / paging ----------------------------------------------

  void onSearchChanged(String value) {
    if (_search == value) return;
    _search = value;
    AdminLog.ui(
      'Enquiry search typed: "$value" '
      '(debouncing ${searchDebounce.inMilliseconds}ms)',
    );
    notifyListeners();

    _debounce?.cancel();
    _debounce = Timer(searchDebounce, () {
      AdminLog.ui('Enquiry search settled: "${_search.trim()}"');
      load(page: 1);
    });
  }

  void clearSearch() {
    if (_search.isEmpty) return;
    AdminLog.ui('Enquiry search cleared');
    _debounce?.cancel();
    _search = '';
    load(page: 1);
  }

  /// Filters the queue by state. Passing the state that is already selected
  /// clears it, so the stat cards toggle.
  void setStatusFilter(CoachingEnquiryStatus? status) {
    final next = _statusFilter == status ? null : status;
    if (_statusFilter == next) return;
    AdminLog.ui('Enquiry status filter → ${next?.slug ?? 'any'}');
    _statusFilter = next;
    load(page: 1);
  }

  void clearFilters() {
    if (!hasFilters) return;
    AdminLog.ui('Enquiry filters cleared');
    _debounce?.cancel();
    _search = '';
    _statusFilter = null;
    load(page: 1);
  }

  void setLimit(int limit) {
    if (_limit == limit) return;
    AdminLog.ui('Enquiry page size → $limit');
    _limit = limit;
    load(page: 1);
  }

  void goToPage(int page) {
    final total = _page.effectiveTotalPages;
    final target = total > 0 ? page.clamp(1, total) : page;
    if (target == _page.page && _state.isReady) return;
    AdminLog.ui('Coaching enquiries go to page $target');
    load(page: target);
  }

  // --- Detail ----------------------------------------------------------------

  /// Opens the panel on the row immediately, then fetches the full record —
  /// the list row does not carry the message, the remarks or the assigned
  /// coach.
  void select(CoachingEnquiry enquiry) {
    AdminLog.ui('Enquiry detail opened for ${enquiry.id}');
    _selected = enquiry;
    _detailState = ViewState.loading;
    _safeNotify();
    unawaited(_refreshDetail(enquiry.id));
  }

  Future<void> _refreshDetail(int id) async {
    if (id <= 0) {
      _detailState = ViewState.ready;
      _safeNotify();
      return;
    }

    final request = ++_detailRequestId;

    try {
      final full = await _repository.getEnquiry(id);
      if (_disposed || request != _detailRequestId) return;
      if (_selected?.id != id) return;

      _selected = full;
      _detailState = ViewState.ready;
      _replaceRow(full);
      AdminLog.state('Enquiry detail ready → $full');
    } catch (error) {
      if (_disposed || request != _detailRequestId) return;
      // The row already on screen stays visible; only the fields the detail
      // call would have added are missing.
      _detailState = ViewState.failed;
      AdminLog.failure('Enquiry detail failed for $id', error: error);
    } finally {
      _safeNotify();
    }
  }

  /// Re-reads the open enquiry — used after a write that the route did not
  /// echo a full record for.
  Future<void> reloadSelected() {
    final current = _selected;
    if (current == null) return Future<void>.value();
    _detailState = ViewState.loading;
    _safeNotify();
    return _refreshDetail(current.id);
  }

  void clearSelection() {
    if (_selected == null) return;
    AdminLog.ui('Enquiry detail closed');
    _selected = null;
    _detailState = ViewState.idle;
    _safeNotify();
  }

  // --- Writes ----------------------------------------------------------------

  /// `POST /coaching-enquiries`, then back to page one so the new enquiry is
  /// visible, with the counters brought along.
  Future<CoachingEnquiry> create(CoachingEnquiryDraft draft) async {
    AdminLog.ui('Create coaching enquiry submitted');
    final created = await _repository.createEnquiry(draft);
    await load(page: 1);
    unawaited(loadStats(refresh: true));
    return created;
  }

  /// `PUT /coaching-enquiries/{id}` — status and remarks together.
  Future<CoachingEnquiry> update(int id, CoachingEnquiryUpdate change) async {
    AdminLog.ui('Update enquiry $id submitted');
    final updated = await _repository.updateEnquiry(id, change);
    await _afterWrite(id, updated, statusChanged: change.status != null);
    return updated;
  }

  /// `PATCH /coaching-enquiries/{id}/status`.
  Future<CoachingEnquiry> changeStatus({
    required int id,
    required CoachingEnquiryStatus status,
  }) async {
    AdminLog.ui('Enquiry $id status → ${status.slug}');

    // Optimistic: the badge moves the moment the desk confirms, and is put
    // back if the server refuses.
    final previous = _rowFor(id);
    if (previous != null) {
      _replaceRow(previous.copyWith(statusRaw: status.slug));
      if (_selected?.id == id) {
        _selected = _selected!.copyWith(statusRaw: status.slug);
      }
      _safeNotify();
    }

    try {
      final updated = await _repository.updateStatus(id: id, status: status);
      await _afterWrite(id, updated, statusChanged: true);
      return updated;
    } catch (error) {
      if (previous != null) {
        AdminLog.failure('Status change refused — rolling the row back');
        _replaceRow(previous);
        if (_selected?.id == id) _selected = previous;
        _safeNotify();
      }
      rethrow;
    }
  }

  /// `PATCH /coaching-enquiries/{id}/assign-coach`.
  Future<CoachingEnquiry> assignCoach({
    required int id,
    required Coach coach,
  }) async {
    AdminLog.ui('Assign coach ${coach.id} to enquiry $id');
    final updated = await _repository.assignCoach(id: id, coachId: coach.id);

    // The assign route is documented without a response body, so the coach's
    // name is filled in from the one that was picked rather than left blank
    // until the re-read lands.
    final resolved = updated.assignedCoachId == null
        ? updated.copyWith(
            assignedCoachId: coach.id,
            assignedCoachName: coach.name,
          )
        : updated;

    await _afterWrite(id, resolved, statusChanged: false);
    return resolved;
  }

  Future<void> delete(int id) async {
    AdminLog.ui('Delete enquiry $id confirmed');

    // Optimistic: the row goes immediately, and comes back if the call fails.
    final previous = _enquiries;
    final index = previous.indexWhere((enquiry) => enquiry.id == id);
    if (index >= 0) {
      _enquiries = List<CoachingEnquiry>.unmodifiable(
        [...previous]..removeAt(index),
      );
      _safeNotify();
    }

    try {
      await _repository.deleteEnquiry(id);
    } catch (error) {
      if (index >= 0) {
        AdminLog.failure('Delete refused — putting the row back');
        _enquiries = previous;
        _safeNotify();
      }
      rethrow;
    }

    if (_selected?.id == id) clearSelection();
    unawaited(loadStats(refresh: true));

    // Removing the last row of a page would otherwise strand an empty page.
    final wasLastRowOnPage = _enquiries.isEmpty && _page.page > 1;
    await load(page: wasLastRowOnPage ? _page.page - 1 : _page.page);
  }

  /// Common tail for the three write routes: patch the row, re-point the open
  /// panel, and only re-read what actually changed.
  Future<void> _afterWrite(
    int id,
    CoachingEnquiry updated, {
    required bool statusChanged,
  }) async {
    // A route that echoed nothing gives back a stub carrying only the id —
    // merging that over a loaded row would blank it.
    final merged = _merge(_rowFor(id), updated);
    if (merged != null) _replaceRow(merged);

    if (_selected?.id == id) {
      _selected = merged ?? updated;
      _safeNotify();
      // The panel shows fields the write routes do not return, so it is
      // re-read; the list is not, because the row above is already correct.
      await _refreshDetail(id);
    } else {
      _safeNotify();
    }

    // Only a status change moves the counters.
    if (statusChanged) unawaited(loadStats(refresh: true));
  }

  // --- Helpers ---------------------------------------------------------------

  CoachingEnquiry? _rowFor(int id) {
    for (final enquiry in _enquiries) {
      if (enquiry.id == id) return enquiry;
    }
    if (_selected?.id == id) return _selected;
    return null;
  }

  /// Lays [incoming] over [existing], keeping whatever the write response did
  /// not carry.
  static CoachingEnquiry? _merge(
    CoachingEnquiry? existing,
    CoachingEnquiry incoming,
  ) {
    if (existing == null) return incoming.id > 0 ? incoming : null;

    return existing.copyWith(
      name: incoming.name,
      phone: incoming.phone,
      email: incoming.email,
      message: incoming.message,
      statusRaw: incoming.statusRaw,
      remarks: incoming.remarks,
      sportId: incoming.sportId,
      sportName: incoming.sportName,
      sportComplexId: incoming.sportComplexId,
      sportComplexName: incoming.sportComplexName,
      assignedCoachId: incoming.assignedCoachId,
      assignedCoachName: incoming.assignedCoachName,
      updatedAt: incoming.updatedAt,
    );
  }

  void _replaceRow(CoachingEnquiry updated) {
    var changed = false;
    final next = _enquiries
        .map((enquiry) {
          if (enquiry.id != updated.id) return enquiry;
          changed = true;
          return updated;
        })
        .toList(growable: false);

    if (!changed) return;
    _enquiries = List<CoachingEnquiry>.unmodifiable(next);
  }

  /// Appends [incoming], skipping rows already on screen.
  ///
  /// A page boundary that shifts between requests (an enquiry logged while the
  /// desk is scrolling) would otherwise show the same row twice.
  static List<CoachingEnquiry> _mergeById(
    List<CoachingEnquiry> existing,
    List<CoachingEnquiry> incoming,
  ) {
    final seen = existing.map((enquiry) => enquiry.id).toSet();
    final merged = <CoachingEnquiry>[...existing];
    for (final enquiry in incoming) {
      if (seen.add(enquiry.id)) merged.add(enquiry);
    }
    return List<CoachingEnquiry>.unmodifiable(merged);
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    AdminLog.life('CoachingEnquiriesController disposed');
    super.dispose();
  }
}
