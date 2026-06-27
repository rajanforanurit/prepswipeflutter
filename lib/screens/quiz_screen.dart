import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
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

class SwipeLimiter {
  static const _kCountKey = 'swipe_limiter_count';
  static const _kWindowStartKey = 'swipe_limiter_window_start';
  static const int maxSwipes = 30;
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureLoaded();
      _loadSwipeState();
    });
  }

  Future<void> _loadSwipeState() async {
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
    if (quiz.state == QuizState.idle || quiz.questions.isEmpty) {
      final auth = context.read<AuthProvider>();
      final exam = auth.userProfile?.examType ?? 'UPSC';
      await quiz.loadQuestions(exam);
    }
  }

  bool _onSwipe(
    int previousIndex,
    int? currentIndex,
    CardSwiperDirection direction,
  ) {
    if (_limitReached) return false;

    final nextIndex = currentIndex ?? previousIndex;
    setState(() => _currentIndex = nextIndex);
    context.read<QuizProvider>().navigateToQuestion(nextIndex);

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

    return true;
  }

  void _goToNext() {
    if (_limitReached) {
      _showLimitSheet();
      return;
    }
    _swiperController.swipe(CardSwiperDirection.top);
  }

  void _showLimitSheet() {
    final remaining = _timeRemaining;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SwipeLimitSheet(timeRemaining: remaining),
    );
  }

  @override
  void dispose() {
    _swiperController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quiz = context.watch<QuizProvider>();
    final auth = context.watch<AuthProvider>();
    final examType = auth.userProfile?.examType ?? 'UPSC';

    return Scaffold(
      backgroundColor: QuizColors.background,
      body: switch (quiz.state) {
        QuizState.idle ||
        QuizState.loading when quiz.questions.isEmpty =>
          const PSLoader(message: 'Loading questions…'),
        QuizState.error when quiz.questions.isEmpty => _ErrorView(
            message: quiz.error ?? 'Something went wrong',
            onRetry: () {
              final auth = context.read<AuthProvider>();
              final exam = auth.userProfile?.examType ?? 'UPSC';
              quiz.loadQuestions(exam, refresh: true);
            },
          ),
        _ => SafeArea(
            child: Column(
              children: [
                _CompactHeader(examType: examType),
                Expanded(
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        child: CardSwiper(
                          controller: _swiperController,
                          cardsCount: quiz.questions.length,
                          numberOfCardsDisplayed:
                              quiz.questions.length >= 2 ? 2 : 1,
                          isLoop: false,
                          isDisabled: false,
                          allowedSwipeDirection:
                              const AllowedSwipeDirection.only(
                                  up: true, down: true),
                          backCardOffset: const Offset(0, 28),
                          padding: EdgeInsets.zero,
                          onSwipe: _onSwipe,
                          cardBuilder: (
                            context,
                            index,
                            percentThresholdX,
                            percentThresholdY,
                          ) {
                            return _QuestionCard(
                              question: quiz.questions[index],
                              questionIndex: index,
                              onNavigateNext: _goToNext,
                            );
                          },
                        ),
                      ),
                      if (_limitReached) _LimitOverlay(onTap: _showLimitSheet),
                      if (!_limitReached)
                        Positioned(
                          right: 24,
                          bottom: 20,
                          child: _NextButton(onTap: _goToNext),
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

class _CompactHeader extends StatelessWidget {
  final String examType;
  const _CompactHeader({required this.examType});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          RichText(
            text: const TextSpan(
              children: [
                TextSpan(
                  text: 'Prep',
                  style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.5,
                    height: 1.0,
                  ),
                ),
                TextSpan(
                  text: 'Swipe',
                  style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: QuizColors.gold,
                    letterSpacing: -0.5,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: QuizColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: QuizColors.primary.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Text(
              examType,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 9.0,
                fontWeight: FontWeight.w600,
                color: QuizColors.primary,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NextButton extends StatelessWidget {
  final VoidCallback onTap;
  const _NextButton({required this.onTap});

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
        child: const Icon(
          Icons.keyboard_arrow_down_rounded,
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
    with SingleTickerProviderStateMixin {
  bool _isSaved = false;
  bool _isSaving = false;
  bool _explanationOpen = false;
  late AnimationController _panelController;
  late Animation<Offset> _panelSlide;

  @override
  void initState() {
    super.initState();
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
    _checkBookmarkStatus();
  }

  @override
  void dispose() {
    _panelController.dispose();
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

  Future<void> _onShare() async {
    final q = widget.question;
    final correctOpt = q.options[q.correctAnswer.toString()] ?? '';
    final shareText =
        '🎯 PrepSwipe Quiz\n\n📘 ${q.exam} ${q.year} | ${q.subject}${q.topic != null ? ' › ${q.topic}' : ''}\n\n❓ ${q.questionText}\n\n${q.optionList.map((o) => '${o.key}. ${o.value}').join('\n')}\n\n✅ Answer: ${q.correctAnswer}. $correctOpt\n\nPractice more PYQs on PrepSwipe 👇\nhttps://play.google.com/store/apps/details?id=com.anuritinnovation.prepswipe';
    await Share.share(shareText,
        subject: 'PrepSwipe – ${q.exam} ${q.year} Question');
  }

  @override
  Widget build(BuildContext context) {
    final quiz = context.watch<QuizProvider>();
    final selected = quiz.selectedOptionFor(widget.questionIndex);
    final submitted = quiz.isSubmitted(widget.questionIndex);
    final explanation = widget.question.explanation;

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              constraints: const BoxConstraints(minHeight: double.infinity),
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return _ScrollableCardContent(
                    question: widget.question,
                    questionIndex: widget.questionIndex,
                    selected: selected,
                    submitted: submitted,
                    onSubmit: () => _submit(context, widget.questionIndex),
                    maxHeight: constraints.maxHeight,
                  );
                },
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
              onShare: _onShare,
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
    );
  }

  Future<void> _submit(BuildContext context, int index) async {
    await context.read<QuizProvider>().submitQuestion(index);
    context.read<AnalyticsProvider>().invalidate();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// THE CORE FIX
//
// Problem: flutter_card_swiper uses onPanUpdate (a GestureDetector) to move
// the card. SingleChildScrollView ALSO registers a vertical drag recognizer.
// They fight in the gesture arena — and the scroll always wins on long cards
// because it gets priority as an inner widget.
//
// Solution: Use a raw Listener widget (pointer events, NOT the gesture arena)
// to intercept touch events BEFORE the gesture system. On every PointerMove:
//   1. If there is no scrollable overflow → do nothing → swiper handles it
//   2. If scrolling mid-content → manually drive ScrollController.jumpTo()
//      and mark this touch as "claimed by scroll" so swiper gets nothing
//   3. If at top edge AND dragging down → let swiper win (previous card)
//   4. If at bottom edge AND dragging up → let swiper win (next card)
//
// Because Listener is below the arena, it can intercept and absorb events
// without interfering when not needed. We use a simple bool flag per pointer
// to track intent once decided on the first move of each gesture.
// ─────────────────────────────────────────────────────────────────────────────

class _ScrollableCardContent extends StatefulWidget {
  final Question question;
  final int questionIndex;
  final int? selected;
  final bool submitted;
  final VoidCallback onSubmit;
  final double maxHeight;

  const _ScrollableCardContent({
    required this.question,
    required this.questionIndex,
    required this.selected,
    required this.submitted,
    required this.onSubmit,
    required this.maxHeight,
  });

  @override
  State<_ScrollableCardContent> createState() => _ScrollableCardContentState();
}

class _ScrollableCardContentState extends State<_ScrollableCardContent> {
  final ScrollController _scrollController = ScrollController();

  // Per-gesture state — reset on every PointerDown
  bool _gestureClaimedByScroll = false;

  static const double _kDragThreshold = 5.0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool get _hasOverflow {
    if (!_scrollController.hasClients) return false;
    return _scrollController.position.maxScrollExtent > 0.0;
  }

  bool get _isAtTop {
    if (!_scrollController.hasClients) return true;
    return _scrollController.position.pixels <=
        _scrollController.position.minScrollExtent + 1.0;
  }

  bool get _isAtBottom {
    if (!_scrollController.hasClients) return true;
    return _scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 1.0;
  }

  void _onPointerDown(PointerDownEvent event) {
    _gestureClaimedByScroll = false;
  }

  void _onPointerMove(PointerMoveEvent event) {
    final dy = event.delta.dy;

    // No scrollable content at all — let the swiper handle everything
    if (!_hasOverflow) return;

    // Already decided for this gesture: keep scrolling
    if (_gestureClaimedByScroll) {
      _scrollBy(-dy);
      return;
    }

    // Not yet decided. Only act on meaningful movement.
    if (dy.abs() < _kDragThreshold) return;

    final draggingUp =
        dy < 0; // finger moving up = scroll down (show more below)
    final draggingDown =
        dy > 0; // finger moving down = scroll up (show more above)

    // At top edge and trying to scroll further up (drag down) → give to swiper
    if (draggingDown && _isAtTop) return;

    // At bottom edge and trying to scroll further down (drag up) → give to swiper
    if (draggingUp && _isAtBottom) return;

    // We are mid-scroll or scrolling toward content — claim it
    _gestureClaimedByScroll = true;
    _scrollBy(-dy);
  }

  void _onPointerUp(PointerUpEvent event) {
    _gestureClaimedByScroll = false;
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _gestureClaimedByScroll = false;
  }

  void _scrollBy(double delta) {
    if (!_scrollController.hasClients) return;
    final newOffset = (_scrollController.offset + delta).clamp(
      _scrollController.position.minScrollExtent,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.jumpTo(newOffset);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      // HitTestBehavior.translucent: we receive events AND pass them through
      // to children (so taps on options/buttons still work)
      behavior: HitTestBehavior.translucent,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: widget.maxHeight),
        child: SingleChildScrollView(
          controller: _scrollController,
          // NeverScrollableScrollPhysics: disables the scroll widget's own
          // gesture handling entirely. We drive it manually via jumpTo above.
          // This is critical — without this, both Listener AND the scroll
          // widget respond to the same touch, causing jitter/conflict.
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 64, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  PSBadge(
                      label: widget.question.year.toString(),
                      color: QuizColors.secondary),
                  PSBadge(
                      label: widget.question.subject,
                      color: QuizColors.textSecondary),
                  if (widget.question.topic != null)
                    PSBadge(
                        label: widget.question.topic!,
                        color: QuizColors.textSecondary),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                widget.question.questionText,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12.0,
                  fontWeight: FontWeight.w400,
                  color: QuizColors.textPrimary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 16),
              ...widget.question.optionList.map((opt) {
                final optKey = int.tryParse(opt.key) ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _OptionTile(
                    optionKey: optKey,
                    optionLabel: opt.key,
                    optionText: opt.value,
                    selected: widget.selected == optKey,
                    submitted: widget.submitted,
                    isCorrect: widget.question.correctAnswer == optKey,
                    onTap: widget.submitted
                        ? null
                        : () => context
                            .read<QuizProvider>()
                            .selectOption(widget.questionIndex, optKey),
                  ),
                );
              }),
              const SizedBox(height: 6),
              if (!widget.submitted) ...[
                SizedBox(
                  width: double.infinity,
                  child: PSButton(
                    label: 'Submit Answer',
                    icon: Icons.check_rounded,
                    color: widget.selected == null
                        ? QuizColors.textTertiary
                        : QuizColors.primary,
                    onTap: widget.selected == null ? null : widget.onSubmit,
                  ),
                ),
              ] else ...[
                _ResultCard(
                  isCorrect: widget.selected == widget.question.correctAnswer,
                  correctAnswer:
                      '${widget.question.correctAnswer}. ${widget.question.options[widget.question.correctAnswer.toString()] ?? ''}',
                ),
              ],
            ],
          ),
        ),
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
  final VoidCallback onTap;
  const _LimitOverlay({required this.onTap});

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
                        child: const Icon(Icons.lock_clock_rounded,
                            color: QuizColors.secondary, size: 28),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Daily limit reached',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12.75,
                          fontWeight: FontWeight.w700,
                          color: QuizColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Tap to see when more questions unlock',
                        textAlign: TextAlign.center,
                        style: TextStyle(
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

class _SwipeLimitSheet extends StatefulWidget {
  final Duration? timeRemaining;
  const _SwipeLimitSheet({required this.timeRemaining});

  @override
  State<_SwipeLimitSheet> createState() => _SwipeLimitSheetState();
}

class _SwipeLimitSheetState extends State<_SwipeLimitSheet> {
  late Duration? _remaining = widget.timeRemaining;

  @override
  Widget build(BuildContext context) {
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
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: PSButton(
                  label: 'Upgrade for unlimited access',
                  icon: Icons.workspace_premium_rounded,
                  color: QuizColors.secondary,
                  onTap: () {
                    Navigator.of(context).pop();
                  },
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
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
