import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import '../providers/analytics_provider.dart';
import '../providers/quiz_provider.dart';
import '../models/question_model.dart';
import '../widgets/ps_card.dart';
import '../services/api_service.dart';
import 'quiz_screen.dart' show SoundSettings;

class RevisionColors {
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
}

class SubjectCluster {
  final String subject;
  final List<Question> questions;

  const SubjectCluster({required this.subject, required this.questions});
}

class RevisionScreen extends StatefulWidget {
  const RevisionScreen({super.key});

  @override
  State<RevisionScreen> createState() => _RevisionScreenState();
}

class _RevisionScreenState extends State<RevisionScreen> {
  bool _loading = true;
  String? _error;
  List<SubjectCluster> _clusters = [];

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final bookmarks = await ApiService().getBookmarks();
      final Map<String, List<Question>> grouped = {};

      for (final bm in bookmarks) {
        final q = bm['question'];
        if (q == null) continue;
        final question = Question.fromJson(q);
        final subject =
            question.subject.isNotEmpty ? question.subject : 'Other';
        grouped.putIfAbsent(subject, () => []).add(question);
      }

      final clusters = grouped.entries
          .map((e) => SubjectCluster(subject: e.key, questions: e.value))
          .toList()
        ..sort((a, b) => b.questions.length.compareTo(a.questions.length));

      if (!mounted) return;
      setState(() {
        _clusters = clusters;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load saved questions';
        _loading = false;
      });
    }
  }

  Future<void> _openSubject(SubjectCluster cluster) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RevisionQuizScreen(
          subject: cluster.subject,
          questions: cluster.questions,
        ),
      ),
    );
    _loadBookmarks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RevisionColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadBookmarks,
          color: RevisionColors.primary,
          backgroundColor: RevisionColors.card,
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const PSLoader(message: 'Loading saved questions…');
    }

    if (_error != null) {
      return PSEmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'Something went wrong',
        subtitle: _error!,
        action: PSButton(
          label: 'Retry',
          icon: Icons.refresh_rounded,
          onTap: _loadBookmarks,
        ),
      );
    }

    if (_clusters.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 80),
          PSEmptyState(
            icon: Icons.bookmark_border_rounded,
            title: 'No saved questions yet',
            subtitle: 'Save questions from the quiz to revise them here.',
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _clusters.length,
      itemBuilder: (context, index) {
        final cluster = _clusters[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _SubjectClusterTile(
            cluster: cluster,
            onTap: () => _openSubject(cluster),
          ),
        );
      },
    );
  }
}

class _SubjectClusterTile extends StatelessWidget {
  final SubjectCluster cluster;
  final VoidCallback onTap;

