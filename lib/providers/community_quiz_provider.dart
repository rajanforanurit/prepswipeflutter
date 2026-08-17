// import 'dart:async';
// import 'package:flutter/material.dart';
// import '../models/question_model.dart';
// import '../services/api_service.dart';

// enum CommunityQuizState { idle, loading, loaded, error }

// class CommunityQuizProvider extends ChangeNotifier {
//   final ApiService _api = ApiService();

//   List<Question> _questions = [];
//   CommunityQuizState _state = CommunityQuizState.idle;
//   String? _error;
//   int _currentIndex = 0;
//   String _challengeId = '';
//   String _inviteCode = '';

//   int _timeSpentSeconds = 0;
//   Timer? _timer;

//   final Map<int, int?> _selectedOptions = {};

//   List<Question> get questions => _questions;
//   CommunityQuizState get state => _state;
//   String? get error => _error;
//   int get currentIndex => _currentIndex;
//   int get timeSpentSeconds => _timeSpentSeconds;
//   String get challengeId => _challengeId;
//   String get inviteCode => _inviteCode;

//   Question? get currentQuestion =>
//       _questions.isNotEmpty && _currentIndex < _questions.length
//           ? _questions[_currentIndex]
//           : null;

//   int? selectedOptionFor(int index) => _selectedOptions[index];

//   void _startTimer() {
//     _timer?.cancel();
//     _timeSpentSeconds = 0;
//     _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
//       _timeSpentSeconds++;
//       notifyListeners();
//     });
//   }

//   Future<void> loadChallenge(String challengeId, String inviteCode) async {
//     _state = CommunityQuizState.loading;
//     _error = null;
//     _challengeId = challengeId;
//     _inviteCode = inviteCode;
//     _currentIndex = 0;
//     _selectedOptions.clear();
//     _timeSpentSeconds = 0;
//     _questions = [];
//     notifyListeners();

//     try {
//       // Trigger user's start attempt timer on the server
//       await _api.startAttempt(challengeId);

//       // Fetch official question payload sorted inside this room
//       final raw = await _api.fetchChallengeQuestions(challengeId);
//       final List rawQuestions = raw['questions'] ?? [];

//       _questions = rawQuestions.map((j) => Question.fromJson(j)).toList();

//       if (_questions.isEmpty) {
//         _state = CommunityQuizState.error;
//         _error = "No questions found for this challenge.";
//       } else {
//         _state = CommunityQuizState.loaded;
//         _startTimer();
//       }
//     } catch (e) {
//       _state = CommunityQuizState.error;
//       _error = e.toString().replaceFirst('Exception: ', '');
//     }
//     notifyListeners();
//   }

//   void selectOption(int questionIndex, int optionKey) {
//     _selectedOptions[questionIndex] = optionKey;
//     notifyListeners();
//   }

//   Future<void> navigateToQuestion(int index) async {
//     if (index < 0 || index >= _questions.length) return;
//     _currentIndex = index;
//     notifyListeners();

//     try {
//       // Notify the server of the current question index to sync live progress cards
//       await _api.updateProgress(_challengeId, index);
//     } catch (_) {}
//   }

//   Future<Map<String, dynamic>> submitChallenge() async {
//     _timer?.cancel();
//     _state = CommunityQuizState.loading;
//     notifyListeners();

//     // Map responses to match backend schema verification requirements
//     final List<Map<String, dynamic>> answers = [];
//     for (int i = 0; i < _questions.length; i++) {
//       final q = _questions[i];
//       final selected = _selectedOptions[i];
//       final isSkipped = selected == null;
//       final isCorrect = !isSkipped && selected == q.correctAnswer;

//       answers.add({
//         "questionId": q.id,
//         "isCorrect": isCorrect,
//         "isSkipped": isSkipped,
//       });
//     }

//     try {
//       final res = await _api.finishChallenge(_challengeId, answers, _timeSpentSeconds);
//       _state = CommunityQuizState.loaded;
//       notifyListeners();
//       return res;
//     } catch (e) {
//       _state = CommunityQuizState.error;
//       _error = e.toString();
//       notifyListeners();
//       return {"success": false, "message": e.toString()};
//     }
//   }

//   void reset() {
//     _questions = [];
//     _state = CommunityQuizState.idle;
//     _error = null;
//     _currentIndex = 0;
//     _selectedOptions.clear();
//     _timer?.cancel();
//     _timeSpentSeconds = 0;
//     notifyListeners();
//   }

//   @override
//   void dispose() {
//     _timer?.cancel();
//     super.dispose();
//   }
// }