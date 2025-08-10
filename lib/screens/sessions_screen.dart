import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

class SessionsScreen extends StatelessWidget {
  const SessionsScreen({super.key});

  int _computeCurrentStreakDays(List<Session> sessions) {
    if (sessions.isEmpty) return 0;
    final days = sessions
        .map(
          (s) => DateTime(s.createdAt.year, s.createdAt.month, s.createdAt.day),
        )
        .toSet();

    int streak = 0;
    DateTime day = DateTime.now();
    while (days.contains(DateTime(day.year, day.month, day.day))) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final sessions = app.sessions;
    final streak = _computeCurrentStreakDays(sessions);

    final fmt = DateFormat('EEE, MMM d • h:mm a');
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 16,
        title: Text(
          'Sessions',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 22,
          ),
        ),
        actions: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.local_fire_department_rounded,
                color: Colors.orange,
              ),
              const SizedBox(width: 6),
              Text(
                '$streak',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ],
      ),
      body: sessions.isEmpty
          ? const Center(
              child: Text('No sessions yet. Start a SuperThinking session!'),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              itemCount: sessions.length,
              itemBuilder: (context, i) {
                final s = sessions[i];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(s.title),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Best ideas'),
                              const SizedBox(height: 6),
                              ...s.ideas.map((e) => Text('- $e')),
                              const SizedBox(height: 12),
                              const Text('Actions'),
                              const SizedBox(height: 6),
                              ...s.actions.map((e) => Text('- $e')),
                              const SizedBox(height: 12),
                              Text('Strength: ${s.strength}'),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      fmt.format(s.createdAt),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: Colors.black54),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.black45,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _StatPill(
                                icon: const Icon(
                                  Icons.lightbulb_outline,
                                  size: 16,
                                ),
                                label: 'Ideas',
                                value: s.ideas.length,
                              ),
                              const SizedBox(width: 8),
                              _StatPill(
                                icon: const Icon(
                                  Icons.check_circle_outline,
                                  size: 16,
                                ),
                                label: 'Actions',
                                value: s.actions.length,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final Widget icon;
  final String label;
  final int value;
  const _StatPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 6),
          Text('$value'),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
