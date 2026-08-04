import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/admin_role.dart';
import '../../domain/entities/role_permissions.dart';
import '../../domain/repositories/admin_repository.dart';
import 'view_state.dart';

/// Drives the Roles & Permissions page.
///
/// [_saved] is the last state the server confirmed and [_draft] is what the
/// admin has toggled. Save stays disabled while the two agree, and Discard
/// simply drops back to [_saved] — no refetch needed.
class AdminRolesController extends ChangeNotifier {
  AdminRolesController(this._repository) {
    AdminLog.life('AdminRolesController created');
  }

  final AdminRepository _repository;

  // Admin and Complex Admin are not permission-managed — a live 400 named the
  // four roles this route takes — so the screen opens on the first of those
  // rather than 400ing before the admin has touched anything.
  AdminRole _role = AdminRole.permissionManaged.first;
  ViewState _state = ViewState.idle;
  String? _error;

  RolePermissions? _saved;
  RolePermissions? _draft;

  bool _saving = false;
  String? _saveError;
  bool _disposed = false;

  int _requestId = 0;

  AdminRole get role => _role;
  ViewState get state => _state;
  String? get error => _error;
  String? get saveError => _saveError;
  bool get isSaving => _saving;

  RolePermissions? get permissions => _draft;

  /// The Save button's enabled condition.
  bool get isDirty {
    final saved = _saved;
    final draft = _draft;
    if (saved == null || draft == null) return false;
    return !draft.sameGrantsAs(saved);
  }

  int get grantedCount => _draft?.granted.length ?? 0;
  int get totalCount => _draft?.catalogue.length ?? 0;

  Future<void> selectRole(AdminRole role, {bool force = false}) async {
    if (_role == role && !force && _state.isReady) {
      AdminLog.ui('Role ${role.slug} already open');
      return;
    }
    AdminLog.ui('Role selected → ${role.slug}');
    _role = role;
    _saved = null;
    _draft = null;
    _saveError = null;
    await load();
  }

  Future<void> load() async {
    final id = ++_requestId;
    AdminLog.state('Permissions loading for ${_role.slug}');

    _state = ViewState.loading;
    _error = null;
    _safeNotify();

    try {
      final result = await _repository.fetchRolePermissions(_role);
      if (_disposed || id != _requestId) {
        AdminLog.state('Permissions response superseded — dropped');
        return;
      }

      _saved = result;
      _draft = result;
      _state = ViewState.ready;
      AdminLog.state('Permissions ready → $result');
    } on ApiException catch (error) {
      if (_disposed || id != _requestId) return;
      _state = ViewState.failed;
      _error = error.message;
      AdminLog.failure(
        'Permissions load failed: ${error.message}',
        error: error,
      );
    } catch (error, stackTrace) {
      if (_disposed || id != _requestId) return;
      _state = ViewState.failed;
      _error = 'Could not load permissions for ${_role.label}.';
      AdminLog.failure(
        'Permissions load crashed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _safeNotify();
    }
  }

  Future<void> refresh() {
    AdminLog.ui('Permissions refresh requested for ${_role.slug}');
    return load();
  }

  void toggle(String slug, bool value) {
    final draft = _draft;
    if (draft == null) return;
    AdminLog.ui('Permission ${value ? 'granted' : 'revoked'}: $slug');
    _draft = draft.toggled(slug, value);
    _saveError = null;
    _safeNotify();
  }

  /// Grants or revokes a whole group in one action.
  void toggleGroup(String group, bool value) {
    final draft = _draft;
    if (draft == null) return;
    final slugs = draft.grouped[group] ?? const <String>[];
    if (slugs.isEmpty) return;

    AdminLog.ui(
      'Group "$group" ${value ? 'granted' : 'revoked'} '
      '(${slugs.length} permissions)',
    );

    var next = draft;
    for (final slug in slugs) {
      next = next.toggled(slug, value);
    }
    _draft = next;
    _saveError = null;
    _safeNotify();
  }

  void discard() {
    final saved = _saved;
    if (saved == null || !isDirty) return;
    AdminLog.ui('Permission changes discarded for ${_role.slug}');
    _draft = saved;
    _saveError = null;
    _safeNotify();
  }

  /// Returns true when the save landed, so the page can show its snackbar.
  Future<bool> save() async {
    final draft = _draft;
    if (draft == null || !isDirty || _saving) return false;

    AdminLog.ui('Saving ${draft.granted.length} permissions for ${_role.slug}');
    _saving = true;
    _saveError = null;
    _safeNotify();

    try {
      final result = await _repository.updateRolePermissions(
        _role,
        draft.granted,
      );
      if (_disposed) return false;

      // Trust the server's echo as the new baseline; if it echoed nothing the
      // repository hands back what was sent, which is the same thing.
      _saved = result;
      _draft = result;
      AdminLog.success('Permissions saved for ${_role.slug}');
      return true;
    } on ApiException catch (error) {
      if (_disposed) return false;
      _saveError = error.message;
      AdminLog.failure(
        'Permission save failed: ${error.message}',
        error: error,
      );
      return false;
    } catch (error, stackTrace) {
      if (_disposed) return false;
      _saveError = 'Could not save permissions. Please try again.';
      AdminLog.failure(
        'Permission save crashed',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    } finally {
      _saving = false;
      _safeNotify();
    }
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    AdminLog.life('AdminRolesController disposed');
    super.dispose();
  }
}
