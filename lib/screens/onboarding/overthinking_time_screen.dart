import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:purchases_flutter/purchases_flutter.dart' as rc;

import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../supabase/user_profile_api.dart';
import '../home_shell.dart';

class OverthinkingTimeScreen extends StatefulWidget {
  const OverthinkingTimeScreen({super.key});

  @override
  State<OverthinkingTimeScreen> createState() => _OverthinkingTimeScreenState();
}

class _OverthinkingTimeScreenState extends State<OverthinkingTimeScreen> {
  String? _selected;
  final List<String> _options = const ['Morning', 'Day', 'Evening'];

  Future<void> _continue() async {
    await Permission.notification.request();
    // Apply local state immediately (fast)
    final chosen = _selected;
    if (chosen != null) {
      context.read<AppState>().addQuickAnswer('Overthink time: $chosen');
    }

    if (!mounted) return;
    // Present RevenueCat paywall (hard paywall)
    try {
      await RevenueCatUI.presentPaywall(displayCloseButton: true);
    } catch (_) {}

    if (!mounted) return;

    // Check if user has access (entitlement active). Replace 'pro' if your entitlement id differs.
    bool hasAccess = false;
    try {
      final info = await rc.Purchases.getCustomerInfo();
      hasAccess = info.entitlements.active.isNotEmpty;
    } catch (_) {}

    if (hasAccess) {
      // Navigate to home only if subscribed / has entitlement
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const HomeShell(),
          transitionDuration: const Duration(milliseconds: 160),
          reverseTransitionDuration: const Duration(milliseconds: 160),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
        (route) => false,
      );

      // Run Supabase updates in background
      Future.microtask(() async {
        try {
          if (chosen != null) {
            await UserProfileApi.setPreferredPromptTime(chosen);
          }
          await UserProfileApi.markOnboardingCompleted();
        } catch (_) {}
      });
    } else {
      // Stay on this screen (hard paywall)
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const PreferredSize(
        preferredSize: Size.fromHeight(56),
        child: _OnboardingHeader(current: 4, total: 4),
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
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'When do you tend to overthink?',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'We\'ll time your gentle reminders to match your rhythm.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 20),
                          ..._options.map(
                            (o) => _OptionButton(
                              label: o,
                              selected: _selected == o,
                              onTap: () => setState(() => _selected = o),
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
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // TextButton(
              //   onPressed: () async {
              //     if (!mounted) return;
              //     // Navigate immediately with a lightweight fade
              //     Navigator.of(context).pushAndRemoveUntil(
              //       PageRouteBuilder(
              //         pageBuilder: (_, __, ___) => const HomeShell(),
              //         transitionDuration: const Duration(milliseconds: 160),
              //         reverseTransitionDuration: const Duration(
              //           milliseconds: 160,
              //         ),
              //         transitionsBuilder: (_, animation, __, child) {
              //           return FadeTransition(opacity: animation, child: child);
              //         },
              //       ),
              //       (route) => false,
              //     );
              //     // Mark completion in background
              //     Future.microtask(() async {
              //       try {
              //         await UserProfileApi.markOnboardingCompleted();
              //       } catch (_) {}
              //     });
              //   },
              //   child: Text(
              //     'Set up later',
              //     style: Theme.of(
              //       context,
              //     ).textTheme.bodySmall?.copyWith(color: Colors.black54),
              //   ),
              // ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _selected == null ? null : _continue,
                child: const Text('Continue'),
              ),
            ],
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
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
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
                      backgroundColor: Colors.black12,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$current/$total',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _OptionButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            side: BorderSide(
              color: selected ? AppColors.primary : Colors.black26,
            ),
            foregroundColor: Colors.black,
            backgroundColor: selected
                ? AppColors.primary.withOpacity(0.08)
                : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label),
              if (selected)
                const Icon(Icons.check_circle, color: AppColors.primary)
              else
                const Icon(Icons.circle_outlined, color: Colors.black26),
            ],
          ),
        ),
      ),
    );
  }
}
