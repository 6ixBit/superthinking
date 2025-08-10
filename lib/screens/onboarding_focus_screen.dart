import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_colors.dart';

class OnboardingFocusScreen extends StatefulWidget {
  const OnboardingFocusScreen({super.key});

  @override
  State<OnboardingFocusScreen> createState() => _OnboardingFocusScreenState();
}

class _OnboardingFocusScreenState extends State<OnboardingFocusScreen> {
  String? _selected;
  final List<String> _options = const ['Problems', 'Possibilities', 'Both'];

  void _onContinue() {
    if (_selected == null) return;
    context.read<AppState>().addQuickAnswer(_selected!);
    Navigator.of(context).pushNamed('/overthinking-time');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PreferredSize(
        preferredSize: Size.fromHeight(56),
        child: _OnboardingHeader(current: 3, total: 4),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'When you overthink, is it mostly…',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _options
                .map(
                  (o) => ChoiceChip(
                    label: Text(o),
                    selected: _selected == o,
                    onSelected: (_) => setState(() => _selected = o),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                )
                .toList(),
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
