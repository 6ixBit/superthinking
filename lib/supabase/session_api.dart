import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';

class SessionRecord {
  final String id;
  final DateTime createdAt;
  final int? durationSeconds;
  final List<String> ideas;
  final List<ActionItem> actions;
  final String? transcript;
  final String?
  processingStatus; // 'pending', 'processing', 'completed', 'failed'
  final SessionAnalysis? analysis;
  final String? title; // AI-generated session title

  SessionRecord({
    required this.id,
    required this.createdAt,
    required this.durationSeconds,
    required this.ideas,
    required this.actions,
    this.transcript,
    this.processingStatus,
    this.analysis,
    this.title,
  });
}

class ActionItem {
  final String id;
  final String description;
  final String? category;
  final String priority; // 'low', 'medium', 'high'
  final String source; // 'user_stated', 'ai_suggested'
  final String status; // 'pending', 'completed'

  ActionItem({
    required this.id,
    required this.description,
    this.category,
    required this.priority,
    required this.source,
    required this.status,
  });
}

class SessionAnalysis {
  final String summaryBefore;
  final String summaryAfter;
  final int problemFocusPercentage;
  final int solutionFocusPercentage;
  final int shiftPercentage;
  final String thinkingStyleToday;
  final Map<String, int> thinkingPatterns;
  final List<String> bestIdeas;
  final String strengthHighlight;
  final List<String> positiveQuotes;
  final List<String> resourcesMentioned;
  final int sessionDurationMinutes;

  SessionAnalysis({
    required this.summaryBefore,
    required this.summaryAfter,
    required this.problemFocusPercentage,
    required this.solutionFocusPercentage,
    required this.shiftPercentage,
    required this.thinkingStyleToday,
    required this.thinkingPatterns,
    required this.bestIdeas,
    required this.strengthHighlight,
    required this.positiveQuotes,
    required this.resourcesMentioned,
    required this.sessionDurationMinutes,
  });
}

class SessionApi {
  static Future<List<SessionRecord>> fetchSessionsForCurrentUser() async {
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) return [];

    final client = SupabaseService.client;

    final sessionsRes = await client
        .from('sessions')
        .select('id, created_at, duration_seconds, processing_status, title')
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
      final duration = r['duration_seconds'] as int?;
      final processingStatus = r['processing_status'] as String?;
      final title = r['title'] as String?;

      // Convert string actions to ActionItem objects for display
      final actionStrings = sessionIdToActions[id] ?? const <String>[];
      final actionItems = actionStrings
          .map(
            (desc) => ActionItem(
              id: '', // We don't need the ID for the summary view
              description: desc,
              priority: 'medium',
              source: 'ai_suggested',
              status: 'pending',
            ),
          )
          .toList();

