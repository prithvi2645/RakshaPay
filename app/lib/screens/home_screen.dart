import 'dart:async';

import 'package:flutter/material.dart';

import '../models/risk_result.dart';
import '../models/scan_record.dart';
import '../services/risk_engine.dart';
import '../services/scam_text_matcher.dart';
import '../services/scan_history_service.dart';
import '../services/sms_monitor_service.dart';
import '../theme/app_theme.dart';
import '../widgets/safety_score_ring.dart';
import 'alerts_screen.dart';
import 'manual_check_screen.dart';
import 'report_scam_screen.dart';
import 'scan_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final RiskEngine engine;
  final ScanHistoryService history;

  const HomeScreen({super.key, required this.engine, required this.history});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final SmsMonitorService _smsMonitor = SmsMonitorService(widget.engine);
  StreamSubscription<ScamAlert>? _alertSubscription;

  bool _smsMonitoring = false;
  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    _alertSubscription = _smsMonitor.alerts.listen((alert) {
      if (!mounted) return;
      _recordAlert(alert);
      setState(() {});
    });
  }

  @override
  void dispose() {
    _alertSubscription?.cancel();
    _smsMonitor.dispose();
    super.dispose();
  }

  Future<void> _recordAlert(ScamAlert alert) async {
    await widget.history.add(ScanRecord(
      merchantName: alert.sender ?? 'Unknown sender',
      vpa: ScamTextMatcher.extractVpa(alert.body) ?? '',
      amount: null,
      level: alert.result.level,
      score: alert.result.score,
      scannedAt: alert.receivedAt,
      source: 'sms',
      preview: alert.body,
      reasons: alert.result.reasons,
    ));
  }

  Future<void> _openScanner() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ScanScreen(engine: widget.engine, history: widget.history),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openManualCheck() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ManualCheckScreen(engine: widget.engine, history: widget.history),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _enableSmsMonitoring() async {
    final messenger = ScaffoldMessenger.of(context);
    final started = await _smsMonitor.start();
    if (!mounted) return;

    setState(() => _smsMonitoring = started);
    if (!started) {
      messenger.showSnackBar(const SnackBar(
        content: Text('SMS permission denied. QR scanning still works.'),
      ));
      return;
    }

    final recent = await _smsMonitor.scanRecentInbox();
    for (final alert in recent) {
      await _recordAlert(alert);
    }
    if (!mounted) return;
    setState(() {});

    if (recent.isEmpty) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Good news — no risky messages found in your inbox.'),
      ));
      return;
    }

    // Take the user straight to what was found. Reporting a count and leaving
    // them to hunt for the messages is what made this feel broken.
    messenger.showSnackBar(SnackBar(
      content: Text('Found ${recent.length} risky message(s).'),
      action: SnackBarAction(label: 'VIEW', onPressed: _openAlerts),
      duration: const Duration(seconds: 5),
    ));
    await _openAlerts();
  }

  Future<void> _openAlerts() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            AlertsScreen(engine: widget.engine, history: widget.history),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              children: [
                _buildStatsRow(),
                const SizedBox(height: 20),
                if (_riskyCount > 0) ...[
                  _buildAlertsBanner(),
                  const SizedBox(height: 20),
                ],
                _buildScanCta(),
                const SizedBox(height: 20),
                _buildQuickActions(),
                const SizedBox(height: 20),
                _buildSmsBanner(),
                const SizedBox(height: 20),
                _buildRecentScans(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeader() {
    final history = widget.history;

    return Container(
      color: AppColors.primary,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Stay protected,',
                                style: AppTheme.body(14,
                                    color: Colors.white.withValues(alpha: 0.8))),
                            const SizedBox(height: 2),
                            Text('RakshaPay',
                                style: AppTheme.heading(26, color: Colors.white)),
                          ],
                        ),
                      ),
                      _circleIconButton(
                        icon: Icons.cloud_sync_outlined,
                        tooltip: 'Sync scam database',
                        onTap: _syncDatabase,
                      ),
                      const SizedBox(width: 10),
                      _circleIconButton(
                        icon: Icons.settings_outlined,
                        tooltip: 'Settings',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SettingsScreen(
                              engine: widget.engine,
                              history: widget.history,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Safety Score',
                                  style: AppTheme.body(13,
                                      color: Colors.white.withValues(alpha: 0.85))),
                              const SizedBox(height: 4),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text('${history.safetyScore}',
                                      style: AppTheme.heading(38, color: Colors.white)),
                                  const SizedBox(width: 4),
                                  Text('/100',
                                      style: AppTheme.body(16,
                                          color: Colors.white.withValues(alpha: 0.7))),
                                ],
                              ),
                              Text(history.safetyLabel,
                                  style: AppTheme.body(13,
                                      color: const Color(0xFFA5D6A7),
                                      weight: FontWeight.w700)),
                            ],
                          ),
                        ),
                        SafetyScoreRing(score: history.safetyScore),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            // Curved separator into the page background.
            Container(
              height: 22,
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.18),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: Colors.white, size: 21),
          ),
        ),
      ),
    );
  }

  Future<void> _syncDatabase() async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await widget.engine.scamDatabase.sync();
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text(ok
          ? 'Scam database updated (${widget.engine.scamDatabase.cachedVpas.length} known UPI IDs).'
          : 'Sync failed — using the cached database.'),
    ));
  }

  Widget _buildStatsRow() {
    final history = widget.history;
    final stats = [
      (
        label: 'Scans Today',
        value: '${history.scansToday}',
        icon: Icons.qr_code_scanner,
        color: AppColors.primary,
        bg: AppColors.blueTint,
      ),
      (
        label: 'Safe Payments',
        value: '${history.safeToday}',
        icon: Icons.check_circle_outline,
        color: AppColors.safe,
        bg: AppColors.safeBg,
      ),
      (
        label: 'Risks Found',
        value: '${history.risksToday}',
        icon: Icons.warning_amber_rounded,
        color: AppColors.danger,
        bg: AppColors.dangerBg,
      ),
    ];

    return Row(
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: kCardShadow,
              ),
              child: Column(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: stats[i].bg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(stats[i].icon, size: 20, color: stats[i].color),
                  ),
                  const SizedBox(height: 8),
                  Text(stats[i].value,
                      style: AppTheme.heading(22, color: stats[i].color)),
                  const SizedBox(height: 2),
                  Text(
                    stats[i].label,
                    textAlign: TextAlign.center,
                    style: AppTheme.body(11,
                        color: AppColors.muted, weight: FontWeight.w700, height: 1.2),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  int get _riskyCount => widget.history.records.where((r) => r.isRisky).length;

  Widget _buildAlertsBanner() {
    final highRisk = widget.history.records
        .where((r) => r.level == RiskLevel.highRisk)
        .length;
    final isSevere = highRisk > 0;
    final color = isSevere ? AppColors.danger : AppColors.caution;
    final bg = isSevere ? AppColors.dangerBg : AppColors.cautionBg;
    final border = isSevere ? AppColors.dangerBorder : AppColors.cautionBorder;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _openAlerts,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  isSevere ? Icons.dangerous_outlined : Icons.warning_amber_rounded,
                  color: color,
                  size: 25,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSevere
                          ? '$highRisk high-risk alert${highRisk == 1 ? '' : 's'}'
                          : '$_riskyCount alert${_riskyCount == 1 ? '' : 's'} to review',
                      style: AppTheme.body(15,
                          color: color, weight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text('Tap to see what RakshaPay found',
                        style: AppTheme.body(12.5, color: color)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: color),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScanCta() {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _openScanner,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.qr_code_scanner, size: 34, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Scan QR Code',
                        style: AppTheme.heading(20, color: Colors.white)),
                    const SizedBox(height: 2),
                    Text('Check before you pay',
                        style: AppTheme.body(13,
                            color: Colors.white.withValues(alpha: 0.8))),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: Colors.white.withValues(alpha: 0.7), size: 26),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Actions', style: AppTheme.heading(18)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _actionCard(
                icon: Icons.keyboard_alt_outlined,
                iconColor: AppColors.primary,
                iconBg: AppColors.surfaceTint,
                borderColor: AppColors.surfaceTint,
                label: 'Check a UPI ID',
                onTap: _openManualCheck,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _actionCard(
                icon: Icons.flag_outlined,
                iconColor: AppColors.danger,
                iconBg: AppColors.dangerBg,
                borderColor: AppColors.dangerBg,
                label: 'Report a Scam',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ReportScamScreen(engine: widget.engine),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _actionCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required Color borderColor,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
            boxShadow: kCardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, size: 22, color: iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    style: AppTheme.body(13,
                        weight: FontWeight.w800, height: 1.2)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmsBanner() {
    if (_smsMonitoring) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.safeBg,
          border: Border.all(color: AppColors.safeBorder),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            const Icon(Icons.verified_user_outlined, color: AppColors.safe, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Watching your messages for scams',
                  style: AppTheme.body(13,
                      color: AppColors.safe, weight: FontWeight.w700)),
            ),
          ],
        ),
      );
    }

    return Material(
      color: AppColors.cautionBg,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _enableSmsMonitoring,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.cautionBorder),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.sms_outlined, color: AppColors.caution, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Turn on SMS scam alerts',
                        style: AppTheme.body(14,
                            color: AppColors.cautionDeep, weight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(
                      'RakshaPay will check incoming messages on your phone and warn you about scams.',
                      style: AppTheme.body(12.5,
                          color: AppColors.caution, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentScans() {
    final records = widget.history.records.take(6).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent Checks', style: AppTheme.heading(18)),
        const SizedBox(height: 12),
        if (records.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: kCardShadow,
            ),
            child: Column(
              children: [
                const Icon(Icons.history, size: 34, color: AppColors.muted),
                const SizedBox(height: 10),
                Text('No checks yet',
                    style: AppTheme.body(14, weight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  'Scan a QR or check a UPI ID and it will show up here.',
                  textAlign: TextAlign.center,
                  style: AppTheme.body(12.5, color: AppColors.muted, height: 1.4),
                ),
              ],
            ),
          )
        else
          ...records.map(_recentTile),
      ],
    );
  }

  Widget _recentTile(ScanRecord record) {
    final (color, bg, icon, label) = switch (record.level) {
      RiskLevel.safe => (
          AppColors.safe,
          AppColors.safeBg,
          Icons.check_circle_outline,
          'Safe'
        ),
      RiskLevel.caution => (
          AppColors.caution,
          AppColors.cautionBg,
          Icons.warning_amber_rounded,
          'Caution'
        ),
      RiskLevel.highRisk => (
          AppColors.danger,
          AppColors.dangerBg,
          Icons.dangerous_outlined,
          'Risk'
        ),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: kCardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration:
                BoxDecoration(color: bg, borderRadius: BorderRadius.circular(15)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.merchantName?.isNotEmpty == true
                      ? record.merchantName!
                      : (record.vpa.isNotEmpty ? record.vpa : 'Unknown payee'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.body(14, weight: FontWeight.w800),
                ),
                if (record.vpa.isNotEmpty)
                  Text(record.vpa,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.body(12, color: AppColors.muted)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 12, color: AppColors.muted),
                    const SizedBox(width: 4),
                    Text(record.relativeTime,
                        style: AppTheme.body(11.5, color: AppColors.muted)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (record.amount != null && record.amount! > 0)
                Text('₹${record.amount!.toStringAsFixed(0)}',
                    style: AppTheme.body(14, weight: FontWeight.w800)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(label,
                    style: AppTheme.body(11, color: color, weight: FontWeight.w800)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    final items = [
      (icon: Icons.shield_outlined, label: 'Home', badge: 0),
      (icon: Icons.notifications_none, label: 'Alerts', badge: _riskyCount),
      (icon: Icons.qr_code_scanner, label: 'Scan', badge: 0),
      (icon: Icons.settings_outlined, label: 'Settings', badge: 0),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.surfaceTint)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (var i = 0; i < items.length; i++)
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _onNavTap(i),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(items[i].icon,
                                size: 24,
                                color: i == _navIndex
                                    ? AppColors.primary
                                    : AppColors.muted),
                            if (items[i].badge > 0)
                              Positioned(
                                top: -4,
                                right: -7,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  constraints:
                                      const BoxConstraints(minWidth: 16),
                                  decoration: BoxDecoration(
                                    color: AppColors.danger,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: Colors.white, width: 1.5),
                                  ),
                                  child: Text(
                                    '${items[i].badge}',
                                    textAlign: TextAlign.center,
                                    style: AppTheme.body(9.5,
                                        color: Colors.white,
                                        weight: FontWeight.w900),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(items[i].label,
                            style: AppTheme.body(11,
                                color: i == _navIndex
                                    ? AppColors.primary
                                    : AppColors.muted,
                                weight: FontWeight.w800)),
                        const SizedBox(height: 3),
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i == _navIndex
                                ? AppColors.primary
                                : Colors.transparent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _onNavTap(int index) {
    switch (index) {
      case 1:
        _openAlerts();
      case 2:
        _openScanner();
      case 3:
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => SettingsScreen(
            engine: widget.engine,
            history: widget.history,
          ),
        ));
      default:
        setState(() => _navIndex = 0);
    }
  }
}
