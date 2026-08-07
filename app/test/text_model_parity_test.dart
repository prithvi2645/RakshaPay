import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rakshapay/services/scam_text_matcher.dart';

/// Numeric parity between the Dart port and the Python pipeline.
///
/// scam_text_matcher.dart reimplements sklearn's TfidfVectorizer and the
/// logistic link by hand. Threshold assertions elsewhere in the suite would
/// still pass if, say, bigram boundaries or sublinear-tf were wrong — the
/// score would move but stay on the same side of the cutoff. These fixtures
/// come straight from predict_proba (ml/src/export_parity_fixtures.py), so any
/// drift in the reimplementation fails here.
///
/// Regenerate with: python ml/src/export_parity_fixtures.py
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ScamTextMatcher matcher;
  late List<dynamic> fixtures;

  setUpAll(() async {
    matcher = ScamTextMatcher();
    await matcher.load();

    final file = File('test/fixtures/text_model_parity.json');
    expect(
      file.existsSync(),
      isTrue,
      reason: 'run `python ml/src/export_parity_fixtures.py` to generate fixtures',
    );
    fixtures = jsonDecode(file.readAsStringSync()) as List<dynamic>;
  });

  test('fixture set is non-empty', () {
    expect(fixtures, isNotEmpty);
  });

  test('matches Python predict_proba to 1e-6 on every fixture', () {
    for (final fixture in fixtures) {
      final text = fixture['text'] as String;
      final expected = (fixture['scam_probability'] as num).toDouble();
      final actual = matcher.scamProbability(text);

      expect(
        actual,
        closeTo(expected, 1e-6),
        reason: 'Dart and Python disagree on: "${text.isEmpty ? '(empty)' : text}"',
      );
    }
  });

  test('handles empty and out-of-vocabulary text without dividing by zero', () {
    for (final text in ['', '!!! ??? ...', 'zzzz qqqq xxxx wwww']) {
      final probability = matcher.scamProbability(text);
      expect(probability.isNaN, isFalse, reason: 'NaN for "$text"');
      expect(probability, inInclusiveRange(0.0, 1.0));
    }
  });
}
