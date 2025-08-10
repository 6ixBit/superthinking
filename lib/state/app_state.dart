import 'package:flutter/foundation.dart';

class Session {
  final DateTime createdAt;
  final String title;
  final List<String> ideas;
  final List<String> actions;
  final String strength;

  Session({
    required this.createdAt,
    required this.title,
    required this.ideas,
    required this.actions,
    required this.strength,
  });
}

class AppState extends ChangeNotifier {
  String? biggestChallenge;
  final List<String> quickAnswers = [];
  String recordedTranscript = '';
  List<String> bestIdeas = [];
  List<String> actionSteps = [];
  String hiddenStrength = '';
  final List<bool> actionCompletion = [false, false, false];

  final List<Session> sessions = [];

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
        createdAt: DateTime.now(),
        title: biggestChallenge?.isNotEmpty == true
            ? biggestChallenge!
            : 'SuperThinking Session',
        ideas: List<String>.from(bestIdeas),
        actions: List<String>.from(actionSteps),
        strength: hiddenStrength,
      ),
    );

    notifyListeners();
  }

  void toggleAction(int index) {
    actionCompletion[index] = !actionCompletion[index];
    notifyListeners();
  }
}
