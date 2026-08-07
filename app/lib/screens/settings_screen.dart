import 'package:flutter/material.dart';

import '../services/risk_engine.dart';
import '../services/scan_history_service.dart';
import '../services/tts_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  final RiskEngine engine;
  final ScanHistoryService history;

  const SettingsScreen({super.key, required this.engine, required this.history});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _tts = TtsService();
  String _language = TtsService.languages.first.code;
  Map<String, bool> _voiceAvailable = {};
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _initVoices();
  }

  Future<void> _initVoices() async {
    final saved = await _tts.loadSavedLanguage();
    final availability = await _tts.availability();
    if (!mounted) return;
    setState(() {
      _language = saved;
      _voiceAvailable = availability;
    });
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _sync() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _syncing = true);
    final ok = await widget.engine.scamDatabase.sync();
    if (!mounted) return;
    setState(() => _syncing = false);
    messenger.showSnackBar(SnackBar(
      content: Text(ok
          ? 'Updated — ${widget.engine.scamDatabase.cachedVpas.length} known scam UPI IDs cached.'
          : 'Sync failed. The app keeps using its saved list.'),
    ));
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Clear scan history?', style: AppTheme.heading(18)),
        content: Text(
          'This removes the checks stored on this phone. Reports you already sent are not affected.',
          style: AppTheme.body(14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await widget.history.clear();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _sectionTitle('Voice alerts'),
          _card(
            child: Column(
              children: [
                RadioGroup<String>(
                  groupValue: _language,
                  onChanged: (v) async {
                    final code = v ?? _language;
                    final messenger = ScaffoldMessenger.of(context);
                    setState(() => _language = code);
                    final spoken = await _tts.setLanguage(code);
                    if (!mounted) return;
                    if (!spoken && code != 'en-IN') {
                      messenger.showSnackBar(SnackBar(
                        content: Text(
                          'This phone has no voice for that language yet. '
                          'Install it from Android Settings > Text-to-speech. '
                          'Alerts will be spoken in English until then.',
                        ),
                        duration: const Duration(seconds: 6),
                      ));
                    }
                  },
                  child: Column(
                    children: [
                      for (final lang in TtsService.languages)
                        RadioListTile<String>(
                          value: lang.code,
                          activeColor: AppColors.primary,
                          dense: true,
                          title: Text(lang.label, style: AppTheme.body(14)),
                          subtitle: _voiceAvailable[lang.code] == false
                              ? Text('Voice not installed on this phone',
                                  style: AppTheme.body(11.5,
                                      color: AppColors.caution))
                              : null,
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.surfaceTint),
                ListTile(
                  leading: const Icon(Icons.play_circle_outline,
                      color: AppColors.primary),
                  title: Text('Test the voice',
                      style: AppTheme.body(14, weight: FontWeight.w700)),
                  onTap: () async {
                    await _tts.setLanguage(_language);
                    await _tts.speakSample();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _sectionTitle('Scam database'),
          _card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.cloud_sync_outlined,
                      color: AppColors.primary),
                  title: Text('Sync now',
                      style: AppTheme.body(14, weight: FontWeight.w700)),
                  subtitle: Text(
                    '${widget.engine.scamDatabase.cachedVpas.length} known scam UPI IDs cached',
                    style: AppTheme.body(12.5, color: AppColors.muted),
                  ),
                  trailing: _syncing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right, color: AppColors.muted),
                  onTap: _syncing ? null : _sync,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _sectionTitle('Your data'),
          _card(
            child: Column(
              children: [
                ListTile(
                  leading:
                      const Icon(Icons.history, color: AppColors.primary),
                  title: Text('Scan history',
                      style: AppTheme.body(14, weight: FontWeight.w700)),
                  subtitle: Text(
                    '${widget.history.records.length} checks stored on this phone',
                    style: AppTheme.body(12.5, color: AppColors.muted),
                  ),
                ),
                const Divider(height: 1, color: AppColors.surfaceTint),
                ListTile(
                  leading: const Icon(Icons.delete_outline,
                      color: AppColors.danger),
                  title: Text('Clear scan history',
                      style: AppTheme.body(14,
                          color: AppColors.danger, weight: FontWeight.w700)),
                  onTap: _clearHistory,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _sectionTitle('About'),
          _card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lock_outline,
                          size: 20, color: AppColors.safe),
                      const SizedBox(width: 10),
                      Text('Everything is checked on your phone',
                          style: AppTheme.body(13.5, weight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'RakshaPay never uploads your QR codes, messages or notifications. '
                    'Only scam reports you choose to send, and an anonymous risk level, leave the device.\n\n'
                    'RakshaPay does not process payments and is not a bank or UPI app.',
                    style: AppTheme.body(12.5, color: AppColors.muted, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 4),
        child: Text(text, style: AppTheme.heading(17)),
      );

  Widget _card({required Widget child}) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: kCardShadow,
        ),
        child: child,
      );
}
