import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;

import '../state/app_state.dart';
import '../theme/app_colors.dart';

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

  Future<void> _startRecording() async {
    setState(() {
      isRecording = true;
      transcript = '';
      promptIndex = 0;
    });

    for (int i = 0; i < prompts.length && isRecording; i++) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted || !isRecording) break;
      setState(() {
        promptIndex = i;
        transcript += '\n[prompt] ${prompts[i]}';
      });
    }
  }

  void _stopRecording() {
    if (!isRecording) return;
    setState(() => isRecording = false);
    context.read<AppState>().setTranscript('User thoughts... $transcript');
    context.read<AppState>().synthesizeMagic();
    Navigator.of(context).pushNamed('/loading');
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
                      Text(
                        "What’s on your mind right now?",
                        style: Theme.of(context).textTheme.headlineMedium,
                        textAlign: TextAlign.center,
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
                      const SizedBox(height: 24),
                      if (isRecording)
                        _SpeechBubble(text: prompts[promptIndex]),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
          if (isRecording)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Text(
                  'Tap to stop when you’re ready',
                  style: Theme.of(context).textTheme.bodyMedium,
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
          const Icon(CupertinoIcons.chat_bubble_text, size: 18),
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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(painter: _AuroraPainter(time: _controller.value));
      },
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final double time;
  _AuroraPainter({required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    final shortest = math.min(size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);

    canvas.saveLayer(Offset.zero & size, Paint());

    void drawBlob({
      required double phase,
      required Color color,
      required double radiusFactor,
      required double dxAmp,
      required double dyAmp,
    }) {
      final t = time * 2 * math.pi + phase;
      final dx = math.sin(t) * dxAmp * size.width;
      final dy = math.cos(t * 0.9) * dyAmp * size.height;
      final pos = center + Offset(dx, dy);
      final r = shortest * radiusFactor;

      final rect = Rect.fromCircle(center: pos, radius: r);
      final gradient = RadialGradient(
        colors: [color.withOpacity(0.55), color.withOpacity(0.0)],
      );
      final paint = Paint()
        ..shader = gradient.createShader(rect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);
      canvas.drawCircle(pos, r, paint);
    }

    drawBlob(
      phase: 0.0,
      color: AppColors.primary,
      radiusFactor: 0.38,
      dxAmp: 0.18,
      dyAmp: 0.12,
    );
    drawBlob(
      phase: 2.1,
      color: AppColors.secondary,
      radiusFactor: 0.32,
      dxAmp: 0.16,
      dyAmp: 0.14,
    );
    drawBlob(
      phase: 4.2,
      color: AppColors.success,
      radiusFactor: 0.28,
      dxAmp: 0.12,
      dyAmp: 0.16,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter oldDelegate) {
    return oldDelegate.time != time;
  }
}
