import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_colors.dart';

class RevealScreen extends StatelessWidget {
  const RevealScreen({super.key});

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final transcript = app.recordedTranscript;
    final selected = app.sessions.isNotEmpty ? app.sessions.first : null;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Session'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header: duration + date
          Row(
            children: [
              const Icon(Icons.mic_none_rounded, color: Colors.black54),
              const SizedBox(width: 8),
              Text(
                'Recent session',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (selected != null)
            Row(
              children: [
                const Icon(
                  Icons.timer_outlined,
                  size: 18,
                  color: Colors.black54,
                ),
                const SizedBox(width: 6),
                Text(
                  _formatDuration(selected.durationSeconds ?? 0),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.black54),
                ),
              ],
            ),
          const SizedBox(height: 16),

          // Transcript
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your transcript',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    transcript.isNotEmpty
                        ? transcript
                        : 'No transcript available for this session.',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Action steps
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Channel your thoughts into something productive',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...app.actionSteps.map(
                    (e) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 2,
                        ),
                        leading: const Icon(
                          Icons.check_circle_outline,
                          color: AppColors.primary,
                        ),
                        title: Text(e),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Best ideas
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Standout ideas from this session',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...app.bestIdeas.map(
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
          ),

          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.of(context).pushNamed('/micro'),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}
