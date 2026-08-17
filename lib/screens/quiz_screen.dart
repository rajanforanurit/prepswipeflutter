import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:prepswipe/Timeline/feed_repository.dart';
import 'package:prepswipe/models/timeline_models.dart';
import 'package:prepswipe/providers/timeline_settings_provider.dart';
import 'package:prepswipe/screens/feed_screen.dart';
import 'package:prepswipe/utils/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import '../providers/auth_provider.dart';
import '../providers/quiz_provider.dart';
import '../providers/analytics_provider.dart';
import '../models/question_model.dart';
import '../widgets/ps_card.dart';
import '../services/api_service.dart';

class QuizColors {
  static const primary = Color(0xFF7C4DFF);
  static const secondary = Color(0xFFFF9F1C);
  static const background = Color(0xFF090C14);
  static const card = Color(0xFF161B2C);
  static const cardBorder = Color(0x1FFFFFFF);
  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFFB4B8C5);
  static const textTertiary = Color(0xFF7A7F91);
  static const success = Color(0xFF22C55E);
  static const error = Color(0xFFEF4444);
  static const gold = Color(0xFFFFD700);
}

class QuestionTextFormatter {
  static final RegExp _numberedItemPattern =
      RegExp(r'\s(\d{1,2}\.\s(?=[A-Z]))');

  static String format(String text) {
    if (text.isEmpty) return text;

    final formatted = text.replaceAllMapped(
      _numberedItemPattern,
      (match) => '\n${match.group(1)}',
    );

    return formatted
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .join('\n');
  }
}

class SoundSettings {
  static const String _soundPrefKey = 'sound_enabled';

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_soundPrefKey) ?? true;
  }
}

class SwipeLimiter {
  static const _kCountKey = 'swipe_limiter_count';
  static const _kWindowStartKey = 'swipe_limiter_window_start';
  static const int maxSwipes = 100;
  static const Duration window = Duration(hours: 3);

  static Future<int> getCount() async {
    final prefs = await SharedPreferences.getInstance();
    await _resetIfExpired(prefs);
    return prefs.getInt(_kCountKey) ?? 0;
  }

  static Future<Duration?> getTimeRemaining() async {
    final prefs = await SharedPreferences.getInstance();
    final startMillis = prefs.getInt(_kWindowStartKey);
    if (startMillis == null) return null;
    final start = DateTime.fromMillisecondsSinceEpoch(startMillis);
    final elapsed = DateTime.now().difference(start);
    final remaining = window - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  static Future<int> increment() async {
    final prefs = await SharedPreferences.getInstance();
    await _resetIfExpired(prefs);
    final hasWindow = prefs.containsKey(_kWindowStartKey);
    if (!hasWindow) {
      await prefs.setInt(
          _kWindowStartKey, DateTime.now().millisecondsSinceEpoch);
    }
    final current = prefs.getInt(_kCountKey) ?? 0;
    final updated = current + 1;
    await prefs.setInt(_kCountKey, updated);
    return updated;
  }

  static Future<bool> hasReachedLimit() async {
    final count = await getCount();
    return count >= maxSwipes;
  }

  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kCountKey);
    await prefs.remove(_kWindowStartKey);
  }

  static Future<void> _resetIfExpired(SharedPreferences prefs) async {
    final startMillis = prefs.getInt(_kWindowStartKey);
    if (startMillis == null) return;
    final start = DateTime.fromMillisecondsSinceEpoch(startMillis);
    if (DateTime.now().difference(start) >= window) {
      await prefs.remove(_kCountKey);
      await prefs.remove(_kWindowStartKey);
    }
  }
}

class RewardLimiter {
  static const _kRewardSwipesKey = 'reward_limiter_swipes';
  static const int maxSwipesBeforeAd = 15;

