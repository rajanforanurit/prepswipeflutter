import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:prepswipe/models/room_model.dart';
import 'package:prepswipe/providers/auth_provider.dart' as auth;
import 'package:prepswipe/services/api_service.dart';
import 'package:prepswipe/utils/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

class LeaderboardScreen extends StatefulWidget {
  final String roomId;
  final List<RoomParticipant> initialLeaderboard;

  const LeaderboardScreen({
    super.key,
    required this.roomId,
    required this.initialLeaderboard,
  });

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final ApiService apiService = ApiService();
  late List<RoomParticipant> _leaderboard;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _leaderboard = widget.initialLeaderboard;
  }

  Future<void> _refreshLeaderboard() async {
    setState(() => _isLoading = true);
    try {
      final room = await apiService.getRoomDetails(widget.roomId);
      setState(() {
        _leaderboard = room.participants;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update stats: ${e.toString()}')),
      );
    }
  }

  void _shareInvite() {
    final link = 'https://prepswipe.com/rooms/${widget.roomId}';
    Clipboard.setData(ClipboardData(text: link));
    Share.share(
        'Join my custom prep contest on PrepSwipe! Room ID: ${widget.roomId}\nJoin Link: $link');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied Invite Link to Clipboard!')),
    );
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Widget _buildParticipantAvatar(RoomParticipant p, bool isYou, int index,
      auth.AuthProvider authProvider) {
    if (isYou && authProvider.user?.photoURL != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Image.network(
          authProvider.user!.photoURL!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildLetterAvatar(p.name, index),
        ),
      );
    }
    return _buildLetterAvatar(p.name, index);
  }

  Widget _buildLetterAvatar(String name, int index) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    Color color;
    if (index == 0) {
      color = const Color(0xFFFFD700); // Gold
    } else if (index == 1) {
      color = const Color(0xFFE2E8F0); // Silver
    } else if (index == 2) {
      color = const Color(0xFFCD7F32); // Bronze
    } else {
      final colors = [
        const Color(0xFF7C4DFF), // Purple
        const Color(0xFF38BDF8), // Light Blue
        const Color(0xFFF43F5E), // Rose
        const Color(0xFF10B981), // Emerald
        const Color(0xFFF59E0B), // Amber
        const Color(0xFFEC4899), // Pink
        const Color(0xFF8B5CF6), // Violet
      ];
      color = colors[(index - 3) % colors.length];
    }

    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Text(
        initial,
        style: TextStyle(
          fontFamily: 'SpaceGrotesk',
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: const Text(
          'Quiz Leaderboard',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: Colors.white),
            onPressed: _shareInvite,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshLeaderboard,
              child: Column(
                children: [
                  // Room Code info bar
                  Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 20),
                    margin: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                          width: 1),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ROOM CODE',
                              style: TextStyle(
                                fontFamily: 'SpaceGrotesk',
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white38,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.roomId,
                              style: const TextStyle(
                                fontFamily: 'SpaceGrotesk',
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF38BDF8),
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: _shareInvite,
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: AppColors.textSecondary
                                      .withValues(alpha: 0.3)),
                            ),
                            child: const Icon(Icons.share_rounded,
                                size: 18, color: AppColors.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Title Bar
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: AppColors.accent.withValues(alpha: 0.3)),
                          ),
                          child: const Icon(Icons.emoji_events_outlined,
                              size: 16, color: Color(0xFFFF9F1C)),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Standings',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Participants List
                  Expanded(
                    child: ListView.builder(
                      itemCount: _leaderboard.length,
                      itemBuilder: (context, index) {
                        final p = _leaderboard[index];
                        final isCompleted = p.status == 'completed';
                        final isYou =
                            p.userId == FirebaseAuth.instance.currentUser!.uid;

                        return Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: isYou
                                ? AppColors.primary.withValues(alpha: 0.1)
                                : AppColors.card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isYou
                                  ? AppColors.primary.withValues(alpha: 0.4)
                                  : Colors.white.withValues(alpha: 0.06),
                              width: isYou ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Rank with Trophies
                              SizedBox(
                                width: 44,
                                child: Row(
                                  children: [
                                    if (index == 0)
                                      const Icon(Icons.emoji_events_rounded,
                                          size: 16, color: Color(0xFFFFD700))
                                    else if (index == 1)
                                      const Icon(Icons.emoji_events_rounded,
                                          size: 16, color: Color(0xFFE2E8F0))
                                    else if (index == 2)
                                      const Icon(Icons.emoji_events_rounded,
                                          size: 16, color: Color(0xFFCD7F32))
                                    else
                                      const SizedBox(width: 4),
                                    const SizedBox(width: 4),
                                    Text(
                                      '#${index + 1}',
                                      style: TextStyle(
                                        fontFamily: 'SpaceGrotesk',
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: index < 3
                                            ? Colors.white
                                            : Colors.white38,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Avatar
                              SizedBox(
                                width: 36,
                                height: 36,
                                child: _buildParticipantAvatar(
                                  p,
                                  isYou,
                                  index,
                                  context.read<auth.AuthProvider>(),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Participant Name & duration status
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            p.name,
                                            style: const TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isYou)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            margin:
                                                const EdgeInsets.only(left: 6),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary
                                                  .withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'YOU',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFFB388FF),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isCompleted
                                          ? 'Time: ${_formatDuration(p.timeTakenSeconds)}'
                                          : 'Status: ${p.status}',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 11,
                                        color: isCompleted
                                            ? Colors.white38
                                            : Colors.amber
                                                .withValues(alpha: 0.8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Score Info
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    isCompleted
                                        ? p.score.toStringAsFixed(
                                            p.score % 1 == 0 ? 0 : 1)
                                        : 'Pending',
                                    style: TextStyle(
                                      fontFamily: 'SpaceGrotesk',
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: isCompleted
                                          ? Colors.greenAccent
                                          : Colors.white30,
                                    ),
                                  ),
                                  if (isCompleted)
                                    const Text(
                                      'pts',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 9.5,
                                        color: Colors.white38,
                                      ),
                                    ),
                                ],
                              ),
                            ],
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
