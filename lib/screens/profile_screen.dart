import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../supabase/supabase_client.dart';
import '../supabase/user_profile_api.dart';
import '../supabase/session_api.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _streak = 0;
  int _totalSessions = 0;
  int _totalCompletedActions = 0;
  int _totalActions = 0;
  String? _dominantThinkingStyle;
  bool _loading = true;

  String _thinkingStyleSubtitle(String style) {
    final s = style.toLowerCase();
    switch (s) {
      case 'vision mapper':
        return "You're future‑focused and imaginative — keep translating “what if” into one small next step.";
      case 'strategic connector':
        return "You're methodical and clear — keep turning clarity into consistent action.";
      case 'creative explorer':
        return "You're inventive and curious — channel ideas into tiny experiments.";
      case 'reflective processor':
        return "You're thoughtful and deep — turn insights into gentle, doable steps.";
      default:
        return "You're adapting your thinking to the moment — keep turning clarity into consistent, kind action.";
    }
  }

  int _computeCurrentStreakDaysFromDates(Iterable<DateTime> sessionDates) {
    if (sessionDates.isEmpty) return 0;
    final days = sessionDates
        .map((d) => DateTime(d.year, d.month, d.day))
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
  void initState() {
    super.initState();
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    setState(() => _loading = true);
    try {
      // Try from profile
      final profile = await UserProfileApi.ensureProfile();
      int streak = (profile?['streak_count'] as int?) ?? 0;
      int totalSessions = (profile?['total_sessions'] as int?) ?? 0;

      // Fallback to sessions compute
      if (streak == 0 || totalSessions == 0) {
        final records = await SessionApi.fetchSessionsForCurrentUser();
        totalSessions = records.length;
        final dates = records.map((r) => r.createdAt);
        streak = _computeCurrentStreakDaysFromDates(dates);
      }

      if (!mounted) return;
      setState(() {
        _streak = streak;
        _totalSessions = totalSessions;
        _totalCompletedActions = 0; // will populate below
        _totalActions = 0;
      });

      // Fetch total completed actions
      final completedActions =
          await SessionApi.countCompletedActionItemsForCurrentUser();
      final totalActions =
          await SessionApi.countTotalActionItemsForCurrentUser();
      final dominantStyle =
          await SessionApi.fetchDominantThinkingStyleForCurrentUser();
      if (mounted) {
        setState(() {
          _totalCompletedActions = completedActions;
          _totalActions = totalActions;
          _dominantThinkingStyle = dominantStyle;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _streak = 0;
        _totalSessions = 0;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showBugReportDialog() async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => _FeedbackDialog(
        title: 'Report a Bug',
        titleController: titleController,
        descriptionController: descriptionController,
        titleHint: 'Brief description of the bug',
        descriptionHint: 'Please describe what happened, what you expected, and steps to reproduce the issue...',
        submitLabel: 'Report Bug',
        type: 'bug',
      ),
    );

    if (result != null) {
      await _submitFeedback('bug', result['title']!, result['description']!);
    }
  }

  Future<void> _showFeatureRequestDialog() async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => _FeedbackDialog(
        title: 'Request a Feature',
        titleController: titleController,
        descriptionController: descriptionController,
        titleHint: 'Feature name or summary',
        descriptionHint: 'Please describe the feature you\'d like to see, how it would help you, and any specific details...',
        submitLabel: 'Submit Request',
        type: 'feature_request',
      ),
    );

    if (result != null) {
      await _submitFeedback('feature_request', result['title']!, result['description']!);
    }
  }

  Future<void> _submitFeedback(String type, String title, String description) async {
    try {
      final user = SupabaseService.client.auth.currentUser;
      if (user == null) return;

      await SupabaseService.client.from('feedback').insert({
        'user_id': user.id,
        'type': type,
        'title': title,
        'description': description,
        'user_email': user.email,
        'device_info': {
          'platform': Theme.of(context).platform.name,
          'app_version': '1.0.0', // You can get this from package_info_plus
        },
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              type == 'bug' 
                ? 'Bug report submitted successfully!' 
                : 'Feature request submitted successfully!'
            ),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final target = _nextStreakTarget(_streak);
    final progress = (_streak / target).clamp(0.0, 1.0);
    final String userEmail =
        SupabaseService.client.auth.currentUser?.email ?? 'user@example.com';

    return Scaffold(
      appBar: null,
      body: SafeArea(
        top: true,
        bottom: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: () async {
                  await _loadMetrics();
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 110),
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
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.black54),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_dominantThinkingStyle != null) ...[
                      // Dominant Thinking Style card (gradient style)
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
                                Icons.psychology_alt_outlined,
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
                                    _dominantThinkingStyle ?? 'Thinking Style',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 20,
                                        ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _thinkingStyleSubtitle(
                                      _dominantThinkingStyle!,
                                    ),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(color: Colors.black87),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Next streak badge at the top
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Next streak target',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
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
                              '$_streak of $target days',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Metrics grid
                    _metricsGrid(
                      context,
                      streak: _streak,
                      totalSessions: _totalSessions,
                    ),
                    const SizedBox(height: 16),
                    // Completed Actions card (same style as streak badge)
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Number on top with icon on the right
                            Row(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Text(
                                    '${_totalCompletedActions}/${_totalActions}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.check_circle_outline,
                                  color: Colors.green,
                                  size: 24,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            // Text below with left padding
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Text(
                                'Daily actions completed',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Account & Support actions
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Support',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Delete your account?'),
                                      content: const Text(
                                        'This will permanently remove your data. This action will be available soon.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(ctx).pop(false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(ctx).pop(true),
                                          child: const Text('OK'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true && mounted) {
                                    // Attempt deletion via edge function
                                    final ok =
                                        await UserProfileApi.deleteAccount();
                                    if (ok) {
                                      try {
                                        await SupabaseService.client.auth
                                            .signOut();
                                      } catch (_) {}
                                      if (context.mounted) {
                                        Navigator.of(
                                          context,
                                        ).pushNamedAndRemoveUntil(
                                          '/login',
                                          (route) => false,
                                        );
                                      }
                                    } else {
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Failed to delete account',
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.danger,
                                  side: BorderSide(
                                    color: AppColors.danger,
                                    width: 1.2,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  textStyle: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                icon: const Icon(Icons.delete_forever_outlined),
                                label: const Text('Delete your account'),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _showBugReportDialog,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  side: BorderSide(
                                    color: AppColors.primary,
                                    width: 1.2,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  textStyle: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                icon: const Icon(Icons.bug_report_outlined),
                                label: const Text('Report a bug'),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _showFeatureRequestDialog,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.black87,
                                  side: const BorderSide(
                                    color: Colors.black54,
                                    width: 1.2,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  textStyle: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                icon: const Icon(Icons.lightbulb_outline),
                                label: const Text('Request a feature'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Hero gradient card moved near the bottom (temporarily hidden)
                    // Container(
                    //   padding: const EdgeInsets.all(20),
                    //   decoration: BoxDecoration(
                    //     borderRadius: BorderRadius.circular(24),
                    //     gradient: LinearGradient(
                    //       begin: Alignment.topLeft,
                    //       end: Alignment.bottomRight,
                    //       colors: [
                    //         AppColors.primary.withOpacity(0.18),
                    //         AppColors.secondary.withOpacity(0.18),
                    //       ],
                    //     ),
                    //     boxShadow: [
                    //       BoxShadow(
                    //         color: AppColors.primary.withOpacity(0.12),
                    //         blurRadius: 24,
                    //         spreadRadius: 2,
                    //         offset: const Offset(0, 8),
                    //       ),
                    //     ],
                    //   ),
                    //   child: Row(
                    //     children: [
                    //       Container(
                    //         width: 64,
                    //         height: 64,
                    //         decoration: BoxDecoration(
                    //           shape: BoxShape.circle,
                    //           color: Colors.white.withOpacity(0.7),
                    //         ),
                    //         child: const Icon(
                    //           CupertinoIcons.sparkles,
                    //           size: 32,
                    //           color: Colors.black87,
                    //         ),
                    //       ),
                    //       const SizedBox(width: 16),
                    //       Expanded(
                    //         child: Column(
                    //           crossAxisAlignment: CrossAxisAlignment.start,
                    //           children: [
                    //             Text(
                    //               'Supercharging your brain',
                    //               style: Theme.of(context).textTheme.titleMedium
                    //                   ?.copyWith(
                    //                     fontWeight: FontWeight.w700,
                    //                     fontSize: 20,
                    //                   ),
                    //             ),
                    //             const SizedBox(height: 6),
                    //             Text(
                    //               'Every SuperThinking session builds focus, optimism, and momentum.',
                    //               style: Theme.of(context).textTheme.bodyMedium
                    //                   ?.copyWith(color: Colors.black87),
                    //             ),
                    //           ],
                    //         ),
                    //       ),
                    //     ],
                    //   ),
                    // ),
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
                          vertical: 22,
                        ),
                        minimumSize: const Size.fromHeight(52),
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

class _FeedbackDialog extends StatelessWidget {
  final String title;
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final String titleHint;
  final String descriptionHint;
  final String submitLabel;
  final String type;

  const _FeedbackDialog({
    required this.title,
    required this.titleController,
    required this.descriptionController,
    required this.titleHint,
    required this.descriptionHint,
    required this.submitLabel,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withValues(alpha: 0.18),
              AppColors.secondary.withValues(alpha: 0.18),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.12),
              blurRadius: 24,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: Colors.white.withValues(alpha: 0.9),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 20),
              // Title field
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'Title',
                  hintText: titleHint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.95),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                maxLength: 200,
              ),
              const SizedBox(height: 12),
              // Description field
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  hintText: descriptionHint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.95),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                maxLines: 4,
                maxLength: 1000,
              ),
              const SizedBox(height: 24),
              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      final title = titleController.text.trim();
                      final description = descriptionController.text.trim();
                      
                      if (title.isEmpty || description.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please fill in both title and description'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      
                      Navigator.of(context).pop({
                        'title': title,
                        'description': description,
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: type == 'bug' ? Colors.red : AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(submitLabel),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
