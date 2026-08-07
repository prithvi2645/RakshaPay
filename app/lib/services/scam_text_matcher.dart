import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

import '../models/risk_result.dart';

/// On-device scam-text classifier.
///
/// Runs the TF-IDF + LogisticRegression model trained in ml/src/train_text_model.py.
/// The weights ship as JSON (see ml/src/export_text_weights.py) and the linear
/// model is evaluated directly here, which avoids depending on ONNX string
/// tensor support on mobile. Results are numerically identical to the Python
/// pipeline.
class ScamTextMatcher {
  static const _assetPath = 'assets/models/scam_text_model.json';
  static final _tokenPattern = RegExp(r'[a-zA-Z0-9]+');

  Map<String, int>? _vocabulary;
  List<double>? _idf;
  List<double>? _coef;
  double _intercept = 0;
  bool _sublinearTf = true;
  int _minN = 1;
  int _maxN = 2;

  bool get isLoaded => _vocabulary != null;

  Future<void> load() async {
    if (isLoaded) return;
    final raw = await rootBundle.loadString(_assetPath);
    final json = jsonDecode(raw) as Map<String, dynamic>;

    _vocabulary = (json['vocabulary'] as Map<String, dynamic>)
        .map((key, value) => MapEntry(key, value as int));
    _idf = (json['idf'] as List).map((v) => (v as num).toDouble()).toList();
    _coef = (json['coef'] as List).map((v) => (v as num).toDouble()).toList();
    _intercept = (json['intercept'] as num).toDouble();
    _sublinearTf = json['sublinear_tf'] as bool? ?? true;
    final ngramRange = json['ngram_range'] as List?;
    if (ngramRange != null && ngramRange.length == 2) {
      _minN = ngramRange[0] as int;
      _maxN = ngramRange[1] as int;
    }
  }

  /// Reproduces sklearn's TfidfVectorizer: word n-grams, sublinear tf,
  /// idf weighting, then L2 normalization.
  Map<int, double> _vectorize(String text) {
    final vocabulary = _vocabulary!;
    final idf = _idf!;

    final tokens = _tokenPattern
        .allMatches(text.toLowerCase())
        .map((m) => m.group(0)!)
        .toList();

    final counts = <int, double>{};
    for (var n = _minN; n <= _maxN; n++) {
      for (var i = 0; i + n <= tokens.length; i++) {
        final term = tokens.sublist(i, i + n).join(' ');
        final index = vocabulary[term];
        if (index != null) {
          counts[index] = (counts[index] ?? 0) + 1;
        }
      }
    }

    final weighted = <int, double>{};
    var normSq = 0.0;
    counts.forEach((index, count) {
      final tf = _sublinearTf ? 1 + log(count) : count;
      final value = tf * idf[index];
      weighted[index] = value;
      normSq += value * value;
    });

    if (normSq > 0) {
      final norm = sqrt(normSq);
      weighted.updateAll((_, value) => value / norm);
    }
    return weighted;
  }

  /// Probability that [text] is a scam message, in 0..1.
  double scamProbability(String text) {
    if (!isLoaded) {
      throw StateError('ScamTextMatcher.load() must be awaited before use');
    }
    final coef = _coef!;
    var z = _intercept;
    _vectorize(text).forEach((index, value) {
      z += coef[index] * value;
    });
    return 1 / (1 + exp(-z));
  }

  /// Pulls a UPI ID out of message text, so an SMS alert can still be
  /// reported — a scam SMS often names the VPA it wants you to pay.
  static String? extractVpa(String text) {
    final match = RegExp(
      r'\b[a-zA-Z0-9._-]{2,}@[a-zA-Z]{2,}\b',
    ).firstMatch(text);
    final candidate = match?.group(0);
    if (candidate == null) return null;

    // Reject email addresses — a VPA handle is never a mail domain.
    const mailSuffixes = ['gmail', 'yahoo', 'outlook', 'hotmail', 'rediffmail'];
    final suffix = candidate.split('@').last.toLowerCase();
    if (mailSuffixes.contains(suffix)) return null;
    return candidate;
  }

  RiskResult analyze(String text) {
    final probability = scamProbability(text);
    final score = (probability * 100).round();

    final reasons = <String>[];
    if (probability >= 0.7) {
      reasons.add('Message language closely matches known scam messages');
    } else if (probability >= 0.35) {
      reasons.add('Message contains some language typical of scam messages');
    } else {
      reasons.add('Message language looks normal');
    }
    reasons.addAll(_explain(text));

    return RiskResult.fromScore(score, reasons);
  }

  /// Surfaces the concrete phrases behind a score. The model gives a
  /// probability; users need a reason they can act on.
  List<String> _explain(String text) {
    const cues = {
      'kyc': 'asks you to update KYC — banks never do this over SMS links',
      'upi pin': 'asks for your UPI PIN — never needed to receive money',
      'otp': 'asks for an OTP — never share it with anyone',
      'anydesk': 'asks you to install remote-access software',
      'teamviewer': 'asks you to install remote-access software',
      'blocked': 'threatens that your account will be blocked',
      'suspend': 'threatens account suspension to create urgency',
      'lottery': 'claims you won a prize',
      'refund': 'offers an unexpected refund',
      'cashback': 'offers unexpected cashback',
      'collect request': 'asks you to accept a collect request — that sends money out',
    };

    final lower = text.toLowerCase();
    final found = <String>[];
    cues.forEach((cue, explanation) {
      if (lower.contains(cue) && found.length < 3) {
        found.add('Message $explanation');
      }
    });

    if (RegExp(r'https?://').hasMatch(lower) && found.isNotEmpty) {
      found.add('Message includes a link — do not open it');
    }
    return found;
  }
}
