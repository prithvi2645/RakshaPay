import 'package:flutter/material.dart';

import '../models/risk_result.dart';
import '../services/risk_engine.dart';
import '../services/scam_text_matcher.dart';
import '../services/tts_service.dart';
import '../theme/app_theme.dart';
import 'report_scam_screen.dart';

class RiskResultScreen extends StatefulWidget {
  final RiskEngine engine;
  final RiskResult result;
  final String? vpa;
  final String? merchantName;
  final double? amount;
  final String? rawPayload;

  const RiskResultScreen({
    super.key,
    required this.engine,
    required this.result,
    this.vpa,
    this.merchantName,
    this.amount,
    this.rawPayload,
  });

  @override
  State<RiskResultScreen> createState() => _RiskResultScreenState();
}

class _RiskResultScreenState extends State<RiskResultScreen> {
  final _tts = TtsService();
  bool _reported = false;

  @override
  void initState() {
    super.initState();
    _speak();
  }

  Future<void> _speak() async {
    // Honour the language chosen in Settings before speaking.
    await _tts.loadSavedLanguage();
    if (!mounted) return;
    await _tts.speakResult(widget.result, messageText: widget.rawPayload);
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  _Presentation get _p => switch (widget.result.level) {
        RiskLevel.safe => const _Presentation(
            header: AppColors.safe,
            accent: AppColors.safe,
            tint: AppColors.safeBg,
            border: AppColors.safeBorder,
            icon: Icons.verified_rounded,
            title: 'SAFE TO PAY',
            subtitle: 'No red flags found in this payment',
          ),
        RiskLevel.caution => const _Presentation(
            header: AppColors.caution,
            accent: AppColors.caution,
            tint: AppColors.cautionBg,
            border: AppColors.cautionBorder,
            icon: Icons.warning_amber_rounded,
            title: 'CAUTION',
            subtitle: 'Check carefully before you pay',
          ),
        RiskLevel.highRisk => const _Presentation(
            header: AppColors.danger,
            accent: AppColors.danger,
            tint: AppColors.dangerBg,
            border: AppColors.dangerBorder,
            icon: Icons.dangerous_rounded,
            title: 'HIGH RISK!',
            subtitle: 'DO NOT pay with this QR code',
          ),
      };

  /// The UPI ID to report. QR scans carry one directly; for an SMS alert we
  /// dig one out of the message text.
  String? get _reportableVpa {
    if (widget.vpa != null && widget.vpa!.isNotEmpty) return widget.vpa;
    final payload = widget.rawPayload;
    return payload == null ? null : ScamTextMatcher.extractVpa(payload);
  }

  /// Opens the report form, pre-filled with the UPI ID we already know.
  ///
  /// Reporting always goes through that one form rather than submitting
  /// inline. The reason code it collects — fake_qr, kyc_scam, refund_scam and
  /// so on — is what lands in the shared scam_patterns table that every other
  /// device reads, so it has to describe the scam. Submitting from here used
  /// to send the risk *level* instead, which wrote "caution" into the
  /// community database and told other users nothing.
  ///
  /// A missing VPA is normal for SMS alerts; the form simply opens empty so
  /// the user can supply one, rather than leaving a dead button.
  Future<void> _report() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReportScamScreen(
          engine: widget.engine,
          prefilledVpa: _reportableVpa,
          onReported: () {
            if (mounted) setState(() => _reported = true);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(p),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              children: [
                _buildPayeeCard(p),
                const SizedBox(height: 16),
                _buildAnalysisCard(p),
              ],
            ),
          ),
          _buildActions(p),
        ],
      ),
    );
  }

  Widget _buildHeader(_Presentation p) {
    return Container(
      width: double.infinity,
      color: p.header,
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned(
              top: -50,
              right: -40,
              child: _decorCircle(160, Colors.white.withValues(alpha: 0.06)),
            ),
            Positioned(
              bottom: -30,
              left: -30,
              child: _decorCircle(120, Colors.black.withValues(alpha: 0.06)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Material(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => Navigator.of(context).pop(),
                        child: const SizedBox(
                          width: 40,
                          height: 40,
                          child: Icon(Icons.arrow_back, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                    child: Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        child: Icon(p.icon, size: 46, color: p.accent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(p.title,
                      textAlign: TextAlign.center,
                      style: AppTheme.heading(34, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(p.subtitle,
                      textAlign: TextAlign.center,
                      style: AppTheme.body(14.5,
                          color: Colors.white.withValues(alpha: 0.9))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _decorCircle(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );

  Widget _buildPayeeCard(_Presentation p) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.border),
        boxShadow: kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: p.tint,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(
                  widget.result.level == RiskLevel.safe
                      ? Icons.storefront_outlined
                      : Icons.block,
                  size: 28,
                  color: p.accent,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.merchantName?.isNotEmpty == true
                          ? widget.merchantName!
                          : (widget.result.level == RiskLevel.safe
                              ? 'Payee'
                              : 'Unverified payee'),
                      style: AppTheme.heading(18),
                    ),
                    if (widget.vpa != null && widget.vpa!.isNotEmpty)
                      Text(widget.vpa!,
                          style: AppTheme.body(13.5,
                              color: widget.result.level == RiskLevel.safe
                                  ? AppColors.muted
                                  : p.accent,
                              weight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _statTile(
                  'Risk Score',
                  '${widget.result.score}/100',
                  p,
                  emphasise: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statTile(
                  'Amount',
                  widget.amount != null && widget.amount! > 0
                      ? '₹${widget.amount!.toStringAsFixed(2)}'
                      : 'Not set',
                  p,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statTile(String label, String value, _Presentation p,
      {bool emphasise = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: emphasise ? p.tint : AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTheme.body(11.5, color: AppColors.muted)),
          const SizedBox(height: 3),
          Text(value,
              style: AppTheme.body(14,
                  color: emphasise ? p.accent : AppColors.navy,
                  weight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildAnalysisCard(_Presentation p) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.border),
        boxShadow: kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.result.level == RiskLevel.safe
                ? 'Safety Analysis'
                : 'Why is this risky?',
            style: AppTheme.heading(18),
          ),
          const SizedBox(height: 6),
          ...widget.result.reasons.map(
            (reason) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    widget.result.level == RiskLevel.safe
                        ? Icons.check_circle
                        : Icons.error_outline,
                    size: 19,
                    color: p.accent,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(reason,
                        style: AppTheme.body(13.5, height: 1.4)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.phone_android, size: 17, color: AppColors.muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Checked on your phone. Nothing was uploaded.',
                    style: AppTheme.body(12, color: AppColors.muted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(_Presentation p) {
    final isHighRisk = widget.result.level == RiskLevel.highRisk;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.surfaceTint)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isHighRisk)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.block),
                    label: const Text('Cancel this payment'),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: p.accent),
                    onPressed: () => Navigator.of(context).pop(true),
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Proceed to pay'),
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (isHighRisk)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Pay anyway'),
                      ),
                    )
                  else
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                    ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.dangerBorder, width: 1.5),
                      ),
                      onPressed: _reported ? null : _report,
                      icon: Icon(_reported ? Icons.check : Icons.flag_outlined, size: 18),
                      label: Text(_reported ? 'Reported' : 'Report'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Presentation {
  final Color header;
  final Color accent;
  final Color tint;
  final Color border;
  final IconData icon;
  final String title;
  final String subtitle;

  const _Presentation({
    required this.header,
    required this.accent,
    required this.tint,
    required this.border,
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}
