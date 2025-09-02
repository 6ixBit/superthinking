import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../theme/app_colors.dart';

class ValueWelcomeScreen extends StatelessWidget {
  const ValueWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const PreferredSize(
        preferredSize: Size.fromHeight(56),
        child: _OnboardingHeader(current: 14, total: 17),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFE7D1), Color(0x00FFE7D1)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Spacer(),
                  SizedBox(
                    height: 180,
                    child: Lottie.asset(
                      'assets/lottie/Sloth_meditate.json',
                      fit: BoxFit.contain,
                      repeat: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Welcome to SuperThinking',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Built from the ground up based on research and real user interactions, so it works in the moments that matter.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                  const Spacer(flex: 2),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: FilledButton(
            onPressed: () => Navigator.of(context).pushNamed('/value-record'),
            child: const Text('Continue'),
          ),
        ),
      ),
    );
  }
}

class _OnboardingHeader extends StatelessWidget {
  final int current;
  final int total;
  const _OnboardingHeader({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    final progress = current / total;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.black,
              ),
            ),
            Expanded(
              child: Center(
                child: SizedBox(
                  width: 180,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0, 1),
                      minHeight: 8,
                      backgroundColor: Colors.black.withOpacity(0.1),
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}
