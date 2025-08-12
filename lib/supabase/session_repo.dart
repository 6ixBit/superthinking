import 'supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

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

  static Future<void> attachAudioAndStartProcessing({
    required String sessionId,
    required String audioUrl,
  }) async {
    // ignore: avoid_print
    print(
      '[SessionRepo] attachAudioAndStartProcessing: sessionId=$sessionId url=$audioUrl',
    );
    // Update session with audio_url and set status to processing
    await SupabaseService.client
        .from('sessions')
        .update({'audio_url': audioUrl, 'processing_status': 'processing'})
        .eq('id', sessionId);

    // Invoke edge function
    try {
      // ignore: avoid_print
      print('[SessionRepo] invoking process-session via SDK');
      await SupabaseService.client.functions.invoke(
        'process-session',
        body: {'sessionId': sessionId},
      );
      // ignore: avoid_print
      print('[SessionRepo] SDK invoke returned OK');
    } catch (e) {
      // ignore: avoid_print
      print('[SessionRepo] SDK invoke failed: $e');
      // Fallback: direct HTTP call to function endpoint
      try {
        final url = Uri.parse(
          '${SupabaseConfig.supabaseUrl}/functions/v1/process-session',
        );
        final jwt = SupabaseService.client.auth.currentSession?.accessToken;
        final resp = await http.post(
          url,
          headers: {
            'Authorization': 'Bearer ${jwt ?? SupabaseConfig.supabaseAnonKey}',
            'Content-Type': 'application/json',
          },
          body: '{"sessionId":"$sessionId"}',
        );
        // ignore: avoid_print
        print(
          '[SessionRepo] HTTP invoke status=${resp.statusCode} body=${resp.body}',
        );
      } catch (e2) {
        // ignore: avoid_print
        print('[SessionRepo] HTTP invoke failed: $e2');
      }
    }
  }
}
