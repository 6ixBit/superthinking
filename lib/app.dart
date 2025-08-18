import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'screens/onboarding/welcome_screen.dart';
import 'screens/quick_context_screen.dart';
import 'screens/onboarding/onboarding_frequency_screen.dart';
import 'screens/onboarding/onboarding_focus_screen.dart';
import 'screens/onboarding/onboarding_age_screen.dart';
import 'screens/onboarding/onboarding_gender_screen.dart';
import 'screens/record_session_screen.dart';
import 'screens/loading_reveal_screen.dart';
import 'screens/reveal_screen.dart';
import 'screens/micro_victory_screen.dart';
import 'screens/action_plan_screen.dart';
import 'screens/next_session_nudge_screen.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding/overthinking_time_screen.dart';
import 'supabase/user_profile_api.dart';
import 'supabase/supabase_client.dart';
import 'screens/dev/dev_catalog_screen.dart';
import 'screens/session_detail_screen.dart';

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
        '/onboarding-age': (_) => const OnboardingAgeScreen(),
        '/onboarding-gender': (_) => const OnboardingGenderScreen(),
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
        '/dev': (_) => const DevCatalogScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/session') {
          final arg = settings.arguments;
          if (arg is String) {
            return MaterialPageRoute(
              builder: (_) => SessionDetailScreen(sessionId: arg),
              settings: settings,
            );
          }
        }
        return null;
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
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _route());
  }

  Future<void> _route() async {
    if (!mounted || _navigated) return;
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) {
      _navigated = true;
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
      });
      return;
    }
    final completed = await UserProfileApi.isOnboardingCompleted();
    if (!mounted || _navigated) return;
    _navigated = true;
    final target = completed ? '/home' : '/';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(target);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
