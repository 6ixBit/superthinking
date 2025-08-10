import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

class SessionsScreen extends StatelessWidget {
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final sessions = app.sessions;
    if (sessions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sessions')),
        body: const Center(
          child: Text('No sessions yet. Start a SuperThinking session!'),
        ),
      );
    }
    final fmt = DateFormat('EEE, MMM d • h:mm a');
    return Scaffold(
      appBar: AppBar(title: const Text('Sessions')),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: sessions.length,
        itemBuilder: (context, i) {
          final s = sessions[i];
          return Card(
            child: ListTile(
              title: Text(s.title),
              subtitle: Text(
                '${fmt.format(s.createdAt)}\n'
                'Ideas: ${s.ideas.length}  •  Actions: ${s.actions.length}',
              ),
              isThreeLine: true,
              onTap: () {
                // For now, just show a summary dialog
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
            ),
          );
        },
      ),
    );
  }
}
