import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'supabase_client.dart';

class PatternAnalysisApi {
  static SupabaseClient get _client => SupabaseService.client;

  static Future<PatternAnalysisResult?> analyzeSessionPatterns(
    String sessionId,
  ) async {
    try {
      final session = _client.auth.currentSession;
      final accessToken = session?.accessToken;
      if (accessToken == null) return null;

      final uri = Uri.parse(
        '${SupabaseConfig.supabaseUrl}/functions/v1/analyze-patterns',
      );

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'apikey': SupabaseConfig.supabaseAnonKey,
          'Content-Type': 'application/json',
        },
        body: json.encode({'sessionId': sessionId}),
      );

      if (response.statusCode != 200) return null;

      final Map<String, dynamic> data = json.decode(response.body);
      return PatternAnalysisResult.fromJson(data);
    } catch (e) {
      print('Pattern analysis error: $e');
      return null;
    }
  }
}

class PatternAnalysisResult {
  final bool hasPatterns;
  final PatternInfo? primaryPattern;
  final String? followUpQuestion;
  final String? insightPreview;

  PatternAnalysisResult({
    required this.hasPatterns,
    this.primaryPattern,
    this.followUpQuestion,
    this.insightPreview,
  });

  factory PatternAnalysisResult.fromJson(Map<String, dynamic> json) {
    return PatternAnalysisResult(
      hasPatterns: json['has_patterns'] ?? false,
      primaryPattern: json['primary_pattern'] != null
          ? PatternInfo.fromJson(json['primary_pattern'])
          : null,
      followUpQuestion: json['follow_up_question'],
      insightPreview: json['insight_preview'],
    );
  }
}

class PatternInfo {
  final String type;
  final String description;
  final String evidence;

  PatternInfo({
    required this.type,
    required this.description,
    required this.evidence,
  });

  factory PatternInfo.fromJson(Map<String, dynamic> json) {
    return PatternInfo(
      type: json['type'] ?? '',
      description: json['description'] ?? '',
      evidence: json['evidence'] ?? '',
    );
  }
}
