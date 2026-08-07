import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Explains what RakshaPay needs and why, before Android's own prompts appear.
///
/// Nothing is requested here — each permission is asked for at the point it's
/// actually used (camera when scanning, SMS when enabling alerts), so declining
/// on this screen still leaves a working app.
class PermissionsScreen extends StatelessWidget {
  final VoidCallback onDone;

  const PermissionsScreen({super.key, required this.onDone});

  static const _items = [
    (
      icon: Icons.camera_alt_outlined,
      title: 'Camera',
      body: 'To scan UPI QR codes. The camera is only on while the scanner is open.',
      tint: AppColors.blueTint,
      color: AppColors.primary,
    ),
    (
      icon: Icons.sms_outlined,
      title: 'SMS',
      body:
          'To spot scam payment messages. Messages are read on your phone and never sent anywhere.',
      tint: AppColors.cautionBg,
      color: AppColors.caution,
    ),
    (
      icon: Icons.volume_up_outlined,
      title: 'Voice alerts',
      body: 'To read warnings aloud in your language, using your phone\'s own voice.',
      tint: AppColors.safeBg,
      color: AppColors.safe,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
              child: Column(
                children: [
                  Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceTint,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(Icons.security,
                        size: 38, color: AppColors.primary),
                  ),
                  const SizedBox(height: 18),
                  Text('What RakshaPay needs', style: AppTheme.heading(24)),
                  const SizedBox(height: 8),
                  Text(
                    'We ask for as little as possible, and only when you use that feature.',
                    textAlign: TextAlign.center,
                    style: AppTheme.body(14, color: AppColors.muted, height: 1.45),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  final item = _items[i];
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: kCardShadow,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: item.tint,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Icon(item.icon, size: 23, color: item.color),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.title,
                                  style: AppTheme.body(15,
                                      weight: FontWeight.w800)),
                              const SizedBox(height: 3),
                              Text(item.body,
                                  style: AppTheme.body(12.5,
                                      color: AppColors.muted, height: 1.4)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onDone,
                      child: const Text('Continue'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You can change these any time in Settings.',
                    style: AppTheme.body(12, color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
