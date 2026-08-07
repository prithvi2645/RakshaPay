import 'package:flutter/material.dart';

import '../models/scan_record.dart';
import '../services/risk_engine.dart';
import '../services/scan_history_service.dart';
import '../theme/app_theme.dart';
import 'risk_result_screen.dart';

/// Score a UPI ID / QR payload typed by hand.
///
/// The QR path is otherwise only reachable through the camera, which can't be
/// exercised on an emulator or in a screen-shared demo. It's also genuinely
/// useful: a user can check a UPI ID someone sent them over chat, with no QR
/// code involved at all.
class ManualCheckScreen extends StatefulWidget {
  final RiskEngine engine;
  final ScanHistoryService history;

  const ManualCheckScreen({
    super.key,
    required this.engine,
    required this.history,
  });

  @override
  State<ManualCheckScreen> createState() => _ManualCheckScreenState();
}

class _ManualCheckScreenState extends State<ManualCheckScreen> {
  final _controller = TextEditingController();

  static const _samples = [
    (
      label: 'Legitimate merchant',
      hint: 'Known bank handle, normal name',
      value: 'upi://pay?pa=sharma.kirana@okaxis&pn=Sharma%20Kirana%20Store&cu=INR',
      color: AppColors.safe,
      bg: AppColors.safeBg,
    ),
    (
      label: 'Random-looking payee ID',
      hint: 'High entropy, ₹1 verification ping',
      value: 'upi://pay?pa=x9k2plq7z1w4@okaxis&pn=Refund%20Team&am=1&cu=INR',
      color: AppColors.caution,
      bg: AppColors.cautionBg,
    ),
    (
      label: 'Unknown bank handle',
      hint: 'Handle that no real PSP uses',
      value: 'upi://pay?pa=kyc-team42@pay-verify&pn=KYC%20Support&cu=INR',
      color: AppColors.danger,
      bg: AppColors.dangerBg,
    ),
    (
      label: 'Plain UPI ID (no QR)',
      hint: 'Like someone sent you over chat',
      value: 'rahul.sharma@oksbi',
      color: AppColors.primary,
      bg: AppColors.blueTint,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final input = _controller.text.trim();
    if (input.isEmpty) return;

    // A bare VPA isn't a QR payload; wrap it so feature extraction sees the
    // same shape the model was trained on.
    final payload = input.startsWith('upi://')
        ? input
        : 'upi://pay?pa=${Uri.encodeComponent(input)}&cu=INR';

    final messenger = ScaffoldMessenger.of(context);
    try {
      final features = widget.engine.qrAnalyzer.extractFeatures(payload);
      final result = widget.engine.analyzeQr(payload);
      final merchantName = Uri.tryParse(payload)?.queryParameters['pn'];

      await widget.history.add(ScanRecord(
        merchantName: merchantName,
        vpa: features.vpa,
        amount: features.hasAmount ? features.amount : null,
        level: result.level,
        score: result.score,
        scannedAt: DateTime.now(),
        source: 'manual',
      ));
      widget.engine.scamDatabase.logRiskEvent(result: result, source: 'manual');

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RiskResultScreen(
            engine: widget.engine,
            result: result,
            vpa: features.vpa.isEmpty ? null : features.vpa,
            merchantName: merchantName,
            amount: features.hasAmount ? features.amount : null,
            rawPayload: payload,
          ),
        ),
      );
      if (mounted) setState(() {});
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Could not score this UPI ID: $e'),
        duration: const Duration(seconds: 6),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Check a UPI ID')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Paste a UPI ID or QR link', style: AppTheme.heading(18)),
          const SizedBox(height: 6),
          Text(
            'RakshaPay scores it the same way it scores a scanned QR code.',
            style: AppTheme.body(13.5, color: AppColors.muted, height: 1.4),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'name@okaxis',
              prefixIcon: Icon(Icons.alternate_email),
            ),
            onSubmitted: (_) => _check(),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _controller.text.trim().isEmpty ? null : _check,
              icon: const Icon(Icons.shield_outlined),
              label: const Text('Check risk'),
            ),
          ),
          const SizedBox(height: 30),
          Text('Try an example', style: AppTheme.heading(17)),
          const SizedBox(height: 12),
          ..._samples.map(
            (sample) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: kCardShadow,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    _controller.text = sample.value;
                    _check();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: sample.bg,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.qr_code_2,
                              size: 22, color: sample.color),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(sample.label,
                                  style: AppTheme.body(14,
                                      weight: FontWeight.w800)),
                              const SizedBox(height: 2),
                              Text(sample.hint,
                                  style: AppTheme.body(12,
                                      color: AppColors.muted)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: AppColors.muted),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
