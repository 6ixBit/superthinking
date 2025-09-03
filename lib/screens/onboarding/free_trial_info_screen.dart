import 'package:flutter/material.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:lottie/lottie.dart';
import '../../theme/app_colors.dart';
import '../../services/tiktok_events.dart';

class FreeTrialInfoScreen extends StatefulWidget {
  const FreeTrialInfoScreen({super.key});

  @override
  State<FreeTrialInfoScreen> createState() => _FreeTrialInfoScreenState();
}

class _FreeTrialInfoScreenState extends State<FreeTrialInfoScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _firstFade;
  late Animation<double> _secondFade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..forward();

    _firstFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );

    _secondFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _goToPaywall() async {
    try {
      // Fire trial start immediately so it appears in Test Events even if paywall stays open
      await TtEvents.trackTrialStart();
      // Show paywall (don't await)
      RevenueCatUI.presentPaywall();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const PreferredSize(
        preferredSize: Size.fromHeight(56),
        child: _OnboardingHeader(current: 17, total: 17),
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
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Spacer(),
                  SizedBox(
                    height: 160,
                    child: Lottie.asset(
                      'assets/lottie/bell_reminder.json',
                      fit: BoxFit.contain,
                      repeat: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FadeTransition(
                    opacity: _firstFade,
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                        children: const [
                          TextSpan(text: 'We offer '),
                          TextSpan(
                            text: '3 days free ',
                            style: TextStyle(color: Color(0xFFFF6B6B)),
                          ),
                          TextSpan(
                            text: 'so everyone can experience SuperThinking',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FadeTransition(
                    opacity: _secondFade,
                    child: Text(
                      "You'll get a reminder just before your trial ends, no payment is needed now",
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                        height: 1.35,
                      ),
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
            onPressed: _goToPaywall,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              "Let's go",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
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
