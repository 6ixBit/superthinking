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
      body: app.loadingSessions
          ? const Center(child: CircularProgressIndicator())
          : sessions.isEmpty
          ? const Center(
              child: Text('No sessions yet. Start a SuperThinking session!'),
            )
          : SafeArea(
              child: RefreshIndicator(
                onRefresh: () =>
                    context.read<AppState>().loadSessionsFromSupabase(),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  itemCount: sessions.length + 2,
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      // Scrollable header with title + streak
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Sessions',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 22,
                                  ),
                            ),
                            Stack(
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
                          ],
                        ),
                      );
                    }
                    if (i == 1) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: _ConsistencyCalendar(sessions: sessions),
                      );
                    }
                    final s = sessions[i - 2];
                    return Dismissible(
                      key: Key(s.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(
                          Icons.delete_outline,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      confirmDismiss: (direction) async {
                        return await showDialog<bool>(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('Delete Session'),
                              content: const Text(
                                'Are you sure you want to delete this session? This action cannot be undone.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                  child: const Text('Delete'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      onDismissed: (direction) async {
                        final success = await context
                            .read<AppState>()
                            .deleteSession(s.id);
                        if (!success) {
                          // Show error message if deletion failed
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Failed to delete session. Please try again.',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            // Reload sessions to restore the UI
                            context.read<AppState>().loadSessionsFromSupabase();
                          }
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            context.read<AppState>().setOpenSession(s.id);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
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
                                                ?.copyWith(
                                                  color: Colors.black54,
                                                ),
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
                      ),
                    );
                  },
                ),
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

class _ConsistencyCalendar extends StatelessWidget {
  final List<Session> sessions;
  const _ConsistencyCalendar({required this.sessions});

  @override
  Widget build(BuildContext context) {
    // Build a set of active days (date-only)
    final Set<DateTime> activeDays = sessions
        .map(
          (s) => DateTime(s.createdAt.year, s.createdAt.month, s.createdAt.day),
        )
        .toSet();

    // Show last 7 days including today, left to right
    final now = DateTime.now();
    final days = List<DateTime>.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      return DateTime(d.year, d.month, d.day);
    });

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: days.map((date) {
          final isActive = activeDays.contains(date);
          final isToday = date == DateTime(now.year, now.month, now.day);
          final baseColor = isActive ? Colors.green : Colors.red;
          final bgColor = isToday ? baseColor : baseColor.withOpacity(0.6);
          final dayStr = DateFormat('E').format(date); // Mon
          final dateStr = DateFormat('d').format(date); // 8

          return Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  dayStr,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isToday ? Colors.black87 : Colors.black45,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: bgColor,
                    shape: BoxShape.circle,
                    boxShadow: isToday
                        ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                    border: isToday
                        ? Border.all(color: Colors.black.withOpacity(0.2))
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    dateStr,
                    style: TextStyle(
                      color: Colors.white.withOpacity(isToday ? 1 : 0.85),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
