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
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../supabase/session_repo.dart';
import '../services/storage.dart';
import '../supabase/supabase_client.dart';
import '../supabase/pattern_analysis_api.dart';
import 'loading_session_screen.dart';
import 'session_detail_screen.dart';

// Helper for unawaited
void unawaited(Future<void> future) {
  // ignore: unawaited_futures
  future;
}

class PatternExplorationScreen extends StatefulWidget {
  final String sessionId;
  final PatternAnalysisResult patternAnalysis;

  const PatternExplorationScreen({
    super.key,
    required this.sessionId,
    required this.patternAnalysis,
  });

  @override
  State<PatternExplorationScreen> createState() =>
      _PatternExplorationScreenState();
}

class _PatternExplorationScreenState extends State<PatternExplorationScreen> {
  bool isRecording = false;
  String transcript = '';

  late final stt.SpeechToText _speech;
  final AudioRecorder _recorder = AudioRecorder();

  Duration _recordElapsed = Duration.zero;
  Timer? _recordTimer;

  String? _recordingFilePath;
  bool _isProcessing = false;
  bool _hasRecorded = false;

  // Max duration for mini sessions (2 minutes)
  static const Duration _kMaxRecordDuration = Duration(minutes: 2);

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initializeSpeech();
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _recorder.dispose();

    // Ensure wake lock is disabled when leaving the screen
    WakelockPlus.disable().catchError((e) {
      print('[PatternExploration] Failed to disable wake lock in dispose: $e');
    });

    super.dispose();
  }

  Future<void> _initializeSpeech() async {
    await _speech.initialize(
      onError: (error) => print('Speech recognition error: $error'),
      debugLogging: false,
    );
  }

  Future<void> _startRecording() async {
    if (!_speech.isAvailable) {
      print('Speech recognition not available');
      return;
    }

    try {
      // Enable wake lock to keep screen on during recording
      await WakelockPlus.enable();

      // Get recording path
      final Directory tempDir = await getTemporaryDirectory();
      final String fileName =
          'pattern_exploration_${DateTime.now().millisecondsSinceEpoch}.m4a';
      _recordingFilePath = p.join(tempDir.path, fileName);

      // Start audio recording
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _recordingFilePath!,
      );

      // Start speech recognition
      await _speech.listen(
        onResult: (result) {
          if (mounted) {
            setState(() {
              transcript = result.recognizedWords;
            });
          }
        },
        listenMode: stt.ListenMode.confirmation,
        partialResults: true,
        localeId: 'en_US',
        cancelOnError: false,
      );

      setState(() {
        isRecording = true;
        _recordElapsed = Duration.zero;
        transcript = '';
      });

      // Start timer
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _recordElapsed = Duration(seconds: timer.tick);
          });

          // Auto-stop at max duration
          if (_recordElapsed >= _kMaxRecordDuration) {
            _stopRecording();
          }
        }
      });
    } catch (e) {
      print('Failed to start recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    if (!isRecording) return;

    // Disable wake lock when recording stops
    await WakelockPlus.disable();

    setState(() {
      isRecording = false;
      _hasRecorded = true;
      _isProcessing = true;
    });

    _recordTimer?.cancel();

    // Start processing in background; stay on this screen showing local loading state
    unawaited(_processExplorationInBackground());
  }

  Future<void> _processExplorationInBackground() async {
    try {
      // Stop speech and recording
      await _speech.stop();
      await _recorder.stop();

      if (_recordingFilePath == null ||
          !File(_recordingFilePath!).existsSync()) {
        print('No recording file found');
        return;
      }

      // Upload audio file
      final user = SupabaseService.client.auth.currentUser;
      if (user == null) return;

      final audioUrl = await StorageService.uploadAudioFile(
        file: File(_recordingFilePath!),
        userId: user.id,
        sessionId:
            'pattern_exploration_${widget.sessionId}_${DateTime.now().millisecondsSinceEpoch}',
      );

      // Process the deeper exploration and wait for completion
      final ok = await _processPatternExploration(audioUrl);

      // Only navigate back after processing is complete
      if (mounted) {
        Navigator.of(context).pop(ok == true ? true : false);
      }
    } catch (e) {
      print('Pattern exploration processing failed: $e');
      // Navigate back on error
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<bool> _processPatternExploration(String audioUrl) async {
    try {
      final session = SupabaseService.client.auth.currentSession;
      final accessToken = session?.accessToken;
      if (accessToken == null) return false;

      final uri = Uri.parse(
        '${SupabaseConfig.supabaseUrl}/functions/v1/process-pattern-exploration',
      );

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'apikey': SupabaseConfig.supabaseAnonKey,
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'sessionId': widget.sessionId,
          'audioUrl': audioUrl,
          'patternType': widget.patternAnalysis.primaryPattern?.type ?? '',
          'originalQuestion': widget.patternAnalysis.followUpQuestion ?? '',
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Pattern exploration completed successfully');
        return true;
      } else {
        print('Pattern exploration failed with status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Failed to process pattern exploration: $e');
      return false;
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Header with close button
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      'Explore Deeper',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48), // Balance the close button
                ],
              ),

              const SizedBox(height: 32),

              // Pattern context
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.psychology, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      widget.patternAnalysis.primaryPattern!.type.toUpperCase(),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Question
              if (widget.patternAnalysis.followUpQuestion != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    widget.patternAnalysis.followUpQuestion!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],

              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Recording timer
                    if (isRecording || _hasRecorded) ...[
                      Text(
                        '${_formatDuration(_recordElapsed)} / 2:00',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w300,
                              color: isRecording
                                  ? AppColors.primary
                                  : Colors.black54,
                            ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Recording button
                    GestureDetector(
                      onTap: isRecording ? _stopRecording : _startRecording,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isRecording
                              ? Colors.red.shade400
                              : AppColors.primary,
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (isRecording
                                          ? Colors.red.shade400
                                          : AppColors.primary)
                                      .withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Icon(
                          isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Status text
                    Text(
                      isRecording
                          ? 'Tap to stop recording'
                          : _hasRecorded
                          ? 'Processing your response...'
                          : 'Tap to start recording',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Live transcript - commented out for now
                    // if (transcript.isNotEmpty) ...[
                    //   Container(
                    //     width: double.infinity,
                    //     padding: const EdgeInsets.all(16),
                    //     decoration: BoxDecoration(
                    //       color: Colors.grey.shade50,
                    //       borderRadius: BorderRadius.circular(12),
                    //     ),
                    //     child: Text(
                    //       transcript,
                    //       style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    //         color: Colors.black87,
                    //         height: 1.4,
                    //       ),
                    //     ),
                    //   ),
                    // ],
                  ],
                ),
              ),

              // Bottom instruction
              if (!isRecording && !_hasRecorded) ...[
                const SizedBox(height: 20),
                Text(
                  'Take your time to reflect on this question.\nYour response will help generate deeper insights.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.black54,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Pattern exploration screen is now complete - results are handled by the session detail screen
