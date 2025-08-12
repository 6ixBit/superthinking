import 'package:flutter/material.dart';
import '../supabase/session_api.dart';
import '../theme/app_colors.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import 'package:confetti/confetti.dart';
import 'package:intl/intl.dart';

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
  List<String> _nextSteps = const [];
  bool _transcriptExpanded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final rec = await SessionApi.fetchSessionById(widget.sessionId);
    if (!mounted) return;
    setState(() {
      _record = rec;
      _loading = false;
      _nextSteps = (rec != null && rec.actions.isNotEmpty)
          ? List<String>.from(rec.actions)
          : <String>[
              'Text Sarah for presentation feedback',
              'Draft a 1-page outline',
              'Schedule a 20‑min practice run',
            ];
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

  void _toggleStep(int index) {
    setState(() {
      if (_completed.contains(index)) {
        _completed.remove(index);
      } else {
        _completed.add(index);
        _confetti.play();
      }
    });
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

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final stored = app.getSessionTranscript(widget.sessionId);
    final transcript = stored ?? widget.initialTranscript; // prefer stored
    final duration =
        widget.initialDurationSeconds ?? _record?.durationSeconds ?? 0;

    final content = ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Header section
        Row(
          children: [
            const Icon(Icons.mic_none_rounded, color: Colors.black54),
            const SizedBox(width: 8),
            Text(
              'Session Summary',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Duration and date row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
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
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.black54),
                ),
              ],
            ),
            Text(
              _formatSessionDate(_record?.createdAt),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // Transcript section
        if (transcript != null) ...[
          Text(
            'Your words',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          if (transcript.isNotEmpty) ...[
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
          ] else ...[
            Text(
              'No transcript available for this session.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.black54,
                height: 1.35,
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
        ...List.generate(_nextSteps.length, (i) {
          final done = _completed.contains(i);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _toggleStep(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
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
                        _nextSteps[i],
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          decoration: done
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          color: done ? Colors.black45 : Colors.black87,
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
        if (_nextSteps.isEmpty)
          Text(
            'No actions yet.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),

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

        // Confetti widget
      ],
    );

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Session'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
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
    );
  }
}
