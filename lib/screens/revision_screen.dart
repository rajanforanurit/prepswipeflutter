import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/analytics_provider.dart';
import '../models/question_model.dart';
import '../widgets/ps_card.dart';
import '../services/api_service.dart';

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

    final totalCount =
        _clusters.fold<int>(0, (sum, c) => sum + c.questions.length);

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _clusters.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
            child: Row(
              children: [
                const Text(
                  'Revision',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                    color: RevisionColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: RevisionColors.card.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: RevisionColors.cardBorder, width: 1),
                  ),
                  child: Text(
                    '$totalCount saved',
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
          );
        }

        final cluster = _clusters[index - 1];
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
  late List<Question> _questions = List.of(widget.questions);
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

  Future<void> _removeBookmark(int index) async {
    final question = _questions[index];
    try {
      await ApiService().removeBookmark(questionId: question.id);
      if (!mounted) return;
      setState(() {
        _questions.removeAt(index);
        if (_questions.isEmpty) {
          Navigator.of(context).pop();
          return;
        }
        if (_currentPage >= _questions.length) {
          _currentPage = _questions.length - 1;
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
              child: PageView.builder(
                controller: _pageController,
                itemCount: _questions.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: _RevisionQuestionCard(
                      question: _questions[index],
                      selected: _selected[index],
                      submitted: _submitted.contains(index),
                      onSelect: (key) => _selectOption(index, key),
                      onSubmit: () => _submit(index),
                      onRemove: () => _removeBookmark(index),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RevisionQuestionCard extends StatelessWidget {
  final Question question;
  final int? selected;
  final bool submitted;
  final ValueChanged<int> onSelect;
  final VoidCallback onSubmit;
  final VoidCallback onRemove;

  const _RevisionQuestionCard({
    required this.question,
    required this.selected,
    required this.submitted,
    required this.onSelect,
    required this.onSubmit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: double.infinity,
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          PSBadge(
                              label: question.year.toString(),
                              color: RevisionColors.secondary),
                          PSBadge(
                              label: question.subject,
                              color: RevisionColors.textSecondary),
                          if (question.topic != null)
                            PSBadge(
                                label: question.topic!,
                                color: RevisionColors.textSecondary),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: onRemove,
                      behavior: HitTestBehavior.opaque,
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.bookmark_remove_rounded,
                          color: RevisionColors.error,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  question.questionText,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: RevisionColors.textPrimary,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 16),
                ...question.optionList.map((opt) {
                  final optKey = int.tryParse(opt.key) ?? 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _RevisionOptionTile(
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
                if (!submitted)
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
                  )
                else
                  _RevisionResultCard(
                    isCorrect: selected == question.correctAnswer,
                    correctAnswer:
                        '${question.correctAnswer}. ${question.options[question.correctAnswer.toString()] ?? ''}',
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RevisionOptionTile extends StatelessWidget {
  final String optionLabel;
  final String optionText;
  final bool selected;
  final bool submitted;
  final bool isCorrect;
  final VoidCallback? onTap;

  const _RevisionOptionTile({
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
    if (selected && !isCorrect)
      return RevisionColors.error.withValues(alpha: 0.10);
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
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
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
                    fontSize: 14,
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

  const _RevisionResultCard(
      {required this.isCorrect, required this.correctAnswer});

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
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
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
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: RevisionColors.textSecondary,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              correctAnswer,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
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
