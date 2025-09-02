import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../../supabase/user_profile_api.dart';
import '../../theme/app_colors.dart';

class OverthinkingContentScreen extends StatefulWidget {
  const OverthinkingContentScreen({super.key});

  @override
  State<OverthinkingContentScreen> createState() =>
      _OverthinkingContentScreenState();
}

class _OverthinkingContentScreenState extends State<OverthinkingContentScreen> {
  String? _selected;
  bool _saving = false;

  final List<Map<String, dynamic>> _options = [
    {
      'value': 'Problems',
      'title': 'Problems',
      'description': 'Dwelling on issues and challenges',
      'emoji': '⚠️',
    },
    {
      'value': 'Solutions',
      'title': 'Solutions',
      'description': 'Analyzing ways to fix things',
      'emoji': '💡',
    },
    {
      'value': 'Imaginative Scenarios',
      'title': 'Imaginative Scenarios',
      'description': 'Creating hypothetical situations',
      'emoji': '🧠',
    },
  ];

  Future<void> _onContinue() async {
    if (_selected == null) return;

    setState(() => _saving = true);
    try {
      context.read<AppState>().addQuickAnswer(
        'Overthinking content: $_selected',
      );
      await UserProfileApi.setOnboardingResponse(
        'overthinking_content',
        _selected,
      );
      if (!mounted) return;
      Navigator.of(context).pushNamed('/overthinking-impact');
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
        child: _OnboardingHeader(current: 10, total: 17),
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
                            'When you overthink, is it mostly about:',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Understanding your thinking patterns helps us provide better guidance.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 40),

                          // Options
                          ..._options.map(
                            (option) => _OptionButton(
                              label: option['title'],
                              description: option['description'],
                              emoji: option['emoji'],
                              selected: _selected == option['value'],
                              onTap: () =>
                                  setState(() => _selected = option['value']),
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
            onPressed: _selected != null && !_saving ? _onContinue : null,
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

class _OptionButton extends StatelessWidget {
  final String label;
  final String description;
  final String? emoji;
  final bool selected;
  final VoidCallback onTap;

  const _OptionButton({
    required this.label,
    required this.description,
    this.emoji,
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
            children: [
              if (emoji != null)
                Text(emoji!, style: const TextStyle(fontSize: 16)),
              if (emoji != null) const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
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
