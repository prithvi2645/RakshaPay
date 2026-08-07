import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Brand splash shown while the on-device models load.
///
/// Model loading is real work (two files off disk plus an ONNX session), so
/// this doubles as the loading state rather than being a fixed timer.
class SplashScreen extends StatelessWidget {
  final String status;

  const SplashScreen({super.key, this.status = 'Loading protection...'});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.navy, Color(0xFF1A2A5E), AppColors.navy],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(36),
                ),
                child: Center(
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: const Icon(Icons.shield_outlined,
                        size: 46, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 26),
              Text('RakshaPay', style: AppTheme.heading(38, color: Colors.white)),
              const SizedBox(height: 8),
              Text(
                'Your fraud shield before you pay',
                style: AppTheme.body(15, color: Colors.white.withValues(alpha: 0.75)),
              ),
              const Spacer(),
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              ),
              const SizedBox(height: 14),
              Text(status,
                  style:
                      AppTheme.body(13, color: Colors.white.withValues(alpha: 0.7))),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
