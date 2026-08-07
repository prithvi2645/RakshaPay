import 'dart:convert';

import 'risk_result.dart';

/// One completed risk check, kept on-device so the home screen can show real
/// history and stats instead of placeholders.
///
/// Stores the derived result and the payee VPA only — never the raw QR payload
/// or message body, matching the privacy rule in docs/architecture.md.
class ScanRecord {
  final String? merchantName;
  final String vpa;
  final double? amount;
  final RiskLevel level;
  final int score;
  final DateTime scannedAt;
  final String source; // qr | manual | sms

  /// The flagged message text, for SMS records only.
  ///
  /// Without this the user is told "a message was risky" and has no way to see
  /// which one — useless as a warning. It stays on the device (the message is
  /// already in the phone's own SMS store) and is never uploaded; reports send
  /// only a VPA and a reason code.
  final String? preview;

  /// Reasons the engine gave, so the detail screen works from history.
  final List<String> reasons;

  const ScanRecord({
    required this.merchantName,
    required this.vpa,
    required this.amount,
    required this.level,
    required this.score,
    required this.scannedAt,
    required this.source,
    this.preview,
    this.reasons = const [],
  });

  Map<String, dynamic> toJson() => {
        'merchantName': merchantName,
        'vpa': vpa,
        'amount': amount,
        'level': level.name,
        'score': score,
        'scannedAt': scannedAt.toIso8601String(),
        'source': source,
        'preview': preview,
        'reasons': reasons,
      };

  static ScanRecord fromJson(Map<String, dynamic> json) => ScanRecord(
        merchantName: json['merchantName'] as String?,
        vpa: json['vpa'] as String? ?? '',
        amount: (json['amount'] as num?)?.toDouble(),
        level: RiskLevel.values.firstWhere(
          (l) => l.name == json['level'],
          orElse: () => RiskLevel.caution,
        ),
        score: (json['score'] as num?)?.toInt() ?? 0,
        scannedAt:
            DateTime.tryParse(json['scannedAt'] as String? ?? '') ?? DateTime.now(),
        source: json['source'] as String? ?? 'qr',
        preview: json['preview'] as String?,
        reasons: (json['reasons'] as List?)?.cast<String>() ?? const [],
      );

  bool get isRisky => level != RiskLevel.safe;

  String encode() => jsonEncode(toJson());

  static ScanRecord decode(String raw) =>
      fromJson(jsonDecode(raw) as Map<String, dynamic>);

  /// "2 min ago" / "1 hr ago" / "Yesterday", as the design shows.
  String get relativeTime {
    final diff = DateTime.now().difference(scannedAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays} days ago';
  }
}
