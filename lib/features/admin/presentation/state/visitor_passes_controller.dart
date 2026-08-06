import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/storage/profile_cache.dart';
import '../../../../models/sports_complex_model.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/admin_role.dart';
import '../../domain/entities/paged.dart';
import '../../domain/entities/visitor_pass.dart';
import '../../domain/repositories/visitor_pass_repository.dart';
import 'view_state.dart';

/// Everything the Visitor Passes page needs: the paged list, debounced search,
/// the detail panel, and the six write/read operations behind the module.
///
/// The list is kept in [passes] rather than read straight off [page] because
/// the two layouts page differently: the desktop table jumps between pages
/// (each load replaces the rows) while the phone list scrolls infinitely (each
/// load appends). One accumulated list serves both, and both read the same
/// counters out of [page].
class VisitorPassesController extends ChangeNotifier {
  VisitorPassesController(this._repository) {
    AdminLog.life('VisitorPassesController created');
  }

  final VisitorPassRepository _repository;

  static const Duration searchDebounce = Duration(milliseconds: 400);
  static const List<int> pageSizes = [10, 20, 50, 100];

  /// The roles the module documents as allowed to delete a pass.
  static const Set<AdminRole> deleteRoles = {
    AdminRole.admin,
    AdminRole.complexAdmin,
  };

  ViewState _state = ViewState.idle;
  Paged<VisitorPass> _page = const Paged<VisitorPass>();
  List<VisitorPass> _passes = const [];
  String? _error;

  int _requestedPage = 1;
  int _limit = 20;
  String _search = '';

  Timer? _debounce;
  int _requestId = 0;
  bool _loadingMore = false;
  bool _disposed = false;

  VisitorPass? _selected;
  ViewState _detailState = ViewState.idle;
  int _detailRequestId = 0;

  List<SportsComplex> _complexes = const [];
  ViewState _complexesState = ViewState.idle;

  AdminRole? _role;
  bool _roleLoaded = false;

  // --- Reads -----------------------------------------------------------------

  ViewState get state => _state;
  Paged<VisitorPass> get page => _page;
  List<VisitorPass> get passes => _passes;
  String? get error => _error;

  int get limit => _limit;
  String get search => _search;

  VisitorPass? get selected => _selected;
  ViewState get detailState => _detailState;

  List<SportsComplex> get complexes => _complexes;
  ViewState get complexesState => _complexesState;

  bool get hasFilters => _search.trim().isNotEmpty;
  bool get isFirstLoad => _state.isLoading && _passes.isEmpty;
  bool get isRefreshing => _state.isLoading && _passes.isNotEmpty;

  /// True while the next page is being appended under an infinite scroll.
  bool get isLoadingMore => _loadingMore;

  bool get hasMore => _page.hasNext;

  /// Whether this account may delete a pass. Until the role is known the
  /// action is hidden — showing a button that is guaranteed to 403 is worse
  /// than not showing it.
  bool get canDelete => _role != null && deleteRoles.contains(_role);

  bool get roleLoaded => _roleLoaded;

  AdminRole? get role => _role;

  // --- Loading ---------------------------------------------------------------

