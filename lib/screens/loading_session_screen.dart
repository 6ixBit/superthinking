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
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100 + 8 * t,
                  height: 100 + 8 * t,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withOpacity(0.08),
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
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