      return SessionRecord(
        id: id,
        createdAt: createdAt,
        durationSeconds: duration,
        ideas: sessionIdToIdeas[id] ?? const <String>[],
        actions: actionItems,
        processingStatus: processingStatus,
        title: title,
      );
    }).toList();
  }

  static Future<SessionRecord?> fetchSessionById(String sessionId) async {
    final client = SupabaseService.client;

    // Fetch session basic info
    final sessionRow = await client
        .from('sessions')
        .select(
          'id, created_at, duration_seconds, raw_transcript, processing_status, title',
        )
        .eq('id', sessionId)
        .maybeSingle();
    if (sessionRow == null) return null;

    // Fetch analysis data
    final analysisRow = await client
        .from('session_analysis')
        .select('*')
        .eq('session_id', sessionId)
        .maybeSingle();

    // Fetch action items
    final actionRows = await client
        .from('action_items')
        .select('id, description, category, priority, source, status')
        .eq('session_id', sessionId);

    final actions = <ActionItem>[];
    if (actionRows is List) {
      for (final r in actionRows) {
        actions.add(
          ActionItem(
            id: r['id'] as String,
            description: r['description'] as String,
            category: r['category'] as String?,
            priority: r['priority'] as String? ?? 'medium',
            source: r['source'] as String? ?? 'ai_suggested',
            status: r['status'] as String? ?? 'pending',
          ),
        );
      }
    }

    // Parse analysis if available
    SessionAnalysis? analysis;
    if (analysisRow != null) {
      analysis = SessionAnalysis(
        summaryBefore: analysisRow['summary_before'] as String? ?? '',
        summaryAfter: analysisRow['summary_after'] as String? ?? '',
        problemFocusPercentage:
            analysisRow['problem_focus_percentage'] as int? ?? 0,
        solutionFocusPercentage:
            analysisRow['solution_focus_percentage'] as int? ?? 0,
        shiftPercentage: analysisRow['shift_percentage'] as int? ?? 0,
        thinkingStyleToday:
            analysisRow['thinking_style_today'] as String? ?? '',
        thinkingPatterns: Map<String, int>.from(
          analysisRow['thinking_patterns'] as Map<String, dynamic>? ?? {},
        ),
        bestIdeas: List<String>.from(
          analysisRow['best_ideas'] as List<dynamic>? ?? [],
        ),
        strengthHighlight: analysisRow['strength_highlight'] as String? ?? '',
        positiveQuotes: List<String>.from(
          analysisRow['positive_quotes'] as List<dynamic>? ?? [],
        ),
        resourcesMentioned: List<String>.from(
          analysisRow['resources_mentioned'] as List<dynamic>? ?? [],
        ),
        sessionDurationMinutes:
            analysisRow['session_duration_minutes'] as int? ?? 0,
      );
    }

    return SessionRecord(
      id: sessionRow['id'] as String,
      createdAt: DateTime.parse(sessionRow['created_at'] as String),
      durationSeconds: sessionRow['duration_seconds'] as int?,
      transcript: sessionRow['raw_transcript'] as String?,
      processingStatus: sessionRow['processing_status'] as String?,
      ideas: analysis?.bestIdeas ?? [],
      actions: actions,
      analysis: analysis,
      title: sessionRow['title'] as String?,
    );
  }

  static Future<bool> deleteSession(String sessionId) async {
    try {
      final client = SupabaseService.client;
      final user = client.auth.currentUser;
      if (user == null) return false;

      // Delete in order: action_items, session_analysis, then sessions
      // This respects foreign key constraints

      await client.from('action_items').delete().eq('session_id', sessionId);

      await client
          .from('session_analysis')
          .delete()
          .eq('session_id', sessionId);

      await client
          .from('sessions')
          .delete()
          .eq('id', sessionId)
          .eq(
            'user_id',
            user.id,
          ); // Ensure user can only delete their own sessions

      return true;
    } catch (e) {
      print('Error deleting session: $e');
      return false;
    }
  }

  static Future<bool> updateActionItemStatus(
    String actionItemId,
    String status,
  ) async {
    try {
      print(
        '[SessionApi] Updating action item $actionItemId to status: $status',
      );
      final client = SupabaseService.client;
      final user = client.auth.currentUser;
      if (user == null) {
        print('[SessionApi] No authenticated user');
        return false;
      }

      await client
          .from('action_items')
          .update({'status': status})
          .eq('id', actionItemId);

      print('[SessionApi] Action item updated successfully');
      return true;
    } catch (e) {
      print('[SessionApi] Error updating action item status: $e');
      return false;
    }
  }

  static Future<ActionItem?> createActionItem({
    required String sessionId,
    required String description,
    String? category,
    String priority = 'medium',
    String source = 'user_stated',
  }) async {
    try {
      final client = SupabaseService.client;
      final user = client.auth.currentUser;
      if (user == null) return null;

      final res = await client
          .from('action_items')
          .insert({
            'session_id': sessionId,
            'description': description,
            'category': category,
            'priority': priority,
            'source': source,
            'status': 'pending',
          })
          .select('id, description, category, priority, source, status')
          .maybeSingle();

      if (res == null) return null;
      return ActionItem(
        id: res['id'] as String,
        description: res['description'] as String,
        category: res['category'] as String?,
        priority: res['priority'] as String? ?? 'medium',
        source: res['source'] as String? ?? 'user_stated',
        status: res['status'] as String? ?? 'pending',
      );
    } catch (e) {
      print('Error creating action item: $e');
      return null;
    }
  }

  static Future<bool> updateSessionTitle({
    required String sessionId,
    required String title,
  }) async {
    try {
      final client = SupabaseService.client;
      final user = client.auth.currentUser;
      if (user == null) return false;

      await client
          .from('sessions')
          .update({'title': title})
          .eq('id', sessionId)
          .eq('user_id', user.id);
      return true;
    } catch (e) {
      print('Error updating session title: $e');
      return false;
    }
  }

  static Future<bool> deleteActionItem({required String actionItemId}) async {
    try {
      final client = SupabaseService.client;
      final user = client.auth.currentUser;
      if (user == null) return false;

      await client.from('action_items').delete().eq('id', actionItemId);
      return true;
    } catch (e) {
      print('Error deleting action item: $e');
      return false;
    }
  }

  static Future<int> countCompletedActionItemsForCurrentUser() async {
    final client = SupabaseService.client;
    final user = client.auth.currentUser;
    if (user == null) return 0;

    // Get all session IDs for this user
    final sessionsRes = await client
        .from('sessions')
        .select('id')
        .eq('user_id', user.id);

    if (sessionsRes is! List || sessionsRes.isEmpty) return 0;
    final sessionIds = <String>[];
    for (final row in sessionsRes) {
      final id = row['id'] as String?;
      if (id != null) sessionIds.add(id);
    }
    if (sessionIds.isEmpty) return 0;

    // Count completed action items across these sessions
    final actionRows = await client
        .from('action_items')
        .select('id')
        .filter(
          'session_id',
          'in',
          '(${sessionIds.map((e) => '"$e"').join(',')})',
        )
        .eq('status', 'completed');

    if (actionRows is! List) return 0;
    return actionRows.length;
  }

  static Future<int> countTotalActionItemsForCurrentUser() async {
    final client = SupabaseService.client;
    final user = client.auth.currentUser;
    if (user == null) return 0;

    // Get all session IDs for this user
    final sessionsRes = await client
        .from('sessions')
        .select('id')
        .eq('user_id', user.id);

    if (sessionsRes is! List || sessionsRes.isEmpty) return 0;
    final sessionIds = <String>[];
    for (final row in sessionsRes) {
      final id = row['id'] as String?;
      if (id != null) sessionIds.add(id);
    }
    if (sessionIds.isEmpty) return 0;

    // Count all action items across these sessions
    final actionRows = await client
        .from('action_items')
        .select('id')
        .filter(
          'session_id',
          'in',
          '(${sessionIds.map((e) => '"$e"').join(',')})',
        );

    if (actionRows is! List) return 0;
    return actionRows.length;
  }
}