  const _SubjectClusterTile({required this.cluster, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            decoration: BoxDecoration(
              color: RevisionColors.card.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.06),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: RevisionColors.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.menu_book_rounded,
                    color: RevisionColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cluster.subject,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: RevisionColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${cluster.questions.length} saved question${cluster.questions.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: RevisionColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: RevisionColors.textTertiary,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RevisionQuizScreen extends StatefulWidget {
  final String subject;
  final List<Question> questions;

  const RevisionQuizScreen({
    super.key,
    required this.subject,
    required this.questions,
  });

  @override
  State<RevisionQuizScreen> createState() => _RevisionQuizScreenState();
}

class _RevisionQuizScreenState extends State<RevisionQuizScreen> {
  late final List<Question> _questions = List.of(widget.questions);
  late final PageController _pageController = PageController();
  final Map<int, int> _selected = {};
  final Set<int> _submitted = {};
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _selectOption(int index, int optionKey) {
    if (_submitted.contains(index)) return;
    setState(() => _selected[index] = optionKey);
  }

  void _submit(int index) {
    if (_selected[index] == null) return;
    setState(() => _submitted.add(index));
    context.read<AnalyticsProvider>().invalidate();
  }

  void _goToNext() {
    if (_currentPage >= _questions.length - 1) return;
    _pageController.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _removeBookmark(int index) async {
    final question = _questions[index];
    try {
      await ApiService().removeBookmark(questionId: question.id);
      if (!mounted) return;
      setState(() {
        _questions.removeAt(index);
        _selected.remove(index);
        _submitted.remove(index);
        if (_questions.isEmpty) {
          Navigator.of(context).pop();
          return;
        }
        if (_currentPage >= _questions.length) {
          _currentPage = _questions.length - 1;
          _pageController.jumpToPage(_currentPage);
        } else {
          _pageController.jumpToPage(_currentPage);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Removed from saved',
            style: TextStyle(
                fontFamily: 'Inter', fontSize: 13, color: Colors.white),
          ),
          backgroundColor: RevisionColors.card,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not remove question',
            style: TextStyle(
                fontFamily: 'Inter', fontSize: 13, color: Colors.white),
          ),
          backgroundColor: RevisionColors.card,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final quizProvider = context.watch<QuizProvider>();
    final lang = quizProvider.language;

    return Scaffold(
      backgroundColor: RevisionColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: RevisionColors.textPrimary),
                  ),
                  Expanded(
                    child: Text(
                      widget.subject,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: RevisionColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _LanguageToggle(
                    language: lang,
                    onTap: () => context.read<QuizProvider>().toggleLanguage(),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: RevisionColors.card.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: RevisionColors.cardBorder, width: 1),
                    ),
                    child: Text(
                      '${_currentPage + 1} / ${_questions.length}',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: RevisionColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _questions.length,
                      onPageChanged: (i) => setState(() => _currentPage = i),
                      itemBuilder: (context, index) {
                        return _RevisionQuestionCard(
                          question: _questions[index],
                          language: lang,
                          selected: _selected[index],
                          submitted: _submitted.contains(index),
                          onSelect: (key) => _selectOption(index, key),
                          onSubmit: () => _submit(index),
                          onRemove: () => _removeBookmark(index),
                          onNavigateNext: _goToNext,
                        );
                      },
                    ),
                  ),
                  if (_currentPage < _questions.length - 1)
                    Positioned(
                      right: 16,
                      bottom: 20,
                      child: _NextButton(onTap: _goToNext),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageToggle extends StatelessWidget {
  final AppLanguage language;
  final VoidCallback onTap;

  const _LanguageToggle({required this.language, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isHindi = language == AppLanguage.hindi;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: RevisionColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.translate_rounded,
              color: RevisionColors.textSecondary,
              size: 15,
            ),
            const SizedBox(width: 6),
            Text(
              isHindi ? 'हिंदी' : 'English',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: RevisionColors.textSecondary,
              ),
            ),
          ],
        ),
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
          color: RevisionColors.card,
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
          Icons.keyboard_arrow_right_rounded,
          color: RevisionColors.textSecondary,
          size: 24,
        ),
      ),
    );
  }
}

class _RevisionQuestionCard extends StatefulWidget {
  final Question question;
  final AppLanguage language;
  final int? selected;
  final bool submitted;
  final ValueChanged<int> onSelect;
  final VoidCallback onSubmit;
  final VoidCallback onRemove;
  final VoidCallback onNavigateNext;

  const _RevisionQuestionCard({
    required this.question,
    required this.language,
    required this.selected,
    required this.submitted,
    required this.onSelect,
    required this.onSubmit,
    required this.onRemove,
    required this.onNavigateNext,
  });

  @override
  State<_RevisionQuestionCard> createState() => _RevisionQuestionCardState();
}

class _RevisionQuestionCardState extends State<_RevisionQuestionCard>
    with SingleTickerProviderStateMixin {
  bool _explanationOpen = false;
  late AnimationController _panelController;
  late Animation<Offset> _panelSlide;
  late final AudioPlayer _audioPlayer;

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
  }

  @override
  void dispose() {
    _panelController.dispose();
    _audioPlayer.dispose();
    super.dispose();
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
    final correctOpt =
        q.optionsFor(widget.language)[q.correctAnswer.toString()] ?? '';
    final shareText =
        '🎯 PrepSwipe Quiz\n\n📘 ${q.exam} ${q.year} | ${q.subject}${q.topic != null ? ' › ${q.topic}' : ''}\n\n❓ ${q.questionText(widget.language)}\n\n${q.optionList(widget.language).map((o) => '${o.key}. ${o.value}').join('\n')}\n\n✅ Answer: ${q.correctAnswer}. $correctOpt\n\nPractice more PYQs on PrepSwipe 👇\nhttps://play.google.com/store/apps/details?id=com.anuritinnovation.prepswipe';
    await Share.share(shareText,
        subject: 'PrepSwipe – ${q.exam} ${q.year} Question');
  }

  Future<void> _playCorrectSound() async {
    try {
      final enabled = await SoundSettings.isEnabled();
      if (!enabled || !mounted) return;
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('music/correct_answer.mp3'));
    } catch (_) {
      // Sound playback failure should never block the quiz flow.
    }
  }

  void _handleSubmit() {
    widget.onSubmit();
    if (widget.selected == widget.question.correctAnswer) {
      _playCorrectSound();
    }
  }

  @override
  Widget build(BuildContext context) {
    final explanation = widget.question.explanation(widget.language);

    return LayoutBuilder(
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
                      color: RevisionColors.card.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: RevisionColors.primary.withValues(alpha: 0.12),
                          blurRadius: 28,
                          spreadRadius: -8,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: _ScrollableRevisionCardContent(
                      question: widget.question,
                      language: widget.language,
                      selected: widget.selected,
                      submitted: widget.submitted,
                      onSelect: widget.onSelect,
                      onSubmit: _handleSubmit,
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
                    onRemove: widget.onRemove,
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
                            color: RevisionColors.card.withValues(alpha: 0.97),
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
    );
  }
}

class _ScrollableRevisionCardContent extends StatelessWidget {
  final Question question;
  final AppLanguage language;
  final int? selected;
  final bool submitted;
  final ValueChanged<int> onSelect;
  final VoidCallback onSubmit;

  const _ScrollableRevisionCardContent({
    required this.question,
    required this.language,
    required this.selected,
    required this.submitted,
    required this.onSelect,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
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
                  label: question.year.toString(),
                  color: RevisionColors.secondary),
              PSBadge(
                  label: question.subject, color: RevisionColors.textSecondary),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            question.questionText(language),
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12.0,
              fontWeight: FontWeight.w400,
              color: RevisionColors.textPrimary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          ...question.optionList(language).map((opt) {
            final optKey = int.tryParse(opt.key) ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RevisionOptionTile(
                optionKey: optKey,
                optionLabel: opt.key,
                optionText: opt.value,
                selected: selected == optKey,
                submitted: submitted,
                isCorrect: question.correctAnswer == optKey,
                onTap: submitted ? null : () => onSelect(optKey),
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
                    ? RevisionColors.textTertiary
                    : RevisionColors.primary,
                onTap: selected == null ? null : onSubmit,
              ),
            ),
          ] else ...[
            _RevisionResultCard(
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
                    color: RevisionColors.textPrimary,
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
                    color: RevisionColors.textSecondary,
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
                      color: RevisionColors.textSecondary,
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
                        color: RevisionColors.textTertiary,
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
                  color: RevisionColors.primary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: RevisionColors.primary.withValues(alpha: 0.35),
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
                        color: RevisionColors.primary,
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: RevisionColors.primary,
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
  final VoidCallback onRemove;
  final VoidCallback onExplain;
  final VoidCallback onShare;

  const _CardActionBar({
    required this.onRemove,
    required this.onExplain,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionButton(
          icon: Icons.bookmark_remove_rounded,
          label: 'Remove',
          iconColor: RevisionColors.error,
          onTap: onRemove,
        ),
        const SizedBox(height: 20),
        _ActionButton(
          icon: Icons.help_outline_rounded,
          label: 'Explain',
          iconColor: RevisionColors.textSecondary,
          onTap: onExplain,
        ),
        const SizedBox(height: 20),
        _ActionButton(
          icon: Icons.share_rounded,
          label: 'Share',
          iconColor: RevisionColors.textSecondary,
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
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 40,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 26),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 7.5,
                fontWeight: FontWeight.w500,
                color: RevisionColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RevisionOptionTile extends StatelessWidget {
  final int optionKey;
  final String optionLabel;
  final String optionText;
  final bool selected;
  final bool submitted;
  final bool isCorrect;
  final VoidCallback? onTap;

  const _RevisionOptionTile({
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
          ? RevisionColors.primary.withValues(alpha: 0.10)
          : Colors.white.withValues(alpha: 0.03);
    }
    if (isCorrect) return RevisionColors.success.withValues(alpha: 0.10);
    if (selected && !isCorrect) {
      return RevisionColors.error.withValues(alpha: 0.10);
    }
    return Colors.white.withValues(alpha: 0.03);
  }

  Color _borderColor() {
    if (!submitted) {
      return selected ? RevisionColors.primary : RevisionColors.cardBorder;
    }
    if (isCorrect) return RevisionColors.success;
    if (selected && !isCorrect) return RevisionColors.error;
    return RevisionColors.cardBorder;
  }

  Color _labelColor() {
    if (!submitted) {
      return selected ? RevisionColors.primary : RevisionColors.textSecondary;
    }
    if (isCorrect) return RevisionColors.success;
    if (selected && !isCorrect) return RevisionColors.error;
    return RevisionColors.textTertiary;
  }

  Widget? _trailingIcon() {
    if (!submitted) return null;
    if (isCorrect) {
      return const Icon(Icons.check_circle_rounded,
          color: RevisionColors.success, size: 20);
    }
    if (selected && !isCorrect) {
      return const Icon(Icons.cancel_rounded,
          color: RevisionColors.error, size: 20);
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
                        ? RevisionColors.textTertiary
                        : RevisionColors.textPrimary,
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

class _RevisionResultCard extends StatelessWidget {
  final bool isCorrect;
  final String correctAnswer;

  const _RevisionResultCard({
    required this.isCorrect,
    required this.correctAnswer,
  });

  @override
  Widget build(BuildContext context) {
    final color = isCorrect ? RevisionColors.success : RevisionColors.error;
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
                color: RevisionColors.textSecondary,
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
                color: RevisionColors.textPrimary,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
