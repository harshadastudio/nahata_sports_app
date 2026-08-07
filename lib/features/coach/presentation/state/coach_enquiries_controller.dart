import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../core/coach_log.dart';
import '../../domain/entities/coach_enquiry.dart';
import '../../domain/entities/coach_fee.dart';
import '../../domain/entities/coach_paged.dart';
import '../../domain/repositories/coach_dashboard_repository.dart';
import 'coach_view_state.dart';

/// The coach's coaching-enquiry queue.
///
/// Every enquiry here is already assigned to this coach — the backend scopes
/// the list, and re-checks ownership on each write, answering 403 otherwise.
class CoachEnquiriesController extends ChangeNotifier {
  CoachEnquiriesController(this._repository) {
    CoachLog.life('CoachEnquiriesController created');
  }

  final CoachDashboardRepository _repository;

  static const int pageSize = 20;

  CoachViewState _state = CoachViewState.idle;
  CoachPaged<CoachEnquiry> _page = const CoachPaged<CoachEnquiry>();
  List<CoachEnquiry> _enquiries = const [];
  String? _error;

  CoachEnquiryStatus? _status;

  bool _loadingMore = false;
  bool _refreshing = false;
  bool _disposed = false;
  int _requestId = 0;

  CoachViewState get state => _state;
  List<CoachEnquiry> get enquiries => _enquiries;
  String? get error => _error;
  CoachEnquiryStatus? get status => _status;

  bool get loadingMore => _loadingMore;
  bool get refreshing => _refreshing;
  bool get hasMore => _page.hasNext;
  int get total => _page.total;

  bool get isFiltered => _status != null;
  bool get isEmpty => _state.isReady && _enquiries.isEmpty;

  /// Still needing the coach's attention, among what is loaded.
  int get openCount => _enquiries.where((e) => e.isOpen).length;

  Future<void> load({bool silent = false}) async {
    if (_disposed) return;

    final request = ++_requestId;

    _refreshing = silent && _enquiries.isNotEmpty;
    if (!_refreshing) _state = CoachViewState.loading;
    _notify();

    try {
      final result = await _repository.getEnquiries(
        page: 1,
        limit: pageSize,
        status: _status,
      );

      if (request != _requestId || _disposed) return;

      _page = result;
      _enquiries = result.items;
      _error = null;
      _state = CoachViewState.ready;
    } catch (e) {
      if (request != _requestId || _disposed) return;

      _error = _describe(e);
      _state = CoachViewState.failed;
      CoachLog.failure('Coach enquiries failed', error: e);
    } finally {
      if (request == _requestId && !_disposed) {
        _refreshing = false;
        _notify();
      }
    }
  }

  Future<void> refresh() => load(silent: true);

  Future<void> loadMore() async {
    if (_disposed || _loadingMore || !_page.hasNext) return;
    if (_state.isLoading) return;

    final request = _requestId;
    _loadingMore = true;
    _notify();

    try {
      final result = await _repository.getEnquiries(
        page: _page.page + 1,
        limit: pageSize,
        status: _status,
      );

      if (request != _requestId || _disposed) return;

      _page = result;
      _enquiries = [..._enquiries, ...result.items];
    } catch (e) {
      if (request != _requestId || _disposed) return;
      _error = _describe(e);
      CoachLog.failure('Coach enquiries page failed', error: e);
    } finally {
      if (!_disposed) {
        _loadingMore = false;
        _notify();
      }
    }
  }

  /// Passing the currently selected status clears the filter, so chips toggle.
  void setStatus(CoachEnquiryStatus? value) {
    final next = value == _status ? null : value;
    if (next == _status) return;
    _status = next;
    CoachLog.ui('Enquiry filter → ${next?.slug ?? 'all'}');
    load();
  }

  void clearFilters() {
    if (!isFiltered) return;
    _status = null;
    load();
  }

  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------

  Future<void> create(CoachEnquiryDraft draft) async {
    await _repository.createEnquiry(draft);
    await load(silent: true);
  }

  /// Moves an enquiry along, optimistically so the chip responds instantly.
  ///
  /// Rolled back if the server refuses — which it will for `Approved`, an
  /// admin-only status the UI does not offer.
  Future<void> updateStatus(int id, CoachEnquiryStatus status) async {
    final index = _enquiries.indexWhere((e) => e.id == id);
    if (index < 0) return;

    final previous = _enquiries;
    _enquiries = [..._enquiries]..[index] =
        _enquiries[index].copyWith(statusRaw: status.slug);
    _notify();

    try {
      await _repository.updateEnquiryStatus(id: id, status: status);
    } catch (e) {
      _enquiries = previous;
      _notify();
      CoachLog.failure('Enquiry $id status change failed', error: e);
      rethrow;
    }

    // A status change can move the row out of an active filter, so the list is
    // re-read rather than left showing something that no longer belongs.
    if (_status != null) await load(silent: true);
  }

  /// Approves an enquiry and enrolls the student.
  ///
  /// Reloaded rather than patched in place: approving creates a student and an
  /// enrollment server-side, so the row's status is not the only thing that
  /// changed.
  Future<void> approveAndEnroll({
    required int id,
    CoachPaymentStatus? paymentStatus,
    num? amountPaid,
    String? notes,
  }) async {
    await _repository.approveAndEnroll(
      id: id,
      paymentStatus: paymentStatus,
      amountPaid: amountPaid,
      notes: notes,
    );
    await load(silent: true);
  }

  /// Deletes an enquiry, optimistically.
  Future<void> delete(int id) async {
    final previous = _enquiries;
    final previousTotal = _page.total;

    _enquiries = _enquiries.where((e) => e.id != id).toList(growable: false);
    _page = _page.copyWith(total: previousTotal > 0 ? previousTotal - 1 : 0);
    _notify();

    try {
      await _repository.deleteEnquiry(id);
      CoachLog.success('Deleted enquiry $id');
    } catch (e) {
      _enquiries = previous;
      _page = _page.copyWith(total: previousTotal);
      _notify();
      CoachLog.failure('Delete enquiry $id failed', error: e);
      rethrow;
    }
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
    CoachLog.life('CoachEnquiriesController disposed');
    super.dispose();
  }
}
