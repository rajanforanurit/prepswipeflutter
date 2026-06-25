import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

enum AnalyticsState { idle, loading, loaded, error }

class AnalyticsProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  AnalyticsSummary? _summary;
  Map<String, dynamic>? _rankData;
  Map<String, dynamic>? _leaderboardData;
  AnalyticsState _state = AnalyticsState.idle;
  String? _error;
  DateTime? _lastFetch;

  AnalyticsSummary? get summary => _summary;
  Map<String, dynamic>? get rankData => _rankData;
  Map<String, dynamic>? get leaderboardData => _leaderboardData;
  AnalyticsState get state => _state;
  String? get error => _error;
  bool get isLoading => _state == AnalyticsState.loading;

  Future<void> load({bool force = false}) async {
    if (!force &&
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < const Duration(seconds: 30)) {
      return;
    }

    _state = AnalyticsState.loading;
    if (_summary == null) notifyListeners();

    try {
      final data = await _api.getAnalytics();
      _summary = AnalyticsSummary.fromJson(data);
      _state = AnalyticsState.loaded;
      _lastFetch = DateTime.now();
    } catch (e) {
      _state = AnalyticsState.error;
      _error = e.toString().replaceFirst('Exception: ', '');
    }

    notifyListeners();
  }

  Future<void> loadRank({bool force = false}) async {
    try {
      final results = await Future.wait([
        _api.getOverallRank(),
        _api.getLeaderboard(),
      ]);
      _rankData = results[0];
      _leaderboardData = results[1];
      notifyListeners();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  void invalidate() {
    _lastFetch = null;
  }
}
