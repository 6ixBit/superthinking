import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'screens/onboarding/welcome_screen.dart';
import 'screens/quick_context_screen.dart';
import 'screens/onboarding/onboarding_frequency_screen.dart';
import 'screens/onboarding/onboarding_age_screen.dart';
import 'screens/onboarding/onboarding_gender_screen.dart';
import 'screens/onboarding/onboarding_goals_screen.dart';
import 'screens/splash_screen.dart';
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
import 'services/notification_service.dart';
import 'services/app_lifecycle.dart';
import 'screens/onboarding/onboarding_name_screen.dart';
import 'screens/onboarding/analysis_results_screen.dart';
import 'screens/onboarding/mental_health_goals_screen.dart';
import 'screens/onboarding/youre_in_right_place_screen.dart';
import 'screens/onboarding/overthinking_triggers_screen.dart';
import 'screens/onboarding/overthinking_content_screen.dart';
import 'screens/onboarding/overthinking_impact_screen.dart';
import 'screens/onboarding/social_proof_screen.dart';
import 'screens/onboarding/analysis_loading_screen.dart';
import 'screens/onboarding/value_welcome_screen.dart';
import 'screens/onboarding/value_record_screen.dart';
import 'screens/onboarding/value_conquer_screen.dart';

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

class SuperThinkingApp extends StatefulWidget {
  const SuperThinkingApp({super.key});

  @override
  State<SuperThinkingApp> createState() => _SuperThinkingAppState();
}

class _SuperThinkingAppState extends State<SuperThinkingApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _setupNotificationHandling();
    AppLifecycleService.initialize();
  }

  void _setupNotificationHandling() {
    // Handle notification taps when app is in foreground
    NotificationService.onNotificationTapped.listen((payload) {
      if (payload != null) {
        _navigateToSession(payload);
      }
    });

    // Handle notification taps when app is launched from notification
    NotificationService.onAppLaunchedFromNotification.listen((payload) {
      if (payload != null) {
        _navigateToSession(payload);
      }
    });
  }

  void _navigateToSession(String sessionId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _navigatorKey.currentState?.pushNamed('/session', arguments: sessionId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SuperThinking',
      theme: AppTheme.light(),
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      initialRoute: '/splash',
      routes: {
        '/splash': (_) => const SplashScreen(),
        '/gate': (_) => const _AuthGate(),
        '/': (_) => const WelcomeScreen(),
        '/login': (_) => const LoginScreen(),
        '/onboarding-name': (_) => const OnboardingNameScreen(),
        '/onboarding-goals': (_) => const OnboardingGoalsScreen(),
        '/mental-health-goals': (_) => const MentalHealthGoalsScreen(),
        '/youre-in-right-place': (_) => const YoureInRightPlaceScreen(),
        '/overthinking-triggers': (_) => const OverthinkingTriggersScreen(),
        '/onboarding-frequency': (_) => const OnboardingFrequencyScreen(),
        '/overthinking-content': (_) => const OverthinkingContentScreen(),
        '/overthinking-impact': (_) => const OverthinkingImpactScreen(),
        '/analysis-loading': (_) => const AnalysisLoadingScreen(),
        '/value-welcome': (_) => const ValueWelcomeScreen(),
        '/value-record': (_) => const ValueRecordScreen(),
        '/value-conquer': (_) => const ValueConquerScreen(),
        '/onboarding-age': (_) => const OnboardingAgeScreen(),
        '/onboarding-gender': (_) => const OnboardingGenderScreen(),
        '/analysis-results': (_) => const AnalysisResultsScreen(),
        '/quick': (_) => const QuickContextScreen(),
        '/record': (_) => const RecordSessionScreen(),
        '/loading': (_) => const LoadingRevealScreen(),
        '/reveal': (_) => const RevealScreen(),
        '/micro': (_) => const MicroVictoryScreen(),
        '/plan': (_) => const ActionPlanScreen(),
        '/nudge': (_) => const NextSessionNudgeScreen(),
        '/home': (_) => const HomeShell(),
        '/dev': (_) => const DevCatalogScreen(),
        '/social-proof': (_) => const SocialProofScreen(),
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
