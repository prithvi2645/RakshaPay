import 'dart:async';

import 'package:another_telephony/telephony.dart';

import '../models/risk_result.dart';
import 'risk_engine.dart';

class ScamAlert {
  final String body;
  final String? sender;
  final RiskResult result;
  final DateTime receivedAt;

  ScamAlert({
    required this.body,
    required this.sender,
    required this.result,
    required this.receivedAt,
  });
}

/// Watches incoming SMS and scores each one on-device.
///
/// Message bodies are read, scored, and discarded in memory — nothing is
/// uploaded. Only the resulting risk level syncs, and only if the user reports.
class SmsMonitorService {
  final Telephony _telephony = Telephony.instance;
  final RiskEngine _engine;
  final _alertController = StreamController<ScamAlert>.broadcast();

  SmsMonitorService(this._engine);

  Stream<ScamAlert> get alerts => _alertController.stream;

  Future<bool> requestPermissions() async {
    final granted = await _telephony.requestPhoneAndSmsPermissions;
    return granted ?? false;
  }

  /// Starts listening. Returns false if the user declined SMS permission —
  /// the app stays usable for QR scanning in that case.
  Future<bool> start() async {
    if (!await requestPermissions()) return false;

    _telephony.listenIncomingSms(
      onNewMessage: _handleMessage,
      listenInBackground: false,
    );
    return true;
  }

  void _handleMessage(SmsMessage message) {
    final body = message.body;
    if (body == null || body.trim().isEmpty) return;
    if (!_engine.isInitialized) return;

    final result = _engine.analyzeText(body, sender: message.address);
    // Only surface something the user needs to act on.
    if (result.level == RiskLevel.safe) return;

    _alertController.add(ScamAlert(
      body: body,
      sender: message.address,
      result: result,
      receivedAt: DateTime.now(),
    ));
  }

  /// Scores the recent inbox once, so a new user sees value immediately
  /// instead of waiting for the next scam SMS to arrive.
  Future<List<ScamAlert>> scanRecentInbox({int limit = 50}) async {
    if (!await requestPermissions()) return [];

    final messages = await _telephony.getInboxSms(
      columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
      sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
    );

    final alerts = <ScamAlert>[];
    for (final message in messages.take(limit)) {
      final body = message.body;
      if (body == null || body.trim().isEmpty) continue;

      final result = _engine.analyzeText(body, sender: message.address);
      if (result.level == RiskLevel.safe) continue;

      alerts.add(ScamAlert(
        body: body,
        sender: message.address,
        result: result,
        receivedAt: DateTime.fromMillisecondsSinceEpoch(message.date ?? 0),
      ));
    }
    return alerts;
  }

  void dispose() {
    _alertController.close();
  }
}
