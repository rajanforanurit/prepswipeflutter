import 'package:flutter/material.dart';
import 'package:prepswipe/models/timeline_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TimelineSettingsProvider extends ChangeNotifier {
  static const _modeKey = "timeline_mode";
  static const _spacingKey = "timeline_spacing";

  TimelineMode _mode = TimelineMode.mixed;

  int _spacing = 4;

  TimelineMode get mode => _mode;

  int get spacing => _spacing;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    _mode = TimelineMode.values[
        prefs.getInt(_modeKey) ??
            TimelineMode.mixed.index];

    _spacing = prefs.getInt(_spacingKey) ?? 4;

    notifyListeners();
  }

  Future<void> setMode(TimelineMode mode) async {
    _mode = mode;

    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt(
      _modeKey,
      mode.index,
    );

    notifyListeners();
  }

  Future<void> setSpacing(int spacing) async {
    _spacing = spacing;

    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt(
      _spacingKey,
      spacing,
    );

    notifyListeners();
  }
}