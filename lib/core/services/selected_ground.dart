import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_logger.dart';

/// The venue/ground the user is currently browsing.
///
/// Ground names are the sports-complex names returned by `/sports-complexes`
/// ("Sinhagad Road", "Gangadham Chowk"). They are the filter value accepted by
/// `/sports?ground=` and `/batches/sport/{id}?ground=`.
///
/// This matters because sport ids are scoped to a ground — "Basketball" is id
/// 8 at one venue and 26 at another — so the coaching screens must always know
/// which ground they are showing.
class SelectedGround {
  SelectedGround._();

  static final SelectedGround instance = SelectedGround._();

  static const String _key = 'selected_ground';
  static const String _idKey = 'selected_ground_id';

  String? _memory;
  int? _memoryId;
  bool _loaded = false;

  /// Last known ground without touching disk. Null means "all grounds".
  String? get current => _memory;

  /// Sports-complex id for [current], when known. `/event-passes` filters by
  /// this id rather than by name.
  int? get currentId => _memoryId;

  Future<String?> read() async {
    await _ensureLoaded();
    return _memory;
  }

  Future<int?> readId() async {
    await _ensureLoaded();
    return _memoryId;
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _memory = _clean(prefs.getString(_key));
    _memoryId = prefs.getInt(_idKey);
    _loaded = true;
  }

  /// Records the venue. [id] is optional — pass it whenever the caller knows
  /// the sports-complex id, so id-based endpoints do not have to resolve it.
  Future<void> save(String? ground, {int? id}) async {
    final value = _clean(ground);
    await _ensureLoaded();

    final previousName = _memory;
    if (value == previousName && (id == null || id == _memoryId)) return;

    // Keep the stored id only when the venue itself has not changed;
    // clearing the venue clears its id.
    final int? resolvedId;
    if (value == null) {
      resolvedId = null;
    } else if (id != null) {
      resolvedId = id;
    } else {
      resolvedId = value == previousName ? _memoryId : null;
    }

    _memory = value;
    _memoryId = resolvedId;
    _loaded = true;

    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(_key);
      await prefs.remove(_idKey);
    } else {
      await prefs.setString(_key, value);
      if (_memoryId == null) {
        await prefs.remove(_idKey);
      } else {
        await prefs.setInt(_idKey, _memoryId!);
      }
    }

    AppLogger.debug(
      'Selected ground: ${value ?? "(all)"}${_memoryId == null ? "" : " (#$_memoryId)"}',
      name: 'Location',
    );
  }

  /// Fills in the id for the venue already selected, once it becomes known.
  Future<void> attachId(int? id) async {
    if (id == null || _memory == null) return;
    await _ensureLoaded();
    if (_memoryId == id) return;

    _memoryId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_idKey, id);
  }

  Future<void> clear() => save(null);

  static String? _clean(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}