  /// Loads a page. [append] adds to the rows already on screen (infinite
  /// scroll); otherwise it replaces them (table paging, search, refresh).
  Future<void> load({int? page, bool append = false}) async {
    final target = page ?? _requestedPage;

    // A second request for the same append would duplicate rows.
    if (append && _loadingMore) return;

    final id = ++_requestId;

    AdminLog.state(
      'Visitor passes loading → page=$target limit=$_limit '
      'search="${_search.trim()}" append=$append',
    );

    _requestedPage = target;
    _state = ViewState.loading;
    _loadingMore = append;
    _error = null;
    _safeNotify();

    try {
      final result = await _repository.fetchVisitorPasses(
        page: target,
        limit: _limit,
        search: _search.trim().isEmpty ? null : _search.trim(),
      );

      if (_disposed || id != _requestId) {
        AdminLog.state('Visitor passes response superseded — dropped');
        return;
      }

      _page = result;
      _requestedPage = result.page;
      _passes = append
          ? _mergeById(_passes, result.items)
          : List<VisitorPass>.unmodifiable(result.items);
      _state = ViewState.ready;

      AdminLog.state(
        'Visitor passes ready → ${result.items.length} rows '
        '(${_passes.length} on screen), page ${result.page}/'
        '${result.effectiveTotalPages}',
      );
    } on ApiException catch (error) {
      if (_disposed || id != _requestId) return;
      _state = ViewState.failed;
      _error = error.message;
      AdminLog.failure(
        'Visitor passes load failed: ${error.message}',
        error: error,
      );
    } catch (error, stackTrace) {
      if (_disposed || id != _requestId) return;
      _state = ViewState.failed;
      _error = 'Could not load visitor passes. Please try again.';
      AdminLog.failure(
        'Visitor passes load crashed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      if (!_disposed && id == _requestId) _loadingMore = false;
      _safeNotify();
    }
  }

  /// Pull-to-refresh and the toolbar's Refresh: back to page one, rows
  /// replaced.
  Future<void> refresh() {
    AdminLog.ui('Visitor passes refresh requested');
    return load(page: 1);
  }

  /// The next page, appended. Called from the phone list's scroll listener, so
  /// it must be cheap and idempotent when there is nothing more to fetch.
  Future<void> loadMore() {
    if (_loadingMore || _state.isLoading || !_page.hasNext) {
      return Future<void>.value();
    }
    AdminLog.ui('Visitor passes infinite scroll → page ${_page.page + 1}');
    return load(page: _page.page + 1, append: true);
  }

  /// Venues for the create form. Cached after the first call unless [refresh].
  Future<void> loadComplexes({bool refresh = false}) async {
    if (_complexesState.isLoading) return;
    if (_complexes.isNotEmpty && !refresh) return;

    AdminLog.state(
      'Sport complexes loading for visitor passes '
      '(refresh: $refresh)',
    );
    _complexesState = ViewState.loading;
    _safeNotify();

    try {
      final result = await _repository.fetchSportComplexes(refresh: refresh);
      if (_disposed) return;
      _complexes = result;
      _complexesState = ViewState.ready;
      AdminLog.state('Sport complexes ready → ${result.length}');
    } catch (error, stackTrace) {
      if (_disposed) return;
      _complexesState = ViewState.failed;
      AdminLog.failure(
        'Sport complexes failed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _safeNotify();
    }
  }

  /// Reads the signed-in role out of the profile cache, to decide whether the
  /// Delete action is offered at all.
  Future<void> loadRole() async {
    if (_roleLoaded) return;

    try {
      final profile = await ProfileCache.instance.read();
      if (_disposed) return;
      _role = AdminRole.tryParse(profile?.role);
      AdminLog.state('Visitor passes role → ${_role?.slug ?? 'unknown'}');
    } catch (error) {
      if (_disposed) return;
      AdminLog.failure('Could not read the signed-in role', error: error);
    } finally {
      _roleLoaded = true;
      _safeNotify();
    }
  }

  // --- Search / paging -------------------------------------------------------

  void onSearchChanged(String value) {
    if (_search == value) return;
    _search = value;
    AdminLog.ui(
      'Visitor pass search typed: "$value" '
      '(debouncing ${searchDebounce.inMilliseconds}ms)',
    );
    notifyListeners();

    _debounce?.cancel();
    _debounce = Timer(searchDebounce, () {
      AdminLog.ui('Visitor pass search settled: "${_search.trim()}"');
      load(page: 1);
    });
  }

  void clearSearch() {
    if (_search.isEmpty) return;
    AdminLog.ui('Visitor pass search cleared');
    _debounce?.cancel();
    _search = '';
    load(page: 1);
  }

  void setLimit(int limit) {
    if (_limit == limit) return;
    AdminLog.ui('Visitor pass page size → $limit');
    _limit = limit;
    load(page: 1);
  }

  void goToPage(int page) {
    final total = _page.effectiveTotalPages;
    final target = total > 0 ? page.clamp(1, total) : page;
    if (target == _page.page && _state.isReady) return;
    AdminLog.ui('Visitor passes go to page $target');
    load(page: target);
  }

  // --- Detail ----------------------------------------------------------------

  /// Opens the panel on the row immediately, then fetches the full record —
  /// the list row may not carry the QR, the entry time or the exit time.
  void select(VisitorPass pass) {
    AdminLog.ui('Visitor pass detail opened for ${pass.reference}');
    _selected = pass;
    _detailState = ViewState.loading;
    _safeNotify();
    unawaited(_refreshDetail(pass));
  }

  Future<void> _refreshDetail(VisitorPass pass) async {
    if (!pass.hasReference) {
      _detailState = ViewState.ready;
      _safeNotify();
      return;
    }

    final id = ++_detailRequestId;

    try {
      final full = await _repository.fetchVisitorPass(pass.reference);
      if (_disposed || id != _detailRequestId) return;
      if (_selected?.key != pass.key) return;

      _selected = full;
      _detailState = ViewState.ready;
      _replaceRow(full);
      AdminLog.state('Visitor pass detail ready → $full');
    } catch (error) {
      if (_disposed || id != _detailRequestId) return;
      // The row already on screen stays visible; only the fields the detail
      // call would have added are missing.
      _detailState = ViewState.failed;
      AdminLog.failure(
        'Visitor pass detail failed for ${pass.reference}',
        error: error,
      );
    } finally {
      _safeNotify();
    }
  }

  /// Re-reads the open pass — used after a scan changes its status.
  Future<void> reloadSelected() {
    final current = _selected;
    if (current == null) return Future<void>.value();
    _detailState = ViewState.loading;
    _safeNotify();
    return _refreshDetail(current);
  }

  void clearSelection() {
    if (_selected == null) return;
    AdminLog.ui('Visitor pass detail closed');
    _selected = null;
    _detailState = ViewState.idle;
    _safeNotify();
  }

  // --- Writes ----------------------------------------------------------------

  /// `POST /visitor-passes`, then back to page one so the new pass is visible.
  Future<VisitorPass> create(VisitorPassDraft draft) async {
    AdminLog.ui('Create visitor pass submitted');
    final created = await _repository.createVisitorPass(draft);
    await load(page: 1);
    return created;
  }

  /// `POST /visitor-passes/verify` — the IN or OUT leg.
  ///
  /// A refusal comes back as a result, so the caller always has something to
  /// show. On success the row is patched in place rather than re-fetched: the
  /// scanner is used at a gate, and a full reload there is latency for nothing.
  Future<VisitorPassCheck> verify({
    required String passCode,
    required VisitorScanType scanType,
  }) async {
    AdminLog.ui('Verify ${scanType.slug} for $passCode');
    final result = await _repository.verifyPass(
      passCode: passCode,
      scanType: scanType,
    );

    final updated = result.pass;
    if (result.success && updated != null) {
      _replaceRow(updated);
      if (_selected != null && _sameRecord(_selected!, updated)) {
        _selected = updated;
      }
      _safeNotify();
    }

    return result;
  }

  /// `POST /visitor-passes/lookup` — never changes anything.
  Future<VisitorPassCheck> lookup(String passCode) {
    AdminLog.ui('Lookup $passCode');
    return _repository.lookupPass(passCode);
  }

  Future<String> sendEmail({
    required VisitorPass pass,
    required String recipientEmail,
    required String recipientName,
  }) {
    AdminLog.ui('Email visitor pass ${pass.reference} to $recipientEmail');
    return _repository.sendPassEmail(
      idOrCode: pass.reference,
      recipientEmail: recipientEmail,
      recipientName: recipientName,
    );
  }

  Future<void> delete(VisitorPass pass) async {
    AdminLog.ui('Delete visitor pass ${pass.reference} confirmed');
    await _repository.deleteVisitorPass(pass.reference);

    if (_selected != null && _sameRecord(_selected!, pass)) clearSelection();

    // Removing the last row of a page would otherwise strand an empty page.
    final wasLastRowOnPage = _passes.length == 1 && _page.page > 1;
    await load(page: wasLastRowOnPage ? _page.page - 1 : _page.page);
  }

  // --- Helpers ---------------------------------------------------------------

  /// Swaps a row for its updated copy, leaving the list untouched when the row
  /// is not on screen.
  void _replaceRow(VisitorPass updated) {
    var changed = false;
    final next = _passes
        .map((pass) {
          if (!_sameRecord(pass, updated)) return pass;
          changed = true;
          return updated;
        })
        .toList(growable: false);

    if (!changed) return;
    _passes = List<VisitorPass>.unmodifiable(next);
  }

  /// Appends [incoming], skipping rows already on screen.
  ///
  /// A page boundary that shifts between requests (a pass created while the
  /// desk is scrolling) would otherwise show the same pass twice.
  static List<VisitorPass> _mergeById(
    List<VisitorPass> existing,
    List<VisitorPass> incoming,
  ) {
    final seen = existing.map((pass) => pass.key).toSet();
    final merged = <VisitorPass>[...existing];
    for (final pass in incoming) {
      if (seen.add(pass.key)) merged.add(pass);
    }
    return List<VisitorPass>.unmodifiable(merged);
  }

  static bool _sameRecord(VisitorPass a, VisitorPass b) {
    if (a.id > 0 && b.id > 0) return a.id == b.id;
    final left = (a.passCode ?? '').trim();
    final right = (b.passCode ?? '').trim();
    if (left.isNotEmpty && right.isNotEmpty) return left == right;
    return a.key == b.key;
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    AdminLog.life('VisitorPassesController disposed');
    super.dispose();
  }
}
