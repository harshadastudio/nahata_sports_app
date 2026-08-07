import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../core/coach_log.dart';
import '../../domain/entities/coach_notification.dart';
import '../../domain/entities/coach_paged.dart';
import '../../domain/repositories/coach_dashboard_repository.dart';
import 'coach_view_state.dart';

/// The coach's notification inbox, plus composing a new one.
///
/// Reads come from `GET /notifications`, which is scoped to the signed-in
/// user's own rows. `GET /notifications/admin` is not used — it is unscoped
/// and a coach calling it would see the whole system's traffic.
class CoachNotificationsController extends ChangeNotifier {
  CoachNotificationsController(this._repository) {
    CoachLog.life('CoachNotificationsController created');
  }

  final CoachDashboardRepository _repository;

  static const int pageSize = 20;

  CoachViewState _state = CoachViewState.idle;
  CoachPaged<CoachNotification> _page = const CoachPaged<CoachNotification>();
  List<CoachNotification> _notifications = const [];
  String? _error;

  int _unread = 0;
  bool _unreadOnly = false;

  bool _loadingMore = false;
  bool _refreshing = false;
  bool _disposed = false;
  int _requestId = 0;

  // ── Recipients, fetched only when the compose sheet needs them ────────────
  CoachViewState _recipientsState = CoachViewState.idle;
  List<CoachNotificationRecipient> _recipients = const [];
  String? _recipientsError;

  CoachViewState get state => _state;
  String? get error => _error;

  /// The inbox, filtered client-side when [unreadOnly] is set — the endpoint
  /// has no unread filter, and the pages are small enough that fetching them
  /// all to filter server-side would cost more than it saves.
  List<CoachNotification> get notifications => _unreadOnly
      ? _notifications.where((n) => !n.isRead).toList(growable: false)
      : _notifications;

  int get unreadCount => _unread;
  bool get unreadOnly => _unreadOnly;

  bool get loadingMore => _loadingMore;
  bool get refreshing => _refreshing;
  bool get hasMore => _page.hasNext;
  int get total => _page.total;

  bool get isEmpty => _state.isReady && notifications.isEmpty;

  /// Nothing at all, as opposed to nothing matching the unread filter.
  bool get inboxEmpty => _state.isReady && _notifications.isEmpty;

  CoachViewState get recipientsState => _recipientsState;
  List<CoachNotificationRecipient> get recipients => _recipients;
  String? get recipientsError => _recipientsError;

  // ---------------------------------------------------------------------------
  // Loading
  // ---------------------------------------------------------------------------

  Future<void> load({bool silent = false}) async {
    if (_disposed) return;

    final request = ++_requestId;

    _refreshing = silent && _notifications.isNotEmpty;
    if (!_refreshing) _state = CoachViewState.loading;
    _notify();

    // The badge is a separate endpoint and is allowed to fail on its own.
    final countFuture = _loadUnreadCount();

    try {
      final result = await _repository.getNotifications(
        page: 1,
        limit: pageSize,
      );

      if (request != _requestId || _disposed) return;

      _page = result;
      _notifications = result.items;
      _error = null;
      _state = CoachViewState.ready;
    } catch (e) {
      if (request != _requestId || _disposed) return;

      _error = _describe(e);
      _state = CoachViewState.failed;
      CoachLog.failure('Notifications failed', error: e);
    } finally {
      await countFuture;
      if (request == _requestId && !_disposed) {
        _refreshing = false;
        _notify();
      }
    }
  }

  Future<void> refresh() => load(silent: true);

  Future<void> _loadUnreadCount() async {
    try {
      final count = await _repository.getUnreadNotificationCount();
      if (!_disposed) _unread = count;
    } catch (e) {
      CoachLog.failure('Unread count failed', error: e);
    }
  }

  Future<void> loadMore() async {
    if (_disposed || _loadingMore || !_page.hasNext) return;
    if (_state.isLoading) return;

    final request = _requestId;
    _loadingMore = true;
    _notify();

    try {
      final result = await _repository.getNotifications(
        page: _page.page + 1,
        limit: pageSize,
      );

      if (request != _requestId || _disposed) return;

      _page = result;
      _notifications = [..._notifications, ...result.items];
    } catch (e) {
      if (request != _requestId || _disposed) return;
      _error = _describe(e);
      CoachLog.failure('Notifications page failed', error: e);
    } finally {
      if (!_disposed) {
        _loadingMore = false;
        _notify();
      }
    }
  }

  void setUnreadOnly(bool value) {
    if (value == _unreadOnly) return;
    _unreadOnly = value;
    CoachLog.ui('Notification filter → ${value ? 'unread' : 'all'}');
    _notify();
  }

  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------

  /// Marks one notification read.
  ///
  /// Applied locally first so the row responds instantly, and rolled back if
  /// the server refuses.
  Future<void> markRead(int id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index < 0 || _notifications[index].isRead) return;

    final previous = _notifications;
    final previousUnread = _unread;

    _notifications = [..._notifications]..[index] =
        _notifications[index].copyWith(isRead: true);
    if (_unread > 0) _unread--;
    _notify();

    try {
      await _repository.markNotificationRead(id);
    } catch (e) {
      _notifications = previous;
      _unread = previousUnread;
      _notify();
      CoachLog.failure('Mark read $id failed', error: e);
    }
  }

  /// Marks everything read.
  Future<void> markAllRead() async {
    if (_unread == 0 && _notifications.every((n) => n.isRead)) return;

    final previous = _notifications;
    final previousUnread = _unread;

    _notifications = _notifications
        .map((n) => n.copyWith(isRead: true))
        .toList(growable: false);
    _unread = 0;
    _notify();

    try {
      await _repository.markAllNotificationsRead();
    } catch (e) {
      _notifications = previous;
      _unread = previousUnread;
      _notify();
      CoachLog.failure('Mark all read failed', error: e);
      rethrow;
    }
  }

  /// The audience for the compose sheet. Loaded on demand — the inbox itself
  /// has no use for it.
  Future<void> loadRecipients() async {
    if (_disposed || _recipientsState.isLoading) return;
    if (_recipientsState.isReady && _recipients.isNotEmpty) return;

    _recipientsState = CoachViewState.loading;
    _notify();

    try {
      _recipients = await _repository.getNotificationRecipients();
      _recipientsError = null;
      _recipientsState = CoachViewState.ready;
    } catch (e) {
      _recipientsError = _describe(e);
      _recipientsState = CoachViewState.failed;
      CoachLog.failure('Notification recipients failed', error: e);
    }

    _notify();
  }

  /// Sends a notification, then reloads — the coach is a recipient of nothing
  /// they send, but the reload keeps the badge honest if anything else landed
  /// meanwhile. Throws so the sheet can stay open and explain a failure.
  Future<void> send(CoachNotificationDraft draft) async {
    await _repository.sendNotification(draft);
    await load(silent: true);
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
    CoachLog.life('CoachNotificationsController disposed');
    super.dispose();
  }
}
