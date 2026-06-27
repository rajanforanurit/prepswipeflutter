import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/app_theme.dart';

const Map<String, Color> _subjectColors = {
  'Polity': Color(0xFF2563EB),
  'Environment': Color(0xFF16A34A),
  'Geography': Color(0xFFF59E0B),
  'History': Color(0xFFDC2626),
  'Science': Color(0xFF7C3AED),
  'Economy': Color(0xFFEA580C),
  'Current Affairs': Color(0xFF475569),
  'Art & Culture': Color(0xFF92400E),
  'Agriculture': Color(0xFF059669),
  'International Relations': Color(0xFF0891B2),
};

const Color _defaultAccent = Color(0xFF475569);

Color _colorForSubject(String subject) {
  for (final key in _subjectColors.keys) {
    if (subject.toLowerCase().contains(key.toLowerCase()) ||
        key.toLowerCase().contains(subject.toLowerCase())) {
      return _subjectColors[key]!;
    }
  }
  return _defaultAccent;
}

enum _CardType { importantTopic, currentAffair, didYouKnow, todayInHistory }

class _FeedCard {
  final _CardType type;
  final Map<String, dynamic> data;
  _FeedCard({required this.type, required this.data});
}

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final ApiService _api = ApiService();

  List<_FeedCard> _cards = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.getImportantTopics(limit: 20),
        _api.getCurrentAffairs(limit: 20),
        _api.getDidYouKnow(limit: 20),
        _api.getRandomTodayInPast(count: 10),
      ]);

      final importantTopics =
          List<Map<String, dynamic>>.from((results[0] as Map)['data'] ?? []);
      final currentAffairs =
          List<Map<String, dynamic>>.from((results[1] as Map)['data'] ?? []);
      final didYouKnow =
          List<Map<String, dynamic>>.from((results[2] as Map)['data'] ?? []);
      final todayInHistory =
          List<Map<String, dynamic>>.from(results[3] as List);

      _buildCardList(
          importantTopics, currentAffairs, didYouKnow, todayInHistory);
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _buildCardList(
    List<Map<String, dynamic>> importantTopics,
    List<Map<String, dynamic>> currentAffairs,
    List<Map<String, dynamic>> didYouKnow,
    List<Map<String, dynamic>> todayInHistory,
  ) {
    final List<_FeedCard> cards = [];
    int itIdx = 0, caIdx = 0, dykIdx = 0, tipIdx = 0;
    int pos = 0;

    while (itIdx < importantTopics.length ||
        caIdx < currentAffairs.length ||
        dykIdx < didYouKnow.length ||
        tipIdx < todayInHistory.length) {
      final mod = pos % 5;

      if (mod == 3 && caIdx < currentAffairs.length) {
        cards.add(_FeedCard(
            type: _CardType.currentAffair, data: currentAffairs[caIdx++]));
      } else if (mod == 4 && dykIdx < didYouKnow.length) {
        cards.add(
            _FeedCard(type: _CardType.didYouKnow, data: didYouKnow[dykIdx++]));
      } else if (mod == 2 && tipIdx < todayInHistory.length) {
        cards.add(_FeedCard(
            type: _CardType.todayInHistory, data: todayInHistory[tipIdx++]));
      } else if (itIdx < importantTopics.length) {
        cards.add(_FeedCard(
            type: _CardType.importantTopic, data: importantTopics[itIdx++]));
      } else if (caIdx < currentAffairs.length) {
        cards.add(_FeedCard(
            type: _CardType.currentAffair, data: currentAffairs[caIdx++]));
      } else if (dykIdx < didYouKnow.length) {
        cards.add(
            _FeedCard(type: _CardType.didYouKnow, data: didYouKnow[dykIdx++]));
      } else if (tipIdx < todayInHistory.length) {
        cards.add(_FeedCard(
            type: _CardType.todayInHistory, data: todayInHistory[tipIdx++]));
      } else {
        break;
      }
      pos++;
    }

    _cards = cards;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
      child: Row(
        children: [
          RichText(
            text: const TextSpan(
              children: [
                TextSpan(
                  text: 'Prep',
                  style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 18,
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
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFFB800),
                    letterSpacing: -0.5,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(width: 1, height: 18, color: AppColors.cardBorder),
          const SizedBox(width: 10),
          const Text(
            'Feed',
            style: TextStyle(
              fontFamily: 'SpaceGrotesk',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const _ShimmerStack();
    if (_error != null) return _ErrorState(onRetry: _loadData);
    if (_cards.isEmpty) return const _EmptyState();
    return _VerticalFeed(cards: _cards);
  }
}

class _VerticalFeed extends StatefulWidget {
  final List<_FeedCard> cards;
  const _VerticalFeed({required this.cards});

  @override
  State<_VerticalFeed> createState() => _VerticalFeedState();
}

class _VerticalFeedState extends State<_VerticalFeed> {
  final PageController _pageController = PageController();
  final Map<int, bool> _flipped = {};

  bool _isFlipped(int i) => _flipped[i] ?? false;

  void _toggleFlip(int i) =>
      setState(() => _flipped[i] = !(_flipped[i] ?? false));

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      itemCount: widget.cards.length,
      itemBuilder: (context, index) {
        final card = widget.cards[index];
        final flipped = _isFlipped(index);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: GestureDetector(
            onTap: () => _toggleFlip(index),
            child: _FlipCard(
              flipped: flipped,
              front: _buildFront(card, index),
              back: _buildBack(card, index),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFront(_FeedCard card, int index) {
    switch (card.type) {
      case _CardType.importantTopic:
        return _ITFrontCard(data: card.data);
      case _CardType.currentAffair:
        return _CAFrontCard(data: card.data);
      case _CardType.didYouKnow:
        return _DYKFrontCard(data: card.data);
      case _CardType.todayInHistory:
        return _TIPFrontCard(data: card.data);
    }
  }

  Widget _buildBack(_FeedCard card, int index) {
    switch (card.type) {
      case _CardType.importantTopic:
        return _ITBackCard(data: card.data);
      case _CardType.currentAffair:
        return _CABackCard(data: card.data);
      case _CardType.didYouKnow:
        return _DYKBackCard(data: card.data);
      case _CardType.todayInHistory:
        return _TIPBackCard(data: card.data);
    }
  }
}

class _FlipCard extends StatefulWidget {
  final bool flipped;
  final Widget front;
  final Widget back;

  const _FlipCard({
    required this.flipped,
    required this.front,
    required this.back,
  });

  @override
  State<_FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<_FlipCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic);
  }

  @override
  void didUpdateWidget(_FlipCard old) {
    super.didUpdateWidget(old);
    if (widget.flipped != old.flipped) {
      widget.flipped ? _ctrl.forward() : _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final angle = _anim.value * 3.14159;
        final showBack = angle > 1.5708;
        return Transform(
          transform: Matrix4.rotationY(angle),
          alignment: Alignment.center,
          child: showBack
              ? Transform(
                  transform: Matrix4.rotationY(3.14159),
                  alignment: Alignment.center,
                  child: widget.back,
                )
              : widget.front,
        );
      },
    );
  }
}

class _CardShell extends StatelessWidget {
  final Color accent;
  final bool isBack;
  final Widget child;

  const _CardShell({
    required this.accent,
    required this.isBack,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isBack ? accent.withValues(alpha: 0.4) : AppColors.cardBorder,
          width: isBack ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isBack
                ? accent.withValues(alpha: 0.10)
                : Colors.black.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: child,
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final String emoji;
  final String label;
  final Color color;

  const _CategoryBadge({
    required this.emoji,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'SpaceGrotesk',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectBadge extends StatelessWidget {
  final String subject;
  final Color color;

  const _SubjectBadge({required this.subject, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        subject,
        style: TextStyle(
          fontFamily: 'SpaceGrotesk',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _DateBadge extends StatelessWidget {
  final String date;
  final Color color;

  const _DateBadge({required this.date, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        date,
        style: TextStyle(
          fontFamily: 'SpaceGrotesk',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}

class _TapToSee extends StatelessWidget {
  final Color color;

  const _TapToSee({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.touch_app_rounded,
              size: 15, color: color.withValues(alpha: 0.85)),
          const SizedBox(width: 7),
          Text(
            'Tap to See',
            style: TextStyle(
              fontFamily: 'SpaceGrotesk',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

class _TapToFlipBack extends StatelessWidget {
  final Color color;

  const _TapToFlipBack({required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.touch_app_rounded,
            size: 13, color: color.withValues(alpha: 0.55)),
        const SizedBox(width: 5),
        Text(
          'Tap to flip back',
          style: TextStyle(
            fontFamily: 'SpaceGrotesk',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: color.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final Color color;

  const _SectionLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'SpaceGrotesk',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

class _BulletPoint extends StatelessWidget {
  final String text;
  final Color color;

  const _BulletPoint({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.7),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: 'SpaceGrotesk',
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: AppColors.textPrimary,
              height: 1.55,
            ),
          ),
        ),
      ],
    );
  }
}

class _AccentStripe extends StatelessWidget {
  final Color color;

  const _AccentStripe({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 4,
      width: double.infinity,
      color: color,
    );
  }
}

class _ITFrontCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ITFrontCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final subject = data['subject'] as String? ?? '';
    final title = data['title'] as String? ?? '';
    final accent = _colorForSubject(subject);

    return _CardShell(
      accent: accent,
      isBack: false,
      child: Stack(
        children: [
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            left: -40,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.04),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AccentStripe(color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _CategoryBadge(
                            emoji: '📚',
                            label: 'Important Topics',
                            color: accent,
                          ),
                          const Spacer(),
                          _SubjectBadge(subject: subject, color: accent),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '📚',
                          style: TextStyle(fontSize: 42),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.5,
                          height: 1.25,
                        ),
                      ),
                      const Spacer(),
                      _TapToSee(color: accent),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ITBackCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ITBackCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final subject = data['subject'] as String? ?? '';
    final title = data['title'] as String? ?? '';
    final points = List<String>.from(data['points'] ?? []);
    final accent = _colorForSubject(subject);

    return _CardShell(
      accent: accent,
      isBack: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AccentStripe(color: accent),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _CategoryBadge(
                          emoji: '📚',
                          label: 'Important Topics',
                          color: accent),
                      const Spacer(),
                      _SubjectBadge(subject: subject, color: accent),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SectionLabel(label: 'KEY POINTS', color: accent),
                  const SizedBox(height: 12),
                  Expanded(
                    child: points.isEmpty
                        ? Center(
                            child: Text(
                              'No points available',
                              style: TextStyle(
                                fontFamily: 'SpaceGrotesk',
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: points.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) =>
                                _BulletPoint(text: points[i], color: accent),
                          ),
                  ),
                  const SizedBox(height: 12),
                  _TapToFlipBack(color: accent),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CAFrontCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _CAFrontCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final date = data['date'] as String? ?? '';
    final subject = data['subject'] as String? ?? '';
    final title = data['title'] as String? ?? '';
    final overview = data['overview'] as String? ?? '';
    final accent =
        _colorForSubject(subject.isEmpty ? 'Current Affairs' : subject);

    return _CardShell(
      accent: accent,
      isBack: false,
      child: Stack(
        children: [
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.05),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AccentStripe(color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _CategoryBadge(
                              emoji: '📰',
                              label: 'Current Affairs',
                              color: accent),
                          const Spacer(),
                          if (subject.isNotEmpty)
                            _SubjectBadge(subject: subject, color: accent),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (date.isNotEmpty) ...[
                        _DateBadge(date: date, color: accent),
                        const SizedBox(height: 4),
                      ],
                      const Spacer(),
                      Text(
                        '📰',
                        style: const TextStyle(fontSize: 36),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3,
                          height: 1.3,
                        ),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (overview.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          overview,
                          style: TextStyle(
                            fontFamily: 'SpaceGrotesk',
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.55,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const Spacer(),
                      _TapToSee(color: accent),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CABackCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _CABackCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final subject = data['subject'] as String? ?? '';
    final date = data['date'] as String? ?? '';
    final title = data['title'] as String? ?? '';
    final highlights = List<String>.from(data['highlights'] ?? []);
    final accent =
        _colorForSubject(subject.isEmpty ? 'Current Affairs' : subject);

    return _CardShell(
      accent: accent,
      isBack: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AccentStripe(color: accent),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _CategoryBadge(
                          emoji: '📰', label: 'Current Affairs', color: accent),
                      const Spacer(),
                      if (date.isNotEmpty)
                        _DateBadge(date: date, color: accent),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                      height: 1.35,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  _SectionLabel(label: 'HIGHLIGHTS', color: accent),
                  const SizedBox(height: 12),
                  Expanded(
                    child: highlights.isEmpty
                        ? Center(
                            child: Text(
                              'No highlights available',
                              style: TextStyle(
                                fontFamily: 'SpaceGrotesk',
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: highlights.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) => _BulletPoint(
                                text: highlights[i], color: accent),
                          ),
                  ),
                  const SizedBox(height: 12),
                  _TapToFlipBack(color: accent),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DYKFrontCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _DYKFrontCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final subject = data['subject'] as String? ?? '';
    final title = data['title'] as String? ?? data['fact'] as String? ?? '';
    final accent = _colorForSubject(subject);

    return _CardShell(
      accent: accent,
      isBack: false,
      child: Stack(
        children: [
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.06),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AccentStripe(color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _CategoryBadge(
                              emoji: '💡',
                              label: 'Did You Know',
                              color: accent),
                          const Spacer(),
                          if (subject.isNotEmpty)
                            _SubjectBadge(subject: subject, color: accent),
                        ],
                      ),
                      const Spacer(),
                      Text('💡', style: const TextStyle(fontSize: 42)),
                      const SizedBox(height: 20),
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3,
                          height: 1.3,
                        ),
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      _TapToSee(color: accent),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DYKBackCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _DYKBackCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final subject = data['subject'] as String? ?? '';
    final title = data['title'] as String? ?? data['fact'] as String? ?? '';
    final explanation =
        data['explanation'] as String? ?? data['description'] as String? ?? '';
    final keyFacts =
        List<String>.from(data['keyFacts'] ?? data['points'] ?? []);
    final examRelevance = data['examRelevance'] as String? ?? '';
    final accent = _colorForSubject(subject);

    return _CardShell(
      accent: accent,
      isBack: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AccentStripe(color: accent),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _CategoryBadge(
                          emoji: '💡', label: 'Did You Know', color: accent),
                      const Spacer(),
                      if (subject.isNotEmpty)
                        _SubjectBadge(subject: subject, color: accent),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.2,
                      height: 1.35,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (explanation.isNotEmpty) ...[
                            _SectionLabel(label: 'EXPLANATION', color: accent),
                            const SizedBox(height: 8),
                            Text(
                              explanation,
                              style: TextStyle(
                                fontFamily: 'SpaceGrotesk',
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                height: 1.55,
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],
                          if (keyFacts.isNotEmpty) ...[
                            _SectionLabel(label: 'KEY FACTS', color: accent),
                            const SizedBox(height: 8),
                            ...keyFacts.map((f) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _BulletPoint(text: f, color: accent),
                                )),
                            const SizedBox(height: 6),
                          ],
                          if (examRelevance.isNotEmpty) ...[
                            _SectionLabel(
                                label: 'EXAM RELEVANCE', color: accent),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: accent.withValues(alpha: 0.2)),
                              ),
                              child: Text(
                                examRelevance,
                                style: TextStyle(
                                  fontFamily: 'SpaceGrotesk',
                                  fontSize: 12,
                                  color: AppColors.textPrimary,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _TapToFlipBack(color: accent),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TIPFrontCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _TIPFrontCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final subject = data['subject'] as String? ?? '';
    final title = data['title'] as String? ?? '';
    final date = data['date'] as String? ?? data['year'] as String? ?? '';
    final accent = _colorForSubject(subject.isEmpty ? 'History' : subject);

    return _CardShell(
      accent: accent,
      isBack: false,
      child: Stack(
        children: [
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.05),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AccentStripe(color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _CategoryBadge(
                              emoji: '🕰️',
                              label: 'Today in History',
                              color: accent),
                          const Spacer(),
                          if (subject.isNotEmpty)
                            _SubjectBadge(subject: subject, color: accent),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (date.isNotEmpty)
                        _DateBadge(date: date, color: accent),
                      const Spacer(),
                      Text('🕰️', style: const TextStyle(fontSize: 42)),
                      const SizedBox(height: 20),
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3,
                          height: 1.3,
                        ),
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      _TapToSee(color: accent),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TIPBackCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _TIPBackCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final subject = data['subject'] as String? ?? '';
    final title = data['title'] as String? ?? '';
    final date = data['date'] as String? ?? data['year'] as String? ?? '';
    final description =
        data['description'] as String? ?? data['overview'] as String? ?? '';
    final points = List<String>.from(
        data['points'] ?? data['highlights'] ?? data['keyPoints'] ?? []);
    final significance = data['significance'] as String? ?? '';
    final accent = _colorForSubject(subject.isEmpty ? 'History' : subject);

    return _CardShell(
      accent: accent,
      isBack: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AccentStripe(color: accent),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _CategoryBadge(
                          emoji: '🕰️',
                          label: 'Today in History',
                          color: accent),
                      const Spacer(),
                      if (date.isNotEmpty)
                        _DateBadge(date: date, color: accent),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.2,
                      height: 1.35,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (description.isNotEmpty) ...[
                            _SectionLabel(label: 'OVERVIEW', color: accent),
                            const SizedBox(height: 8),
                            Text(
                              description,
                              style: TextStyle(
                                fontFamily: 'SpaceGrotesk',
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                height: 1.55,
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],
                          if (points.isNotEmpty) ...[
                            _SectionLabel(label: 'KEY FACTS', color: accent),
                            const SizedBox(height: 8),
                            ...points.map((p) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _BulletPoint(text: p, color: accent),
                                )),
                            const SizedBox(height: 6),
                          ],
                          if (significance.isNotEmpty) ...[
                            _SectionLabel(label: 'SIGNIFICANCE', color: accent),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: accent.withValues(alpha: 0.2)),
                              ),
                              child: Text(
                                significance,
                                style: const TextStyle(
                                  fontFamily: 'SpaceGrotesk',
                                  fontSize: 12,
                                  color: AppColors.textPrimary,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _TapToFlipBack(color: accent),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShimmerStack extends StatefulWidget {
  const _ShimmerStack();

  @override
  State<_ShimmerStack> createState() => _ShimmerStackState();
}

class _ShimmerStackState extends State<_ShimmerStack>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.25, end: 0.65).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final shimmerColor =
            AppColors.cardBorder.withValues(alpha: _anim.value);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.cardBorder),
            ),
            padding: const EdgeInsets.all(26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                        width: 130, height: 26, decoration: _box(shimmerColor)),
                    const Spacer(),
                    Container(
                        width: 60, height: 22, decoration: _box(shimmerColor)),
                  ],
                ),
                const Spacer(),
                Container(
                    width: 60, height: 50, decoration: _box(shimmerColor)),
                const SizedBox(height: 20),
                Container(
                    width: double.infinity,
                    height: 30,
                    decoration: _box(shimmerColor)),
                const SizedBox(height: 12),
                Container(
                    width: 220, height: 30, decoration: _box(shimmerColor)),
                const SizedBox(height: 8),
                Container(
                    width: 160, height: 30, decoration: _box(shimmerColor)),
                const Spacer(),
                Container(
                    width: 120, height: 38, decoration: _box(shimmerColor)),
              ],
            ),
          ),
        );
      },
    );
  }

  BoxDecoration _box(Color color) => BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      );
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off_rounded,
                  size: 28, color: Colors.red),
            ),
            const SizedBox(height: 20),
            const Text(
              'Something went wrong',
              style: TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We couldn\'t load your feed. Check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📚', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 20),
            const Text(
              'Nothing here yet',
              style: TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No topics or current affairs available right now.\nCheck back soon.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
