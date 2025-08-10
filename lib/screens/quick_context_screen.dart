import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

class QuickContextScreen extends StatelessWidget {
  const QuickContextScreen({super.key});

  Widget _choiceChips({
    required BuildContext context,
    required List<String> options,
    required void Function(String) onSelect,
  }) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options
          .map(
            (o) => ChoiceChip(
              label: Text(o),
              selected: false,
              onSelected: (_) => onSelect(o),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final challengeController = TextEditingController();
    return Scaffold(
      appBar: AppBar(title: const Text('Quick Context')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('How often do you overthink?'),
                  const SizedBox(height: 12),
                  _choiceChips(
                    context: context,
                    options: const [
                      'Rarely',
                      'Sometimes',
                      'Often',
                      'All the time',
                    ],
                    onSelect: app.addQuickAnswer,
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'When you overthink, is it mostly problems or possibilities?',
                  ),
                  const SizedBox(height: 12),
                  _choiceChips(
                    context: context,
                    options: const ['Problems', 'Possibilities', 'Both'],
                    onSelect: app.addQuickAnswer,
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("What’s your biggest challenge right now?"),
                  const SizedBox(height: 12),
                  TextField(
                    controller: challengeController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'Type a few words…',
                      border: OutlineInputBorder(borderSide: BorderSide.none),
                      filled: true,
                    ),
                    onChanged: app.setChallenge,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pushNamed('/record');
            },
            child: const Text('Start First Session'),
          ),
        ],
      ),
    );
  }
}
