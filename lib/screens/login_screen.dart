import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:sign_in_with_apple/sign_in_with_apple.dart' as apple;
import 'package:crypto/crypto.dart' as crypto;
import 'dart:convert' show utf8;

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
  bool _navigated = false;

  void _showDocument(String title, String body) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(child: Text(body)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    debugPrint('[Auth] LoginScreen initState');
    _sub = SupabaseService.client.auth.onAuthStateChange.listen(
      (data) {
        final event = data.event;
        debugPrint('[Auth] onAuthStateChange: $event');
        if (!mounted || _navigated) return;
        if (event == sb.AuthChangeEvent.signedIn) {
          _navigated = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            debugPrint('[Auth] Navigating to /gate after sign-in');
            Navigator.of(context).pushReplacementNamed('/gate');
          });
        }
      },
      onError: (e, st) {
        debugPrint('[Auth] onAuthStateChange error: $e\n$st');
      },
    );
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
      debugPrint(
        '[Auth] signInWithOAuth provider=$provider redirectTo=$redirectTo',
      );
      await SupabaseService.client.auth.signInWithOAuth(
        provider,
        redirectTo: redirectTo,
      );
      debugPrint('[Auth] signInWithOAuth initiated');
    } catch (e, st) {
      debugPrint('[Auth][Error] signInWithOAuth: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sign-in failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithAppleNative() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final rawNonce = SupabaseService.client.auth.generateRawNonce();
      final hashedNonce = crypto.sha256
          .convert(utf8.encode(rawNonce))
          .toString();
      debugPrint('[Auth] Apple native begin, nonce hashed=$hashedNonce');
      final credential = await apple.SignInWithApple.getAppleIDCredential(
        scopes: [
          apple.AppleIDAuthorizationScopes.email,
          apple.AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );
      final idToken = credential.identityToken;
      debugPrint(
        '[Auth] Apple native credential received, idToken null? ${idToken == null}',
      );
      if (idToken == null) {
        throw Exception('No Apple ID token');
      }
      await SupabaseService.client.auth.signInWithIdToken(
        provider: sb.OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );
      debugPrint('[Auth] Supabase signInWithIdToken succeeded');
    } on apple.SignInWithAppleAuthorizationException catch (e, st) {
      debugPrint(
        '[Auth][Apple] AuthorizationException code=${e.code} message=${e.message}\n$st',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Apple sign-in failed: ${e.code.name}')),
      );
    } on sb.AuthException catch (e, st) {
      debugPrint('[Auth][Supabase] AuthException: ${e.message}\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Auth error: ${e.message}')));
    } catch (e, st) {
      debugPrint('[Auth][Error] Apple native sign-in: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Apple sign-in failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _isApplePlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

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
                          : () async {
                              debugPrint('[Auth] Apple button pressed');
                              if (_isApplePlatform) {
                                await _signInWithAppleNative();
                              } else {
                                await _signInOAuth(sb.OAuthProvider.apple);
                              }
                            },
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
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: SafeArea(
              top: false,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () => _showDocument(
                        'Terms of Service',
                        '''Welcome to SuperThinking. By accessing or using the app, you agree to these Terms of Service.

1) Purpose of the Service
SuperThinking helps you transform overthinking into clarity by recording short sessions, transcribing them, and generating insights and suggested next steps. It is intended for wellbeing and productivity support only. It is not medical, legal, or other professional advice.

2) Eligibility & Accounts
You must be 13+ to use SuperThinking. You are responsible for your account and for keeping your device secure. If you use third‑party sign‑in (e.g., Apple), you authorize us to receive basic account information to create or access your account.

3) Your Content & License
You retain ownership of all content you create (e.g., audio, transcripts, session insights, action items). You grant SuperThinking a limited, non‑exclusive license to host, process, and display your content solely to provide and improve the Service. You can delete sessions in‑app; related analysis and action items are removed.

4) AI‑Generated Insights
We use AI services to transcribe audio and generate insights. Outputs may be imperfect or incomplete. You agree not to rely on them as professional advice.

5) Acceptable Use
Do not use the app while driving or in unsafe situations. Do not upload unlawful, harmful, or infringing content. Do not misuse or attempt to disrupt the Service.

6) Changes, Suspension, Termination
We may modify or discontinue parts of the Service. We may suspend or terminate accounts that violate these Terms or pose risk to the Service or users.

7) Disclaimers & Limitation of Liability
The Service is provided “as is.” To the maximum extent permitted by law, SuperThinking disclaims all warranties and will not be liable for indirect, incidental, or consequential damages.

8) Governing Law
These Terms are governed by applicable laws in your jurisdiction unless local law requires otherwise.

9) Contact
Questions? Contact support@superthinking.app.''',
                      ),
                      child: const Text('Terms of Service'),
                    ),
                    Text(
                      '•',
                      style: TextStyle(color: Colors.black.withOpacity(0.4)),
                    ),
                    TextButton(
                      onPressed: () => _showDocument(
                        'Privacy Policy',
                        '''This Privacy Policy explains how SuperThinking collects, uses, and protects your information.

1) Information We Collect
- Account information: Email or basic profile details from your chosen sign‑in provider.
- Session content: Audio you record, transcripts, session analysis, and action items you create.
- Usage data: Basic app interactions and diagnostics to improve the Service.

2) How We Use Your Information
- To operate the app (record, transcribe, analyze sessions, and show insights).
- To improve the experience (e.g., enhance accuracy and reliability).
- To provide support and maintain security.

3) AI & Third‑Party Services
- We use reputable AI providers (e.g., transcription and language models) to process audio and generate insights. Only the minimal necessary data is shared, and it is transmitted securely.

4) Data Retention & Deletion
- You may delete sessions from within the app; related analysis and action items are also removed.
- You may request account deletion at any time via support@superthinking.app.

5) Security
- We use industry‑standard measures to protect your data. No method is 100% secure, but we continually improve our safeguards.

6) Your Rights
- You may access, correct, or delete your data. Contact support@superthinking.app for requests.

7) Children
- SuperThinking is not directed to children under 13. If you believe a child provided data, contact us to remove it.

8) Changes
- We may update this policy and will post the latest version in‑app.

9) Contact
- Questions? Contact support@superthinking.app.''',
                      ),
                      child: const Text('Privacy Policy'),
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
