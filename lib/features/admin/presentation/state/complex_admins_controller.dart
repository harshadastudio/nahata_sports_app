import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../models/sports_complex_model.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/complex_admin.dart';
import '../../domain/entities/paged.dart';
import '../../domain/repositories/complex_admin_repository.dart';
import 'view_state.dart';

/// Everything the Complex Admin page needs: the list, debounced search, the
/// detail panel and the three write operations.
class ComplexAdminsController extends ChangeNotifier {
  ComplexAdminsController(this._repository) {
    AdminLog.life('ComplexAdminsController created');
  }

  final ComplexAdminRepository _repository;

  static const Duration searchDebounce = Duration(milliseconds: 400);
  static const List<int> pageSizes = [10, 20, 50, 100];

  ViewState _state = ViewState.idle;
  Paged<ComplexAdmin> _page = const Paged<ComplexAdmin>();
  String? _error;

  int _requestedPage = 1;
  int _limit = 20;
  String _search = '';

  Timer? _debounce;
  int _requestId = 0;
  bool _disposed = false;

  ComplexAdmin? _selected;

  /// The venue list for the form's dropdown, loaded once and reused.
  List<SportsComplex> _complexes = const [];
  ViewState _complexesState = ViewState.idle;

  // --- Reads -----------------------------------------------------------------

  ViewState get state => _state;
  Paged<ComplexAdmin> get page => _page;
  List<ComplexAdmin> get admins => _page.items;
  String? get error => _error;

  int get limit => _limit;
  String get search => _search;

  ComplexAdmin? get selected => _selected;

  List<SportsComplex> get complexes => _complexes;
  ViewState get complexesState => _complexesState;

  bool get hasFilters => _search.trim().isNotEmpty;
  bool get isFirstLoad => _state.isLoading && _page.items.isEmpty;
  bool get isRefreshing => _state.isLoading && _page.items.isNotEmpty;

  // --- Loading ---------------------------------------------------------------

  Future<void> load({int? page}) async {
    final target = page ?? _requestedPage;
    final id = ++_requestId;

    AdminLog.state(
      'Complex admins loading → page=$target limit=$_limit '
      'search="${_search.trim()}"',
    );

    _requestedPage = target;
    _state = ViewState.loading;
    _error = null;
    _safeNotify();

    try {
      final result = await _repository.fetchComplexAdmins(
        page: target,
        limit: _limit,
        search: _search.trim().isEmpty ? null : _search.trim(),
      );

      if (_disposed || id != _requestId) {
        AdminLog.state('Complex admins response superseded — dropped');
        return;
      }

      _page = result;
      _requestedPage = result.page;
      _state = ViewState.ready;
      AdminLog.state(
        'Complex admins ready → ${result.items.length} rows, '
        'page ${result.page}/${result.effectiveTotalPages}',
      );
    } on ApiException catch (error) {
      if (_disposed || id != _requestId) return;
      _state = ViewState.failed;
      _error = error.message;
      AdminLog.failure(
        'Complex admins load failed: ${error.message}',
        error: error,
      );
    } catch (error, stackTrace) {
      if (_disposed || id != _requestId) return;
      _state = ViewState.failed;
      _error = 'Could not load complex admins. Please try again.';
      AdminLog.failure(
        'Complex admins load crashed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _safeNotify();
    }
  }

  Future<void> refresh() {
    AdminLog.ui('Complex admins refresh requested');
    return load();
  }

  /// Loads the venue list the Add/Edit form needs. Cached after the first call
  /// unless [refresh] is set.
  Future<void> loadComplexes({bool refresh = false}) async {
    if (_complexesState.isLoading) return;
    if (_complexes.isNotEmpty && !refresh) return;

    AdminLog.state('Sport complexes loading (refresh: $refresh)');
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

  // --- Search / paging -------------------------------------------------------

  void onSearchChanged(String value) {
    if (_search == value) return;
    _search = value;
    AdminLog.ui(
      'Complex admin search typed: "$value" '
      '(debouncing ${searchDebounce.inMilliseconds}ms)',
    );
    notifyListeners();

    _debounce?.cancel();
    _debounce = Timer(searchDebounce, () {
      AdminLog.ui('Complex admin search settled: "${_search.trim()}"');
      load(page: 1);
    });
  }

  void clearSearch() {
    if (_search.isEmpty) return;
    AdminLog.ui('Complex admin search cleared');
    _debounce?.cancel();
    _search = '';
    load(page: 1);
  }

  void setLimit(int limit) {
    if (_limit == limit) return;
    AdminLog.ui('Complex admin page size → $limit');
    _limit = limit;
    load(page: 1);
  }

  void goToPage(int page) {
    final total = _page.effectiveTotalPages;
    final target = total > 0 ? page.clamp(1, total) : page;
    if (target == _page.page && _state.isReady) return;
    AdminLog.ui('Complex admins go to page $target');
    load(page: target);
  }

  // --- Detail ----------------------------------------------------------------

  /// The list row carries every field the drawer shows, so there is no detail
  /// endpoint to call — this just opens the panel.
  void select(ComplexAdmin admin) {
    AdminLog.ui('Complex admin detail opened for ${admin.id}');
    _selected = admin;
    _safeNotify();
  }

  void clearSelection() {
    if (_selected == null) return;
    AdminLog.ui('Complex admin detail closed');
    _selected = null;
    _safeNotify();
  }

  // --- Writes ----------------------------------------------------------------

  Future<ComplexAdmin> create(ComplexAdminDraft draft) async {
    AdminLog.ui('Create complex admin submitted');
    final created = await _repository.createComplexAdmin(draft);
    await load(page: 1);
    return created;
  }

  Future<ComplexAdmin> update(String id, ComplexAdminDraft draft) async {
    AdminLog.ui('Update complex admin $id submitted');
    final updated = await _repository.updateComplexAdmin(id, draft);
    await load();

    // Re-point the open drawer at the freshly loaded row.
    if (_selected?.id == id) {
      for (final admin in _page.items) {
        if (admin.id == id) {
          _selected = admin;
          break;
        }
      }
      _safeNotify();
    }

    return updated;
  }

  Future<void> delete(String id) async {
    AdminLog.ui('Delete complex admin $id confirmed');
    await _repository.deleteComplexAdmin(id);

    if (_selected?.id == id) clearSelection();

    // Removing the last row of a page would otherwise strand an empty page.
    final wasLastRowOnPage = _page.items.length == 1 && _page.page > 1;
    await load(page: wasLastRowOnPage ? _page.page - 1 : _page.page);
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    AdminLog.life('ComplexAdminsController disposed');
    super.dispose();
  }
}