  static Future<int> getSwipes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kRewardSwipesKey) ?? 0;
  }

  static Future<int> increment() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_kRewardSwipesKey) ?? 0;
    final updated = current + 1;
    await prefs.setInt(_kRewardSwipesKey, updated);
    return updated;
  }

  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRewardSwipesKey);
  }
}

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final CardSwiperController _swiperController = CardSwiperController();

  int _swipeCount = 0;
  bool _limitReached = false;
  Duration? _timeRemaining;
  int _currentIndex = 0;
  final Map<int, bool> _flipped = {};

  List<FeedCard> _feedCards = [];
  String? _previousSessionId;

  int _rewardSwipes = 0;
  bool _rewardLimitReached = false;
  int _maxIndexReached = 0;

  RewardedAd? _rewardedAd;
  bool _isRewardedAdLoading = false;

  bool _isFlipped(int i) => _flipped[i] ?? false;

  void _toggleFlip(int i) =>
      setState(() => _flipped[i] = !(_flipped[i] ?? false));

  int _getQuestionIndex(int timelineIndex, List<TimelineItem> timeline) {
    final count = timeline
        .take(timelineIndex + 1)
        .where((item) => item.type == TimelineItemType.question)
        .length;
    return count > 0 ? count - 1 : 0;
  }

  @override
  void initState() {
    super.initState();
    _loadFeeds();
    _loadRewardedAd();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureLoaded();
      _loadSwipeState();
      _loadRewardLimitState();
      context
          .read<AuthProvider>()
          .setPremiumActivatedListener(_onPremiumUnlocked);
    });
  }

  @override
  void dispose() {
    _swiperController.dispose();
    _rewardedAd?.dispose();
    super.dispose();
  }

  Future<void> _loadFeeds() async {
    try {
      final feeds = await FeedRepository().loadFeed();
      if (mounted) {
        setState(() {
          _feedCards = feeds;
        });
      }
    } catch (_) {}
  }

  void _onPremiumUnlocked() async {
    await SwipeLimiter.reset();
    if (!mounted) return;
    setState(() {
      _swipeCount = 0;
      _limitReached = false;
      _timeRemaining = null;
    });
    if (Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  Future<void> _loadSwipeState() async {
    final auth = context.read<AuthProvider>();
    if (auth.isPremium) {
      if (!mounted) return;
      setState(() {
        _swipeCount = 0;
        _limitReached = false;
        _timeRemaining = null;
      });
      return;
    }
    final count = await SwipeLimiter.getCount();
    final remaining = await SwipeLimiter.getTimeRemaining();
    if (!mounted) return;
    setState(() {
      _swipeCount = count;
      _limitReached = count >= SwipeLimiter.maxSwipes;
      _timeRemaining = remaining;
    });
  }

  Future<void> _ensureLoaded() async {
    if (!mounted) return;
    final quiz = context.read<QuizProvider>();
    if (quiz.state == QuizState.idle || quiz.visibleQuestions.isEmpty) {
      final auth = context.read<AuthProvider>();
      final exam = auth.userProfile?.examType ?? 'UPSC';
      final settings = context.read<TimelineSettingsProvider>();

      await quiz.loadInitial(
        exam,
        mode: settings.mode,
        feedCards: _feedCards,
        spacing: settings.spacing,
        isPremium: auth.isPremium,
      );
    }
  }

  Future<void> _loadRewardLimitState() async {
    final auth = context.read<AuthProvider>();
    if (auth.isPremium) {
      if (!mounted) return;
      setState(() {
        _rewardSwipes = 0;
        _rewardLimitReached = false;
      });
      return;
    }
    final swipes = await RewardLimiter.getSwipes();
    if (!mounted) return;
    setState(() {
      _rewardSwipes = swipes;
      _rewardLimitReached = swipes >= RewardLimiter.maxSwipesBeforeAd;
    });
  }

  void _onPageChanged(
      int index, QuizProvider quiz, TimelineSettingsProvider settings) {
    setState(() => _currentIndex = index);

    final auth = context.read<AuthProvider>();
    final qIndex = _getQuestionIndex(index, quiz.timeline);
    quiz.navigateToQuestion(
      qIndex,
      mode: settings.mode,
      feedCards: _feedCards,
      spacing: settings.spacing,
      isPremium: auth.isPremium,
    );

    if (auth.isPremium) return;

    SwipeLimiter.increment().then((updated) {
      if (!mounted) return;
      setState(() {
        _swipeCount = updated;
        _limitReached = updated >= SwipeLimiter.maxSwipes;
      });
      if (_limitReached) {
        SwipeLimiter.getTimeRemaining().then((remaining) {
          if (!mounted) return;
          setState(() => _timeRemaining = remaining);
        });
      }
    });

    if (index > _maxIndexReached) {
      _maxIndexReached = index;
      RewardLimiter.increment().then((updated) {
        if (!mounted) return;
        setState(() {
          _rewardSwipes = updated;
          _rewardLimitReached = updated >= RewardLimiter.maxSwipesBeforeAd;
        });
      });
    }
  }

  void _loadRewardedAd() {
    if (_isRewardedAdLoading || _rewardedAd != null) return;
    _isRewardedAdLoading = true;

    final adUnitId = defaultTargetPlatform == TargetPlatform.iOS
        ? 'ca-app-pub-3940256099942544/1712485313'
        : 'ca-app-pub-3940256099942544/5224354917';

    RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          setState(() {
            _rewardedAd = ad;
            _isRewardedAdLoading = false;
          });
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _rewardedAd = null;
              _loadRewardedAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _rewardedAd = null;
              _loadRewardedAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          setState(() {
            _isRewardedAdLoading = false;
          });
          print('RewardedAd failed to load: $error');
        },
      ),
    );
  }

  void _showRewardedAd() {
    if (_rewardedAd == null) {
      _loadRewardedAd();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Loading video, please try again in a moment...'),
        ),
      );
      return;
    }

    _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        Future.wait([
          SwipeLimiter.reset(),
          RewardLimiter.reset(),
        ]).then((_) {
          if (!mounted) return;
          setState(() {
            _swipeCount = 0;
            _limitReached = false;
            _timeRemaining = null;
            _rewardSwipes = 0;
            _rewardLimitReached = false;
            _maxIndexReached = _currentIndex;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 15 more questions unlocked!'),
              backgroundColor: QuizColors.success,
            ),
          );
        });
      },
    );
  }

  void _goToNext() {
    final auth = context.read<AuthProvider>();
    if (_limitReached && !auth.isPremium) {
      _showLimitSheet();
      return;
    }
    _swiperController.swipe(CardSwiperDirection.left);
  }

  void _showLimitSheet() {
    final remaining = _timeRemaining;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<AuthProvider>(),
        child: _SwipeLimitSheet(timeRemaining: remaining),
      ),
    );
  }

  Future<void> _showTimelineSettings() async {
    final settings = context.read<TimelineSettingsProvider>();
    final quiz = context.read<QuizProvider>();

    TimelineMode selectedMode = settings.mode;
    int selectedSpacing = settings.spacing;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: QuizColors.card,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .08),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Timeline Settings",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Content",
                        style: TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text("Quiz + Feed"),
                          selected: selectedMode == TimelineMode.mixed,
                          showCheckmark: false,
                          selectedColor: AppColors.accent,
                          labelStyle: TextStyle(
                              fontFamily: 'SpaceGrotesk',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                              color: selectedMode == TimelineMode.mixed
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          onSelected: (_) {
                            setModalState(() {
                              selectedMode = TimelineMode.mixed;
                            });
                          },
                        ),
                        ChoiceChip(
                          label: const Text("Quiz Only"),
                          selected: selectedMode == TimelineMode.quizOnly,
                          selectedColor: AppColors.accent,
                          labelStyle: TextStyle(
                              fontFamily: 'SpaceGrotesk',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                              color: selectedMode == TimelineMode.quizOnly
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          showCheckmark: false,
                          onSelected: (_) {
                            setModalState(() {
                              selectedMode = TimelineMode.quizOnly;
                            });
                          },
                        ),
                        ChoiceChip(
                          label: const Text("Feed Only"),
                          selected: selectedMode == TimelineMode.feedOnly,
                          selectedColor: AppColors.accent,
                          labelStyle: TextStyle(
                              fontFamily: 'SpaceGrotesk',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                              color: selectedMode == TimelineMode.feedOnly
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          showCheckmark: false,
                          onSelected: (_) {
                            setModalState(() {
                              selectedMode = TimelineMode.feedOnly;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: selectedMode == TimelineMode.mixed ? 1 : .35,
                      child: IgnorePointer(
                        ignoring: selectedMode != TimelineMode.mixed,
                        child: Column(
                          children: [
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "Feed every",
                                style: TextStyle(
                                  fontFamily: 'SpaceGrotesk',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              children: [4, 5, 10, 15, 20]
                                  .map(
                                    (e) => ChoiceChip(
                                      label: Text("$e Questions"),
                                      selected: selectedSpacing == e,
                                      selectedColor: AppColors.accent,
                                      labelStyle: TextStyle(
                                          fontFamily: 'SpaceGrotesk',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5,
                                          color: selectedSpacing == e
                                              ? AppColors.textPrimary
                                              : AppColors.textSecondary),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      showCheckmark: false,
                                      onSelected: (_) {
                                        setModalState(() {
                                          selectedSpacing = e;
                                        });
                                      },
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: PSButton(
                            onTap: () {
                              Navigator.pop(context);
                            },
                            label: "Cancel",
                            outlined: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: PSButton(
                            onTap: () async {
                              await settings.setMode(selectedMode);
                              await settings.setSpacing(selectedSpacing);

                              if (!mounted) return;
                              Navigator.pop(context);

                              quiz.rebuildTimeline(
                                mode: selectedMode,
                                feedCards: _feedCards,
                                spacing: selectedSpacing,
                              );
                            },
                            label: "Apply",
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDropdownFilters(
      QuizProvider quiz, TimelineSettingsProvider settings) {
    final years = quiz.availableYears;
    final subjects = quiz.availableSubjects;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      child: Row(
        children: [
          PopupMenuButton<int?>(
            offset: const Offset(0, 45),
            color: QuizColors.card,
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
            onSelected: (value) {
              if (value == null) {
                quiz.applyFilters(
                  years: {},
                  subjects: quiz.selectedSubjects,
                  mode: settings.mode,
                  feedCards: _feedCards,
                  spacing: settings.spacing,
                );
              } else {
                final nextYears = Set<int>.from(quiz.selectedYears);
                if (nextYears.contains(value)) {
                  nextYears.remove(value);
                } else {
                  nextYears.add(value);
                }
                quiz.applyFilters(
                  years: nextYears,
                  subjects: quiz.selectedSubjects,
                  mode: settings.mode,
                  feedCards: _feedCards,
                  spacing: settings.spacing,
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<int?>(
                value: null,
                child: Row(
                  children: [
                    Icon(
                      quiz.selectedYears.isEmpty
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text('All Years',
                        style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              ...years.map((y) {
                final isSelected = quiz.selectedYears.contains(y);
                return PopupMenuItem<int?>(
                  value: y,
                  child: Row(
                    children: [
                      Icon(
                        isSelected
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded,
                        color:
                            isSelected ? const Color(0xFF38BDF8) : Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(y.toString(),
                          style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                );
              }),
            ],
            child: _buildFilterChipButton(
              icon: Icons.calendar_today_outlined,
              label: quiz.selectedYears.isEmpty
                  ? 'Year'
                  : quiz.selectedYears.length == 1
                      ? quiz.selectedYears.first.toString()
                      : '${quiz.selectedYears.length} Years',
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String?>(
            offset: const Offset(0, 45),
            color: QuizColors.card,
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
            onSelected: (value) {
              if (value == null) {
                quiz.applyFilters(
                  years: quiz.selectedYears,
                  subjects: {},
                  mode: settings.mode,
                  feedCards: _feedCards,
                  spacing: settings.spacing,
                );
              } else {
                final nextSubjects = Set<String>.from(quiz.selectedSubjects);
                if (nextSubjects.contains(value)) {
                  nextSubjects.remove(value);
                } else {
                  nextSubjects.add(value);
                }
                quiz.applyFilters(
                  years: quiz.selectedYears,
                  subjects: nextSubjects,
                  mode: settings.mode,
                  feedCards: _feedCards,
                  spacing: settings.spacing,
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String?>(
                value: null,
                child: Row(
                  children: [
                    Icon(
                      quiz.selectedSubjects.isEmpty
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text('All Subjects',
                        style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              ...subjects.map((s) {
                final isSelected = quiz.selectedSubjects.contains(s);
                return PopupMenuItem<String?>(
                  value: s,
                  child: Row(
                    children: [
                      Icon(
                        isSelected
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded,
                        color:
                            isSelected ? const Color(0xFF38BDF8) : Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(s, style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                );
              }),
            ],
            child: _buildFilterChipButton(
              icon: Icons.book_outlined,
              label: quiz.selectedSubjects.isEmpty
                  ? 'Subject'
                  : quiz.selectedSubjects.length == 1
                      ? quiz.selectedSubjects.first
                      : '${quiz.selectedSubjects.length} Subjects',
            ),
          ),
          const SizedBox(width: 8),
          _buildFilterChipButton(
            icon: Icons.school_outlined,
            label: quiz.currentExam ?? 'Exam',
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildFilterChipButton(
      {required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF141927),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF38BDF8), size: 15),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            Icons.arrow_drop_down,
            color: Colors.white.withValues(alpha: 0.6),
            size: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFilters(
      QuizProvider quiz, TimelineSettingsProvider settings) {
    final hasFilters =
        quiz.selectedYears.isNotEmpty || quiz.selectedSubjects.isNotEmpty;
    if (!hasFilters) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      child: Row(
        children: [
          ...quiz.selectedYears.map((y) => Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: _buildActiveChip(
                  label: 'Year: $y',
                  onClear: () {
                    final nextYears = Set<int>.from(quiz.selectedYears)
                      ..remove(y);
                    quiz.applyFilters(
                      years: nextYears,
                      subjects: quiz.selectedSubjects,
                      mode: settings.mode,
                      feedCards: _feedCards,
                      spacing: settings.spacing,
                    );
                  },
                ),
              )),
          ...quiz.selectedSubjects.map((s) => Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: _buildActiveChip(
                  label: 'Subject: $s',
                  onClear: () {
                    final nextSubjects = Set<String>.from(quiz.selectedSubjects)
                      ..remove(s);
                    quiz.applyFilters(
                      years: quiz.selectedYears,
                      subjects: nextSubjects,
                      mode: settings.mode,
                      feedCards: _feedCards,
                      spacing: settings.spacing,
                    );
                  },
                ),
              )),
          GestureDetector(
            onTap: () {
              quiz.clearFilters(
                mode: settings.mode,
                feedCards: _feedCards,
                spacing: settings.spacing,
              );
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                'Clear all',
                style: TextStyle(
                  color: Color(0xFF38BDF8),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveChip(
      {required String label, required VoidCallback onClear}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF141927).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onClear,
            child: Icon(
              Icons.close_rounded,
              color: Colors.white.withValues(alpha: 0.5),
              size: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyFilterState(
      QuizProvider quiz, TimelineSettingsProvider settings) {
    final hasFilters =
        quiz.selectedYears.isNotEmpty || quiz.selectedSubjects.isNotEmpty;
    if (hasFilters) {
      return SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDropdownFilters(quiz, settings),
            _buildActiveFilters(quiz, settings),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.filter_list_off_rounded,
                        color: QuizColors.textTertiary,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No questions match your filters',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Try relaxing some filters or clear all to show everything.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: QuizColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: 180,
                        child: PSButton(
                          label: 'Reset Filters',
                          onTap: () {
                            quiz.clearFilters(
                              mode: settings.mode,
                              feedCards: _feedCards,
                              spacing: settings.spacing,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return const PSLoader(message: "Preparing timeline...");
  }

  @override
  Widget build(BuildContext context) {
    final quiz = context.watch<QuizProvider>();
    final auth = context.watch<AuthProvider>();
    final settings = context.watch<TimelineSettingsProvider>();
    final reachedQuota = _rewardLimitReached;
    final blocked = reachedQuota || (_limitReached && !auth.isPremium);

    final timeline = quiz.timeline;

    if (_previousSessionId != quiz.sessionId) {
      _previousSessionId = quiz.sessionId;
      _currentIndex = 0;
      _maxIndexReached = 0;
    }

    return Scaffold(
      backgroundColor: QuizColors.background,
      body: switch (quiz.state) {
        QuizState.idle ||
        QuizState.loading when quiz.visibleQuestions.isEmpty =>
          const PSLoader(message: 'Loading questions…'),
        QuizState.error when quiz.visibleQuestions.isEmpty => _ErrorView(
            message: quiz.error ?? 'Something went wrong',
            onRetry: () {
              final authP = context.read<AuthProvider>();
              final exam = authP.userProfile?.examType ?? 'UPSC';

              quiz.loadInitial(
                exam,
                mode: settings.mode,
                feedCards: _feedCards,
                spacing: settings.spacing,
              );
            },
          ),
        _ when timeline.isEmpty => _buildEmptyFilterState(quiz, settings),
        _ => SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDropdownFilters(quiz, settings),
                _buildActiveFilters(quiz, settings),
                const SizedBox(height: 12),
                Expanded(
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        child: CardSwiper(
                          key: ValueKey(quiz.sessionId),
                          controller: _swiperController,
                          cardsCount: timeline.length,
                          numberOfCardsDisplayed:
                              timeline.length > 2 ? 3 : timeline.length,
                          backCardOffset: const Offset(0, -12),
                          padding: EdgeInsets.zero,
                          isDisabled: blocked,
                          threshold: 100,
                          allowedSwipeDirection:
                              const AllowedSwipeDirection.only(
                            left: true,
                            right: true,
                          ),
                          onSwipe: (previousIndex, currentIndex, direction) {
                            final item = timeline[previousIndex];
                            final isQuestion =
                                item.type == TimelineItemType.question;
                            final qIndex = isQuestion
                                ? _getQuestionIndex(previousIndex, timeline)
                                : -1;
                            final isAnswered =
                                qIndex != -1 && quiz.isSubmitted(qIndex);
                            final isUnanswered = isQuestion && !isAnswered;

                            if (isUnanswered) {
                              if (direction != CardSwiperDirection.left &&
                                  direction != CardSwiperDirection.right) {
                                return false;
                              }
                            }

                            if (currentIndex != null) {
                              _onPageChanged(currentIndex, quiz, settings);
                            }
                            return true;
                          },
                          onUndo: (previousIndex, currentIndex, direction) {
                            _onPageChanged(currentIndex, quiz, settings);
                            return true;
                          },
                          cardBuilder: (context, index, percentX, percentY) {
                            final item = timeline[index];
                            final isQuestion =
                                item.type == TimelineItemType.question;
                            final qIndex = isQuestion
                                ? _getQuestionIndex(index, timeline)
                                : -1;
                            final isAnswered =
                                qIndex != -1 && quiz.isSubmitted(qIndex);
                            final isUnansweredQuestion =
                                isQuestion && !isAnswered;

                            final cardWidget = () {
                              switch (item.type) {
                                case TimelineItemType.question:
                                  return _QuestionCard(
                                    question: item.data,
                                    questionIndex: qIndex,
                                    onNavigateNext: _goToNext,
                                  );

                                case TimelineItemType.feed:
                                  final flipped = _isFlipped(index);
                                  return GestureDetector(
                                    onTap: () => _toggleFlip(index),
                                    behavior: HitTestBehavior.opaque,
                                    child: FlipCard(
                                      flipped: flipped,
                                      front: buildFront(
                                          timeline[index].data as FeedCard,
                                          index),
                                      back: buildBack(
                                          timeline[index].data as FeedCard,
                                          index),
                                    ),
                                  );

                                case TimelineItemType.ad:
                                  return const _AdCard();
                              }
                            }();

                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                cardWidget,
                                if (isUnansweredQuestion && percentX != 0) ...[
                                  Positioned.fill(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(24),
                                      child: Container(
                                        color: Colors.black.withValues(
                                            alpha: ((percentX.abs())
                                                        .clamp(0, 100) /
                                                    100.0) *
                                                0.75),
                                      ),
                                    ),
                                  ),
                                  Center(
                                    child: Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        color: Colors.black45,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white
                                                .withValues(alpha: 0.1),
                                            width: 1.5),
                                      ),
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          SizedBox(
                                            width: 60,
                                            height: 60,
                                            child: CircularProgressIndicator(
                                              value: ((percentX.abs())
                                                      .clamp(0, 100) /
                                                  100.0),
                                              strokeWidth: 4,
                                              valueColor:
                                                  const AlwaysStoppedAnimation<
                                                      Color>(AppColors.primary),
                                              backgroundColor: Colors.white24,
                                            ),
                                          ),
                                          const Icon(
                                            Icons.skip_next_rounded,
                                            color: Colors.white,
                                            size: 32,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                      ),
                      if (blocked)
                        _LimitOverlay(
                          title: _rewardLimitReached
                              ? 'Unlock More Questions'
                              : 'Daily Limit Reached',
                          subtitle: _rewardLimitReached
                              ? 'Watch a quick video to unlock 15 more questions'
                              : 'Tap to unlock or upgrade to Premium',
                          icon: _rewardLimitReached
                              ? Icons.play_circle_outline_rounded
                              : Icons.lock_rounded,
                          onTap: _rewardLimitReached
                              ? _showRewardedAd
                              : _showLimitSheet,
                        ),
                      if (!blocked)
                        Positioned(
                          right: 16,
                          bottom: 20,
                          child: _FloatingButton(
                              onTap: _goToNext,
                              icon: Icons.keyboard_arrow_right_rounded),
                        ),
                      if (!blocked && _currentIndex > 0)
                        Positioned(
                          right: 16,
                          bottom: 70,
                          child: _FloatingButton(
                              onTap: () {
                                _swiperController.undo();
                              },
                              icon: Icons.keyboard_arrow_left_rounded),
                        ),
                      Positioned(
                        right: 16,
                        bottom: (!blocked && _currentIndex > 0) ? 120 : 70,
                        child: _FloatingButton(
                            onTap: _showTimelineSettings, icon: Icons.settings),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      },
    );
  }
}

class _FloatingButton extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  const _FloatingButton({required this.onTap, required this.icon});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: QuizColors.card,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: QuizColors.textSecondary,
          size: 24,
        ),
      ),
    );
  }
}

class _QuestionCard extends StatefulWidget {
  final Question question;
  final int questionIndex;
  final VoidCallback onNavigateNext;

  const _QuestionCard({
    required this.question,
    required this.questionIndex,
    required this.onNavigateNext,
  });

  @override
  State<_QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<_QuestionCard>
    with TickerProviderStateMixin {
  bool _isSaved = false;
  bool _isSaving = false;
  bool _explanationOpen = false;
  late AnimationController _panelController;
  late Animation<Offset> _panelSlide;
  late final AudioPlayer _audioPlayer;
  late AnimationController _feedbackController;
  late Animation<double> _shakeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _panelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _panelSlide = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _panelController,
      curve: Curves.easeOutCubic,
    ));
    _feedbackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -4.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -4.0, end: 4.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 4.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _feedbackController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeInOut),
    ));
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.05), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.05, end: 0.98), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.98, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _feedbackController,
      curve: Curves.easeInOut,
    ));
    _checkBookmarkStatus();
  }

  @override
  void dispose() {
    _panelController.dispose();
    _feedbackController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _checkBookmarkStatus() async {
    try {
      final bookmarks = await ApiService().getBookmarks();
      if (!mounted) return;
      final alreadySaved = bookmarks.any((bm) {
        final q = bm['question'];
        if (q == null) return false;
        return q['_id']?.toString() == widget.question.id?.toString();
      });
      setState(() => _isSaved = alreadySaved);
    } catch (_) {}
  }

  Future<void> _toggleSave() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      if (_isSaved) {
        await ApiService().removeBookmark(questionId: widget.question.id);
        if (mounted) {
          setState(() => _isSaved = false);
          _showSnack('Removed from saved');
        }
      } else {
        await ApiService().addBookmark(questionId: widget.question.id);
        if (mounted) {
          setState(() => _isSaved = true);
          _showSnack('Question saved!');
        }
      }
    } catch (e) {
      if (mounted) _showSnack('Could not save question');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 9.75,
            color: Colors.white,
          ),
        ),
        backgroundColor: QuizColors.card,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _openExplanation() {
    setState(() => _explanationOpen = true);
    _panelController.forward();
  }

  void _closeExplanation() {
    _panelController.reverse().then((_) {
      if (mounted) setState(() => _explanationOpen = false);
    });
  }

  void _closeAndNext() {
    _panelController.reverse().then((_) {
      if (mounted) {
        setState(() => _explanationOpen = false);
        widget.onNavigateNext();
      }
    });
  }

  Future<void> _onShare(AppLanguage lang) async {
    final q = widget.question;
    final correctOpt = q.optionsFor(lang)[q.correctAnswer.toString()] ?? '';
    final formattedQuestion =
        QuestionTextFormatter.format(q.questionText(lang));
    final shareText =
        '🎯 PrepSwipe Quiz\n\n📘 ${q.exam} ${q.year} | ${q.subject}${q.topic != null ? ' › ${q.topic}' : ''}\n\n❓ $formattedQuestion\n\n${q.optionList(lang).map((o) => '${o.key}. ${o.value}').join('\n')}\n\n✅ Answer: ${q.correctAnswer}. $correctOpt\n\nPractice more PYQs on PrepSwipe 👇\nhttps://play.google.com/store/apps/details?id=com.anuritinnovation.prepswipe';
    await Share.share(shareText,
        subject: 'PrepSwipe – ${q.exam} ${q.year} Question');
  }

  Future<void> _playCorrectSound() async {
    try {
      print("playing correct");
      final enabled = await SoundSettings.isEnabled();
      if (!enabled || !mounted) return;
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('music/correct_answer.mp3'));
    } catch (e) {
      print("Error playing correct sound: $e");
    }
  }

  Future<void> _playInCorrectSound() async {
    try {
      print("playing incorrect");
      final enabled = await SoundSettings.isEnabled();
      if (!enabled || !mounted) return;
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('music/wrong_answer.mp3'));
    } catch (e) {
      print("Error playing incorrect sound: $e");
    }
  }

  Future<void> _submit(BuildContext context, int index) async {
    final quizProvider = context.read<QuizProvider>();
    await quizProvider.submitQuestion(index);
    if (!mounted) return;
    context.read<AnalyticsProvider>().invalidate();
    final selected = quizProvider.selectedOptionFor(index);
    _feedbackController.forward(from: 0.0);
    if (selected == widget.question.correctAnswer) {
      await _playCorrectSound();
    } else {
      await _playInCorrectSound();
    }
  }

  @override
  Widget build(BuildContext context) {
    final quiz = context.watch<QuizProvider>();
    final lang = quiz.language;
    final selected = quiz.selectedOptionFor(widget.questionIndex);
    final submitted = quiz.isSubmitted(widget.questionIndex);
    final explanation = widget.question.explanation(lang);
    final isCorrect = selected == widget.question.correctAnswer;

    return AnimatedBuilder(
      animation: _feedbackController,
      builder: (context, child) {
        final scaleValue =
            (submitted && isCorrect) ? _scaleAnimation.value : 1.0;
        final shakeValue =
            (submitted && !isCorrect) ? _shakeAnimation.value : 0.0;

        return Transform.translate(
          offset: Offset(shakeValue, 0.0),
          child: Transform.scale(
            scale: scaleValue,
            child: child,
          ),
        );
      },
      child: LayoutBuilder(
        builder: (context, outerConstraints) {
          return SizedBox(
            height: outerConstraints.maxHeight,
            width: outerConstraints.maxWidth,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: Container(
                      height: outerConstraints.maxHeight,
                      decoration: BoxDecoration(
                        color: QuizColors.card.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: QuizColors.primary.withValues(alpha: 0.12),
                            blurRadius: 28,
                            spreadRadius: -8,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: _ScrollableCardContent(
                        question: widget.question,
                        questionIndex: widget.questionIndex,
                        language: lang,
                        selected: selected,
                        submitted: submitted,
                        onSubmit: () => _submit(context, widget.questionIndex),
                      ),
                    ),
                  ),
                ),
                if (submitted && isCorrect)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.green.withValues(alpha: 0.2),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  right: 10,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _CardActionBar(
                      isSaved: _isSaved,
                      isSaving: _isSaving,
                      onSave: _toggleSave,
                      onExplain: _openExplanation,
                      onShare: () => _onShare(lang),
                    ),
                  ),
                ),
                if (_explanationOpen)
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: _closeExplanation,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                if (_explanationOpen)
                  Positioned(
                    top: 0,
                    bottom: 0,
                    right: 0,
                    width: MediaQuery.of(context).size.width * 0.82,
                    child: SlideTransition(
                      position: _panelSlide,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          bottomLeft: Radius.circular(20),
                          topRight: Radius.circular(24),
                          bottomRight: Radius.circular(24),
                        ),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Container(
                            decoration: BoxDecoration(
                              color: QuizColors.card.withValues(alpha: 0.97),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(20),
                                bottomLeft: Radius.circular(20),
                                topRight: Radius.circular(24),
                                bottomRight: Radius.circular(24),
                              ),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                                width: 1,
                              ),
                            ),
                            child: _ExplanationPanel(
                              explanation: explanation,
                              onClose: _closeExplanation,
                              onNext: _closeAndNext,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ScrollableCardContent extends StatelessWidget {
  final Question question;
  final int questionIndex;
  final AppLanguage language;
  final int? selected;
  final bool submitted;
  final VoidCallback onSubmit;

  const _ScrollableCardContent({
    required this.question,
    required this.questionIndex,
    required this.language,
    required this.selected,
    required this.submitted,
    required this.onSubmit,
  });

  Widget _buildCustomBadge(String label,
      {required Color textColor, required Color bgColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 64, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildCustomBadge(
                    question.year.toString(),
                    textColor: const Color(0xFFF59E0B),
                    bgColor: const Color(0xFF2D1E10),
                  ),
                  _buildCustomBadge(
                    question.subject,
                    textColor: const Color(0xFF94A3B8),
                    bgColor: const Color(0xFF1E293B),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            QuestionTextFormatter.format(question.questionText(language)),
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12.0,
              fontWeight: FontWeight.w400,
              color: QuizColors.textPrimary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          ...question.optionList(language).map((opt) {
            final optKey = int.tryParse(opt.key) ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _OptionTile(
                optionKey: optKey,
                optionLabel: opt.key,
                optionText: opt.value,
                selected: selected == optKey,
                submitted: submitted,
                isCorrect: question.correctAnswer == optKey,
                onTap: submitted
                    ? null
                    : () => context
                        .read<QuizProvider>()
                        .selectOption(questionIndex, optKey),
              ),
            );
          }),
          const SizedBox(height: 6),
          if (!submitted) ...[
            SizedBox(
              width: double.infinity,
              child: PSButton(
                label: 'Submit Answer',
                icon: Icons.check_rounded,
                color: selected == null
                    ? QuizColors.textTertiary
                    : QuizColors.primary,
                onTap: selected == null ? null : onSubmit,
              ),
            ),
          ] else ...[
            _ResultCard(
              isCorrect: selected == question.correctAnswer,
              correctAnswer:
                  '${question.correctAnswer}. ${question.optionsFor(language)[question.correctAnswer.toString()] ?? ''}',
            ),
          ],
        ],
      ),
    );
  }
}

class _ExplanationPanel extends StatelessWidget {
  final String? explanation;
  final VoidCallback onClose;
  final VoidCallback onNext;

  const _ExplanationPanel({
    required this.explanation,
    required this.onClose,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 0),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Explanation',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12.0,
                    fontWeight: FontWeight.w600,
                    color: QuizColors.textPrimary,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onClose,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: QuizColors.textSecondary,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 1,
          color: Colors.white.withValues(alpha: 0.06),
        ),
        Expanded(
          child: explanation != null && explanation!.isNotEmpty
              ? SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Text(
                    explanation!,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w400,
                      color: QuizColors.textSecondary,
                      height: 1.6,
                    ),
                  ),
                )
              : const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No explanation available for this question.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w400,
                        color: QuizColors.textTertiary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
        ),
        Container(
          height: 1,
          color: Colors.white.withValues(alpha: 0.06),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: onNext,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: QuizColors.primary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: QuizColors.primary.withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Next Question',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: QuizColors.primary,
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: QuizColors.primary,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CardActionBar extends StatelessWidget {
  final bool isSaved;
  final bool isSaving;
  final VoidCallback onSave;
  final VoidCallback onExplain;
  final VoidCallback onShare;

  const _CardActionBar({
    required this.isSaved,
    required this.isSaving,
    required this.onSave,
    required this.onExplain,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionButton(
          icon:
              isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          label: 'Save',
          iconColor: isSaved ? QuizColors.primary : QuizColors.textSecondary,
          isLoading: isSaving,
          onTap: onSave,
        ),
        const SizedBox(height: 20),
        _ActionButton(
          icon: Icons.help_outline_rounded,
          label: 'Explain',
          iconColor: QuizColors.textSecondary,
          onTap: onExplain,
        ),
        const SizedBox(height: 20),
        _ActionButton(
          icon: Icons.share_rounded,
          label: 'Share',
          iconColor: QuizColors.textSecondary,
          onTap: onShare,
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final bool isLoading;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 40,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: QuizColors.primary,
                    ),
                  )
                : Icon(icon, color: iconColor, size: 26),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 7.5,
                fontWeight: FontWeight.w500,
                color: QuizColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final int optionKey;
  final String optionLabel;
  final String optionText;
  final bool selected;
  final bool submitted;
  final bool isCorrect;
  final VoidCallback? onTap;

  const _OptionTile({
    required this.optionKey,
    required this.optionLabel,
    required this.optionText,
    required this.selected,
    required this.submitted,
    required this.isCorrect,
    this.onTap,
  });

  Color _bgColor() {
    if (!submitted) {
      return selected
          ? QuizColors.primary.withValues(alpha: 0.10)
          : Colors.white.withValues(alpha: 0.03);
    }
    if (isCorrect) return QuizColors.success.withValues(alpha: 0.10);
    if (selected && !isCorrect) return QuizColors.error.withValues(alpha: 0.10);
    return Colors.white.withValues(alpha: 0.03);
  }

  Color _borderColor() {
    if (!submitted) {
      return selected ? QuizColors.primary : QuizColors.cardBorder;
    }
    if (isCorrect) return QuizColors.success;
    if (selected && !isCorrect) return QuizColors.error;
    return QuizColors.cardBorder;
  }

  Color _labelColor() {
    if (!submitted) {
      return selected ? QuizColors.primary : QuizColors.textSecondary;
    }
    if (isCorrect) return QuizColors.success;
    if (selected && !isCorrect) return QuizColors.error;
    return QuizColors.textTertiary;
  }

  Widget? _trailingIcon() {
    if (!submitted) return null;
    if (isCorrect) {
      return const Icon(Icons.check_circle_rounded,
          color: QuizColors.success, size: 20);
    }
    if (selected && !isCorrect) {
      return const Icon(Icons.cancel_rounded,
          color: QuizColors.error, size: 20);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: _bgColor(),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _borderColor(), width: 1.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: _labelColor().withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  optionLabel,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 9.0,
                    fontWeight: FontWeight.w700,
                    color: _labelColor(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  optionText,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w400,
                    color: submitted && !isCorrect && !selected
                        ? QuizColors.textTertiary
                        : QuizColors.textPrimary,
                    height: 1.45,
                  ),
                ),
              ),
            ),
            if (_trailingIcon() != null) ...[
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: _trailingIcon()!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final bool isCorrect;
  final String correctAnswer;

  const _ResultCard({required this.isCorrect, required this.correctAnswer});

  @override
  Widget build(BuildContext context) {
    final color = isCorrect ? QuizColors.success : QuizColors.error;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: color,
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                isCorrect ? 'Correct! 🎉' : 'Incorrect',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12.0,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          if (!isCorrect) ...[
            const SizedBox(height: 10),
            const Text(
              'CORRECT ANSWER',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 8.25,
                fontWeight: FontWeight.w600,
                color: QuizColors.textSecondary,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              correctAnswer,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 10.5,
                fontWeight: FontWeight.w400,
                color: QuizColors.textPrimary,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LimitOverlay extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _LimitOverlay({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: QuizColors.background.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: QuizColors.secondary.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child:
                            Icon(icon, color: QuizColors.secondary, size: 28),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12.75,
                          fontWeight: FontWeight.w700,
                          color: QuizColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 9.75,
                          color: QuizColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdCard extends StatefulWidget {
  const _AdCard();

  @override
  State<_AdCard> createState() => _AdCardState();
}

class _AdCardState extends State<_AdCard> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  bool _adError = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    final adUnitId = defaultTargetPlatform == TargetPlatform.iOS
        ? 'ca-app-pub-3940256099942544/2934735716'
        : 'ca-app-pub-3940256099942544/6300978111';

    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      size: AdSize.mediumRectangle,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          setState(() {
            _adError = true;
          });
          print('Ad failed to load: $error');
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: QuizColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
          width: 1,
        ),
      ),
      alignment: Alignment.center,
      child: _adError
          ? const Center(
              child: Text(
                'Sponsored Link',
                style: TextStyle(color: QuizColors.textTertiary, fontSize: 13),
              ),
            )
          : !_isAdLoaded
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 300,
                    height: 250,
                    child: AdWidget(ad: _bannerAd!),
                  ),
                ),
    );
  }
}

class _SwipeLimitSheet extends StatefulWidget {
  final Duration? timeRemaining;
  const _SwipeLimitSheet({required this.timeRemaining});

  @override
  State<_SwipeLimitSheet> createState() => _SwipeLimitSheetState();
}

class _SwipeLimitSheetState extends State<_SwipeLimitSheet> {
  late final Duration? _remaining = widget.timeRemaining;

  Future<void> _handleSubscribe() async {
    final auth = context.read<AuthProvider>();
    await auth.purchase();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final remaining = _remaining ?? Duration.zero;
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          decoration: BoxDecoration(
            color: QuizColors.card.withValues(alpha: 0.92),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: QuizColors.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'You\'ve hit today\'s free limit',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: QuizColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You\'ve answered ${SwipeLimiter.maxSwipes} questions. '
                'More unlock in $hours h $minutes m, or upgrade to keep going now.',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10.5,
                  color: QuizColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: QuizColors.secondary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: QuizColors.secondary.withValues(alpha: 0.30),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: QuizColors.secondary.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.workspace_premium_rounded,
                          color: QuizColors.secondary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PrepSwipe Premium',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11.25,
                              fontWeight: FontWeight.w700,
                              color: QuizColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Unlimited swipes, no daily cap',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 9.0,
                              color: QuizColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹39',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14.0,
                            fontWeight: FontWeight.w800,
                            color: QuizColors.secondary,
                          ),
                        ),
                        Text(
                          '/ month',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 8.25,
                            color: QuizColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: PSButton(
                  label: auth.purchaseLoading
                      ? 'Processing…'
                      : 'Subscribe @ ₹39/month',
                  icon: Icons.workspace_premium_rounded,
                  color: QuizColors.secondary,
                  onTap: auth.purchaseLoading ? null : _handleSubscribe,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: auth.purchaseLoading
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text(
                    'Got it',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      color: QuizColors.textTertiary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return PSEmptyState(
      icon: Icons.wifi_off_rounded,
      title: 'Failed to load questions',
      subtitle: message,
      action: PSButton(
        label: 'Retry',
        icon: Icons.refresh_rounded,
        onTap: onRetry,
      ),
    );
  }
}
