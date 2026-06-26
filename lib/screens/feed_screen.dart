import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import '../services/api_service.dart';
import '../utils/app_theme.dart';

const Color _gold = Color(0xFFFFB800);

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final ApiService _api = ApiService();
  final CardSwiperController _swiperController = CardSwiperController();

  List<Map<String, dynamic>> _importantTopics = [];
  List<Map<String, dynamic>> _currentAffairs = [];
  List<_FeedCard> _cards = [];

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _swiperController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final itResult = await _api.getImportantTopics(limit: 30);
      final caResult = await _api.getCurrentAffairs(limit: 30);

      _importantTopics =
          List<Map<String, dynamic>>.from(itResult['data'] ?? []);
      _currentAffairs = List<Map<String, dynamic>>.from(caResult['data'] ?? []);

      _buildCardList();
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _buildCardList() {
    final List<_FeedCard> cards = [];
    int itIndex = 0;
    int caIndex = 0;
    int position = 0;

    while (
        itIndex < _importantTopics.length || caIndex < _currentAffairs.length) {
      if (position % 4 == 3 && caIndex < _currentAffairs.length) {
        cards.add(_FeedCard(
          type: _CardType.currentAffair,
          data: _currentAffairs[caIndex],
        ));
        caIndex++;
      } else if (itIndex < _importantTopics.length) {
        cards.add(_FeedCard(
          type: _CardType.importantTopic,
          data: _importantTopics[itIndex],
        ));
        itIndex++;
      } else if (caIndex < _currentAffairs.length) {
        cards.add(_FeedCard(
          type: _CardType.currentAffair,
          data: _currentAffairs[caIndex],
        ));
        caIndex++;
      }
      position++;
    }

    _cards = cards;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
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
                    color: _gold,
                    letterSpacing: -0.5,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 1,
            height: 18,
            color: AppColors.cardBorder,
          ),
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
          const Spacer(),
          if (!_loading && _error == null)
            GestureDetector(
              onTap: _loadData,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: const Icon(
                  Icons.refresh_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const _ShimmerCards();
    if (_error != null) return _ErrorState(onRetry: _loadData);
    if (_cards.isEmpty) return const _EmptyState();
    return _SwipeStack(cards: _cards, controller: _swiperController);
  }
}

enum _CardType { importantTopic, currentAffair }

class _FeedCard {
  final _CardType type;
  final Map<String, dynamic> data;
  _FeedCard({required this.type, required this.data});
}

class _SwipeStack extends StatefulWidget {
  final List<_FeedCard> cards;
  final CardSwiperController controller;

  const _SwipeStack({required this.cards, required this.controller});

  @override
  State<_SwipeStack> createState() => _SwipeStackState();
}

class _SwipeStackState extends State<_SwipeStack> {
  final Map<int, bool> _flippedCards = {};

  bool _isFlipped(int index) => _flippedCards[index] ?? false;

