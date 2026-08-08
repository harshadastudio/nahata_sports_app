import '../../core/employee_log.dart';
import '../../domain/entities/employee_notification.dart';
import '../../domain/entities/employee_paged.dart';
import '../../domain/repositories/employee_dashboard_repository.dart';
import 'employee_list_controller.dart';

/// Notifications — the employee's own inbox, and composing a broadcast.
///
/// The list reads `GET /notifications`, not `/notifications/admin`: the latter
/// is unscoped and would return every notification in the system.
///
/// The audience for the compose sheet is fetched lazily, when the sheet is
/// first opened — most visits to this screen are to read the inbox, and pulling
/// every coach and student of the complex for a send that may not happen is
/// wasted work.
class EmployeeNotificationsController
    extends EmployeeListController<EmployeeNotification> {
  EmployeeNotificationsController(this._repository);

  final EmployeeDashboardRepository _repository;

  int _unread = 0;
  EmployeeAudience _audience = EmployeeAudience.empty;
  bool _audienceLoading = false;
  String? _audienceError;

  int get unread => _unread;
  EmployeeAudience get audience => _audience;
  bool get audienceLoading => _audienceLoading;
  String? get audienceError => _audienceError;

  @override
  Future<EmployeePaged<EmployeeNotification>> fetchPage(int page) {
    return _repository.getNotifications(page: page, limit: pageSize);
  }

  @override
  Future<void> onFirstPageLoaded() => _loadUnread();

  Future<void> _loadUnread() async {
    try {
      final count = await _repository.getUnreadNotificationCount();
      if (isDisposed) return;
      _unread = count;
      notify();
    } catch (e) {
      // Non-fatal: the badge just does not show.
      EmployeeLog.failure('Unread count failed', error: e);
    }
  }

  /// Pulls the addressable audience. Safe to call repeatedly — it returns the
  /// cached list once loaded.
  Future<void> loadAudience({bool force = false}) async {
    if (_audienceLoading) return;
    if (!force && !_audience.isEmpty) return;

    _audienceLoading = true;
    _audienceError = null;
    notify();

    try {
      final audience = await _repository.getAudience();
      if (isDisposed) return;
      _audience = audience;
    } catch (e) {
      if (isDisposed) return;
      _audienceError = EmployeeListController.describeError(e);
      EmployeeLog.failure('Audience failed', error: e);
    } finally {
      if (!isDisposed) {
        _audienceLoading = false;
        notify();
      }
    }
  }

  /// Marks one as read, and drops the unread badge by one.
  Future<void> markRead(EmployeeNotification notification) async {
    if (notification.isRead) return;

    // Optimistic: the read state is cosmetic, and a failed PATCH is not worth
    // bouncing the row back and confusing the reader.
    replaceItem(
      (n) => n.id == notification.id,
      (n) => n.copyWith(isRead: true),
    );
    if (_unread > 0) {
      _unread -= 1;
      notify();
    }

    try {
      await _repository.markNotificationRead(notification.id);
    } catch (e) {
      EmployeeLog.failure('Mark read failed', error: e);
    }
  }

  Future<String?> markAllRead() async {
    try {
      await _repository.markAllNotificationsRead();
      _unread = 0;
      await refresh();
      return null;
    } catch (e) {
      return reportFailure('Mark all read failed', e);
    }
  }

  /// Sends a broadcast. Returns the server's own confirmation on success — it
  /// says how many people it reached, which the caller shows verbatim.
  Future<({String? error, String? message})> send(
    EmployeeNotificationDraft draft,
  ) async {
    try {
      final message = await _repository.sendNotification(draft);
      await refresh();
      return (error: null, message: message);
    } catch (e) {
      return (error: reportFailure('Send notification failed', e), message: null);
    }
  }
}
