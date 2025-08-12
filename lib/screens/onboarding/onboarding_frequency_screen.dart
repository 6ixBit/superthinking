import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../supabase/user_profile_api.dart';

class OnboardingFrequencyScreen extends StatefulWidget {
  const OnboardingFrequencyScreen({super.key});

  @override
  State<OnboardingFrequencyScreen> createState() =>
      _OnboardingFrequencyScreenState();
}

class _OnboardingFrequencyScreenState extends State<OnboardingFrequencyScreen> {
  String? _selected;
  final List<String> _options = const ['Rarely', 'Sometimes', 'Often'];

  void _onContinue() async {
    if (_selected == null) return;
    context.read<AppState>().addQuickAnswer(_selected!);
    await UserProfileApi.setOnboardingResponse(
      'overthinking_frequency',
      _selected,
    );
    if (!mounted) return;
    Navigator.of(context).pushNamed('/onboarding-focus');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const PreferredSize(
        preferredSize: Size.fromHeight(56),
        child: _OnboardingHeader(current: 2, total: 4),
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
                            'How often do you overthink?',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 16),
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
          child: FilledButton(
            onPressed: _selected == null ? null : _onContinue,
            child: const Text('Continue'),
          ),
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
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  Navigator.of(context).pushReplacementNamed('/login');
                }
              },
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
