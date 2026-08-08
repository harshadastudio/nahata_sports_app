import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/contact_inquiry.dart';
import '../../domain/entities/paged.dart';
import '../../domain/repositories/contact_enquiry_repository.dart';
import 'view_state.dart';

/// State for the Contact Enquiries page.
///
/// Server-paginated only: `GET /contact-us/admin` takes `page` and `limit` and
/// the console asks for one page at a time. It never walks the whole dataset —
/// there is nothing here that needs the full set, and the status counts the
/// cards show come from the payload rather than from counting rows.
///
/// The one thing worth knowing: **the status filter and the search box act on
/// the loaded page only**, and say so. Neither parameter name is confirmed on
/// this endpoint, so sending a guess would produce a filter that silently does
/// nothing. Filtering what is on screen is a smaller, honest promise — and
/// [filterIsPageScoped] is what the UI uses to make it out loud.
class ContactEnquiriesController extends ChangeNotifier {
  ContactEnquiriesController(this._repository) {
    AdminLog.life('ContactEnquiriesController created');
  }

  final ContactEnquiryRepository _repository;

  /// The confirmed default. 10 is what the captured URL asks for.
  static const int defaultLimit = 10;
  static const List<int> pageSizes = [10, 20, 50, 100];

  ViewState _state = ViewState.idle;
  Paged<ContactInquiry> _page = const Paged<ContactInquiry>(
    limit: defaultLimit,
  );
  ContactStatusCounts _counts = const ContactStatusCounts();
  String? _error;

  int _requestedPage = 1;
  int _limit = defaultLimit;
  int _requestId = 0;
  bool _disposed = false;

  String _search = '';
  ContactInquiryStatus? _statusFilter;

  ContactInquiry? _selected;

  // --- Reads -----------------------------------------------------------------

  ViewState get state => _state;
  String? get error => _error;

  /// The page exactly as the server answered it — the pager reads this, so it
  /// is never affected by the on-screen filters.
  Paged<ContactInquiry> get page => _page;

  ContactStatusCounts get counts => _counts;

  int get limit => _limit;
  String get search => _search;
  ContactInquiryStatus? get statusFilter => _statusFilter;

  ContactInquiry? get selected => _selected;

  bool get isFirstLoad => _state.isLoading && _page.items.isEmpty;
  bool get isRefreshing => _state.isLoading && _page.items.isNotEmpty;

  bool get hasFilters => _search.trim().isNotEmpty || _statusFilter != null;

  /// True while a filter is narrowing only the rows already loaded — which is
  /// the only kind of filtering this endpoint supports today.
  bool get filterIsPageScoped => hasFilters;

  /// How many rows the server sent for this page, before the local filters.
  int get loadedCount => _page.items.length;

  /// The rows to draw: the server's page, narrowed by whatever the toolbar is
  /// set to.
  List<ContactInquiry> get enquiries {
    final term = _search.trim().toLowerCase();
    final status = _statusFilter;
    if (term.isEmpty && status == null) return _page.items;

    return _page.items.where((row) {
      if (status != null && row.status != status) return false;
      if (term.isEmpty) return true;

      return [
        row.fullName,
        row.email ?? '',
        row.subject ?? '',
        row.referenceNumber ?? '',
        row.message ?? '',
        row.sportComplexName,
      ].any((field) => field.toLowerCase().contains(term));
    }).toList(growable: false);
  }

  // --- Loading ---------------------------------------------------------------

  Future<void> load({int? page}) async {
    final target = page ?? _requestedPage;
    final id = ++_requestId;

    AdminLog.state('Contact enquiries loading → page=$target limit=$_limit');

    _requestedPage = target;
    _state = ViewState.loading;
    _error = null;
    _safeNotify();

    try {
      final result = await _repository.fetchEnquiries(
        page: target,
        limit: _limit,
      );

      // A slow page 1 landing after a fast page 2 would otherwise overwrite it.
      if (_disposed || id != _requestId) {
        AdminLog.state('Contact enquiries response superseded — dropped');
        return;
      }

      _page = result.page;
      _counts = result.counts;
      _requestedPage = result.page.page;
      _state = ViewState.ready;

      // The open detail panel is refreshed from the new rows so it cannot show
      // a stale copy of a row that just changed; a row that has gone from the
      // page closes the panel rather than lingering.
      final open = _selected;
      if (open != null) {
        ContactInquiry? fresh;
        for (final row in _page.items) {
          if (row.id == open.id) {
            fresh = row;
            break;
          }
        }
        _selected = fresh;
      }

      AdminLog.state(
        'Contact enquiries ready → ${result.items.length} rows, '
        'page ${_page.page}/${_page.effectiveTotalPages}, '
        'total ${_page.total}',
      );
    } on ApiException catch (error) {
      if (_disposed || id != _requestId) return;
      _state = ViewState.failed;
      _error = error.message;
      AdminLog.failure('Contact enquiries load failed: ${error.message}');
    } catch (error, stackTrace) {
      if (_disposed || id != _requestId) return;
      _state = ViewState.failed;
      _error = 'Could not load contact enquiries.';
      AdminLog.failure(
        'Contact enquiries load error',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _safeNotify();
    }
  }

  Future<void> refresh() => load(page: _requestedPage);

  Future<void> goToPage(int page) {
    if (page < 1 || page == _page.page) return Future<void>.value();
    AdminLog.ui('Contact enquiries → page $page');
    return load(page: page);
  }

  Future<void> setLimit(int limit) {
    if (limit == _limit) return Future<void>.value();
    AdminLog.ui('Contact enquiries page size → $limit');
    _limit = limit;
    return load(page: 1);
  }

  // --- Filters (page-scoped) -------------------------------------------------

  void onSearchChanged(String value) {
    if (_search == value) return;
    // No debounce: this filters rows already in memory, so there is no request
    // to hold back and a delay would only make typing feel laggy.
    _search = value;
    _safeNotify();
  }

  void clearSearch() {
    if (_search.isEmpty) return;
    _search = '';
    _safeNotify();
  }

  void setStatusFilter(ContactInquiryStatus? status) {
    if (_statusFilter == status) return;
    AdminLog.ui('Contact enquiry status filter → ${status?.slug ?? 'All'}');
    _statusFilter = status;
    _safeNotify();
  }

  /// Tapping the card that is already filtering clears it.
  void toggleStatusFilter(ContactInquiryStatus status) =>
      setStatusFilter(_statusFilter == status ? null : status);

  void clearFilters() {
    if (!hasFilters) return;
    AdminLog.ui('Contact enquiry filters cleared');
    _search = '';
    _statusFilter = null;
    _safeNotify();
  }

  // --- Selection -------------------------------------------------------------

  void select(ContactInquiry enquiry) {
    if (_selected?.id == enquiry.id) return;
    AdminLog.ui('Contact enquiry opened: ${enquiry.referenceNumber ?? enquiry.id}');
    _selected = enquiry;
    _safeNotify();
  }

  void clearSelection() {
    if (_selected == null) return;
    _selected = null;
    _safeNotify();
  }

  // --- Lifecycle -------------------------------------------------------------

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    AdminLog.life('ContactEnquiriesController disposed');
    super.dispose();
  }
}