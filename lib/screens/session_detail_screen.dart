import 'package:flutter/material.dart';
import '../supabase/session_api.dart';
import '../theme/app_colors.dart';
import 'loading_session_screen.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import 'package:confetti/confetti.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class SessionDetailScreen extends StatefulWidget {
  final String sessionId;
  final String? initialTranscript;
  final int? initialDurationSeconds;

  const SessionDetailScreen({
    super.key,
    required this.sessionId,
    this.initialTranscript,
    this.initialDurationSeconds,
  });

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  SessionRecord? _record;
  bool _loading = true;
  final ConfettiController _confetti = ConfettiController(
    duration: const Duration(milliseconds: 800),
  );
  final Set<int> _completed = <int>{};
  bool _transcriptExpanded = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _confetti.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final rec = await SessionApi.fetchSessionById(widget.sessionId);
    if (!mounted) return;
    setState(() {
      _record = rec;
      _loading = false;

      // Initialize completed actions based on database status
      _completed.clear();
      if (rec != null) {
        for (int i = 0; i < rec.actions.length; i++) {
          if (rec.actions[i].status == 'completed') {
            _completed.add(i);
          }
        }
      }
    });

    // If session is still processing, set up periodic refresh
    if (rec != null &&
        (rec.processingStatus == 'processing' ||
            rec.processingStatus == 'pending')) {
      _startPeriodicRefresh();
    }
  }

  void _startPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final rec = await SessionApi.fetchSessionById(widget.sessionId);
      if (!mounted) return;

      setState(() {
        _record = rec;

        // Update completed actions based on database status
        _completed.clear();
        if (rec != null) {
          for (int i = 0; i < rec.actions.length; i++) {
            if (rec.actions[i].status == 'completed') {
              _completed.add(i);
            }
          }
        }
      });

      // Stop refreshing if processing is complete
      if (rec != null && rec.processingStatus == 'completed') {
        timer.cancel();
      }
    });
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _formatSessionDate(DateTime? createdAt) {
    if (createdAt == null) return '';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sessionDate = DateTime(
      createdAt.year,
      createdAt.month,
      createdAt.day,
    );

    if (sessionDate == today) {
      return 'Today';
    } else if (sessionDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return DateFormat('MMM d').format(createdAt);
    }
  }

  void _toggleStep(int index) async {
    if (_record == null || index >= _record!.actions.length) return;

    final action = _record!.actions[index];
    final isCompleted = _completed.contains(index);
    final newStatus = isCompleted ? 'pending' : 'completed';

    print('[SessionDetail] Toggling action $index: ${action.description}');
    print('[SessionDetail] Action ID: ${action.id}');
    print('[SessionDetail] Current status: ${action.status}');
    print('[SessionDetail] New status: $newStatus');

    // Update local state immediately for responsive UI
    setState(() {
      if (isCompleted) {
        _completed.remove(index);
      } else {
        _completed.add(index);
        _confetti.play();
      }
    });

    // Update database in background
    try {
      final success = await SessionApi.updateActionItemStatus(
        action.id,
        newStatus,
      );
      if (!success) {
        print('[SessionDetail] Database update failed, reverting UI');
        // Revert local state if database update failed
        setState(() {
          if (isCompleted) {
            _completed.add(index);
          } else {
            _completed.remove(index);
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update action item. Please try again.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        print('[SessionDetail] Database update successful');
      }
    } catch (e) {
      print('[SessionDetail] Error updating action item: $e');
      // Revert local state on error
      setState(() {
        if (isCompleted) {
          _completed.add(index);
        } else {
          _completed.remove(index);
        }
      });
    }
  }

  bool _shouldTruncateTranscript(String text) {
    // Count approximate lines by counting characters
    // Roughly 50-60 characters per line on mobile
    return text.length > 240; // ~4 lines worth of text
  }

  String _getTruncatedTranscript(String text) {
    if (!_shouldTruncateTranscript(text) || _transcriptExpanded) {
      return text;
    }

    // Find a good break point around 4 lines (240 chars)
    int breakPoint = 240;
    if (text.length > breakPoint) {
      // Try to break at a sentence or word boundary
      int lastPeriod = text.lastIndexOf('.', breakPoint);
      int lastSpace = text.lastIndexOf(' ', breakPoint);

      if (lastPeriod > breakPoint - 50) {
        breakPoint = lastPeriod + 1;
      } else if (lastSpace > breakPoint - 20) {
        breakPoint = lastSpace;
      }

      return text.substring(0, breakPoint).trim();
    }

    return text;
  }

  Widget _buildLoadingState() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // Header section with close button and session title
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Close button and title row
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        final app = context.read<AppState>();
                        if (app.openSessionId != null) {
                          app.setOpenSession(null);
                          return;
                        }
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                      },
                      tooltip: 'Close',
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _record?.title ?? 'Processing Session...',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Date and duration stacked tightly
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.mic_none_rounded,
                          color: Colors.black54,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatSessionDate(_record?.createdAt),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          size: 18,
                          color: Colors.black54,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatDuration(
                            widget.initialDurationSeconds ??
                                _record?.durationSeconds ??
                                0,
                          ),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.black54),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Rest of content with padding
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Duration row
              Row(
                children: [
                  const Icon(
                    Icons.timer_outlined,
                    size: 18,
                    color: Colors.black54,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatDuration(
                      widget.initialDurationSeconds ??
                          _record?.durationSeconds ??
                          0,
                    ),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.black54),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Processing indicator
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Analyzing your session...',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'We\'re transcribing your audio and generating insights. This usually takes 30-60 seconds.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Show transcript if available from recording
              if (_getDisplayTranscript() != null) ...[
                Text(
                  'Your words',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Text(
                  _getDisplayTranscript()!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.black54,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String? _getDisplayTranscript() {
    // Prefer stored transcript from app state, fallback to database, then initial
    final app = context.watch<AppState>();
    final stored = app.getSessionTranscript(widget.sessionId);
    return stored ?? _record?.transcript ?? widget.initialTranscript;
  }

  Widget _buildShiftScoreSection() {
    if (_record?.analysis == null) return const SizedBox.shrink();

    final analysis = _record!.analysis!;
    final shiftScore = analysis.shiftPercentage;
    final problemFocus = analysis.problemFocusPercentage;
    final solutionFocus = analysis.solutionFocusPercentage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Attributes',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),

        // Progress visualization
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.red.withOpacity(0.1),
                Colors.amber.withOpacity(0.1),
                Colors.green.withOpacity(0.1),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withOpacity(0.2), width: 1),
          ),
          child: Column(
            children: [
              // Progress bars
              _buildProgressBar(
                'Problem-focused',
                problemFocus,
                Colors.red.shade400,
              ),
              const SizedBox(height: 12),
              _buildProgressBar(
                'Solution-focused',
                solutionFocus,
                Colors.green.shade400,
              ),
              const SizedBox(height: 12),
              _buildProgressBar(
                'Thinking shift',
                shiftScore,
                AppColors.primary,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar(String label, int percentage, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
            Text(
              '$percentage%',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: percentage / 100,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildThinkingStyleBadge() {
    if (_record?.analysis == null) return const SizedBox.shrink();

    final thinkingStyle = _record!.analysis!.thinkingStyleToday;
    final styleInfo = _getThinkingStyleInfo(thinkingStyle);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Thinking Style',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: styleInfo['color'].withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: styleInfo['color'].withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: styleInfo['color'],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(styleInfo['icon'], color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      styleInfo['name'],
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: styleInfo['color'],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      styleInfo['description'],
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
      ],
    );
  }

  Map<String, dynamic> _getThinkingStyleInfo(String style) {
    switch (style.toLowerCase()) {
      case 'vision mapper':
        return {
          'name': 'Vision Mapper',
          'description':
              'Great at imagining possibilities and exploring "what if" scenarios',
          'color': Colors.purple.shade600,
          'icon': Icons.visibility_outlined,
        };
      case 'strategic connector':
        return {
          'name': 'Strategic Connector',
          'description':
              'Logical and methodical, excelling at step-by-step planning',
          'color': Colors.blue.shade600,
          'icon': Icons.account_tree_outlined,
        };
      case 'creative explorer':
        return {
          'name': 'Creative Explorer',
          'description':
              'Innovative and unconventional, finding unique solutions',
          'color': Colors.orange.shade600,
          'icon': Icons.lightbulb_outline,
        };
      case 'reflective processor':
        return {
          'name': 'Reflective Processor',
          'description':
              'Deep and contemplative, processing complex thoughts thoroughly',
          'color': Colors.teal.shade600,
          'icon': Icons.psychology_outlined,
        };
      default:
        return {
          'name': 'Balanced Thinker',
          'description': 'Adapting thinking style based on the situation',
          'color': Colors.grey.shade600,
          'icon': Icons.balance_outlined,
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    final duration =
        widget.initialDurationSeconds ?? _record?.durationSeconds ?? 0;
    final transcript = _getDisplayTranscript();

    // Show loading state only when backend is processing
    final isProcessing =
        _record?.processingStatus == 'processing' ||
        _record?.processingStatus == 'pending';

    // When fetching the record for the first time, show a small spinner
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Do not redirect to analyzing screen from here; render what we have
    final content = ListView(
      padding: EdgeInsets.zero,
      children: [
        // Header section with close button and session title
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Close button and title row
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        final app = context.read<AppState>();
                        if (app.openSessionId != null) {
                          app.setOpenSession(null);
                          return;
                        }
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                      },
                      tooltip: 'Close',
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _record?.title ?? 'Session Summary',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Date and duration stacked tightly
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.mic_none_rounded,
                          color: Colors.black54,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatSessionDate(_record?.createdAt),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          size: 18,
                          color: Colors.black54,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatDuration(duration),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.black54),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Rest of content with padding and bottom spacing to avoid nav overlap
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thinking Style Badge
              if (_record?.analysis != null) ...[
                _buildThinkingStyleBadge(),
                const SizedBox(height: 24),
              ],

              // Transcript section
              if (transcript != null && transcript.isNotEmpty) ...[
                Text(
                  'Your words',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Text(
                  _getTruncatedTranscript(transcript),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.black54,
                    height: 1.35,
                  ),
                ),
                if (_shouldTruncateTranscript(transcript)) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _transcriptExpanded = !_transcriptExpanded;
                      });
                    },
                    child: Text(
                      _transcriptExpanded ? 'Read less' : 'Read more',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 40),
              ],

              // Next Steps section
              Text(
                'Next Steps',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              if (_record != null && _record!.actions.isNotEmpty) ...[
                ...List.generate(_record!.actions.length, (i) {
                  final action = _record!.actions[i];
                  final done = _completed.contains(i);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _toggleStep(i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 8,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              done ? Icons.check_circle : Icons.circle_outlined,
                              color: done ? AppColors.primary : Colors.black26,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                action.description,
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(
                                      decoration: done
                                          ? TextDecoration.lineThrough
                                          : TextDecoration.none,
                                      color: done
                                          ? Colors.black45
                                          : Colors.black87,
                                      decorationThickness: 2,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ] else ...[
                Text(
                  'No actions generated yet.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                ),
              ],

              const SizedBox(height: 40),

              // Standout ideas section
              if (_record != null && _record!.ideas.isNotEmpty) ...[
                Text(
                  'Standout ideas',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                ...List.generate(_record!.ideas.length, (i) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '• ',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            _record!.ideas[i],
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 24),
              ],

              // Analysis insights (if available)
              if (_record?.analysis != null) ...[
                Text(
                  'Session Insights',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                if (_record!.analysis!.summaryAfter.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.withOpacity(0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Key Insights',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.green.shade700,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _record!.analysis!.summaryAfter,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(height: 1.35),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_record!.analysis!.strengthHighlight.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Strength Highlight',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _record!.analysis!.strengthHighlight,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
              ],

              // Attributes and Progress Visualization
              if (_record!.analysis != null) ...[
                const SizedBox(height: 32),
                _buildShiftScoreSection(),
              ],
            ],
          ),
        ),
      ],
    );

    return WillPopScope(
      onWillPop: () async {
        // Handle back gesture the same way as close button
        final app = context.read<AppState>();
        if (app.openSessionId != null) {
          app.setOpenSession(null);
          return false; // Prevent default back navigation
        }
        return true; // Allow normal back navigation
      },
      child: Scaffold(
        body: Stack(
          children: [
            content,
            // Subtle confetti overlay when completing a step
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confetti,
                blastDirectionality: BlastDirectionality.explosive,
                emissionFrequency: 0.0,
                numberOfParticles: 18,
                gravity: 0.6,
                colors: const [
                  AppColors.primary,
                  Colors.blueAccent,
                  Colors.orange,
                  Colors.green,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
