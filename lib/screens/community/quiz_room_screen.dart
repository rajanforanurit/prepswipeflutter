import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:prepswipe/models/room_model.dart';
import 'package:prepswipe/screens/community/leaderboard_screen.dart';
import 'package:prepswipe/services/api_service.dart';
import 'package:prepswipe/utils/app_theme.dart';
import 'package:prepswipe/widgets/ps_card.dart';

class QuizRoomScreen extends StatefulWidget {
  final Room room;
  final List<RoomQuestion> questions;

  const QuizRoomScreen({
    super.key,
    required this.room,
    required this.questions,
  });

  @override
  State<QuizRoomScreen> createState() => _QuizRoomScreenState();
}

class _QuizRoomScreenState extends State<QuizRoomScreen> {
  final ApiService apiService = ApiService();
  int _currentIndex = 0;
  final Map<int, int> _userSelections = {}; // Index : Option index (1-4)
  final Map<int, int> _questionTimers = {}; // Index : Seconds taken

  Timer? _ticker;
  int _secondsElapsed = 0;

  late final CardSwiperController _swiperController;
  bool _isHindi = false;

  @override
  void initState() {
    super.initState();
    _swiperController = CardSwiperController();
    _startTimer();
  }

  @override
  void dispose() {
    _swiperController.dispose();
    _ticker?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _secondsElapsed++;
        _questionTimers[_currentIndex] =
            (_questionTimers[_currentIndex] ?? 0) + 1;
      });
    });
  }

  void _submitTest() async {
    _ticker?.cancel();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    List<QuizAttempt> attempts = [];
    for (int i = 0; i < widget.questions.length; i++) {
      final q = widget.questions[i];
      final selected = _userSelections[i] ?? -1;
      final isSkipped = selected == -1;
      final isCorrect = selected == q.correctAnswer;

      attempts.add(
        QuizAttempt(
          questionId: q.id,
          selectedOption: isSkipped ? -1 : selected,
          isCorrect: isCorrect,
          isSkipped: isSkipped,
          timeTakenSeconds: _questionTimers[i] ?? 0,
          questionMeta: {
            'exam': q.exam,
            'subject': q.subject,
            'topic': q.topic,
            'year': q.year,
            'marks': q.marks,
            'negativeMarks': q.negativeMarks,
          },
        ),
      );
    }

    try {
      final leaderboard = await apiService.submitRoomResults(
        roomId: widget.room.roomId,
        attempts: attempts,
      );

      Navigator.pop(context); // Dismiss loader

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LeaderboardScreen(
            roomId: widget.room.roomId,
            initialLeaderboard: leaderboard,
          ),
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Dismiss loader
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Submission Error: ${e.toString()}')),
      );
    }
  }

  void _showQuitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Quit Test?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to quit the test? Your current progress will be lost.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Exit quiz screen
            },
            child:
                const Text('Quit', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  String _getOptionLabel(int optionKey) {
    switch (optionKey) {
      case 1:
        return 'A';
      case 2:
        return 'B';
      case 3:
        return 'C';
      case 4:
        return 'D';
      default:
        return optionKey.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.bg,
          title: Text(widget.room.title),
        ),
        body: const Center(
            child: Text('No questions loaded in this room.',
                style: TextStyle(color: Colors.white))),
      );
    }

    final formattedTime =
        '${(_secondsElapsed ~/ 60).toString().padLeft(2, '0')}:${(_secondsElapsed % 60).toString().padLeft(2, '0')}';

    return WillPopScope(
      onWillPop: () async {
        _showQuitConfirmation();
        return false;
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.bg,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: _showQuitConfirmation,
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.room.title,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                'Question ${_currentIndex + 1} of ${widget.questions.length}',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: Colors.white38,
                ),
              ),
            ],
          ),
          actions: [
            // Timer Widget
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              margin: const EdgeInsets.only(right: 4, top: 10, bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer_outlined,
                      size: 15, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text(
                    formattedTime,
                    style: const TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  ),
                ],
              ),
            ),
            // Language Toggle Widget
            IconButton(
              icon: Icon(
                Icons.translate_rounded,
                color: _isHindi ? Colors.amber : Colors.white54,
              ),
              tooltip: 'Toggle Language',
              onPressed: () {
                setState(() {
                  _isHindi = !_isHindi;
                });
              },
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Question Swiper (PageView)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: CardSwiper(
                    controller: _swiperController,
                    cardsCount: widget.questions.length,
                    numberOfCardsDisplayed: widget.questions.length > 2
                        ? 3
                        : widget.questions.length,
                    backCardOffset: const Offset(0, -12),
                    padding: EdgeInsets.zero,
                    threshold: 100,
                    isLoop: false,
                    allowedSwipeDirection: const AllowedSwipeDirection.only(
                      left: true,
                      right: true,
                    ),
                    onSwipe: (previousIndex, currentIndex, direction) {
                      final isUnanswered =
                          _userSelections[previousIndex] == null;
                      if (isUnanswered) {
                        // Cancel swipe if it is not horizontal (skip)
                        if (direction != CardSwiperDirection.left &&
                            direction != CardSwiperDirection.right) {
                          return false;
                        }
                      }

                      if (currentIndex != null) {
                        setState(() {
                          _currentIndex = currentIndex;
                        });
                      }
                      return true;
                    },
                    onUndo: (previousIndex, currentIndex, direction) {
                      setState(() {
                        _currentIndex = currentIndex;
                      });
                      return true;
                    },
                    cardBuilder: (context, index, percentX, percentY) {
                      final q = widget.questions[index];
                      final questionText =
                          _isHindi ? q.hindiQuestion : q.englishQuestion;
                      final options =
                          _isHindi ? q.hindiOptions : q.englishOptions;
                      final selectedVal = _userSelections[index];
                      final isUnansweredQuestion = selectedVal == null;

                      final cardWidget = ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.06),
                              width: 1,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Badges Row
                                Row(
                                  children: [
                                    if (q.exam.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF38BDF8)
                                              .withValues(alpha: 0.08),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          q.exam.toUpperCase(),
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF7DD3FC),
                                          ),
                                        ),
                                      ),
                                    const SizedBox(width: 6),
                                    if (q.subject.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF43F5E)
                                              .withValues(alpha: 0.08),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          q.subject,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFFFDA4AF),
                                          ),
                                        ),
                                      ),
                                    const Spacer(),
                                    Text(
                                      '+${q.marks} / -${q.negativeMarks}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white54,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Question Text
                                Expanded(
                                  flex: 3,
                                  child: SingleChildScrollView(
                                    child: Text(
                                      questionText,
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Options List
                                Expanded(
                                  flex: 5,
                                  child: SingleChildScrollView(
                                    child: Column(
                                      children: options.entries.map((entry) {
                                        final optionKey =
                                            int.tryParse(entry.key) ?? 0;
                                        final optionVal =
                                            entry.value.toString();
                                        final isSelected =
                                            selectedVal == optionKey;
                                        final label =
                                            _getOptionLabel(optionKey);

                                        return _OptionRow(
                                          label: label,
                                          content: optionVal,
                                          isSelected: isSelected,
                                          onTap: () {
                                            setState(() {
                                              _userSelections[index] =
                                                  optionKey;
                                            });
                                          },
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );

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
                                      alpha: ((percentX.abs()).clamp(0, 100) /
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
                                      color:
                                          Colors.white.withValues(alpha: 0.1),
                                      width: 1.5),
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    SizedBox(
                                      width: 60,
                                      height: 60,
                                      child: CircularProgressIndicator(
                                        value: ((percentX.abs()).clamp(0, 100) /
                                            100.0),
                                        strokeWidth: 4,
                                        valueColor:
                                            const AlwaysStoppedAnimation<Color>(
                                                AppColors.primary),
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
              ),

              // Navigation and Actions Bottom Row
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 12.0),
                child: Row(
                  children: [
                    // Previous button
                    if (_currentIndex > 0)
                      Expanded(
                        child: PSButton(
                          label: 'Previous',
                          icon: Icons.keyboard_arrow_left_rounded,
                          outlined: true,
                          color: Colors.white70,
                          onTap: () {
                            _swiperController.undo();
                          },
                        ),
                      )
                    else
                      const Spacer(),
                    const SizedBox(width: 12),
                    // Next / Submit button
                    Expanded(
                      child: _currentIndex < widget.questions.length - 1
                          ? PSButton(
                              label: 'Next',
                              icon: Icons.keyboard_arrow_right_rounded,
                              onTap: () {
                                _swiperController
                                    .swipe(CardSwiperDirection.left);
                              },
                            )
                          : PSButton(
                              label: 'Submit Quiz',
                              icon: Icons.check_circle_outline_rounded,
                              color: Colors.green,
                              onTap: _submitTest,
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  final String label;
  final String content;
  final bool isSelected;
  final VoidCallback onTap;

  const _OptionRow({
    required this.label,
    required this.content,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF7C4DFF).withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF7C4DFF)
                : Colors.white.withValues(alpha: 0.06),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF7C4DFF)
                    : Colors.white.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isSelected ? Colors.white : Colors.white70,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                content,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: Colors.white,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
