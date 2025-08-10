import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

class MicroVictoryScreen extends StatefulWidget {
  const MicroVictoryScreen({super.key});

  @override
  State<MicroVictoryScreen> createState() => _MicroVictoryScreenState();
}

class _MicroVictoryScreenState extends State<MicroVictoryScreen> {
  bool done = false;
  late final ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 1));
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final first = app.actionSteps.isNotEmpty
        ? app.actionSteps.first
        : 'Text Sarah for presentation feedback';
    return Scaffold(
      appBar: AppBar(title: const Text('First Action')),
      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('✅ First, easiest action'),
                          const SizedBox(height: 8),
                          Text(
                            first,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () async {
                              setState(() => done = true);
                              _confetti.play();
                              await Future.delayed(
                                const Duration(milliseconds: 600),
                              );
                              if (!mounted) return;
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('First win activated!'),
                                  content: const Text(
                                    "You’re already in motion. Keep going!",
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      child: const Text('Nice'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            child: const Text('Do It Now'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(context).pushNamed('/plan');
                    },
                    child: const Text('Next'),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 20,
              maxBlastForce: 30,
              minBlastForce: 10,
              emissionFrequency: 0.01,
              gravity: 0.6,
              colors: const [
                Colors.deepPurple,
                Colors.teal,
                Colors.green,
                Colors.white,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
