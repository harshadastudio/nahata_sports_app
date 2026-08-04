import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/admin_log.dart';
import '../navigation/admin_destination.dart';

/// Chrome-level state: which module is open, whether the sidebar is collapsed
/// and which brightness the panel runs at.
///
/// The two cosmetic choices are persisted, so an admin who collapses the rail
/// or picks dark mode gets it back on the next launch.
class AdminShellController extends ChangeNotifier {
  AdminShellController() {
    AdminLog.life('AdminShellController created');
    _restore();
  }

  static const String _kThemeKey = 'admin_dashboard_theme_mode';
  static const String _kSidebarKey = 'admin_dashboard_sidebar_collapsed';

  AdminDestination _destination = AdminDestination.dashboard;
  UsersTab _usersTab = UsersTab.users;
  bool _sidebarCollapsed = false;
  ThemeMode _themeMode = ThemeMode.light;
  bool _restored = false;

  AdminDestination get destination => _destination;

  /// Which tab of the Users module is open. Owned here rather than inside the
  /// module so the top bar knows whether its search box applies.
  UsersTab get usersTab => _usersTab;

  /// The top bar's search only drives the users list, so it is live on exactly
  /// one screen.
  bool get isSearchable =>
      _destination == AdminDestination.users && _usersTab == UsersTab.users;
  bool get sidebarCollapsed => _sidebarCollapsed;
  ThemeMode get themeMode => _themeMode;

  /// True once the persisted preferences have been read, so the first frame
  /// does not flash the wrong theme.
  bool get isRestored => _restored;

  bool get isDark => _themeMode == ThemeMode.dark;

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedTheme = prefs.getString(_kThemeKey);
      final storedSidebar = prefs.getBool(_kSidebarKey);

      if (storedTheme == 'dark') _themeMode = ThemeMode.dark;
      if (storedTheme == 'light') _themeMode = ThemeMode.light;
      if (storedSidebar != null) _sidebarCollapsed = storedSidebar;

      AdminLog.state(
        'Shell restored → theme=${_themeMode.name}, '
        'sidebarCollapsed=$_sidebarCollapsed',
      );
    } catch (error) {
      // Preferences are cosmetic; a failure here must not block the dashboard.
      AdminLog.failure('Shell preferences unreadable', error: error);
    } finally {
      _restored = true;
      notifyListeners();
    }
  }

  void go(AdminDestination destination) {
    if (_destination == destination) {
      AdminLog.ui('Navigation → ${destination.label} (already open)');
      return;
    }
    AdminLog.ui('Navigation → ${destination.label}');
    _destination = destination;
    notifyListeners();
  }

  void openUsersTab(UsersTab tab) {
    if (_usersTab == tab) return;
    AdminLog.ui('Users module tab → ${tab.label}');
    _usersTab = tab;
    notifyListeners();
  }

  void toggleSidebar() {
    _sidebarCollapsed = !_sidebarCollapsed;
    AdminLog.ui('Sidebar ${_sidebarCollapsed ? 'collapsed' : 'expanded'}');
    notifyListeners();
    _persist(_kSidebarKey, _sidebarCollapsed);
  }

  void toggleTheme() {
    _themeMode = isDark ? ThemeMode.light : ThemeMode.dark;
    AdminLog.ui('Theme → ${_themeMode.name}');
    notifyListeners();
    _persist(_kThemeKey, _themeMode.name);
  }

  Future<void> _persist(String key, Object value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value is bool) {
        await prefs.setBool(key, value);
      } else {
        await prefs.setString(key, value.toString());
      }
    } catch (error) {
      AdminLog.failure('Could not persist $key', error: error);
    }
  }

  @override
  void dispose() {
    AdminLog.life('AdminShellController disposed');
    super.dispose();
  }
}
