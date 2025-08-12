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
  final prompts = const [
    'Now imagine this turns out better than expected — how?',
    'What’s the best possible outcome here?',
    'What resources could help you?',
  ];
  int promptIndex = 0;

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

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  Future<void> _startRecording() async {
    print('[RecordSession] Starting recording...');
    setState(() {
      isRecording = true;
      _recordElapsed = Duration.zero;
      transcript = '';
      _promptEvents.clear();
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
    }

    for (int i = 0; i < prompts.length && isRecording; i++) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted || !isRecording) break;
      setState(() {
        promptIndex = i;
        _promptEvents.add({
          'text': prompts[i],
          'ts_seconds': _recordElapsed.inSeconds,
        });
      });
      print('[RecordSession] Showing prompt $i: ${prompts[i]}');
    }
  }

  Future<void> _stopRecording() async {
    if (!isRecording) return;
    print('[RecordSession] Stopping recording...');
    _recordTimer?.cancel();
    setState(() => isRecording = false);

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
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil('/home', (r) => false, arguments: 0);
      return;
    } catch (e, stackTrace) {
      print('[RecordSession] ERROR creating session: $e');
      print('[RecordSession] Stack trace: $stackTrace');
    }
    if (!mounted) return;
    Navigator.of(context).pushNamed('/home');
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: null,
      body: Stack(
        children: [
          const Positioned.fill(child: IgnorePointer(child: OracleAura())),
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
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: isRecording ? 120 : 108,
                          height: isRecording ? 120 : 108,
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
                        _SpeechBubble(text: prompts[promptIndex]),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
          if (isRecording) const SizedBox.shrink(),
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
