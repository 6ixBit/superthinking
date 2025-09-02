import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../../supabase/user_profile_api.dart';
import '../../theme/app_colors.dart';

class OverthinkingTriggersScreen extends StatefulWidget {
  const OverthinkingTriggersScreen({super.key});

  @override
  State<OverthinkingTriggersScreen> createState() =>
      _OverthinkingTriggersScreenState();
}

class _OverthinkingTriggersScreenState
    extends State<OverthinkingTriggersScreen> {
  final Set<String> _selectedTriggers = {};
  bool _saving = false;

  final List<String> _triggers = [
    'Life 🌱',
    'Family 👨‍👩‍👧‍👦',
    'Friends 👥',
    'Relationships ❤️',
    'Finances 💰',
  ];

  void _toggleTrigger(String trigger) {
    setState(() {
      if (_selectedTriggers.contains(trigger)) {
        _selectedTriggers.remove(trigger);
      } else {
        _selectedTriggers.add(trigger);
      }
    });
  }

  Future<void> _onContinue() async {
    if (_selectedTriggers.isEmpty) return;

    setState(() => _saving = true);
    try {
      final triggersString = _selectedTriggers.join(', ');
      context.read<AppState>().addQuickAnswer(
        'Overthinking triggers: $triggersString',
      );
      await UserProfileApi.setOnboardingResponse(
        'overthinking_triggers',
        triggersString,
      );
      if (!mounted) return;
      Navigator.of(context).pushNamed('/onboarding-frequency');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const PreferredSize(
        preferredSize: Size.fromHeight(56),
        child: _OnboardingHeader(current: 8, total: 17),
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
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          const SizedBox(height: 40),
                          Text(
                            'What are some triggers for your overthinking?',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 40),

                          // Trigger options
                          ..._triggers.map(
                            (trigger) => _TriggerOption(
                              trigger: trigger,
                              isSelected: _selectedTriggers.contains(trigger),
                              onTap: () => _toggleTrigger(trigger),
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
            onPressed: _selectedTriggers.isNotEmpty && !_saving
                ? _onContinue
                : null,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Continue'),
          ),
        ),
      ),
    );
  }
}

class _TriggerOption extends StatelessWidget {
  final String trigger;
  final bool isSelected;
  final VoidCallback onTap;

  const _TriggerOption({
    required this.trigger,
    required this.isSelected,
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
              color: isSelected ? AppColors.primary : Colors.black26,
            ),
            foregroundColor: Colors.black,
            backgroundColor: isSelected
                ? AppColors.primary.withOpacity(0.08)
                : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  trigger,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              if (isSelected)
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
            Text(
              '$current/$total',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.black),
            ),
          ],
        ),
      ),
    );
  }
}
