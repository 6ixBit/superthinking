import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_client.dart';

class PatternExplorationInsightsApi {
  static SupabaseClient get _client => SupabaseService.client;

  static Future<PatternExplorationInsight?> getInsightsForSession(
    String sessionId,
  ) async {
    try {
      final response = await _client
          .from('pattern_exploration_insights')
          .select('*')
          .eq('session_id', sessionId)
          .maybeSingle();

      if (response == null) return null;

      return PatternExplorationInsight.fromJson(response);
    } catch (e) {
      print('Error fetching pattern exploration insights: $e');
      return null;
    }
  }
}

class PatternExplorationInsight {
  final String id;
  final String sessionId;
  final String patternType;
  final String? originalQuestion;
  final String? explorationTranscript;
  final String? insight;
  final String? keyRealization;
  final String? encouragement;
  final String? audioUrl;
  final DateTime createdAt;

  PatternExplorationInsight({
    required this.id,
    required this.sessionId,
    required this.patternType,
    this.originalQuestion,
    this.explorationTranscript,
    this.insight,
    this.keyRealization,
    this.encouragement,
    this.audioUrl,
    required this.createdAt,
  });

  factory PatternExplorationInsight.fromJson(Map<String, dynamic> json) {
    return PatternExplorationInsight(
      id: json['id'],
      sessionId: json['session_id'],
      patternType: json['pattern_type'],
      originalQuestion: json['original_question'],
      explorationTranscript: json['exploration_transcript'],
      insight: json['insight'],
      keyRealization: json['key_realization'],
      encouragement: json['encouragement'],
      audioUrl: json['audio_url'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
