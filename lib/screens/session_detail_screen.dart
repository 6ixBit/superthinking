import 'package:flutter/material.dart';
import '../supabase/session_api.dart';
import '../theme/app_colors.dart';
import '../supabase/pattern_analysis_api.dart';
import '../supabase/pattern_exploration_insights_api.dart';
import 'pattern_exploration_screen.dart';
import 'loading_session_screen.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import 'package:confetti/confetti.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../services/notification_manager.dart';
import 'package:audioplayers/audioplayers.dart';

class SessionDetailScreen extends StatefulWidget {
  final String sessionId;
  final String? initialTranscript;
  final int? initialDurationSeconds;
  final int? initialTabIndex;

  const SessionDetailScreen({
    super.key,
    required this.sessionId,
    this.initialTranscript,
    this.initialDurationSeconds,
    this.initialTabIndex,
  });

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  SessionRecord? _record;
  bool _loading = true;
  final ConfettiController _confetti = ConfettiController(
    duration: const Duration(milliseconds: 1200),
  );
  final Set<int> _completed = <int>{};
  bool _transcriptExpanded = false;
  Timer? _refreshTimer;

  // Pattern analysis state
  PatternAnalysisResult? _patternAnalysis;
  bool _isAnalyzingPatterns = false;
  bool _patternSectionDismissed = false;

  // Pattern exploration insights state
  PatternExplorationInsight? _explorationInsights;

