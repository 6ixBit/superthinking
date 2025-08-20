import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:async';
import 'dart:io';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../supabase/session_repo.dart';
import '../services/storage.dart';
import '../supabase/supabase_client.dart';
import '../services/live_suggestions_service.dart';
import 'loading_session_screen.dart';

// Helper for unawaited
void unawaited(Future<void> future) {
  // ignore: unawaited_futures
  future;
}

class RecordSessionScreen extends StatefulWidget {
  const RecordSessionScreen({super.key});

  @override
  State<RecordSessionScreen> createState() => _RecordSessionScreenState();
}

class _RecordSessionScreenState extends State<RecordSessionScreen> {
  bool isRecording = false;
  String transcript = '';
  Timer? _suggestionTimer;
  String? _currentSuggestion;
  int _suggestionRequestCount = 0;

  late final stt.SpeechToText _speech;
  final AudioRecorder _recorder = AudioRecorder();

  Duration _recordElapsed = Duration.zero;
  Timer? _recordTimer;
  final List<Map<String, dynamic>> _promptEvents = [];

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _getDayOfWeek(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Monday';
      case DateTime.tuesday:
        return 'Tuesday';
      case DateTime.wednesday:
        return 'Wednesday';
      case DateTime.thursday:
        return 'Thursday';
      case DateTime.friday:
        return 'Friday';
      case DateTime.saturday:
        return 'Saturday';
      case DateTime.sunday:
        return 'Sunday';
      default:
        return '';
    }
  }

  String _getMonth(int month) {
    switch (month) {
      case 1:
        return 'Jan';
      case 2:
        return 'Feb';
      case 3:
        return 'Mar';
      case 4:
        return 'Apr';
      case 5:
        return 'May';
      case 6:
        return 'Jun';
      case 7:
        return 'Jul';
      case 8:
        return 'Aug';
      case 9:
        return 'Sep';
      case 10:
        return 'Oct';
      case 11:
        return 'Nov';
      case 12:
        return 'Dec';
      default:
        return '';
    }
  }

  int _generateActiveUserCount() {
    // Generate a realistic number based on time of day
    final now = DateTime.now();
    final hour = now.hour;

    // Base number varies by hour to simulate realistic usage patterns
    int base;
    if (hour >= 6 && hour <= 9) {
      base = 45 + (hour - 6) * 15; // Morning: 45-90
    } else if (hour >= 10 && hour <= 17) {
      base = 60 + (hour - 10) * 8; // Day: 60-116
    } else if (hour >= 18 && hour <= 22) {
      base = 80 + (hour - 18) * 10; // Evening: 80-120
    } else {
      base = 25 + hour * 2; // Night/early morning: 25-45
    }

    // Add some variation based on minutes for more dynamic feel
    final variation = (now.minute % 10) - 5;
    final result = base + variation;

    return math.max(30, result); // Minimum 30
  }

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  void _startLiveSuggestionsLoop() {
    _suggestionTimer?.cancel();
    // First request ~10–12s, subsequent requests randomized 15–40s
    _suggestionTimer = Timer(const Duration(seconds: 1), () async {
      if (!mounted || !isRecording) return;
      // Schedule next tick first to avoid drift
      final isFirst = _suggestionRequestCount == 0;
      final nextIn = isFirst
          ? 10 +
                math.Random().nextInt(3) // 10..12
          : 15 + math.Random().nextInt(46); // 15..60
      _suggestionTimer = Timer(
        Duration(seconds: nextIn),
        _startLiveSuggestionsLoop,
      );

      final current = transcript.trim();
      if (current.isEmpty) return;

      final windowed = current.length > 1000
          ? current.substring(current.length - 1000)
          : current;
      // Clear current suggestion right before sending the next request
      setState(() {
        _currentSuggestion = null;
      });

      final suggestions = await LiveSuggestionsService.fetchSuggestions(
        transcript: windowed,
      );
      if (!mounted || !isRecording) return;
      if (suggestions.isEmpty) return;

      setState(() {
        _currentSuggestion = suggestions.first.trim();
        if (_currentSuggestion != null && _currentSuggestion!.isNotEmpty) {
          _promptEvents.add({
            'text': _currentSuggestion,
            'ts_seconds': _recordElapsed.inSeconds,
            'source': 'ai_dynamic',
          });
        }
        _suggestionRequestCount += 1;
      });
    });
  }

  // Removed queue rotation; we only show the first suggestion per response
  // void _startQueueRotation() { ... }

  Future<void> _startRecording() async {
    print('[RecordSession] Starting recording...');
    setState(() {
      isRecording = true;
      _recordElapsed = Duration.zero;
      transcript = '';
      _promptEvents.clear();
      _currentSuggestion = null;
    });

    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _recordElapsed += const Duration(seconds: 1);
      });
    });

    // Start file recording
    print('[RecordSession] Checking microphone permission...');
    final hasPerm = await _recorder.hasPermission();
    print('[RecordSession] Has permission: $hasPerm');
    if (hasPerm) {
      final dir = await getTemporaryDirectory();
      final path = p.join(
        dir.path,
        'session_${DateTime.now().millisecondsSinceEpoch}.m4a',
      );
      print('[RecordSession] Starting file recording to: $path');
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      print('[RecordSession] File recording started successfully');
    } else {
      print('[RecordSession] WARNING: No microphone permission!');
    }

    // Initialize speech recognition
    print('[RecordSession] Initializing speech recognition...');
    final available = await _speech.initialize(
      onStatus: (s) {
        print('[RecordSession] Speech status: $s');
      },
      onError: (e) {
        print('[RecordSession] Speech error: $e');
      },
    );
    print('[RecordSession] Speech available: $available');
    if (available) {
      await _speech.listen(
        onResult: (r) {
          setState(() {
            final words = r.recognizedWords.trim();
            if (words.isNotEmpty) {
              // Always update with the latest recognized words
              // speech_to_text accumulates words automatically
              transcript = words;
              print(
                '[RecordSession] Transcript updated: "${words.substring(0, math.min(50, words.length))}..."',
              );
            }
          });
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          partialResults: true,
          cancelOnError: false,
        ),
        pauseFor: const Duration(minutes: 30),
        listenFor: const Duration(hours: 1),
        localeId: null,
      );
      print('[RecordSession] Speech listening started');
      _startLiveSuggestionsLoop();
      // Removed static prompt loop in favor of dynamic, context-aware suggestions
      // Dynamic suggestions are recorded as prompt events when fetched
    }
  }

  Future<void> _stopRecording() async {
    if (!isRecording) return;
    print('[RecordSession] Stopping recording...');
    _recordTimer?.cancel();
    _suggestionTimer?.cancel();
    // Keep recording UI until we navigate to analyzing to avoid a flash

    if (_speech.isListening) {
      print('[RecordSession] Stopping speech recognition...');
      await _speech.stop();
    }

    // Stop file recording and upload
    String? audioFilePath;
    if (await _recorder.isRecording()) {
      print('[RecordSession] Stopping file recording...');
      audioFilePath = await _recorder.stop();
      print('[RecordSession] File recording stopped. Path: $audioFilePath');
    } else {
      print(
        '[RecordSession] WARNING: Recorder was not recording when we tried to stop',
      );
    }

    context.read<AppState>().setTranscript(transcript);
    context.read<AppState>().synthesizeMagic();
    try {
      print('[RecordSession] Creating pending session...');
      final sessionId = await SessionRepo.createPendingSession(
        durationSeconds: _recordElapsed.inSeconds,
        promptsShown: List<Map<String, dynamic>>.from(_promptEvents),
      );
      print('[RecordSession] Session created with ID: $sessionId');
      if (!mounted) return;
      context.read<AppState>().setSessionTranscript(sessionId, transcript);
      context.read<AppState>().setOpenSession(sessionId);

      // Upload and trigger processing in background
      if (audioFilePath != null) {
        print(
          '[RecordSession] Starting background upload for audio file: $audioFilePath',
        );
        unawaited(() async {
          try {
            print('[RecordSession] Getting current user...');
            final user = SupabaseService.client.auth.currentUser;
            if (user == null) {
              print('[RecordSession] ERROR: No authenticated user found!');
              return;
            }
            print('[RecordSession] User ID: ${user.id}');

            print('[RecordSession] Uploading audio file...');
            final url = await StorageService.uploadAudioFile(
              file: File(audioFilePath!),
              userId: user.id,
              sessionId: sessionId,
            );
            print('[RecordSession] Upload successful. URL: $url');

            print('[RecordSession] Attaching audio and starting processing...');
            await SessionRepo.attachAudioAndStartProcessing(
              sessionId: sessionId,
              audioUrl: url,
            );
            print('[RecordSession] Processing started successfully');
          } catch (e, stackTrace) {
            print('[RecordSession] ERROR in background upload: $e');
            print('[RecordSession] Stack trace: $stackTrace');
          }
        }());
      } else {
        print('[RecordSession] WARNING: No audio file path to upload');
      }
      // Navigate directly to our existing analyzing screen for this session
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => LoadingSessionScreen(sessionId: sessionId),
          ),
        );
      }
      return;
    } catch (e, stackTrace) {
      print('[RecordSession] ERROR creating session: $e');
      print('[RecordSession] Stack trace: $stackTrace');
      // On error, go home
      if (mounted) {
        Navigator.of(context).pushNamed('/home');
      }
    }
    if (!mounted) return;
    Navigator.of(context).pushNamed('/home');
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _suggestionTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dayOfWeek = _getDayOfWeek(now.weekday);
    final month = _getMonth(now.month);

    return Scaffold(
      appBar: null,
      body: Stack(
        children: [
          const Positioned.fill(child: IgnorePointer(child: OracleAura())),
          // Date layout - day on left, date on right
          Positioned(
            top: MediaQuery.of(context).padding.top + 32,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Happy ' + dayOfWeek,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF8B7355),
                      letterSpacing: -0.2,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '$month ${now.day} ${now.year}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF8B7355),
                      letterSpacing: -0.2,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 4),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'What’s on your mind',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    fontStyle: FontStyle.italic,
                                    fontWeight: FontWeight.w600,
                                    height: 1.2,
                                    letterSpacing: -0.2,
                                    fontSize: 27,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'right now?',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.4,
                                    fontSize: 30,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      GestureDetector(
                        onTap: () {
                          isRecording ? _stopRecording() : _startRecording();
                        },
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: isRecording
                                ? AppColors.danger.withOpacity(0.9)
                                : AppColors.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.3),
                                blurRadius: 24,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Icon(
                            isRecording
                                ? CupertinoIcons.stop_fill
                                : CupertinoIcons.mic,
                            color: Colors.white,
                            size: 44,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (isRecording)
                        Text(
                          _formatDuration(_recordElapsed),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.black54),
                        ),
                      if (isRecording) const SizedBox(height: 4),
                      if (isRecording)
                        Text(
                          'Tap to stop when you’re ready',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.black54),
                        ),
                      const SizedBox(height: 36),
                      if (isRecording)
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_currentSuggestion != null)
                              _SpeechBubble(text: _currentSuggestion!),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
          if (isRecording) const SizedBox.shrink(),
          // Community indicator
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 100,
            left: 0,
            right: 0,
            child: Center(
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '${_generateActiveUserCount()}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF8B7355),
                        letterSpacing: -0.2,
                        fontSize: 16,
                      ),
                    ),
                    TextSpan(
                      text: ' people are SuperThinking right now',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF8B7355),
                        letterSpacing: -0.2,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  final String text;
  const _SpeechBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline, size: 18, color: Colors.amber),
          const SizedBox(width: 8),
          Flexible(child: Text(text, textAlign: TextAlign.left)),
        ],
      ),
    );
  }
}

