import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_colors.dart';

class ActionPlanScreen extends StatelessWidget {
  const ActionPlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('My SuperThinking Plan')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ...List.generate(3, (i) {
            final label = app.actionSteps.length > i
                ? app.actionSteps[i]
                : ['Text Sarah', 'Draft outline', 'Schedule practice'][i];
            return Card(
              child: CheckboxListTile(
                title: Text(label),
                subtitle: const Text('Due: Tomorrow'),
                value: app.actionCompletion[i],
                onChanged: (_) => app.toggleAction(i),
              ),
            );
          }),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: app.actionCompletion.where((c) => c).length / 3,
            backgroundColor: Colors.black12,
            minHeight: 10,
            borderRadius: BorderRadius.circular(8),
            color: AppColors.success,
          ),
          const SizedBox(height: 24),
          Text(
            'Complete 3 days in a row to unlock your first streak badge.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pushNamed('/nudge');
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}
