import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../supabase/user_profile_api.dart';
import 'session_detail_screen.dart';

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  int _profileStreak = 0;
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
  void initState() {
    super.initState();
    // Trigger initial load
    Future.microtask(() => context.read<AppState>().loadSessionsFromSupabase());
    Future.microtask(() async {
      final profile = await UserProfileApi.ensureProfile();
      if (!mounted) return;
      setState(() {
        _profileStreak = (profile?['streak_count'] as int?) ?? 0;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final sessions = app.sessions;
    final computed = _computeCurrentStreakDays(sessions);
    final streak = computed > 0 ? computed : _profileStreak;

    if (app.openSessionId != null) {
      return SessionDetailScreen(sessionId: app.openSessionId!);
    }

    final fmt = DateFormat('EEE, MMM d • h:mm a');
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
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
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  color: Colors.orange,
                  size: 26,
                ),
                Positioned(
                  right: -6,
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      '$streak',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: app.loadingSessions
          ? const Center(child: CircularProgressIndicator())
          : sessions.isEmpty
          ? const Center(
              child: Text('No sessions yet. Start a SuperThinking session!'),
            )
          : RefreshIndicator(
              onRefresh: () =>
                  context.read<AppState>().loadSessionsFromSupabase(),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
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
                        context.read<AppState>().setOpenSession(s.id);
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
