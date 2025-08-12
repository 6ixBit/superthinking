import 'package:flutter/foundation.dart';
import '../supabase/session_api.dart';

class Session {
  final String id;
  final DateTime createdAt;
  final String title;
  final List<String> ideas;
  final List<String> actions;
  final String strength;
  final int? durationSeconds;

  Session({
    required this.id,
    required this.createdAt,
    required this.title,
    required this.ideas,
    required this.actions,
    required this.strength,
    this.durationSeconds,
  });
}

class AppState extends ChangeNotifier {
  String? biggestChallenge;
  final List<String> quickAnswers = [];
  String recordedTranscript = '';
  final Map<String, String> sessionIdToTranscript = {};
  List<String> bestIdeas = [];
  List<String> actionSteps = [];
  String hiddenStrength = '';
  final List<bool> actionCompletion = [false, false, false];

  final List<Session> sessions = [];
  bool loadingSessions = false;

  String? openSessionId;
  void setOpenSession(String? sessionId) {
    openSessionId = sessionId;
    notifyListeners();
  }

  void setChallenge(String value) {
    biggestChallenge = value;
    notifyListeners();
  }

  void addQuickAnswer(String value) {
    quickAnswers.add(value);
    notifyListeners();
  }

  void setTranscript(String value) {
    recordedTranscript = value;
    notifyListeners();
  }

  void setSessionTranscript(String sessionId, String transcript) {
    sessionIdToTranscript[sessionId] = transcript;
    notifyListeners();
  }

  String? getSessionTranscript(String sessionId) =>
      sessionIdToTranscript[sessionId];

  void synthesizeMagic() {
    bestIdeas = [
      'Leverage existing strengths to reframe',
      'Break the problem into small experiments',
      'Ask for perspective from a trusted person',
    ];
    actionSteps = [
      'Text Sarah for presentation feedback',
      'Draft a 1-page outline',
      'Schedule 20-min practice run',
    ];
    hiddenStrength = 'You are resourceful and reflective';

    sessions.insert(
      0,
      Session(
        id: 'local',
        createdAt: DateTime.now(),
        title: biggestChallenge?.isNotEmpty == true
            ? biggestChallenge!
            : 'SuperThinking Session',
        ideas: List<String>.from(bestIdeas),
        actions: List<String>.from(actionSteps),
        strength: hiddenStrength,
        durationSeconds: null,
      ),
    );

    notifyListeners();
  }

  void toggleAction(int index) {
    actionCompletion[index] = !actionCompletion[index];
    notifyListeners();
  }

  Future<void> loadSessionsFromSupabase() async {
    loadingSessions = true;
    notifyListeners();
    try {
      final records = await SessionApi.fetchSessionsForCurrentUser();
      sessions
        ..clear()
        ..addAll(
          records.map(
            (r) => Session(
              id: r.id,
              createdAt: r.createdAt,
              title: 'SuperThinking Session',
              ideas: r.ideas,
              actions: r.actions,
              strength: '',
              durationSeconds: r.durationSeconds,
            ),
          ),
        );
    } catch (_) {
      // ignore errors for now
    } finally {
      loadingSessions = false;
      notifyListeners();
    }
  }

  Future<bool> deleteSession(String sessionId) async {
    try {
      final success = await SessionApi.deleteSession(sessionId);
      if (success) {
        // Remove from local list
        sessions.removeWhere((session) => session.id == sessionId);

        // Clear open session if it was the deleted one
        if (openSessionId == sessionId) {
          openSessionId = null;
        }

        // Clear transcript for this session
        sessionIdToTranscript.remove(sessionId);

        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('Error in AppState.deleteSession: $e');
      return false;
    }
  }
}
