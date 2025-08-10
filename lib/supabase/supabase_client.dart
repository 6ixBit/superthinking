import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://hqaoeknjodwlyutojsvf.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhxYW9la25qb2R3bHl1dG9qc3ZmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQ4NTk1NzcsImV4cCI6MjA3MDQzNTU3N30.apArxRS15CozZ8todoPT4zmilwUM5gHZil4eeaZ25gk',
  );
  static const String redirectUri = String.fromEnvironment(
    'SUPABASE_REDIRECT_URL',
    defaultValue: 'io.supabase.flutter://login-callback/',
  );
}

class SupabaseService {
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
    _initialized = true;
  }

  static SupabaseClient get client => Supabase.instance.client;
}
