import 'package:flutter/material.dart';

class NextSessionNudgeScreen extends StatelessWidget {
  const NextSessionNudgeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('See You Tomorrow')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your mind gets stronger with every SuperThinking session.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            const Text('3 more and we’ll unlock your personal style profile.'),
            const Spacer(),
            FilledButton(
              onPressed: () => Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/home', (route) => false),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}
