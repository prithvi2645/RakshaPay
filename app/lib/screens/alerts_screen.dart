import 'package:flutter/material.dart';

import '../models/risk_result.dart';
import '../models/scan_record.dart';
import '../services/risk_engine.dart';
import '../services/scan_history_service.dart';
import '../theme/app_theme.dart';
import 'risk_result_screen.dart';

/// Everything RakshaPay has flagged, with the actual message text.
///
/// Telling a user "5 risky messages found" and then not showing which ones is
/// not a warning — it is an anxiety generator. This screen is where a flagged
/// SMS becomes actionable.
class AlertsScreen extends StatefulWidget {
  final RiskEngine engine;
  final ScanHistoryService history;

  const AlertsScreen({super.key, required this.engine, required this.history});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  _Filter _filter = _Filter.all;

  List<ScanRecord> get _visible {
    final risky = widget.history.records.where((r) => r.isRisky).toList();
    return switch (_filter) {
      _Filter.all => risky,
      _Filter.highRisk =>
        risky.where((r) => r.level == RiskLevel.highRisk).toList(),
      _Filter.caution =>
        risky.where((r) => r.level == RiskLevel.caution).toList(),
      _Filter.messages => risky.where((r) => r.source == 'sms').toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final records = _visible;
    final riskyTotal = widget.history.records.where((r) => r.isRisky).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Alerts')),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: records.isEmpty
                ? _buildEmpty(riskyTotal)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    itemCount: records.length,
                    itemBuilder: (_, i) => _buildTile(records[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        children: [
          for (final f in _Filter.values) ...[
            ChoiceChip(
              label: Text(f.label),
              selected: _filter == f,
              onSelected: (_) => setState(() => _filter = f),
              selectedColor: AppColors.primary,
              backgroundColor: Colors.white,
              labelStyle: AppTheme.body(13,
                  color: _filter == f ? Colors.white : AppColors.muted,
                  weight: FontWeight.w700),
              side: BorderSide(
                color: _filter == f ? AppColors.primary : AppColors.surfaceTint,
              ),
              showCheckmark: false,
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildEmpty(int riskyTotal) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppColors.safeBg,
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(Icons.verified_user_outlined,
                  size: 42, color: AppColors.safe),
            ),
            const SizedBox(height: 18),
            Text(
              riskyTotal == 0 ? 'Nothing risky found' : 'Nothing in this filter',
              style: AppTheme.heading(19),
            ),
            const SizedBox(height: 8),
            Text(
              riskyTotal == 0
                  ? 'Your scanned QR codes and messages all looked fine. '
                      'RakshaPay keeps watching in the background.'
                  : 'Try a different filter to see other alerts.',
              textAlign: TextAlign.center,
              style: AppTheme.body(13.5, color: AppColors.muted, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(ScanRecord record) {
    final (color, bg, icon, label) = switch (record.level) {
      RiskLevel.highRisk => (
          AppColors.danger,
          AppColors.dangerBg,
          Icons.dangerous_outlined,
          'High Risk'
        ),
      _ => (
          AppColors.caution,
          AppColors.cautionBg,
          Icons.warning_amber_rounded,
          'Caution'
        ),
    };

    final sourceLabel = switch (record.source) {
      'sms' => 'Message',
      'manual' => 'Typed UPI ID',
      'qr_image' => 'QR image',
      _ => 'QR scan',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: bg),
        boxShadow: kCardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _open(record),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: color, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record.merchantName?.isNotEmpty == true
                                ? record.merchantName!
                                : (record.vpa.isNotEmpty
                                    ? record.vpa
                                    : 'Unknown sender'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.body(14.5, weight: FontWeight.w800),
                          ),
                          Text('$sourceLabel • ${record.relativeTime}',
                              style:
                                  AppTheme.body(11.5, color: AppColors.muted)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(label,
                          style: AppTheme.body(11,
                              color: color, weight: FontWeight.w800)),
                    ),
                  ],
                ),
                // The message itself — the whole point of this screen.
                if (record.preview != null && record.preview!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      record.preview!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.body(12.5,
                          color: AppColors.navy, height: 1.4),
                    ),
                  ),
                ],
                if (record.reasons.isNotEmpty) ...[
                  const SizedBox(height: 9),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 15, color: color),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          record.reasons.first,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.body(12, color: color, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _open(ScanRecord record) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RiskResultScreen(
        engine: widget.engine,
        result: RiskResult(
          level: record.level,
          score: record.score,
          reasons: record.reasons.isEmpty
              ? ['Flagged by RakshaPay']
              : record.reasons,
        ),
        vpa: record.vpa.isEmpty ? null : record.vpa,
        merchantName: record.merchantName,
        amount: record.amount,
        rawPayload: record.preview,
      ),
    ));
  }
}

enum _Filter {
  all('All'),
  highRisk('High Risk'),
  caution('Caution'),
  messages('Messages');

  final String label;
  const _Filter(this.label);
}
