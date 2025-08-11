import 'supabase_client.dart';

class SessionRepo {
  static Future<String> createPendingSession({
    required int durationSeconds,
    required List<Map<String, dynamic>> promptsShown,
    String inputMethod = 'voice',
  }) async {
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in user');
    }

    final data = {
      'user_id': user.id,
      'input_method': inputMethod,
      'duration_seconds': durationSeconds,
      'prompts_shown': promptsShown,
      'processing_status': 'pending',
    };

    final res = await SupabaseService.client
        .from('sessions')
        .insert(data)
        .select('id')
        .single();

    return res['id'] as String;
  }
}
