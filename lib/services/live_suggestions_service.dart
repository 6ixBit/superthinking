import 'dart:convert';

import 'package:http/http.dart' as http;

import '../supabase/supabase_client.dart';

class LiveSuggestionsService {
  /// Fetch 1–3 short, context-aware suggestions for the given transcript.
  static Future<List<String>> fetchSuggestions({
    required String transcript,
  }) async {
    if (transcript.trim().isEmpty) return const [];
    try {
      final client = SupabaseService.client;

      // Direct HTTP call first (mirrors process-session behavior)
      final directUrl = Uri.parse(
        'https://hqaoeknjodwlyutojsvf.supabase.co/functions/v1/live-suggestions',
      );
      final jwt = client.auth.currentSession?.accessToken;
      try {
        final resp = await http.post(
          directUrl,
          headers: {
            'Authorization': 'Bearer ${jwt ?? SupabaseConfig.supabaseAnonKey}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'transcript': transcript}),
        );
        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          final decoded = jsonDecode(resp.body);
          if (decoded is Map && decoded['suggestions'] is List) {
            return List<String>.from(decoded['suggestions'] as List)
                .map((s) => s.toString().trim())
                .where((s) => s.isNotEmpty)
                .toList();
          }
        }
      } catch (_) {
        // fall back to SDK invoke
      }

      // SDK invoke as a fallback
      try {
        final res = await client.functions.invoke(
          'live-suggestions',
          body: {'transcript': transcript},
        );
        final data = res.data;
        if (data is Map && data['suggestions'] is List) {
          return List<String>.from(
            data['suggestions'] as List,
          ).map((s) => s.toString().trim()).where((s) => s.isNotEmpty).toList();
        }
      } catch (_) {
        // ignore
      }
    } catch (_) {
      // ignore
    }
    return const [];
  }
}
