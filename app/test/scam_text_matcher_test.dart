import 'package:flutter_test/flutter_test.dart';
import 'package:rakshapay/services/scam_text_matcher.dart';

/// Verifies the Dart reimplementation of the TF-IDF + LogReg pipeline agrees
/// with the Python model. Expected probabilities come from
/// ml/src/verify_models.py run against the same exported weights.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ScamTextMatcher matcher;

  setUpAll(() async {
    matcher = ScamTextMatcher();
    await matcher.load();
  });

  test('loads the exported model weights', () {
    expect(matcher.isLoaded, isTrue);
  });

  test('scores a legitimate UPI debit alert as low risk', () {
    final probability = matcher.scamProbability(
      'Rs.500 debited from a/c **1234 for UPI txn to City Cafe. Avl bal Rs.4200. -HDFC Bank',
    );
    expect(probability, lessThan(0.35));
  });

  test('scores a KYC-expiry scam as high risk', () {
    final probability = matcher.scamProbability(
      'Dear customer, your SBI KYC will be blocked in 24 hours. Update now: http://bit.ly/1234',
    );
    expect(probability, greaterThan(0.7));
  });

  test('scores an OTP-harvesting message as high risk', () {
    final probability = matcher.scamProbability(
      'We noticed suspicious activity on your UPI account. Share the OTP sent to you to secure it.',
    );
    expect(probability, greaterThan(0.7));
  });

  test('explains why a message was flagged', () {
    final result = matcher.analyze(
      'Your KYC has expired. Share your UPI PIN to reactivate: http://bit.ly/9999',
    );
    expect(result.reasons, isNotEmpty);
    expect(
      result.reasons.any((r) => r.toLowerCase().contains('kyc')),
      isTrue,
      reason: 'user needs a concrete reason, not just a score',
    );
  });
}
