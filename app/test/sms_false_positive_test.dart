import 'package:flutter_test/flutter_test.dart';
import 'package:rakshapay/models/risk_result.dart';
import 'package:rakshapay/services/fraud_signals.dart';
import 'package:rakshapay/services/risk_engine.dart';
import 'package:rakshapay/services/scam_text_matcher.dart';
import 'package:rakshapay/services/sender_reputation.dart';

/// Regression tests for the false-positive blowup found on a real phone:
/// 47 of 50 inbox messages were flagged risky, nearly all of them ordinary
/// bank alerts and recharge offers.
///
/// Root cause: the text model is trained on a UK corpus where "spam" means
/// marketing, so Indian transactional SMS — amounts, links, offers — scores
/// like spam. These tests pin the corrections that matter: sender trust and
/// requiring an actual fraud ask.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RiskEngine engine;

  setUpAll(() async {
    final matcher = ScamTextMatcher();
    await matcher.load();
    // No ONNX here — analyzeText only needs the text model.
    engine = RiskEngine(textMatcher: matcher);
  });

  group('sender classification', () {
    test('recognises DLT business headers', () {
      for (final sender in ['VM-HDFCBK', 'AD-SBIINB', 'JD-PAYTM', 'BP-ICICIB']) {
        expect(SenderReputation.classify(sender), SenderTrust.registeredBusiness,
            reason: sender);
      }
    });

    test('recognises personal mobile numbers', () {
      for (final sender in ['9876543210', '+919876543210', '7012345678']) {
        expect(SenderReputation.classify(sender), SenderTrust.personalNumber,
            reason: sender);
      }
    });
  });

  group('legitimate Indian SMS must not alert', () {
    const legitimate = <String, String>{
      'VM-HDFCBK':
          'Rs.500.00 debited from a/c **1234 on 06-08-26 to VPA citycafe@okaxis. Avl bal Rs.4200.00. Not you? Call 18002586161.',
      'AD-SBIINB': 'Your OTP for SBI NetBanking is 481920. Valid for 10 mins. Do not share.',
      'VK-JIOINF':
          'Recharge successful! Rs.299 plan activated. 1.5GB/day for 28 days. Enjoy unlimited calls.',
      'AX-AIRTEL':
          'Special offer! Get 2GB extra data on Rs.399 recharge. Limited period offer. Recharge now on the Airtel Thanks app.',
      'BZ-AMAZON': 'Your order has been shipped and will arrive by Friday. Track in the app.',
      'VM-ICICIB':
          'Rs.2,499 spent on ICICI Card XX1234 at BIGBAZAAR on 06-Aug. Avl limit Rs.47,501.',
    };

    legitimate.forEach((sender, body) {
      test('"${body.substring(0, 40)}..." from $sender is not flagged', () {
        final result = engine.analyzeText(body, sender: sender);
        expect(
          result.level,
          RiskLevel.safe,
          reason: 'scored ${result.score}: ${result.reasons.join(" | ")}',
        );
      });
    });
  });

  group('real scams must still alert', () {
    const scams = <String, String>{
      '9876543210':
          'Dear customer, your SBI KYC will be blocked in 24 hours. Update now: http://bit.ly/1234',
      '7012345678':
          'We noticed suspicious activity on your UPI account. Share the OTP sent to you to secure it.',
      '9123456780':
          'This is HDFC support. Please install AnyDesk and share your screen so we can process your refund.',
      '8123456789':
          'I have sent Rs.2000 to your account by mistake. Please accept the collect request to return it.',
    };

    scams.forEach((sender, body) {
      test('"${body.substring(0, 40)}..." is flagged', () {
        final result = engine.analyzeText(body, sender: sender);
        expect(
          result.level,
          isNot(RiskLevel.safe),
          reason: 'scored ${result.score}: ${result.reasons.join(" | ")}',
        );
      });
    });

    test('a KYC scam spoofing a bank header is still caught', () {
      // Sender trust discounts, but an explicit fraud ask must still surface —
      // header spoofing exists, so trust alone can never clear a message.
      final result = engine.analyzeText(
        'Your KYC will be blocked today. Share your UPI PIN to reactivate immediately.',
        sender: 'VM-HDFCBK',
      );
      expect(result.level, isNot(RiskLevel.safe),
          reason: 'scored ${result.score}: ${result.reasons.join(" | ")}');
    });
  });

  group('fraud signal detection', () {
    test('finds credential requests', () {
      expect(FraudSignals.hasActionableAsk('Please share your OTP to continue'),
          isTrue);
    });

    test('finds account threats', () {
      expect(
          FraudSignals.hasActionableAsk('Your account will be blocked today'),
          isTrue);
    });

    test('does not fire on a plain promotional offer', () {
      expect(
        FraudSignals.hasActionableAsk(
            'Special offer! Get 2GB extra data on Rs.399 recharge. Recharge now.'),
        isFalse,
      );
    });
  });
}
