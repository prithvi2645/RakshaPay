import 'package:flutter/material.dart';

import '../services/risk_engine.dart';
import '../theme/app_theme.dart';

class ReportScamScreen extends StatefulWidget {
  final RiskEngine engine;
  final String? prefilledVpa;

  /// Fired once a report is accepted, so a screen that opened this form (the
  /// risk result, for instance) can reflect that without popping the user out
  /// of the confirmation state shown here.
  final VoidCallback? onReported;

  const ReportScamScreen({
    super.key,
    required this.engine,
    this.prefilledVpa,
    this.onReported,
  });

  @override
  State<ReportScamScreen> createState() => _ReportScamScreenState();
}

class _ReportScamScreenState extends State<ReportScamScreen> {
  late final TextEditingController _vpaController =
      TextEditingController(text: widget.prefilledVpa ?? '');
  String _reason = 'fake_qr';
  bool _submitting = false;
  bool _submitted = false;

  static const _reasons = [
    (id: 'fake_qr', label: 'Fake or tampered QR code'),
    (id: 'kyc_scam', label: 'KYC / account-blocked scam'),
    (id: 'refund_scam', label: 'Fake refund or cashback'),
    (id: 'collect_request', label: 'Unwanted collect request'),
    (id: 'impersonation', label: 'Pretending to be someone else'),
    (id: 'other', label: 'Something else'),
  ];

  @override
  void dispose() {
    _vpaController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final vpa = _vpaController.text.trim();
    if (vpa.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _submitting = true);
    final ok = await widget.engine.scamDatabase
        .reportScam(vpa: vpa, reasonCode: _reason);
    if (!mounted) return;

    setState(() {
      _submitting = false;
      _submitted = ok;
    });

    if (ok) widget.onReported?.call();

    messenger.showSnackBar(SnackBar(
      content: Text(ok
          ? 'Report sent. Thank you for protecting others.'
          : 'Could not send — check your connection and try again.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.danger,
        title: const Text('Report a Scam'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.dangerBg,
              border: Border.all(color: AppColors.dangerBorder),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.shield_outlined,
                    color: AppColors.danger, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Help protect others',
                          style: AppTheme.body(14,
                              color: AppColors.dangerDeep,
                              weight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text(
                        'Once a UPI ID is reported by enough people, everyone using RakshaPay gets warned about it.',
                        style: AppTheme.body(12.5,
                            color: AppColors.danger, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text('Which UPI ID?', style: AppTheme.heading(17)),
          const SizedBox(height: 10),
          TextField(
            controller: _vpaController,
            enabled: !_submitted,
            decoration: const InputDecoration(
              hintText: 'scammer@upi',
              prefixIcon: Icon(Icons.alternate_email),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 22),
          Text('What happened?', style: AppTheme.heading(17)),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: kCardShadow,
            ),
            child: RadioGroup<String>(
              groupValue: _reason,
              onChanged: (v) {
                if (_submitted) return;
                setState(() => _reason = v ?? _reason);
              },
              child: Column(
                children: [
                  for (final reason in _reasons)
                    RadioListTile<String>(
                      value: reason.id,
                      activeColor: AppColors.danger,
                      title: Text(reason.label, style: AppTheme.body(14)),
                      dense: true,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceTint,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_outline, size: 18, color: AppColors.muted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Only the UPI ID and this reason are sent. Your name, phone number and messages are not.',
                    style: AppTheme.body(12, color: AppColors.muted, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor:
                    _submitted ? AppColors.safe : AppColors.danger,
              ),
              onPressed: (_vpaController.text.trim().isEmpty ||
                      _submitting ||
                      _submitted)
                  ? null
                  : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(_submitted ? Icons.check : Icons.send_outlined),
              label: Text(_submitted ? 'Report sent' : 'Submit report'),
            ),
          ),
        ],
      ),
    );
  }
}