  // Audio player
  AudioPlayer? _audioPlayer;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  // Observed TabController for auto-refresh on Action tab
  TabController? _observedTabController;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _confetti.dispose();
    _refreshTimer?.cancel();
    _audioPlayer?.dispose();
    _observedTabController?.removeListener(_onTabChanged);
    super.dispose();
  }

  void _onTabChanged() {
    if (_observedTabController == null) return;
    if (!_observedTabController!.indexIsChanging &&
        _observedTabController!.index == 1) {
      // Auto-refresh when switching to Action tab
      _refreshActionTab();
    }
  }

  Future<void> _refreshActionTab() async {
    final rec = await SessionApi.fetchSessionById(widget.sessionId);
    if (!mounted) return;
    setState(() {
      _record = rec;
      _completed.clear();
      if (rec != null) {
        for (int i = 0; i < rec.actions.length; i++) {
          if (rec.actions[i].status == 'completed') {
            _completed.add(i);
          }
        }
      }
    });
    await _loadExplorationInsights();
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

    // Initialize audio player if session has audio
    if (rec != null && rec.audioUrl != null) {
      _initializeAudioPlayer(rec.audioUrl!);
    }

    // If session is still processing, set up periodic refresh
    if (rec != null &&
        (rec.processingStatus == 'processing' ||
            rec.processingStatus == 'pending')) {
      _startPeriodicRefresh();
    }

    // Trigger pattern analysis if session is completed
    if (rec != null && rec.processingStatus == 'completed') {
      _analyzePatterns();
      _loadExplorationInsights();
    }

    // If we're starting on the Action tab (from pattern exploration), reload insights
    if (widget.initialTabIndex == 1) {
      _loadExplorationInsights();
    }
  }

  void _initializeAudioPlayer(String audioUrl) {
    _audioPlayer = AudioPlayer();

    // Set up event listeners
    _audioPlayer!.onDurationChanged.listen((Duration duration) {
      setState(() {
        _duration = duration;
      });
    });

    _audioPlayer!.onPositionChanged.listen((Duration position) {
      setState(() {
        _position = position;
      });
    });

    _audioPlayer!.onPlayerComplete.listen((_) {
      setState(() {
        _isPlaying = false;
        _position = Duration.zero;
      });
    });

    // Set the audio source
    _audioPlayer!.setSourceUrl(audioUrl);
  }

  Future<void> _togglePlayPause() async {
    if (_audioPlayer == null) return;

    if (_isPlaying) {
      await _audioPlayer!.pause();
      setState(() {
        _isPlaying = false;
      });
    } else {
      await _audioPlayer!.resume();
      setState(() {
        _isPlaying = true;
      });
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

        // Schedule notifications when session is completed
        NotificationManager.onSessionCompleted();

        // Send notification for session analysis completion
        NotificationManager.onSessionAnalysisComplete(widget.sessionId);

        // Trigger pattern analysis now that session is completed
        _analyzePatterns();

        // Load exploration insights
        _loadExplorationInsights();
      }
    });
  }

  Future<void> _confirmAndDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _StyledDialog(
        title: 'Delete session?',
        primaryColor: Colors.red,
        secondaryColor: Colors.orange,
        content: Text(
          'This will permanently delete this session and its insights.',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final ok = await SessionApi.deleteSession(widget.sessionId);
      if (ok) {
        final app = context.read<AppState>();
        await app.deleteSession(widget.sessionId);
        app.setOpenSession(null);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Session deleted')));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete session')),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete session')),
        );
      }
    }
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _formatDurationFromDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Widget _buildAudioVisualizer() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(5, (index) {
        final height = _isPlaying
            ? 4.0 +
                  (index * 2.0) +
                  (DateTime.now().millisecondsSinceEpoch % 1000 / 1000 * 8)
            : 4.0;
        return Container(
          width: 3,
          height: height,
          decoration: BoxDecoration(
            color: _isPlaying ? AppColors.primary : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }

  String _formatSessionDate(DateTime? createdAt) {
    if (createdAt == null) return '';
    return DateFormat('EEE, MMM d').format(createdAt);
  }

  String _formatSessionTime(DateTime? createdAt) {
    if (createdAt == null) return '';
    return DateFormat('h:mm a').format(createdAt);
  }

  void _toggleStep(int index) async {
    if (_record == null || index >= _record!.actions.length) return;

    final action = _record!.actions[index];
    final isCompleted = _completed.contains(index);
    final newStatus = isCompleted ? 'pending' : 'completed';

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
        // Trigger notification manager when task is completed
        if (newStatus == 'completed') {
          NotificationManager.onTaskCompleted();
        }
      }
    } catch (e) {
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

  void _showAddActionDialog() {
    if (_record == null) return;

    final controller = TextEditingController();
    showDialog<String>(
      context: context,
      builder: (ctx) => _StyledDialog(
        title: 'New action',
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Describe a small next step…',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.95),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    ).then((added) async {
      if (added == null || added.isEmpty) return;

      final newItem = await SessionApi.createActionItem(
        sessionId: _record!.id,
        description: added,
        source: 'user_stated',
        priority: 'medium',
      );

      if (newItem != null && mounted) {
        setState(() {
          _record!.actions.add(newItem);
        });
      }
    });
  }

  Future<void> _deleteActionItem(int index) async {
    if (_record == null || index >= _record!.actions.length) return;

    final action = _record!.actions[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _StyledDialog(
        title: 'Delete action?',
        primaryColor: Colors.red,
        secondaryColor: Colors.orange,
        content: Text(
          'Are you sure you want to delete this action: "${action.description}"?',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final ok = await SessionApi.deleteActionItem(actionItemId: action.id);
      if (ok) {
        setState(() {
          _record = SessionRecord(
            id: _record!.id,
            createdAt: _record!.createdAt,
            durationSeconds: _record!.durationSeconds,
            ideas: _record!.ideas,
            actions: List.from(_record!.actions)..removeAt(index),
            transcript: _record!.transcript,
            processingStatus: _record!.processingStatus,
            analysis: _record!.analysis,
            title: _record!.title,
          );
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Action item deleted'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete action item')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete action item')),
        );
      }
    }
  }

  bool _shouldTruncateTranscript(String text) {
    // Count approximate lines by counting characters
    // Roughly 50-60 characters per line on mobile
    return text.length > 240;
  }

  String _getTruncatedTranscript(String text) {
    if (!_shouldTruncateTranscript(text) || _transcriptExpanded) {
      return text;
    }

    // Find a good break point around 4 lines (240 chars)
    int breakPoint = 140;
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
                    // const SizedBox(width: 8),
                    // Expanded(
                    //   child: Text(
                    //     _record?.title ?? 'Processing Session...',
                    //     textAlign: TextAlign.center,
                    //     style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    //       fontWeight: FontWeight.w700,
                    //     ),
                    //   ),
                    // ),
                  ],
                ),
                const SizedBox(height: 16),
                // (moved) date & duration now rendered below advice
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
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        // Show personalized analysis if available, otherwise show chart only
        if (analysis.attributeAnalysis != null &&
            analysis.attributeAnalysis!.trim().isNotEmpty)
          Text(
            analysis.attributeAnalysis!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.black54,
              height: 1.35,
            ),
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
          'Today you are a ',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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

  // New: Header builder (close button + title)
  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        10,
        MediaQuery.of(context).padding.top + 16,
        10,
        8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 260),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.12),
                          width: 1,
                        ),
                      ),
                      child: Stack(
                        children: [
                          TabBar(
                            labelColor: AppColors.primary,
                            unselectedLabelColor: Colors.black54,
                            labelStyle: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                            unselectedLabelStyle: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w400),
                            indicator: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            indicatorPadding: const EdgeInsets.all(4),
                            dividerColor: Colors.transparent,
                            overlayColor: MaterialStateProperty.all(
                              Colors.transparent,
                            ),
                            splashFactory: NoSplash.splashFactory,
                            tabs: const [
                              Tab(text: 'Insights'),
                              Tab(text: 'Take Action'),
                            ],
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            top: 8,
                            bottom: 8,
                            child: Center(
                              child: Container(
                                width: 1,
                                color: Colors.black.withOpacity(0.1),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              PopupMenuButton<String>(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (value) async {
                  if (value == 'delete') {
                    await _confirmAndDelete();
                  } else if (value == 'edit_title') {
                    if (_record == null) return;
                    final controller = TextEditingController(
                      text: _record!.title ?? '',
                    );
                    final newTitle = await showDialog<String>(
                      context: context,
                      builder: (ctx) => _StyledDialog(
                        title: 'Edit title',
                        content: TextField(
                          controller: controller,
                          autofocus: true,
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            hintText: 'Session title',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.95),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () =>
                                Navigator.of(ctx).pop(controller.text.trim()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                    );
                    if (newTitle == null) return;
                    final trimmed = newTitle.trim();
                    if (trimmed.isEmpty) return;
                    final ok = await SessionApi.updateSessionTitle(
                      sessionId: _record!.id,
                      title: trimmed,
                    );
                    if (ok && mounted) {
                      setState(() {
                        _record = SessionRecord(
                          id: _record!.id,
                          createdAt: _record!.createdAt,
                          durationSeconds: _record!.durationSeconds,
                          ideas: _record!.ideas,
                          actions: _record!.actions,
                          transcript: _record!.transcript,
                          processingStatus: _record!.processingStatus,
                          analysis: _record!.analysis,
                          title: trimmed,
                        );
                      });
                    }
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'edit_title',
                    child: Row(
                      children: const [
                        Icon(Icons.edit_outlined),
                        SizedBox(width: 8),
                        Text('Edit title'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete_outline, color: Colors.red),
                        const SizedBox(width: 8),
                        const Text(
                          'Delete session',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
                icon: const Icon(Icons.more_vert),
                tooltip: 'Options',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // New: Insights tab content
  Widget _buildInsightsTab() {
    final duration =
        widget.initialDurationSeconds ?? _record?.durationSeconds ?? 0;
    final transcript = _getDisplayTranscript();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 96),
      children: [
        Row(
          children: [
            const Icon(Icons.timer_outlined, size: 18, color: Colors.black54),
            const SizedBox(width: 6),
            Text(
              _formatDuration(duration),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.black54),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.calendar_today_outlined, color: Colors.black54),
            const SizedBox(width: 6),
            Text(
              _formatSessionDate(_record?.createdAt),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.black54),
            ),
            const Spacer(),
            Text(
              _formatSessionTime(_record?.createdAt),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.black54),
            ),
          ],
        ),
        const SizedBox(height: 32),
        if (_record?.analysis?.gentleAdvice != null &&
            _record!.analysis!.gentleAdvice.trim().isNotEmpty) ...[
          Stack(
            clipBehavior: Clip.none,
            children: [_ThoughtBubble(text: _record!.analysis!.gentleAdvice)],
          ),
          const SizedBox(height: 32),
        ],
        if (_record?.analysis != null) ...[
          _buildShiftScoreSection(),
          const SizedBox(height: 40),
          Text(
            'Session Insights',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          if (_record!.analysis!.summaryAfter.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withValues(alpha: 0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🗝️ Key Insights',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
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
        ],
        if (transcript != null && transcript.isNotEmpty) ...[
          const SizedBox(height: 40),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Your words',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (_record?.audioUrl != null) ...[
                        const Spacer(),
                        IconButton(
                          onPressed: _togglePlayPause,
                          icon: Icon(
                            _isPlaying
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_filled,
                            size: 24,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 60,
                          height: 20,
                          child: _buildAudioVisualizer(),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDurationFromDuration(_duration),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Colors.black54,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '"${_getTruncatedTranscript(transcript)}"',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.black54,
                      height: 1.35,
                    ),
                  ),
                  if (_shouldTruncateTranscript(transcript)) ...[
                    const SizedBox(height: 12),
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
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  // New: Action tab content
  Widget _buildActionsTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await _refreshActionTab();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 30, 20, 96),
        children: [
          // Commented out for now while implementing pattern detection
          // if (_record?.analysis != null) ...[
          //   _buildThinkingStyleBadge(),
          //   const SizedBox(height: 24),
          // ],
          _buildPatternDetectionSection(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Your next steps',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'Add action',
                onPressed: () => _showAddActionDialog(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_record != null && _record!.actions.isNotEmpty) ...[
            ...List.generate(_record!.actions.length, (i) {
              final action = _record!.actions[i];
              final done = _completed.contains(i);
              final isFromDeepExploration =
                  action.source == 'deeper_exploration';

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Dismissible(
                  key: Key('action_${action.id}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.delete,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  onDismissed: (direction) async {
                    await _deleteActionItem(i);
                  },
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _toggleStep(i),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: isFromDeepExploration
                            ? Border.all(
                                color: AppColors.primary.withOpacity(0.3),
                                width: 1,
                              )
                            : null,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
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
                                          : isFromDeepExploration
                                          ? AppColors.primary
                                          : Colors.black87,
                                      decorationThickness: 2,
                                      fontWeight: isFromDeepExploration
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                              ),
                            ),
                            if (isFromDeepExploration) ...[
                              const SizedBox(width: 8),
                              Icon(
                                Icons.psychology,
                                size: 16,
                                color: AppColors.primary.withOpacity(0.7),
                              ),
                            ],
                          ],
                        ),
                      ),
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
          const SizedBox(height: 16),
          _buildDeeperInsightsSection(),
        ],
      ),
    );
  }

  // Pattern detection section for deeper insights
  Widget _buildPatternDetectionSection() {
    // Don't show if dismissed or still analyzing
    if (_patternSectionDismissed) return const SizedBox.shrink();

    // Show loading state while analyzing
    if (_isAnalyzingPatterns) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Analyzing thinking patterns...',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.black54),
            ),
          ],
        ),
      );
    }

    // Don't show if no patterns detected
    if (_patternAnalysis == null || !_patternAnalysis!.hasPatterns) {
      return const SizedBox.shrink();
    }

    final pattern = _patternAnalysis!.primaryPattern!;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pattern Detected: ${_formatPatternType(pattern.type)}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            pattern.description,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.black87),
          ),
          if (_patternAnalysis!.insightPreview != null) ...[
            const SizedBox(height: 8),
            Text(
              _patternAnalysis!.insightPreview!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.black54,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: _explorationInsights == null
                ? ElevatedButton(
                    onPressed: () {
                      _startDeeperExploration();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Explore This'),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Future<void> _loadExplorationInsights() async {
    if (_record?.id == null) return;

    try {
      final insights =
          await PatternExplorationInsightsApi.getInsightsForSession(
            _record!.id,
          );
      if (mounted) {
        setState(() {
          _explorationInsights = insights;
        });
      }
    } catch (e) {
      print('Failed to load exploration insights: $e');
    }
  }

  String _formatPatternType(String type) {
    switch (type.toLowerCase()) {
      case 'rumination':
        return 'Rumination';
      case 'catastrophizing':
        return 'Catastrophizing';
      case 'perfectionism':
        return 'Perfectionism';
      case 'avoidance':
        return 'Avoidance';
      case 'overthinking':
        return 'Overthinking';
      case 'self_doubt':
        return 'Self-Doubt';
      case 'people_pleasing':
        return 'People-Pleasing';
      case 'comparison':
        return 'Comparison';
      case 'procrastination':
        return 'Procrastination';
      case 'decision_paralysis':
        return 'Decision Paralysis';
      default:
        return type
            .replaceAll('_', ' ')
            .split(' ')
            .map(
              (word) => word.isNotEmpty
                  ? word[0].toUpperCase() + word.substring(1)
                  : word,
            )
            .join(' ');
    }
  }

  Future<void> _startDeeperExploration() async {
    if (_patternAnalysis == null || _record?.id == null) return;

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => PatternExplorationScreen(
          sessionId: _record!.id,
          patternAnalysis: _patternAnalysis!,
        ),
      ),
    );

    // If exploration succeeded, switch to Action tab and refresh data explicitly
    if (result == true && mounted) {
      if (_observedTabController != null) {
        _observedTabController!.animateTo(1); // Action tab
      }
      await _refreshActionTab();
    }
  }

  Widget _buildDeeperInsightsSection() {
    if (_explorationInsights == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb, color: Colors.purple.shade600, size: 20),
              const SizedBox(width: 8),
              Text(
                'Deeper Insights',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.purple.shade600,
                ),
              ),
            ],
          ),
          if (_explorationInsights!.insight != null) ...[
            const SizedBox(height: 12),
            Text(
              _explorationInsights!.insight!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.black87,
                height: 1.4,
              ),
            ),
          ],
          // key_realization hidden for now
          if (_explorationInsights!.encouragement != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _explorationInsights!.encouragement!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.green.shade800,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _analyzePatterns() async {
    if (_record?.id == null || _isAnalyzingPatterns) return;

    setState(() {
      _isAnalyzingPatterns = true;
    });

    try {
      final result = await PatternAnalysisApi.analyzeSessionPatterns(
        _record!.id,
      );
      if (mounted) {
        setState(() {
          _patternAnalysis = result;
          _isAnalyzingPatterns = false;
        });
      }
    } catch (e) {
      print('Pattern analysis failed: $e');
      if (mounted) {
        setState(() {
          _isAnalyzingPatterns = false;
        });
      }
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

    // Tabbed content
    final content = DefaultTabController(
      length: 2,
      initialIndex: widget.initialTabIndex ?? 0,
      child: Column(
        children: [
          _buildHeader(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 2),
            child: Center(
              child: Text(
                _record?.title ?? 'Session Summary',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          Expanded(
            child: Builder(
              builder: (innerContext) {
                final controller = DefaultTabController.of(innerContext);
                if (controller != null &&
                    controller != _observedTabController) {
                  _observedTabController?.removeListener(_onTabChanged);
                  _observedTabController = controller;
                  _observedTabController!.addListener(_onTabChanged);
                }
                return TabBarView(
                  children: [_buildInsightsTab(), _buildActionsTab()],
                );
              },
            ),
          ),
        ],
      ),
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

class _ThoughtBubble extends StatelessWidget {
  final String text;

  const _ThoughtBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.0),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.18),
            AppColors.secondary.withValues(alpha: 0.18),
          ],
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Colors.black87,
          fontWeight: FontWeight.w600,
          fontSize: 16,
          height: 1.4,
        ),
      ),
    );
  }
}

class _ThoughtDots extends StatelessWidget {
  const _ThoughtDots();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        // Largest dot
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.4),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Medium dot
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.35),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 3),
        // Smallest dot
        Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}

class _ThoughtBubbleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;

    // Create main rounded rectangle only
    const radius = 20.0;
    path.addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, w, h),
        const Radius.circular(radius),
      ),
    );

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class _StyledDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final List<Widget> actions;
  final Color? primaryColor;
  final Color? secondaryColor;

  const _StyledDialog({
    required this.title,
    required this.content,
    required this.actions,
    this.primaryColor,
    this.secondaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final primary = primaryColor ?? AppColors.primary;
    final secondary = secondaryColor ?? AppColors.secondary;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              primary.withValues(alpha: 0.18),
              secondary.withValues(alpha: 0.18),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: primary.withValues(alpha: 0.12),
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
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 16),
              content,
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: actions,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
