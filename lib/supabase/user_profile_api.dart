import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';

class UserProfileApi {
  static SupabaseClient get _client => SupabaseService.client;

  static Future<Map<String, dynamic>?> getProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    final res = await _client
        .from('user_profiles')
        .select()
        .eq('user_id', user.id)
        .limit(1)
        .maybeSingle();
    return res;
  }

  static Future<Map<String, dynamic>?> ensureProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    final existing = await getProfile();
    if (existing != null) return existing;
    final inserted = await _client
        .from('user_profiles')
        .insert({'user_id': user.id})
        .select()
        .maybeSingle();
    return inserted;
  }

  static Future<void> setOnboardingResponse(String key, dynamic value) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    // Fetch current responses, merge locally, then update
    final profile = await ensureProfile();
    final Map<String, dynamic> current =
        (profile?['onboarding_responses'] as Map?)?.cast<String, dynamic>() ??
        {};
    current[key] = value;
    await _client
        .from('user_profiles')
        .update({
          'onboarding_responses': current,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', user.id);
  }

  static Future<void> setPreferredPromptTime(String timeLabel) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    await ensureProfile();
    await _client
        .from('user_profiles')
        .update({
          'preferred_prompt_time': timeLabel,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', user.id);
  }

  static Future<void> markOnboardingCompleted() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    await ensureProfile();
    await _client
        .from('user_profiles')
        .update({
          'onboarding_completed': true,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', user.id);
  }

  static Future<bool> isOnboardingCompleted() async {
    final profile = await ensureProfile();
    if (profile == null) return false;
    return (profile['onboarding_completed'] as bool?) ?? false;
  }
}
