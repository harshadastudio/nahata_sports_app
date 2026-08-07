import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../admin/core/admin_log.dart';
import '../../domain/entities/gate_scan.dart';

/// One line of the activity feed.
@immutable
class ScanJournalEntry {
  const ScanJournalEntry({
    required this.kind,
    required this.outcome,
    required this.passCode,
    required this.at,
    this.personName,
    this.direction,
    this.message,
  });

  final GateScanKind kind;
  final GateScanOutcome outcome;
  final String passCode;
  final DateTime at;
  final String? personName;
  final GateDirection? direction;
  final String? message;

  bool get isSuccess => outcome.isSuccess;
  bool get isFailure => outcome.isFailure;

  String get displayName {
    final name = (personName ?? '').trim();
    if (name.isNotEmpty) return name;
    return passCode.isEmpty ? kind.label : passCode;
  }

  String get timeLabel =>
      '${at.hour.toString().padLeft(2, '0')}:'
      '${at.minute.toString().padLeft(2, '0')}';

  factory ScanJournalEntry.of(GateScanResult result) => ScanJournalEntry(
        kind: result.kind,
        outcome: result.outcome,
        passCode: result.passCode,
        at: result.at,
        personName: result.personName,
        direction: result.direction,
        message: result.message,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'kind': kind.name,
        'outcome': outcome.name,
        'passCode': passCode,
        'at': at.toIso8601String(),
        'personName': personName,
        'direction': direction?.name,
        'message': message,
      };

  static ScanJournalEntry? fromJson(Object? value) {
    if (value is! Map) return null;
    final json = Map<String, dynamic>.from(value);

    final at = DateTime.tryParse(json['at']?.toString() ?? '');
    if (at == null) return null;

    T? byName<T extends Enum>(List<T> values, Object? name) {
      final text = name?.toString();
      if (text == null) return null;
      for (final entry in values) {
        if (entry.name == text) return entry;
      }
      return null;
    }

    final kind = byName(GateScanKind.values, json['kind']);
    final outcome = byName(GateScanOutcome.values, json['outcome']);
    if (kind == null || outcome == null) return null;

    return ScanJournalEntry(
      kind: kind,
      outcome: outcome,
      passCode: json['passCode']?.toString() ?? '',
      at: at,
      personName: json['personName']?.toString(),
      direction: byName(GateDirection.values, json['direction']),
      message: json['message']?.toString(),
    );
  }
}

/// The gate's own record of what it scanned.
///
/// There is no endpoint that returns "recent scans across all four modules" —
/// each backend knows only about its own passes, and a failed scan is not
/// stored anywhere at all. But a guard's most-asked question is "what just
/// happened at this gate?", including the refusals, so the console keeps its
/// own log.
///
/// It is deliberately device-local and capped: it is an operational aid for the
/// person on the door, not an audit trail, and it must never be read as the
/// authoritative record. It survives a restart via [SharedPreferences] and is
/// pruned to [maxEntries] and [retention] on every write.
class ScanJournal extends ChangeNotifier {
  ScanJournal({SharedPreferences? preferences}) : _prefs = preferences;

  static const String _key = 'security_scan_journal_v1';

  /// Enough for a full shift; old lines are dropped rather than grown forever.
  static const int maxEntries = 200;

  /// Nothing older than this is kept — a stale line is worse than no line.
  static const Duration retention = Duration(days: 2);

  SharedPreferences? _prefs;
  List<ScanJournalEntry> _entries = const [];
  bool _restored = false;

  List<ScanJournalEntry> get entries => _entries;
  bool get isRestored => _restored;
  bool get isEmpty => _entries.isEmpty;

  /// The most recent [limit] lines, newest first.
  List<ScanJournalEntry> recent([int limit = 10]) =>
      _entries.length <= limit ? _entries : _entries.sublist(0, limit);

  /// Today's lines only — what the dashboard counters are built from.
  List<ScanJournalEntry> today([DateTime? now]) {
    final moment = now ?? DateTime.now();
    final start = DateTime(moment.year, moment.month, moment.day);
    return _entries
        .where((entry) => !entry.at.isBefore(start))
        .toList(growable: false);
  }

  /// Scans recorded today for one gate.
  int countToday(GateScanKind kind, [DateTime? now]) =>
      today(now).where((entry) => entry.kind == kind).length;

  int get totalToday => today().length;

  /// Refused or failed scans today — the "Invalid QR Attempts" counter.
  int get failuresToday =>
      today().where((entry) => entry.outcome.isFailure).length;

  Future<void> restore() async {
    if (_restored) return;

    try {
      final prefs = _prefs ??= await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _entries = _prune(
            decoded
                .map(ScanJournalEntry.fromJson)
                .whereType<ScanJournalEntry>()
                .toList(),
          );
        }
      }
      AdminLog.state('Scan journal restored → ${_entries.length} entries');
    } catch (error) {
      // A corrupt journal is not worth failing a shift over.
      AdminLog.failure('Scan journal unreadable — starting fresh', error: error);
      _entries = const [];
    } finally {
      _restored = true;
      notifyListeners();
    }
  }

  /// Records a scan — successful or not.
  Future<void> record(GateScanResult result) async {
    final entry = ScanJournalEntry.of(result);
    _entries = _prune([entry, ..._entries]);
    notifyListeners();
    await _persist();
  }

  Future<void> clear() async {
    if (_entries.isEmpty) return;
    _entries = const [];
    notifyListeners();
    await _persist();
  }

  /// Newest first, inside the retention window, capped.
  static List<ScanJournalEntry> _prune(List<ScanJournalEntry> entries) {
    final cutoff = DateTime.now().subtract(retention);
    final kept = entries
        .where((entry) => entry.at.isAfter(cutoff))
        .toList()
      ..sort((a, b) => b.at.compareTo(a.at));

    return List<ScanJournalEntry>.unmodifiable(
      kept.length <= maxEntries ? kept : kept.sublist(0, maxEntries),
    );
  }

  Future<void> _persist() async {
    try {
      final prefs = _prefs ??= await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode(_entries.map((entry) => entry.toJson()).toList()),
      );
    } catch (error) {
      // Losing the journal is survivable; failing the scan that produced it is
      // not, so this never propagates.
      AdminLog.failure('Scan journal could not be saved', error: error);
    }
  }
}