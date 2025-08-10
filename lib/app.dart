import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'screens/welcome_screen.dart';
import 'screens/quick_context_screen.dart';
import 'screens/onboarding_frequency_screen.dart';
import 'screens/onboarding_focus_screen.dart';
import 'screens/record_session_screen.dart';
import 'screens/loading_reveal_screen.dart';
import 'screens/reveal_screen.dart';
import 'screens/micro_victory_screen.dart';
import 'screens/action_plan_screen.dart';
import 'screens/next_session_nudge_screen.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'screens/overthinking_time_screen.dart';
import 'supabase/user_profile_api.dart';
import 'supabase/supabase_client.dart';

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const SuperThinkingApp(),
    );
  }
}

class SuperThinkingApp extends StatelessWidget {
  const SuperThinkingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SuperThinking',
      theme: AppTheme.light(),
      debugShowCheckedModeBanner: false,
      initialRoute: '/gate',
      routes: {
        '/gate': (_) => const _AuthGate(),
        '/': (_) => const WelcomeScreen(),
        '/login': (_) => const LoginScreen(),
        '/onboarding-frequency': (_) => const OnboardingFrequencyScreen(),
        '/onboarding-focus': (_) => const OnboardingFocusScreen(),
        '/quick': (_) => const QuickContextScreen(),
        '/overthinking-time': (_) => const OverthinkingTimeScreen(),
        '/record': (_) => const RecordSessionScreen(),
        '/loading': (_) => const LoadingRevealScreen(),
        '/reveal': (_) => const RevealScreen(),
        '/micro': (_) => const MicroVictoryScreen(),
        '/plan': (_) => const ActionPlanScreen(),
        '/nudge': (_) => const NextSessionNudgeScreen(),
        '/home': (_) => const HomeShell(),
      },
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    // If no user, go to login
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/login');
      return;
    }
    // If user, check onboarding
    final completed = await UserProfileApi.isOnboardingCompleted();
    if (!mounted) return;
    if (completed) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      Navigator.of(context).pushReplacementNamed('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
