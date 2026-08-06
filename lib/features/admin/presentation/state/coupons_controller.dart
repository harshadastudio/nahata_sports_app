import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/storage/profile_cache.dart';
import '../../../../models/sports_complex_model.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/admin_role.dart';
import '../../domain/entities/coupon.dart';
import '../../domain/entities/event_pass.dart';
import '../../domain/entities/paged.dart';
import '../../domain/entities/sport.dart';
import '../../domain/repositories/coupons_repository.dart';
import 'view_state.dart';

/// Everything the Coupons page needs: the paged list, debounced search, the
/// detail panel, the form's option lists, the four write operations and the
/// checkout validator.
///
/// The list is kept in [coupons] rather than read straight off [page] because
/// the two layouts page differently: the desktop table jumps between pages
/// (each load replaces the rows) while the phone list scrolls infinitely (each
/// load appends). One accumulated list serves both.
class CouponsController extends ChangeNotifier {
  CouponsController(this._repository) {
    AdminLog.life('CouponsController created');
  }

  final CouponsRepository _repository;

  static const Duration searchDebounce = Duration(milliseconds: 400);
  static const List<int> pageSizes = [10, 20, 50, 100];

  ViewState _state = ViewState.idle;
  Paged<AdminCoupon> _page = const Paged<AdminCoupon>();
  List<AdminCoupon> _coupons = const [];
  String? _error;

  int _requestedPage = 1;
  int _limit = 20;
  String _search = '';

  Timer? _debounce;
  int _requestId = 0;
  bool _loadingMore = false;
  bool _disposed = false;

  AdminCoupon? _selected;
  ViewState _detailState = ViewState.idle;
  int _detailRequestId = 0;

  List<SportsComplex> _complexes = const [];
  ViewState _complexesState = ViewState.idle;

  List<Sport> _sports = const [];
  ViewState _sportsState = ViewState.idle;

  List<AdminEventPass> _events = const [];
  ViewState _eventsState = ViewState.idle;

  AdminRole? _role;
  int? _ownComplexId;
  bool _roleLoaded = false;

  // --- Reads -----------------------------------------------------------------

  ViewState get state => _state;
  Paged<AdminCoupon> get page => _page;
  List<AdminCoupon> get coupons => _coupons;
  String? get error => _error;

  int get limit => _limit;
  String get search => _search;

  AdminCoupon? get selected => _selected;
  ViewState get detailState => _detailState;

  List<SportsComplex> get complexes => _complexes;
  ViewState get complexesState => _complexesState;

  List<Sport> get sports => _sports;
  ViewState get sportsState => _sportsState;

  List<AdminEventPass> get events => _events;
  ViewState get eventsState => _eventsState;

  bool get hasFilters => _search.trim().isNotEmpty;
  bool get isFirstLoad => _state.isLoading && _coupons.isEmpty;
  bool get isRefreshing => _state.isLoading && _coupons.isNotEmpty;
  bool get isLoadingMore => _loadingMore;
  bool get hasMore => _page.hasNext;

  AdminRole? get role => _role;
  bool get roleLoaded => _roleLoaded;

  /// A complex admin manages one venue's court coupons and nothing else, so
  /// the form locks the scope and the venue for them rather than offering
  /// choices the server would refuse.
  bool get isComplexScoped => _role == AdminRole.complexAdmin;

  /// The venue a complex admin is bound to, when the profile carries it.
  int? get ownComplexId => _ownComplexId;

  /// The scopes this account may issue coupons for.
  List<CouponAppliesTo> get allowedScopes =>
      isComplexScoped ? const [CouponAppliesTo.court] : CouponAppliesTo.values;

  /// The venue list a form should offer — one entry for a complex admin.
  List<SportsComplex> get selectableComplexes {
    final own = _ownComplexId;
    if (!isComplexScoped || own == null) return _complexes;
    final scoped = _complexes.where((complex) => complex.id == own).toList();
    // If the catalogue does not cover their venue, offering nothing would make
    // the form unusable — the full list is better than a dead end.
    return scoped.isEmpty ? _complexes : scoped;
  }

  // --- Loading ---------------------------------------------------------------

