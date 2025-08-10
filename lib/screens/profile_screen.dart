import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_colors.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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

  int _nextStreakTarget(int current) {
    if (current < 3) return 3;
    if (current < 7) return 7;
    if (current < 14) return 14;
    if (current < 30) return 30;
    return current + 7;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final sessions = app.sessions;
    final streak = _computeCurrentStreakDays(sessions);
    final totalSessions = sessions.length;
    final target = _nextStreakTarget(streak);
    final progress = (streak / target).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 16,
        title: Text(
          'Profile',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 24,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Hero gradient card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withOpacity(0.18),
                  AppColors.secondary.withOpacity(0.18),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.12),
                  blurRadius: 24,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.7),
                  ),
                  child: const Icon(
                    CupertinoIcons.sparkles,
                    size: 32,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Supercharging your brain',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 20,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Every SuperThinking session builds focus, optimism, and momentum.',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Metrics grid (responsive)
          _metricsGrid(context, streak: streak, totalSessions: totalSessions),
          const SizedBox(height: 16),

          // Progress toward next badge
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Next streak badge',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Stay consistent for $target days'),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 12,
                      color: AppColors.primary,
                      backgroundColor: Colors.black12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$streak of $target days',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Motivational quote (influential person)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: AppColors.card,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(CupertinoIcons.quote_bubble, color: Colors.black54),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'The mind is everything. What you think you become.',
                        style: TextStyle(fontStyle: FontStyle.italic),
                      ),
                      SizedBox(height: 6),
                      Text('— Buddha', style: TextStyle(color: Colors.black54)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricsGrid(
    BuildContext context, {
    required int streak,
    required int totalSessions,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final maxW = constraints.maxWidth;
        final columns = maxW >= 560 ? 2 : 2; // keep 2 for readability
        final tileW = (maxW - spacing * (columns - 1)) / columns;
        final tiles = <Widget>[
          _metricCard(
            context,
            icon: const Icon(CupertinoIcons.flame, color: Colors.orange),
            value: '$streak',
            label: 'Day streak',
          ),
          _metricCard(
            context,
            icon: const Icon(CupertinoIcons.sparkles, color: Colors.purple),
            value: '$totalSessions',
            label: 'Sessions',
          ),
        ];
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: tiles
              .map((card) => SizedBox(width: tileW, child: card))
              .toList(growable: false),
        );
      },
    );
  }

  Widget _metricCard(
    BuildContext context, {
    required Widget icon,
    required String value,
    required String label,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              value,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                icon,
                const SizedBox(width: 8),
                Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
