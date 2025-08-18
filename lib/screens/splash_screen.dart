import 'package:flutter/material.dart';
import '../supabase/supabase_client.dart';
import '../supabase/user_profile_api.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _route());
  }

  Future<void> _route() async {
    if (!mounted || _navigated) return;
    
    // Add a small delay to show the splash screen
    await Future.delayed(const Duration(milliseconds: 1500));
    
    if (!mounted || _navigated) return;
    
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) {
      _navigated = true;
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/login');
      return;
    }
    
    final completed = await UserProfileApi.isOnboardingCompleted();
    if (!mounted || _navigated) return;
    _navigated = true;
    final target = completed ? '/home' : '/';
    Navigator.of(context).pushReplacementNamed(target);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _OrangeGradientBackground()),
          SafeArea(
            child: Center(
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
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrangeGradientBackground extends StatelessWidget {
  const _OrangeGradientBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFE7D1), // Warm orange from UI design guide
            Color(0x00FFE7D1), // Same color fading to transparent
          ],
        ),
      ),
    );
  }
}