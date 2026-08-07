import 'package:flutter_test/flutter_test.dart';
import 'package:rakshapay/services/risk_engine.dart';
import 'package:rakshapay/services/scam_text_matcher.dart';

/// Diagnostic: prints the level and score for a spread of realistic messages.
/// Not an assertion suite — it exists to show where the Caution band actually
/// lands so the thresholds can be tuned against evidence.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('score distribution across message types', () async {
    final matcher = ScamTextMatcher();
    await matcher.load();
    final engine = RiskEngine(textMatcher: matcher);

    const cases = <(String label, String sender, String body)>[
      ('bank debit', 'VM-HDFCBK',
          'Rs.500.00 debited from a/c **1234 to VPA citycafe@okaxis. Avl bal Rs.4200.00.'),
      ('otp', 'AD-SBIINB', 'Your OTP for SBI NetBanking is 481920. Do not share.'),
      ('recharge done', 'VK-JIOINF',
          'Recharge successful! Rs.299 plan activated. 1.5GB/day for 28 days.'),
      ('telecom promo', 'AX-AIRTEL',
          'Special offer! Get 2GB extra data on Rs.399 recharge. Limited period offer!'),
      ('promo, unknown sender', '',
          'Special offer! Get 2GB extra data on Rs.399 recharge. Limited period offer!'),
      ('promo, personal number', '9876543210',
          'Hey! Flat 50% off on all orders today only. Click http://bit.ly/2345 to claim now!'),
      ('loan spam, personal', '9876501234',
          'Get instant personal loan up to Rs.5,00,000 with no documents. Apply now!'),
      ('kyc scam', '9876543210',
          'Dear customer, your SBI KYC will be blocked in 24 hours. Update now: http://bit.ly/1234'),
      ('otp harvest', '7012345678',
          'We noticed suspicious activity on your UPI account. Share the OTP sent to you.'),
      ('collect trap', '8123456789',
          'I sent Rs.2000 to your account by mistake. Please accept the collect request to return it.'),
    ];

    // ignore: avoid_print
    print('\n  LEVEL      SCORE  CASE');
    // ignore: avoid_print
    print('  ---------  -----  ----------------------------------');
    for (final (label, sender, body) in cases) {
      final r = engine.analyzeText(body, sender: sender.isEmpty ? null : sender);
      // ignore: avoid_print
      print('  ${r.level.name.padRight(9)}  ${r.score.toString().padLeft(5)}  $label');
    }
    // ignore: avoid_print
    print('');
  });
}
