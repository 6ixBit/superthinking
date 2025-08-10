import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../theme/app_colors.dart';
import '../supabase/supabase_client.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  StreamSubscription<sb.AuthState>? _sub;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _sub = SupabaseService.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (!mounted) return;
      if (event == sb.AuthChangeEvent.signedIn) {
        Navigator.of(context).pushReplacementNamed('/');
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _signInOAuth(sb.OAuthProvider provider) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final redirectTo = kIsWeb ? null : SupabaseConfig.redirectUri;
      await SupabaseService.client.auth.signInWithOAuth(
        provider,
        redirectTo: redirectTo,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sign-in failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _WavesBackground()),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/superthinking_profile.png',
                      width: 96,
                      height: 96,
                      fit: BoxFit.contain,
                      errorBuilder: (c, e, s) => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'SuperThinking',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Turn overthinking into your superpower',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.black.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 40),
                    _SignInButton(
                      onPressed: _loading
                          ? null
                          : () => _signInOAuth(sb.OAuthProvider.apple),
                      background: Colors.black,
                      foreground: Colors.white,
                      icon: const Icon(Icons.apple, color: Colors.white),
                      label: _loading ? 'Signing in…' : 'Continue with Apple',
                    ),
                    const SizedBox(height: 12),
                    _SignInButton(
                      onPressed: _loading
                          ? null
                          : () => _signInOAuth(sb.OAuthProvider.google),
                      background: Colors.white,
                      foreground: Colors.black,
                      borderColor: Colors.black.withOpacity(0.15),
                      icon: const Icon(Icons.g_mobiledata, size: 22),
                      label: _loading ? 'Signing in…' : 'Continue with Google',
                    ),
                    const SizedBox(height: 12),
                    _SignInButton(
                      onPressed: _loading
                          ? null
                          : () =>
                                Navigator.of(context).pushReplacementNamed('/'),
                      background: AppColors.primary,
                      foreground: Colors.white,
                      icon: const Icon(Icons.bolt, color: Colors.white),
                      label: 'Super Login (skip)',
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

class _SignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color background;
  final Color foreground;
  final Widget icon;
  final String label;
  final Color? borderColor;

  const _SignInButton({
    required this.onPressed,
    required this.background,
    required this.foreground,
    required this.icon,
    required this.label,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: borderColor ?? Colors.transparent,
              width: 1,
            ),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        icon: icon,
        label: Text(label),
      ),
    );
  }
}

class _WavesBackground extends StatefulWidget {
  const _WavesBackground();

  @override
  State<_WavesBackground> createState() => _WavesBackgroundState();
}

class _WavesBackgroundState extends State<_WavesBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
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
        return CustomPaint(painter: _WavesPainter(t: _controller.value));
      },
    );
  }
}

class _WavesPainter extends CustomPainter {
  final double t;
  _WavesPainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = AppColors.background;
    canvas.drawRect(Offset.zero & size, bg);

    final colors = [
      const Color(0xFFFFE7D1),
      const Color(0xFFFFD7A8),
      const Color(0xFFFFC180),
    ];

    void wave({
      required double amp,
      required double freq,
      required double phase,
      required Color color,
    }) {
      final path = Path();
      final height = size.height;
      final width = size.width;
      final yBase = height * (0.6 + 0.05 * math.sin(phase + t * 2 * math.pi));
      path.moveTo(0, yBase);
      for (double x = 0; x <= width; x += 10) {
        final y =
            yBase +
            math.sin(
                  (x / width) * 2 * math.pi * freq + phase + t * 4 * math.pi,
                ) *
                amp;
        path.lineTo(x, y);
      }
      path.lineTo(width, height);
      path.lineTo(0, height);
      path.close();
      final paint = Paint()..color = color.withOpacity(0.6);
      canvas.drawPath(path, paint);
    }

    wave(amp: 22, freq: 2.2, phase: 0.0, color: colors[0]);
    wave(amp: 28, freq: 1.6, phase: 1.3, color: colors[1]);
    wave(amp: 18, freq: 2.8, phase: 2.2, color: colors[2]);
  }

  @override
  bool shouldRepaint(covariant _WavesPainter oldDelegate) => oldDelegate.t != t;
}