class OracleAura extends StatefulWidget {
  const OracleAura({super.key});

  @override
  State<OracleAura> createState() => _OracleAuraState();
}

class _OracleAuraState extends State<OracleAura>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late DateTime _start;
  double _elapsedSec = 0;

  @override
  void initState() {
    super.initState();
    _start = DateTime.now();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..addListener(() {
            final now = DateTime.now();
            _elapsedSec = now.difference(_start).inMilliseconds / 1000.0;
            setState(() {});
          });
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _AuroraPainter(timeSec: _elapsedSec));
  }
}

class _AuroraPainter extends CustomPainter {
  final double timeSec;
  _AuroraPainter({required this.timeSec});

  @override
  void paint(Canvas canvas, Size size) {
    final shortest = math.min(size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);

    canvas.saveLayer(Offset.zero & size, Paint());

    // Subtle global rotation for more organic motion
    canvas.translate(center.dx, center.dy);
    final rot = 0.08 * math.sin(timeSec * 0.2);
    canvas.rotate(rot);
    canvas.translate(-center.dx, -center.dy);

    // Warm orange palette
    final palette = <Color>[
      const Color(0xFFFFE7D1),
      const Color(0xFFFFD7A8),
      const Color(0xFFFFC180),
      const Color(0xFFFFAD66),
      const Color(0xFFFF994D),
    ];

    void drawBlob({
      required int idx,
      required double basePhase,
      required double baseRadius,
      required double dxAmp,
      required double dyAmp,
    }) {
      final color = palette[idx % palette.length];
      final t = timeSec;
      // Use incommensurate multipliers
      final dx =
          math.sin((t * (1.1 + 0.03 * idx)) + basePhase) * dxAmp * size.width;
      final dy =
          math.cos((t * (0.9 + 0.05 * idx)) + basePhase * 0.7) *
          dyAmp *
          size.height;
      final pos = center + Offset(dx, dy);

      final r =
          shortest *
          baseRadius *
          (1.0 + 0.06 * math.sin(t * (0.7 + 0.02 * idx)));

      final rect = Rect.fromCircle(center: pos, radius: r);
      final gradient = RadialGradient(
        colors: [color.withOpacity(0.45), color.withOpacity(0.0)],
      );
      final paint = Paint()
        ..shader = gradient.createShader(rect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);
      canvas.drawCircle(pos, r, paint);
    }

    drawBlob(
      idx: 0,
      basePhase: 0.0,
      baseRadius: 0.40,
      dxAmp: 0.16,
      dyAmp: 0.10,
    );
    drawBlob(
      idx: 1,
      basePhase: 1.9,
      baseRadius: 0.34,
      dxAmp: 0.14,
      dyAmp: 0.12,
    );
    drawBlob(
      idx: 2,
      basePhase: 3.7,
      baseRadius: 0.30,
      dxAmp: 0.12,
      dyAmp: 0.14,
    );
    drawBlob(
      idx: 3,
      basePhase: 5.3,
      baseRadius: 0.28,
      dxAmp: 0.10,
      dyAmp: 0.16,
    );
    drawBlob(
      idx: 4,
      basePhase: 0.8,
      baseRadius: 0.26,
      dxAmp: 0.09,
      dyAmp: 0.11,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter oldDelegate) {
    return oldDelegate.timeSec != timeSec;
  }
}
