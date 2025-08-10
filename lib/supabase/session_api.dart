import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';

class SessionRecord {
  final String id;
  final DateTime createdAt;
  final List<String> ideas;
  final List<String> actions;

  SessionRecord({
    required this.id,
    required this.createdAt,
    required this.ideas,
    required this.actions,
  });
}

class SessionApi {
  static Future<List<SessionRecord>> fetchSessionsForCurrentUser() async {
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) return [];

    final client = SupabaseService.client;

    final sessionsRes = await client
        .from('sessions')
        .select('id, created_at')
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    final List<dynamic> sessionRows = sessionsRes as List<dynamic>;
    if (sessionRows.isEmpty) return [];

    final sessionIds = sessionRows.map((r) => r['id'] as String).toList();

    final analysisFuture = client
        .from('session_analysis')
        .select('session_id, best_ideas')
        .filter(
          'session_id',
          'in',
          '(${sessionIds.map((e) => '"$e"').join(',')})',
        );

    final actionsFuture = client
        .from('action_items')
        .select('session_id, description')
        .filter(
          'session_id',
          'in',
          '(${sessionIds.map((e) => '"$e"').join(',')})',
        );

    final results = await Future.wait([analysisFuture, actionsFuture]);
    final List<dynamic> analysisRows = results[0] as List<dynamic>;
    final List<dynamic> actionRows = results[1] as List<dynamic>;

    final Map<String, List<String>> sessionIdToIdeas = {};
    for (final row in analysisRows) {
      final sid = row['session_id'] as String;
      final ideasDynamic = row['best_ideas'];
      final ideas = <String>[];
      if (ideasDynamic is List) {
        for (final v in ideasDynamic) {
          if (v is String) ideas.add(v);
        }
      }
      sessionIdToIdeas[sid] = ideas;
    }

    final Map<String, List<String>> sessionIdToActions = {};
    for (final row in actionRows) {
      final sid = row['session_id'] as String;
      final desc = row['description'] as String?;
      if (desc == null) continue;
      sessionIdToActions.putIfAbsent(sid, () => <String>[]).add(desc);
    }

    return sessionRows.map((r) {
      final id = r['id'] as String;
      final createdAt = DateTime.parse(r['created_at'] as String);
      return SessionRecord(
        id: id,
        createdAt: createdAt,
        ideas: sessionIdToIdeas[id] ?? const <String>[],
        actions: sessionIdToActions[id] ?? const <String>[],
      );
    }).toList();
  }
}
