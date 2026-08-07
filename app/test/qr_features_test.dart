import 'package:flutter_test/flutter_test.dart';
import 'package:rakshapay/services/qr_risk_analyzer.dart';

/// Feature extraction must stay in lockstep with FEATURES in
/// ml/src/train_risk_model.py — if these drift, the model is fed garbage
/// and scores silently become meaningless.
void main() {
  final analyzer = QrRiskAnalyzer();

  test('extracts the payee VPA from a UPI payment URI', () {
    final features = analyzer.extractFeatures(
      'upi://pay?pa=rahul.sharma@okaxis&pn=Rahul%20Sharma&cu=INR',
    );
    expect(features.isUpiUri, isTrue);
    expect(features.vpa, 'rahul.sharma@okaxis');
    expect(features.suffix, 'okaxis');
    expect(features.knownPspSuffix, isTrue);
  });

  test('flags an unrecognized PSP handle', () {
    final features = analyzer.extractFeatures('upi://pay?pa=kyc-team42@pay-verify&cu=INR');
    expect(features.knownPspSuffix, isFalse);
    expect(features.suffix, 'pay-verify');
  });

  test('detects a pre-filled amount', () {
    final features = analyzer.extractFeatures(
      'upi://pay?pa=shop@okhdfcbank&am=249.50&cu=INR',
    );
    expect(features.hasAmount, isTrue);
    expect(features.amount, 249.50);
  });

  test('treats a non-UPI payload as not a payment URI', () {
    final features = analyzer.extractFeatures('https://example.com/not-a-upi-qr');
    expect(features.isUpiUri, isFalse);
    expect(features.vpa, isEmpty);
  });

  test('computes higher entropy for a random-looking payee id', () {
    final random = analyzer.extractFeatures('upi://pay?pa=x9k2plq7z1@okaxis&cu=INR');
    final human = analyzer.extractFeatures('upi://pay?pa=rahul@okaxis&cu=INR');
    expect(random.entropy, greaterThan(human.entropy));
  });

  test('computes digit ratio for a digit-heavy payee id', () {
    final features = analyzer.extractFeatures('upi://pay?pa=987654321012@okaxis&cu=INR');
    expect(features.digitRatio, 1.0);
  });

  test('emits features in the exact order the model expects', () {
    final features = analyzer.extractFeatures(
      'upi://pay?pa=rahul.sharma@okaxis&am=100&cu=INR',
    );
    final input = features.toModelInput();

    expect(input.length, QrFeatures.featureCount);
    expect(input[0], 1); // known_psp_suffix
    expect(input[3], 'rahul.sharma'.length.toDouble()); // local_part_len
    expect(input[4], 1); // has_amount
    expect(input[5], 100); // amount
  });
}
