import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;

  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = [
    (
      icon: Icons.qr_code_scanner,
      title: 'Check before you pay',
      body:
          'Scan any UPI QR code and RakshaPay tells you if it looks safe — before you enter your PIN.',
      tint: AppColors.blueTint,
      color: AppColors.primary,
    ),
    (
      icon: Icons.sms_outlined,
      title: 'Catch scam messages',
      body:
          'RakshaPay reads payment SMS on your phone and warns you about KYC, refund and OTP scams.',
      tint: AppColors.cautionBg,
      color: AppColors.caution,
    ),
    (
      icon: Icons.lock_outline,
      title: 'Your data stays yours',
      body:
          'All checking happens on your phone. Your messages and QR codes are never uploaded anywhere.',
      tint: AppColors.safeBg,
      color: AppColors.safe,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page == _pages.length - 1) {
      widget.onDone();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 12, top: 6),
                child: TextButton(
                  onPressed: widget.onDone,
                  child: Text('Skip',
                      style: AppTheme.body(14,
                          color: AppColors.muted, weight: FontWeight.w700)),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) {
                  final page = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            color: page.tint,
                            borderRadius: BorderRadius.circular(46),
                          ),
                          child: Icon(page.icon, size: 74, color: page.color),
                        ),
                        const SizedBox(height: 38),
                        Text(page.title,
                            textAlign: TextAlign.center,
                            style: AppTheme.heading(26)),
                        const SizedBox(height: 14),
                        Text(
                          page.body,
                          textAlign: TextAlign.center,
                          style: AppTheme.body(15,
                              color: AppColors.muted, height: 1.5),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pages.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _page ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page ? AppColors.primary : AppColors.surfaceTint,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  child: Text(_page == _pages.length - 1 ? 'Get Started' : 'Next'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