  void _toggleFlip(int index) {
    setState(() => _flippedCards[index] = !(_flippedCards[index] ?? false));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 12),
        _buildProgressHint(),
        const SizedBox(height: 4),
        Expanded(
          child: CardSwiper(
            controller: widget.controller,
            cardsCount: widget.cards.length,
            numberOfCardsDisplayed:
                widget.cards.length < 3 ? widget.cards.length : 3,
            backCardOffset: const Offset(0, 28),
            scale: 0.94,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            allowedSwipeDirection:
                const AllowedSwipeDirection.only(left: true, right: true),
            onSwipe: (prev, current, direction) {
              if (direction == CardSwiperDirection.left &&
                  _isFlipped(prev) == false) {
                setState(() => _flippedCards[prev] = false);
              }
              return true;
            },
            cardBuilder:
                (context, index, percentThresholdX, percentThresholdY) {
              final card = widget.cards[index];
              final flipped = _isFlipped(index);

              return GestureDetector(
                onTap: () => _toggleFlip(index),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 380),
                  transitionBuilder: (child, animation) {
                    final rotate = Tween(begin: 0.0, end: 1.0).animate(
                      CurvedAnimation(
                          parent: animation, curve: Curves.easeInOutCubic),
                    );
                    return AnimatedBuilder(
                      animation: rotate,
                      child: child,
                      builder: (context, child) {
                        final angle = rotate.value * 3.14159;
                        final isBack = angle > 1.5708;
                        return Transform(
                          transform: Matrix4.rotationY(angle),
                          alignment: Alignment.center,
                          child: isBack
                              ? Transform(
                                  transform: Matrix4.rotationY(3.14159),
                                  alignment: Alignment.center,
                                  child: child,
                                )
                              : child,
                        );
                      },
                    );
                  },
                  child: flipped
                      ? KeyedSubtree(
                          key: ValueKey('back_$index'),
                          child: card.type == _CardType.importantTopic
                              ? _ImportantTopicBackCard(data: card.data)
                              : _CurrentAffairBackCard(data: card.data),
                        )
                      : KeyedSubtree(
                          key: ValueKey('front_$index'),
                          child: card.type == _CardType.importantTopic
                              ? _ImportantTopicFrontCard(data: card.data)
                              : _CurrentAffairFrontCard(data: card.data),
                        ),
                ),
              );
            },
          ),
        ),
        _buildSwipeHint(),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildProgressHint() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${widget.cards.length} cards to explore',
            style: TextStyle(
              fontFamily: 'SpaceGrotesk',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          Row(
            children: [
              _TypeBadge(
                  label: 'Topics', color: AppColors.accent, dotted: false),
              const SizedBox(width: 8),
              _TypeBadge(label: 'Current Affairs', color: _gold, dotted: false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSwipeHint() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.swipe_rounded,
              size: 14, color: AppColors.textSecondary.withValues(alpha: 0.6)),
          const SizedBox(width: 6),
          Text(
            'Swipe to navigate • Tap to flip',
            style: TextStyle(
              fontFamily: 'SpaceGrotesk',
              fontSize: 12,
              color: AppColors.textSecondary.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportantTopicFrontCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ImportantTopicFrontCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final subject = data['subject'] as String? ?? '';
    final title = data['title'] as String? ?? '';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            bottom: -30,
            left: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: 0.04),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _SubjectBadge(subject: subject, color: AppColors.accent),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.bookmark_rounded,
                        size: 16,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 2,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Tap to see key points',
                      style: TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                _CardFooterHint(
                  icon: Icons.touch_app_rounded,
                  label: 'Tap to Flip  •  Swipe to Skip',
                  color: AppColors.accent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportantTopicBackCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ImportantTopicBackCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final subject = data['subject'] as String? ?? '';
    final title = data['title'] as String? ?? '';
    final points = List<String>.from(data['points'] ?? []);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: AppColors.accent.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SubjectBadge(subject: subject, color: AppColors.accent),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 3,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Key Points',
                  style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
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
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => _BulletPoint(
                        text: points[i],
                        color: AppColors.accent,
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            _CardFooterHint(
              icon: Icons.touch_app_rounded,
              label: 'Tap to flip back',
              color: AppColors.accent,
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrentAffairFrontCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _CurrentAffairFrontCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final date = data['date'] as String? ?? '';
    final subject = data['subject'] as String? ?? '';
    final title = data['title'] as String? ?? '';
    final overview = data['overview'] as String? ?? '';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
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
                color: _gold.withValues(alpha: 0.05),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _DateBadge(date: date),
                    const SizedBox(width: 8),
                    _SubjectBadge(subject: subject, color: _gold),
                  ],
                ),
                const Spacer(),
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
                const SizedBox(height: 14),
                Text(
                  overview,
                  style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                    height: 1.55,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                _CardFooterHint(
                  icon: Icons.swipe_left_rounded,
                  label: 'Tap to flip for Highlights',
                  color: _gold,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentAffairBackCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _CurrentAffairBackCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final title = data['title'] as String? ?? '';
    final highlights = List<String>.from(data['highlights'] ?? []);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _gold.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _gold.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 3,
                  height: 16,
                  decoration: BoxDecoration(
                    color: _gold,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Highlights',
                  style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _gold,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
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
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => _BulletPoint(
                        text: highlights[i],
                        color: _gold,
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _CardFooterHint(
                  icon: Icons.touch_app_rounded,
                  label: 'Tap to flip back',
                  color: _gold,
                ),
                Text(
                  'Stay Updated with PrepSwipe',
                  style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ],
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        subject,
        style: TextStyle(
          fontFamily: 'SpaceGrotesk',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _DateBadge extends StatelessWidget {
  final String date;
  const _DateBadge({required this.date});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.cardBorder.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        date,
        style: TextStyle(
          fontFamily: 'SpaceGrotesk',
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
      ),
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
          padding: const EdgeInsets.only(top: 6),
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
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _CardFooterHint extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _CardFooterHint({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color.withValues(alpha: 0.6)),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'SpaceGrotesk',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: color.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool dotted;

  const _TypeBadge(
      {required this.label, required this.color, required this.dotted});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'SpaceGrotesk',
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _ShimmerCards extends StatefulWidget {
  const _ShimmerCards();

  @override
  State<_ShimmerCards> createState() => _ShimmerCardsState();
}

class _ShimmerCardsState extends State<_ShimmerCards>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.7).animate(
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
      animation: _animation,
      builder: (context, _) {
        final shimmerColor =
            AppColors.cardBorder.withValues(alpha: _animation.value);
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                top: 24,
                left: 8,
                right: 8,
                child: _ShimmerCard(color: shimmerColor, opacity: 0.5),
              ),
              Positioned(
                top: 12,
                left: 4,
                right: 4,
                child: _ShimmerCard(color: shimmerColor, opacity: 0.7),
              ),
              _ShimmerCard(color: shimmerColor, opacity: 1.0),
            ],
          ),
        );
      },
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  final Color color;
  final double opacity;

  const _ShimmerCard({required this.color, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.55,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.cardBorder),
        ),
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 80, height: 26, decoration: _shimmerBox(color)),
            const Spacer(),
            Container(
                width: double.infinity,
                height: 30,
                decoration: _shimmerBox(color)),
            const SizedBox(height: 12),
            Container(width: 200, height: 30, decoration: _shimmerBox(color)),
            const SizedBox(height: 24),
            Container(
                width: double.infinity,
                height: 13,
                decoration: _shimmerBox(color)),
            const SizedBox(height: 8),
            Container(width: 180, height: 13, decoration: _shimmerBox(color)),
            const Spacer(),
            Container(width: 140, height: 13, decoration: _shimmerBox(color)),
          ],
        ),
      ),
    );
  }

  BoxDecoration _shimmerBox(Color color) => BoxDecoration(
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
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 28,
                color: Colors.red,
              ),
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
            Text(
              '📚',
              style: TextStyle(fontSize: 48),
            ),
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