  /// Loads a page. [append] adds to the rows already on screen (infinite
  /// scroll); otherwise it replaces them (table paging, search, refresh).
  Future<void> load({int? page, bool append = false}) async {
    final target = page ?? _requestedPage;

    // A second request for the same append would duplicate rows.
    if (append && _loadingMore) return;

    final id = ++_requestId;

    AdminLog.state(
      'Coupons loading → page=$target limit=$_limit '
      'search="${_search.trim()}" append=$append',
    );

    _requestedPage = target;
    _state = ViewState.loading;
    _loadingMore = append;
    _error = null;
    _safeNotify();

    try {
      final result = await _repository.getCoupons(
        page: target,
        limit: _limit,
        search: _search.trim().isEmpty ? null : _search.trim(),
      );

      if (_disposed || id != _requestId) {
        AdminLog.state('Coupons response superseded — dropped');
        return;
      }

      _page = result;
      _requestedPage = result.page;
      _coupons = append
          ? _mergeById(_coupons, result.items)
          : List<AdminCoupon>.unmodifiable(result.items);
      _state = ViewState.ready;

      AdminLog.state(
        'Coupons ready → ${result.items.length} rows '
        '(${_coupons.length} on screen), page ${result.page}/'
        '${result.effectiveTotalPages}',
      );
    } on ApiException catch (error) {
      if (_disposed || id != _requestId) return;
      _state = ViewState.failed;
      _error = error.message;
      AdminLog.failure('Coupons load failed: ${error.message}', error: error);
    } catch (error, stackTrace) {
      if (_disposed || id != _requestId) return;
      _state = ViewState.failed;
      _error = 'Could not load coupons. Please try again.';
      AdminLog.failure(
        'Coupons load crashed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      if (!_disposed && id == _requestId) _loadingMore = false;
      _safeNotify();
    }
  }

  Future<void> refresh() {
    AdminLog.ui('Coupons refresh requested');
    return load(page: 1);
  }

  /// The next page, appended. Called from the phone list's scroll listener, so
  /// it must be cheap and idempotent when there is nothing more to fetch.
  Future<void> loadMore() {
    if (_loadingMore || _state.isLoading || !_page.hasNext) {
      return Future<void>.value();
    }
    AdminLog.ui('Coupons infinite scroll → page ${_page.page + 1}');
    return load(page: _page.page + 1, append: true);
  }

  /// The three option lists the form needs. Cached after the first call unless
  /// [refresh] is set.
  Future<void> loadFormOptions({bool refresh = false}) async {
    await Future.wait<void>([
      loadComplexes(refresh: refresh),
      loadSports(refresh: refresh),
      loadEvents(refresh: refresh),
    ]);
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
      AdminLog.state('Complexes for coupons ready → ${result.length}');
    } catch (error, stackTrace) {
      if (_disposed) return;
      _complexesState = ViewState.failed;
      AdminLog.failure(
        'Complexes for coupons failed',
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
      AdminLog.state('Sports for coupons ready → ${result.length}');
    } catch (error, stackTrace) {
      if (_disposed) return;
      _sportsState = ViewState.failed;
      AdminLog.failure(
        'Sports for coupons failed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _safeNotify();
    }
  }

  Future<void> loadEvents({bool refresh = false}) async {
    if (_eventsState.isLoading) return;
    if (_events.isNotEmpty && !refresh) return;

    _eventsState = ViewState.loading;
    _safeNotify();

    try {
      final result = await _repository.fetchEventPasses(refresh: refresh);
      if (_disposed) return;
      _events = result;
      _eventsState = ViewState.ready;
      AdminLog.state('Events for coupons ready → ${result.length}');
    } catch (error, stackTrace) {
      if (_disposed) return;
      _eventsState = ViewState.failed;
      AdminLog.failure(
        'Events for coupons failed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _safeNotify();
    }
  }

  /// Reads the signed-in role and venue out of the profile cache, so the form
  /// can hold a complex admin to their own venue's court coupons.
  Future<void> loadRole() async {
    if (_roleLoaded) return;

    try {
      final profile = await ProfileCache.instance.read();
      if (_disposed) return;
      _role = AdminRole.tryParse(profile?.role);
      _ownComplexId = profile?.sportComplexId;
      AdminLog.state(
        'Coupons role → ${_role?.slug ?? 'unknown'} '
        '(complex ${_ownComplexId ?? '-'})',
      );
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
      'Coupon search typed: "$value" '
      '(debouncing ${searchDebounce.inMilliseconds}ms)',
    );
    notifyListeners();

    _debounce?.cancel();
    _debounce = Timer(searchDebounce, () {
      AdminLog.ui('Coupon search settled: "${_search.trim()}"');
      load(page: 1);
    });
  }

  void clearSearch() {
    if (_search.isEmpty) return;
    AdminLog.ui('Coupon search cleared');
    _debounce?.cancel();
    _search = '';
    load(page: 1);
  }

  void setLimit(int limit) {
    if (_limit == limit) return;
    AdminLog.ui('Coupon page size → $limit');
    _limit = limit;
    load(page: 1);
  }

  void goToPage(int page) {
    final total = _page.effectiveTotalPages;
    final target = total > 0 ? page.clamp(1, total) : page;
    if (target == _page.page && _state.isReady) return;
    AdminLog.ui('Coupons go to page $target');
    load(page: target);
  }

  // --- Detail ----------------------------------------------------------------

  /// Opens the panel on the row immediately, then fetches the full record —
  /// the list row may not carry the scope names or the redemption counters.
  void select(AdminCoupon coupon) {
    AdminLog.ui('Coupon detail opened for ${coupon.id}');
    _selected = coupon;
    _detailState = ViewState.loading;
    _safeNotify();
    unawaited(_refreshDetail(coupon));
  }

  Future<void> _refreshDetail(AdminCoupon coupon) async {
    if (coupon.id <= 0) {
      _detailState = ViewState.ready;
      _safeNotify();
      return;
    }

    final id = ++_detailRequestId;

    try {
      final full = await _repository.getCouponById(coupon.id);
      if (_disposed || id != _detailRequestId) return;
      if (_selected?.id != coupon.id) return;

      _selected = full;
      _detailState = ViewState.ready;
      _replaceRow(full);
      AdminLog.state('Coupon detail ready → $full');
    } catch (error) {
      if (_disposed || id != _detailRequestId) return;
      // The row already on screen stays visible; only the fields the detail
      // call would have added are missing.
      _detailState = ViewState.failed;
      AdminLog.failure('Coupon detail failed for ${coupon.id}', error: error);
    } finally {
      _safeNotify();
    }
  }

  void clearSelection() {
    if (_selected == null) return;
    AdminLog.ui('Coupon detail closed');
    _selected = null;
    _detailState = ViewState.idle;
    _safeNotify();
  }

  // --- Writes ----------------------------------------------------------------

  Future<AdminCoupon> create(CouponDraft draft) async {
    AdminLog.ui('Create coupon submitted');
    final created = await _repository.createCoupon(draft);
    await load(page: 1);
    return created;
  }

  Future<AdminCoupon> update(int id, CouponDraft draft) async {
    AdminLog.ui('Update coupon $id submitted');
    final updated = await _repository.updateCoupon(id, draft);
    await load();

    // Re-point the open panel at the freshly loaded row.
    if (_selected?.id == id) {
      for (final coupon in _coupons) {
        if (coupon.id == id) {
          _selected = coupon;
          break;
        }
      }
      _safeNotify();
    }

    return updated;
  }

  Future<void> delete(int id) async {
    AdminLog.ui('Delete coupon $id confirmed');
    await _repository.deleteCoupon(id);

    if (_selected?.id == id) clearSelection();

    // Removing the last row of a page would otherwise strand an empty page.
    final wasLastRowOnPage = _coupons.length == 1 && _page.page > 1;
    await load(page: wasLastRowOnPage ? _page.page - 1 : _page.page);
  }

  /// Looks a code up before it is posted. Null means the code is free.
  Future<AdminCoupon?> findByCode(String code) =>
      _repository.getCouponByCode(code);

  /// `POST /coupons/validate` — what a shopper would actually get.
  Future<CouponCheck> validate({
    required String code,
    required num amount,
    required CouponAppliesTo appliesTo,
    int? sportComplexId,
    int? sportId,
    int? eventPassId,
  }) {
    AdminLog.ui('Validate $code against $amount (${appliesTo.slug})');
    return _repository.validateCoupon(
      code: code,
      amount: amount,
      appliesTo: appliesTo,
      sportComplexId: sportComplexId,
      sportId: sportId,
      eventPassId: eventPassId,
    );
  }

  /// `GET /coupons/active` — the offers the app is currently showing.
  Future<List<AdminCoupon>> activeCoupons({CouponAppliesTo? appliesTo}) =>
      _repository.getActiveCoupons(appliesTo: appliesTo);

  // --- Helpers ---------------------------------------------------------------

  void _replaceRow(AdminCoupon updated) {
    var changed = false;
    final next = _coupons
        .map((coupon) {
          if (coupon.id != updated.id) return coupon;
          changed = true;
          return updated;
        })
        .toList(growable: false);

    if (!changed) return;
    _coupons = List<AdminCoupon>.unmodifiable(next);
  }

  /// Appends [incoming], skipping rows already on screen.
  ///
  /// A page boundary that shifts between requests (a coupon created while the
  /// desk is scrolling) would otherwise show the same coupon twice.
  static List<AdminCoupon> _mergeById(
    List<AdminCoupon> existing,
    List<AdminCoupon> incoming,
  ) {
    final seen = existing.map((coupon) => coupon.id).toSet();
    final merged = <AdminCoupon>[...existing];
    for (final coupon in incoming) {
      if (seen.add(coupon.id)) merged.add(coupon);
    }
    return List<AdminCoupon>.unmodifiable(merged);
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    AdminLog.life('CouponsController disposed');
    super.dispose();
  }
}
