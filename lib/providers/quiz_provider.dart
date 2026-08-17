import 'package:flutter/material.dart';
import 'package:prepswipe/Timeline/feed_repository.dart';
import 'package:prepswipe/Timeline/timeline_builder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/question_model.dart';
import '../models/timeline_models.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';

enum QuizState { idle, loading, loaded, error }

class QuizProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final _uuid = const Uuid();

  // State Variables
  QuizState _state = QuizState.idle;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;
  String? _currentExam;
  String _sessionId = '';
  AppLanguage _language = AppLanguage.english;
  int _currentIndex = 0;

  // Question Collections
  final List<Question> _masterQuestions = [];
  final List<Question> _visibleQuestions = [];
  final Set<String> _loadedQuestionIds = {};
  List<TimelineItem> _timeline = [];

  // Active Filters
  final Set<int> _selectedYears = {};
  final Set<String> _selectedSubjects = {};

  // Available Filters (extracted from initial questions load)
  List<int> _availableYears = [];
  List<String> _availableSubjects = [];

  // Option submission & tracking
  final Map<int, int?> _selectedOptions = {};
  final Map<int, bool> _submitted = {};
  final Map<int, DateTime> _questionStartTimes = {};

  // Getters
  List<Question> get masterQuestions => _masterQuestions;
  List<Question> get visibleQuestions => _visibleQuestions;
  List<TimelineItem> get timeline => _timeline;
  Set<String> get loadedQuestionIds => _loadedQuestionIds;
  QuizState get state => _state;
  bool get isLoading => _state == QuizState.loading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;
  int get currentIndex => _currentIndex;
  String get sessionId => _sessionId;
  String? get currentExam => _currentExam;
  AppLanguage get language => _language;
  Set<int> get selectedYears => _selectedYears;
  Set<String> get selectedSubjects => _selectedSubjects;
  List<int> get availableYears => _availableYears;
  List<String> get availableSubjects => _availableSubjects;

  int get remainingQuestions => _visibleQuestions.length - _currentIndex;

  Question? get currentQuestion =>
      _visibleQuestions.isNotEmpty && _currentIndex < _visibleQuestions.length
          ? _visibleQuestions[_currentIndex]
          : null;

  int? selectedOptionFor(int index) => _selectedOptions[index];
  bool isSubmitted(int index) => _submitted[index] == true;

  Future<void> setLanguage(AppLanguage lang) async {
    if (_language == lang) return;
    _language = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', lang.name);
    notifyListeners();
  }

  void toggleLanguage() {
    setLanguage(
      _language == AppLanguage.english
          ? AppLanguage.hindi
          : AppLanguage.english,
    );
  }

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

  // --- Core Architecture Loading Strategies ---

  Future<void> loadInitial(
    String exam, {
    required TimelineMode mode,
    required List<FeedCard> feedCards,
    required int spacing,
    bool isPremium = false,
  }) async {
    _state = QuizState.loading;
    _error = null;
    _currentExam = exam;
    _currentIndex = 0;
    _hasMore = true;
    _masterQuestions.clear();
    _visibleQuestions.clear();
    _loadedQuestionIds.clear();
    _selectedOptions.clear();
    _submitted.clear();
    _questionStartTimes.clear();
    _timeline.clear();
    notifyListeners();

    try {
      final collection = AppConstants.collectionForExam(exam);

      // Attempt initial fetch with active filters
      var raw = await _fetchFilteredQuestions(
        collection,
        exam,
        years: _selectedYears,
        subjects: _selectedSubjects,
        count: 30,
      );

      // Extract year and subjects from initial unfiltered questions only if no filters are active
      if (_selectedYears.isEmpty && _selectedSubjects.isEmpty && raw.isNotEmpty) {
        _availableYears = raw
            .map((json) => (json['year'] as num?)?.toInt() ?? 0)
            .where((y) => y > 0)
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));

        _availableSubjects = raw
            .map((json) => json['subject']?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
      }

      if (raw.isEmpty) {
        // Only fall back to general pool if NO filters are active
        if (_selectedYears.isEmpty && _selectedSubjects.isEmpty) {
          raw = await _api.getRandomQuestions(
            collection: 'pcsquestions',
            count: 30,
          );
        }
      }

      _appendQuestions(raw);
      _state = QuizState.loaded;
      startSession();
      recordQuestionView(0);
    } catch (e) {
      _state = QuizState.error;
      _error = e.toString().replaceFirst('Exception: ', '');
    }

    rebuildTimeline(mode: mode, feedCards: feedCards, spacing: spacing, isPremium: isPremium);
  }

  // preloads background questions on threshold trigger (remaining < 10)
  Future<void> preloadNextBatch({
    required TimelineMode mode,
    required List<FeedCard> feedCards,
    required int spacing,
    bool isPremium = false,
  }) async {
    if (_isLoadingMore || !_hasMore || _currentExam == null) return;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final collection = AppConstants.collectionForExam(_currentExam!);
      var raw = await _fetchFilteredQuestions(
        collection,
        _currentExam!,
        years: _selectedYears,
        subjects: _selectedSubjects,
        count: 30,
      );

      if (raw.isNotEmpty) {
        _appendQuestions(raw);
      } else {
        if (_selectedYears.isEmpty && _selectedSubjects.isEmpty) {
          // If raw is empty and no filters are active, try relaxing/general fallbacks
          _loadedQuestionIds.clear();
          for (final q in _visibleQuestions) {
            _loadedQuestionIds.add(q.id.toString());
          }
          
          raw = await _relaxAndFetch(collection, count: 30);
          if (raw.isNotEmpty) {
            _appendQuestions(raw);
          } else {
            // Absolute fallback to general collection
            raw = await _api.getRandomQuestions(
              collection: 'pcsquestions',
              count: 30,
            );
            if (raw.isNotEmpty) {
              _appendQuestions(raw);
            } else {
              _hasMore = false; // truly empty database
            }
          }
        } else {
          // If filters are active and no more questions are found, stop preloading
          _hasMore = false;
        }
      }
    } catch (_) {
      // Slient failure for preloading requests to prevent breaking UX flow
    } finally {
      _isLoadingMore = false;
      rebuildTimeline(mode: mode, feedCards: feedCards, spacing: spacing, isPremium: isPremium);
    }
  }

  // --- Intelligent Multi-Filter Fetching ---

  Future<List<Map<String, dynamic>>> _fetchFilteredQuestions(
    String collection,
    String exam, {
    required Set<int> years,
    required Set<String> subjects,
    int count = 30,
  }) async {
    if (years.isEmpty && subjects.isEmpty) {
      final list = await _api.getRandomQuestions(
        collection: collection,
        exam: exam,
        count: count,
      );
      final shuffledList = List<Map<String, dynamic>>.from(list)..shuffle();
      return shuffledList;
    }

    List<Map<String, dynamic>> rawResults = [];

    if (subjects.isNotEmpty && (years.isEmpty || subjects.length <= years.length)) {
      // Query by subject, then filter by year in-memory
      final futures = subjects.map((sub) => _api.getRandomQuestions(
            collection: collection,
            exam: exam,
            subject: sub,
            count: count,
          ));
      final lists = await Future.wait(futures);
      for (final list in lists) {
        rawResults.addAll(list);
      }

      if (years.isNotEmpty) {
        rawResults = rawResults.where((json) {
          final y = (json['year'] as num?)?.toInt() ?? 0;
          return years.contains(y);
        }).toList();
      }
    } else {
      // Query by year, then filter by subject in-memory
      final futures = years.map((yr) => _api.getRandomQuestions(
            collection: collection,
            exam: exam,
            year: yr,
            count: count,
          ));
      final lists = await Future.wait(futures);
      for (final list in lists) {
        rawResults.addAll(list);
      }

      if (subjects.isNotEmpty) {
        rawResults = rawResults.where((json) {
          final s = json['subject']?.toString() ?? '';
          return subjects.contains(s);
        }).toList();
      }
    }

    rawResults.shuffle();
    return rawResults;
  }

  // --- Filter Relaxation Engine ---

  Future<List<Map<String, dynamic>>> _relaxAndFetch(
    String collection, {
    required int count,
  }) async {
    // relaxation Step 1: Relax Year (Keep Subject target active)
    if (_selectedYears.isNotEmpty) {
      final raw = await _api.getRandomQuestions(
        collection: collection,
        exam: _currentExam!,
        subject: _selectedSubjects.isNotEmpty ? _selectedSubjects.first : null,
        count: count,
      );
      if (raw.isNotEmpty) return raw;
    }

    // relaxation Step 2: Relax Subject (Keep Year target active)
    if (_selectedSubjects.isNotEmpty) {
      final raw = await _api.getRandomQuestions(
        collection: collection,
        exam: _currentExam!,
        year: _selectedYears.isNotEmpty ? _selectedYears.first : null,
        count: count,
      );
      if (raw.isNotEmpty) return raw;
    }

    // relaxation Step 3: Clear both filters and pull general collection questions
    return await _api.getRandomQuestions(
      collection: collection,
      exam: _currentExam!,
      count: count,
    );
  }

  void _appendQuestions(List<Map<String, dynamic>> raw) {
    var uniqueBatch = raw
        .map((json) => Question.fromJson(json))
        .where((q) => !_loadedQuestionIds.contains(q.id.toString()))
        .toList();

    // If we could not find any new unique questions in this batch, it means we have exhausted the unique set of questions.
    // To prevent the flow from halting, we reset the tracking list of loaded IDs (keeping only the currently visible ones so they don't immediately repeat)
    // and try filtering again.
    if (uniqueBatch.isEmpty && raw.isNotEmpty) {
      _loadedQuestionIds.clear();
      for (final q in _visibleQuestions) {
        _loadedQuestionIds.add(q.id.toString());
      }
      uniqueBatch = raw
          .map((json) => Question.fromJson(json))
          .where((q) => !_loadedQuestionIds.contains(q.id.toString()))
          .toList();

      // If it is still empty (meaning the batch only contains currently visible questions),
      // we just allow all questions in the raw batch to be added anyway to keep the flow alive.
      if (uniqueBatch.isEmpty) {
        uniqueBatch = raw.map((json) => Question.fromJson(json)).toList();
      }
    }

    for (final q in uniqueBatch) {
      _loadedQuestionIds.add(q.id.toString());
      _masterQuestions.add(q);
      _visibleQuestions.add(q);
    }
  }

  // --- Server-side Filtering Action ---

  Future<void> applyFilters({
    Set<int>? years,
    Set<String>? subjects,
    required TimelineMode mode,
    required List<FeedCard> feedCards,
    required int spacing,
  }) async {
    final nextYears = years != null ? Set<int>.from(years) : <int>{};
    final nextSubjects = subjects != null ? Set<String>.from(subjects) : <String>{};

    _selectedYears.clear();
    _selectedYears.addAll(nextYears);
    _selectedSubjects.clear();
    _selectedSubjects.addAll(nextSubjects);

    if (_currentExam != null) {
      await loadInitial(
        _currentExam!,
        mode: mode,
        feedCards: feedCards,
        spacing: spacing,
      );
    }
  }

  Future<void> clearFilters({
    required TimelineMode mode,
    required List<FeedCard> feedCards,
    required int spacing,
  }) async {
    await applyFilters(
      years: {},
      subjects: {},
      mode: mode,
      feedCards: feedCards,
      spacing: spacing,
    );
  }

  // --- Timeline Building Pipeline ---

  void rebuildTimeline({
    required TimelineMode mode,
    required List<FeedCard> feedCards,
    required int spacing,
    bool isPremium = false,
  }) {
    _timeline = TimelineBuilder.build(
      mode: mode,
      questions: _visibleQuestions,
      feedCards: feedCards,
      questionsBetweenFeeds: spacing,
      isPremium: isPremium,
    );
    notifyListeners();
  }

  // --- Navigation & Preloading checks ---

  void navigateToQuestion(
    int index, {
    required TimelineMode mode,
    required List<FeedCard> feedCards,
    required int spacing,
    bool isPremium = false,
  }) {
    if (index < 0 || index >= _visibleQuestions.length) return;
    _currentIndex = index;
    recordQuestionView(index);

    // Preload triggers dynamically when remaining questions drop below 10 (TikTok Queue paradigm)
    if (remainingQuestions < 10 && !_isLoadingMore && _hasMore) {
      preloadNextBatch(mode: mode, feedCards: feedCards, spacing: spacing, isPremium: isPremium);
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
    if (questionIndex >= _visibleQuestions.length) return false;

    final question = _visibleQuestions[questionIndex];
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

  void reset() {
    _masterQuestions.clear();
    _visibleQuestions.clear();
    _loadedQuestionIds.clear();
    _timeline.clear();
    _state = QuizState.idle;
    _error = null;
    _currentExam = null;
    _currentIndex = 0;
    _selectedOptions.clear();
    _submitted.clear();
    _questionStartTimes.clear();
    _selectedYears.clear();
    _selectedSubjects.clear();
    _hasMore = true;
    _isLoadingMore = false;
    _availableYears.clear();
    _availableSubjects.clear();
    notifyListeners();
  }
}