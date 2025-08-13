import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../supabase/session_api.dart';
import 'session_detail_screen.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';

class LoadingSessionScreen extends StatefulWidget {
  final String sessionId;
  const LoadingSessionScreen({super.key, required this.sessionId});

  @override
  State<LoadingSessionScreen> createState() => _LoadingSessionScreenState();
}

class _LoadingSessionScreenState extends State<LoadingSessionScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  Timer? _pollTimer;
  int _pollAttempts = 0;
  Timer? _msgTimer;
  int _msgIndex = 0;
  static const List<String> _messages = [
    'Determining your thinking style…',
    'Pinpointing your strengths…',
    'Calculating your sentiment…',
    'Finalizing insights…',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _checkOnce();
    _startPolling();
    _startMessageCycle();
  }

  // Check immediately and navigate if done
  Future<void> _checkOnce() async {
    final rec = await SessionApi.fetchSessionById(widget.sessionId);
    if (!mounted) return;
    final isDone =
        rec != null &&
        (rec.processingStatus == 'completed' || rec.analysis != null);
    if (isDone) {
      _pollTimer?.cancel();
      if (!mounted) return;
      // Open inside home shell by setting openSessionId, so bottom nav remains
      final app = context.read<AppState>();
      app.setOpenSession(widget.sessionId);
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil('/home', (r) => false, arguments: 0);
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      await _checkOnce();
    });
  }

  void _startMessageCycle() {
    _msgTimer?.cancel();
    _msgTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      setState(() {
        _msgIndex = (_msgIndex + 1) % _messages.length;
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Re-check immediately when app returns to foreground
      _checkOnce();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _msgTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = _controller.value;
            final isTop = _msgIndex % 2 == 0;
            return Stack(
              alignment: Alignment.center,
              children: [
                // Central analyzing component
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 100 + 8 * t,
                      height: 100 + 8 * t,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(alpha: 0.08),
                      ),
                      child: Icon(
                        CupertinoIcons.sparkles,
                        color: AppColors.primary,
                        size: 44 + 6 * t,
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
                  ],
                ),
                // Large muted rotating status text positioned above or below
                Align(
                  alignment: isTop
                      ? const Alignment(0, -0.6)
                      : const Alignment(0, 0.6),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder: (child, anim) =>
                        FadeTransition(opacity: anim, child: child),
                    child: Text(
                      _messages[_msgIndex],
                      key: ValueKey('overlay_${_msgIndex}'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.black.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
