import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../supabase/supabase_client.dart';

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
    final String userEmail =
        SupabaseService.client.auth.currentUser?.email ?? 'user@example.com';

    return Scaffold(
      appBar: null,
      body: SafeArea(
        top: true,
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
          children: [
            // Mascot and email
            Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white,
                  backgroundImage: const AssetImage(
                    'assets/superthinking_profile.png',
                  ),
                  onBackgroundImageError: (_, __) {},
                ),
                const SizedBox(height: 8),
                Text(
                  userEmail,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.black54),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Next streak badge at the top
            Card(
              margin: EdgeInsets.zero,
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
            const SizedBox(height: 16),
            // Metrics grid
            _metricsGrid(context, streak: streak, totalSessions: totalSessions),
            const SizedBox(height: 16),
            // Hero gradient card moved near the bottom
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
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 56),
            // Logout button
            OutlinedButton.icon(
              onPressed: () async {
                try {
                  await SupabaseService.client.auth.signOut();
                } catch (_) {}
                if (context.mounted) {
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/login', (route) => false);
                }
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: BorderSide(color: AppColors.danger, width: 1.2),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
              icon: const Icon(Icons.logout),
              label: const Text('Log out'),
            ),
          ],
        ),
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
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 6),
                icon,
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
