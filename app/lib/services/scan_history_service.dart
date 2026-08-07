import 'package:shared_preferences/shared_preferences.dart';

import '../models/risk_result.dart';
import '../models/scan_record.dart';

/// Local scan history — powers the home screen's stats and Recent Scans.
///
/// Deliberately on-device only: the history includes which merchants a user
/// pays, which is exactly the sort of thing docs/architecture.md says never
/// leaves the phone.
class ScanHistoryService {
  static const _key = 'scan_history';
  static const _maxRecords = 100;

  List<ScanRecord> _records = [];

  List<ScanRecord> get records => List.unmodifiable(_records);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const [];
    _records = raw
        .map((entry) {
          try {
            return ScanRecord.decode(entry);
          } catch (_) {
            return null;
          }
        })
        .whereType<ScanRecord>()
        .toList()
      ..sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
  }

  Future<void> add(ScanRecord record) async {
    _records = [record, ..._records];
    if (_records.length > _maxRecords) {
      _records = _records.sublist(0, _maxRecords);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, _records.map((r) => r.encode()).toList());
  }

  Future<void> clear() async {
    _records = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  List<ScanRecord> get today {
    final now = DateTime.now();
    return _records
        .where((r) =>
            r.scannedAt.year == now.year &&
            r.scannedAt.month == now.month &&
            r.scannedAt.day == now.day)
        .toList();
  }

  int get scansToday => today.length;
  int get safeToday => today.where((r) => r.level == RiskLevel.safe).length;
  int get risksToday =>
      today.where((r) => r.level != RiskLevel.safe).length;

  /// Headline "Safety Score" on the home screen: the share of recent checks
  /// that came back clean. With no history yet we show 100 rather than 0 — a
  /// user who has scanned nothing hasn't been exposed to anything.
  int get safetyScore {
    if (_records.isEmpty) return 100;
    final recent = _records.take(20).toList();
    final safe = recent.where((r) => r.level == RiskLevel.safe).length;
    return ((safe / recent.length) * 100).round();
  }

  String get safetyLabel {
    final score = safetyScore;
    if (score >= 90) return 'Excellent Protection';
    if (score >= 70) return 'Good Protection';
    if (score >= 50) return 'Stay Alert';
    return 'High Exposure';
  }
}
