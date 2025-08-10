import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_colors.dart';

class RevealScreen extends StatelessWidget {
  const RevealScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('The Reveal')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Look how your thinking just transformed in minutes.',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          _beforeAfter(
            title: 'Before',
            color: AppColors.danger.withOpacity(0.08),
            text: (() {
              final parts = app.recordedTranscript.split('\n');
              return parts.isNotEmpty
                  ? parts.first
                  : 'I am worried this will go wrong…';
            })(),
          ),
          const SizedBox(height: 12),
          _beforeAfter(
            title: 'After',
            color: AppColors.success.withOpacity(0.08),
            text: 'I can turn this into a series of small wins.',
          ),
          const SizedBox(height: 16),
          _bulletSection('✨ 3 best ideas you mentioned', app.bestIdeas),
          _bulletSection(
            '🎯 3 action steps AI distilled from your words',
            app.actionSteps,
          ),
          _bulletSection('💪 A hidden strength you revealed', [
            app.hiddenStrength,
          ]),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.of(context).pushNamed('/micro'),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Widget _beforeAfter({
    required String title,
    required Color color,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(text),
        ],
      ),
    );
  }

  Widget _bulletSection(String title, List<String> items) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...items.map(
              (e) => Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• '),
                  Expanded(child: Text(e)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
