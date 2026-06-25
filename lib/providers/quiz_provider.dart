import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/question_model.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';

enum QuizState { idle, loading, loaded, error }

class QuizProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final _uuid = const Uuid();

  List<Question> _questions = [];
  QuizState _state = QuizState.idle;
  String? _error;
  String? _currentExam;
  String _sessionId = '';

  int _currentIndex = 0;
  final Map<int, int?> _selectedOptions = {};
  final Map<int, bool> _submitted = {};
  final Map<int, DateTime> _questionStartTimes = {};

  List<Question> get questions => _questions;
  QuizState get state => _state;
  String? get error => _error;
  int get currentIndex => _currentIndex;
  String get sessionId => _sessionId;
  String? get currentExam => _currentExam;

  Question? get currentQuestion =>
      _questions.isNotEmpty && _currentIndex < _questions.length
          ? _questions[_currentIndex]
          : null;

  int? selectedOptionFor(int index) => _selectedOptions[index];
  bool isSubmitted(int index) => _submitted[index] == true;

  void startSession() {
    _sessionId = _uuid.v4();
    _questionStartTimes[_currentIndex] = DateTime.now();
  }

  void recordQuestionView(int index) {
    _questionStartTimes[index] ??= DateTime.now();
  }

  int getTimeSpent(int index) {
    final start = _questionStartTimes[index];
    if (start == null) return 0;
    return DateTime.now().difference(start).inSeconds;
  }

  Future<void> loadQuestions(String exam, {bool refresh = false}) async {
    if (_currentExam == exam && _questions.isNotEmpty && !refresh) return;

    _state = QuizState.loading;
    _error = null;
    _currentExam = exam;
    _currentIndex = 0;
    _selectedOptions.clear();
    _submitted.clear();
    _questionStartTimes.clear();
    notifyListeners();

    try {
      final collection = AppConstants.collectionForExam(exam);

      final raw = await _api.getRandomQuestions(
        collection: collection,
        exam: exam,
        count: 30,
      );

      if (raw.isEmpty) {
        final fallback = await _api.getRandomQuestions(
          collection: 'pcsquestions',
          count: 30,
        );
        _questions = fallback.map((j) => Question.fromJson(j)).toList();
      } else {
        _questions = raw.map((j) => Question.fromJson(j)).toList();
      }

      if (_questions.isEmpty) {
        _state = QuizState.error;
        _error = 'No questions found. Try a different exam.';
      } else {
        _state = QuizState.loaded;
        startSession();
        recordQuestionView(0);
      }
    } catch (e) {
      _state = QuizState.error;
      _error = e.toString().replaceFirst('Exception: ', '');
    }

    notifyListeners();
  }

  void selectOption(int questionIndex, int optionKey) {
    if (isSubmitted(questionIndex)) return;
    _selectedOptions[questionIndex] = optionKey;
    notifyListeners();
  }

  Future<bool> submitQuestion(int questionIndex) async {
    if (isSubmitted(questionIndex)) return false;
    final question = _questions[questionIndex];
    final selected = _selectedOptions[questionIndex];
    if (selected == null) return false;

    _submitted[questionIndex] = true;
    notifyListeners();

    final isCorrect = selected == question.correctAnswer;
    final timeTaken = getTimeSpent(questionIndex);

    try {
      await _api.submitAttempt(
        questionId: question.id,
        selectedOption: selected,
        isCorrect: isCorrect,
        timeTakenSeconds: timeTaken,
        sessionId: _sessionId,
        questionMeta: question.toMeta(),
      );
    } catch (_) {}

    return isCorrect;
  }

  void navigateToQuestion(int index) {
    if (index < 0 || index >= _questions.length) return;
    _currentIndex = index;
    recordQuestionView(index);

    if (index >= _questions.length - 5) {
      _loadMore();
    }

    notifyListeners();
  }

  Future<void> _loadMore() async {
    if (_currentExam == null) return;
    try {
      final collection = AppConstants.collectionForExam(_currentExam!);
      final raw = await _api.getRandomQuestions(
        collection: collection,
        exam: _currentExam!,
        count: 20,
      );
      if (raw.isNotEmpty) {
        _questions.addAll(raw.map((j) => Question.fromJson(j)));
        notifyListeners();
      }
    } catch (_) {}
  }

  void reset() {
    _questions = [];
    _state = QuizState.idle;
    _error = null;
    _currentExam = null;
    _currentIndex = 0;
    _selectedOptions.clear();
    _submitted.clear();
    _questionStartTimes.clear();
    notifyListeners();
  }
}
