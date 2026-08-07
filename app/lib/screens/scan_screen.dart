import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/scan_record.dart';
import '../services/risk_engine.dart';
import '../services/scan_history_service.dart';
import '../theme/app_theme.dart';
import 'risk_result_screen.dart';

class ScanScreen extends StatefulWidget {
  final RiskEngine engine;
  final ScanHistoryService history;

  const ScanScreen({super.key, required this.engine, required this.history});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _controller = MobileScannerController();
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled || capture.barcodes.isEmpty) return;
    final code = capture.barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    setState(() => _handled = true);
    await _controller.stop();

    try {
      final features = widget.engine.qrAnalyzer.extractFeatures(code);
      final result = widget.engine.analyzeQr(code);

      final uri = Uri.tryParse(code);
      final merchantName = uri?.queryParameters['pn'];

      await widget.history.add(ScanRecord(
        merchantName: merchantName,
        vpa: features.vpa,
        amount: features.hasAmount ? features.amount : null,
        level: result.level,
        score: result.score,
        scannedAt: DateTime.now(),
        source: 'qr',
      ));
      widget.engine.scamDatabase.logRiskEvent(result: result, source: 'qr');

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RiskResultScreen(
            engine: widget.engine,
            result: result,
            vpa: features.vpa.isEmpty ? null : features.vpa,
            merchantName: merchantName,
            amount: features.hasAmount ? features.amount : null,
            rawPayload: code,
          ),
        ),
      );
    } catch (e) {
      // Never leave the user staring at a spinner: scoring failed, say so.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not score this QR: $e'),
          duration: const Duration(seconds: 6),
        ));
      }
    } finally {
      if (mounted) {
        setState(() => _handled = false);
        await _controller.start();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          // Viewfinder
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 3),
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Material(
                        color: Colors.black.withValues(alpha: 0.4),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => Navigator.of(context).pop(),
                          child: const SizedBox(
                            width: 42,
                            height: 42,
                            child: Icon(Icons.arrow_back,
                                color: Colors.white, size: 21),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('Scan UPI QR',
                          style: AppTheme.heading(20, color: Colors.white)),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.shield_outlined,
                          color: Colors.white, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Point at a UPI QR code. RakshaPay checks it before you pay.',
                          style: AppTheme.body(13.5,
                              color: Colors.white, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_handled)
            ColoredBox(
              color: Colors.black.withValues(alpha: 0.65),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 16),
                    Text('Checking this QR...',
                        style: AppTheme.body(15, color: Colors.white)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
